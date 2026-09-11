import AppKit
import Combine
import SwiftUI

/// Owns a running session: the 1 Hz scanner, the 60 Hz knight, the overlay, the closer, and
/// the menu bar item. The window reads its state from here and never drives the machinery itself.
@MainActor
final class SessionController: ObservableObject {
    static let shared = SessionController()

    /// The latest thing that happened, kept with its time so the window can say "just now".
    struct Event: Equatable {
        let text: String
        let at: Date
    }

    @Published private(set) var isRunning = false
    @Published private(set) var startedAt: Date?
    @Published private(set) var siteCount = 0
    @Published private(set) var appCount = 0
    @Published private(set) var lastEvent: Event?

    /// Set by the window so the panel can bring it back after it has been closed.
    var openMainWindow: (() -> Void)?

    private let scanner = BrowserScanner()
    private let closer = TabCloser()
    private let hider = AppHider()
    private let statusItem = StatusItemController()
    private let scanQueue = DispatchQueue(label: "dev.keeper.scan", qos: .utility)
    private var blacklist = Blacklist(text: "")
    private var apps = AppList(text: "")
    private var knight: Knight?
    private var overlay: OverlayWindow?

    /// What the knight is currently walking towards. A tab and an app are the same errand as far
    /// as he is concerned — run there, strike, and something goes away — so they share the slot.
    private enum Quarry {
        case site(Hit)
        case app(AppHit)
    }
    private var pending: Quarry?
    private var scanTimer: Timer?
    private var frameTimer: Timer?
    private var scanInFlight = false
    private var lastHome: CGPoint?
    private var dockObservers: [NSObjectProtocol] = []
    private let clock = Date()

    private init() {}

    // MARK: - Session

