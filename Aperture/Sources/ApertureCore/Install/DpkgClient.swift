import Foundation

/// Reads dpkg status and runs dpkg -i for local .deb files.
public actor DpkgClient {
    private let queue = DispatchQueue(label: "aperture.dpkg")
    public private(set) var privilegeHelper: AptClient.PrivilegeHelper

    public init() { self.privilegeHelper = AptClient.PrivilegeHelper.detect() }

    public static let statusFile = "/var/lib/dpkg/status"

    public func installed() throws -> [InstalledRecord] {
        guard FileManager.default.fileExists(atPath: Self.statusFile) else { return [] }
        let text = try String(contentsOfFile: Self.statusFile, encoding: .utf8)
        return parseStatus(text)
    }

    public func parseStatus(_ text: String) -> [InstalledRecord] {
        var records: [InstalledRecord] = []
        var pkg = "", version = "", arch = "", desc = ""
        var status: DpkgStatus = .unknown
        var size: Int64 = 0
        func flush() {
            guard !pkg.isEmpty else { return }
            records.append(InstalledRecord(
                package: pkg, version: version, architecture: arch,
                status: status, installedSize: size, shortDescription: desc))
            pkg = ""; version = ""; arch = ""; desc = ""; size = 0; status = .unknown
        }
        let newline = Character("\n")
        let tab = Character("\t")
        for raw in text.split(separator: newline, omittingEmptySubsequences: false) {
            let line = String(raw)
            if line.isEmpty { flush(); continue }
            if line.hasPrefix(" ") || line.hasPrefix(String(tab)) {
                if !desc.isEmpty { desc += " " + String(line.drop(while: { $0 == " " || $0 == tab })) }
                continue
            }
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let val = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            switch key {
            case "Package": pkg = val
            case "Version": version = val
            case "Architecture": arch = val
            case "Status":
                let parts = val.split(separator: " ").map(String.init)
                if parts.count == 3 { status = DpkgStatus(rawStatus: parts[2], rawWanted: parts[0], rawError: parts[1]) }
            case "Installed-Size": size = Int64(val) ?? 0
            case "Description": desc = val
            default: break
            }
        }
        flush()
        return records
    }

    public func installLocal(_ path: String) -> AsyncStream<InstallProgress> {
        let helper = privilegeHelper
        return AsyncStream { continuation in
            queue.async {
                let proc = Process()
                if helper == .none { proc.launchPath = "/usr/bin/dpkg"; proc.arguments = ["-i", path] }
                else { proc.launchPath = "/usr/bin/env"; proc.arguments = [helper.rawValue, "dpkg", "-i", path] }
                let outPipe = Pipe(); let errPipe = Pipe()
                proc.standardOutput = outPipe; proc.standardError = errPipe
                let outHandle = outPipe.fileHandleForReading
                var buffer = Data()
                outHandle.readabilityHandler = { handle in
                    let chunk = handle.availableData
                    if chunk.isEmpty { return }
                    buffer.append(chunk)
                    while let nl = buffer.firstIndex(of: 0x0A) {
                        let lineData = buffer[...nl]
                        buffer = Data(buffer[buffer.index(after: nl)...])
                        if let s = String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .newlines) {
                            continuation.yield(InstallProgress.line(s))
                        }
                    }
                }
                proc.terminationHandler = { p in
                    outHandle.readabilityHandler = nil
                    let err = (try? errPipe.fileHandleForReading.readToEnd()) ?? Data()
                    let errStr = String(data: err, encoding: .utf8) ?? ""
                    continuation.yield(InstallProgress.finished(exitCode: p.terminationStatus, stderr: errStr))
                    continuation.finish()
                }
                do { try proc.run() } catch {
                    continuation.yield(InstallProgress.finished(exitCode: -1, stderr: String(describing: error)))
                    continuation.finish()
                }
            }
        }
    }
}

