import AppKit

/// The menu bar shield and the panel that hangs off it.
///
/// Left-click opens the panel, which is the whole app. Right-click opens a three-item menu —
/// Open Keeper, Settings…, Quit — which exists only as a way out: a panel that fails to appear
/// must never leave Keeper running with nothing to click.
@MainActor
final class StatusItemController {
    static let autosaveName = "Keeper"

    var onOpen: (() -> Void)?
    var onSettings: (() -> Void)?

    /// Built once by the session controller and reused, so the panel keeps its typing state
    /// between openings rather than being rebuilt under the person's cursor.
    var panelViewController: NSViewController? {
        didSet { popover.contentViewController = panelViewController }
    }

    private var item: NSStatusItem?

    private lazy var popover: NSPopover = {
        let popover = NSPopover()
        popover.behavior = .transient      // closes as soon as you click anywhere else
        popover.animates = false
        return popover
    }()

    var isVisible: Bool { item != nil }

    func setVisible(_ visible: Bool) {
        if visible { show() } else { hide() }
    }

    func closePanel() {
        popover.performClose(nil)
    }

    #if DEBUG
    /// Opens the panel without a click, so its layout can be looked at and photographed the way
    /// `KEEPER_ASSUME_TRUSTED` lets the other states be looked at. Compiled out of release builds.
    func openPanelForInspection() {
        guard let button = item?.button else { return }
        togglePanel(from: button)
    }
    #endif

    private func show() {
        guard item == nil else { return }

        // macOS puts a new status item at the left end of the row. On a Mac with a notch that can
        // land it under the notch, or left of it, where nothing is drawn at all — the item exists,
        // has a panel, and is invisible. Claiming a position on first run avoids that. The system
        // stores the person's own drag under the same key, so this only ever seeds.
        let positionKey = "NSStatusItem Preferred Position \(Self.autosaveName)"
        if UserDefaults.standard.object(forKey: positionKey) == nil {
            UserDefaults.standard.set(0, forKey: positionKey)
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = Self.autosaveName
        item.isVisible = true
        item.button?.image = Self.menuBarImage(active: false)
        item.button?.imagePosition = .imageOnly
        item.button?.toolTip = "Keeper"
        item.button?.target = self
        item.button?.action = #selector(buttonClicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        self.item = item
    }

    private func hide() {
        popover.performClose(nil)
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
    }

    /// Only the shield changes with the session now: empty while Keeper waits, filled on duty.
    /// The panel redraws itself, and the escape-hatch menu has nothing state-dependent in it.
    func update(isRunning: Bool) {
        item?.button?.image = Self.menuBarImage(active: isRunning)
    }

    // MARK: - Clicks

    @objc private func buttonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isSecondary = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true
        if isSecondary { showMenu(from: sender) } else { togglePanel(from: sender) }
    }

    private func togglePanel(from button: NSStatusBarButton) {
        guard panelViewController != nil else { return showMenu(from: button) }
        if popover.isShown { popover.performClose(nil); return }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // Without this the panel draws but its text field takes no keystrokes: a status item
        // click does not activate the app, so the popover's window never becomes key.
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func showMenu(from button: NSStatusBarButton) {
        popover.performClose(nil)
        let menu = NSMenu()
        menu.addItem(withTitle: L.t("menu.open"), action: #selector(openWindow), keyEquivalent: "").target = self
        menu.addItem(withTitle: L.t("menu.settings"), action: #selector(openSettings), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: L.t("menu.quit"), action: #selector(quit), keyEquivalent: "q").target = self
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func openWindow() { onOpen?() }
    @objc private func openSettings() { onSettings?() }
    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: - The shield

    /// A stroke drawing rather than the sprite: every other icon in the menu bar is a thin
    /// outline, and a filled 16-pixel character among them reads as a blob at any size.
    ///
    /// The shield is empty while Keeper is idle and filled like smoked glass while a session
    /// runs, so the state is legible at a glance without a second glyph or a colour.
    ///
    /// Rendered eagerly into a bitmap rather than through `NSImage`'s drawing handler: the handler
    /// is called lazily, off the main thread, and produced an empty image here — a status item
    /// that occupies space and shows nothing.
    static func menuBarImage(active: Bool, size: CGFloat = 18) -> NSImage {
        let scale: CGFloat = 2
        let side = Int(size * scale)
        let points = NSSize(width: size, height: size)

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: rep) else { return NSImage(size: points) }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let cg = context.cgContext

        // Draw in an 18-unit box with y running down, the way the shape was designed.
        let unit = size * scale / 18
        cg.scaleBy(x: unit, y: unit)
        cg.translateBy(x: 0, y: 18)
        cg.scaleBy(x: 1, y: -1)

        let shield = Self.shieldPath()

        if active {
            // A template image is tinted through its alpha, so a part-transparent fill comes out
            // as a part-transparent shield: glass rather than a solid slab.
            cg.addPath(shield)
            cg.setFillColor(NSColor.black.withAlphaComponent(0.45).cgColor)
            cg.fillPath()
        }

        cg.addPath(shield)
        cg.setStrokeColor(NSColor.black.cgColor)
        cg.setLineWidth(1.5)
        cg.setLineCap(.round)
        cg.setLineJoin(.round)
        cg.strokePath()

        NSGraphicsContext.restoreGraphicsState()

        rep.size = points
        let image = NSImage(size: points)
        image.addRepresentation(rep)
        image.isTemplate = true      // a stroke shape tints correctly on a light or dark bar
        return image
    }

    /// A heater shield in an 18-unit box, y running down.
    private static func shieldPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 9, y: 2.1))
        path.addLine(to: CGPoint(x: 14.6, y: 4.2))
        path.addLine(to: CGPoint(x: 14.6, y: 9.1))
        path.addCurve(to: CGPoint(x: 9, y: 16.2),
                      control1: CGPoint(x: 14.6, y: 12.7), control2: CGPoint(x: 12.3, y: 15.2))
        path.addCurve(to: CGPoint(x: 3.4, y: 9.1),
                      control1: CGPoint(x: 5.7, y: 15.2), control2: CGPoint(x: 3.4, y: 12.7))
        path.addLine(to: CGPoint(x: 3.4, y: 4.2))
        path.closeSubpath()
        return path
    }
}
