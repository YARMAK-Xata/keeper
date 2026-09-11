import XCTest
@testable import Keeper

/// Keeper can be reached from the menu bar shield or from the Dock icon. Hiding both would leave
/// a running app with no way in and no way out, so the last one standing refuses to go.
final class PresenceTests: XCTestCase {
    func testBothVisibleByDefault() {
        XCTAssertEqual(Presence.default, Presence(menuBar: true, dock: true))
    }

    func testEitherOneCanBeHiddenWhileTheOtherRemains() {
        XCTAssertEqual(Presence.default.setting(menuBar: false), Presence(menuBar: false, dock: true))
        XCTAssertEqual(Presence.default.setting(dock: false), Presence(menuBar: true, dock: false))
    }

    func testHidingTheLastOneIsRefused() {
        let dockOnly = Presence(menuBar: false, dock: true)
        XCTAssertEqual(dockOnly.setting(dock: false), dockOnly, "hiding the Dock icon with no shield left must be refused")

        let shieldOnly = Presence(menuBar: true, dock: false)
        XCTAssertEqual(shieldOnly.setting(menuBar: false), shieldOnly, "hiding the shield with no Dock icon left must be refused")
    }

    func testTurningOneBackOnAlwaysWorks() {
        XCTAssertEqual(Presence(menuBar: false, dock: true).setting(menuBar: true), Presence.default)
        XCTAssertEqual(Presence(menuBar: true, dock: false).setting(dock: true), Presence.default)
    }

    /// Setting a switch to what it already is is not a change, and must not be read as one.
    func testSettingAValueItAlreadyHasIsANoOp() {
        XCTAssertEqual(Presence(menuBar: true, dock: false).setting(menuBar: true), Presence(menuBar: true, dock: false))
        XCTAssertEqual(Presence(menuBar: false, dock: true).setting(dock: true), Presence(menuBar: false, dock: true))
    }

    /// Defaults written by an older build, or by hand, can say both are off. The app has to
    /// come back from that rather than launch invisible.
    func testAnImpossibleStoredStateIsRepaired() {
        XCTAssertEqual(Presence(stored: Presence(menuBar: false, dock: false)), Presence.default)
        XCTAssertEqual(Presence(stored: Presence(menuBar: false, dock: true)), Presence(menuBar: false, dock: true))
    }
}
