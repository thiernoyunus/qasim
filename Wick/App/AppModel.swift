import AppKit
import SwiftUI

enum Theater: Equatable {
    case none
    case lights
    case fire
    case notes
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
    var timerCenter: CGPoint?
    var isEditingSession = false
    var effectIntensity: CGFloat { min(1, CGFloat(effectAge / 2.1)) }
    var breakRemainingLabel: String {
        let t = max(0, breakRemaining)
        return String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
    var showPet: Bool {
        if prefs.isHiddenNow { return false }
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
    private var timerPanelOrigin: NSPoint?
    private var timerPanelDragStart: NSPoint?
    private var timerPanelSize = NSSize(width: 160, height: 110)
    private var timerPanelResizeStart: (size: NSSize, origin: NSPoint)?
    private var lastTimerRemaining = ""
    private var lastTimerAngry = false
    private var lastTimerTask = ""
    private var lastTimerPaused = false
    private var lastTimerExpanded = false
    private var tickTask: Task<Void, Never>?
    private var lastLightsKick: Escalation = .calm
    private var lastTheater: Theater = .none
    private var screen: NSScreen = NSScreen.main ?? NSScreen.screens[0]
    private var previewTask: Task<Void, Never>?
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
        showOverlay()
        startTicking()
        salah.start(prefs: prefs)
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
            setupPanel = makeCardPanel(title: "Wick", size: NSSize(width: 480, height: 720))
        }
        let view: AnyView = if prefs.hasCompletedSetup {
            // Onboarding is a one-time wizard (3 steps). What users see every time
            // after that is the home dashboard with a NEW button — the new-session
            // config sheet is reached from there.
            AnyView(HomeView().environment(self))
        } else {
            AnyView(SetupView().environment(self))
        }
        setupPanel?.contentView = NSHostingView(rootView: view)
        present(setupPanel)
    }

    /// Opens the detailed new-session config sheet (task -> mode -> apps -> duration).
    /// Reached from the home dashboard's NEW button, or from the menu bar.
    func openNewSessionConfig() {
        if setupPanel == nil {
            setupPanel = makeCardPanel(title: "Wick", size: NSSize(width: 480, height: 720))
        }
        let view = NewSessionView().environment(self)
        setupPanel?.contentView = NSHostingView(rootView: view)
        present(setupPanel)
    }

    func openSettings() {
        if settingsPanel == nil {
            settingsPanel = makeCardPanel(title: "Customize", size: NSSize(width: 520, height: 720))
            let view = SettingsView()
                .environment(self)
            settingsPanel?.contentView = NSHostingView(rootView: view)
        }
        present(settingsPanel)
    }

    func openSessionEditor() {
        guard session.phase == .running || session.phase == .paused else {
            openSetup()
            return
        }
        isEditingSession = true
        timerExpanded = false
        if setupPanel == nil {
            setupPanel = makeCardPanel(title: "Wick", size: NSSize(width: 480, height: 720))
        }
        let view = NewSessionView().environment(self)
        setupPanel?.contentView = NSHostingView(rootView: view)
        present(setupPanel)
    }

    func openProgress() {
        if progressPanel == nil {
            progressPanel = makeCardPanel(title: "Progress", size: NSSize(width: 460, height: 520))
            let view = ProgressBoardView()
                .environment(self)
            progressPanel?.contentView = NSHostingView(rootView: view)
        }
        present(progressPanel)
    }

    func restartSession(_ record: SessionRecord) {
        session.taskTitle = record.taskTitle
        session.durationMinutes = record.durationMinutes
        session.strategy = record.strategy
        beginSession()
    }

