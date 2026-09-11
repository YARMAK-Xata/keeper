import XCTest
@testable import Keeper

/// Keeper is used from the menu bar shield and nowhere else, so the shield is not optional any
/// more. The Dock icon still is: turning it off leaves the app fully usable, which is what makes
/// it a setting rather than a way to lock yourself out.
final class PresenceTests: XCTestCase {
    private func scratchDefaults(_ name: String = #function) -> UserDefaults {
        let suite = "dev.keeper.tests.presence.\(name)"
        UserDefaults().removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite)!
    }

    func testTheShieldIsAlwaysInTheMenuBar() {
        XCTAssertTrue(Presence(dock: true).menuBar)
        XCTAssertTrue(Presence(dock: false).menuBar, "with no Dock icon the shield is the only way in")
    }

    func testBothVisibleByDefault() {
        XCTAssertEqual(Presence.default, Presence(dock: true))
        XCTAssertTrue(Presence.default.menuBar)
    }

    func testTheDockIconCanBeTurnedOffAndBackOn() {
        let defaults = scratchDefaults()
        Presence(dock: false).save(to: defaults)
        XCTAssertEqual(Presence(defaults: defaults), Presence(dock: false))
        Presence(dock: true).save(to: defaults)
        XCTAssertEqual(Presence(defaults: defaults), Presence(dock: true))
    }

    func testNothingStoredMeansBothVisible() {
        XCTAssertEqual(Presence(defaults: scratchDefaults()), Presence.default)
    }

    /// 1.9 and earlier could switch the shield off and leave the window doing the work. The
    /// window does not do the work any more, so that stored setting would be a Keeper with no
    /// usable surface at all. It has to be ignored on the way in.
    func testAShieldHiddenByAnOlderBuildComesBack() {
        let defaults = scratchDefaults()
        defaults.set(false, forKey: "showInMenuBar")
        XCTAssertTrue(Presence(defaults: defaults).menuBar)
    }

    /// And cleared on the way out, so `defaults read` stops describing a switch that is gone.
    func testSavingRetiresTheOldShieldKey() {
        let defaults = scratchDefaults()
        defaults.set(false, forKey: "showInMenuBar")
        Presence(dock: true).save(to: defaults)
        XCTAssertNil(defaults.object(forKey: "showInMenuBar"))
    }
}
