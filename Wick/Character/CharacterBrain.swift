import AppKit
import CoreGraphics
import Foundation

enum WickPose: String {
    case idle
    case typing
    case angry
    case flipSwitch
    case sleep
    case qiyam
    case ruku
    case sujud
}

enum WickActivity: Equatable {
    case wander
    case sit
    case sleep
    case work
    case scold
    case theater
    case breakTime
    case salah
}

@Observable
@MainActor
final class CharacterBrain {
    var pose: WickPose = .idle
    var activity: WickActivity = .sit
    var position: CGPoint = .zero
    var target: CGPoint = .zero
    var facing: CGFloat = 1
    var hopPhase: Double = 0
    var breathePhase: Double = 0
    var bubble: String?
    var bubbleUntil: Date = .distantPast

    private var nextDecision = Date()
    private var lastEscalation: Escalation = .calm
    private var lastBreakActivity: BreakActivity?
    private var queuedSpeech: [String] = []
    private var queuedSpeechSeconds: TimeInterval = 0
    private var stride: CGFloat = 0

    func size(for prefs: Preferences) -> CGSize {
        let scale = prefs.reducedMotion ? min(prefs.characterScale, 1.1) : prefs.characterScale
        return CGSize(width: 156 * scale, height: 168 * scale)
    }

    func placeIn(_ canvas: CGRect, prefs: Preferences) {
        let home = perch(in: canvas, prefs: prefs, window: .zero)
        position = home
        target = home
    }

    func tick(
        dt: TimeInterval,
        canvas: CGRect,
        session: SessionController,
        prefs: Preferences,
        breakActivity: BreakActivity? = nil
    ) {
        breathePhase += dt
        let hopSpeed = prefs.reducedMotion ? 4.0 : (isMoving ? 10.0 : 2.4)
        hopPhase += dt * hopSpeed

        let char = size(for: prefs)
        let pad: CGFloat = 24
        let bounds = canvas.insetBy(dx: pad + char.width / 2, dy: pad + char.height / 2)

        if let breakActivity {
            liveBreak(dt: dt, canvas: canvas, activity: breakActivity, prefs: prefs)
        } else {
            lastBreakActivity = nil
            switch session.phase {
            case .idle, .paused:
                if prefs.alwaysOnDesktop {
                    liveOwnLife(dt: dt, bounds: bounds, canvas: canvas, prefs: prefs)
                } else {
                    pose = .idle
                    target = perch(in: canvas, prefs: prefs, window: .zero)
                    move(dt: dt, prefs: prefs)
                }
            case .running:
                liveWithSession(dt: dt, bounds: bounds, canvas: canvas, session: session, prefs: prefs)
            case .finished:
                pose = .idle
                activity = .sit
                target = perch(in: canvas, prefs: prefs, window: .zero)
                move(dt: dt, prefs: prefs)
                if lastEscalation != .calm {
                    speak(SpeechLines.doneLine(voice: prefs.voice, name: prefs.userName), seconds: 4, prefs: prefs)
                }
                lastEscalation = .calm
            }
        }

        if Date() > bubbleUntil {
            if queuedSpeech.isEmpty {
                bubble = nil
            } else {
                bubble = queuedSpeech.removeFirst()
                bubbleUntil = Date().addingTimeInterval(queuedSpeechSeconds)
            }
        }
    }

    func poke(prefs: Preferences) {
        speak(SpeechLines.pokeLine(companion: prefs.companion, voice: prefs.voice), seconds: 2.4, prefs: prefs)
        hopPhase += 2
    }

    func speak(_ text: String, seconds: TimeInterval, prefs: Preferences) {
        guard prefs.speechEnabled else { return }
        queuedSpeech = []
        bubble = text
        bubbleUntil = Date().addingTimeInterval(seconds)
    }

    private func speakSequence(_ lines: [String], seconds: TimeInterval, prefs: Preferences) {
        guard prefs.speechEnabled, let first = lines.first else { return }
        queuedSpeech = Array(lines.dropFirst())
        queuedSpeechSeconds = seconds
        bubble = first
        bubbleUntil = Date().addingTimeInterval(seconds)
    }