    func beginSession() {
        stopPreview(spoken: false)
        clearBreakFlow()
        setupPanel?.orderOut(nil)
        settingsPanel?.orderOut(nil)
        isEditingSession = false
        timerExpanded = false
        prefs.hasCompletedSetup = true
        // If the previous session left a block/allow list, pre-populate the new one
        // so the user doesn't have to re-add the same sites/apps every time.
        if !prefs.lastBlockedApps.isEmpty { session.blockedApps = prefs.lastBlockedApps }
        if !prefs.lastBlockedSites.isEmpty { session.blockedSites = prefs.lastBlockedSites }
        if !prefs.lastAllowedApps.isEmpty { session.allowedApps = prefs.lastAllowedApps }
        if !prefs.lastAllowedSites.isEmpty { session.allowedSites = prefs.lastAllowedSites }
        prefs.save()
        session.start()
        brain.speak(SpeechLines.startLine(voice: prefs.voice, name: prefs.userName), seconds: 2.5, prefs: prefs)
        theater = .none
        stopLightShow()
        lastLightsKick = .calm
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
        if session.phase == .running || session.phase == .paused || session.phase == .finished {
            progress.record(
                focused: session.elapsedFocused,
                distracted: session.elapsedDistracted,
                finishedSession: finished,
                taskTitle: session.taskTitle,
                durationMinutes: session.durationMinutes,
                strategy: session.strategy
            )
        }
        // Remember what the user blocked/allowed so the next session's setup starts
        // pre-populated and they don't have to re-add the same sites.
        prefs.lastBlockedApps = session.blockedApps
        prefs.lastAllowedApps = session.allowedApps
        prefs.lastBlockedSites = session.blockedSites
        prefs.lastAllowedSites = session.allowedSites
        prefs.save()
        session.end(finished: finished)
        isEditingSession = false
        timerExpanded = false
        if finished {
            brain.speak(SpeechLines.doneLine(voice: prefs.voice, name: prefs.userName), seconds: 4, prefs: prefs)
            showBreakChoice()
        } else {
            clearBreakFlow()
        }
        theater = .none
        stopLightShow()
        sounds.stopAll()
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
        onDragChanged: ((CGSize) -> Void)? = nil,
        onDragEnded: (() -> Void)? = nil,
        onResizeChanged: ((CGSize) -> Void)? = nil,
        onResizeEnded: (() -> Void)? = nil
    ) -> TimerChipView {
        return TimerChipView(
            remaining: session.remainingLabel,
            angry: session.escalation >= .nudge && session.phase == .running,
            task: session.taskTitle,
            size: size,
            paused: session.phase == .paused,
            expanded: timerExpanded,
            onToggleExpanded: { [weak self] in self?.toggleTimerExpanded() },
            onTogglePause: { [weak self] in self?.togglePauseResume() },
            onEdit: { [weak self] in self?.openSessionEditor() },
            onStop: { [weak self] in self?.stopSession(finished: false) },
            onDragChanged: onDragChanged,
            onDragEnded: onDragEnded,
            onResizeChanged: onResizeChanged,
            onResizeEnded: onResizeEnded,
        )
    }

    func currentQuickToggleTitle() -> String? {
        let ctx = session.monitor.context
        guard session.strategy != .company, !ctx.bundleID.isEmpty else { return nil }
        if let host = ctx.host {
            guard let rule = SiteRule.normalize(host).map(SiteRule.init) else { return nil }
            let already = session.strategy == .block
                ? session.blockedSites.contains(rule)
                : session.allowedSites.contains(rule)
            return already ? nil : (session.strategy == .block ? "Block \(host)" : "Allow \(host)")
        }
        let app = AppIdentity(bundleID: ctx.bundleID, name: ctx.appName, path: "")
        let already = session.strategy == .block
            ? session.blockedApps.contains(app)
            : session.allowedApps.contains(app)
        return already ? nil : (session.strategy == .block ? "Block \(ctx.appName)" : "Allow \(ctx.appName)")
    }

