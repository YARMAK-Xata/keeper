import AppKit

/// A blacklisted page visible in a browser window. Frames use AX (top-left) coordinates.
struct Hit {
    let pid: pid_t
    let appName: String
    let window: AXElement
    let url: URL
    let rule: BlacklistRule
    let windowFrame: CGRect?
    let tabFrame: CGRect?
}

final class BrowserScanner: @unchecked Sendable {   // `prepared` is only touched on the scan queue
    static let knownBundleIDs: Set<String> = [
        "com.apple.Safari", "com.apple.SafariTechnologyPreview",
        "com.google.Chrome", "com.google.Chrome.canary", "com.google.Chrome.beta", "com.google.Chrome.dev",
        "org.chromium.Chromium", "company.thebrowser.Browser", "company.thebrowser.dia",
        "com.brave.Browser", "com.brave.Browser.beta", "com.brave.Browser.nightly",
        "com.microsoft.edgemac", "com.microsoft.edgemac.Beta", "com.microsoft.edgemac.Dev", "com.microsoft.edgemac.Canary",
        "com.vivaldi.Vivaldi", "com.operasoftware.Opera", "com.operasoftware.OperaGX", "com.operasoftware.OperaDeveloper",
        "org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition", "org.mozilla.nightly", "app.zen-browser.zen",
        "com.kagi.kagimacOS", "com.duckduckgo.macos.browser", "org.torproject.torbrowser",
        "ru.yandex.desktop.yandex-browser", "com.sigmaos.sigmaos.macos", "ai.perplexity.comet",
        "net.imput.helium", "org.ladybird.Ladybird",
    ]

    private var prepared = Set<pid_t>()

    /// Running apps that can show web pages: every registered http handler plus the known list, never Keeper itself.
    func browserApps() -> [NSRunningApplication] {
        let handlers = NSWorkspace.shared.urlsForApplications(toOpen: URL(string: "http://example.com")!)
            .compactMap { Bundle(url: $0)?.bundleIdentifier }
        let ids = Set(handlers).union(Self.knownBundleIDs).subtracting([Bundle.main.bundleIdentifier ?? ""])
        return NSWorkspace.shared.runningApplications.filter { app in
            app.activationPolicy == .regular && app.bundleIdentifier.map(ids.contains) == true
        }
    }

    /// One pass over every visible window of every browser. Safe to call off the main thread.
    func scan(apps: [NSRunningApplication], blacklist: Blacklist) -> [Hit] {
        var hits: [Hit] = []
        for app in apps {
            let pid = app.processIdentifier
            let ax = AXElement.application(pid: pid)
            if !prepared.contains(pid) {
                ax.setTimeout(1.0)
                ax.set("AXManualAccessibility", true)   // makes Chromium/Electron publish their tree
                prepared.insert(pid)
            }
            let visible = Self.onScreenBounds(pid: pid)
            for window in ax.windows {
                guard !window.isMinimized, let windowFrame = window.frame,
                      visible.contains(where: { ScreenGeometry.roughlyEqual($0, windowFrame, tolerance: 2) }) else { continue }
                guard let url = Self.pageURL(in: window), let rule = blacklist.matches(url) else { continue }
                hits.append(Hit(pid: pid, appName: app.localizedName ?? "browser", window: window, url: url, rule: rule,
                                windowFrame: windowFrame, tabFrame: Self.selectedTabFrame(in: window)))
            }
        }
        return hits
    }

    /// The URL of the page shown in the window: the largest AXWebArea's URL.
    static func pageURL(in window: AXElement) -> URL? {
        var best: (url: URL, area: CGFloat)?
        window.walk(maxDepth: 12, maxNodes: 600) { element, _ in
            guard element.role == "AXWebArea" else { return true }
            if let url = element.url {
                let area = element.frame.map { $0.width * $0.height } ?? 0
                if best == nil || area > best!.area { best = (url, area) }
            }
            return false
        }
        return best?.url
    }

    /// Frame of the selected tab: the first AXRadioButton with value 1 outside the web area. Chrome and
    /// Firefox keep them inside an AXTabGroup; Safari hangs them straight off the window.
    static func selectedTabFrame(in window: AXElement) -> CGRect? {
        selectedTab(in: window)?.frame
    }

    static func selectedTab(in window: AXElement) -> AXElement? {
        var found: AXElement?
        window.walk(maxDepth: 10, maxNodes: 500) { element, _ in
            if found != nil || element.role == "AXWebArea" { return false }
            if element.role == kAXRadioButtonRole {
                if element.intValue == 1 { found = element }
                return false
            }
            return true
        }
        return found
    }

    /// Bounds of this process's windows that are actually on screen (current Space, not minimized, app not hidden).
    static func onScreenBounds(pid: pid_t) -> [CGRect] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        return list.compactMap { info in
            guard (info[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = bounds["X"], let y = bounds["Y"], let w = bounds["Width"], let h = bounds["Height"] else { return nil }
            return CGRect(x: x, y: y, width: w, height: h)
        }
    }
}
