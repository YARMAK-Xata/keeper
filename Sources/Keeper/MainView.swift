import AppKit
import SwiftUI

/// Keeper's window. It shows the Accessibility step on a first launch, and after that the same
/// task the menu bar panel shows, with room to breathe — literally the same `TaskSection`, the
/// same header and the same button, set out on the roomier of the two surfaces in `Metrics`.
///
/// Nothing lives only here: everything in this window is also in the panel, so closing it never
/// takes a capability away. The settings switches moved to Settings, where they stop competing
/// with the one action.
struct MainView: View {
    @ObservedObject var session: SessionController

    @AppStorage("blacklistText") private var storedText = "youtube.com\n"
    @AppStorage("blockedAppsText") private var storedApps = ""
    @AppStorage("draftSite") private var draft = ""

    @ObservedObject private var updates = UpdateChecker.shared

    @State private var trusted = Permissions.isTrusted
    @State private var alertShown = Permissions.hasRequestedTrust
    @State private var tick = Date()

    @Environment(\.openWindow) private var openWindow

    private let trustCheck = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    private let clockTick = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    private let surface = Metrics.Surface.window

    private var sites: SiteList { SiteList(text: storedText) }
    private var apps: AppList { AppList(text: storedApps) }
    private var state: SurfaceState { .current(trusted: trusted, running: session.isRunning) }

    var body: some View {
        VStack(alignment: .leading, spacing: surface.sectionSpacing) {
            StateHeader(title: state.title(startedAt: session.startedAt),
                        subtitle: state.subtitle(siteCount: session.siteCount,
                                                 appCount: session.appCount))
            UpdateLine(checker: updates)
            switch state {
            case .needsAccess: PermissionSection(alertShown: $alertShown)
            case .ready, .onDuty:
                TaskSection(session: session, surface: surface,
                            storedText: $storedText, storedApps: $storedApps,
                            draft: $draft, now: tick)
            }
        }
        .padding(surface.margin)
        .frame(width: surface.width)
        // The title bar has always been glass while the body underneath was a flat grey, which
        // put a seam across the window. The same material behind the whole thing removes it.
        .background(WindowGlass())
        .onAppear { session.openMainWindow = { openWindow(id: "main") } }
        .onAppear { updates.checkIfDue() }
        .onReceive(trustCheck) { _ in trusted = Permissions.isTrusted }
        .onReceive(clockTick) { now in tick = now }
        .onChange(of: session.lastEvent) { _, _ in tick = Date() }
    }

}