    func resetEscalationForPreview() {
        lastEscalation = .calm
    }

    var hopLift: CGFloat {
        if isMoving {
            return abs(sin(stride / 62 * .pi)) * 48
        }
        return CGFloat(sin(breathePhase * 2.1)) * 2.4
    }

    var breatheScale: CGFloat {
        1 + CGFloat(sin(breathePhase * 1.7)) * 0.018
    }

    var isMoving: Bool {
        hypot(target.x - position.x, target.y - position.y) > 6
    }

    private func liveOwnLife(dt: TimeInterval, bounds: CGRect, canvas: CGRect, prefs: Preferences) {
        if Date() >= nextDecision {
            decideIdle(bounds: bounds, canvas: canvas, prefs: prefs)
        }
        move(dt: dt, prefs: prefs)
        if isMoving {
            pose = .idle
            activity = .wander
        }
    }

    private func decideIdle(bounds: CGRect, canvas: CGRect, prefs: Preferences) {
        if !prefs.wanderWhenIdle || prefs.reducedMotion {
            activity = .sit
            pose = .idle
            target = perch(in: canvas, prefs: prefs, window: .zero)
            nextDecision = Date().addingTimeInterval(12)
            return
        }
        let roll = Int.random(in: 0..<100)
        if roll < 50 {
            activity = .wander
            pose = .idle
            target = randomPoint(in: bounds)
            nextDecision = Date().addingTimeInterval(Double.random(in: 2.4...5.5))
        } else if roll < 78 {
            activity = .sit
            pose = .idle
            target = perch(in: canvas, prefs: prefs, window: .zero)
            nextDecision = Date().addingTimeInterval(Double.random(in: 6...14))
        } else if roll < 88 {
            activity = .sleep
            pose = .sleep
            target = perch(in: canvas, prefs: prefs, window: .zero)
            nextDecision = Date().addingTimeInterval(Double.random(in: 8...16))
        } else {
            activity = .sit
            pose = .idle
            target = CGPoint(x: bounds.midX, y: bounds.maxY - 10)
            nextDecision = Date().addingTimeInterval(4)
        }
    }

    private func liveWithSession(
        dt: TimeInterval,
        bounds: CGRect,
        canvas: CGRect,
        session: SessionController,
        prefs: Preferences
    ) {
        let escalation = session.escalation
        if escalation != lastEscalation {
            if escalation == .calm, session.isOnTask {
                speak(SpeechLines.startLine(voice: prefs.voice, name: prefs.userName), seconds: 2.4, prefs: prefs)
            } else if escalation != .calm, prefs.allows(.talk, previewing: session.previewMove) {
                if let line = SpeechLines.line(
                    for: escalation,
                    appName: session.monitor.context.appName,
                    host: session.monitor.context.host,
                    voice: prefs.voice,
                    name: prefs.userName,
                    custom: prefs.customAngryLine
                ) {
                    speak(line, seconds: escalation >= .fire ? 3.5 : 2.6, prefs: prefs)
                }
            }
            lastEscalation = escalation
        }

        switch escalation {
        case .calm:
            activity = .work
            pose = .typing
            target = perch(in: canvas, prefs: prefs, window: session.monitor.context.windowFrame, forceFollow: prefs.perch == .followWindow)
        case .glance:
            activity = .scold
            pose = .idle
            target = towardOffendingWindow(session: session, canvas: canvas, closeness: 0.35)
        case .nudge:
            activity = .scold
            pose = .angry
            if prefs.allows(.chase, previewing: session.previewMove) {
                target = mousePoint(in: canvas)
            } else {
                target = towardOffendingWindow(session: session, canvas: canvas, closeness: 0.18)
            }
        case .lights:
            activity = .theater
            pose = .flipSwitch
            target = switchSpot(in: canvas, prefs: prefs)
        case .notes:
            activity = .theater
            pose = .angry
            target = towardOffendingWindow(session: session, canvas: canvas, closeness: 0.12)
        case .fire:
            activity = .theater
            pose = .angry
            if prefs.allows(.sitOnWindow, previewing: session.previewMove) {
                target = perch(in: canvas, prefs: prefs, window: session.monitor.context.windowFrame, forceFollow: true)
            } else {
                target = towardOffendingWindow(session: session, canvas: canvas, closeness: 0.08)
            }
        }

        move(dt: dt, prefs: prefs)
        if escalation == .lights {
            // The qasim-switch-* art faces right natively; the light show always
            // faces left regardless of which perch corner was picked.
            facing = -1
        }
        if isMoving {
            pose = escalation == .lights ? .idle : (escalation >= .nudge ? .angry : .idle)
        }
    }

