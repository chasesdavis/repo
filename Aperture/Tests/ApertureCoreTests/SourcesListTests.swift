import XCTest
@testable import ApertureCore

final class SourcesListTests: XCTestCase {
    func testParsesSimpleDebLine() {
        let list = SourcesList()
        let entries = list.parse("deb https://example.com/ ./ main\ndeb https://other.com/ stable main contrib")
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].url, "https://example.com/")
        XCTAssertEqual(entries[0].suite, "./")
        XCTAssertEqual(entries[0].components, ["main"])
        XCTAssertEqual(entries[1].suite, "stable")
        XCTAssertEqual(entries[1].components, ["main", "contrib"])
    }

    func testParsesArchOptions() {
        let list = SourcesList()
        let entries = list.parse("deb [arch=iphoneos-arm64] https://example.com/ stable main")
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].archs, ["iphoneos-arm64"])
    }

    func testIgnoresCommentsAndBlanks() {
        let list = SourcesList()
        let entries = list.parse("# comment\n\ndeb https://x/ ./\n")
        XCTAssertEqual(entries.count, 1)
    }

    func testMalformedReturnsNil() {
        let list = SourcesList()
        let entries = list.parse("not a deb line\ndeb\n")
        XCTAssertEqual(entries.count, 0)
    }
}
