import CoreGraphics
import Foundation

final class PetSimulationEngine {
    var onPositionChanged: ((CGPoint) -> Void)?
    var onStateChanged: ((PetActivityState) -> Void)?
    var onDirectionChanged: ((Bool) -> Void)?

    private let playableRect: CGRect
    private let petSize: CGSize

    private var timer: Timer?
    private var position: CGPoint
    private var velocity = CGVector(dx: 0, dy: 0)
    private var horizontalDirection: CGFloat = 1
    private var tempoProfile: TempoProfile = .normal
    private var isPaused = false
    private var dragPosition: CGPoint?

    private var state: MotionState = .patrol
    private var currentGroundY: CGFloat
    private var targetPoint: CGPoint?
    private var pendingJump: JumpPlan?
    private var jumpElapsed: CGFloat = 0
    private var jumpDuration: CGFloat = 0
    private var runSpeed: CGFloat = 52
    private var idleUntil: TimeInterval = 0
    private var prepareUntil: TimeInterval = 0
    private var landingUntil: TimeInterval = 0

    // SwiftUI 在当前窗口内使用 Y 轴向下的坐标系，重力取正值表示向下加速。
    private let gravity: CGFloat = 980
    private let tickRate: TimeInterval = 1.0 / 30.0
    private var nextDecisionAt: TimeInterval = 0

    private enum MotionState {
        case patrol
        case idle
        case prepareJump
        case jumping
        case landing
        case dragging
    }

    private struct JumpPlan {
        let landing: CGPoint
        let velocity: CGVector
        let duration: CGFloat
    }

    init(playableRect: CGRect, initialPosition: CGPoint, petSize: CGSize) {
        self.playableRect = playableRect
        self.position = initialPosition
        self.petSize = petSize
        self.currentGroundY = initialPosition.y
    }

