import AppKit
import XCTest
@testable import Keeper

/// The spacing scale itself. These are the invariants that make it a scale rather than a
/// collection of numbers someone liked.
final class MetricsTests: XCTestCase {
    func testTheScaleClimbsInEvenSteps() {
        let scale = Metrics.Space.scale
        XCTAssertEqual(scale, scale.sorted(), "the scale is not in order")
        XCTAssertEqual(Set(scale).count, scale.count, "the scale repeats a value")
        for step in scale {
            XCTAssertEqual(step.truncatingRemainder(dividingBy: 2), 0, "\(step) is off the two-point grid")
        }
    }

    /// The panel is the tighter of the two surfaces at every level, and narrower. If that ever
    /// inverts, one of them was edited without the other being thought about.
    func testThePanelIsTighterThanTheWindow() {
        XCTAssertLessThan(Metrics.Surface.panel.width, Metrics.Surface.window.width)
        XCTAssertLessThan(Metrics.Surface.panel.margin, Metrics.Surface.window.margin)
        XCTAssertLessThan(Metrics.Surface.panel.sectionSpacing, Metrics.Surface.window.sectionSpacing)
        XCTAssertLessThanOrEqual(Metrics.Surface.panel.itemSpacing, Metrics.Surface.window.itemSpacing)
    }

    /// Every spacing a surface uses comes off the scale. A surface built from numbers that are
    /// not on it is the thing this whole file exists to prevent.
    func testBothSurfacesAreBuiltFromTheScale() {
        for (name, surface) in [("window", Metrics.Surface.window), ("panel", Metrics.Surface.panel)] {
            for (label, value) in [("margin", surface.margin),
                                   ("sectionSpacing", surface.sectionSpacing),
                                   ("itemSpacing", surface.itemSpacing)] {
                XCTAssertTrue(Metrics.Space.scale.contains(value),
                              "\(name).\(label) = \(value) is not on the scale")
            }
        }
    }

    /// A row is a row on both surfaces — the furniture is shared and only the frame around it
    /// changes — so the row metrics have to be on the scale too, and big enough for the icon.
    func testARowCanHoldItsIcon() {
        XCTAssertTrue(Metrics.Space.scale.contains(Metrics.Row.horizontalInset))
        XCTAssertTrue(Metrics.Space.scale.contains(Metrics.Row.verticalInset))
        XCTAssertTrue(Metrics.Space.scale.contains(Metrics.Row.iconGap))
        XCTAssertGreaterThanOrEqual(Metrics.Row.iconSize, 16, "smaller than an app icon renders blurry")
    }

    /// Both lists put their text in the same column: icon slot, gap, text. This is the number
    /// that makes the sites group and the apps group read as one piece of furniture.
    func testBothListsShareOneTextColumn() {
        XCTAssertEqual(Metrics.Row.textInset,
                       Metrics.Row.horizontalInset + Metrics.Row.iconSize + Metrics.Row.iconGap)
    }
}

/// Where the design system meets the seven languages: a label that does not fit its surface
/// wraps to a second line and takes the rhythm of the whole panel with it. Measured rather than
/// eyeballed, so adding an eighth language fails here instead of in front of someone.
final class TextFitsTests: XCTestCase {
    private func strings(_ language: String) throws -> [String: String] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Sources/Keeper/Resources/\(language).lproj/Localizable.strings")
        let plist = try PropertyListSerialization.propertyList(
            from: try Data(contentsOf: url), options: [], format: nil)
        return try XCTUnwrap(plist as? [String: String])
    }

    private func width(_ text: String, _ size: CGFloat) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size)]).width
    }

    /// The group labels — the longest short strings in the app — on one line in the panel.
    ///
    /// Measured while idle, which is when these are read: you set a session up, then start it.
    /// Once it is running a lock glyph joins the label and the longest of them, Russian's apps
    /// label, goes twelve points over and wraps. That is a deliberate trade: reserving room for
    /// the lock in every language would cost forty points of panel width permanently, to keep a
    /// label tidy in a state where the label no longer tells you anything you can act on.
    func testGroupLabelsFitThePanelOnOneLine() throws {
        let available = Metrics.Surface.panel.contentWidth
        for language in LocalizationTests.languages {
            let table = try strings(language)
            for key in ["list.label", "list.apps.label"] {
                let text = try XCTUnwrap(table[key])
                let needed = width(text, Metrics.Typography.secondarySize)
                XCTAssertLessThanOrEqual(needed, available,
                    "\(language) \(key) needs \(Int(needed))pt of \(Int(available))pt and will wrap")
            }
        }
    }

    /// The add row puts a field and a menu side by side. Both are body size now, and together
    /// with the row's insets they have to fit or the menu's title truncates to an ellipsis.
    func testAddRowsFitThePanel() throws {
        let available = Metrics.Surface.panel.contentWidth
        for language in LocalizationTests.languages {
            let table = try strings(language)
            for (field, menu) in [("list.add.placeholder", "quickAdd.menu"),
                                  ("list.apps.add.placeholder", "list.apps.choose")] {
                let needed = Metrics.Row.textInset
                    + width(try XCTUnwrap(table[field]), Metrics.Typography.bodySize)
                    + Metrics.Row.iconGap
                    + width(try XCTUnwrap(table[menu]), Metrics.Typography.bodySize)
                    + Metrics.menuChevronWidth
                    + Metrics.Row.horizontalInset
                XCTAssertLessThanOrEqual(needed, available,
                    "\(language) \(field) + \(menu) needs \(Int(needed))pt of \(Int(available))pt")
            }
        }
    }

    /// The panel's links wrap to a second row when they have to, so the row itself may overflow —
    /// but a single link that cannot fit on a line of its own has nowhere left to go.
    func testNoSingleLinkIsWiderThanThePanel() throws {
        let available = Metrics.Surface.panel.contentWidth
        for language in LocalizationTests.languages {
            let table = try strings(language)
            for key in ["menu.open", "menu.settings", "menu.quit"] {
                let needed = width(try XCTUnwrap(table[key]), Metrics.Typography.secondarySize)
                XCTAssertLessThanOrEqual(needed, available, "\(language) \(key) cannot fit on any line")
            }
        }
    }

    /// The window is the roomy surface: everything that fits the panel fits here with margin to
    /// spare, and the one-line strings should never come close.
    func testTheWindowHasRoomForEveryLanguage() throws {
        let available = Metrics.Surface.window.contentWidth
        for language in LocalizationTests.languages {
            let table = try strings(language)
            for (key, text) in table where !text.contains(" ") || text.count < 40 {
                let needed = width(text, Metrics.Typography.bodySize) + Metrics.Row.textInset
                XCTAssertLessThanOrEqual(needed, available, "\(language) \(key) overflows the window")
            }
        }
    }
}
