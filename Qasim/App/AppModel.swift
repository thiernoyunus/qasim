import AppKit
import SwiftUI

enum Theater: Equatable {
    case none
    case lights
    case fire
    case notes
    case spray
    case chase
}

enum ActionPreview: Equatable {
    case move(AngryMove)
    case breakActivity(BreakActivity)
    case salah
}

@Observable
@MainActor
final class AppModel {
    let session = SessionController()
    let progress = ProgressStore()
    let catalog = InstalledAppCatalog()
    let brain = CharacterBrain()
    let prefs = Preferences()
    let sounds = SoundBoard()
    let salah = SalahWatch()

    var theater: Theater = .none
    var lightsOff = false
    var flashWhite = false
    var switchPressed = false
    var now: TimeInterval = 0
    var characterPressed = false
    var fireRectSwiftUI: CGRect = .zero
    var effectAge: TimeInterval = 0
    var breakState: BreakState = .none
    var breakRemaining: TimeInterval = 0
    var breakActivity: BreakActivity?
    var actionPreview: ActionPreview?
    var actionPreviewAge: TimeInterval = 0
    var timerExpanded = false
    var isEditingSession = false
    var effectIntensity: CGFloat { min(1, CGFloat(effectAge / 1.5)) }
    var breakRemainingLabel: String {
        let t = max(0, breakRemaining)
        return String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
    var showPet: Bool {
        if prefs.isHiddenNow { return false }
        // A prayer nudge must be seen. It overrides the break panel and the
        // "only when you wander" setting, which would otherwise hide him (and
        // the nudge with him) for the whole time you stay on task.
        if salah.ask != nil || salah.matVisible { return true }
        if breakState != .none { return false }
        if session.phase == .running, session.isOnTask, !prefs.showWhileFocused {
            return false
        }
        return true
    }

    private var overlay: OverlayPanel?
    private var hosting: NSHostingView<OverlayRootView>?
    private var setupPanel: NSPanel?
    private var breakPanel: NSPanel?
    private var progressPanel: NSPanel?
    private var settingsPanel: NSPanel?
    private var timerPanel: NSPanel?
    private var timerHost: NSHostingView<TimerChipView>?
    private let timerState = TimerChipState()
    private var timerPanelOrigin: NSPoint?
    private var timerPanelSize = NSSize(width: 230, height: 140)
    private var timerPanelResizeStart: (size: NSSize, origin: NSPoint, mouse: NSPoint)?
    private var timerPanelMoveStart: (origin: NSPoint, mouse: NSPoint)?
    private var lastTimerExpanded = false
    private var lastTimerOnTop = true
    private var tickTask: Task<Void, Never>?
    private var lastTheater: Theater = .none
    private var distractionEffectAge: TimeInterval = 0
    private var distractionEffect: Theater = .none
    /// How long each distraction effect (fire, lights, notes...) runs before switching.
    static let distractionEffectDuration: TimeInterval = 20
    private var nextNoteSoundAt: TimeInterval = 0
    private var wasPraying = false
    private var lastAskRound: String?

    /// True once he has left his corner to stand in the middle and call you.
    var callingToPrayer: Bool {
        prefs.salahStandInTheWay && (salah.ask?.isStanding ?? false)
    }
    private var screen: NSScreen = NSScreen.main ?? NSScreen.screens[0]
    private var previewTask: Task<Void, Never>?
    /// When a preview borrows a session that isn't running (idle, paused, or
    /// finished), what to put back once it ends.
    private var previewSnapshot: PreviewSnapshot?

    private struct PreviewSnapshot {
        var phase: SessionPhase
        var remaining: TimeInterval
        var elapsedFocused: TimeInterval
        var elapsedDistracted: TimeInterval
    }
    private var lightShowTask: Task<Void, Never>?

    var isPreviewing: Bool { session.previewTheater != nil || actionPreview != nil }
    var previewingMove: AngryMove? { session.previewMove }
    var previewingSalah: Bool { actionPreview == .salah }
    var activeBreakActivity: BreakActivity? {
        if breakState == .running { return breakActivity }
        if case let .breakActivity(activity) = actionPreview { return activity }
        return nil
    }

    func start() {
        catalog.refresh()
#if DEBUG
        PrayerName.selfCheck()
        SalahAsk.selfCheck()
        BrowserInspector.selfCheck()
        ProgressStore.selfCheck()
        SiteRule.selfCheck()
        SiteBrand.selfCheck()
        SpeechLines.selfCheck()
#endif
        session.blockedApps = prefs.lastBlockedApps
        session.allowedApps = prefs.lastAllowedApps
        session.blockedSites = prefs.lastBlockedSites
        session.allowedSites = prefs.lastAllowedSites
        showOverlay()
        startTicking()
        // Salah asks for notification and location access. On first run that
        // waits until onboarding has explained why.
        if prefs.hasCompletedSetup {
            salah.start(prefs: prefs)
        }
        openSetup()
        installHotkeys()
    }

    func shutdown() {
        previewTask?.cancel()
        stopLightShow()
        tickTask?.cancel()
        overlay?.close()
        breakPanel?.close()
    }

    func openSetup() {
        if breakState != .none {
            presentBreakPanel()
            return
        }
        isEditingSession = false
        if setupPanel == nil {
            setupPanel = makeCardPanel(title: "Qasim", size: NSSize(width: 480, height: 720))
        }
        let view: AnyView = if prefs.hasCompletedSetup {
            // Onboarding is a one-time wizard (3 steps). What users see every time
            // after that is the home dashboard with a NEW button — the new-session
            // config sheet is reached from there.
            AnyView(HomeView().environment(self))
        } else {
            AnyView(SetupView().environment(self))
        }
        setupPanel?.contentView = cardHost(view)
        present(setupPanel)
    }

    func finishOnboarding() {
        prefs.hasCompletedSetup = true
        prefs.save()
        openNewSessionConfig()
    }

    /// Dock-icon click: bring back whatever screen is already open instead of resetting to Home.
    func reopen() {
        if breakState == .none, let panel = setupPanel, panel.isVisible {
            present(panel)
        } else {
            openSetup()
        }
    }

    /// Opens the one-screen new-session config (task, mode, list, duration).
    /// Reached from the home dashboard's New session button, or from the menu bar.
    func openNewSessionConfig() {
        if breakState != .none {
            presentBreakPanel()
            return
        }
        isEditingSession = false
        if setupPanel == nil {
            setupPanel = makeCardPanel(title: "Qasim", size: NSSize(width: 480, height: 720))
        }
        let view = NewSessionView().environment(self)
        setupPanel?.contentView = cardHost(view)
        present(setupPanel)
    }

    func openSettings() {
        if settingsPanel == nil {
            settingsPanel = makeCardPanel(title: "Settings", size: NSSize(width: 480, height: 720))
            let view = SettingsView()
                .environment(self)
            settingsPanel?.contentView = cardHost(view)
        }
        present(settingsPanel)
    }

    /// Back arrow on Settings / Analytics. They open over Home, so closing one shows Home again.
    func closeSettings() {
        settingsPanel?.orderOut(nil)
        reopen()
    }

    func closeProgress() {
        progressPanel?.orderOut(nil)
        reopen()
    }

    func openSessionEditor() {
        guard session.phase == .running || session.phase == .paused else {
            openSetup()
            return
        }
        isEditingSession = true
        timerExpanded = false
        if setupPanel == nil {
            setupPanel = makeCardPanel(title: "Qasim", size: NSSize(width: 480, height: 720))
        }
        let view = NewSessionView().environment(self)
        setupPanel?.contentView = cardHost(view)
        present(setupPanel)
    }

    func openProgress(_ tab: AnalyticsTab = .today) {
        if progressPanel == nil {
            progressPanel = makeCardPanel(title: "Analytics", size: NSSize(width: 480, height: 720))
        }
        let view = ProgressBoardView(initialTab: tab)
            .environment(self)
        progressPanel?.contentView = cardHost(view)
        present(progressPanel)
    }

    func restartSession(_ record: SessionRecord) {
        session.taskTitle = record.taskTitle
        session.durationMinutes = record.durationMinutes
        session.strategy = record.strategy
        if record.strategy == .allow, session.allowedApps.isEmpty, session.allowedSites.isEmpty {
            // Nothing to allow yet: let them pick before everything counts as a distraction.
            openNewSessionConfig()
            return
        }
        beginSession()
    }

    func beginSession() {
        stopPreview(spoken: false)
        // Starting over mid-session still logs the time already spent.
        if session.phase == .running || session.phase == .paused {
            recordSession(finished: false)
        }
        clearBreakFlow()
        setupPanel?.orderOut(nil)
        settingsPanel?.orderOut(nil)
        isEditingSession = false
        timerExpanded = false
        prefs.hasCompletedSetup = true
        prefs.save()
        session.start()
        brain.speak(SpeechLines.startLine(companion: prefs.companion, name: prefs.userName), seconds: 2.5, prefs: prefs)
        theater = .none
        stopLightShow()
        sounds.stopAll()
    }

    func saveSessionEdits() {
        guard isEditingSession else { return }
        if session.isStopwatch {
            session.remaining = 0
        } else {
            let elapsed = session.elapsedFocused + session.elapsedDistracted
            session.remaining = max(0, TimeInterval(session.durationMinutes * 60) - elapsed)
        }
        prefs.save()
        isEditingSession = false
        setupPanel?.orderOut(nil)
    }

    func stopSession(finished: Bool) {
        // A preview may be borrowing an idle or paused session. Put the real one
        // back first so a preview is never logged as a session of its own.
        if previewSnapshot != nil {
            stopPreview(spoken: false)
        }
        guard session.phase == .running || session.phase == .paused else { return }
        recordSession(finished: finished)
        session.end(finished: finished)
        isEditingSession = false
        timerExpanded = false
        if finished {
            brain.speak(SpeechLines.doneLine(companion: prefs.companion, name: prefs.userName), seconds: 4, prefs: prefs)
            showBreakChoice()
        } else {
            clearBreakFlow()
        }
        theater = .none
        stopLightShow()
        sounds.stopAll()
    }

    private func recordSession(finished: Bool) {
        progress.record(
            focused: session.elapsedFocused,
            distracted: session.elapsedDistracted,
            finishedSession: finished,
            taskTitle: session.taskTitle,
            durationMinutes: session.durationMinutes,
            strategy: session.strategy,
            activities: session.activityStats,
            hourlyFocusedSeconds: session.hourlyFocusedSeconds,
            hourlyDistractedSeconds: session.hourlyDistractedSeconds
        )
        // Remember what the user blocked/allowed so the next session's setup starts
        // pre-populated and they don't have to re-add the same sites.
        prefs.lastBlockedApps = session.blockedApps
        prefs.lastAllowedApps = session.allowedApps
        prefs.lastBlockedSites = session.blockedSites
        prefs.lastAllowedSites = session.allowedSites
        prefs.save()
    }

    func toggleTimerExpanded() {
        timerExpanded.toggle()
    }

    func togglePauseResume() {
        switch session.phase {
        case .running: session.pause()
        case .paused: session.resume()
        default: break
        }
    }

    func timerChip(
        size: CGSize? = nil,
        onResizeChanged: (() -> Void)? = nil,
        onResizeEnded: (() -> Void)? = nil
    ) -> TimerChipView {
        return TimerChipView(
            state: timerState,
            size: size,
            onToggleExpanded: { [weak self] in self?.toggleTimerExpanded() },
            onTogglePause: { [weak self] in self?.togglePauseResume() },
            onEdit: { [weak self] in self?.openSessionEditor() },
            onStop: { [weak self] in self?.stopSession(finished: false) },
            onFinish: { [weak self] in self?.stopSession(finished: true) },
            onResizeChanged: onResizeChanged,
            onResizeEnded: onResizeEnded,
            onQuickToggle: { [weak self] in self?.quickToggleCurrentApp() },
            onSnooze: { [weak self] in self?.session.snoozedUntil = Date().addingTimeInterval(2 * 60) },
            onEndSnooze: { [weak self] in self?.session.snoozedUntil = .distantPast },
            onMoveChanged: { [weak self] in self?.moveTimerPanel() },
            onMoveEnded: { [weak self] in self?.timerPanelMoveStart = nil }
        )
    }

    /// Qasim itself and system surfaces (Dock, Spotlight, login) are never
    /// judged, so offering to block or allow them would do nothing.
    private var canQuickToggleCurrentApp: Bool {
        let ctx = session.monitor.context
        return session.strategy != .company
            && !ctx.bundleID.isEmpty
            && !QasimIdentity.alwaysAllowed.contains(ctx.bundleID)
    }

    func currentQuickToggleTitle() -> String? {
        let ctx = session.monitor.context
        guard canQuickToggleCurrentApp else { return nil }
        if let host = ctx.host {
            // Covered already counts: a rule for youtube.com covers m.youtube.com and youtu.be.
            let rules = session.strategy == .block ? session.blockedSites : session.allowedSites
            let already = rules.contains { $0.matches(host, path: ctx.path) }
            return already ? nil : (session.strategy == .block ? "Block \(host)" : "Allow \(host)")
        }
        let app = AppIdentity(bundleID: ctx.bundleID, name: ctx.appName, path: "")
        let already = session.strategy == .block
            ? session.blockedApps.contains(app)
            : session.allowedApps.contains(app)
        return already ? nil : (session.strategy == .block ? "Block \(ctx.appName)" : "Allow \(ctx.appName)")
    }

    private var snoozeRemainingLabel: String? {
        let left = Int(session.snoozedUntil.timeIntervalSinceNow.rounded(.up))
        return left > 0 ? String(format: "%d:%02d", left / 60, left % 60) : nil
    }

    /// Smallest timer that still fits the full "Allow <app>" button and time.
    private var timerMinimumSize: NSSize {
        timerExpanded ? NSSize(width: 220, height: 200) : NSSize(width: 210, height: 130)
    }

    private let timerMaximumSize = NSSize(width: 340, height: 240)

    /// Drag anywhere on the timer to move it. Measured in screen coordinates,
    /// so the window moving under the cursor doesn't feed back into the drag.
    private func moveTimerPanel() {
        guard let timerPanel else { return }
        let mouse = NSEvent.mouseLocation
        if timerPanelMoveStart == nil {
            timerPanelMoveStart = (timerPanel.frame.origin, mouse)
        }
        guard let start = timerPanelMoveStart else { return }
        let origin = NSPoint(x: start.origin.x + mouse.x - start.mouse.x, y: start.origin.y + mouse.y - start.mouse.y)
        timerPanel.setFrameOrigin(origin)
        timerPanelOrigin = origin
    }

    func resizeTimerPanel() {
        guard let timerPanel else { return }
        let mouse = NSEvent.mouseLocation
        if timerPanelResizeStart == nil {
            timerPanelResizeStart = (timerPanel.frame.size, timerPanel.frame.origin, mouse)
        }
        guard let start = timerPanelResizeStart else { return }
        // Screen y grows upward; dragging the corner down makes it taller.
        let translation = CGSize(width: mouse.x - start.mouse.x, height: start.mouse.y - mouse.y)

        let visible = screen.visibleFrame
        let minimum = timerMinimumSize
        let maximum = timerMaximumSize
        let width = min(
            max(minimum.width, start.size.width + translation.width),
            min(maximum.width, visible.width)
        )
        let height = min(
            max(minimum.height, start.size.height + translation.height),
            min(maximum.height, visible.height)
        )
        let size = NSSize(width: width, height: height)
        let origin = NSPoint(
            x: min(max(visible.minX, start.origin.x), visible.maxX - size.width),
            y: min(
                max(visible.minY, start.origin.y - (size.height - start.size.height)),
                visible.maxY - size.height
            )
        )
        timerPanelSize = size
        timerPanelOrigin = origin
        timerPanel.setFrame(NSRect(origin: origin, size: size), display: true)
        // Just resize the host; the SwiftUI view already uses maxWidth/maxHeight
        // and lays itself out inside whatever frame we give it. Rebuilding the
        // rootView on every drag tick was the source of the sluggishness.
        timerHost?.frame = NSRect(origin: .zero, size: size)
    }

    func finishResizingTimerPanel() {
        timerPanelResizeStart = nil
    }

    func startBreak() {
        guard breakState == .choice else { return }
        let choices: [BreakActivity] = (prefs.breakAdhkar ? [.adhkar] : []) + (prefs.breakQuran ? [.quran] : [])
        breakActivity = choices.randomElement() ?? .rest
        breakRemaining = TimeInterval(prefs.breakMinutes * 60)
        breakState = .running
        presentBreakPanel()
    }

    func skipBreak() {
        guard breakState == .choice || breakState == .running else { return }
        showRepeatChoice()
    }

    func repeatSession() {
        guard breakState == .repeatChoice else { return }
        beginSession()
    }

    func declineRepeat() {
        guard breakState == .repeatChoice else { return }
        clearBreakFlow()
        session.resetToIdle()
        openSetup()
    }

    func previewLights() {
        togglePreview()
    }

    func togglePreview() {
        if isPreviewing {
            stopPreview(spoken: true)
        } else {
            startPreview()
        }
    }

    func preview(_ move: AngryMove) {
        if actionPreview == .move(move) {
            stopPreview(spoken: true)
            return
        }
        startMovePreview(move)
    }

    func quickToggleCurrentApp() {
        let ctx = session.monitor.context
        guard canQuickToggleCurrentApp else { return }
        if let host = ctx.host {
            guard let rule = SiteRule.normalize(host).map({ SiteRule(host: $0) }) else { return }
            if session.strategy == .block, !session.blockedSites.contains(rule) {
                session.blockedSites.append(rule)
            } else if session.strategy == .allow, !session.allowedSites.contains(rule) {
                session.allowedSites.append(rule)
            }
        } else {
            let app = AppIdentity(bundleID: ctx.bundleID, name: ctx.appName, path: "")
            if session.strategy == .block, !session.blockedApps.contains(app) {
                session.blockedApps.append(app)
            } else if session.strategy == .allow, !session.allowedApps.contains(app) {
                session.allowedApps.append(app)
            }
        }
    }

    func preview(_ activity: BreakActivity) {
        if actionPreview == .breakActivity(activity) {
            stopPreview(spoken: true)
            return
        }
        stopPreview(spoken: false)
        actionPreview = .breakActivity(activity)
        actionPreviewAge = 0
        brain.resetEscalationForPreview()
        brain.speak(SpeechLines.breakLine(for: activity), seconds: 5, prefs: prefs)
        startTimedActionPreview()
    }

    func previewSalah() {
        if actionPreview == .salah {
            stopPreview(spoken: true)
            return
        }
        stopPreview(spoken: false)
        actionPreview = .salah
        actionPreviewAge = 0
        brain.resetEscalationForPreview()
        brain.speak("Previewing Salah.", seconds: 4, prefs: prefs)
        startTimedActionPreview()
    }

    func startPreview() {
        previewTask?.cancel()
        actionPreview = nil
        actionPreviewAge = 0
        session.previewMove = nil
        session.previewTheater = .lights
        session.forceDistracted = true
        borrowSessionForPreview()
        brain.resetEscalationForPreview()
        brain.speak(SpeechLines.previewStartLine(companion: prefs.companion), seconds: 5, prefs: prefs)
        previewTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            session.previewTheater = .fire
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            stopPreview(spoken: true)
        }
    }

