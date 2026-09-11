import AppKit
import SwiftUI

/// Keeper's window. It shows the Accessibility step on a first launch, and after that the same
/// list the menu bar panel shows, with room to breathe — the same `SiteListView`, the same
/// header, the same button, at 420 pt instead of 300.
///
/// Nothing lives only here: everything in this window is also in the panel, so closing it never
/// takes a capability away. The settings switches moved to Settings, where they stop competing
/// with the one action.
struct MainView: View {
    @ObservedObject var session: SessionController

    @AppStorage("blacklistText") private var storedText = "youtube.com\n"
    @AppStorage("blockedAppsText") private var storedApps = ""
    @AppStorage("draftSite") private var draft = ""

    @State private var trusted = Permissions.isTrusted
    @State private var alertShown = Permissions.hasRequestedTrust
    @State private var tick = Date()

    @Environment(\.openWindow) private var openWindow

    private let trustCheck = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    private let clockTick = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    private var sites: SiteList { SiteList(text: storedText) }
    private var apps: AppList { AppList(text: storedApps) }
    private var state: SurfaceState { .current(trusted: trusted, running: session.isRunning) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StateHeader(title: state.title(startedAt: session.startedAt),
                        subtitle: state.subtitle(siteCount: session.siteCount,
                                                 appCount: session.appCount))
            switch state {
            case .needsAccess: PermissionSection(alertShown: $alertShown)
            case .ready, .onDuty: task
            }
        }
        .padding(20)
        .frame(width: 420)
        // The title bar has always been glass while the body underneath was a flat grey, which
        // put a seam across the window. The same material behind the whole thing removes it.
        .background(WindowGlass())
        .onAppear { session.openMainWindow = { openWindow(id: "main") } }
        .onReceive(trustCheck) { _ in trusted = Permissions.isTrusted }
        .onReceive(clockTick) { now in tick = now }
        .onChange(of: session.lastEvent) { _, _ in tick = Date() }
    }

    private var task: some View {
        VStack(alignment: .leading, spacing: 12) {
            // A locked group with nothing in it would be a label over an empty box, so a session
            // guarding only sites shows only sites, and the other way round.
            if !(session.isRunning && sites.isEmpty) {
                SiteListView(sites: sites, locked: session.isRunning, draft: $draft,
                             onAdd: { SiteStore.add($0, to: &storedText); draft = "" },
                             onRemove: { SiteStore.remove($0, from: &storedText) })
            }
            if !(session.isRunning && apps.isEmpty) {
                AppListView(apps: apps, locked: session.isRunning,
                            onAdd: { AppStore.add($0, to: &storedApps) },
                            onRemove: { AppStore.remove($0, from: &storedApps) })
            }
            if let event = session.lastEvent {
                LatestEvent(event: event, now: max(tick, event.at))
            }
            if session.isRunning {
                PrimaryButton(label: L.t("button.stop"), tint: .red) { session.stop() }
            } else {
                PrimaryButton(label: L.t("button.start"), isDefault: true,
                              enabled: !(sites.isEmpty && apps.isEmpty)) {
                    session.start(sites: sites, apps: apps)
                }
                if sites.isEmpty && apps.isEmpty {
                    Text(L.t("button.start.hint")).font(.callout).foregroundStyle(.secondary)
                }
            }
        }
    }
}
