import XCTest
@testable import ApertureCore

final class ReleaseParserTests: XCTestCase {
    func testParsesRelease() throws {
        let text = "Origin: Example Repo\nLabel: Example\nSuite: stable\nVersion: 1.0\nCodename: ios\nArchitectures: iphoneos-arm iphoneos-arm64\nComponents: main\nDate: Sat, 01 Jan 2025 00:00:00 UTC"
        let parser = ReleaseParser()
        let release = try XCTUnwrap(parser.parse(text))
        XCTAssertEqual(release.origin, "Example Repo")
        XCTAssertEqual(release.suite, "stable")
        XCTAssertEqual(release.version, "1.0")
        XCTAssertEqual(release.codename, "ios")
        XCTAssertEqual(release.archs, ["iphoneos-arm", "iphoneos-arm64"])
        XCTAssertEqual(release.components, ["main"])
    }

    func testMissingRequiredFieldsReturnsNil() {
        let text = "Origin: Only\nLabel: x\n"
        XCTAssertNil(ReleaseParser().parse(text))
    }
}
