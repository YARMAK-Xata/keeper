import AppKit
import SwiftUI

/// Keeper's window. It shows the Accessibility step on a first launch, and after that it says
/// where Keeper actually is: under the shield in the menu bar.
///
/// It used to carry a second copy of the whole task — the same `TaskSection`, the same button —
/// on the theory that two surfaces which render the same view cannot drift apart. They could not,
/// and that was not the problem. Two places to do one thing is one place too many: it invites you
/// to keep a window open for an app that does not need one, and it leaves people who found the
/// window first never discovering the panel, which is where Keeper lives while you work. So the
/// lists, Start and Stop are the panel's alone, and this window points at them.
///
/// The permission step stays here, because it is a gate rather than day-to-day use, and because
/// a popover is the wrong place to be sent to System Settings from.
struct MainView: View {
    @ObservedObject var session: SessionController

    @ObservedObject private var updates = UpdateChecker.shared

    @State private var trusted = Permissions.isTrusted
    @State private var alertShown = Permissions.hasRequestedTrust

    @Environment(\.openWindow) private var openWindow

    private let trustCheck = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    private let surface = Metrics.Surface.window

    private var state: SurfaceState { .current(trusted: trusted, running: session.isRunning) }

    var body: some View {
        VStack(alignment: .leading, spacing: surface.sectionSpacing) {
            StateHeader(title: state.title(startedAt: session.startedAt),
                        subtitle: state.subtitle(siteCount: session.siteCount,
                                                 appCount: session.appCount))
            UpdateLine(checker: updates)
            switch state {
            case .needsAccess: PermissionSection(alertShown: $alertShown)
            case .ready, .onDuty: MenuBarSignpost()
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
    }

}
