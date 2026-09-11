import AppKit
import ApplicationServices

/// Where the Dock's row of icons is, read from its accessibility tree.
///
/// The Dock's *window* is no help: it is a full-screen transparent overlay, so its bounds are the
/// whole display whatever the Dock looks like. The row of icons is a list inside it, and that
/// does have the frame we want — which is how the knight knows where to stand and, more to the
/// point, knows when it has moved.
@MainActor
enum DockShelf {
    /// The icon row's frame in accessibility coordinates (top-left origin), or nil when the Dock
    /// is hidden, on another display, or simply will not answer.
    static func frame() -> CGRect? {
        guard let dock = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.dock").first else { return nil }
        let app = AXElement.application(pid: dock.processIdentifier)
        app.setTimeout(0.3)          // the Dock is never slow, but never block the main thread on it
        guard let list = app.children.first(where: { $0.role == kAXListRole }) else { return nil }
        guard let frame = list.frame, frame.width > 1, frame.height > 1 else { return nil }
        return frame
    }
}
