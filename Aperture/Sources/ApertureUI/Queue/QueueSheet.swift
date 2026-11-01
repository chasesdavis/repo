import SwiftUI
import ApertureCore

public struct QueueSheet: View {
    @EnvironmentObject private var vm: ApertureViewModel
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                if vm.queue.isEmpty {
                    EmptyState(icon: "tray.full", title: "Queue Empty", subtitle: "Installs and removals will appear here.")
                } else {
                    ForEach(vm.queue, id: \.id) { txn in
                        QueueRow(txn: txn, onCancel: { vm.cancelTransaction(txn.id) }, onRetry: { vm.retryTransaction(txn.id) })
                            .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
            #if os(iOS)
            .scrollContentBackground(.hidden)
            #endif
            .background(ApertureTheme.bgPrimary)
            .navigationTitle("Queue")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
                #else
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                #endif
            }
        }
    }
}

private struct QueueRow: View {
    let txn: ApertureCore.Transaction
    let onCancel: () -> Void
    let onRetry: () -> Void
    var body: some View {
        HStack(spacing: ApertureTheme.spacingMd) {
            iconForState
            VStack(alignment: .leading, spacing: 4) {
                Text(txn.package.name).font(.system(size: 16, weight: .semibold, design: .rounded))
                Text(txn.package.package).font(.system(size: 12, design: .monospaced)).foregroundStyle(ApertureTheme.textSecondary)
                Text(statusText).font(.caption).foregroundStyle(statusColor)
            }
            Spacer()
            if case .queued = txn.state {
                Button("Cancel", action: onCancel).font(.system(size: 14, weight: .semibold)).foregroundStyle(ApertureTheme.danger)
            } else if case .failed = txn.state {
                Button("Retry", action: onRetry).font(.system(size: 14, weight: .semibold)).foregroundStyle(ApertureTheme.accent)
            }
        }.padding(.vertical, ApertureTheme.spacingSm)
    }

    @ViewBuilder
    private var iconForState: some View {
        switch txn.state {
        case .queued:
            Image(systemName: "clock").foregroundStyle(ApertureTheme.textSecondary)
        case .installing:
            ProgressView().tint(ApertureTheme.accent)
        case .completed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(ApertureTheme.success)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(ApertureTheme.danger)
        case .cancelled:
            Image(systemName: "minus.circle").foregroundStyle(ApertureTheme.textSecondary)
        default:
            Image(systemName: "clock").foregroundStyle(ApertureTheme.textSecondary)
        }
    }

    private var statusText: String {
        switch txn.state {
        case .queued: return "Queued"
        case .installing(_, let stage): return stage.rawValue
        case .completed: return "Completed"
        case .failed(let err): return "Failed: \(err.prefix(120))"
        case .cancelled: return "Cancelled"
        default: return "Pending"
        }
    }

    private var statusColor: Color {
        switch txn.state {
        case .completed: return ApertureTheme.success
        case .failed: return ApertureTheme.danger
        case .cancelled: return ApertureTheme.textSecondary
        default: return ApertureTheme.textSecondary
        }
    }
}

