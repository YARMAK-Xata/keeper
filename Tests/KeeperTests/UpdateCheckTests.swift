import XCTest
@testable import Keeper

/// Comparing versions is the part that fails quietly. A string comparison puts 1.10 before 1.9
/// and nobody notices until the tenth release, so it is a pure function with its own tests.
final class VersionTests: XCTestCase {
    func testANewerVersionIsNewer() {
        XCTAssertTrue(UpdateCheck.isNewer("1.9", than: "1.8"))
        XCTAssertTrue(UpdateCheck.isNewer("2.0", than: "1.9"))
        XCTAssertTrue(UpdateCheck.isNewer("1.8.1", than: "1.8"))
    }

    /// The one a string comparison gets wrong: "1.10" sorts before "1.9" as text.
    func testDoubleDigitsCompareAsNumbers() {
        XCTAssertTrue(UpdateCheck.isNewer("1.10", than: "1.9"))
        XCTAssertFalse(UpdateCheck.isNewer("1.9", than: "1.10"))
        XCTAssertTrue(UpdateCheck.isNewer("1.21", than: "1.3"))
    }

    func testTheSameVersionIsNotAnUpdate() {
        XCTAssertFalse(UpdateCheck.isNewer("1.8", than: "1.8"))
        XCTAssertFalse(UpdateCheck.isNewer("1.8.0", than: "1.8"), "trailing zeroes are the same version")
        XCTAssertFalse(UpdateCheck.isNewer("1.8", than: "1.8.0"))
    }

    func testAnOlderVersionIsNotAnUpdate() {
        XCTAssertFalse(UpdateCheck.isNewer("1.7", than: "1.8"))
        XCTAssertFalse(UpdateCheck.isNewer("0.9", than: "1.0"))
    }

    /// Releases are tagged v1.8 and the bundle says 1.8. They are the same version.
    func testTheTagPrefixIsIgnored() {
        XCTAssertFalse(UpdateCheck.isNewer("v1.8", than: "1.8"))
        XCTAssertTrue(UpdateCheck.isNewer("v1.9", than: "1.8"))
        XCTAssertTrue(UpdateCheck.isNewer("V1.9", than: "v1.8"))
    }

    /// Anything unparseable must read as "no update". A checker that nags because someone typed
    /// a tag by hand is worse than one that stays quiet.
    func testNonsenseIsNeverAnUpdate() {
        XCTAssertFalse(UpdateCheck.isNewer("", than: "1.8"))
        XCTAssertFalse(UpdateCheck.isNewer("latest", than: "1.8"))
        XCTAssertFalse(UpdateCheck.isNewer("1.8-beta", than: "1.8"))
        XCTAssertFalse(UpdateCheck.isNewer("1.9", than: ""))
    }
}

/// Reading GitHub's answer. The app must take only the two fields it needs and ignore a payload
/// that is a hundred times larger, and must not fall over on a shape it did not expect.
final class ReleaseParsingTests: XCTestCase {
    private func json(_ body: String) -> Data { Data(body.utf8) }

    func testReadsTheTagAndThePage() throws {
        let data = json("""
        {"tag_name": "v1.9", "html_url": "https://github.com/YARMAK-Xata/keeper/releases/tag/v1.9",
         "name": "Keeper 1.9", "body": "notes", "draft": false, "prerelease": false}
        """)
        let release = try XCTUnwrap(UpdateCheck.release(from: data))
        XCTAssertEqual(release.version, "v1.9", "the tag is kept exactly as published")
        XCTAssertEqual(release.displayVersion, "1.9", "and shown the way the app numbers itself")
        XCTAssertEqual(release.page.absoluteString,
                       "https://github.com/YARMAK-Xata/keeper/releases/tag/v1.9")
    }

    func testADraftOrPrereleaseIsNotOffered() {
        let draft = json("""
        {"tag_name": "v2.0", "html_url": "https://example.com/x", "draft": true, "prerelease": false}
        """)
        let pre = json("""
        {"tag_name": "v2.0", "html_url": "https://example.com/x", "draft": false, "prerelease": true}
        """)
        XCTAssertNil(UpdateCheck.release(from: draft), "a draft is not published")
        XCTAssertNil(UpdateCheck.release(from: pre), "a prerelease is not for everyone")
    }

    func testSomethingElseEntirelyIsIgnored() {
        XCTAssertNil(UpdateCheck.release(from: json("not json at all")))
        XCTAssertNil(UpdateCheck.release(from: json("{}")))
        XCTAssertNil(UpdateCheck.release(from: json("[]")))
        XCTAssertNil(UpdateCheck.release(from: json(#"{"tag_name": "v1.9"}"#)), "no page to send them to")
        XCTAssertNil(UpdateCheck.release(from: Data()))
    }

    /// GitHub's own page, and nothing else. A payload naming some other host must not become a
    /// link the app will open — that is the one way a check like this could hurt someone.
    func testOnlyGitHubPagesAreAccepted() {
        let elsewhere = json("""
        {"tag_name": "v9.0", "html_url": "https://example.com/pwn", "draft": false, "prerelease": false}
        """)
        XCTAssertNil(UpdateCheck.release(from: elsewhere))
    }
}
