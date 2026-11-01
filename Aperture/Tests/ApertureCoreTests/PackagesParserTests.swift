import XCTest
@testable import ApertureCore

final class PackagesParserTests: XCTestCase {
    func testParsesPlainPackages() throws {
        let text = "Package: com.example.foo\nName: Foo Tweak\nVersion: 1.0.0\nArchitecture: iphoneos-arm\nSection: Tweaks\nMaintainer: Chase <chase@example.com>\nDescription: A test tweak\n with continuation line\nDepends: mobilesubstrate, firmware (>= 15.0)\nFilename: ./debs/foo_1.0.0_iphoneos-arm.deb\nSize: 12345\nMD5sum: abcdef1234567890\nSHA256: 1111222233334444\nIcon: https://example.com/icon.png\nTag: role::developer, purpose::test\n"
        let parser = PackagesParser()
        let pkgs = parser.parseText(text, repoID: "repo1", repoURL: "https://example.com/./Release")
        XCTAssertEqual(pkgs.count, 1)
        let p = try XCTUnwrap(pkgs.first)
        XCTAssertEqual(p.package, "com.example.foo")
        XCTAssertEqual(p.name, "Foo Tweak")
        XCTAssertEqual(p.version, "1.0.0")
        XCTAssertEqual(p.architecture, "iphoneos-arm")
        XCTAssertEqual(p.section, "Tweaks")
        XCTAssertEqual(p.depends, ["mobilesubstrate", "firmware (>= 15.0)"])
        XCTAssertEqual(p.filename, "./debs/foo_1.0.0_iphoneos-arm.deb")
        XCTAssertEqual(p.size, 12345)
        XCTAssertEqual(p.iconURL, "https://example.com/icon.png")
        XCTAssertTrue(p.tags.contains("role::developer"))
        XCTAssertTrue(p.descriptionText.contains("continuation line"))
    }

    func testHandlesMalformedGracefully() {
        let text = "Package: broken\nVersion: \nGarbageLineWithoutColon\n\n"
        let parser = PackagesParser()
        let pkgs = parser.parseText(text, repoID: "r", repoURL: "https://x/./Release")
        XCTAssertEqual(pkgs.count, 0)
    }

    func testMultiplePackages() {
        let text = "Package: a\nVersion: 1\n\nPackage: b\nVersion: 2\n\n"
        let pkgs = PackagesParser().parseText(text, repoID: "r", repoURL: "https://x/./Release")
        XCTAssertEqual(pkgs.count, 2)
        XCTAssertEqual(pkgs[0].package, "a")
        XCTAssertEqual(pkgs[1].package, "b")
    }
}
