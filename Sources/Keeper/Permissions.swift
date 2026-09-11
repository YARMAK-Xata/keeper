import AppKit
import ApplicationServices

/// What the one button on the permission screen does when it is pressed.
///
/// The Accessibility alert is a one-shot: `AXIsProcessTrustedWithOptions` shows it the first time
/// and never again, however often it is called. So a button that always meant "show the alert"
/// would be dead from the second press onwards.
///
/// The screen used to answer that by growing a second control — a link to System Settings that
/// appeared once the alert had been spent — which left two blue things about one permission
/// stacked on top of each other, the prominent one being the one that no longer did anything.
/// There is one control now, and this is what it means.
enum PermissionStep: Equatable {
    /// Nothing has been asked yet. The system alert is still available, and it is also what puts
    /// Keeper into the Accessibility list in the first place.
    case requestTrust
    /// The alert is spent. Pressing again has to go somewhere the person can actually act.
    case openSettings

    static func current(alertShown: Bool) -> PermissionStep {
        alertShown ? .openSettings : .requestTrust
    }

    var label: String {
        switch self {
        case .requestTrust: return L.t("permission.continue")
        case .openSettings: return L.t("permission.openSettings")
        }
    }

    /// Trust is requested either way. The call is what registers Keeper in the Accessibility
    /// list, and on the second and later presses that is all it does — so the pane is opened
    /// alongside it rather than instead of it.
    func take() {
        Permissions.requestTrust()
        if self == .openSettings { Permissions.openAccessibilitySettings() }
    }
}

enum Permissions {
    private static let requestedKey = "hasRequestedAccessibilityTrust"

    static var isTrusted: Bool {
        #if DEBUG
        // Lets a debug build show the Ready and On duty states without the system alert,
        // for screenshots and manual layout checks. Compiled out of the shipped app.
        if ProcessInfo.processInfo.environment["KEEPER_ASSUME_TRUSTED"] == "1" { return true }
        #endif
        return AXIsProcessTrusted()
    }

    /// True once the system alert has been put in front of the person. Until then, offering a
    /// shortcut to System Settings would be a second way to do the thing the button already does.
    static var hasRequestedTrust: Bool { UserDefaults.standard.bool(forKey: requestedKey) }

    /// Shows the system prompt that adds Keeper to the Accessibility list (the user still flips the switch).
    static func requestTrust() {
        UserDefaults.standard.set(true, forKey: requestedKey)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
