import Foundation

/// Reads and writes Aperture's APT sources list at
/// /etc/apt/sources.list.d/aperture.list. Pure value-type parser; no
/// filesystem coupling in the parse path so it is unit-testable.
public struct SourcesList: Sendable {
    public static let apertureFile = "/etc/apt/sources.list.d/aperture.list"
    public init() {}

    public func parse(_ text: String) -> [SourcesEntry] {
        var entries: [SourcesEntry] = []
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if let entry = parseLine(line) { entries.append(entry) }
        }
        return entries
    }

    public func parseLine(_ line: String) -> SourcesEntry? {
        var rest = line.trimmingCharacters(in: .whitespaces)
        guard rest.hasPrefix("deb") else { return nil }
        rest = String(rest.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        var archs: [String] = []
        if rest.hasPrefix("[") {
            guard let close = rest.firstIndex(of: "]") else { return nil }
            let opts = rest[rest.index(after: rest.startIndex)..<close]
            archs = opts.split(separator: " ")
                .map(String.init)
                .filter { $0.hasPrefix("arch=") }
                .flatMap { $0.dropFirst(5).split(separator: ",").map(String.init) }
            rest = String(rest[rest.index(after: close)...]).trimmingCharacters(in: .whitespaces)
        }
        let parts = rest.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2 else { return nil }
        return SourcesEntry(
            url: String(parts[0]),
            suite: String(parts[1]),
            components: parts.dropFirst(2).map(String.init),
            archs: archs
        )
    }

    public func readAperture() throws -> [SourcesEntry] {
        guard FileManager.default.fileExists(atPath: Self.apertureFile) else { return [] }
        let text = try String(contentsOfFile: Self.apertureFile, encoding: .utf8)
        return parse(text)
    }

    public func append(_ entry: SourcesEntry) throws {
        var existing = try readAperture()
        if !existing.contains(where: { $0.url == entry.url && $0.suite == entry.suite }) {
            existing.append(entry)
        }
        try write(existing)
    }

    public func remove(url: String, suite: String) throws {
        var existing = try readAperture()
        existing.removeAll { $0.url == url && $0.suite == suite }
        try write(existing)
    }

    public func write(_ entries: [SourcesEntry]) throws {
        let text = entries.map(\.serialized).joined(separator: "\n") + "\n"
        let dir = (Self.apertureFile as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try text.write(toFile: Self.apertureFile, atomically: true, encoding: .utf8)
    }
}

public struct SourcesEntry: Hashable, Sendable {
    public let url: String
    public let suite: String
    public let components: [String]
    public let archs: [String]
    public init(url: String, suite: String, components: [String], archs: [String] = []) {
        self.url = url; self.suite = suite; self.components = components; self.archs = archs
    }
    public var serialized: String {
        var s = "deb "
        if !archs.isEmpty { s += "[arch=\(archs.joined(separator: ","))] " }
        s += "\(url) \(suite)"
        if !components.isEmpty { s += " " + components.joined(separator: " ") }
        return s
    }
}

