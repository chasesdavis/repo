import Foundation
import Compression

public struct PackagesParser: Sendable {
    public init() {}

    public func parse(_ data: Data, repoID: String, repoURL: String) -> [AperturePackage] {
        let plain = isGzip(data) ? gunzip(data) : data
        guard let text = String(data: plain, encoding: .utf8) else { return [] }
        return parseText(text, repoID: repoID, repoURL: repoURL)
    }

    public func parseText(_ text: String, repoID: String, repoURL: String) -> [AperturePackage] {
        var packages: [AperturePackage] = []
        packages.reserveCapacity(max(64, text.count / 600))
        var pkg = "", name = "", version = "", arch = "", section: String? = nil
        var maintainer: String? = nil, author: String? = nil, desc = "", homepage: String? = nil
        var depends: [String] = [], conflicts: [String] = [], provides: [String] = [], replaces: [String] = []
        var filename = "", size: Int64 = 0, md5: String? = nil, sha256: String? = nil
        var depiction: String? = nil, sileoDepiction: String? = nil, tags: [String] = []
        var icon: String? = nil, screenshots: [String] = [], changelog: String? = nil
        var lastKey = ""
        func flush() {
            guard !pkg.isEmpty, !version.isEmpty else { return }
            let id = "\(repoID)::\(pkg)::\(version)"
            packages.append(AperturePackage(
                id: id, package: pkg, name: name.isEmpty ? pkg : name, version: version,
                architecture: arch, section: section, repoID: repoID, repoURL: repoURL,
                maintainer: maintainer, author: author, descriptionText: desc, homepage: homepage,
                depends: depends, conflicts: conflicts, provides: provides, replaces: replaces,
                filename: filename, size: size, md5sum: md5, sha256: sha256,
                depiction: depiction, sileoDepiction: sileoDepiction, tags: tags,
                iconURL: icon, screenshotURLs: screenshots, changelog: changelog))
            pkg = ""; name = ""; version = ""; arch = ""; section = nil
            maintainer = nil; author = nil; desc = ""; homepage = nil
            depends = []; conflicts = []; provides = []; replaces = []
            filename = ""; size = 0; md5 = nil; sha256 = nil
            depiction = nil; sileoDepiction = nil; tags = []
            icon = nil; screenshots = []; changelog = nil; lastKey = ""
        }
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            if line.isEmpty { flush(); continue }
            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                let cont = String(line.drop(while: { $0 == " " || $0 == "\t" }))
                if lastKey == "Description" { desc += "\n" + cont }
                continue
            }
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let val = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            lastKey = key
            switch key {
            case "Package": pkg = val
            case "Name": name = val
            case "Version": version = val
            case "Architecture": arch = val
            case "Section": section = val
            case "Maintainer": maintainer = val
            case "Author": author = val
            case "Description": desc = val
            case "Homepage": homepage = val
            case "Depends": depends = splitList(val)
            case "Conflicts": conflicts = splitList(val)
            case "Provides": provides = splitList(val)
            case "Replaces": replaces = splitList(val)
            case "Filename": filename = val
            case "Size": size = Int64(val) ?? 0
            case "MD5sum": md5 = val
            case "SHA256": sha256 = val
            case "Depiction": depiction = val
            case "SileoDepiction": sileoDepiction = val
            case "Tag": tags = splitList(val)
            case "Icon": icon = val
            case "Screenshot": screenshots.append(val)
            case "Changelog": changelog = val
            default: break
            }
        }
        flush()
        return packages
    }

    private func splitList(_ val: String) -> [String] {
        val.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private func isGzip(_ data: Data) -> Bool {
        data.count >= 2 && data[0] == 0x1F && data[1] == 0x8B
    }

    func gunzip(_ data: Data) -> Data {
        let capacity = max(data.count * 10, 64 * 1024)
        var output = Data(count: capacity)
        let written = output.withUnsafeMutableBytes { (outPtr: UnsafeMutableRawBufferPointer) -> Int in
            data.withUnsafeBytes { (inPtr: UnsafeRawBufferPointer) -> Int in
                guard let outBase = outPtr.baseAddress, let inBase = inPtr.baseAddress else { return 0 }
                return compression_decode_buffer(
                    outBase.assumingMemoryBound(to: UInt8.self), capacity,
                    inBase.assumingMemoryBound(to: UInt8.self), data.count,
                    nil, COMPRESSION_ZLIB)
            }
        }
        return output.prefix(written)
    }
}

