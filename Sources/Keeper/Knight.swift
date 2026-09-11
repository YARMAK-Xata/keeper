import Foundation
import CoreGraphics

enum KnightAnimation: Equatable { case idle, run, attack }

struct KnightTarget: Equatable {
    var point: CGPoint
    var message: String
}

/// What to draw right now. `position` is the knight's feet centre in AppKit screen coordinates.
struct KnightFrame: Equatable {
    var position: CGPoint
    var animation: KnightAnimation
    var frameIndex: Int
    var facingLeft: Bool
    var message: String?
}

/// Pure state machine: idle at home → run to target → attack (strike once) → run home → idle.
///
/// One branch off that loop: from idle he can be picked up and carried, and where he is let go
/// he walks home by the same path he takes after an errand. Only from idle — the errand always
/// finishes, so grabbing him is never a way to save a tab.
struct Knight {
    enum Event: Equatable { case strike, arrivedHome }
    enum Phase: Equatable {
        case idle
        case carried
        case running(to: CGPoint, attackOnArrival: Bool)
        case attacking(since: TimeInterval)
    }

    static let speed: CGFloat = 200
    /// How far one frame of the run cycle carries him. The frame rate is worked out from this
    /// rather than written beside it, so changing his speed can never leave his legs behind:
    /// pick a speed, and the cycle plays at whatever rate keeps that stride on the ground.
    static let strideLength: CGFloat = 25
    static let idleFrames = 5, idleFPS = 6.0
    static let runFrames = 8
    static let runFPS = Double(speed / strideLength)
    static let attackFrames = 6, attackFPS = 10.0, strikeFrame = 3

    private(set) var home: CGPoint
    private(set) var position: CGPoint
    private(set) var phase: Phase = .idle
    private(set) var facingLeft = false
    private(set) var message: String?
    private var lastTime: TimeInterval?
    private var struck = false

    init(home: CGPoint) {
        self.home = home
        position = home
    }

    var isBusy: Bool { phase != .idle }

    mutating func dispatch(to target: KnightTarget) {
        guard !isBusy else { return }
        message = target.message
        facingLeft = target.point.x < position.x
        phase = .running(to: target.point, attackOnArrival: true)
    }

    /// Picks him up, and says whether he allowed it.
    ///
    /// Only from idle. Mid-errand he is refused, and that refusal is the feature: a knight you
    /// could snatch off a tab he was sent to close would be a way out of the session, and the
    /// session is the whole point of the app.
    @discardableResult
    mutating func grab() -> Bool {
        guard phase == .idle else { return false }
        phase = .carried
        return true
    }

    /// Carries him. He faces the way he is being moved, so he never travels backwards.
    mutating func drag(to point: CGPoint) {
        guard phase == .carried else { return }
        if point.x != position.x { facingLeft = point.x < position.x }
        position = point
    }

    /// Lets go. He walks back to his post on the same legs he comes home on, and picks up his
    /// duties when he arrives.
    mutating func release() {
        guard phase == .carried else { return }
        facingLeft = home.x < position.x
        phase = .running(to: home, attackOnArrival: false)
    }

    /// Moves the spot he waits at, without interrupting him.
    ///
    /// The Dock changes shape while a session is running — resized, or simply widened by an app
    /// launching — and he should end up wherever it went. Mid-errand he finishes first and finds
    /// the new spot on the way back; standing idle, he is already there, so he just steps across.
    mutating func moveHome(to newHome: CGPoint) {
        home = newHome
        guard !isBusy else { return }
        position = newHome
    }

    mutating func reset(home newHome: CGPoint) {
        home = newHome
        position = newHome
        phase = .idle
        message = nil
        facingLeft = false
        struck = false
        lastTime = nil
    }

    mutating func update(now: TimeInterval) -> [Event] {
        let dt = CGFloat(min(max(now - (lastTime ?? now), 0), 0.1))
        lastTime = now
        switch phase {
        case .idle, .carried:
            return []
        case .running(let to, let attackOnArrival):
            let dx = to.x - position.x, dy = to.y - position.y
            let distance = hypot(dx, dy)
            let step = Self.speed * dt
            if distance <= step {
                position = to
                if attackOnArrival {
                    phase = .attacking(since: now)
                    struck = false
                    return []
                }
                phase = .idle
                facingLeft = false
                return [.arrivedHome]
            }
            position.x += dx / distance * step
            position.y += dy / distance * step
            return []
        case .attacking(let since):
            let index = Int((now - since) * Self.attackFPS)
            var events: [Event] = []
            if index >= Self.strikeFrame, !struck {
                struck = true
                events.append(.strike)
            }
            if index >= Self.attackFrames {
                message = nil
                facingLeft = home.x < position.x
                phase = .running(to: home, attackOnArrival: false)
            }
            return events
        }
    }

    func frame(now: TimeInterval) -> KnightFrame {
        func loop(_ fps: Double, _ count: Int) -> Int {
            let i = Int((now * fps).rounded(.down)) % count
            return i < 0 ? i + count : i
        }
        switch phase {
        // Carried, he dangles: the idle cycle is the one that reads as "not doing anything",
        // and the sheet has no row for being held.
        case .idle, .carried:
            return KnightFrame(position: position, animation: .idle, frameIndex: loop(Self.idleFPS, Self.idleFrames), facingLeft: facingLeft, message: message)
        case .running:
            return KnightFrame(position: position, animation: .run, frameIndex: loop(Self.runFPS, Self.runFrames), facingLeft: facingLeft, message: message)
        case .attacking(let since):
            let index = min(Int((now - since) * Self.attackFPS), Self.attackFrames - 1)
            return KnightFrame(position: position, animation: .attack, frameIndex: max(index, 0), facingLeft: facingLeft, message: message)
        }
    }
}
