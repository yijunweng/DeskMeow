import CoreGraphics
import Foundation

struct Platform: Identifiable, Hashable {
    enum Kind: Hashable {
        case ground
        case window
    }

    let id: String
    let kind: Kind
    let minX: CGFloat
    let maxX: CGFloat
    let y: CGFloat

    var width: CGFloat { maxX - minX }

    func contains(x: CGFloat, tolerance: CGFloat = 0) -> Bool {
        x >= (minX - tolerance) && x <= (maxX + tolerance)
    }
}

struct PlatformSnapshot {
    let platforms: [Platform]
    let capturedAt: Date
}
