import XCTest
@testable import Keeper

/// The apps list is the sites list with a different kind of entry, so it gets the same battery:
/// it must normalise, de-duplicate, survive a round trip through the text it is stored as, and
/// refuse the three applications that would lock somebody out of their own Mac.
final class AppListTests: XCTestCase {
    func testParsesOneIdentifierPerLineAndIgnoresJunk() {
        let list = AppList(text: """
        com.hnc.Discord

          ru.keepcoder.Telegram
        # a comment
        com.spotify.client
        """)
        XCTAssertEqual(list.entries.map(\.bundleID),
                       ["com.hnc.Discord", "ru.keepcoder.Telegram", "com.spotify.client"])
    }

    func testDropsDuplicatesRegardlessOfCase() {
        var list = AppList(text: "com.hnc.Discord\nCOM.HNC.DISCORD")
        XCTAssertEqual(list.count, 1)
        XCTAssertFalse(list.add("com.hnc.discord"), "the same app in another case is the same app")
        XCTAssertEqual(list.count, 1)
    }

    func testRoundTripsThroughItsStoredText() {
        let original = AppList(text: "com.hnc.Discord\ncom.spotify.client")
        XCTAssertEqual(AppList(text: original.text).entries, original.entries)
    }

    func testAddAndRemove() {
        var list = AppList(text: "")
        XCTAssertTrue(list.add("com.hnc.Discord"))
        XCTAssertTrue(list.add("com.spotify.client"))
        XCTAssertEqual(list.count, 2)
        XCTAssertTrue(list.contains("com.hnc.Discord"))

        list.remove("com.hnc.Discord")
        XCTAssertEqual(list.entries.map(\.bundleID), ["com.spotify.client"])
        XCTAssertFalse(list.contains("com.hnc.Discord"))
    }

    func testEmptyAndWhitespaceAreNotApps() {
        XCTAssertTrue(AppList(text: "   \n\t\n").isEmpty)
        var list = AppList(text: "")
        XCTAssertFalse(list.add("   "))
        XCTAssertFalse(list.add(""))
        XCTAssertTrue(list.isEmpty)
    }

    // MARK: - The floor under the feature

    func testRefusesTheThreeApplicationsThatWouldLockYouOut() {
        for identifier in ["com.apple.systempreferences", "com.apple.finder", "dev.keeper.Keeper"] {
            var list = AppList(text: "")
            XCTAssertFalse(list.add(identifier), "\(identifier) must never be addable")
            XCTAssertTrue(list.isEmpty, "a refused app must leave the list untouched")
            XCTAssertNotNil(AppList.refusal(for: identifier),
                            "\(identifier) must come with a reason to show the person")
        }
    }

    func testRefusalIsCaseInsensitiveAndSurvivesAHandEditedFile() {
        var list = AppList(text: "")
        XCTAssertFalse(list.add("COM.APPLE.FINDER"))

        // Written straight into the preferences by hand, or by an older build.
        let smuggled = AppList(text: "com.hnc.Discord\ncom.apple.finder\ndev.keeper.Keeper")
        XCTAssertEqual(smuggled.entries.map(\.bundleID), ["com.hnc.Discord"],
                       "a refused app must be dropped on the way in, not just at the chooser")
    }

    func testOrdinaryAppsAreNotRefused() {
        for identifier in ["com.hnc.Discord", "com.apple.Safari", "com.apple.MobileSMS"] {
            XCTAssertNil(AppList.refusal(for: identifier), "\(identifier) is a normal app")
        }
    }

    // MARK: - The name drawn when the app is gone

    /// An app that has been uninstalled still has a row. Showing a raw identifier is honest but
    /// unreadable; the last component is what a person recognises.
    func testFallbackNameIsTheLastComponentOfTheIdentifier() {
        XCTAssertEqual(AppRule(bundleID: "com.hnc.Discord").fallbackName, "Discord")
        XCTAssertEqual(AppRule(bundleID: "com.spotify.client").fallbackName, "client")
        XCTAssertEqual(AppRule(bundleID: "Discord").fallbackName, "Discord")
    }
}
