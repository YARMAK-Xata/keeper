import AppKit

/// The embedded rgsdev sheet: 8×8 cells of 64 px; the 16 px character stands with its feet at `anchor`.
final class KnightSprite {
    static let shared = KnightSprite()
    static let cell: CGFloat = 64
    static let scale: CGFloat = 3
    static let anchor = CGPoint(x: 32, y: 16)        // feet centre, bottom-left cell coordinates
    static let characterHeight: CGFloat = 30         // cell units from feet to the top of the helmet

    let image: NSImage

    private init() {
        guard let data = Data(base64Encoded: knightSheetBase64), let image = NSImage(data: data) else {
            fatalError("Embedded knight sheet is corrupt")
        }
        self.image = image
    }

    static func row(for animation: KnightAnimation) -> Int {
        switch animation {
        case .idle: return 0
        case .run: return 1
        case .attack: return 4
        }
    }

    /// Tight bounds of the character inside a 64 px cell, in bottom-left cell coordinates.
    /// Used where the knight stands alone — the window header and the menu bar — so the
    /// empty margin of the cell does not push him around.
    static let characterBox = CGRect(x: 22, y: 16, width: 20, height: 26)

    /// The character with the empty margin trimmed away: 16 by 22 sprite pixels. Used where the
    /// knight has to be as large as the space allows, which is the menu bar.
    static let characterTightBox = CGRect(x: 24, y: 16, width: 16, height: 22)

    /// Draws just the character, unsmoothed, scaled to fill `rect`.
    func drawCharacter(_ animation: KnightAnimation, frame: Int, in rect: CGRect,
                       box: CGRect = KnightSprite.characterBox) {
        let cell = sourceRect(animation, frame: frame)
        let source = CGRect(x: cell.minX + box.minX, y: cell.minY + box.minY,
                            width: box.width, height: box.height)
        NSGraphicsContext.current?.imageInterpolation = .none
        image.draw(in: rect, from: source, operation: .sourceOver, fraction: 1,
                   respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none])
    }

    /// Source rectangle in NSImage (bottom-left origin) coordinates.
    func sourceRect(_ animation: KnightAnimation, frame: Int) -> CGRect {
        let rows = image.size.height / Self.cell
        let row = CGFloat(Self.row(for: animation))
        return CGRect(x: CGFloat(frame) * Self.cell, y: (rows - 1 - row) * Self.cell, width: Self.cell, height: Self.cell)
    }

    /// Draws one frame, scaled and unsmoothed, so the character's feet land on `feet` in the current context.
    func draw(_ frame: KnightFrame, at feet: CGPoint) {
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        defer { context.restoreGraphicsState() }
        context.imageInterpolation = .none
        let cg = context.cgContext
        cg.interpolationQuality = .none
        cg.translateBy(x: feet.x, y: feet.y)
        if frame.facingLeft { cg.scaleBy(x: -1, y: 1) }
        cg.translateBy(x: -Self.anchor.x * Self.scale, y: -Self.anchor.y * Self.scale)
        let size = Self.cell * Self.scale
        image.draw(in: CGRect(x: 0, y: 0, width: size, height: size),
                   from: sourceRect(frame.animation, frame: frame.frameIndex),
                   operation: .sourceOver, fraction: 1, respectFlipped: true,
                   hints: [.interpolation: NSImageInterpolation.none])
    }
}
