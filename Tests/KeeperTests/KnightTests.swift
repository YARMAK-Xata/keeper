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
        for _ in 0..<(60 * 6) {          // six seconds at 60 Hz
            now += 1.0 / 60
            for e in k.update(now: now) {
                if e == .strike { strikes += 1 }
                if e == .arrivedHome { arrivals += 1 }
            }
            let f = k.frame(now: now)
            if abs(now - 1.0) < 0.01 {
                XCTAssertEqual(f.animation, .run)
                XCTAssertFalse(f.facingLeft)
                XCTAssertEqual(f.position.x, 500, accuracy: 20)
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
            if now > 10 { XCTFail("never started home"); return }
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
}
