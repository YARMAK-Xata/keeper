import AppKit
import SwiftUI

/// The menu bar panel: the whole task under the shield. Everything the app does is here, so the
/// window never has to be open for Keeper to be used or stopped.
///
/// Sized by its content in height, and by `Metrics.Surface.panel` in width. The links along the
/// bottom are the only navigation, which is why Quit is one of them: the panel must never be a
/// dead end.
struct PanelView: View {
    @ObservedObject var session: SessionController

    @AppStorage("blacklistText") private var storedText = "youtube.com\n"
    @AppStorage("blockedAppsText") private var storedApps = ""
    @AppStorage("draftSite") private var draft = ""

    @ObservedObject private var updates = UpdateChecker.shared

    @State private var trusted = Permissions.isTrusted
    @State private var alertShown = Permissions.hasRequestedTrust
    @State private var tick = Date()

    var onOpenWindow: () -> Void
    var onOpenSettings: () -> Void
    var onQuit: () -> Void

    private let trustCheck = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    private let clockTick = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    private let surface = Metrics.Surface.panel

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
            Divider()
            links
        }
        .padding(surface.margin)
        .frame(width: surface.width)
        .onAppear { updates.checkIfDue() }
        .onReceive(trustCheck) { _ in trusted = Permissions.isTrusted }
        .onReceive(clockTick) { now in tick = now }
        .onChange(of: session.lastEvent) { _, _ in tick = Date() }
    }

    /// The three links, on one row where they fit and two where they do not.
    ///
    /// They were justified edge to edge across a fixed-width popover, which held in English and
    /// nowhere else: "Keeper öffnen · Einstellungen… · Keeper beenden" wants 274 points, the
    /// Russian 291 and the Ukrainian 297, against the 272 the panel had. The overflow did not
    /// wrap, it pushed Quit off the edge — and Quit is the one link the panel cannot afford to
    /// lose, because it is the only way out of a dead end.
    ///
    /// The panel is wider now and all seven fit again, but a fixed row that happens to fit today
    /// is the same bug waiting for the eighth language. `ViewThatFits` measures instead of
    /// assuming: it takes the single row when the row is genuinely wide enough, and drops Quit to
    /// its own line when it is not.
    private var links: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                Button(L.t("menu.open"), action: onOpenWindow)
                Spacer(minLength: Metrics.Space.step)
                Button(L.t("menu.settings"), action: onOpenSettings)
                Spacer(minLength: Metrics.Space.step)
                Button(L.t("menu.quit"), action: onQuit)
            }
            VStack(alignment: .leading, spacing: Metrics.Space.snug) {
                HStack(spacing: 0) {
                    Button(L.t("menu.open"), action: onOpenWindow)
                    Spacer(minLength: Metrics.Space.step)
                    Button(L.t("menu.settings"), action: onOpenSettings)
                }
                Button(L.t("menu.quit"), action: onQuit)
            }
        }
        .buttonStyle(.link)
        .font(Metrics.Typography.secondary)
    }
}

/// The last thing that happened, with a relative time that ages as you look at it.
struct LatestEvent: View {
    let event: SessionController.Event
    let now: Date

    var body: some View {
        Text("\(event.text) · \(L.ago(event.at, from: now))")
            .font(Metrics.Typography.secondary)
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
        VStack(alignment: .leading, spacing: Metrics.Space.gap) {
            Text(L.t("permission.purpose"))
                .font(Metrics.Typography.body)
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
                    .font(Metrics.Typography.secondary).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
