import AppKit
import Combine
import SwiftUI

final class OverlayWindowController: NSWindowController {
    private let viewModel: OverlayViewModel
    private let screenFrame: CGRect
    private var catScreenRect: CGRect = .zero
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var positionCancellable: AnyCancellable?
    private var interactionLocked = false
    private var hoverTimer: Timer?

    init(screenFrame: CGRect) {
        self.screenFrame = screenFrame
        self.viewModel = OverlayViewModel(screenFrame: screenFrame)

        let hosting = NSHostingController(rootView: OverlayRootView(viewModel: viewModel))
        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = hosting
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        // 默认穿透，只有鼠标靠近猫咪时才接收事件。
        window.ignoresMouseEvents = true
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.setFrame(screenFrame, display: true)

        super.init(window: window)
        shouldCascadeWindows = false

        window.orderFrontRegardless()

        positionCancellable = viewModel.$petPosition.sink { [weak self] point in
            Task { @MainActor [weak self] in
                self?.updateCatRect(with: point)
            }
        }
        setupMouseMonitors()
        startHoverPolling()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func shutdown() {
        viewModel.stop()
        removeMouseMonitors()
        stopHoverPolling()
        positionCancellable?.cancel()
        positionCancellable = nil
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            NSApp.terminate(nil)
        } else {
            super.keyDown(with: event)
        }
    }

    private func updateCatRect(with center: CGPoint) {
        let size = viewModel.petSize
        let screenRect = CGRect(
            x: screenFrame.minX + center.x - size.width * 0.5,
            y: screenFrame.maxY - center.y - size.height * 0.5,
            width: size.width,
            height: size.height
        )
        catScreenRect = screenRect
        refreshHitMode(by: NSEvent.mouseLocation, eventType: nil)
    }

    private func setupMouseMonitors() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.refreshHitMode(by: NSEvent.mouseLocation, eventType: event.type)
            }
            return event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.refreshHitMode(by: NSEvent.mouseLocation, eventType: event.type)
            }
        }
    }

    private func removeMouseMonitors() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }

    private func startHoverPolling() {
        hoverTimer?.invalidate()
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshHitMode(by: NSEvent.mouseLocation, eventType: nil)
            }
        }
        if let hoverTimer {
            RunLoop.main.add(hoverTimer, forMode: .common)
        }
    }

    private func stopHoverPolling() {
        hoverTimer?.invalidate()
        hoverTimer = nil
    }

    private func refreshHitMode(by mouseLocation: CGPoint, eventType: NSEvent.EventType?) {
        guard let window else { return }

        let hitZone = catScreenRect.insetBy(dx: -18, dy: -18)
        let isInsideCat = hitZone.contains(mouseLocation)

        if eventType == .leftMouseDown, isInsideCat {
            interactionLocked = true
        }
        if eventType == .leftMouseUp {
            interactionLocked = false
        }

        if interactionLocked || isInsideCat {
            if window.ignoresMouseEvents {
                window.ignoresMouseEvents = false
            }
        } else {
            if !window.ignoresMouseEvents {
                window.ignoresMouseEvents = true
            }
        }
    }
}
