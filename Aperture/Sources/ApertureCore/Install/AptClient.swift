import Foundation

public actor AptClient {
    private let queue = DispatchQueue(label: "aperture.apt")

    public enum PrivilegeHelper: String, Sendable {
        case tsudo, sudo, none
        public static func detect() -> PrivilegeHelper {
            if FileManager.default.isExecutableFile(atPath: "/usr/bin/tsudo") { return .tsudo }
            if FileManager.default.isExecutableFile(atPath: "/usr/bin/sudo") { return .sudo }
            return .none
        }
    }
    public private(set) var privilegeHelper: PrivilegeHelper = .none

    public init() { self.privilegeHelper = PrivilegeHelper.detect() }

    public func install(_ p: String) -> AsyncStream<InstallProgress> { run(["install","-y","--allow-downgrades",p]) }
    public func reinstall(_ p: String) -> AsyncStream<InstallProgress> { run(["install","--reinstall","-y",p]) }
    public func upgrade(_ p: String) -> AsyncStream<InstallProgress> { run(["install","--only-upgrade","-y",p]) }
    public func remove(_ p: String) -> AsyncStream<InstallProgress> { run(["remove","-y",p]) }
    public func purge(_ p: String) -> AsyncStream<InstallProgress> { run(["purge","-y",p]) }
    public func update() -> AsyncStream<InstallProgress> { run(["update"]) }

    public func run(_ args: [String]) -> AsyncStream<InstallProgress> {
        let helper = privilegeHelper
        return AsyncStream { continuation in
            queue.async {
                let proc = Process()
                if helper == .none { proc.launchPath = "/usr/bin/apt-get"; proc.arguments = args }
                else { proc.launchPath = "/usr/bin/env"; proc.arguments = [helper.rawValue,"apt-get"] + args }
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

public enum InstallProgress: Sendable {
    case line(String)
    case finished(exitCode: Int32, stderr: String)
}

