import AppKit
import CoreGraphics
import Foundation

final class DesktopWindowSensor {
    var onSnapshot: ((PlatformSnapshot) -> Void)?

    private let screenFrame: CGRect
    private let petSize: CGSize
    private var timer: Timer?

    init(screenFrame: CGRect, petSize: CGSize) {
        self.screenFrame = screenFrame
        self.petSize = petSize
    }

    func start() {
        stop()
        publishSnapshot()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.publishSnapshot()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func publishSnapshot() {
        let snapshot = PlatformSnapshot(
            platforms: buildPlatforms(),
            capturedAt: Date()
        )
        onSnapshot?(snapshot)
    }

    private func buildPlatforms() -> [Platform] {
        var result: [Platform] = [groundPlatform()]
        let currentPID = ProcessInfo.processInfo.processIdentifier

        guard let rawList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return result
        }

        let minWidth: CGFloat = 140
        let minHeight: CGFloat = 90
        let inset: CGFloat = 10

        for item in rawList {
            guard let owner = item[kCGWindowOwnerName as String] as? String,
                  owner != "Window Server",
                  owner != "Dock" else {
                continue
            }

            if let ownerPID = item[kCGWindowOwnerPID as String] as? NSNumber,
               ownerPID.int32Value == currentPID {
                continue
            }

            guard let layer = item[kCGWindowLayer as String] as? Int,
                  layer == 0 else {
                continue
            }

            guard let boundsDict = item[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
                continue
            }

            guard frame.width >= minWidth, frame.height >= minHeight else {
                continue
            }

            guard frame.intersects(screenFrame) else {
                continue
            }

            let localMinX = max(0, frame.minX - screenFrame.minX + inset)
            let localMaxX = min(screenFrame.width, frame.maxX - screenFrame.minX - inset)

            guard localMaxX - localMinX >= 60 else {
                continue
            }

            let localY = max(
                petSize.height * 0.5,
                min(screenFrame.height - petSize.height * 0.5, frame.maxY - screenFrame.minY + petSize.height * 0.5)
            )

            let id = windowPlatformId(owner: owner, frame: frame)
            result.append(
                Platform(
                    id: id,
                    kind: .window,
                    minX: localMinX,
                    maxX: localMaxX,
                    y: localY
                )
            )
        }

        return deduplicatePlatforms(result)
    }

    private func groundPlatform() -> Platform {
        Platform(
            id: "ground",
            kind: .ground,
            minX: petSize.width * 0.5,
            maxX: screenFrame.width - petSize.width * 0.5,
            y: petSize.height * 0.5 + 6
        )
    }

    private func windowPlatformId(owner: String, frame: CGRect) -> String {
        let raw = "\(owner)-\(Int(frame.origin.x)):\(Int(frame.origin.y)):\(Int(frame.width)):\(Int(frame.height))"
        return raw.replacingOccurrences(of: " ", with: "_")
    }

    private func deduplicatePlatforms(_ platforms: [Platform]) -> [Platform] {
        var seen = Set<String>()
        var unique: [Platform] = []

        for platform in platforms {
            if seen.insert(platform.id).inserted {
                unique.append(platform)
            }
        }

        return unique.sorted { lhs, rhs in
            if lhs.y == rhs.y {
                return lhs.minX < rhs.minX
            }
            return lhs.y < rhs.y
        }
    }
}