    func start(sites: SiteList, apps: AppList) {
        guard !isRunning, !(sites.isEmpty && apps.isEmpty), Permissions.isTrusted else { return }
        blacklist = sites.blacklist
        self.apps = apps
        siteCount = sites.count
        appCount = apps.count
        lastHome = nil
        knight = Knight(home: Self.homePoint())
        overlay = OverlayWindow()
        // He can be picked up and carried anywhere, and walks back to his post when he is let
        // go. `Knight` refuses the grab while he is on an errand, which is what stops this being
        // a way to lift him off a tab he was sent to close.
        overlay?.onGrab = { [weak self] in self?.knight?.grab() ?? false }
        overlay?.onCarry = { [weak self] point in self?.knight?.drag(to: point) }
        overlay?.onRelease = { [weak self] in self?.knight?.release() }
        isRunning = true
        startedAt = Date()
        lastEvent = nil

        let frameTimer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        let scanTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.scan() }
        }
        RunLoop.main.add(frameTimer, forMode: .common)
        RunLoop.main.add(scanTimer, forMode: .common)
        self.frameTimer = frameTimer
        self.scanTimer = scanTimer

        for (center, name) in [
            (NotificationCenter.default, NSApplication.didChangeScreenParametersNotification),
            (NSWorkspace.shared.notificationCenter, NSWorkspace.didLaunchApplicationNotification),
            (NSWorkspace.shared.notificationCenter, NSWorkspace.didTerminateApplicationNotification),
        ] {
            dockObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.followDock() }
            })
        }

        refreshPresence()
        scan()
    }

    func stop() {
        guard isRunning else { return }
        frameTimer?.invalidate(); frameTimer = nil
        scanTimer?.invalidate(); scanTimer = nil
        for observer in dockObservers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        dockObservers.removeAll()
        overlay?.orderOut(nil)
        overlay = nil
        knight = nil
        pending = nil
        lastHome = nil
        isRunning = false
        startedAt = nil
        refreshPresence()
    }

    // MARK: - Where Keeper lives

    /// Builds the panel and wires the shield, once, at launch. The panel is built here and kept
    /// rather than rebuilt per opening, so a half-typed site is still there when you come back.
    func setupPresence() {
        let panel = NSHostingController(rootView: PanelView(
            session: self,
            onOpenSettings: { [weak self] in self?.showSettings() },
            onQuit: { NSApp.terminate(nil) }
        ))
        // Let the panel be as tall as its content rather than a guessed fixed size.
        panel.sizingOptions = [.preferredContentSize]
        statusItem.panelViewController = panel
        statusItem.onOpen = { [weak self] in self?.showMainWindow() }
        statusItem.onSettings = { [weak self] in self?.showSettings() }
        refreshPresence()
    }

    /// Puts Keeper where the settings say it should be — the menu bar, the Dock, or both — and
    /// makes the shield match the session. `Presence` guarantees at least one of the two, so
    /// this can never hide the app entirely.
    func refreshPresence() {
        let presence = Presence()
        statusItem.setVisible(presence.menuBar)
        statusItem.update(isRunning: isRunning)

        let wanted: NSApplication.ActivationPolicy = presence.dock ? .regular : .accessory
        if NSApp.activationPolicy() != wanted {
            NSApp.setActivationPolicy(wanted)
            // Coming back to the Dock without this leaves the app running behind everything
            // with no way to tell it arrived.
            if wanted == .regular { NSApp.activate(ignoringOtherApps: true) }
        }
    }

    #if DEBUG
    func showPanelForInspection() { statusItem.openPanelForInspection() }
    #endif

    /// What a launch should look like. With a Dock icon, Keeper is an app you just opened, so it
    /// comes to the front. Without one it is a menu bar app: the window scene opens itself, and
    /// putting a window in front of someone who asked for menu bar only — at login, no less —
    /// would be an intrusion, so it goes straight back out of sight.
    func presentAtLaunch() {
        if Presence().dock {
            NSApp.activate(ignoringOtherApps: true)
        } else {
            DispatchQueue.main.async { Self.mainWindow()?.orderOut(nil) }
        }
    }

    func showMainWindow() {
        statusItem.closePanel()
        NSApp.activate(ignoringOtherApps: true)
        if let window = Self.mainWindow() {
            window.makeKeyAndOrderFront(nil)
        } else {
            // Closed rather than hidden, so it has to be built again.
            openMainWindow?()
        }
    }

    private static func mainWindow() -> NSWindow? {
        NSApp.windows.first { $0.canBecomeMain && $0.title == "Keeper" }
    }

    /// Opens the Settings scene. In menu bar only mode there is no application menu on screen, so
    /// the panel's link is the only way in and ⌘, does not exist — this is what both go through.
    ///
    /// SwiftUI puts the Settings scene's opener on the application menu's own item and has
    /// renamed the selector behind it once already, so the item is found by its ⌘, key rather
    /// than by a selector name, and firing it is left to whatever action it carries. The two
    /// named selectors stay as a fallback for the case where the menu has not been built.
    func showSettings() {
        statusItem.closePanel()
        NSApp.activate(ignoringOtherApps: true)

        if let appMenu = NSApp.mainMenu?.items.first?.submenu,
           let item = appMenu.items.first(where: { $0.keyEquivalent == "," && $0.action != nil }),
           let action = item.action,
           NSApp.sendAction(action, to: item.target, from: item) {
            return
        }
        for name in ["showSettingsWindow:", "showPreferencesWindow:"] where
            NSApp.sendAction(Selector(name), to: nil, from: nil) { return }

        // Every route refused. Rather than a link that silently does nothing, bring the window
        // forward: it is not Settings, but it is a surface the person can see and act on.
        showMainWindow()
    }

    /// Starting without a window to read uses the saved lists. With nothing saved, or without
    /// permission, the window is the honest answer rather than a silent no-op.
    func startFromSavedList() {
        let sites = SiteList(text: UserDefaults.standard.string(forKey: "blacklistText") ?? "")
        let apps = AppList(text: UserDefaults.standard.string(forKey: "blockedAppsText") ?? "")
        guard !(sites.isEmpty && apps.isEmpty), Permissions.isTrusted else { return showMainWindow() }
        start(sites: sites, apps: apps)
    }

    // MARK: - Detection

    private func scan() {
        guard isRunning, knight?.isBusy == false else { return }

        // He is standing still, so this is the moment to check the Dock has not moved under him.
        followDock()

        // Apps first, because finding one is a property read: it costs nothing to check every
        // tick, and an app already open when the session starts should go straight away.
        if let hit = AppScanner.hits(for: apps).first(where: { !hider.isCoolingDown($0) }) {
            pending = .app(hit)
            record(L.t("event.appSpotted", hit.name))
            dispatchKnight(to: AppScanner.windowFrame(of: hit), tab: nil,
                           saying: L.t("knight.bubble.app", hit.name))
            return
        }

        guard !scanInFlight else { return }
        scanInFlight = true
        let apps = scanner.browserApps()
        let blacklist = self.blacklist
        let scanner = self.scanner
        scanQueue.async {
            let hits = scanner.scan(apps: apps, blacklist: blacklist)
            Task { @MainActor in
                self.scanInFlight = false
                self.handle(hits)
            }
        }
    }

    private func handle(_ hits: [Hit]) {
        guard isRunning, knight?.isBusy == false,
              let hit = hits.first(where: { !closer.isCoolingDown($0) }) else { return }
        pending = .site(hit)
        record(L.t("event.spotted", hit.rule.host, hit.appName))
        dispatchKnight(to: hit.windowFrame, tab: hit.tabFrame,
                       saying: L.t("knight.bubble", hit.rule.host))
    }

    /// Sends the knight somewhere.
    ///
    /// The target is worked out and finished with *before* `dispatch` is called, and that order
    /// is the whole point. `Knight` is a struct, so `knight?.dispatch(…)` takes exclusive access
    /// to the property for the length of the expression; anything inside the argument that reads
    /// `knight` — the old code read `knight?.home` for its fallback — is a simultaneous access,
    /// and Swift ends the process for it. It took an app being caught before it had a window to
    /// find, which is exactly what opening Spotify looks like.
    private func dispatchKnight(to windowFrame: CGRect?, tab: CGRect?, saying message: String) {
        let point = ScreenGeometry.knightTarget(
            tabFrame: tab, windowFrame: windowFrame,
            home: knight?.home ?? Self.homePoint(),
            primaryHeight: NSScreen.screens.first?.frame.height ?? 900)
        let target = KnightTarget(point: point, message: message)
        knight?.dispatch(to: target)
    }

    private func tick() {
        guard isRunning, knight != nil else { return }
        let now = Date().timeIntervalSince(clock)
        for event in knight!.update(now: now) where event == .strike {
            guard let quarry = pending else { continue }
            pending = nil
            switch quarry {
            case .site(let hit):
                closer.close(hit, blacklist: blacklist) { [weak self] outcome in
                    Task { @MainActor in self?.record(Self.describe(outcome, hit)) }
                }
            case .app(let hit):
                hider.hide(hit) { [weak self] outcome in
                    Task { @MainActor in self?.record(Self.describe(outcome, hit)) }
                }
            }
        }
        overlay?.render(knight!.frame(now: now))
    }

    private func record(_ text: String) {
        lastEvent = Event(text: text, at: Date())
    }

    private static func describe(_ outcome: HideOutcome, _ hit: AppHit) -> String {
        switch outcome {
        case .hidden: return L.t("event.hid", hit.name)
        case .alreadyGone: return L.t("event.appAlreadyGone", hit.name)
        case .noWindows: return L.t("event.hidNoWindows", hit.name)
        case .failed: return L.t("event.hidFailed", hit.name)
        }
    }

    private static func describe(_ outcome: CloseOutcome, _ hit: Hit) -> String {
        switch outcome {
        case .closed: return L.t("event.closed", hit.rule.host, hit.appName)
        case .alreadyGone: return L.t("event.alreadyGone", hit.rule.host, hit.appName)
        case .failed: return L.t("event.failed", hit.rule.host, hit.appName)
        }
    }

    // MARK: - Geometry

    /// Just past the end of the Dock, standing on it.
    static func homePoint() -> CGPoint {
        let screen = NSScreen.screens.first
        return ScreenGeometry.knightHome(
            dockShelf: DockShelf.frame(),
            visibleFrame: screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900),
            primaryHeight: screen?.frame.height ?? 900)
    }

    /// Puts him back where the Dock now is.
    ///
    /// Driven two ways on purpose. The notifications — the screen changing shape, an application
    /// launching or quitting — make him respond the moment the Dock moves. The scan tick then
    /// checks again every second, because the notifications are not enough on their own: the Dock
    /// animates its resize, so a frame read the instant one arrives can catch it mid-flight, and
    /// Keeper's own icon joins the Dock as Keeper launches, widening it just after a session that
    /// started at launch worked out where he should stand. Either way he ended up a tile short
    /// with nothing left to correct him. Re-reading settles it within a second.
    private func followDock() {
        let home = Self.homePoint()          // read before the mutating call, never inside it
        guard home != lastHome else { return }
        lastHome = home
        knight?.moveHome(to: home)
    }

}
