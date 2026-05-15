import CoreGraphics
import Foundation

@MainActor
final class OverlayViewModel: ObservableObject {
    @Published var petPosition: CGPoint
    @Published var activityState: PetActivityState = .idle
    @Published var isFacingRight = true
    @Published var tempoProfile: TempoProfile = .normal
    @Published var isPaused = false

    let petSize = CGSize(width: 90, height: 90)

    private let simulation: PetSimulationEngine

    init(screenFrame: CGRect) {
        let screenSize = screenFrame.size
        let startX = screenSize.width * 0.5
        let startY = screenSize.height * 0.35
        let startPosition = CGPoint(x: startX, y: startY)
        let playableRect = CGRect(origin: .zero, size: screenSize)

        self.petPosition = startPosition
        self.simulation = PetSimulationEngine(
            playableRect: playableRect,
            initialPosition: startPosition,
            petSize: petSize
        )

        simulation.onPositionChanged = { [weak self] position in
            self?.petPosition = position
        }

        simulation.onStateChanged = { [weak self] state in
            self?.activityState = state
        }

        simulation.onDirectionChanged = { [weak self] isRight in
            self?.isFacingRight = isRight
        }

        simulation.setTempoProfile(.normal)

        simulation.start()
    }

    func stop() {
        simulation.stop()
    }

    func onCatTap() {
        simulation.triggerJumpInPlace()
    }

    func onDragChanged(_ location: CGPoint) {
        if activityState != .drag {
            simulation.beginDrag()
        }
        simulation.drag(to: location)
    }

    func onDragEnded() {
        simulation.endDrag()
    }

    func setTempoProfile(_ profile: TempoProfile) {
        tempoProfile = profile
        simulation.setTempoProfile(profile)
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        simulation.setPaused(paused)
    }
}
