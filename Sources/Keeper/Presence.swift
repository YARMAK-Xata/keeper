import Foundation

/// Where Keeper can be found: the menu bar shield, always, and the Dock icon if you want it.
///
/// The shield used to be a switch too, and the pair guarded each other — whichever was the last
/// one on refused to go, so the app could never hide completely. That guard existed because the
/// window was a second way to use Keeper. It is not any more: the lists, Start and Stop live
/// under the shield and the window only points at it. A Keeper with no shield would be a Keeper
/// with nothing to click, so the shield is no longer something you can switch off.
///
/// The Dock icon stays a switch, because turning it off costs you nothing.
struct Presence: Equatable {
    /// Always true. Kept as a property rather than dropped so the surfaces still read where
    /// Keeper lives from one place instead of hard-coding it.
    var menuBar: Bool { true }

    var dock: Bool

    static let `default` = Presence(dock: true)

    private static let dockKey = "showInDock"
    /// Written by 1.9 and earlier. Read by nothing.
    private static let retiredMenuBarKey = "showInMenuBar"

    init(dock: Bool) {
        self.dock = dock
    }

    // MARK: - Persistence

    /// A stored `showInMenuBar = false` is simply not consulted: an older build could leave one
    /// behind, and honouring it now would launch a Keeper with no usable surface at all.
    init(defaults: UserDefaults = .standard) {
        self.init(dock: defaults.object(forKey: Self.dockKey) as? Bool ?? true)
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(dock, forKey: Self.dockKey)
        // Clear the retired key rather than leave it lying in the domain, where `defaults read`
        // would go on describing a switch nobody can find.
        defaults.removeObject(forKey: Self.retiredMenuBarKey)
    }
}