    private func startMovePreview(_ move: AngryMove) {
        stopPreview(spoken: false)
        actionPreview = .move(move)
        actionPreviewAge = 0
        session.previewMove = move
        session.previewTheater = move.previewEscalation
        session.forceDistracted = true
        borrowSessionForPreview()
        brain.resetEscalationForPreview()
        brain.speak(SpeechLines.previewLine(for: move), seconds: 5, prefs: prefs)
        previewTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            stopPreview(spoken: true)
        }
    }

    private func borrowSessionForPreview() {
        guard session.phase != .running else { return }
        if previewSnapshot == nil {
            previewSnapshot = PreviewSnapshot(
                phase: session.phase,
                remaining: session.remaining,
                elapsedFocused: session.elapsedFocused,
                elapsedDistracted: session.elapsedDistracted
            )
        }
        session.phase = .running
        session.remaining = 90
    }

    private func startTimedActionPreview() {
        previewTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            stopPreview(spoken: true)
        }
    }

    func stopPreview(spoken: Bool) {
        previewTask?.cancel()
        previewTask = nil
        let wasPreviewing = session.previewTheater != nil || session.forceDistracted
        session.previewTheater = nil
        session.previewMove = nil
        session.forceDistracted = false
        actionPreview = nil
        actionPreviewAge = 0
        theater = .none
        stopLightShow()
        sounds.stopAll()
        if let snapshot = previewSnapshot {
            if snapshot.phase == .idle {
                session.resetToIdle()
            } else {
                session.phase = snapshot.phase
                session.remaining = snapshot.remaining
                session.elapsedFocused = snapshot.elapsedFocused
                session.elapsedDistracted = snapshot.elapsedDistracted
                session.distractedFor = 0
                session.escalation = .calm
            }
        }
        previewSnapshot = nil
        if spoken, wasPreviewing {
            brain.speak(SpeechLines.previewStopLine(companion: prefs.companion), seconds: 2.4, prefs: prefs)
        }
    }

    func poke() {
        if isPreviewing {
            stopPreview(spoken: true)
            return
        }
        brain.poke(prefs: prefs)
    }

    // MARK: - Prayer nudge

    /// "I'm getting up." He steps aside and lets you go.
    func answerSalahRising() {
        salah.acknowledgeAsk()
        brain.speak(SpeechLines.salahRising(), seconds: 3, prefs: prefs)
    }

    /// "One more minute." He comes back when it's up, and says so.
    func answerSalahSnooze() {
        let again = salah.ask?.snoozes ?? 0
        salah.snoozeAsk()
        brain.speak(SpeechLines.salahSnooze(times: again), seconds: 3, prefs: prefs)
    }

    private func installHotkeys() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleHotkey(event)
            return event
        }
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleHotkey(event)
        }
    }

    private func handleHotkey(_ event: NSEvent) {
        let optionShift = event.modifierFlags.contains([.option, .shift])
        guard optionShift else { return }
        if event.charactersIgnoringModifiers == "l" || event.charactersIgnoringModifiers == "L" {
            previewLights()
        } else if event.charactersIgnoringModifiers == "w" || event.charactersIgnoringModifiers == "W" {
            openSetup()
        }
    }

    private func showOverlay() {
        screen = NSScreen.main ?? NSScreen.screens[0]
        let panel = OverlayChrome.panel(on: screen, clickable: true)
        let root = OverlayRootView(model: self, screenFrame: screen.frame)
        let container = FlippedContainer(frame: panel.contentView?.bounds ?? screen.frame)
        container.autoresizingMask = [.width, .height]
        let host = NSHostingView(rootView: root)
        host.frame = container.bounds
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)
        panel.contentView = container
        panel.orderFrontRegardless()
        overlay = panel
        hosting = host
        let canvas = swiftUIVisibleCanvas()
        brain.placeIn(canvas, prefs: prefs)
    }

    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            var last = Date()
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                let nowDate = Date()
                let dt = nowDate.timeIntervalSince(last)
                last = nowDate
                self?.step(dt)
            }
        }
    }

    private func step(_ dt: TimeInterval) {
        now += dt
        if let current = NSScreen.main, current.frame != screen.frame {
            screen = current
            overlay?.setFrame(current.frame, display: true)
        }

        let wasRunning = session.phase == .running
        session.tick(dt, prefs: prefs)
        if wasRunning, session.phase == .finished {
            recordSession(finished: true)
            brain.speak(SpeechLines.doneLine(companion: prefs.companion, name: prefs.userName), seconds: 4, prefs: prefs)
            showBreakChoice()
        }
        if breakState == .running {
            breakRemaining = max(0, breakRemaining - dt)
            if breakRemaining == 0 {
                finishBreak()
            }
        }
        if actionPreview != nil { actionPreviewAge += dt }
        if prefs.hasCompletedSetup {
            stepSalah(dt: dt)
        }
        updateTheater(dt: dt)
        finishStep(dt: dt)
    }

    private func stepSalah(dt: TimeInterval) {
        salah.refresh(now: Date(), dt: dt, prefs: prefs)
        // He finishes his prayer before he goes back to policing you.
        // Stay quiet during prayer even with "Pray on the desktop" off: the user may be praying.
        session.praying = salah.prayerInProgress
        if wasPraying, !salah.matVisible {
            let inSession = session.phase == .running || session.phase == .paused
            brain.speak(
                SpeechLines.salahDone(voice: prefs.voice, task: inSession ? session.taskTitle : ""),
                seconds: 5,
                prefs: prefs
            )
        }
        wasPraying = salah.matVisible
        salah.refreshAsk(now: Date(), prefs: prefs)
        // A chime each time the nudge comes back, so a fresh one after a borrowed
        // minute is heard rather than appearing silently behind a window.
        let askingRound = salah.ask.map { "\($0.name.rawValue).\($0.snoozes)" }
        if askingRound != lastAskRound {
            if askingRound != nil, prefs.salahChime {
                sounds.playSalahChime()
            }
            lastAskRound = askingRound
        }
        if let soon = salah.consumeSoonAnnouncement() {
            // Only narrate in passing when the waiting nudge is off; otherwise the
            // nudge itself is the announcement.
            if !prefs.salahAsk {
                brain.speak(SpeechLines.salahSoon(soon.0, at: soon.1), seconds: 5.5, prefs: prefs)
            }
        }
        if let name = salah.consumeNowAnnouncement() {
            brain.speak(SpeechLines.salahNow(name), seconds: 6, prefs: prefs)
        }
    }

    private func finishStep(dt: TimeInterval) {
        if theater != lastTheater {
            effectAge = 0
            lastTheater = theater
        }
        effectAge += dt
        sounds.volume = Float(prefs.yellVolume)
        fireRectSwiftUI = convertWindowToSwiftUI(session.monitor.context.windowFrame)
        brain.tick(
            dt: dt,
            canvas: swiftUIVisibleCanvas(),
            session: session,
            prefs: prefs,
            theater: theater,
            breakActivity: activeBreakActivity,
            callingToPrayer: callingToPrayer
        )
        if salah.matVisible || previewingSalah {
            brain.activity = .salah
            brain.pose = previewingSalah
                ? [.qiyam, .ruku, .sujud][Int(actionPreviewAge / 2.4) % 3]
                : salah.salahPose
        }
        let prayerOnScreen = salah.ask != nil || salah.matVisible
        overlay?.alphaValue = (prefs.alwaysOnDesktop || session.phase != .idle || prayerOnScreen) ? 1 : 0
        updateTimerPanel()
        updateClickThrough()
    }

    private func updateTheater(dt: TimeInterval) {
        let lightsAllowed = prefs.allows(.lights, previewing: session.previewMove)
        let notesAllowed = prefs.allows(.notes, previewing: session.previewMove)
        let fireAllowed = prefs.allows(.fire, previewing: session.previewMove)
        let sprayAllowed = lightsAllowed || notesAllowed || fireAllowed

        // The character closes the laptop and stands angry before any
        // distraction effect begins. Movement is held by CharacterBrain; this
        // also gates effects that do not already wait on arrival, such as notes
        // and fire.
        if brain.distractionTransitionActive
            || brain.willBeginDistractionTransition(for: session, prefs: prefs) {
            distractionEffectAge = 0
            distractionEffect = .none
            theater = .none
            stopLightShow()
            sounds.stopFire()
            sounds.stopSpray()
            return
        }

        switch session.escalation {
        case .glance, .nudge, .lights, .notes, .fire:
            let effects = [
                prefs.allows(.chase, previewing: session.previewMove) ? Theater.chase : nil,
                lightsAllowed ? Theater.lights : nil,
                notesAllowed ? Theater.notes : nil,
                fireAllowed ? Theater.fire : nil,
                sprayAllowed ? Theater.spray : nil
            ].compactMap { $0 }
            guard !effects.isEmpty else {
                theater = .none
                distractionEffect = .none
                distractionEffectAge = 0
                stopLightShow()
                sounds.stopFire()
                sounds.stopSpray()
                return
            }

            // Random order so the person can't predict what's coming next;
            // never repeat the effect that just played.
            if !effects.contains(distractionEffect) {
                distractionEffect = effects.randomElement()!
                distractionEffectAge = 0
            } else {
                distractionEffectAge += dt
                if distractionEffectAge >= Self.distractionEffectDuration {
                    distractionEffect = effects.filter { $0 != distractionEffect }.randomElement() ?? distractionEffect
                    distractionEffectAge = 0
                }
            }

            let previousTheater = theater
            theater = distractionEffect
            if theater == .chase {
                stopLightShow()
                sounds.stopFire()
                sounds.stopSpray()
            } else if theater == .lights {
                sounds.stopFire()
                sounds.stopSpray()
                if previousTheater != .lights {
                    runLightShow()
                }
            } else if theater == .notes {
                stopLightShow()
                sounds.stopFire()
                sounds.stopSpray()
                if prefs.allows(.sound, previewing: session.previewMove) {
                    if previousTheater != .notes {
                        sounds.playNotes()
                        nextNoteSoundAt = 0.75
                    } else if distractionEffectAge >= nextNoteSoundAt {
                        // The canvas adds notes continuously; echo the paper sound
                        // on a short cadence instead of only at stage entry.
                        sounds.playNotes()
                        nextNoteSoundAt += 0.75
                    }
                }
            } else if theater == .fire, prefs.allows(.sound, previewing: session.previewMove) {
                stopLightShow()
                sounds.stopSpray()
                sounds.startFire()
            } else if theater == .fire {
                stopLightShow()
                sounds.stopFire()
                sounds.stopSpray()
            } else {
                stopLightShow()
                sounds.stopFire()
                if prefs.allows(.sound, previewing: session.previewMove) {
                    sounds.startSpray()
                } else {
                    sounds.stopSpray()
                }
            }
        default:
            stopLightShow()
            distractionEffect = .none
            distractionEffectAge = 0
            if session.previewTheater == nil {
                theater = .none
                lightsOff = false
            }
            sounds.stopFire()
            sounds.stopSpray()
        }
    }

    private func runLightShow() {
        guard !prefs.motionReduced else { return }
        stopLightShow()
        lightShowTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                // Let the character reach the switch before the room reacts.
                try await Task.sleep(for: .milliseconds(16))
                while self.theater == .lights, self.brain.isMoving {
                    try await Task.sleep(for: .milliseconds(16))
                }
                guard self.theater == .lights, self.brain.pose == .flipSwitch else {
                    self.lightShowTask = nil
                    return
                }
                assert(!self.brain.isMoving, "Light show must wait for the companion to reach the switch")
                try await Task.sleep(for: .milliseconds(180))

                // Keep the switch animation alive for the whole light stage.
                // The old four-pass loop finished after ~3 seconds, leaving the
                // remaining hold time looking like a frozen pause.
                while self.theater == .lights {
                    self.switchPressed = true
                    if self.prefs.allows(.sound, previewing: self.session.previewMove) { self.sounds.playSwitch() }
                    try await Task.sleep(for: .milliseconds(110))
                    self.flashWhite = true
                    try await Task.sleep(for: .milliseconds(70))
                    self.flashWhite = false
                    self.lightsOff = true
                    try await Task.sleep(for: .milliseconds(360))
                    self.switchPressed = false
                    if self.prefs.allows(.sound, previewing: self.session.previewMove) { self.sounds.playSwitch() }
                    self.lightsOff = false
                    try await Task.sleep(for: .milliseconds(240))
                }

                self.lightShowTask = nil
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
    }

    private func stopLightShow() {
        lightShowTask?.cancel()
        lightShowTask = nil
        switchPressed = false
        flashWhite = false
        lightsOff = false
    }

    private func updateClickThrough() {
        guard let overlay else { return }
        if characterPressed {
            overlay.ignoresMouseEvents = false
            return
        }
        let mouse = NSEvent.mouseLocation
        let local = CGPoint(x: mouse.x - screen.frame.minX, y: screen.frame.maxY - mouse.y)
        let size = brain.size(for: prefs)
        let charRect = CGRect(
            x: brain.position.x - size.width / 2,
            y: brain.position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        // The prayer nudge is taller (it carries two buttons) and must stay
        // clickable, so it gets its own hit box.
        let asking = salah.ask != nil
        // The adhan wording runs two lines, so the standing nudge is taller.
        let askHeight: CGFloat = callingToPrayer ? 140 : 112
        let bubbleRect = CGRect(
            x: brain.position.x - 140,
            y: brain.position.y - size.height * 0.5 - askHeight - 6,
            width: 280,
            height: askHeight
        )
        // Only the prayer nudge has buttons; ordinary speech is not clickable, so
        // clicks pass straight through to whatever is behind it.
        let overUI = (showPet && charRect.contains(local))
            || (showPet && asking && bubbleRect.contains(local))
        overlay.ignoresMouseEvents = !overUI
    }

    private func updateTimerPanel() {
        let remaining = session.remainingLabel
        let angry = session.escalation >= .nudge && session.phase == .running
        let paused = session.phase == .paused
        timerState.update(
            remaining: remaining,
            angry: angry,
            task: session.taskTitle,
            paused: paused,
            expanded: timerExpanded,
            quickToggleTitle: currentQuickToggleTitle(),
            quickToggleHost: session.monitor.context.host,
            quickToggleBundleID: session.monitor.context.bundleID,
            snoozeRemaining: snoozeRemainingLabel
        )

        let shouldShow = prefs.showTimerChip
            && !isEditingSession
            && (session.phase == .running || session.phase == .paused)
        if !shouldShow {
            timerPanel?.orderOut(nil)
            return
        }

        let minimum = timerMinimumSize
        let maximum = timerMaximumSize
        timerPanelSize.width = min(max(timerPanelSize.width, minimum.width), maximum.width)
        timerPanelSize.height = min(max(timerPanelSize.height, minimum.height), maximum.height)
        let size = timerPanelSize
        if let timerPanel, timerPanelOrigin != nil, timerPanelResizeStart == nil {
            // Keep the top edge where the user put it when the size changes;
            // AppKit grows windows from the bottom corner, which made it drop.
            let frame = timerPanel.frame
            timerPanelOrigin = NSPoint(x: frame.minX, y: frame.maxY - size.height)
        }
        let layoutChanged = timerPanel == nil
            || timerExpanded != lastTimerExpanded
            || timerPanel?.frame.size != size
        let stackingChanged = timerPanel == nil || prefs.timerOnTop != lastTimerOnTop

        if timerPanel == nil {
            let panel = TimerOverlayPanel(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.hidesOnDeactivate = false
            panel.isMovableByWindowBackground = true
            panel.isReleasedWhenClosed = false
            panel.ignoresMouseEvents = false
            panel.title = "Qasim Timer"
            let host = FirstClickHostingView(rootView: timerChip(
                size: size,
                onResizeChanged: { [weak self] in self?.resizeTimerPanel() },
                onResizeEnded: { [weak self] in self?.finishResizingTimerPanel() }
            ))
            host.frame = NSRect(origin: .zero, size: size)
            // The panel's size comes from timerPanelSize only; don't let the
            // SwiftUI content grow or shrink the window behind our back.
            host.sizingOptions = []
            panel.contentView = host
            timerHost = host
            timerPanel = panel
        } else if layoutChanged {
            timerPanel?.setContentSize(size)
            timerHost?.frame = NSRect(origin: .zero, size: size)
        }
        lastTimerExpanded = timerExpanded
        lastTimerOnTop = prefs.timerOnTop
        timerPanel?.level = prefs.timerOnTop
            ? NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)) - 1)
            : .normal
        timerPanel?.isFloatingPanel = prefs.timerOnTop
        timerPanel?.hidesOnDeactivate = !prefs.timerOnTop
        if !layoutChanged && !stackingChanged {
            if timerPanel?.isVisible == false { timerPanel?.orderFrontRegardless() }
            return
        }
        let vis = screen.visibleFrame
        if timerPanelOrigin == nil {
            timerPanelOrigin = NSPoint(x: vis.maxX - size.width - 20, y: vis.maxY - size.height - 20)
        }
        let currentOrigin = timerPanelOrigin ?? NSPoint(x: vis.maxX - size.width - 20, y: vis.maxY - size.height - 20)
        let origin = NSPoint(
            x: min(max(vis.minX, currentOrigin.x), vis.maxX - size.width),
            y: min(max(vis.minY, currentOrigin.y), vis.maxY - size.height)
        )
        timerPanelOrigin = origin
        if timerPanelResizeStart == nil {
            timerPanel?.setFrameOrigin(origin)
        }
        timerPanel?.orderFrontRegardless()
    }

    private func swiftUIVisibleCanvas() -> CGRect {
        let vis = screen.visibleFrame
        return CGRect(
            x: vis.minX - screen.frame.minX,
            y: screen.frame.maxY - vis.maxY,
            width: vis.width,
            height: vis.height
        )
    }

    private func convertWindowToSwiftUI(_ appKit: CGRect) -> CGRect {
        guard appKit.width > 8 else { return .zero }
        return CGRect(
            x: appKit.minX - screen.frame.minX,
            y: screen.frame.maxY - appKit.maxY,
            width: appKit.width,
            height: appKit.height
        )
    }

    /// Card windows size themselves from their SwiftUI content, so the smallest
    /// allowed window lives here. Below it the one-column layouts start to crowd.
    private func cardHost<V: View>(_ view: V) -> NSView {
        NSHostingView(rootView: view.frame(minWidth: 440, minHeight: 660))
    }

    private func makeCardPanel(title: String, size: NSSize) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        // Keep cards at the normal window level. The character overlay is transparent
        // where these cards are shown, so they stay visible without floating over
        // whichever app the user clicks next.
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.titlebarAppearsTransparent = true
        panel.appearance = NSAppearance(named: .aqua)
        panel.backgroundColor = NSColor(Palette.ground)
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.midX - size.width / 2
            let y = screen.visibleFrame.midY - size.height / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        // Remembers where the user put it and how big they made it.
        panel.setFrameAutosaveName("Qasim.\(title)")
        return panel
    }

    private func present(_ panel: NSPanel?, activate: Bool = true) {
        guard let panel else { return }
        panel.level = .normal
        // Stay put when another app (or the screenshot drag thumbnail) takes focus;
        // at normal level the card already sits behind whatever the user switches to.
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = false
        panel.appearance = NSAppearance(named: .aqua)
        if activate {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }
        panel.orderFrontRegardless()
    }

    private func showBreakChoice() {
        guard breakState == .none else { return }
        breakRemaining = TimeInterval(prefs.breakMinutes * 60)
        breakActivity = nil
        breakState = .choice
        setupPanel?.orderOut(nil)
        presentBreakPanel(activate: false)
    }

    private func finishBreak() {
        guard breakState == .running else { return }
        breakRemaining = 0
        breakActivity = nil
        breakState = .repeatChoice
        brain.speak(SpeechLines.breakFinishedLine(), seconds: 4, prefs: prefs)
        presentBreakPanel(activate: false)
    }

    private func showRepeatChoice() {
        breakRemaining = 0
        breakActivity = nil
        breakState = .repeatChoice
        presentBreakPanel()
    }

    private func presentBreakPanel(activate: Bool = true) {
        if breakPanel == nil {
            breakPanel = makeCardPanel(title: "Break", size: NSSize(width: 480, height: 640))
            breakPanel?.contentView = cardHost(BreakView().environment(self))
        }
        breakPanel?.title = breakState == .running ? "Break" : "Session complete"
        present(breakPanel, activate: activate)
    }

    private func clearBreakFlow() {
        breakState = .none
        breakRemaining = 0
        breakActivity = nil
        breakPanel?.orderOut(nil)
    }
}
