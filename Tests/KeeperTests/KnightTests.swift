import XCTest
@testable import Keeper

final class KnightTests: XCTestCase {
    func testStartsIdleAtHome() {
        let k = Knight(home: CGPoint(x: 100, y: 10))
        let f = k.frame(now: 0)
        XCTAssertEqual(f.position, CGPoint(x: 100, y: 10))
        XCTAssertEqual(f.animation, .idle)
        XCTAssertNil(f.message)
        XCTAssertFalse(k.isBusy)
    }

    func testRunsToTargetStrikesOnceThenReturnsHome() {
        var k = Knight(home: CGPoint(x: 0, y: 0))
        k.dispatch(to: KnightTarget(point: CGPoint(x: 1000, y: 0), message: "Are you trying to enter youtube.com?"))
        XCTAssertTrue(k.isBusy)
        XCTAssertEqual(k.frame(now: 0).message, "Are you trying to enter youtube.com?")

        var now: TimeInterval = 0
        var strikes = 0, arrivals = 0
        var sawAttackAtTarget = false
        _ = k.update(now: now)
        // Long enough for the round trip at whatever pace he walks, plus the strike.
        let ticks = Int(60 * (2 * 1000 / Double(Knight.speed) + 2))
        for _ in 0..<ticks {
            now += 1.0 / 60
            for e in k.update(now: now) {
                if e == .strike { strikes += 1 }
                if e == .arrivedHome { arrivals += 1 }
            }
            let f = k.frame(now: now)
            if abs(now - 1.0) < 0.01 {
                XCTAssertEqual(f.animation, .run)
                XCTAssertFalse(f.facingLeft)
                XCTAssertEqual(f.position.x, Knight.speed, accuracy: 20, "one second of walking is one second of speed")
            }
            if f.animation == .attack {
                sawAttackAtTarget = true
                XCTAssertEqual(f.position, CGPoint(x: 1000, y: 0))
                XCTAssertNotNil(f.message)
            }
        }
        XCTAssertTrue(sawAttackAtTarget)
        XCTAssertEqual(strikes, 1)
        XCTAssertEqual(arrivals, 1)
        XCTAssertFalse(k.isBusy)
        XCTAssertEqual(k.frame(now: now).position, .zero)
        XCTAssertNil(k.frame(now: now).message)
    }

    func testFacesLeftWhenTargetIsLeftAndRightWhenGoingHome() {
        var k = Knight(home: CGPoint(x: 500, y: 0))
        k.dispatch(to: KnightTarget(point: CGPoint(x: 0, y: 0), message: "x"))
        _ = k.update(now: 0)
        _ = k.update(now: 0.1)
        XCTAssertTrue(k.frame(now: 0.1).facingLeft)
        var now: TimeInterval = 0.1
        var sawAttack = false
        while true {
            now += 1.0 / 60; _ = k.update(now: now)
            let f = k.frame(now: now)
            if f.animation == .attack { sawAttack = true }
            if sawAttack, f.animation == .run { break }          // the trip home
            if now > 30 { XCTFail("never started home"); return }
        }
        XCTAssertFalse(k.frame(now: now).facingLeft)
    }

    func testIgnoresDispatchWhileBusy() {
        var k = Knight(home: .zero)
        k.dispatch(to: KnightTarget(point: CGPoint(x: 100, y: 0), message: "first"))
        k.dispatch(to: KnightTarget(point: CGPoint(x: -100, y: 0), message: "second"))
        XCTAssertEqual(k.frame(now: 0).message, "first")
    }

    func testLargeTimeGapDoesNotOvershoot() {
        var k = Knight(home: .zero)
        k.dispatch(to: KnightTarget(point: CGPoint(x: 10, y: 0), message: "x"))
        _ = k.update(now: 0)
        _ = k.update(now: 100)
        XCTAssertEqual(k.frame(now: 100).position, CGPoint(x: 10, y: 0))
    }

    // MARK: - Pace

    /// He used to cross a thousand points in two seconds, which is a teleport with legs on it.
    func testCrossingAThousandPointsTakesSeveralSeconds() {
        var k = Knight(home: .zero)
        k.dispatch(to: KnightTarget(point: CGPoint(x: 1000, y: 0), message: "x"))
        var now: TimeInterval = 0
        _ = k.update(now: now)
        while k.frame(now: now).animation == .run, now < 60 {
            now += 1.0 / 60
            _ = k.update(now: now)
        }
        XCTAssertGreaterThan(now, 4, "a thousand points should be a walk you can watch")
    }

    /// His speed and his legs are one setting, not two. Slowed down without slowing the run
    /// cycle he skates — feet racing over ground that crawls past — so the frame rate is
    /// derived from how far one stride carries him rather than written down beside it.
    func testTheRunCycleIsPacedByHisSpeed() {
        XCTAssertEqual(Knight.runFPS, Double(Knight.speed / Knight.strideLength), accuracy: 0.0001)
    }

    // MARK: - Being picked up

    func testHeCanBePickedUpWhileIdle() {
        var k = Knight(home: CGPoint(x: 100, y: 10))
        XCTAssertTrue(k.grab())
        XCTAssertTrue(k.isBusy, "held in the air he is in no state to take an errand")
    }

