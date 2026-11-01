import Foundation
import SQLite

/// SQLite-backed FTS5 full-text index over all packages from all repos.
/// Uses raw SQL for the FTS5 virtual table to avoid typed-API friction.
public final class SearchIndex: @unchecked Sendable {
    private let db: Connection

    public init(path: String = ":memory:") throws {
        db = try Connection(path)
        db.busyTimeout = 5_000
        try migrate()
    }

    private func migrate() throws {
        try db.run("""
            CREATE TABLE IF NOT EXISTS aperture_packages (
                id TEXT PRIMARY KEY,
                package TEXT NOT NULL,
                name TEXT NOT NULL,
                version TEXT NOT NULL,
                section TEXT,
                repo_id TEXT NOT NULL,
                description TEXT NOT NULL,
                author TEXT,
                icon_url TEXT
            )
        """)
        try db.run("CREATE INDEX IF NOT EXISTS idx_packages_repo ON aperture_packages(repo_id)")
        try db.run("""
            CREATE VIRTUAL TABLE IF NOT EXISTS aperture_fts USING fts5(
                package, name, description, author,
                content='aperture_packages', content_rowid='rowid',
                tokenize='porter unicode61')
        """)
    }

    public func replaceRepo(_ pkgs: [AperturePackage], repoID: String) throws {
        try db.transaction {
            try db.run("DELETE FROM aperture_fts WHERE rowid IN (SELECT rowid FROM aperture_packages WHERE repo_id = ?)", repoID)
            try db.run("DELETE FROM aperture_packages WHERE repo_id = ?", repoID)
            for p in pkgs {
                try db.run(
                    "INSERT OR REPLACE INTO aperture_packages (id, package, name, version, section, repo_id, description, author, icon_url) VALUES (?,?,?,?,?,?,?,?,?)",
                    p.id, p.package, p.name, p.version, p.section, p.repoID, p.descriptionText, p.author, p.iconURL)
                let rowid = try db.scalar("SELECT rowid FROM aperture_packages WHERE id = ?", p.id) as! Int64
                try db.run(
                    "INSERT INTO aperture_fts (rowid, package, name, description, author) VALUES (?,?,?,?,?)",
                    rowid, p.package, p.name, p.descriptionText, p.author ?? "")
            }
        }
    }

    public struct Hit: Hashable, Sendable {
        public let id: String
        public let package: String
        public let name: String
        public let version: String
        public let section: String?
        public let repoID: String
        public let iconURL: String?

        public init(id: String, package: String, name: String, version: String,
                     section: String?, repoID: String, iconURL: String?) {
            self.id = id; self.package = package; self.name = name
            self.version = version; self.section = section
            self.repoID = repoID; self.iconURL = iconURL
        }
    }

    public func search(_ query: String, limit: Int = 200) throws -> [Hit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let match = FTSQueryTokenizer.tokenize(trimmed)
        guard !match.isEmpty else { return [] }
        let sql = """
            SELECT p.id, p.package, p.name, p.version, p.section, p.repo_id, p.icon_url
            FROM aperture_fts JOIN aperture_packages p ON p.rowid = aperture_fts.rowid
            WHERE aperture_fts MATCH ?
            ORDER BY bm25(aperture_fts)
            LIMIT ?
        """
        let stmt = try db.prepare(sql)
        var hits: [Hit] = []
        for row in stmt.bind(match, limit) {
            hits.append(Hit(
                id: row[0] as! String, package: row[1] as! String,
                name: row[2] as! String, version: row[3] as! String,
                section: row[4] as? String, repoID: row[5] as! String,
                iconURL: row[6] as? String))
        }
        return hits
    }

    public func count() throws -> Int {
        try db.scalar("SELECT COUNT(*) FROM aperture_packages") as! Int
    }

    public func clearRepo(_ repoID: String) throws {
        try db.transaction {
            try db.run("DELETE FROM aperture_fts WHERE rowid IN (SELECT rowid FROM aperture_packages WHERE repo_id = ?)", repoID)
            try db.run("DELETE FROM aperture_packages WHERE repo_id = ?", repoID)
        }
    }
}

enum FTSQueryTokenizer {
    static func tokenize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let allowed = CharacterSet.alphanumerics
        let tokens = trimmed.split(whereSeparator: { $0.isWhitespace })
        let escaped = tokens.compactMap { token -> String? in
            let cleaned = String(token).filter { $0.unicodeScalars.allSatisfy { allowed.contains($0) } }
            return cleaned.isEmpty ? nil : "\(cleaned)*"
        }
        return escaped.joined(separator: " ")
    }
}
