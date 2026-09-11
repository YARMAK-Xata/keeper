import XCTest
@testable import Keeper

/// The Accessibility alert is a one-shot: `AXIsProcessTrustedWithOptions` puts it in front of the
/// person the first time and never again. Everything here exists so the one button on that screen
/// cannot become the thing that does nothing.
final class PermissionStepTests: XCTestCase {
    func testTheFirstPressAsksTheSystemForTheAlert() {
        XCTAssertEqual(PermissionStep.current(alertShown: false), .requestTrust)
    }

    /// The bug this prevents: the alert is spent, the button still says "Continue", and pressing
    /// it produces nothing at all — no alert, no window, no explanation. The screen used to carry
    /// a separate link for this case, which is how one button came to have a dead twin beside it.
    func testOnceTheAlertIsSpentThePressOpensSystemSettingsInstead() {
        XCTAssertEqual(PermissionStep.current(alertShown: true), .openSettings)
    }

    func testTheButtonSaysWhichOfTheTwoItWillDo() {
        XCTAssertNotEqual(PermissionStep.requestTrust.label, PermissionStep.openSettings.label)
        XCTAssertFalse(PermissionStep.requestTrust.label.isEmpty)
        XCTAssertFalse(PermissionStep.openSettings.label.isEmpty)
    }

    /// Both labels are real entries rather than a key echoed back, in every language Keeper speaks.
    func testBothLabelsAreTranslatedEverywhere() throws {
        for step in [PermissionStep.requestTrust, .openSettings] {
            XCTAssertFalse(step.label.contains("permission."), "\(step) fell back to its key: \(step.label)")
        }
    }
}
