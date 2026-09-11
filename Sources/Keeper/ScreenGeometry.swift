import CoreGraphics

/// Accessibility and CoreGraphics report window frames with a top-left origin on the primary
/// display; AppKit uses a bottom-left origin. These convert between the two.
enum ScreenGeometry {
    static func appKitRect(fromAX rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    static func appKitPoint(fromAX point: CGPoint, primaryHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    /// Where the knight should stand for something he has been sent to: on the tab if one was
    /// found, else just inside the window's top-left corner, else where he already was.
    ///
    /// Pure, and takes `home` rather than reaching for the knight's own. It used to be a method
    /// on the session controller that read `knight?.home`, and it was called inside the argument
    /// to `knight?.dispatch(…)` — a mutating call on a struct, which holds exclusive access to
    /// that property for the whole expression. Reading it there aborted the process, every time
    /// an app was caught with no window yet published. A function that cannot see the knight
    /// cannot make that mistake again.
    static func knightTarget(tabFrame: CGRect?, windowFrame: CGRect?,
                             home: CGPoint, primaryHeight: CGFloat) -> CGPoint {
        if let tab = tabFrame {
            let r = appKitRect(fromAX: tab, primaryHeight: primaryHeight)
            return CGPoint(x: r.midX, y: r.minY)
        }
        if let window = windowFrame {
            let r = appKitRect(fromAX: window, primaryHeight: primaryHeight)
            return CGPoint(x: r.minX + 140, y: r.maxY - 40)
        }
        return home
    }

    /// Where the knight waits between errands: just past the end of the Dock, standing on it.
    ///
    /// The Dock is centred by default, so the bottom-right corner of the screen — where he used
    /// to stand — is beside it on bare desktop rather than on it, and stays put when the Dock is
    /// resized. Its shelf is measured instead, which means he moves whenever it does.
    ///
    /// `dockShelf` is the accessibility frame of the Dock's row of icons, top-left origin.
    static func knightHome(dockShelf: CGRect?, visibleFrame: CGRect, primaryHeight: CGFloat) -> CGPoint {
        if let shelf = dockShelf {
            let r = appKitRect(fromAX: shelf, primaryHeight: primaryHeight)
            // Only a Dock lying along the bottom: on the left or right edge it is tall and narrow
            // and its far end is the middle of the screen, which is no place to stand.
            if r.width > r.height, r.minY <= visibleFrame.minY {
                // Beside the Dock's right end, standing on the same ground it sits on. Putting
                // his feet on its *top* edge instead leaves him in mid-air over whatever window
                // is behind, because past the end of the Dock there is no shelf under him.
                return CGPoint(x: min(r.maxX + 26, visibleFrame.maxX - 24), y: r.minY)
            }
        }
        return CGPoint(x: visibleFrame.maxX - 140, y: visibleFrame.minY + 2)
    }

    static func roughlyEqual(_ a: CGRect, _ b: CGRect, tolerance: CGFloat) -> Bool {
        abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance
            && abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
    }
}
