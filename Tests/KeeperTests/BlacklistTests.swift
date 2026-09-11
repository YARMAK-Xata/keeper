import XCTest
@testable import Keeper

final class BlacklistTests: XCTestCase {
    func testParsesHostsIgnoringSchemeWwwCommentsAndBlankLines() {
        let b = Blacklist(text: "https://www.YouTube.com/\n\n# comment\nreddit.com/r/funny/\n")
        XCTAssertEqual(b.rules, [
            BlacklistRule(host: "youtube.com", pathPrefix: ""),
            BlacklistRule(host: "reddit.com", pathPrefix: "/r/funny"),
        ])
    }

    func testMatchesHostAndSubdomainsOnly() {
        let b = Blacklist(text: "youtube.com")
        XCTAssertNotNil(b.matches(URL(string: "https://www.youtube.com/watch?v=1")!))
        XCTAssertNotNil(b.matches(URL(string: "https://m.youtube.com/")!))
        XCTAssertNil(b.matches(URL(string: "https://youtube.com.evil.example/")!))
        XCTAssertNil(b.matches(URL(string: "https://notyoutube.com/")!))
    }

    func testPathPrefixRuleOnlyMatchesThatPath() {
        let b = Blacklist(text: "reddit.com/r/funny")
        XCTAssertNotNil(b.matches(URL(string: "https://www.reddit.com/r/funny/top")!))
        XCTAssertNotNil(b.matches(URL(string: "https://reddit.com/r/funny")!))
        XCTAssertNil(b.matches(URL(string: "https://reddit.com/r/programming")!))
        XCTAssertNil(b.matches(URL(string: "https://reddit.com/r/funnyfarm")!))
    }

    func testBareWordMatchesAnyHostLabel() {
        let b = Blacklist(text: "youtube")
        XCTAssertNotNil(b.matches(URL(string: "https://www.youtube.com/")!))
        XCTAssertNil(b.matches(URL(string: "https://youtubekids.com/")!))
    }

    func testEmptyAndJunkLinesProduceNoRules() {
        XCTAssertTrue(Blacklist(text: "  \n\n").isEmpty)
        XCTAssertTrue(Blacklist(text: "/nohost").isEmpty)
        XCTAssertNil(Blacklist(text: "youtube.com").matches(URL(string: "file:///tmp/x")!))
    }
}
