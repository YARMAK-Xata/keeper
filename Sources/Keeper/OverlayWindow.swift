import AppKit

/// A small, transparent, click-through window that carries the knight. It is moved every frame so the
/// knight's feet sit at `KnightFrame.position`; it floats above everything on every Space.
final class OverlayWindow: NSWindow {
    static let size = CGSize(width: 360, height: 300)
    static let feetY: CGFloat = 110                     // where the feet sit inside the window
    private let knightView = KnightView()

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
        if !isVisible { orderFrontRegardless() }
    }
}

final class KnightView: NSView {
    var knightFrame: KnightFrame? { didSet { needsDisplay = true } }
    var bubbleBelow = false

    override var isOpaque: Bool { false }

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
