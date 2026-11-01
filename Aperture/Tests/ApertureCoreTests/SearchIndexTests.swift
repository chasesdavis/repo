import XCTest
@testable import ApertureCore

final class SearchIndexTests: XCTestCase {
    func testInsertAndSearch() throws {
        let idx = try SearchIndex(path: ":memory:")
        let pkg = AperturePackage(
            id: "r::p::1", package: "p", name: "Package One", version: "1",
            architecture: "arm", section: "Tweaks", repoID: "r", repoURL: "https://x/./Release",
            maintainer: nil, author: "Author", descriptionText: "A test package", homepage: nil,
            depends: [], conflicts: [], provides: [], replaces: [],
            filename: "./p.deb", size: 0, md5sum: nil, sha256: nil,
            depiction: nil, sileoDepiction: nil, tags: [],
            iconURL: nil, screenshotURLs: [], changelog: nil
        )
        try idx.replaceRepo([pkg], repoID: "r")
        let hits = try idx.search("package", limit: 10)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.package, "p")
    }

    func testPrefixSearch() throws {
        let idx = try SearchIndex(path: ":memory:")
        let pkgs = (1...5).map { i in
            AperturePackage(
                id: "r::p\(i)::1", package: "pkg\(i)", name: "Name \(i)", version: "1",
                architecture: "arm", section: nil, repoID: "r", repoURL: "https://x/./Release",
                maintainer: nil, author: nil, descriptionText: "desc", homepage: nil,
                depends: [], conflicts: [], provides: [], replaces: [],
                filename: "", size: 0, md5sum: nil, sha256: nil,
                depiction: nil, sileoDepiction: nil, tags: [],
                iconURL: nil, screenshotURLs: [], changelog: nil
            )
        }
        try idx.replaceRepo(pkgs, repoID: "r")
        let hits = try idx.search("pkg", limit: 10)
        XCTAssertEqual(hits.count, 5)
    }

    func testClearRepo() throws {
        let idx = try SearchIndex(path: ":memory:")
        let pkg = AperturePackage(
            id: "r::p::1", package: "p", name: "P", version: "1",
            architecture: "arm", section: nil, repoID: "r", repoURL: "https://x/./Release",
            maintainer: nil, author: nil, descriptionText: "d", homepage: nil,
            depends: [], conflicts: [], provides: [], replaces: [],
            filename: "", size: 0, md5sum: nil, sha256: nil,
            depiction: nil, sileoDepiction: nil, tags: [],
            iconURL: nil, screenshotURLs: [], changelog: nil
        )
        try idx.replaceRepo([pkg], repoID: "r")
        try idx.clearRepo("r")
        let hits = try idx.search("P", limit: 10)
        XCTAssertEqual(hits.count, 0)
    }
}

