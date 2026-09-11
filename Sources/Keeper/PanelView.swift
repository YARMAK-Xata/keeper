import AppKit
import SwiftUI

/// The menu bar panel: the whole task under the shield. Everything the app does is here, so the
/// window never has to be open for Keeper to be used or stopped.
///
/// 300 pt wide, sized by its content in height. The links along the bottom are the only
/// navigation, which is why Quit is one of them: the panel must never be a dead end.
struct PanelView: View {
    @ObservedObject var session: SessionController

    @AppStorage("blacklistText") private var storedText = "youtube.com\n"
    @AppStorage("blockedAppsText") private var storedApps = ""
    @AppStorage("draftSite") private var draft = ""

    @State private var trusted = Permissions.isTrusted
    @State private var alertShown = Permissions.hasRequestedTrust
    @State private var tick = Date()

    var onOpenWindow: () -> Void
    var onOpenSettings: () -> Void
    var onQuit: () -> Void

    private let trustCheck = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    private let clockTick = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    private var sites: SiteList { SiteList(text: storedText) }
    private var apps: AppList { AppList(text: storedApps) }
    private var state: SurfaceState { .current(trusted: trusted, running: session.isRunning) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StateHeader(title: state.title(startedAt: session.startedAt),
                        subtitle: state.subtitle(siteCount: session.siteCount,
                                                 appCount: session.appCount))
            switch state {
            case .needsAccess: PermissionSection(alertShown: $alertShown)
            case .ready, .onDuty: task
            }
            Divider()
            links
        }
        .padding(14)
        .frame(width: 300)
        .onReceive(trustCheck) { _ in trusted = Permissions.isTrusted }
        .onReceive(clockTick) { now in tick = now }
        .onChange(of: session.lastEvent) { _, _ in tick = Date() }
    }

    private var task: some View {
        VStack(alignment: .leading, spacing: 10) {
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

    private var links: some View {
        HStack(spacing: 0) {
            Button(L.t("menu.open"), action: onOpenWindow)
            Spacer(minLength: 8)
            Button(L.t("menu.settings"), action: onOpenSettings)
            Spacer(minLength: 8)
            Button(L.t("menu.quit"), action: onQuit)
        }
        .buttonStyle(.link)
        .font(.callout)
    }
}

/// The last thing that happened, with a relative time that ages as you look at it.
struct LatestEvent: View {
    let event: SessionController.Event
    let now: Date

    var body: some View {
        Text("\(event.text) · \(L.ago(event.at, from: now))")
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// One purpose sentence and one button that opens the system alert, as the HIG asks. The
/// settings link appears only once the alert has been shown, because before that it is a second
/// way to do the thing the button already does.
struct PermissionSection: View {
    @Binding var alertShown: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.t("permission.purpose"))
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton(label: L.t("permission.continue"), isDefault: true) {
                Permissions.requestTrust()
                alertShown = true
            }
            if alertShown {
                Button(L.t("permission.openSettings")) { Permissions.openAccessibilitySettings() }
                    .buttonStyle(.link)
                // A rebuilt copy of an app is a different app to macOS, so an approval granted to
                // the previous copy stays switched on and stops working. Say so rather than
                // leaving people to wonder why the switch is on and Keeper disagrees.
                Text(L.t("permission.stale"))
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
