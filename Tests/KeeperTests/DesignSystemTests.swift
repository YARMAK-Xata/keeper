import XCTest
@testable import Keeper

/// A design system is only a system while everything goes through it. This reads the views and
/// fails if one of them writes a measurement down instead of naming one — which is how the window
/// and the panel came to hold two different sets of numbers for the same three relationships in
/// the first place.
final class DesignSystemTests: XCTestCase {
    private static let views = ["MainView", "PanelView", "SharedViews", "AppListView",
                                "TaskSection", "SettingsView"]

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// A literal zero is not a measurement — `spacing: 0` says "these touch", and there is no
    /// token that could say it more clearly.
    private static let patterns = [
        #"spacing:\s*([1-9]\d*)"#,
        #"\.padding\(\s*([1-9]\d*)\s*\)"#,
        #"\.padding\(\.\w+,\s*([1-9]\d*)\)"#,
        #"cornerRadius:\s*([1-9]\d*)"#,
        #"\.frame\(\s*(?:width|height):\s*([1-9]\d*)"#,
        #"\.font\(\.system\(size:\s*([1-9]\d*)"#,
    ]

    func testNoViewWritesDownAMeasurement() throws {
        var offences: [String] = []
        for view in Self.views {
            let url = Self.root.appending(path: "Sources/Keeper/\(view).swift")
            let text = try String(contentsOf: url, encoding: .utf8)
            for pattern in Self.patterns {
                let regex = try NSRegularExpression(pattern: pattern)
                for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                    let whole = String(text[Range(match.range, in: text)!])
                    let line = text[..<text.index(text.startIndex, offsetBy: match.range.location)]
                        .components(separatedBy: "\n").count
                    offences.append("\(view).swift:\(line)  \(whole)")
                }
            }
        }
        XCTAssertEqual(offences, [], "these should name a value in Metrics rather than write one down")
    }

    /// Both surfaces must actually read the tokens, or the test above passes on a file that
    /// simply has no layout left in it.
    func testBothSurfacesReadTheirMetrics() throws {
        for view in ["MainView", "PanelView"] {
            let text = try String(contentsOf: Self.root.appending(path: "Sources/Keeper/\(view).swift"),
                                  encoding: .utf8)
            XCTAssertTrue(text.contains("surface.width"), "\(view) does not take its width from Metrics")
            XCTAssertTrue(text.contains("surface.margin"), "\(view) does not take its margin from Metrics")
            XCTAssertTrue(text.contains("surface.sectionSpacing"),
                          "\(view) does not take its rhythm from Metrics")
        }
    }

    /// The scrolling cap and the row count that triggers it are derived from one another, so a
    /// list can never scroll at a height that shows a different number of rows than it promised.
    func testTheScrollCapShowsExactlyTheRowsItAllows() {
        XCTAssertEqual(Metrics.Group.scrollHeight,
                       Metrics.Group.rowHeight * CGFloat(Metrics.Group.maxVisibleRows))
    }
}
