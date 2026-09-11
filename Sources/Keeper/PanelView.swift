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

    /// The two links, on one row where they fit and stacked where they do not.
    ///
    /// There used to be three, opening the window first. That link went when the window stopped
    /// being a second place to use Keeper: a link whose whole result is a sign telling you to come
    /// back here is a step that leads nowhere.
    ///
    /// They sit against the left margin like everything above them. Justifying them edge to edge
    /// put Quit out on the right rail, alone in a panel whose every other element starts at the
    /// same x — and it was only ever a way to space three items, which there are no longer three
    /// of.
    ///
    /// Still measured rather than assumed. Two links fit in every language Keeper speaks today,
    /// but a row that happens to fit is the same bug that once pushed Quit off the edge in German,
    /// waiting for the eighth language. `ViewThatFits` stacks them instead of clipping.
    private var links: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Metrics.Space.section) {
                Button(L.t("menu.settings"), action: onOpenSettings)
                Button(L.t("menu.quit"), action: onQuit)
            }
            VStack(alignment: .leading, spacing: Metrics.Space.snug) {
                Button(L.t("menu.settings"), action: onOpenSettings)
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

/// One purpose sentence and one button, as the HIG asks — and one button is the whole point.
///
/// There were two: Continue, which showed the system alert, and a link to System Settings that
/// appeared underneath once the alert had been shown. They were not alternatives, they were a
/// sequence, because the alert is a one-shot and Continue stopped doing anything after the first
/// press. Stacked together they read as the same offer made twice, with the prominent one being
/// the one that had gone dead. `PermissionStep` folds them into a single button that says which
/// of the two it is about to do.
struct PermissionSection: View {
    @Binding var alertShown: Bool

    private var step: PermissionStep { .current(alertShown: alertShown) }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Space.gap) {
            Text(L.t("permission.purpose"))
                .font(Metrics.Typography.body)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton(label: step.label, isDefault: true) {
                step.take()
                alertShown = true
            }
            // A rebuilt copy of an app is a different app to macOS, so an approval granted to
            // the previous copy stays switched on and stops working. Say so rather than
            // leaving people to wonder why the switch is on and Keeper disagrees.
            if alertShown {
                Text(L.t("permission.stale"))
                    .font(Metrics.Typography.secondary).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
