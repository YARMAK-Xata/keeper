import SwiftUI

/// What both surfaces show once Keeper has the access it needs: the two lists, the last thing
/// that happened, and the one button.
///
/// This used to be the same twenty-five lines written twice, once in `MainView` and once in
/// `PanelView`. Both files carried a comment promising the two surfaces could not drift apart,
/// and a copy each of the logic that would do the drifting — a fix landing in one and not the
/// other is exactly the failure the comment claimed was impossible. One view now, and the only
/// thing the surface decides is how far apart to set the pieces.
struct TaskSection: View {
    @ObservedObject var session: SessionController

    /// Which surface is drawing this. Everything inside is identical on both; only the gaps
    /// between the pieces come from here.
    let surface: Metrics.Surface

    @Binding var storedText: String
    @Binding var storedApps: String
    @Binding var draft: String

    /// Drives the relative time on the event line, which ages while you look at it.
    let now: Date

    private var sites: SiteList { SiteList(text: storedText) }
    private var apps: AppList { AppList(text: storedApps) }

    var body: some View {
        VStack(alignment: .leading, spacing: surface.itemSpacing) {
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
                LatestEvent(event: event, now: max(now, event.at))
            }
            if session.isRunning {
                PrimaryButton(label: L.t("button.stop"), tint: .red) { session.stop() }
            } else {
                PrimaryButton(label: L.t("button.start"), isDefault: true,
                              enabled: !(sites.isEmpty && apps.isEmpty)) {
                    session.start(sites: sites, apps: apps)
                }
                if sites.isEmpty && apps.isEmpty {
                    Text(L.t("button.start.hint"))
                        .font(Metrics.Typography.secondary)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
