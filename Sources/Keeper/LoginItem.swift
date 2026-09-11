import Foundation
import ServiceManagement

/// Whether macOS opens Keeper when you log in. `SMAppService` registers the app itself,
/// so there is no helper bundle and nothing to install.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

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
