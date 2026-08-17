import Foundation

@Observable
@MainActor
final class SessionController {
    var phase: SessionPhase = .idle
    var taskTitle: String = ""
    var strategy: FocusStrategy = .allow
    var temper: Temper = .normal
    var durationMinutes: Int = 25
    var allowedApps: [AppIdentity] = []
    var blockedApps: [AppIdentity] = []
    var allowedSites: [SiteRule] = []
    var blockedSites: [SiteRule] = []

    var remaining: TimeInterval = 0
    var elapsedFocused: TimeInterval = 0
    var elapsedDistracted: TimeInterval = 0
    var distractedFor: TimeInterval = 0
    var escalation: Escalation = .calm
    var isOnTask: Bool = true
    var forceDistracted: Bool = false
    var previewTheater: Escalation? = nil
    var previewMove: AngryMove?

    let monitor = DistractionMonitor()

    var isStopwatch: Bool { durationMinutes <= 0 }

    var remainingLabel: String {
        let t = max(0, remaining)
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }

    var elapsedLabel: String {
        let t = elapsedFocused + elapsedDistracted
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }

    func start() {
        phase = .running
        remaining = isStopwatch ? 0 : TimeInterval(durationMinutes * 60)
        elapsedFocused = 0
        elapsedDistracted = 0
        distractedFor = 0
        escalation = .calm
        isOnTask = true
        forceDistracted = false
        previewTheater = nil
        previewMove = nil
    }

    func pause() {
        guard phase == .running else { return }
        phase = .paused
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .running
    }

    func end(finished: Bool) {
        phase = finished ? .finished : .idle
        escalation = .calm
        forceDistracted = false
        previewTheater = nil
        previewMove = nil
    }

    func resetToIdle() {
        phase = .idle
        remaining = 0
        distractedFor = 0
        escalation = .calm
        forceDistracted = false
        previewTheater = nil
        previewMove = nil
    }

    func tick(_ dt: TimeInterval, prefs: Preferences) {
        monitor.poll()

        guard phase == .running else {
            if previewTheater == nil {
                isOnTask = true
                escalation = .calm
            }
            return
        }

        if !isStopwatch {
            remaining -= dt
            if remaining <= 0 {
                remaining = 0
                phase = .finished
                escalation = .calm
                return
            }
        } else {
            remaining += dt
        }

        let allowedIDs = Set(allowedApps.map(\.bundleID))
        let blockedIDs = Set(blockedApps.map(\.bundleID))
        let naturallyOnTask = monitor.isOnTask(
            strategy: strategy,
            allowedApps: allowedIDs,
            blockedApps: blockedIDs,
            allowedSites: allowedSites,
            blockedSites: blockedSites
        )
        isOnTask = naturallyOnTask && !forceDistracted

        if isOnTask {
            elapsedFocused += dt
            distractedFor = 0
            if previewTheater == nil {
                escalation = .calm
            }
        } else {
            elapsedDistracted += dt
            distractedFor += dt
        }

        if let preview = previewTheater {
            escalation = preview
            return
        }

        if strategy == .company {
            escalation = .calm
            return
        }

        if isOnTask {
            return
        }

        let t = temper.thresholds
        if prefs.allows(.fire, previewing: previewMove), distractedFor >= t.fire {
            escalation = .fire
        } else if prefs.allows(.lights, previewing: previewMove), distractedFor >= t.lights {
            escalation = .lights
        } else if prefs.allows(.notes, previewing: previewMove), distractedFor >= t.lights {
            escalation = .notes
        } else if (prefs.allows(.talk, previewing: previewMove)
            || prefs.allows(.chase, previewing: previewMove)
            || prefs.allows(.sitOnWindow, previewing: previewMove)),
                  distractedFor >= t.nudge {
            escalation = .nudge
        } else {
            escalation = .calm
        }
    }
}
