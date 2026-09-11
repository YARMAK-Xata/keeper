import XCTest
@testable import Keeper

final class SiteListTests: XCTestCase {
    func testNormalizesEntriesAndDropsDuplicates() {
        let list = SiteList(text: "https://www.YouTube.com/\nyoutube.com\nreddit.com/r/funny/\n\n#note\n")
        XCTAssertEqual(list.entries, ["youtube.com", "reddit.com/r/funny"])
    }

    func testAddRejectsJunkAndRepeats() {
        var list = SiteList(text: "")
        XCTAssertTrue(list.add("YouTube.com"))
        XCTAssertFalse(list.add("youtube.com"), "already listed")
        XCTAssertFalse(list.add("   "), "nothing to add")
        XCTAssertFalse(list.add("/just/a/path"), "no host")
        XCTAssertEqual(list.entries, ["youtube.com"])
    }

    /// A pasted page address means the whole site; typed text is taken at its word.
    func testPastedURLBlocksTheWholeSiteButTypedPathsSurvive() {
        var list = SiteList(text: "")
        list.add("https://www.youtube.com/watch?v=QeGPiu74jKg")
        XCTAssertEqual(list.entries, ["youtube.com"])
        XCTAssertFalse(list.add("https://youtube.com/feed/subscriptions"), "same site again")

        list.add("reddit.com/r/funny")
        XCTAssertEqual(list.entries, ["youtube.com", "reddit.com/r/funny"])
        XCTAssertNil(list.blacklist.matches(URL(string: "https://reddit.com/r/swift")!))
    }

    func testRemoveAndRoundTripThroughText() {
        var list = SiteList(text: "youtube.com\nreddit.com\ntwitch.tv")
        list.remove("reddit.com")
        XCTAssertEqual(list.text, "youtube.com\ntwitch.tv")
        XCTAssertEqual(SiteList(text: list.text), list)
    }

    func testBlacklistMatchesWhatTheListHolds() {
        let list = SiteList(text: "youtube.com\nreddit.com/r/funny")
        let blacklist = list.blacklist
        XCTAssertNotNil(blacklist.matches(URL(string: "https://m.youtube.com/feed")!))
        XCTAssertNotNil(blacklist.matches(URL(string: "https://reddit.com/r/funny/top")!))
        XCTAssertNil(blacklist.matches(URL(string: "https://reddit.com/r/swift")!))
    }

    func testUsedPresetsDisappearFromQuickAdd() {
        var list = SiteList(text: "")
        XCTAssertEqual(list.unusedPresets.count, SitePreset.all.count)
        list.add("youtube.com")
        XCTAssertFalse(list.unusedPresets.contains { $0.rule == "youtube.com" })
        XCTAssertEqual(list.unusedPresets.count, SitePreset.all.count - 1)
    }

    func testEveryPresetIsAValidRule() {
        for preset in SitePreset.all {
            XCTAssertNotNil(BlacklistRule(line: preset.rule), "\(preset.label) is not parseable")
            XCTAssertFalse(preset.label.isEmpty)
        }
    }
}
