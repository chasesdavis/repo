import Foundation

/// A single install/upgrade/remove operation moving through the queue.
public struct Transaction: Identifiable, Sendable {
    public let id: UUID
    public let kind: TransactionKind
    public let package: AperturePackage
    public var state: InstallState
    public var startedAt: Date?
    public var finishedAt: Date?
    public var attempts: Int
    public let maxAttempts: Int

    public init(
        id: UUID = UUID(), kind: TransactionKind, package: AperturePackage,
        state: InstallState = .queued, startedAt: Date? = nil,
        finishedAt: Date? = nil, attempts: Int = 0, maxAttempts: Int = 3
    ) {
        self.id = id; self.kind = kind; self.package = package
        self.state = state; self.startedAt = startedAt
        self.finishedAt = finishedAt; self.attempts = attempts
        self.maxAttempts = maxAttempts
    }

    public var canRetry: Bool { attempts < maxAttempts }
}

