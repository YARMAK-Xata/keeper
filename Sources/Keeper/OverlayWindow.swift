import AppKit

/// What the overlay does with the pointer this frame: whether it is still holding the knight, and
/// whether clicks go through it to whatever is behind.
///
/// Pulled out of the window because the window floats above everything on every Space, so getting
/// this wrong does not produce a Keeper bug, it produces a Mac that will not take a click.
struct OverlayInteraction: Equatable {
    var carrying: Bool
    var ignoresMouseEvents: Bool

    /// `buttonsDown` is the truth and `carrying` is only a belief. A mouse-up can fail to arrive
    /// — released over another app, a Space switched mid-drag — and a window that went on
    /// believing would hold the knight and swallow every click in its 360 by 300 rectangle until
    /// Keeper was quit. So the carry lasts exactly as long as a button is actually held.
    static func next(carrying: Bool, buttonsDown: Bool, pointerOnKnight: Bool) -> OverlayInteraction {
        let stillCarrying = carrying && buttonsDown
        return OverlayInteraction(carrying: stillCarrying,
                                  ignoresMouseEvents: !(stillCarrying || pointerOnKnight))
    }
}

/// A small, transparent, click-through window that carries the knight. It is moved every frame so the
/// knight's feet sit at `KnightFrame.position`; it floats above everything on every Space.
///
/// Click-through *except* on the knight himself. The window is 360 by 300 and he occupies 60 by
/// 78 of it; the rest is empty air over the Dock and whatever is behind it, and a window that
/// took clicks across all of it would be a window that took the Dock's. So the pass-through is
/// switched off only while the pointer is inside his own outline, which `render` re-checks every
/// frame — the knight moves, so the hole in the window has to move with him.
final class OverlayWindow: NSWindow {
    static let size = CGSize(width: 360, height: 300)
    static let feetY: CGFloat = 110                     // where the feet sit inside the window

    /// Someone pressed on him. Returns whether he allowed himself to be picked up; a refusal
    /// leaves the press alone.
    var onGrab: (() -> Bool)?
    /// Where he is being carried to, in screen coordinates, with the grab offset already applied
    /// so he does not jump to the pointer on the first move.
    var onCarry: ((CGPoint) -> Void)?
    var onRelease: (() -> Void)?

    private let knightView = KnightView()
    private var carrying = false
    private var grabOffset = CGVector.zero
    private var feet = CGPoint.zero

    init() {
        super.init(contentRect: CGRect(origin: .zero, size: Self.size), styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        animationBehavior = .none
        contentView = knightView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func render(_ frame: KnightFrame) {
        let origin = CGPoint(x: frame.position.x - Self.size.width / 2, y: frame.position.y - Self.feetY)
        let screen = NSScreen.screens.first { $0.frame.contains(frame.position) } ?? NSScreen.screens.first
        let topOfBubble = frame.position.y + (KnightSprite.characterHeight * KnightSprite.scale) + 70
        knightView.bubbleBelow = screen.map { topOfBubble > $0.frame.maxY } ?? false
        setFrameOrigin(origin)
        knightView.knightFrame = frame
        feet = frame.position

        let next = OverlayInteraction.next(
            carrying: carrying,
            buttonsDown: NSEvent.pressedMouseButtons != 0,
            pointerOnKnight: KnightSprite.grabBox(feetAt: feet).contains(NSEvent.mouseLocation))
        // A carry that ended without a mouse-up still has to put him down.
        if carrying, !next.carrying { onRelease?() }
        carrying = next.carrying
        ignoresMouseEvents = next.ignoresMouseEvents

        if !isVisible { orderFrontRegardless() }
    }

    // MARK: - Being picked up

    override func mouseDown(with event: NSEvent) {
        guard onGrab?() == true else { return }
        carrying = true
        // He is picked up by the point you grabbed, not by his feet, so he does not snap to the
        // pointer the moment you press.
        let mouse = NSEvent.mouseLocation
        grabOffset = CGVector(dx: feet.x - mouse.x, dy: feet.y - mouse.y)
    }

    override func mouseDragged(with event: NSEvent) {
        guard carrying else { return }
        let mouse = NSEvent.mouseLocation
        onCarry?(CGPoint(x: mouse.x + grabOffset.dx, y: mouse.y + grabOffset.dy))
    }

    override func mouseUp(with event: NSEvent) {
        guard carrying else { return }
        carrying = false
        onRelease?()
    }
}

final class KnightView: NSView {
    var knightFrame: KnightFrame? { didSet { needsDisplay = true } }
    var bubbleBelow = false

    override var isOpaque: Bool { false }

    /// Keeper is almost never the frontmost app while he is on duty, and without this the first
    /// click on him would be spent activating Keeper rather than picking him up.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let frame = knightFrame else { return }
        let feet = CGPoint(x: bounds.midX, y: OverlayWindow.feetY)
        KnightSprite.shared.draw(frame, at: feet)
        guard let message = frame.message else { return }
        let headTop = feet.y + KnightSprite.characterHeight * KnightSprite.scale
        drawBubble(message, tip: CGPoint(x: feet.x, y: bubbleBelow ? feet.y - 6 : headTop + 6), below: bubbleBelow)
    }

    private func drawBubble(_ text: String, tip: CGPoint, below: Bool) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.black,
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let textSize = string.size()
        let pad: CGFloat = 8, tail: CGFloat = 8
        let boxSize = CGSize(width: textSize.width + pad * 2, height: textSize.height + pad * 2)
        var box = CGRect(x: tip.x - boxSize.width / 2,
                         y: below ? tip.y - tail - boxSize.height : tip.y + tail,
                         width: boxSize.width, height: boxSize.height)
        box.origin.x = max(4, min(box.origin.x, bounds.width - box.width - 4))
        let bubble = NSBezierPath(roundedRect: box, xRadius: 6, yRadius: 6)
        let pointer = NSBezierPath()
        let baseY = below ? box.maxY : box.minY
        pointer.move(to: CGPoint(x: tip.x - 6, y: baseY))
        pointer.line(to: tip)
        pointer.line(to: CGPoint(x: tip.x + 6, y: baseY))
        pointer.close()
        NSColor.white.setFill()
        bubble.fill()
        pointer.fill()
        NSColor.black.setStroke()
        bubble.lineWidth = 2
        bubble.stroke()
        string.draw(at: CGPoint(x: box.minX + pad, y: box.minY + pad))
    }
}
