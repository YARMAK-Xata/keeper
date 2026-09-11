import CoreGraphics
import SwiftUI

/// Every measurement in Keeper.
///
/// The window and the menu bar panel are the same furniture at two sizes. That was the intent
/// from the start, but each surface carried its own literals — 20/16/12 in one file, 14/12/10 in
/// the other — for the same three relationships, so "the same" was only ever true until someone
/// edited one of them. The numbers live here now and the surfaces read them, which is what makes
/// the claim enforceable rather than aspirational.
///
/// The split is deliberate: a **surface** has a width and a rhythm, and the two differ. A **row**
/// does not — a row is a row, and both surfaces draw the identical one. So the density knob turns
/// the frame around the content, never the content itself.
enum Metrics {
    /// The scale. Two points, stepping wider as the gaps grow: nothing in Keeper is spaced by a
    /// number that is not on this list, and the tests fail if a surface invents one.
    enum Space {
        /// Between a title and the line under it — enough to separate, not enough to divide.
        static let hair: CGFloat = 2
        /// Inside a label, and either side of a glyph.
        static let tight: CGFloat = 4
        /// The height a list row breathes by.
        static let snug: CGFloat = 6
        /// Between a control and the thing it belongs to.
        static let step: CGFloat = 8
        /// Between rows of different things; the panel's margin.
        static let gap: CGFloat = 12
        /// Between one section of a surface and the next.
        static let section: CGFloat = 16
        /// The window's margin.
        static let margin: CGFloat = 20

        static let scale: [CGFloat] = [hair, tight, snug, step, gap, section, margin]
    }

    /// The type ramp. Three sizes, and every piece of text is one of them.
    ///
    /// The sizes are named separately from the fonts because the tests measure strings with
    /// `NSFont` to check they fit, and measuring against a number the views do not use would
    /// prove nothing.
    enum Typography {
        static let titleSize: CGFloat = 14
        static let bodySize: CGFloat = 13
        static let secondarySize: CGFloat = 12

        /// The state — "Ready", "On duty since 14:22". The only bold thing on the surface.
        static var title: Font { .system(size: titleSize, weight: .semibold) }
        /// Anything you read to act on it: a site, an app's name, the permission sentence.
        static var body: Font { .body }
        /// Anything you read to understand the thing next to it: group labels, the event line,
        /// the hint under a disabled button, the panel's links.
        static var secondary: Font { .callout }
    }

    /// A row in either list. Shared between the two surfaces and between the two lists, which is
    /// the whole point: a site and an app sit in the same-shaped row with their text in the same
    /// column, so the two groups read as one piece of furniture rather than two.
    enum Row {
        /// An app's own icon, and the glyph that stands in the same slot for a site.
        static let iconSize: CGFloat = 16
        static let iconGap = Space.step
        static let horizontalInset = Space.gap
        static let verticalInset = Space.snug

        /// Where the text column starts, measured from the inside edge of the group's box.
        /// Every row on both surfaces begins its text here — including the add row, whose plus
        /// sits in the same icon slot rather than leaving the column ragged.
        static var textInset: CGFloat { horizontalInset + iconSize + iconGap }
    }

    /// The rounded box a list sits in, the gap between its label and its top edge, and the
    /// point at which it starts scrolling instead of growing.
    enum Group {
        static let cornerRadius: CGFloat = 8
        static let labelGap = Space.snug

        /// Past this many entries the list would push the button off a short screen, so it
        /// scrolls instead.
        static let maxVisibleRows = 8

        /// A row's full height: the icon slot, plus the padding above and below it. Body text at
        /// thirteen points sets the same line height, so the two agree.
        static var rowHeight: CGFloat { Row.iconSize + Row.verticalInset * 2 }

        /// The height the scrolling list is capped at. Derived from the row count rather than
        /// written down beside it, so the cap and the threshold cannot come to disagree — which
        /// is what a hard-coded 240 next to a hard-coded 8 was always going to do.
        static var scrollHeight: CGFloat { rowHeight * CGFloat(maxVisibleRows) }
    }

    /// A borderless menu draws a chevron after its title. Sizing an add row without counting it
    /// is how the menu's title ends up truncated at the exact moment the row looks fine in
    /// English — so the tests count it.
    static let menuChevronWidth: CGFloat = 16

    /// A surface is a width and a rhythm. There are two.
    struct Surface: Equatable {
        let width: CGFloat
        /// The margin all the way round.
        let margin: CGFloat
        /// Between the header, the task, and the links.
        let sectionSpacing: CGFloat
        /// Between the pieces of the task: the two groups, the event line, the button.
        let itemSpacing: CGFloat

        /// What a label actually has to fit inside.
        var contentWidth: CGFloat { width - margin * 2 }

        /// The window: room to read, and the surface someone sets up their session in.
        static let window = Surface(width: 420, margin: Space.margin,
                                    sectionSpacing: Space.section, itemSpacing: Space.gap)

        /// The panel under the shield: the same thing, closer together, because it hangs off the
        /// menu bar and a tall popover reaches the bottom of a laptop screen.
        ///
        /// 340 rather than the 300 it was, and the width was measured rather than chosen. The
        /// group labels are the longest short strings in the app, and the Russian pair —
        /// "Программы, которые вы не откроете в этой сессии" — needs 304 points. At 300 it wrapped
        /// to a second line and pushed the whole panel down; 340 leaves it twelve points of air.
        /// The window stays wider still, so the panel is plainly the compact one.
        static let panel = Surface(width: 340, margin: Space.gap,
                                   sectionSpacing: Space.gap, itemSpacing: Space.step)
    }
}
