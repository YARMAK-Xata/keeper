import AppKit
import SwiftUI

@main
struct KeeperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var session = SessionController.shared

    init() {
        #if DEBUG
        if CommandLine.arguments.contains("--probe") { Probe.run() }
        #endif
    }

    var body: some Scene {
        Window("Keeper", id: "main") {
            MainView(session: session)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(L.t("menu.about")) { AboutPanel.show() }
            }
        }

        Settings {
            SettingsView(session: session)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            // Puts Keeper in the menu bar, the Dock or both, and sets the activation policy to
            // match, so this is also what makes the app visible at all on a first launch.
            // Before anything else: a guard you have to remember to start is one you forget on
            // the day it matters. Once only, so switching it off later stays off.
            LoginItem.enableOnFirstRun()
            SessionController.shared.setupPresence()
            SessionController.shared.presentAtLaunch()
            if CommandLine.arguments.contains("--start") {
                SessionController.shared.startFromSavedList()
            }
            #if DEBUG
            // A click on the shield cannot be scripted without Accessibility access, so these are
            // how the panel and Settings get looked at during development. Both go through the
            // same methods the panel's own links use, so they check the real path, not a copy.
            // Compiled out of release builds.
            let arguments = CommandLine.arguments
            if arguments.contains("--panel") || arguments.contains("--settings") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    if arguments.contains("--panel") { SessionController.shared.showPanelForInspection() }
                    if arguments.contains("--settings") { SessionController.shared.showSettings() }
                }
            }
            #endif
        }
    }

    /// Closing the window must not quit: a session may be running, and the panel under the shield
    /// is how Keeper is meant to be reached once the window is out of the way. `Presence` keeps
    /// at least one of the shield and the Dock icon on screen, so there is always a way back.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            MainActor.assumeIsolated { SessionController.shared.showMainWindow() }
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { SessionController.shared.stop() }
    }
}

/// The standard About panel, carrying the sprite attribution the CC BY-SA licence requires.
enum AboutPanel {
    static func show() {
        let body = NSFont.systemFont(ofSize: 11)
        let credits = NSMutableAttributedString(
            string: L.t("about.tagline") + "\n\n",
            attributes: [.font: body, .foregroundColor: NSColor.labelColor]
        )
        credits.append(NSAttributedString(
            string: L.t("about.credit"),
            attributes: [.font: body,
                         .foregroundColor: NSColor.secondaryLabelColor,
                         .link: URL(string: "https://opengameart.org/content/animated-knight-character-pack-v20")!]
        ))
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }
}
