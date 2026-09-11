import AppKit
import SwiftUI

/// The knight standing in a header, idling. He is the session indicator, not an ornament: he is
/// on screen in every state and his animation is the only thing moving.
///
/// Drawn from the tight box — the character with the sprite cell's empty margin trimmed off — so
/// the frame it is given is the frame he fills, at whatever size the surface asks for.
struct KnightBadge: NSViewRepresentable {
    var box: CGRect = KnightSprite.characterTightBox

    func makeNSView(context: Context) -> KnightBadgeView { KnightBadgeView(box: box) }
    func updateNSView(_ view: KnightBadgeView, context: Context) { view.box = box }
}

final class KnightBadgeView: NSView {
    var box: CGRect { didSet { needsDisplay = true } }
    private var timer: Timer?
    private var frameIndex = 0

    init(box: CGRect) {
        self.box = box
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var intrinsicContentSize: NSSize {
        NSSize(width: box.width * 2, height: box.height * 2)
    }

    override var isFlipped: Bool { false }

    /// Animate only while on screen, so a closed window and a shut panel cost nothing.
    override func viewDidMoveToWindow() {
        timer?.invalidate()
        guard window != nil else { timer = nil; return }
        let timer = Timer(timeInterval: 1.0 / Knight.idleFPS, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.frameIndex = (self.frameIndex + 1) % Knight.idleFrames
            self.needsDisplay = true
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    override func draw(_ dirtyRect: NSRect) {
        KnightSprite.shared.drawCharacter(.idle, frame: frameIndex, in: bounds, box: box)
    }
}
