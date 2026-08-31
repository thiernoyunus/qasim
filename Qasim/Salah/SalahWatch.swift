import Foundation

enum SalahPhase: Equatable {
    case none
    case soon(PrayerName, date: Date)
    case now(PrayerName)
}

/// A prayer nudge that stays on screen until the user answers it.
struct SalahAsk: Equatable {
    var name: PrayerName
    var due: Date
    /// How many times the user has asked for one more minute.
    var snoozes: Int = 0

    var isFinal: Bool { snoozes >= 2 }

    /// After the first borrowed minute runs out he stops asking from the corner
    /// and comes to stand in the middle of the screen.
    var isStanding: Bool { snoozes >= 1 }

#if DEBUG
    /// The nudge ladder: ask from the corner, then stand in the way, then drop
    /// the snooze button. Fails loudly if the rungs ever overlap wrongly.
    static func selfCheck() {
        let due = Date()
        let first = SalahAsk(name: .maghrib, due: due, snoozes: 0)
        assert(!first.isStanding && !first.isFinal, "first ask stays in the corner and can be snoozed")
        let second = SalahAsk(name: .maghrib, due: due, snoozes: 1)
        assert(second.isStanding && !second.isFinal, "after one minute he stands, but you may still borrow one")
        let third = SalahAsk(name: .maghrib, due: due, snoozes: 2)
        assert(third.isStanding && third.isFinal, "third time there is no snooze left")
    }
#endif
}

@Observable
@MainActor
final class SalahWatch {
    var today: PrayerTimes?
    var tomorrow: PrayerTimes?
    var phase: SalahPhase = .none
    var matVisible = false
    var salahPose: QasimPose = .qiyam
    /// The prayer being prayed right now, and when it started. Used for the raka'
    /// count and so the rest of the app knows not to scold mid-prayer.
    var prayingNow: PrayerName?
    var locationLabel = ""
    var status = ""
    var fetching = false

    let locator = LocationFix()

    private var warned: Set<String> = []
    private var started: Set<String> = []
    private var announcedNow: Set<String> = []
    private var acknowledged: Set<String> = []
    private var pendingAsk: SalahAsk?
    private var snoozeUntil: [String: Date] = [:]
    private var snoozeCount: [String: Int] = [:]
    private var lastFetchKey = ""
    private var lastNotifyKey = ""
    private var lastLoadRequestAt = Date.distantPast
    private let loadRequestInterval: TimeInterval = 30
    private var booted = false

    func start(prefs: Preferences) {
        locationLabel = prefs.salahLocationLabel
        locator.onChange = { [weak self] in
            self?.ingestLocation(prefs: prefs)
        }
        if prefs.salahReminders {
            SalahNotifier.ask()
        }
        if prefs.salahSource == .location {
            locator.request()
        }
        booted = true
        lastLoadRequestAt = Date()
        Task { await loadIfNeeded(now: Date(), prefs: prefs, force: true) }
    }

    func useMyLocation(prefs: Preferences) {
        prefs.salahSource = .location
        prefs.save()
        status = "Finding you…"
        locator.request()
        invalidate()
    }

    func invalidate() {
        lastFetchKey = ""
        lastNotifyKey = ""
        lastLoadRequestAt = .distantPast
    }

    func refresh(now: Date, dt: TimeInterval = 1 / 60, prefs: Preferences) {
        guard prefs.salahReminders else {
            phase = .none
            matVisible = false
            prayingNow = nil
            pendingAsk = nil
            if lastNotifyKey != "off" {
                lastNotifyKey = "off"
                Task { await SalahNotifier.refresh(times: [], leadMinutes: prefs.salahLeadMinutes, enabled: false) }
            }
            return
        }

        if !booted {
            start(prefs: prefs)
        }
        if lastNotifyKey == "off" {
            lastFetchKey = ""
        }

        if prefs.salahSource == .location {
            ingestLocation(prefs: prefs)
        }
        if now.timeIntervalSince(lastLoadRequestAt) >= loadRequestInterval {
            lastLoadRequestAt = now
            Task { await loadIfNeeded(now: now, prefs: prefs, force: false) }
        }

        guard let today else { return }

        // The companion prays for as long as that prayer actually takes — 2 raka'
        // for Fajr, 4 for Dhuhr — instead of a flat four minutes for every prayer.
        if let current = today.activeSalah(at: now) {
            let key = stamp(current.name, current.date)
            let elapsed = now.timeIntervalSince(current.date)
            if elapsed >= 0, elapsed < current.name.prayerSeconds {
                started.insert(key)
                phase = .now(current.name)
                matVisible = true
                prayingNow = current.name
                salahPose = current.name.pose(elapsed: elapsed)
                return
            }
        }

        prayingNow = nil

        if let next = nextOccurrence(after: now) {
            let remaining = next.date.timeIntervalSince(now)
            if remaining > 0, remaining <= TimeInterval(prefs.salahLeadMinutes * 60) {
                phase = .soon(next.name, date: next.date)
            } else {
                phase = .none
            }
        } else {
            phase = .none
        }
        matVisible = false
    }

