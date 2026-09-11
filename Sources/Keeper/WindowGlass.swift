import AppKit
import SwiftUI

/// The window's glass.
///
/// macOS draws a window's title bar as a translucent material and, by default, the rest of the
/// window as a flat colour. In a window this small the two read as two surfaces with a step
/// between them. This puts a material behind the whole window and takes the separator out, so
/// there is one surface.
///
/// `.containerBackground(.bar, for: .window)` says this in one line, but it is macOS 15 and
/// Keeper still runs on 14.
///
/// Three details were each arrived at by measuring the result against the bar above it:
///
/// - `.windowBackground` rather than `.titlebar`. The obvious choice is the material the bar
///   itself uses, but in the content area it renders about 8% lighter than the bar does; the
///   window background material lands within a couple of per cent.
/// - The state is left at `.followsWindowActiveState`. Forcing it active keeps the body vivid
///   while the bar above dims with the rest of the window, which is the most visible mismatch
///   of the lot.
/// - The window's own background is cleared. While it is opaque the bar composites over it
///   instead of over what is behind the window, and comes out a different shade again.
struct WindowGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView { GlassView() }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}

    private final class GlassView: NSVisualEffectView {
        override init(frame: NSRect) {
            super.init(frame: frame)
            material = .windowBackground
            blendingMode = .behindWindow
        }

        required init?(coder: NSCoder) { fatalError("not used") }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarSeparatorStyle = .none
        }
    }
}
