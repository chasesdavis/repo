import Foundation

/// Orchestrates a single Transaction end-to-end: apt-get -> progress -> result.
public actor InstallEngine {
    private let apt: AptClient
    private let dpkg: DpkgClient

    public init(apt: AptClient = AptClient(), dpkg: DpkgClient = DpkgClient()) {
        self.apt = apt; self.dpkg = dpkg
    }

    public func execute(_ txn: Transaction) -> AsyncStream<Transaction> {
        AsyncStream { continuation in
            Task {
                var current = txn
                current.startedAt = Date()
                current.attempts += 1
                continuation.yield(current)

                let stream: AsyncStream<InstallProgress>
                switch txn.kind {
                case .install: stream = await apt.install(txn.package.package)
                case .reinstall: stream = await apt.reinstall(txn.package.package)
                case .upgrade: stream = await apt.upgrade(txn.package.package)
                case .remove: stream = await apt.remove(txn.package.package)
                case .purge: stream = await apt.purge(txn.package.package)
                }

                var exitCode: Int32 = 0
                var stderr = ""
                var stage: InstallStage = .resolving
                for await progress in stream {
                    switch progress {
                    case .line(let line):
                        if let detected = detectStage(line) { stage = detected }
                        current.state = .installing(progress: 0.5, stage: stage)
                        continuation.yield(current)
                    case .finished(let code, let err):
                        exitCode = code; stderr = err
                    }
                }

                current.finishedAt = Date()
                if exitCode == 0 {
                    current.state = .completed
                } else if current.canRetry {
                    current.state = .queued
                } else {
                    current.state = .failed(error: stderr)
                }
                continuation.yield(current)
                continuation.finish()
            }
        }
    }

    private func detectStage(_ line: String) -> InstallStage? {
        if line.contains("Reading package lists") || line.contains("Building dependency tree") { return .resolving }
        if line.contains("Fetching") || line.contains("Get:") { return .fetching }
        if line.contains("Unpacking") { return .unpacking }
        if line.contains("Setting up") || line.contains("Configuring") { return .configuring }
        if line.contains("Removing") { return .removing }
        if line.contains("Processing triggers") { return .triggers }
        return nil
    }
}

