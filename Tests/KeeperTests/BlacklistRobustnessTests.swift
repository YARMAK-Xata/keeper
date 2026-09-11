import XCTest
@testable import Keeper

/// The parser is the one place in Keeper that reads text nobody vetted — pasted addresses,
/// a hand-edited preferences file, a list someone was sent. It never runs a shell, a query or a
/// regular expression, so there is nothing to inject into; what is left to prove is that it does
/// not hang, crash, or quietly accept nonsense as a rule.
final class BlacklistRobustnessTests: XCTestCase {
    private static let hostile: [(String, String)] = [
        ("empty", ""),
        ("blank", "     \t  "),
        ("dots only", String(repeating: ".", count: 5_000)),
        ("enormous host", String(repeating: "a", count: 200_000) + ".com"),
        ("enormous path", "a.com" + String(repeating: "/x", count: 50_000)),
        ("trailing slashes", "a.com" + String(repeating: "/", count: 50_000)),
        ("scheme only", "https://"),
        ("scheme and slashes", "https://///////"),
        ("port junk", "a.com:::::99999"),
        ("percent signs", "%%%%%.com"),
        ("control characters", "a.com\u{0}\u{1}\u{7}evil"),
        ("right-to-left override", "a.com\u{202E}moc.live"),
        ("zero width joiners", "a\u{200D}.\u{200B}com"),
        ("combining marks", "a\u{0301}\u{0301}\u{0301}.com"),
        ("emoji", "🐴🐴🐴.com"),
        ("query and fragment", "a.com/x?y=1#z"),
        ("comment", "# not a rule"),
        ("just a colon", ":"),
        ("just a slash", "/"),
    ]

    /// Nothing here may hang or trap. A rule that comes back must round-trip to itself, because
    /// the canonical form is what gets written to disk and parsed again on the next launch.
    func testPathologicalLinesAreParsedOrRejectedButNeverCrash() {
        for (name, line) in Self.hostile {
            guard let rule = BlacklistRule(line: line) else { continue }
            XCTAssertFalse(rule.host.isEmpty, "\(name) produced a rule with no host")
            let reparsed = BlacklistRule(line: rule.canonical)
            XCTAssertEqual(reparsed?.canonical, rule.canonical,
                           "\(name) does not survive a round trip through its canonical form")
        }
    }

    /// Linear work only: no regular expressions, so no input can make this quadratic. A rule two
    /// hundred thousand characters long is parsed and matched well inside a second.
    func testHostileInputIsParsedInLinearTime() {
        let started = Date()
        for (_, line) in Self.hostile {
            let list = SiteList(text: line)
            let blacklist = list.blacklist
            _ = blacklist.matches(URL(string: "https://example.com/path")!)
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 2.0,
                          "parsing hostile input took long enough to be a denial of service")
    }

    /// A line that names no host must be dropped rather than becoming a rule that matches
    /// everything — the failure that would silently close every tab in the browser.
    func testNothingBecomesARuleThatMatchesUnrelatedPages() {
        let innocent = [URL(string: "https://example.com/")!,
                        URL(string: "https://bank.example.org/account")!,
                        URL(string: "http://localhost:8080/")!]
        for (name, line) in Self.hostile {
            let blacklist = SiteList(text: line).blacklist
            for url in innocent {
                XCTAssertNil(blacklist.matches(url),
                             "\(name) produced a rule that matches \(url), which it has nothing to do with")
            }
        }
    }

    /// A bare word matches any label of a host, which is the documented behaviour — and the one
    /// rule shape broad enough to be worth pinning down, so it cannot widen by accident.
    func testBareWordMatchesALabelAndNotASubstring() {
        let rule = BlacklistRule(line: "reddit")
        XCTAssertNotNil(rule)
        XCTAssertTrue(rule!.matches(host: "www.reddit.com", path: "/"))
        XCTAssertTrue(rule!.matches(host: "old.reddit.com", path: "/"))
        XCTAssertFalse(rule!.matches(host: "notreddit.com", path: "/"),
                       "a bare word must match a whole label, never a substring of one")
        XCTAssertFalse(rule!.matches(host: "reddit-mirror.com", path: "/"))
    }
}