    private func liveBreak(dt: TimeInterval, canvas: CGRect, activity breakActivity: BreakActivity, prefs: Preferences) {
        if lastBreakActivity != breakActivity {
            if breakActivity == .adhkar {
                speakSequence(SpeechLines.adhkarLines, seconds: 2.4, prefs: prefs)
            } else {
                speak(SpeechLines.breakLine(for: breakActivity), seconds: 6, prefs: prefs)
            }
            lastBreakActivity = breakActivity
        }
        self.activity = .breakTime
        pose = breakActivity.pose
        target = perch(in: canvas, prefs: prefs, window: .zero)
        move(dt: dt, prefs: prefs)
    }

    private func move(dt: TimeInterval, prefs: Preferences) {
        let dx = target.x - position.x
        let dy = target.y - position.y
        let dist = hypot(dx, dy)
        if dist < 4 {
            position = target
            stride = 0
            return
        }
        if abs(dx) > 2 {
            facing = dx >= 0 ? 1 : -1
        }
        let speed: CGFloat = prefs.reducedMotion ? 180 : (activity == .theater ? 420 : 260)
        let step = min(speed * CGFloat(dt), dist)
        stride += step
        position.x += dx / dist * step
        position.y += dy / dist * step
    }

    private func perch(in canvas: CGRect, prefs: Preferences, window: CGRect, forceFollow: Bool = false) -> CGPoint {
        let char = size(for: prefs)
        if (forceFollow || prefs.perch == .followWindow), window.width > 80 {
            return CGPoint(
                x: min(max(canvas.minX + 80, window.midX), canvas.maxX - 80),
                y: min(canvas.maxY - char.height * 0.4, max(canvas.minY + 80, canvas.maxY - 140))
            )
        }
        if prefs.perch == .bottomLeading {
            return CGPoint(x: canvas.minX + char.width * 0.62, y: canvas.maxY - char.height * 0.58)
        }
        return CGPoint(x: canvas.maxX - char.width * 0.62, y: canvas.maxY - char.height * 0.58)
    }

    private func switchSpot(in canvas: CGRect, prefs: Preferences) -> CGPoint {
        perch(in: canvas, prefs: prefs, window: .zero)
    }

    private func towardOffendingWindow(session: SessionController, canvas: CGRect, closeness: CGFloat) -> CGPoint {
        _ = closeness
        if session.monitor.context.windowFrame.width < 40 {
            return CGPoint(x: canvas.midX, y: canvas.maxY - 90)
        }
        let destX = min(max(canvas.minX + 80, canvas.maxX - 180), canvas.midX + 120)
        let destY = min(canvas.maxY - 80, max(canvas.minY + 120, canvas.maxY - 160))
        return CGPoint(x: destX, y: destY)
    }

    private func mousePoint(in canvas: CGRect) -> CGPoint {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.main else {
            return CGPoint(x: canvas.midX, y: canvas.midY)
        }
        return CGPoint(
            x: min(max(canvas.minX + 40, mouse.x - screen.frame.minX), canvas.maxX - 40),
            y: min(max(canvas.minY + 40, screen.frame.maxY - mouse.y), canvas.maxY - 40)
        )
    }

    private func randomPoint(in bounds: CGRect) -> CGPoint {
        guard bounds.width > 8, bounds.height > 8 else {
            return CGPoint(x: bounds.midX, y: bounds.midY)
        }
        return CGPoint(
            x: CGFloat.random(in: bounds.minX...bounds.maxX),
            y: CGFloat.random(in: (bounds.maxY - 160)...bounds.maxY)
        )
    }
}
