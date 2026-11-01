import Foundation

/// Serial install queue. One transaction runs at a time; others wait.
/// Failed transactions stay in queue with .failed state for retry/inspection.
public actor InstallQueue {
    private var pending: [Transaction] = []
    private var running: Transaction?
    private var history: [Transaction] = []
    private let engine: InstallEngine
    private var isProcessing = false
    private var listeners: [UUID: AsyncStream<QueueEvent>.Continuation] = [:]

    public init(engine: InstallEngine = InstallEngine()) { self.engine = engine }

    public enum QueueEvent: Sendable {
        case enqueued(Transaction)
        case updated(Transaction)
        case dequeued(Transaction)
        case queueChanged([Transaction])
    }

    public func enqueue(_ txn: Transaction) {
        pending.append(txn)
        emit(.enqueued(txn)); emit(.queueChanged(all()))
        startProcessingIfNeeded()
    }

    public func cancel(id: UUID) {
        if let idx = pending.firstIndex(where: { $0.id == id }) {
            var t = pending.remove(at: idx); t.state = .cancelled; t.finishedAt = Date()
            history.append(t); emit(.dequeued(t)); emit(.queueChanged(all()))
        }
    }

    public func retry(id: UUID) {
        guard let idx = history.firstIndex(where: { $0.id == id && $0.canRetry }) else { return }
        var t = history.remove(at: idx); t.state = .queued; t.attempts = 0
        pending.append(t); emit(.enqueued(t)); emit(.queueChanged(all()))
        startProcessingIfNeeded()
    }

    public func all() -> [Transaction] { (running.map { [$0] } ?? []) + pending + history.suffix(20) }

    public func events() -> AsyncStream<QueueEvent> {
        AsyncStream { continuation in
            let token = UUID()
            listeners[token] = continuation
            continuation.onTermination = { [weak self] _ in Task { await self?.remove(token) } }
        }
    }

    private func remove(_ token: UUID) { listeners.removeValue(forKey: token) }
    private func emit(_ event: QueueEvent) { for c in listeners.values { c.yield(event) } }

    private func startProcessingIfNeeded() {
        guard !isProcessing, running == nil, !pending.isEmpty else { return }
        isProcessing = true
        var txn = pending.removeFirst()
        running = txn
        emit(.updated(txn)); emit(.queueChanged(all()))
        Task {
            for await updated in await engine.execute(txn) {
                txn = updated
                running = txn
                emit(.updated(txn)); emit(.queueChanged(all()))
            }
            history.append(txn)
            running = nil
            isProcessing = false
            emit(.dequeued(txn)); emit(.queueChanged(all()))
            await startProcessingIfNeeded()
        }
    }
}

