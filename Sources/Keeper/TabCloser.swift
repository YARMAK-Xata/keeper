import AppKit

/// What happened to a tab Keeper went after. The view turns this into words; the closer
/// stays out of the language business.
enum CloseOutcome: Equatable {
    case closed
    case alreadyGone
    case failed
}

/// Closes the tab a Hit points at: raise the window, re-check the page, ⌘W, verify, fall back to the
/// tab's close button. Each window gets a cooldown so a tab that refuses to close is not hammered.
final class TabCloser {
    static let cooldown: TimeInterval = 3
    private var cooldownUntil: [Int: Date] = [:]

    func isCoolingDown(_ hit: Hit) -> Bool {
        (cooldownUntil[hit.window.id] ?? .distantPast) > Date()
    }

    /// Must be called on the main thread.
    func close(_ hit: Hit, blacklist: Blacklist, completion: @escaping (CloseOutcome) -> Void) {
        cooldownUntil[hit.window.id] = Date().addingTimeInterval(Self.cooldown)
        NSRunningApplication(processIdentifier: hit.pid)?.activate()
        hit.window.perform(kAXRaiseAction)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard let url = BrowserScanner.pageURL(in: hit.window), blacklist.matches(url) != nil else {
                completion(.alreadyGone)
                return
            }
            let app = AXElement.application(pid: hit.pid)
            let windowFocused = app.focusedWindow.map { $0.isSame(as: hit.window) } ?? false
            let appInFront = NSWorkspace.shared.frontmostApplication?.processIdentifier == hit.pid
            if windowFocused && appInFront {
                Self.postCommandW(pid: hit.pid, viaHID: true)
            } else if windowFocused {
                Self.postCommandW(pid: hit.pid, viaHID: false)
            } else {
                _ = Self.pressCloseButton(in: hit.window)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if let url = BrowserScanner.pageURL(in: hit.window), blacklist.matches(url) != nil {
                    completion(Self.pressCloseButton(in: hit.window) ? .closed : .failed)
                } else {
                    completion(.closed)
                }
            }
        }
    }

    /// ⌘W. Through the HID tap when the browser is frontmost (most faithful), else straight to its pid.
    static func postCommandW(pid: pid_t, viaHID: Bool) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyW: CGKeyCode = 13
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyW, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyW, keyDown: false) else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        if viaHID {
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        } else {
            down.postToPid(pid)
            up.postToPid(pid)
        }
    }

    /// Presses the close button inside the selected tab, when the browser exposes one.
    static func pressCloseButton(in window: AXElement) -> Bool {
        guard let tab = BrowserScanner.selectedTab(in: window),
              let button = tab.children.first(where: { $0.role == kAXButtonRole }) else { return false }
        return button.perform(kAXPressAction)
    }
}
