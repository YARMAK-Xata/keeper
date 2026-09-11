import Foundation

/// Where Keeper can be found: the menu bar shield, the Dock icon, or both.
///
/// Both off would leave the app running with nothing to click — no panel, no window, no Quit.
/// So the last one standing refuses to go and the switch springs back, which is the same answer
/// the login-item switch gives when the system turns it down: say no rather than lie.
struct Presence: Equatable {
    var menuBar: Bool
    var dock: Bool

    static let `default` = Presence(menuBar: true, dock: true)

    private static let menuBarKey = "showInMenuBar"
    private static let dockKey = "showInDock"

    func setting(menuBar: Bool) -> Presence {
        menuBar || dock ? Presence(menuBar: menuBar, dock: dock) : self
    }

    func setting(dock: Bool) -> Presence {
        dock || menuBar ? Presence(menuBar: menuBar, dock: dock) : self
    }

    /// Repairs a stored pair that says both are hidden — written by an older build, or by hand
    /// with `defaults write` — rather than launching a Keeper nobody can see.
    init(stored: Presence) {
        self = (stored.menuBar || stored.dock) ? stored : .default
    }

    init(menuBar: Bool, dock: Bool) {
        self.menuBar = menuBar
        self.dock = dock
    }

    // MARK: - Persistence

    init(defaults: UserDefaults = .standard) {
        self.init(stored: Presence(
            menuBar: defaults.object(forKey: Self.menuBarKey) as? Bool ?? true,
            dock: defaults.object(forKey: Self.dockKey) as? Bool ?? true
        ))
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(menuBar, forKey: Self.menuBarKey)
        defaults.set(dock, forKey: Self.dockKey)
    }
}