    func consumeSoonAnnouncement() -> (PrayerName, Date)? {
        if case let .soon(name, date) = phase {
            let key = "soon." + stamp(name, date)
            if !warned.contains(key) {
                warned.insert(key)
                return (name, date)
            }
        }
        return nil
    }

    // MARK: - The nudge that waits for an answer

    /// The prayer nudge currently waiting on the user, if any.
    var ask: SalahAsk? { pendingAsk }

    /// Raises the nudge once per prayer, then re-raises it after each snooze runs out.
    func refreshAsk(now: Date, prefs: Preferences) {
        guard prefs.salahReminders, prefs.salahAsk else {
            pendingAsk = nil
            return
        }
        // An open nudge stays open until answered.
        if pendingAsk != nil { return }

        guard case let .soon(name, due) = phase else { return }
        let key = askKey(name, due)
        guard !acknowledged.contains(key) else { return }
        // Snoozes re-arm through snoozeUntil; a fresh prayer starts at zero.
        if let until = snoozeUntil[key], now < until { return }
        pendingAsk = SalahAsk(name: name, due: due, snoozes: snoozeCount[key] ?? 0)
    }

    /// "I'm getting up." Clears the nudge for the rest of this prayer window.
    func acknowledgeAsk() {
        guard let ask = pendingAsk else { return }
        acknowledged.insert(askKey(ask.name, ask.due))
        pendingAsk = nil
    }

    /// "Give me one more minute." Comes back when the minute is up.
    func snoozeAsk(now: Date = Date(), minutes: Int = 1) {
        guard let ask = pendingAsk else { return }
        let key = askKey(ask.name, ask.due)
        snoozeCount[key] = ask.snoozes + 1
        snoozeUntil[key] = now.addingTimeInterval(TimeInterval(minutes * 60))
        pendingAsk = nil
    }

    private func askKey(_ name: PrayerName, _ due: Date) -> String {
        "ask." + stamp(name, due)
    }

    func consumeNowAnnouncement() -> PrayerName? {
        if case let .now(name) = phase {
            let key = "now." + name.rawValue + ".\(Calendar.current.component(.day, from: Date()))"
            if !announcedNow.contains(key) {
                announcedNow.insert(key)
                return name
            }
        }
        return nil
    }

    func nextOccurrence(after now: Date) -> PrayerOccurrence? {
        let pool = [today, tomorrow].compactMap { $0 }
        var best: PrayerOccurrence?
        for day in pool {
            if let hit = day.nextSalah(after: now) {
                if best == nil || hit.date < best!.date {
                    best = hit
                }
            }
        }
        return best
    }

    private func ingestLocation(prefs: Preferences) {
        guard prefs.salahSource == .location else { return }
        if !locator.placeName.isEmpty {
            locationLabel = locator.placeName
            if prefs.salahLocationLabel != locator.placeName {
                prefs.salahLocationLabel = locator.placeName
                prefs.save()
            }
        }
        if locator.denied {
            status = "Location is off. Pick a city or type your masjid times."
        } else if !locator.status.isEmpty {
            status = locator.status
        }
        if let coord = locator.coordinate {
            let lat = (coord.latitude * 1000).rounded() / 1000
            let lon = (coord.longitude * 1000).rounded() / 1000
            if prefs.salahLatitude != lat || prefs.salahLongitude != lon {
                prefs.salahLatitude = lat
                prefs.salahLongitude = lon
                prefs.save()
                lastLoadRequestAt = Date()
                Task { await loadIfNeeded(now: Date(), prefs: prefs, force: true) }
            }
        }
    }

