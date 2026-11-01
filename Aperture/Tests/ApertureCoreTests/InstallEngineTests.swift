import XCTest
@testable import ApertureCore

final class InstallEngineTests: XCTestCase {
    func testTransactionInitialState() {
        let pkg = AperturePackage(
            id: "r::p::1", package: "p", name: "P", version: "1",
            architecture: "arm", section: nil, repoID: "r", repoURL: "https://x/./Release",
            maintainer: nil, author: nil, descriptionText: "d", homepage: nil,
            depends: [], conflicts: [], provides: [], replaces: [],
            filename: "", size: 0, md5sum: nil, sha256: nil,
            depiction: nil, sileoDepiction: nil, tags: [],
            iconURL: nil, screenshotURLs: [], changelog: nil
        )
        let txn = Transaction(kind: .install, package: pkg)
        XCTAssertEqual(txn.state, .queued)
        XCTAssertEqual(txn.attempts, 0)
        XCTAssertTrue(txn.canRetry)
    }

    func testTransactionMaxAttempts() {
        let pkg = AperturePackage(
            id: "r::p::1", package: "p", name: "P", version: "1",
            architecture: "arm", section: nil, repoID: "r", repoURL: "https://x/./Release",
            maintainer: nil, author: nil, descriptionText: "d", homepage: nil,
            depends: [], conflicts: [], provides: [], replaces: [],
            filename: "", size: 0, md5sum: nil, sha256: nil,
            depiction: nil, sileoDepiction: nil, tags: [],
            iconURL: nil, screenshotURLs: [], changelog: nil
        )
        let txn = Transaction(kind: .install, package: pkg, attempts: 5, maxAttempts: 3)
        XCTAssertFalse(txn.canRetry)
    }
}

