import Foundation

enum SalahPhase: Equatable {
    case none
    case soon(PrayerName, date: Date)
    case now(PrayerName)
}

@Observable
@MainActor
final class SalahWatch {
    var today: PrayerTimes?
    var tomorrow: PrayerTimes?
    var phase: SalahPhase = .none
    var matVisible = false
    var salahPose: WickPose = .qiyam
    var locationLabel = ""
    var status = ""
    var fetching = false

    let locator = LocationFix()

    private var warned: Set<String> = []
    private var started: Set<String> = []
    private var announcedNow: Set<String> = []
    private var poseTick: TimeInterval = 0
    private var lastFetchKey = ""
    private var lastNotifyKey = ""
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
    }

    func refresh(now: Date, dt: TimeInterval = 1 / 60, prefs: Preferences) {
        guard prefs.salahReminders else {
            phase = .none
            matVisible = false
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
        Task { await loadIfNeeded(now: now, prefs: prefs, force: false) }

        guard let today else { return }

        if let current = today.activeSalah(at: now),
           now.timeIntervalSince(current.date) < 4 * 60 {
            let key = stamp(current.name, current.date)
            if !started.contains(key) {
                started.insert(key)
                poseTick = 0
            }
            phase = .now(current.name)
            matVisible = true
            poseTick += dt
            let step = Int(poseTick / 2.4) % 3
            salahPose = [.qiyam, .ruku, .sujud][step]
            return
        }

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
                do {
                    let fetched = try await PrayerAPI.fetchByCoordinate(
                        day: day,
                        latitude: lat,
                        longitude: lon,
                        method: prefs.salahMethod,
                        asr: prefs.asrSchool
                    )
                    locationLabel = prefs.salahLocationLabel.isEmpty ? "Here" : prefs.salahLocationLabel
                    return fetched.applying(clocks: prefs.customSalah, on: day)
                } catch {
                    return PrayerAPI.offline(
                        day: day,
                        latitude: lat,
                        longitude: lon,
                        method: prefs.salahMethod,
                        asr: prefs.asrSchool,
                        label: prefs.salahLocationLabel
                    ).applying(clocks: prefs.customSalah, on: day)
                }
            }
            return await cityTimes(day: day, prefs: prefs)
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