    private func loadIfNeeded(now: Date, prefs: Preferences, force: Bool) async {
        let key = fetchKey(now: now, prefs: prefs)
        if !force, key == lastFetchKey { return }
        if fetching { return }
        fetching = true
        defer { fetching = false }

        let todayTimes = await resolve(day: now, prefs: prefs)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86_400)
        let tomorrowTimes = await resolve(day: nextDay, prefs: prefs)

        today = todayTimes
        tomorrow = tomorrowTimes
        lastFetchKey = key

        let notifyKey = "\(key).\(prefs.salahLeadMinutes).\(prefs.salahReminders)"
        if notifyKey != lastNotifyKey {
            lastNotifyKey = notifyKey
            await SalahNotifier.refresh(
                times: [todayTimes, tomorrowTimes],
                leadMinutes: prefs.salahLeadMinutes,
                enabled: prefs.salahReminders
            )
        }
    }

    private func resolve(day: Date, prefs: Preferences) async -> PrayerTimes {
        switch prefs.salahSource {
        case .masjid:
            status = "Using the times you typed."
            locationLabel = "Masjid"
            return PrayerTimes.fromMasjid(clocks: prefs.customSalah, on: day)
        case .city:
            return await cityTimes(day: day, prefs: prefs)
        case .location:
            if let lat = prefs.salahLatitude, let lon = prefs.salahLongitude {
                locationLabel = prefs.salahLocationLabel.isEmpty ? "Here" : prefs.salahLocationLabel
                status = "Prayer times calculated on this Mac."
                return PrayerAPI.offline(
                    day: day,
                    latitude: lat,
                    longitude: lon,
                    method: prefs.salahMethod,
                    asr: prefs.asrSchool,
                    label: prefs.salahLocationLabel
                ).applying(clocks: prefs.customSalah, on: day)
            }
            let place = prefs.salahPlace
            locationLabel = place.name
            status = "Waiting for your location. Using local times for \(place.name)."
            return PrayerAPI.offline(
                day: day,
                latitude: place.latitude,
                longitude: place.longitude,
                method: prefs.salahMethod,
                asr: prefs.asrSchool,
                label: place.name
            ).applying(clocks: prefs.customSalah, on: day)
        }
    }

    private func cityTimes(day: Date, prefs: Preferences) async -> PrayerTimes {
        let place = prefs.salahPlace
        locationLabel = place.name
        if prefs.salahSource == .city {
            status = "Times for \(place.name). Your exact spot stays on this Mac."
        }
        do {
            let fetched = try await PrayerAPI.fetchByCity(
                day: day,
                city: place.name,
                country: place.country,
                method: prefs.salahMethod,
                asr: prefs.asrSchool
            )
            return fetched.applying(clocks: prefs.customSalah, on: day)
        } catch {
            return PrayerAPI.offline(
                day: day,
                latitude: place.latitude,
                longitude: place.longitude,
                method: prefs.salahMethod,
                asr: prefs.asrSchool,
                label: place.name
            ).applying(clocks: prefs.customSalah, on: day)
        }
    }

    private func fetchKey(now: Date, prefs: Preferences) -> String {
        let day = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: now))
        let customs = prefs.customSalah
            .map { "\($0.key):\($0.value.hour):\($0.value.minute)" }
            .sorted()
            .joined(separator: ",")
        let pin: String
        if prefs.salahSource == .location, let lat = prefs.salahLatitude, let lon = prefs.salahLongitude {
            pin = "gps.\(lat).\(lon)"
        } else {
            pin = "city.\(prefs.salahCityName)"
        }
        return "\(day).\(prefs.salahSource.rawValue).\(pin).\(prefs.salahMethod.rawValue).\(prefs.asrSchool.rawValue).\(customs)"
    }

    private func stamp(_ name: PrayerName, _ date: Date) -> String {
        "\(name.rawValue).\(Int(date.timeIntervalSince1970))"
    }
}
