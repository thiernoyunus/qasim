import Foundation

enum BreakActivity: String, CaseIterable, Equatable, Identifiable {
    case adhkar
    case quran
    case rest

    var id: String { rawValue }

    var pose: WickPose {
        switch self {
        case .adhkar: .qiyam
        case .quran: .idle
        case .rest: .sleep
        }
    }

    var title: String {
        switch self {
        case .adhkar: "Adhkar / Tasbih"
        case .quran: "Read Quran"
        case .rest: "A quiet break"
        }
    }

    var blurb: String {
        switch self {
        case .adhkar: "Hold and move prayer beads during remembrance."
        case .quran: "Sit down with an open Quran."
        case .rest: "Take a quiet pause before returning to work."
        }
    }
}
