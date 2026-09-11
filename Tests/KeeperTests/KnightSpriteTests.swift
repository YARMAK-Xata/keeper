import XCTest
@testable import Keeper

final class KnightSpriteTests: XCTestCase {
    func testSheetDecodesTo512Square() {
        let image = KnightSprite.shared.image
        XCTAssertEqual(image.size, CGSize(width: 512, height: 512))
    }

    func testSourceRectsPickTheRightRowBottomUp() {
        let s = KnightSprite.shared
        XCTAssertEqual(s.sourceRect(.idle, frame: 0), CGRect(x: 0, y: 448, width: 64, height: 64))
        XCTAssertEqual(s.sourceRect(.run, frame: 7), CGRect(x: 448, y: 384, width: 64, height: 64))
        XCTAssertEqual(s.sourceRect(.attack, frame: 2), CGRect(x: 128, y: 192, width: 64, height: 64))
    }

    func testDrawingPutsFeetAtTheAnchor() {
        // Render idle frame 0 into a 192x192 bitmap with feet at (96, 48); the lowest opaque pixel must sit at y≈48.
        let size = 192
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        KnightSprite.shared.draw(KnightFrame(position: .zero, animation: .idle, frameIndex: 0, facingLeft: false, message: nil), at: CGPoint(x: 96, y: 48))
        NSGraphicsContext.restoreGraphicsState()
        var lowestOpaqueRowFromTop = -1
        for y in (0..<size).reversed() where lowestOpaqueRowFromTop < 0 {
            for x in 0..<size where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 { lowestOpaqueRowFromTop = y; break }
        }
        XCTAssertEqual(size - 1 - lowestOpaqueRowFromTop, 48, accuracy: 3)
    }
}

extension KnightSpriteTests {
    private func coverage(_ image: NSImage) throws -> Double {
        let rep = try XCTUnwrap(image.representations.first as? NSBitmapImageRep)
        var ink = 0.0
        for x in 0..<rep.pixelsWide {
            for y in 0..<rep.pixelsHigh {
                ink += Double(rep.colorAt(x: x, y: y)?.alphaComponent ?? 0)
            }
        }
        return ink / Double(rep.pixelsWide * rep.pixelsHigh)
    }

    /// Two states, one shape: an empty shield while Keeper waits, a glass-filled one while it
    /// works. A blank icon would leave a status item that takes up space and shows nothing.
    @MainActor
    func testMenuBarIconsDifferByFillNotByShape() throws {
        let idle = StatusItemController.menuBarImage(active: false)
        let onDuty = StatusItemController.menuBarImage(active: true)

        for image in [idle, onDuty] {
            XCTAssertTrue(image.isTemplate, "a stroke shape should tint with the menu bar")
            XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
        }

        let idleInk = try coverage(idle)
        let onDutyInk = try coverage(onDuty)
        XCTAssertGreaterThan(idleInk, 0.05, "the idle icon came out blank")
        XCTAssertGreaterThan(onDutyInk, idleInk * 1.5, "the on-duty shield should read as filled")
        XCTAssertLessThan(onDutyInk, 0.5, "the fill should look like glass, not a solid slab")
    }

    // MARK: - The part of him you can pick up

    /// The overlay window is 360 by 300 and almost all of it is empty air over the Dock. Only
    /// the drawn character may take a click; everything else has to stay click-through, or
    /// standing beside the Dock would mean standing on top of it.
    func testTheGrabBoxIsTheDrawnCharacterAndNotTheWindow() {
        let feet = CGPoint(x: 200, y: 50)
        let box = KnightSprite.grabBox(feetAt: feet)

        XCTAssertTrue(box.contains(CGPoint(x: 200, y: 90)), "his chest is him")
        XCTAssertTrue(box.contains(CGPoint(x: 200, y: 52)), "just above his feet is him")
        XCTAssertFalse(box.contains(CGPoint(x: 200, y: 40)), "below his feet is the Dock, not him")
        XCTAssertFalse(box.contains(CGPoint(x: 120, y: 90)), "the empty margin of the window is not him")
        XCTAssertFalse(box.contains(CGPoint(x: 200, y: 200)), "the speech bubble is not him")
    }

    /// Grown or shrunk, the box is whatever is actually on screen — it is measured from the same
    /// character bounds and scale the drawing uses, never written down a second time.
    func testTheGrabBoxMatchesTheDrawnSize() {
        let box = KnightSprite.grabBox(feetAt: .zero)
        XCTAssertEqual(box.width, KnightSprite.characterBox.width * KnightSprite.scale)
        XCTAssertEqual(box.height, KnightSprite.characterBox.height * KnightSprite.scale)
        XCTAssertEqual(box.midX, 0, accuracy: 0.001, "he is centred on his feet")
        XCTAssertEqual(box.minY, 0, accuracy: 0.001, "and stands on them")
    }
}
