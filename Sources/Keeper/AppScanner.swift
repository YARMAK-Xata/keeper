import AppKit
import ApplicationServices

/// An application on the list that is on screen right now.
struct AppHit {
    let pid: pid_t
    let bundleID: String
    let name: String
}

/// What happened to an app the knight went after.
enum HideOutcome: Equatable {
    case hidden
    case alreadyGone
    case noWindows
    case failed
}

/// The cheap sibling of `BrowserScanner`. Finding a blocked app is a property read rather than an
/// accessibility tree walk, so it happens on the main actor inside the existing tick instead of
/// costing a background queue. Window frames are not read here — only when the knight is actually
/// dispatched at one — so a tick stays a few microseconds however long the list is.
@MainActor
enum AppScanner {
    static func hits(for list: AppList) -> [AppHit] {
        guard !list.isEmpty else { return [] }
        return NSWorkspace.shared.runningApplications.compactMap { app in
            guard app.activationPolicy == .regular,       // not a menu bar or background helper
                  !app.isTerminated,
                  !app.isHidden,                          // already out of the way; leave it alone
                  let bundleID = app.bundleIdentifier,
                  list.contains(bundleID) else { return nil }
            return AppHit(pid: app.processIdentifier, bundleID: bundleID,
                          name: app.localizedName ?? AppRule(bundleID: bundleID).fallbackName)
        }
    }

    /// Where the knight should stand: the app's frontmost window, in accessibility coordinates.
    static func windowFrame(of hit: AppHit) -> CGRect? {
        let app = AXElement.application(pid: hit.pid)
        app.setTimeout(0.5)
        return (app.focusedWindow ?? app.windows.first)?.frame
    }
}

/// Hides an app the knight has caught: the mirror of `TabCloser`. Hiding rather than quitting is
/// the whole point — the windows leave the screen and ⌘Tab brings them back, so nothing can be
/// lost, which is what lets Keeper stay a speed bump rather than a lock.
@MainActor
final class AppHider {
    static let cooldown: TimeInterval = 3
    private var cooldownUntil: [String: Date] = [:]

    func isCoolingDown(_ hit: AppHit) -> Bool {
        (cooldownUntil[hit.bundleID.lowercased()] ?? .distantPast) > Date()
    }

    func hide(_ hit: AppHit, completion: @escaping (HideOutcome) -> Void) {
        cooldownUntil[hit.bundleID.lowercased()] = Date().addingTimeInterval(Self.cooldown)

        guard let running = NSRunningApplication(processIdentifier: hit.pid), !running.isTerminated else {
            return completion(.alreadyGone)
        }
        if running.isHidden { return completion(.hidden) }

        let element = AXElement.application(pid: hit.pid)
        element.setTimeout(0.5)

        // A menu bar tool has no windows, so there is nothing to take off the screen. Say so
        // rather than reporting a success nobody can see.
        guard !element.windows.isEmpty else { return completion(.noWindows) }

        // Two routes to the same end. `hide()` is the plain one and works once Keeper is trusted;
        // the accessibility attribute is the one that was verified by hand, and covers the apps
        // that ignore the first. Trying both costs nothing and neither can do any harm.
        if !running.hide() {
            element.set(kAXHiddenAttribute as String, true)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard let app = NSRunningApplication(processIdentifier: hit.pid), !app.isTerminated else {
                return completion(.alreadyGone)
            }
            completion(app.isHidden ? .hidden : .failed)
        }
    }
}
