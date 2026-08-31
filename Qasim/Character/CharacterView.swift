import AppKit
import SwiftUI

struct CharacterView: View {
    var companion: CompanionID
    var pose: QasimPose
    var facing: CGFloat
    var hopLift: CGFloat
    var breatheScale: CGFloat
    var pressed: Bool
    var size: CGSize
    var lightsOff = false
    var switchPressed = false
    var breakActivity: BreakActivity? = nil
    /// When on, pose changes swap instantly instead of playing a clip.
    var reducedMotion = false
    /// True only during the initial close-laptop-to-standing interruption.
    var distractionActive = false
    /// A short, positive completion beat shown in the session-complete card.
    var celebrating = false

    /// Non-nil while a between-poses clip is playing. Holds the frame names and
    /// how far through them we are.
    @State private var transition: (frames: [String], index: Int)?
    /// The pose we last drew, so a change can be detected and bridged.
    @State private var shownPose: QasimPose?
    /// A pose change can happen while a previous clip is still waiting on its
    /// next frame. Keep only the current clip alive.
    @State private var transitionTask: Task<Void, Never>?
    @State private var celebrationActive = false
    @State private var celebrationStartedAt = Date()
    @State private var celebrationTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.18))
                .frame(width: size.width * 0.5, height: 16)
                .offset(y: size.height * 0.37)
                .blur(radius: 1)

            if celebrationActive {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    ZStack {
                        let elapsed = timeline.date.timeIntervalSince(celebrationStartedAt)
                        celebrationSprite(at: elapsed)
                        CelebrationSparkles(time: elapsed)
                    }
                }
            } else {
                ZStack {
                    sprite
                }
                .offset(y: -hopLift)
            }

            if let breakActivity {
                BreakPropView(activity: breakActivity, companion: companion, size: size)
                    .offset(y: -hopLift)
            }
        }
        .frame(width: size.width, height: size.height)
        // No cross-fade while a clip plays: the frames already carry the motion,
        // and fading them turns crisp drawings into mush.
        .animation(transition == nil ? .easeOut(duration: 0.12) : nil, value: pose)
        .animation(.easeOut(duration: 0.08), value: pressed)
        .onAppear {
            shownPose = pose
            updateCelebration(celebrating)
        }
        .onDisappear {
            transitionTask?.cancel()
            transitionTask = nil
            celebrationTask?.cancel()
            celebrationTask = nil
        }
        .onChange(of: celebrating) { _, value in
            updateCelebration(value)
        }
        .onChange(of: reducedMotion) { _, value in
            if value {
                updateCelebration(false)
            } else if celebrating {
                updateCelebration(true)
            }
        }
        .onChange(of: pose) { previous, next in
            transitionTask?.cancel()
            shownPose = next
            guard !reducedMotion,
                  let frames = PoseTransition.frames(
                      companion: companion,
                      from: previous,
                      to: next,
                      distractionActive: distractionActive
                  )
            else {
                transition = nil
                return
            }
            play(frames)
        }
    }

    /// Steps through the clip one drawing at a time, then hands back to the
    /// normal pose sprite. Cancels itself if the pose changes again mid-play.
    private func play(_ frames: [String]) {
        transition = (frames, 0)
        transitionTask = Task { @MainActor in
            for step in 1...frames.count {
                let hold = Double(PoseTransition.transitionHoldMs(for: frames, at: step - 1)) / 1000
                try? await Task.sleep(for: .seconds(hold))
                guard !Task.isCancelled, shownPose == pose, transition != nil else { return }
                transition = step < frames.count ? (frames, step) : nil
            }
        }
    }

    @ViewBuilder
    private func celebrationSprite(at elapsed: TimeInterval) -> some View {
        if let frame = PoseTransition.completionFrame(companion: companion, elapsed: elapsed) {
            renderedSprite(named: frame)
                .frame(
                    width: size.width * PoseTransition.canvasScale,
                    height: size.height * PoseTransition.canvasScale
                )
        } else {
            transformCelebrationSprite(at: elapsed)
        }
    }

    private func transformCelebrationSprite(at elapsed: TimeInterval) -> some View {
        let phase = elapsed.truncatingRemainder(dividingBy: 1.8)
        let jump = CGFloat(max(0, sin(phase * Double.pi * 4))) * 30
        let tilt = sin(phase * Double.pi * 4) * 5
        let scale = 1 + CGFloat(max(0, sin(phase * Double.pi * 4))) * 0.035

        return ZStack {
            sprite
        }
        .offset(y: -jump)
        .rotationEffect(.degrees(tilt))
        .scaleEffect(scale)
    }

    private func updateCelebration(_ value: Bool) {
        celebrationTask?.cancel()
        celebrationTask = nil
        guard value, !reducedMotion else {
            celebrationActive = false
            return
        }
        celebrationStartedAt = Date()
        celebrationActive = true
        celebrationTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(PoseTransition.completionDuration))
            guard !Task.isCancelled else { return }
            celebrationActive = false
        }
    }

    @ViewBuilder
    private var sprite: some View {
        if let transition {
            // Drawn in a box canvasScale times larger, matching the larger
            // canvas these frames were exported on. The character ends up the
            // same on-screen size; the extra room keeps the seated laptop and
            // standing handoff on one stable canvas.
            renderedSprite(named: transition.frames[transition.index])
                .frame(
                    width: size.width * PoseTransition.canvasScale,
                    height: size.height * PoseTransition.canvasScale
                )
        } else if !reducedMotion,
                  breakActivity == nil,
                  let loop = PoseTransition.loop(companion: companion, pose: pose) {
            // Same enlarged box as the bridge clip: both were exported on one
            // canvas so they hand off without a size change.
            TimelineView(.animation(minimumInterval: Double(PoseTransition.loopHoldMs) / 1000)) { timeline in
                let step = Int(timeline.date.timeIntervalSinceReferenceDate * 1000)
                    / PoseTransition.loopHoldMs
                renderedSprite(named: loop[((step % loop.count) + loop.count) % loop.count])
            }
            .frame(
                width: size.width * PoseTransition.canvasScale,
                height: size.height * PoseTransition.canvasScale
            )
        } else if breakActivity == .adhkar, companion == .qasim {
            TimelineView(.animation(minimumInterval: 0.12)) { timeline in
                renderedSprite(named: tasbihAsset(at: timeline.date))
            }
        } else if pose == .typing {
            TimelineView(.animation(minimumInterval: 0.16)) { timeline in
                renderedSprite(named: resolvedAsset)
                    .offset(y: typingBob(at: timeline.date))
            }
        } else {
            renderedSprite(named: resolvedAsset)
        }
    }

    private func renderedSprite(named: String) -> some View {
        Image(named)
            .resizable()
            .interpolation(companion.isPixelCompanion ? .none : .high)
            .scaledToFit()
            .scaleEffect(x: facing, y: 1, anchor: .center)
            .scaleEffect(breatheScale * (pressed ? 0.94 : 1))
            .shadow(color: .black.opacity(0.18), radius: 8, y: 6)
    }

    private func tasbihAsset(at date: Date) -> String {
        Int(date.timeIntervalSinceReferenceDate * 1.6) % 2 == 0
            ? "qasim-tasbih-a"
            : "qasim-tasbih-b"
    }

    private func typingBob(at date: Date) -> CGFloat {
        let phase = (sin(date.timeIntervalSinceReferenceDate * 7.5) + 1) * 0.5
        return -CGFloat(phase) * 1.5
    }

    private var resolvedAsset: String {
        let named: String
        if breakActivity == .quran, companion == .qasim {
            named = "qasim-quran"
        } else if pose == .flipSwitch, companion == .qasim {
            named = lightsOff || switchPressed ? "qasim-switch-down" : "qasim-switch-up"
        } else {
            named = companion.assetName(for: pose)
        }
        if NSImage(named: named) != nil { return named }
#if DEBUG
        assertionFailure("Missing companion sprite: \(named)")
#endif
        let idle = companion.assetName(for: .idle)
        if NSImage(named: idle) != nil { return idle }
        return CompanionID.qasim.assetName(for: .idle)
    }
}

