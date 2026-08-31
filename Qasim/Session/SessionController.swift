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
    /// True while the companion is on the prayer mat. He finishes the prayer
    /// instead of breaking it to scold you.
    var praying: Bool = false
    var previewTheater: Escalation? = nil
    var previewMove: AngryMove?
    private(set) var activityStats: [ActivityStat] = []
    private(set) var hourlyFocusedSeconds = Array(repeating: 0.0, count: 24)
    private(set) var hourlyDistractedSeconds = Array(repeating: 0.0, count: 24)

    let monitor = DistractionMonitor()

    private var lastActivityID: String?

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
        activityStats = []
        hourlyFocusedSeconds = Array(repeating: 0, count: 24)
        hourlyDistractedSeconds = Array(repeating: 0, count: 24)
        lastActivityID = nil
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

        recordActivity(dt)

        if let preview = previewTheater {
            escalation = preview
            return
        }

        // He does not interrupt his own salah to yell at you. Distraction still
        // accrues honestly; the theatre resumes the moment he finishes.
        if praying {
            escalation = .calm
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
        } else if prefs.allows(.glance, previewing: previewMove), distractedFor >= t.glance {
            escalation = .glance
        } else {
            escalation = .calm
        }
    }

    private func recordActivity(_ seconds: TimeInterval) {
        guard seconds > 0, let activity = currentActivity else { return }
        let isFocused = isOnTask
        if let index = activityStats.firstIndex(where: { $0.id == activity.id }) {
            if isFocused {
                activityStats[index].focusedSeconds += seconds
            } else {
                activityStats[index].distractedSeconds += seconds
            }
            if lastActivityID != activity.id {
                activityStats[index].visits += 1
            }
        } else {
            activityStats.append(
                ActivityStat(
                    name: activity.name,
                    kind: activity.kind,
                    focusedSeconds: isFocused ? seconds : 0,
                    distractedSeconds: isFocused ? 0 : seconds,
                    visits: 1,
                    sourceIdentifier: activity.sourceIdentifier
                )
            )
        }
        lastActivityID = activity.id

        let hour = Calendar.current.component(.hour, from: Date())
        if isFocused {
            hourlyFocusedSeconds[hour] += seconds
        } else {
            hourlyDistractedSeconds[hour] += seconds
        }
    }

    private var currentActivity: (id: String, name: String, kind: ActivityKind, sourceIdentifier: String?)? {
        let context = monitor.context
        guard context.bundleID != QasimIdentity.bundleID else { return nil }
        if let host = context.host {
            return ("website:\(host)", host, .website, host)
        }
        guard !context.appName.isEmpty else { return nil }
        let bundleID = context.bundleID.isEmpty ? nil : context.bundleID
        return ("application:\(context.appName)", context.appName, .application, bundleID)
    }
}