    func moveTimerPanel(_ translation: CGSize) {
        guard let timerPanel else { return }
        if timerPanelDragStart == nil {
            timerPanelDragStart = timerPanel.frame.origin
        }
        let start = timerPanelDragStart ?? timerPanel.frame.origin
        let size = timerPanel.frame.size
        let visible = screen.visibleFrame
        let x = min(max(visible.minX, start.x + translation.width), visible.maxX - size.width)
        let y = min(max(visible.minY, start.y - translation.height), visible.maxY - size.height)
        let origin = NSPoint(x: x, y: y)
        timerPanel.setFrameOrigin(origin)
        timerPanelOrigin = origin
    }

    func finishMovingTimerPanel() {
        timerPanelDragStart = nil
    }

    func resizeTimerPanel(_ translation: CGSize) {
        guard let timerPanel else { return }
        if timerPanelResizeStart == nil {
            timerPanelResizeStart = (timerPanel.frame.size, timerPanel.frame.origin)
        }
        guard let start = timerPanelResizeStart else { return }

        let visible = screen.visibleFrame
        let minimum = timerExpanded
            ? NSSize(width: 180, height: 170)
            : NSSize(width: 150, height: 110)
        let width = min(
            max(minimum.width, start.size.width + translation.width),
            max(minimum.width, visible.width)
        )
        let height = min(
            max(minimum.height, start.size.height + translation.height),
            max(minimum.height, visible.height)
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
        breakActivity = [BreakActivity.adhkar, .quran].randomElement() ?? .adhkar
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
        guard session.strategy != .company, !ctx.bundleID.isEmpty else { return }
        if let host = ctx.host {
            guard let rule = SiteRule.normalize(host).map(SiteRule.init) else { return }
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
        if session.phase != .running {
            session.phase = .running
            session.remaining = 90
        }
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
        if session.phase != .running {
            session.phase = .running
            session.remaining = 90
        }
        brain.resetEscalationForPreview()
        brain.speak(SpeechLines.previewLine(for: move), seconds: 5, prefs: prefs)
        previewTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            stopPreview(spoken: true)
        }
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
        lastLightsKick = .calm
        sounds.stopAll()
        if session.taskTitle.isEmpty {
            session.resetToIdle()
        }
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
            progress.record(
                focused: session.elapsedFocused,
                distracted: session.elapsedDistracted,
                finishedSession: true,
                taskTitle: session.taskTitle,
                durationMinutes: session.durationMinutes,
                strategy: session.strategy
            )
            brain.speak(SpeechLines.doneLine(voice: prefs.voice, name: prefs.userName), seconds: 4, prefs: prefs)
            showBreakChoice()
        }
        if breakState == .running {
            breakRemaining = max(0, breakRemaining - dt)
            if breakRemaining == 0 {
                finishBreak()
            }
        }
        if actionPreview != nil { actionPreviewAge += dt }
        salah.refresh(now: Date(), dt: dt, prefs: prefs)
        if let soon = salah.consumeSoonAnnouncement() {
            brain.speak(SpeechLines.salahSoon(soon.0, at: soon.1), seconds: 5.5, prefs: prefs)
        }
        if let name = salah.consumeNowAnnouncement() {
            brain.speak(SpeechLines.salahNow(name), seconds: 6, prefs: prefs)
        }
        updateTheater()
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
            breakActivity: activeBreakActivity
        )
        if salah.matVisible || previewingSalah {
            brain.activity = .salah
            brain.pose = previewingSalah
                ? [.qiyam, .ruku, .sujud][Int(actionPreviewAge / 2.4) % 3]
                : salah.salahPose
        }
        overlay?.alphaValue = (prefs.alwaysOnDesktop || session.phase != .idle) ? 1 : 0
        updateTimerPanel()
        updateClickThrough()