private struct CelebrationSparkles: View {
    let time: TimeInterval

    var body: some View {
        let phase = time.truncatingRemainder(dividingBy: 1.8) / 1.8

        ZStack {
            ForEach(0..<8, id: \.self) { index in
                let progress = (phase + Double(index) / 8).truncatingRemainder(dividingBy: 1)
                let angle = Double(index) / 8 * Double.pi * 2
                let distance = 38 + CGFloat(progress * 28)
                Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "star.fill")
                    .font(.system(size: index.isMultiple(of: 2) ? 13 : 9, weight: .bold))
                    .foregroundStyle(index.isMultiple(of: 3) ? Palette.flame : Palette.good)
                    .opacity(1 - progress)
                    .scaleEffect(0.75 + progress * 0.45)
                    .rotationEffect(.degrees(progress * 90))
                    .offset(
                        x: CGFloat(cos(angle)) * distance,
                        y: CGFloat(sin(angle)) * distance - 16
                    )
            }
        }
    }
}

private struct BreakPropView: View {
    var activity: BreakActivity
    var companion: CompanionID
    var size: CGSize

    var body: some View {
        switch activity {
        case .adhkar:
            if companion == .qasim {
                EmptyView()
            } else {
                HStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { _ in
                        Circle()
                            .fill(Palette.ember)
                            .frame(width: 5, height: 5)
                    }
                }
                .padding(5)
                .background(Palette.cream.opacity(0.92), in: Capsule())
                .overlay(Capsule().stroke(Palette.ink.opacity(0.55), lineWidth: 1))
                .offset(x: size.width * 0.2, y: size.height * 0.12)
            }
        case .quran:
            if companion == .qasim {
                EmptyView()
            } else {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .padding(6)
                    .background(Palette.cream.opacity(0.92), in: Circle())
                    .overlay(Circle().stroke(Palette.ink.opacity(0.55), lineWidth: 1))
                    .offset(y: size.height * 0.16)
            }
        case .rest:
            Text("z z")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.inkSoft)
                .offset(x: size.width * 0.18, y: -size.height * 0.27)
        }
    }
}