    func start() {
        stop()
        nextDecisionAt = CFAbsoluteTimeGetCurrent()
        timer = Timer.scheduledTimer(withTimeInterval: tickRate, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
        emitState(.walk)
        onDirectionChanged?(horizontalDirection >= 0)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func setTempoProfile(_ profile: TempoProfile) {
        tempoProfile = profile
        runSpeed = randomCruiseSpeed()
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        if paused {
            emitState(.idle)
        } else if state == .patrol {
            emitState(runSpeed > runThreshold ? .run : .walk)
        }
    }

    func triggerJumpInPlace() {
        guard state != .jumping && state != .dragging && state != .prepareJump else {
            return
        }
        scheduleJump(changeHeight: false, preferredTargetX: position.x)
    }

    func beginDrag() {
        dragPosition = position
        state = .dragging
        velocity = .zero
        targetPoint = nil
        emitState(.drag)
    }

    func drag(to point: CGPoint) {
        let clamped = CGPoint(x: clampX(point.x), y: clampY(point.y))
        dragPosition = clamped
        position = clamped
        currentGroundY = clamped.y
        onPositionChanged?(position)
    }

    func endDrag() {
        guard state == .dragging else {
            return
        }
        if let dragPosition {
            position = dragPosition
            currentGroundY = dragPosition.y
        }
        state = .idle
        idleUntil = CFAbsoluteTimeGetCurrent() + .random(in: 0.3...0.8)
        nextDecisionAt = idleUntil + .random(in: 0.7...1.4)
        emitState(.idle)
    }

    private func tick() {
        if isPaused {
            return
        }

        let dt = CGFloat(tickRate)

        switch state {
        case .patrol:
            patrolStep(dt: dt)
        case .idle:
            idleStep()
        case .prepareJump:
            prepareJumpStep()
        case .jumping:
            jumpStep(dt: dt)
        case .landing:
            landingStep(dt: dt)
        case .dragging:
            if let dragPosition {
                position = dragPosition
                currentGroundY = dragPosition.y
            }
        }

        clampToScreenBounds()

        onPositionChanged?(position)
    }

    private func patrolStep(dt: CGFloat) {
        let now = CFAbsoluteTimeGetCurrent()
        position.y = currentGroundY

        position.x += horizontalDirection * runSpeed * dt
        emitState(runSpeed > runThreshold ? .run : .walk)

        let minX = playableRect.minX + petSize.width * 0.5
        let maxX = playableRect.maxX - petSize.width * 0.5

        if position.x <= minX {
            position.x = minX
            horizontalDirection = 1
            onDirectionChanged?(true)
        }
        if position.x >= maxX {
            position.x = maxX
            horizontalDirection = -1
            onDirectionChanged?(false)
        }

        if now >= nextDecisionAt {
            nextDecisionAt = now + randomDecisionInterval()
            runSpeed = randomCruiseSpeed()

            let roll = Int.random(in: 0...99)
            let movingJumpThreshold = jumpChangeHeightProbability
            let inPlaceJumpThreshold = movingJumpThreshold + jumpSameHeightProbability
            let idleThreshold = inPlaceJumpThreshold + idleProbability

            if roll < movingJumpThreshold {
                scheduleJump(changeHeight: true)
            } else if roll < inPlaceJumpThreshold {
                scheduleJump(changeHeight: false)
            } else if roll < idleThreshold {
                state = .idle
                idleUntil = now + randomIdleDuration()
                emitState(.idle)
            } else {
                horizontalDirection = Bool.random() ? 1 : -1
                onDirectionChanged?(horizontalDirection >= 0)
            }
        }
    }

    private func idleStep() {
        position.y = currentGroundY
        emitState(.idle)
        let now = CFAbsoluteTimeGetCurrent()
        if now >= idleUntil {
            state = .patrol
            runSpeed = randomCruiseSpeed()
            nextDecisionAt = now + randomDecisionInterval()
        }
    }

    private func prepareJumpStep() {
        position.y = currentGroundY
        emitState(.idle)

        let now = CFAbsoluteTimeGetCurrent()
        if now >= prepareUntil, let plan = pendingJump {
            state = .jumping
            pendingJump = nil
            targetPoint = plan.landing
            velocity = plan.velocity
            jumpElapsed = 0
            jumpDuration = plan.duration
            emitState(.jump)
        }
    }

    private func jumpStep(dt: CGFloat) {
        emitState(.jump)
        let previousY = position.y
        jumpElapsed += dt
        velocity.dy += gravity * dt
        position.x += velocity.dx * dt
        position.y += velocity.dy * dt

        if shouldLand(previousY: previousY) {
            let target = targetPoint ?? CGPoint(x: position.x, y: currentGroundY)
            position.x = clampX(target.x)
            position.y = target.y
            currentGroundY = target.y
            state = .landing
            targetPoint = nil
            velocity.dx *= 0.22
            velocity.dy = 0
            horizontalDirection = Bool.random() ? 1 : -1
            onDirectionChanged?(horizontalDirection >= 0)
            landingUntil = CFAbsoluteTimeGetCurrent() + randomLandingDuration()
        }
    }

    private func landingStep(dt: CGFloat) {
        emitState(.idle)
        position.y = currentGroundY
        position.x += velocity.dx * dt
        velocity.dx *= 0.88

        if CFAbsoluteTimeGetCurrent() >= landingUntil {
            state = .patrol
            runSpeed = randomCruiseSpeed()
            nextDecisionAt = CFAbsoluteTimeGetCurrent() + randomDecisionInterval()
        }
    }

    private func scheduleJump(changeHeight: Bool, preferredTargetX: CGFloat? = nil) {
        guard let plan = makeJumpPlan(changeHeight: changeHeight, preferredTargetX: preferredTargetX) else {
            return
        }

        pendingJump = plan
        state = .prepareJump
        prepareUntil = CFAbsoluteTimeGetCurrent() + randomPrepareDuration()
        runSpeed *= 0.55
    }

    private func makeJumpPlan(changeHeight: Bool, preferredTargetX: CGFloat? = nil) -> JumpPlan? {
        let currentX = position.x
        let currentY = currentGroundY

        let targetX: CGFloat
        if let preferredTargetX {
            targetX = clampX(preferredTargetX)
        } else {
            targetX = clampX(currentX + randomJumpDistance())
        }

        let nextY: CGFloat
        if changeHeight {
            let deltaY = randomHeightDeltaConservative()
            nextY = clampY(currentY + deltaY)
        } else {
            nextY = currentY
        }

        let landing = CGPoint(x: targetX, y: nextY)
        let dx = landing.x - currentX

        // 最高点应在更小的 Y（视觉上更高的位置）。
        let apexY = clampY(min(currentY, nextY) - randomApexPadding())
        let upHeight = max(currentY - apexY, 26)
        let vy = -sqrt(2 * gravity * upHeight)

        let timeUp = abs(vy) / gravity
        let downHeight = max(nextY - apexY, 4)
        let timeDown = sqrt(2 * downHeight / gravity)
        let flightTime = max(timeUp + timeDown, 0.25)
        let vx = dx / flightTime

        if abs(vx) > maxHorizontalJumpVelocity {
            return nil
        }

        return JumpPlan(
            landing: landing,
            velocity: CGVector(dx: vx, dy: vy),
            duration: flightTime
        )
    }

    private func shouldLand(previousY: CGFloat) -> Bool {
        guard let target = targetPoint else {
            return false
        }

        if jumpElapsed >= jumpDuration + 0.22 {
            return true
        }

        if velocity.dy >= 0 {
            let crossedTargetY = previousY <= target.y && position.y >= target.y
            let closeX = abs(position.x - target.x) <= 26
            return crossedTargetY && closeX
        }

        return false
    }

    private func clampToScreenBounds() {
        let minX = playableRect.minX + petSize.width * 0.5
        let maxX = playableRect.maxX - petSize.width * 0.5
        let minY = playableRect.minY + petSize.height * 0.5
        let maxY = playableRect.maxY - petSize.height * 0.5

        position.x = min(max(position.x, minX), maxX)
        position.y = min(max(position.y, minY), maxY)
    }

    private func clampX(_ x: CGFloat) -> CGFloat {
        let minX = playableRect.minX + petSize.width * 0.5
        let maxX = playableRect.maxX - petSize.width * 0.5
        return min(max(x, minX), maxX)
    }

    private func clampY(_ y: CGFloat) -> CGFloat {
        let minY = playableRect.minY + petSize.height * 0.5
        let maxY = playableRect.maxY - petSize.height * 0.5
        return min(max(y, minY), maxY)
    }

    private var runThreshold: CGFloat {
        switch tempoProfile {
        case .lazy: return 52
        case .normal: return 64
        case .active: return 74
        }
    }

    private var jumpChangeHeightProbability: Int {
        switch tempoProfile {
        case .lazy: return 7
        case .normal: return 12
        case .active: return 20
        }
    }

    private var jumpSameHeightProbability: Int {
        switch tempoProfile {
        case .lazy: return 5
        case .normal: return 8
        case .active: return 12
        }
    }

    private var idleProbability: Int {
        switch tempoProfile {
        case .lazy: return 52
        case .normal: return 38
        case .active: return 24
        }
    }

    private func randomCruiseSpeed() -> CGFloat {
        switch tempoProfile {
        case .lazy: return CGFloat.random(in: 22...56)
        case .normal: return CGFloat.random(in: 30...85)
        case .active: return CGFloat.random(in: 52...128)
        }
    }

    private func randomDecisionInterval() -> TimeInterval {
        switch tempoProfile {
        case .lazy: return .random(in: 1.8...4.2)
        case .normal: return .random(in: 1.3...3.4)
        case .active: return .random(in: 0.8...2.2)
        }
    }

    private func randomIdleDuration() -> TimeInterval {
        switch tempoProfile {
        case .lazy: return .random(in: 1.1...3.6)
        case .normal: return .random(in: 0.8...2.6)
        case .active: return .random(in: 0.4...1.8)
        }
    }

    private func randomJumpDistance() -> CGFloat {
        switch tempoProfile {
        case .lazy: return CGFloat.random(in: -90...90)
        case .normal: return CGFloat.random(in: -130...130)
        case .active: return CGFloat.random(in: -190...190)
        }
    }

    private func randomHeightDelta() -> CGFloat {
        switch tempoProfile {
        case .lazy: return CGFloat.random(in: -90...90)
        case .normal: return CGFloat.random(in: -120...120)
        case .active: return CGFloat.random(in: -170...170)
        }
    }

    private func randomHeightDeltaConservative() -> CGFloat {
        switch tempoProfile {
        case .lazy: return CGFloat.random(in: -62...58)
        case .normal: return CGFloat.random(in: -78...72)
        case .active: return CGFloat.random(in: -98...90)
        }
    }

    private func randomApexPadding() -> CGFloat {
        switch tempoProfile {
        case .lazy: return CGFloat.random(in: 34...72)
        case .normal: return CGFloat.random(in: 42...90)
        case .active: return CGFloat.random(in: 58...118)
        }
    }

    private func randomJumpDuration() -> CGFloat {
        switch tempoProfile {
        case .lazy: return CGFloat.random(in: 0.82...1.35)
        case .normal: return CGFloat.random(in: 0.75...1.25)
        case .active: return CGFloat.random(in: 0.55...1.0)
        }
    }

    private func randomPrepareDuration() -> TimeInterval {
        switch tempoProfile {
        case .lazy: return .random(in: 0.14...0.24)
        case .normal: return .random(in: 0.12...0.22)
        case .active: return .random(in: 0.1...0.18)
        }
    }

    private func randomLandingDuration() -> TimeInterval {
        switch tempoProfile {
        case .lazy: return .random(in: 0.12...0.2)
        case .normal: return .random(in: 0.1...0.18)
        case .active: return .random(in: 0.08...0.14)
        }
    }

    private var maxHorizontalJumpVelocity: CGFloat {
        switch tempoProfile {
        case .lazy: return 118
        case .normal: return 148
        case .active: return 188
        }
    }

    private func emitState(_ state: PetActivityState) {
        onStateChanged?(state)
    }
}
