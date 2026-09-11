import AppKit
import ApplicationServices

// Debug builds only. The probe prints the address of every page open in every browser, and it
// runs under Keeper's own code signature — which is what the Accessibility grant is keyed to.
// Shipped in a release build it would let any process on the Mac borrow that grant and dump the
// user's open tabs by running Keeper's binary with a flag. It is a developer tool; `swift run
// Keeper --probe` is a debug build, so nothing is lost by compiling it out.
#if DEBUG

/// `Keeper --probe [rule ...]`: prints what the scanner sees, for checking browsers by hand.
enum Probe {
    static func run() -> Never {
        let rules = Array(CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("--") })
        let blacklist = Blacklist(text: rules.joined(separator: "\n"))
        print("accessibility trusted: \(AXIsProcessTrusted())")
        let scanner = BrowserScanner()
        let apps = scanner.browserApps()
        print("browsers running: \(apps.compactMap(\.localizedName))")
        for app in apps {
            let ax = AXElement.application(pid: app.processIdentifier)
            ax.setTimeout(1.0)
            ax.set("AXManualAccessibility", true)
            let visible = BrowserScanner.onScreenBounds(pid: app.processIdentifier)
            for window in ax.windows {
                let frame = window.frame ?? .null
                let onScreen = visible.contains { ScreenGeometry.roughlyEqual($0, frame, tolerance: 2) }
                let url = BrowserScanner.pageURL(in: window)?.absoluteString ?? "(no web area URL)"
                let tab = BrowserScanner.selectedTabFrame(in: window).map { "\($0)" } ?? "(no tab frame)"
                print("\(app.localizedName ?? "?") window '\(window.title)' onScreen=\(onScreen) minimized=\(window.isMinimized)\n   url: \(url)\n   tab: \(tab)")
            }
        }
        let onlyApp = CommandLine.arguments.first { $0.hasPrefix("--app=") }.map { String($0.dropFirst(6)) }
        if CommandLine.arguments.contains("--tree") {
            for app in apps where onlyApp == nil || app.localizedName == onlyApp {
                let ax = AXElement.application(pid: app.processIdentifier)
                for window in ax.windows {
                    if CommandLine.arguments.contains("--raise") {
                        window.set(kAXMinimizedAttribute, false)
                        window.perform(kAXRaiseAction)
                    }
                    print("== \(app.localizedName ?? "?") window '\(window.title)' axFrame=\(window.frame.map { "\($0)" } ?? "nil")")
                    print("   cg on-screen bounds for pid: \(BrowserScanner.onScreenBounds(pid: app.processIdentifier))")
                    var count = 0
                    window.walk(maxDepth: 14, maxNodes: 2000) { element, depth in
                        count += 1
                        let role = element.role
                        var line = String(repeating: "  ", count: depth) + role
                        let title = element.title
                        if !title.isEmpty { line += " '\(title.prefix(40))'" }
                        if let value = element.raw(kAXValueAttribute) { line += " value=\(String(describing: value).prefix(40))" }
                        if role == "AXWebArea" { line += " url=\(element.url?.absoluteString ?? "nil") frame=\(element.frame.map { "\($0)" } ?? "nil")" }
                        print(line)
                        return role != "AXWebArea"
                    }
                    print("   (\(count) nodes)")
                }
            }
        }
        if !rules.isEmpty {
            let hits = scanner.scan(apps: apps, blacklist: blacklist)
            print("hits for \(rules): \(hits.map { "\($0.appName) \($0.url)" })")
            if CommandLine.arguments.contains("--close"),
               let hit = hits.first(where: { onlyApp == nil || $0.appName == onlyApp }) {
                let closer = TabCloser()
                closer.close(hit, blacklist: blacklist) { outcome in
                    print("\(outcome) — \(hit.rule.host) in \(hit.appName)")
                    exit(0)
                }
                RunLoop.main.run(until: Date().addingTimeInterval(3))
            }
        }
        if CommandLine.arguments.contains("--walk") {
            let app = NSApplication.shared
            app.setActivationPolicy(.accessory)
            let screen = NSScreen.screens[0].visibleFrame
            var knight = Knight(home: CGPoint(x: screen.maxX - 140, y: screen.minY + 2))
            let overlay = OverlayWindow()
            let start = Date()
            var dispatched = false
            let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { _ in
                let now = Date().timeIntervalSince(start)
                if now > 1, !dispatched {
                    dispatched = true
                    knight.dispatch(to: KnightTarget(point: CGPoint(x: screen.minX + 200, y: screen.maxY - 30), message: "Are you trying to enter youtube.com?"))
                }
                for event in knight.update(now: now) { print("\(now): \(event)") }
                overlay.render(knight.frame(now: now))
                if now > 12 { exit(0) }
            }
            RunLoop.main.add(timer, forMode: .common)
            app.run()
        }
        exit(0)
    }
}

#endif
