import Foundation
import ServiceManagement

/// Whether macOS opens Keeper when you log in. `SMAppService` registers the app itself,
/// so there is no helper bundle and nothing to install.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Set once, the first time this copy of Keeper runs, so that turning the login item off
    /// afterwards is not undone on the next launch.
    private static let decidedKey = "loginItemDecided"

    /// Registers Keeper to open at login, once, on a first run.
    ///
    /// On by default because of what Keeper is: it guards a session you started, and a guard that
    /// has to be remembered and launched by hand is one you will forget on the day it matters.
    /// It is a login item, not a background daemon — it appears in System Settings → General →
    /// Login Items like anything else, and removing it there or in Keeper's own Settings sticks,
    /// because this runs once and never argues with a decision you have made.
    static func enableOnFirstRun() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: decidedKey) else { return }
        defaults.set(true, forKey: decidedKey)
        setEnabled(true)
    }

    /// Failures are reported, never fatal: a login item that will not register is a preference
    /// that did not take, not a reason to stop the app.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("Keeper: could not %@ the login item: %@",
                  enabled ? "register" : "unregister", String(describing: error))
            return false
        }
    }
}
