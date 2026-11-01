import Foundation

/// Snapshot of an installed package from dpkg -l / /var/lib/dpkg/status.
public struct InstalledRecord: Hashable, Sendable {
    public let package: String
    public let version: String
    public let architecture: String
    public let status: DpkgStatus
    public let installedSize: Int64  // KB per dpkg convention
    public let shortDescription: String

    public init(package: String, version: String, architecture: String,
                status: DpkgStatus, installedSize: Int64, shortDescription: String) {
        self.package = package; self.version = version; self.architecture = architecture
        self.status = status; self.installedSize = installedSize; self.shortDescription = shortDescription
    }
}

public enum DpkgStatus: String, Sendable {
    public var display: String {
        switch self {
        case .installed: return "Installed"
        case .halfConfigured: return "Half-configured"
        case .unpacked: return "Unpacked"
        case .halfInstalled: return "Half-installed"
        case .configFiles: return "Config files"
        case .notInstalled: return "Not installed"
        case .unknown: return "Unknown"
        }
    }
    case installed = "install ok installed"
    case halfConfigured = "install ok half-configured"
    case unpacked = "install ok unpacked"
    case halfInstalled = "install ok half-installed"
    case configFiles = "deinstall ok config-files"
    case notInstalled = "deinstall ok not-installed"
    case unknown = "unknown ok unknown"
    public init(rawStatus: String, rawWanted: String, rawError: String) {
        let key = "\(rawWanted) \(rawError) \(rawStatus)"
        self = DpkgStatus(rawValue: key) ?? .unknown
    }
}

public enum DownloadState: Hashable, Sendable {
    case pending
    case downloading(progress: Double)
    case completed(localPath: String)
    case failed(error: String)
    case cancelled
}

public enum InstallState: Hashable, Sendable {
    case queued
    case downloading(DownloadState)
    case installing(progress: Double, stage: InstallStage)
    case completed
    case failed(error: String)
    case cancelled
}

public enum InstallStage: String, Hashable, Sendable {
    case resolving = "Resolving dependencies"
    case fetching = "Fetching packages"
    case unpacking = "Unpacking"
    case configuring = "Configuring"
    case removing = "Removing"
    case triggers = "Processing triggers"
    case finishing = "Finishing"
}

public enum TransactionKind: String, Sendable {
    case install, reinstall, upgrade, remove, purge
}
