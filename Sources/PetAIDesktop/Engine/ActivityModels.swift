import Foundation

enum PetActivityState: String {
    case idle = "Idle"
    case walk = "Walk"
    case run = "Run"
    case jump = "Jump"
    case drag = "Drag"
}

enum TempoProfile: String, CaseIterable, Identifiable {
    case lazy = "慵懒"
    case normal = "日常"
    case active = "活跃"

    var id: String { rawValue }
}