        if session.phase == .finished {
            // linger so the user sees the done line, then settle
        }
    }

    private func updateTheater() {
        let lightsAllowed = prefs.allows(.lights, previewing: session.previewMove)
        if (session.escalation != .lights || !lightsAllowed), lightShowTask != nil {
            stopLightShow()
        }

        switch session.escalation {
        case .lights:
            theater = lightsAllowed ? .lights : (prefs.allows(.notes, previewing: session.previewMove) ? .notes : .none)
            sounds.stopFire()
            if lastLightsKick != .lights {
                lastLightsKick = .lights
                if lightsAllowed {
                    runLightShow()
                } else if prefs.allows(.notes, previewing: session.previewMove), prefs.allows(.sound, previewing: session.previewMove) {
                    sounds.playNotes()
                }
            }
        case .notes:
            if lastLightsKick != .notes, prefs.allows(.sound, previewing: session.previewMove) {
                sounds.playNotes()
            }
            theater = .notes
            lightsOff = false
            lastLightsKick = .notes
            sounds.stopFire()
        case .fire:
            if prefs.allows(.fire, previewing: session.previewMove) {
                theater = .fire
                if prefs.allows(.sound, previewing: session.previewMove) { sounds.startFire() }
            } else if prefs.allows(.notes, previewing: session.previewMove) {
                theater = .notes
                if lastLightsKick != .fire, prefs.allows(.sound, previewing: session.previewMove) { sounds.playNotes() }
                sounds.stopFire()
            } else {
                theater = .none
                sounds.stopFire()
            }
            lightsOff = false
            lastLightsKick = .fire
        case .nudge, .glance:
            if lastLightsKick == .calm, prefs.allows(.sound, previewing: session.previewMove) {
                sounds.playScold()
            }
            if session.previewTheater == nil {
                theater = prefs.allows(.notes, previewing: session.previewMove) && session.escalation == .nudge ? .notes : .none
                lightsOff = false
            }
            lastLightsKick = session.escalation
            sounds.stopFire()
        default:
            if session.previewTheater == nil {
                theater = .none
                lightsOff = false
                lastLightsKick = session.escalation
            }
            sounds.stopFire()
        }
    }

    private func runLightShow() {
        stopLightShow()
        lightShowTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                // Let the character reach the switch before the room reacts.
                try await Task.sleep(for: .milliseconds(16))
                while self.session.escalation == .lights, self.brain.isMoving {
                    try await Task.sleep(for: .milliseconds(16))
                }
                guard self.session.escalation == .lights, self.brain.pose == .flipSwitch else {
                    self.lightShowTask = nil
                    return
                }
                assert(!self.brain.isMoving, "Light show must wait for the companion to reach the switch")
                try await Task.sleep(for: .milliseconds(180))

                for _ in 0..<4 {
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
        let timerSize = CGSize(width: timerExpanded ? 220 : 160, height: timerExpanded ? 170 : 110)
        let timerPoint = timerCenter ?? CGPoint(x: screen.frame.width - timerSize.width / 2 - 16, y: timerSize.height / 2 + 16)
        let timerRect = CGRect(
            x: timerPoint.x - timerSize.width / 2,
            y: timerPoint.y - timerSize.height / 2,
            width: timerSize.width,
            height: timerSize.height
        )
        let bubbleRect = CGRect(
            x: brain.position.x - 110,
            y: brain.position.y - size.height * 0.5 - 70,
            width: 220,
            height: 64
        )
        let overUI = (showPet && charRect.contains(local))
            || (showPet && brain.bubble != nil && bubbleRect.contains(local))
            || ((session.phase == .running || session.phase == .paused)
                && !prefs.timerOnTop && timerRect.contains(local))
        overlay.ignoresMouseEvents = !overUI
    }

    private func updateTimerPanel() {
        let shouldShow = prefs.showTimerChip
            && prefs.timerOnTop
            && !isEditingSession
            && (session.phase == .running || session.phase == .paused)
        if !shouldShow {
            timerPanel?.orderOut(nil)
            return
        }

        let minimum = timerExpanded
            ? NSSize(width: 180, height: 170)
            : NSSize(width: 150, height: 110)
        timerPanelSize.width = max(timerPanelSize.width, minimum.width)
        timerPanelSize.height = max(timerPanelSize.height, minimum.height)
        let size = timerPanelSize
        let remaining = session.remainingLabel
        let angry = session.escalation >= .nudge && session.phase == .running
        let paused = session.phase == .paused
        let contentChanged = timerPanel == nil
            || remaining != lastTimerRemaining
            || angry != lastTimerAngry
            || session.taskTitle != lastTimerTask
            || paused != lastTimerPaused
            || timerExpanded != lastTimerExpanded

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
            panel.isFloatingPanel = true
            panel.isReleasedWhenClosed = false
            panel.ignoresMouseEvents = false
            panel.title = "Wick Timer"
            let host = NSHostingView(rootView: timerChip(
                size: size,
                onDragChanged: { [weak self] translation in self?.moveTimerPanel(translation) },
                onDragEnded: { [weak self] in self?.finishMovingTimerPanel() },
                onResizeChanged: { [weak self] translation in self?.resizeTimerPanel(translation) },
                onResizeEnded: { [weak self] in self?.finishResizingTimerPanel() }
            ))
            host.frame = NSRect(origin: .zero, size: size)
            panel.contentView = host
            timerHost = host
            timerPanel = panel
        } else if contentChanged {
            timerPanel?.setContentSize(size)
            timerHost?.frame = NSRect(origin: .zero, size: size)
            timerHost?.rootView = timerChip(
                size: size,
                onDragChanged: { [weak self] translation in self?.moveTimerPanel(translation) },
                onDragEnded: { [weak self] in self?.finishMovingTimerPanel() },
                onResizeChanged: { [weak self] translation in self?.resizeTimerPanel(translation) },
                onResizeEnded: { [weak self] in self?.finishResizingTimerPanel() }
            )
        }
        lastTimerRemaining = remaining
        lastTimerAngry = angry
        lastTimerTask = session.taskTitle
        lastTimerPaused = paused
        lastTimerExpanded = timerExpanded
        if !contentChanged {
            if timerPanel?.isVisible == false { timerPanel?.orderFrontRegardless() }
            return
        }
        timerPanel?.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)) - 1)
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
        if timerPanelDragStart == nil && timerPanelResizeStart == nil {
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

    private func makeCardPanel(title: String, size: NSSize) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        // Normal window level (not floating): clicking into another app sends this
        // panel behind it, same as any regular window. A floating panel would stay
        // pinned above everything else on the Mac, including full-screen apps,
        // with no way to click past it short of minimizing.
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.titlebarAppearsTransparent = true
        panel.appearance = NSAppearance(named: .aqua)
        panel.backgroundColor = NSColor(Palette.paper)
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.midX - size.width / 2
            let y = screen.visibleFrame.midY - size.height / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        return panel
    }

    private func present(_ panel: NSPanel?) {
        guard let panel else { return }
        panel.appearance = NSAppearance(named: .aqua)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    private func showBreakChoice() {
        guard breakState == .none else { return }
        breakRemaining = TimeInterval(prefs.breakMinutes * 60)
        breakActivity = nil
        breakState = .choice
        setupPanel?.orderOut(nil)
        presentBreakPanel()
    }

    private func finishBreak() {
        guard breakState == .running else { return }
        breakRemaining = 0
        breakActivity = nil
        breakState = .repeatChoice
        brain.speak(SpeechLines.breakFinishedLine(), seconds: 4, prefs: prefs)
        presentBreakPanel()
    }

    private func showRepeatChoice() {
        breakRemaining = 0
        breakActivity = nil
        breakState = .repeatChoice
        presentBreakPanel()
    }

    private func presentBreakPanel() {
        if breakPanel == nil {
            breakPanel = makeCardPanel(title: "Break", size: NSSize(width: 320, height: 450))
            breakPanel?.contentView = NSHostingView(
                rootView: BreakView().environment(self)
            )
        }
        present(breakPanel)
    }

    private func clearBreakFlow() {
        breakState = .none
        breakRemaining = 0
        breakActivity = nil
        breakPanel?.orderOut(nil)
    }
}
