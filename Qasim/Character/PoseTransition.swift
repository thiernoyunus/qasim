import Foundation
import CoreGraphics

/// Frame-by-frame clips for the companion: a bridge that plays *between* two
/// poses so he moves into an activity instead of snapping into it, and a loop
/// that keeps him alive while he stays in one.
///
/// Qasim is the only companion with clips so far. Everyone else swaps poses
/// instantly and holds a still sprite, which is the existing behaviour.
enum PoseTransition {
    /// Milliseconds each work-transition drawing is held. The grounded
    /// distraction transition has its own slower timing below so the laptop
    /// close and angry reaction can be read.
    static let transitionHoldMs = [120, 100, 100, 120, 100, 160, 150, 150, 120]

    /// Grounded distraction beat: open laptop, close it, react angrily, stand,
    /// then hand off to the existing distraction action.
    static let distractionHoldMs = [160, 180, 220, 180, 180, 260]
    static let distractionDuration = Double(distractionHoldMs.reduce(0, +)) / 1000
    static let distractionFrameIndices = Array(0..<6)

    static func transitionHoldMs(at index: Int) -> Int {
        transitionHoldMs.indices.contains(index) ? transitionHoldMs[index] : 120
    }

    static func transitionHoldMs(for frames: [String], at index: Int) -> Int {
        if frames.first?.hasPrefix("qasim-t-angry-jump-") == true {
            return distractionHoldMs.indices.contains(index) ? distractionHoldMs[index] : 120
        }
        return transitionHoldMs(at: index)
    }

    /// Milliseconds per drawing in a loop. Slower than the bridge: the loop is
    /// breathing and keystrokes, not travel, and it plays for the whole
    /// session, so it should read as calm rather than busy.
    static let loopHoldMs = 180

    /// The completion beat is a real eight-frame flipbook, not a scale/offset
    /// effect. The last frame holds a little longer so the achievement lands.
    static let completionHoldMs = [160, 120, 110, 110, 120, 130, 160, 260]
    static let completionDuration = Double(completionHoldMs.reduce(0, +)) / 1000

    /// Transition frames live on a canvas this many times the pose sprite's so
    /// the seated laptop frames and the standing handoff share one safe box.
    ///
    /// Printed by scripts/slice_transition_sheet.py; keep the two in step.
    static let canvasScale: CGFloat = 1.9

    /// Asset names for the clip covering `from -> to`, or nil when we have no
    /// art for that pair and the pose should just swap.
    static func frames(
        companion: CompanionID,
        from: QasimPose,
        to: QasimPose,
        distractionActive: Bool = false
    ) -> [String]? {
        guard companion == .qasim else { return nil }
        if distractionActive, from == .typing, to != .typing {
            return distractionFrameIndices.map { "qasim-t-angry-jump-\($0)" }
        }
        guard from == .idle, to == .typing else { return nil }
        return (0..<9).map { "qasim-t-idle-typing-\($0)" }
    }

    /// Frames that cycle for as long as he holds `pose`, or nil when that pose
    /// has no loop art and should stay a still sprite.
    static func loop(companion: CompanionID, pose: QasimPose) -> [String]? {
        guard companion == .qasim, pose == .typing else { return nil }
        return (0..<8).map { "qasim-loop-typing-\($0)" }
    }

    static func completionFrames(companion: CompanionID) -> [String]? {
        guard companion == .qasim else { return nil }
        return (0..<8).map { "qasim-session-complete-\(String(format: "%03d", $0))" }
    }

    static func completionFrame(companion: CompanionID, elapsed: TimeInterval) -> String? {
        guard let frames = completionFrames(companion: companion) else { return nil }
        var elapsed = min(max(0, elapsed), completionDuration - 0.0001)

        for (index, holdMs) in completionHoldMs.enumerated() {
            let hold = Double(holdMs) / 1000
            if elapsed < hold { return frames[index] }
            elapsed -= hold
        }
        return frames.last
    }
}
