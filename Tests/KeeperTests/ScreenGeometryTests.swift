import XCTest
@testable import Keeper

final class ScreenGeometryTests: XCTestCase {
    func testConvertsTopLeftRectToBottomLeft() {
        let ax = CGRect(x: 100, y: 50, width: 300, height: 20)        // 50 pt below the top edge
        let ak = ScreenGeometry.appKitRect(fromAX: ax, primaryHeight: 1000)
        XCTAssertEqual(ak, CGRect(x: 100, y: 930, width: 300, height: 20))
    }

    func testConvertsPoint() {
        XCTAssertEqual(ScreenGeometry.appKitPoint(fromAX: CGPoint(x: 10, y: 0), primaryHeight: 1000), CGPoint(x: 10, y: 1000))
    }

    func testRoughEqualityTolerance() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertTrue(ScreenGeometry.roughlyEqual(a, CGRect(x: 1, y: -1, width: 101, height: 99), tolerance: 2))
        XCTAssertFalse(ScreenGeometry.roughlyEqual(a, CGRect(x: 5, y: 0, width: 100, height: 100), tolerance: 2))
    }
}

/// Where the knight is sent.
///
/// This lived on `SessionController` as a method that read `knight?.home` for its fallback, and
/// was called inside the argument to `knight?.dispatch(…)`. `Knight` is a struct, so that call
/// holds an exclusive modify access to the property while the argument is evaluated — and the
/// fallback read the same property. Swift's exclusivity check aborted the process.
///
/// It only fired when there was no window to walk to, which is exactly what a just-launched app
/// looks like: opening Spotify crashed Keeper every time. Taking the home point as a parameter
/// is what makes the whole class of bug impossible, and what makes it testable at all.
final class KnightTargetTests: XCTestCase {
    private let home = CGPoint(x: 1300, y: 2)
    private let height: CGFloat = 1000

    func testWalksToTheTabWhenThereIsOne() {
        let tab = CGRect(x: 200, y: 80, width: 120, height: 24)       // top-left origin
        let point = ScreenGeometry.knightTarget(tabFrame: tab, windowFrame: nil,
                                                home: home, primaryHeight: height)
        XCTAssertEqual(point, CGPoint(x: 260, y: 896), "the middle of the tab's bottom edge")
    }

    func testWalksToTheWindowWhenThereIsNoTab() {
        let window = CGRect(x: 400, y: 100, width: 800, height: 600)
        let point = ScreenGeometry.knightTarget(tabFrame: nil, windowFrame: window,
                                                home: home, primaryHeight: height)
        XCTAssertEqual(point, CGPoint(x: 540, y: 860), "inside the window's top-left corner")
    }

    /// The case that crashed: an app still opening has published no window yet.
    func testStaysHomeWhenThereIsNothingToWalkTo() {
        XCTAssertEqual(ScreenGeometry.knightTarget(tabFrame: nil, windowFrame: nil,
                                                   home: home, primaryHeight: height), home)
    }

    func testATabIsPreferredOverTheWindowAroundIt() {
        let tab = CGRect(x: 200, y: 80, width: 120, height: 24)
        let window = CGRect(x: 0, y: 0, width: 900, height: 700)
        let point = ScreenGeometry.knightTarget(tabFrame: tab, windowFrame: window,
                                                home: home, primaryHeight: height)
        XCTAssertEqual(point, CGPoint(x: 260, y: 896))
    }
}

/// Where the knight waits between errands.
///
/// He used to stand at the bottom-right corner of the screen, which is only the Dock's corner if
/// the Dock happens to fill the width. On this Mac the Dock is centred and ends two hundred
/// points short of the edge, so he stood beside it on bare desktop — and stayed there when the
/// Dock was resized underneath him.
final class KnightHomeTests: XCTestCase {
    private let screenHeight: CGFloat = 967
    private let visible = CGRect(x: 0, y: 62, width: 1496, height: 876)

    /// The measured Dock on this Mac: centred, 838 wide, its top edge 66 points up.
    private let centredDock = CGRect(x: 329, y: 901, width: 838, height: 56)

    func testStandsBesideTheDockOnTheGroundItSitsOn() {
        let home = ScreenGeometry.knightHome(dockShelf: centredDock, visibleFrame: visible,
                                             primaryHeight: screenHeight)
        XCTAssertEqual(home.y, 10, "the Dock's own baseline, not its top edge — past its end "
                       + "there is no shelf under him and he would hang in the air")
        XCTAssertEqual(home.x, 1193, "just clear of the last icon, not on top of it")
    }

    /// A wider Dock pushes him along; a narrower one brings him back. This is the whole point.
    func testFollowsTheDockWhenItIsResized() {
        let bigger = CGRect(x: 240, y: 872, width: 1016, height: 85)
        let smaller = CGRect(x: 430, y: 921, width: 636, height: 36)
        let a = ScreenGeometry.knightHome(dockShelf: bigger, visibleFrame: visible, primaryHeight: screenHeight)
        let b = ScreenGeometry.knightHome(dockShelf: smaller, visibleFrame: visible, primaryHeight: screenHeight)
        XCTAssertGreaterThan(a.x, b.x, "a bigger Dock reaches further right and he goes with it")
        XCTAssertEqual(a.y, b.y, "the Dock's base is the same height off the screen whatever its size")
    }

    /// A Dock crowded with icons runs to the screen edge; he must not walk off it.
    func testNeverLeavesTheScreen() {
        let huge = CGRect(x: 0, y: 901, width: 1496, height: 56)
        let home = ScreenGeometry.knightHome(dockShelf: huge, visibleFrame: visible, primaryHeight: screenHeight)
        XCTAssertLessThanOrEqual(home.x, visible.maxX - 24)
    }

    /// On the left or right edge the Dock is tall and narrow, and its far edge is the middle of
    /// the screen — no place to stand. The old bottom-right corner is the honest answer there.
    func testFallsBackForASideDock() {
        let sideDock = CGRect(x: 0, y: 300, width: 70, height: 400)
        let sideVisible = CGRect(x: 70, y: 0, width: 1426, height: 938)
        let home = ScreenGeometry.knightHome(dockShelf: sideDock, visibleFrame: sideVisible,
                                             primaryHeight: screenHeight)
        XCTAssertEqual(home, CGPoint(x: sideVisible.maxX - 140, y: sideVisible.minY + 2))
    }

    /// Hidden, or an accessibility read that came back empty.
    func testFallsBackWhenThereIsNoDockToFind() {
        let home = ScreenGeometry.knightHome(dockShelf: nil, visibleFrame: visible, primaryHeight: screenHeight)
        XCTAssertEqual(home, CGPoint(x: visible.maxX - 140, y: visible.minY + 2))
    }
}
