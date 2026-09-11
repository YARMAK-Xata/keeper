import XCTest
@testable import Keeper

/// The overlay floats above everything on every Space and is 360 by 300 points of mostly empty
/// air. Deciding when it takes a click is therefore the one thing in Keeper that can make the
/// Mac itself feel broken, so the decision is a value rather than a pile of flags on a window.
final class OverlayInteractionTests: XCTestCase {
    func testClicksPassThroughWhenThePointerIsNowhereNearHim() {
        let next = OverlayInteraction.next(carrying: false, buttonsDown: false, pointerOnKnight: false)
        XCTAssertTrue(next.ignoresMouseEvents)
        XCTAssertFalse(next.carrying)
    }

    func testTheWindowTakesTheClickOnlyWhereHeIsDrawn() {
        let next = OverlayInteraction.next(carrying: false, buttonsDown: false, pointerOnKnight: true)
        XCTAssertFalse(next.ignoresMouseEvents)
    }

    /// A hand moving faster than he does leaves the pointer off him mid-carry. Letting go of the
    /// events then would drop him in place.
    func testCarryingKeepsTheWindowListeningEvenWhenThePointerRunsAhead() {
        let next = OverlayInteraction.next(carrying: true, buttonsDown: true, pointerOnKnight: false)
        XCTAssertTrue(next.carrying)
        XCTAssertFalse(next.ignoresMouseEvents)
    }

    /// The failure that matters: a mouse-up that never arrives — the button released over another
    /// app, a Space switched mid-drag — would otherwise leave the overlay holding him and
    /// swallowing every click in a 360 by 300 rectangle, with no way to get it back short of
    /// quitting Keeper. The button being up is the truth; `carrying` is only a belief.
    func testLettingGoOfTheButtonEndsTheCarryEvenWithoutAMouseUp() {
        let next = OverlayInteraction.next(carrying: true, buttonsDown: false, pointerOnKnight: false)
        XCTAssertFalse(next.carrying)
        XCTAssertTrue(next.ignoresMouseEvents, "and the window goes back to being click-through")
    }

    func testAnAbandonedCarryStillEndsWhileThePointerRestsOnHim() {
        let next = OverlayInteraction.next(carrying: true, buttonsDown: false, pointerOnKnight: true)
        XCTAssertFalse(next.carrying, "he is not being held, he is merely being pointed at")
        XCTAssertFalse(next.ignoresMouseEvents, "but he is still grabbable")
    }
}