/// His ordinary speech. It always expires on its own, so it carries no close
/// button — only the prayer nudge, which waits for an answer, needs one.
struct SpeechBubbleView: View {
    var text: String
    /// How far the tail sits from the bubble's centre. Non-zero when the bubble
    /// had to slide inward to stay on screen, so it keeps pointing at his head.
    var tailOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(Typeface.display(16))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                // Short lines hug their text; long ones wrap onto a second
                // line rather than growing into a strip too wide to fit.
                .fixedSize(horizontal: !wraps, vertical: true)
                .frame(maxWidth: wraps ? SpeechBubbleView.maxWidth : nil)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Palette.cream, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Palette.ink, lineWidth: 2)
                )

            BubbleTail()
                .fill(Palette.cream)
                .overlay(BubbleTail().stroke(Palette.ink, lineWidth: 2))
                .frame(width: 14, height: 9)
                .offset(x: tailOffset, y: -1)
        }
        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
    }

    /// Bubble text wraps past this width. Half of it is the on-screen clamp.
    static let maxWidth: CGFloat = 220

    /// Roughly the longest line that still looks right unwrapped at this font.
    /// ponytail: character count instead of real text measurement; swap for
    /// TextRenderer sizing if a font change ever makes this misjudge.
    private var wraps: Bool { text.count > 26 || text.contains("\n") }

    /// Half the width this bubble will actually take, used to keep it on screen.
    static func halfWidth(for text: String) -> CGFloat {
        if text.count > 26 || text.contains("\n") { return maxWidth / 2 }
        // ~8.5pt per character at this display font, plus the horizontal padding.
        let measured = CGFloat(text.count) * 8.5 + 24
        return min(maxWidth, max(64, measured)) / 2
    }
}

private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

/// The prayer nudge. Unlike a normal speech bubble this one has no timer and no
/// close box — it stays until the user answers it.
struct SalahAskBubbleView: View {
    var text: String
    var showSnooze: Bool
    var tailOffset: CGFloat = 0
    var onRise: () -> Void
    var onSnooze: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 9) {
                Text(text)
                    .font(Typeface.display(16))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 7) {
                    Button("I'm getting up", action: onRise)
                        .buttonStyle(AskButtonStyle(filled: true))
                    if showSnooze {
                        Button("One more minute", action: onSnooze)
                            .buttonStyle(AskButtonStyle(filled: false))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: 260)
            .background(Palette.cream, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Palette.ink, lineWidth: 2)
            )

            BubbleTail()
                .fill(Palette.cream)
                .overlay(BubbleTail().stroke(Palette.ink, lineWidth: 2))
                .frame(width: 14, height: 9)
                .offset(x: tailOffset, y: -1)
        }
        .shadow(color: .black.opacity(0.16), radius: 8, y: 4)
    }
}

private struct AskButtonStyle: ButtonStyle {
    var filled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .foregroundStyle(filled ? Palette.cream : Palette.ink)
            .background(
                Capsule().fill(filled ? Palette.ink : Color.clear)
            )
            .overlay(
                Capsule().stroke(Palette.ink, lineWidth: filled ? 0 : 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
