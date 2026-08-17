import Foundation

@Observable
@MainActor
final class Preferences {
    var userName: String = ""
    var companion: CompanionID = .qasim
    var voice: VoiceStyle = .dry
    var perch: PerchCorner = .bottomTrailing
    var characterScale: Double = 1.0
    var alwaysOnDesktop = true
    var wanderWhenIdle = true
    var showTimerChip = true
    var timerOnTop = true
    var showWhileFocused = true
    var yellVolume: Double = 0.7
    var speechEnabled = true
    var reducedMotion = false
    var dailyGoalMinutes = 120
    var breakMinutes = 5
    var hasCompletedSetup = false
    var customAngryLine = ""
    var salahReminders = true
    var salahLeadMinutes = 10
    var salahMethod: CalculationMethod = .isna
    var asrSchool: AsrSchool = .standard
    var salahSource: SalahSource = .location
    var salahCityName = "New York"
    var salahLatitude: Double?
    var salahLongitude: Double?
    var salahLocationLabel = ""
    var customSalah: [String: SalahClock] = [:]
    var hiddenUntil: Date = .distantPast
    // Persisted from the previous session so the next onboarding starts pre-populated
    // instead of asking the user to re-add every site/app.
    var lastBlockedApps: [AppIdentity] = []
    var lastAllowedApps: [AppIdentity] = []
    var lastBlockedSites: [SiteRule] = []
    var lastAllowedSites: [SiteRule] = []
    var enabledMoves: Set<AngryMove> = [
        .glance, .talk, .lights, .fire, .sound
    ]

    private let key = "wick.preferences.v1"

    init() {
        load()
    }

    var salahPlace: GeoPlace {
        GeoPlace.cities.first { $0.name == salahCityName } ?? GeoPlace.cities[3]
    }

    var isHiddenNow: Bool { Date() < hiddenUntil }

    func hide(for interval: TimeInterval) {
        hiddenUntil = Date().addingTimeInterval(interval)
        save()
    }

    func unhide() {
        hiddenUntil = .distantPast
        save()
    }

    func allows(_ move: AngryMove) -> Bool {
        enabledMoves.contains(move)
    }

    func allows(_ move: AngryMove, previewing previewMove: AngryMove?) -> Bool {
        enabledMoves.contains(move) || previewMove == move
    }

    func toggle(_ move: AngryMove) {
        if enabledMoves.contains(move) {
            enabledMoves.remove(move)
        } else {
            enabledMoves.insert(move)
        }
        save()
    }

    func save() {
        let box = Box(
            lastBlockedApps: lastBlockedApps,
            lastAllowedApps: lastAllowedApps,
            lastBlockedSites: lastBlockedSites,
            lastAllowedSites: lastAllowedSites,
            userName: userName,
            companion: companion,
            voice: voice,
            perch: perch,
            characterScale: characterScale,
            alwaysOnDesktop: alwaysOnDesktop,
            wanderWhenIdle: wanderWhenIdle,
            showTimerChip: showTimerChip,
            timerOnTop: timerOnTop,
            showWhileFocused: showWhileFocused,
            yellVolume: yellVolume,
            speechEnabled: speechEnabled,
            reducedMotion: reducedMotion,
            dailyGoalMinutes: dailyGoalMinutes,
            breakMinutes: breakMinutes,
            hasCompletedSetup: hasCompletedSetup,
            customAngryLine: customAngryLine,
            salahReminders: salahReminders,
            salahLeadMinutes: salahLeadMinutes,
            salahMethod: salahMethod,
            asrSchool: asrSchool,
            salahSource: salahSource,
            salahCityName: salahCityName,
            salahLatitude: salahLatitude,
            salahLongitude: salahLongitude,
            salahLocationLabel: salahLocationLabel,
            customSalah: customSalah,
            hiddenUntil: hiddenUntil,
            enabledMoves: Array(enabledMoves)
        )
        if let data = try? JSONEncoder().encode(box) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let box = try? JSONDecoder().decode(Box.self, from: data) else { return }
        lastBlockedApps = box.lastBlockedApps ?? []
        lastAllowedApps = box.lastAllowedApps ?? []
        lastBlockedSites = box.lastBlockedSites ?? []
        lastAllowedSites = box.lastAllowedSites ?? []
        userName = box.userName ?? ""
        companion = box.companion
        voice = box.voice
        perch = box.perch
        characterScale = min(1.6, max(0.7, box.characterScale))
        alwaysOnDesktop = box.alwaysOnDesktop
        wanderWhenIdle = box.wanderWhenIdle
        showTimerChip = box.showTimerChip
        timerOnTop = box.timerOnTop ?? true
        showWhileFocused = box.showWhileFocused ?? true
        yellVolume = min(1, max(0, box.yellVolume ?? 0.7))
        speechEnabled = box.speechEnabled
        reducedMotion = box.reducedMotion
        dailyGoalMinutes = box.dailyGoalMinutes
        breakMinutes = box.breakMinutes ?? 5
        hasCompletedSetup = box.hasCompletedSetup ?? false
        customAngryLine = box.customAngryLine
        salahReminders = box.salahReminders ?? true
        salahLeadMinutes = box.salahLeadMinutes ?? 10
        salahMethod = box.salahMethod ?? .isna
        asrSchool = box.asrSchool ?? .standard
        salahSource = box.salahSource ?? .location
        salahCityName = box.salahCityName ?? "New York"
        salahLatitude = box.salahLatitude
        salahLongitude = box.salahLongitude
        salahLocationLabel = box.salahLocationLabel ?? ""
        customSalah = box.customSalah ?? [:]
        hiddenUntil = box.hiddenUntil ?? .distantPast
        if !box.enabledMoves.isEmpty {
            enabledMoves = Set(box.enabledMoves)
        }
    }

    private struct Box: Codable {
        var lastBlockedApps: [AppIdentity]?
        var lastAllowedApps: [AppIdentity]?
        var lastBlockedSites: [SiteRule]?
        var lastAllowedSites: [SiteRule]?
        var userName: String?
        var companion: CompanionID
        var voice: VoiceStyle
        var perch: PerchCorner
        var characterScale: Double
        var alwaysOnDesktop: Bool
        var wanderWhenIdle: Bool
        var showTimerChip: Bool
        var timerOnTop: Bool?
        var showWhileFocused: Bool?
        var yellVolume: Double?
        var speechEnabled: Bool
        var reducedMotion: Bool
        var dailyGoalMinutes: Int
        var breakMinutes: Int?
        var hasCompletedSetup: Bool?
        var customAngryLine: String
        var salahReminders: Bool?
        var salahLeadMinutes: Int?
        var salahMethod: CalculationMethod?
        var asrSchool: AsrSchool?
        var salahSource: SalahSource?
        var salahCityName: String?
        var salahLatitude: Double?
        var salahLongitude: Double?
        var salahLocationLabel: String?
        var customSalah: [String: SalahClock]?
        var hiddenUntil: Date?
        var enabledMoves: [AngryMove]
    }
}
