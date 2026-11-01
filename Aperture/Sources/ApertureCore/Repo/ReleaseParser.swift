import Foundation

/// Parses an APT Release file into a strongly-typed value.
/// Tolerant of missing fields — only Origin, Suite, and Version are required.
public struct ReleaseParser: Sendable {
    public init() {}

    public struct Release: Hashable, Sendable {
        public let origin: String
        public let label: String?
        public let suite: String
        public let version: String
        public let codename: String?
        public let description: String?
        public let archs: [String]
        public let components: [String]
        public let date: Date?
        public let acquiredBy: Date

        public init(
            origin: String, label: String?, suite: String, version: String,
            codename: String?, description: String?, archs: [String],
            components: [String], date: Date?, acquiredBy: Date = Date()
        ) {
            self.origin = origin; self.label = label; self.suite = suite
            self.version = version; self.codename = codename
            self.description = description; self.archs = archs
            self.components = components; self.date = date
            self.acquiredBy = acquiredBy
        }
    }

    public func parse(_ text: String) -> Release? {
        var dict: [String: String] = [:]
        var lastKey = ""
        let newline = Character("\n")
        for raw in text.split(separator: newline, omittingEmptySubsequences: false) {
            let line = String(raw)
            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                dict[lastKey, default: ""] += "\n" + String(line.drop(while: { $0 == " " || $0 == "\t" }))
                continue
            }
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let val = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            dict[key] = val
            lastKey = key
        }
        guard let origin = dict["Origin"], let suite = dict["Suite"], let version = dict["Version"] else {
            return nil
        }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        let date = dict["Date"].flatMap { fmt.date(from: $0) }
        return Release(
            origin: origin, label: dict["Label"], suite: suite, version: version,
            codename: dict["Codename"], description: dict["Description"],
            archs: splitList(dict["Architectures"]), components: splitList(dict["Components"]),
            date: date
        )
    }

    private func splitList(_ val: String?) -> [String] {
        guard let val, !val.isEmpty else { return [] }
        return val.split(separator: " ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}