    func testHeCannotBePickedUpOnTheWayToAQuarry() {
        var k = Knight(home: .zero)
        k.dispatch(to: KnightTarget(point: CGPoint(x: 600, y: 0), message: "x"))
        _ = k.update(now: 0)
        _ = k.update(now: 0.1)
        XCTAssertFalse(k.grab(), "the job comes before the game")
        XCTAssertEqual(k.frame(now: 0.1).animation, .run)
    }

    func testHeCannotBePickedUpMidStrike() {
        var k = Knight(home: .zero)
        k.dispatch(to: KnightTarget(point: CGPoint(x: 20, y: 0), message: "x"))
        var now: TimeInterval = 0
        _ = k.update(now: now)
        while k.frame(now: now).animation != .attack, now < 10 {
            now += 1.0 / 60
            _ = k.update(now: now)
        }
        XCTAssertEqual(k.frame(now: now).animation, .attack, "never reached the strike")
        XCTAssertFalse(k.grab())
        XCTAssertEqual(k.frame(now: now).animation, .attack)
    }

    func testHeCannotBePickedUpOnTheWayHome() {
        var k = Knight(home: .zero)
        k.dispatch(to: KnightTarget(point: CGPoint(x: 400, y: 0), message: "x"))
        var now: TimeInterval = 0
        var sawAttack = false
        _ = k.update(now: now)
        while now < 30 {
            now += 1.0 / 60
            _ = k.update(now: now)
            let animation = k.frame(now: now).animation
            if animation == .attack { sawAttack = true }
            if sawAttack, animation == .run { break }
        }
        XCTAssertTrue(sawAttack, "never started home")
        XCTAssertFalse(k.grab(), "the errand is not over until he is back at his post")
    }

    func testHeStaysWhereHeIsPutUntilLetGo() {
        var k = Knight(home: .zero)
        XCTAssertTrue(k.grab())
        k.drag(to: CGPoint(x: 800, y: 400))
        var now: TimeInterval = 0
        for _ in 0..<120 {
            now += 1.0 / 60
            XCTAssertEqual(k.update(now: now), [], "a held knight has nothing to report")
        }
        XCTAssertEqual(k.frame(now: now).position, CGPoint(x: 800, y: 400))
        XCTAssertEqual(k.frame(now: now).animation, .idle)
    }

    func testHeFacesTheWayHeIsCarried() {
        var k = Knight(home: CGPoint(x: 500, y: 0))
        _ = k.grab()
        k.drag(to: CGPoint(x: 200, y: 0))
        XCTAssertTrue(k.frame(now: 0).facingLeft)
        k.drag(to: CGPoint(x: 900, y: 0))
        XCTAssertFalse(k.frame(now: 0).facingLeft)
    }

    func testLettingGoSendsHimRunningHomeAndBackToIdle() {
        var k = Knight(home: CGPoint(x: 50, y: 10))
        _ = k.grab()
        k.drag(to: CGPoint(x: 900, y: 500))
        k.release()
        XCTAssertEqual(k.frame(now: 0).animation, .run, "he walks back rather than snapping back")

        var now: TimeInterval = 0
        var arrivals = 0
        _ = k.update(now: now)
        for _ in 0..<(60 * 30) {
            now += 1.0 / 60
            for e in k.update(now: now) where e == .arrivedHome { arrivals += 1 }
        }
        XCTAssertEqual(arrivals, 1)
        XCTAssertEqual(k.frame(now: now).position, CGPoint(x: 50, y: 10))
        XCTAssertEqual(k.frame(now: now).animation, .idle)
        XCTAssertFalse(k.frame(now: now).facingLeft)
        XCTAssertFalse(k.isBusy, "home again, and back on duty")
    }

    /// The Dock can be resized while he dangles. He belongs wherever it went, not where it was
    /// when he was picked up.
    func testLetGoHeWalksToWhereHisPostMovedTo() {
        var k = Knight(home: CGPoint(x: 50, y: 10))
        _ = k.grab()
        k.drag(to: CGPoint(x: 900, y: 500))
        k.moveHome(to: CGPoint(x: 300, y: 10))
        k.release()
        var now: TimeInterval = 0
        _ = k.update(now: now)
        for _ in 0..<(60 * 30) {
            now += 1.0 / 60
            _ = k.update(now: now)
        }
        XCTAssertEqual(k.frame(now: now).position, CGPoint(x: 300, y: 10))
    }

    func testHeTakesErrandsAgainOnceHeIsBackFromBeingCarried() {
        var k = Knight(home: .zero)
        _ = k.grab()
        k.drag(to: CGPoint(x: 400, y: 200))
        k.release()
        var now: TimeInterval = 0
        _ = k.update(now: now)
        for _ in 0..<(60 * 30) {
            now += 1.0 / 60
            _ = k.update(now: now)
        }
        k.dispatch(to: KnightTarget(point: CGPoint(x: 100, y: 0), message: "back to work"))
        XCTAssertEqual(k.frame(now: now).message, "back to work")
    }
}
