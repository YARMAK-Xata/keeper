import AppKit
import ApplicationServices

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
