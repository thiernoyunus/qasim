import Foundation

// MARK: - Prayer names

enum PrayerName: String, CaseIterable, Identifiable {
    case fajr
    case sunrise
    case dhuhr
    case asr
    case maghrib
    case isha

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fajr: "Fajr"
        case .sunrise: "Sunrise"
        case .dhuhr: "Dhuhr"
        case .asr: "Asr"
        case .maghrib: "Maghrib"
        case .isha: "Isha"
        }
    }

    var isSalah: Bool { self != .sunrise }
}

extension PrayerName: Comparable {
    static func < (lhs: PrayerName, rhs: PrayerName) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

// MARK: - Calculation rules

enum CalculationMethod: String, CaseIterable, Identifiable, Codable {
    case mwl
    case isna
    case egypt
    case makkah
    case karachi

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mwl: "Muslim World League"
        case .isna: "ISNA"
        case .egypt: "Egyptian General Authority"
        case .makkah: "Umm al-Qura (Makkah)"
        case .karachi: "Univ. of Islamic Sciences, Karachi"
        }
    }

    /// Aladhan API method number.
    var aladhanID: Int {
        switch self {
        case .karachi: 1
        case .isna: 2
        case .mwl: 3
        case .makkah: 4
        case .egypt: 5
        }
    }

    /// How far below the horizon the Sun must be for Fajr to begin.
    var fajrAngle: Double {
        switch self {
        case .mwl: 18
        case .isna: 15
        case .egypt: 19.5
        case .makkah: 18.5
        case .karachi: 18
        }
    }

    /// How far below the horizon the Sun must be for Isha to begin (angle-based methods).
    var ishaAngle: Double? {
        switch self {
        case .mwl: 17
        case .isna: 15
        case .egypt: 17.5
        case .makkah: nil
        case .karachi: 18
        }
    }

    /// Minutes after Maghrib for Isha, for methods that use a fixed interval instead of an angle.
    var ishaInterval: Double? {
        switch self {
        case .makkah: 90
        default: nil
        }
    }
}

enum AsrSchool: String, CaseIterable, Identifiable, Codable {
    case standard
    case hanafi

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "Standard"
        case .hanafi: "Hanafi"
        }
    }

    /// Object shadow length at which Asr begins (1 for standard, 2 for Hanafi).
    var shadowFactor: Double {
        switch self {
        case .standard: 1
        case .hanafi: 2
        }
    }
}

// MARK: - Location

struct GeoPlace: Identifiable, Hashable, Codable, Sendable {
    var name: String
    var country: String
    var latitude: Double
    var longitude: Double
    var timeZoneIdentifier: String

    var id: String { name }
}

enum SalahSource: String, CaseIterable, Identifiable, Codable {
    case location
    case city
    case masjid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .location: "My location"
        case .city: "A city"
        case .masjid: "Masjid times"
        }
    }
}

struct SalahClock: Codable, Equatable, Hashable {
    var hour: Int
    var minute: Int

    static func placeholder(for name: PrayerName) -> SalahClock {
        switch name {
        case .fajr: SalahClock(hour: 5, minute: 30)
        case .sunrise: SalahClock(hour: 6, minute: 45)
        case .dhuhr: SalahClock(hour: 13, minute: 15)
        case .asr: SalahClock(hour: 16, minute: 45)
        case .maghrib: SalahClock(hour: 19, minute: 30)
        case .isha: SalahClock(hour: 21, minute: 0)
        }
    }

    static func from(_ date: Date, calendar: Calendar = .current) -> SalahClock {
        let bits = calendar.dateComponents([.hour, .minute], from: date)
        return SalahClock(hour: bits.hour ?? 0, minute: bits.minute ?? 0)
    }

    func date(on day: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: calendar.startOfDay(for: day)
        )
    }
}

extension GeoPlace {
    /// Well-known cities with reasonable coordinates and IANA time zone identifiers.
    static let cities: [GeoPlace] = [
        GeoPlace(name: "Mecca", country: "Saudi Arabia", latitude: 21.4225, longitude: 39.8262, timeZoneIdentifier: "Asia/Riyadh"),
        GeoPlace(name: "Medina", country: "Saudi Arabia", latitude: 24.5247, longitude: 39.5692, timeZoneIdentifier: "Asia/Riyadh"),
        GeoPlace(name: "London", country: "United Kingdom", latitude: 51.5074, longitude: -0.1278, timeZoneIdentifier: "Europe/London"),
        GeoPlace(name: "New York", country: "United States", latitude: 40.7128, longitude: -74.0060, timeZoneIdentifier: "America/New_York"),
        GeoPlace(name: "Toronto", country: "Canada", latitude: 43.6532, longitude: -79.3832, timeZoneIdentifier: "America/Toronto"),
        GeoPlace(name: "Chicago", country: "United States", latitude: 41.8781, longitude: -87.6298, timeZoneIdentifier: "America/Chicago"),
        GeoPlace(name: "Houston", country: "United States", latitude: 29.7604, longitude: -95.3698, timeZoneIdentifier: "America/Chicago"),
        GeoPlace(name: "Los Angeles", country: "United States", latitude: 34.0522, longitude: -118.2437, timeZoneIdentifier: "America/Los_Angeles"),
        GeoPlace(name: "Dubai", country: "United Arab Emirates", latitude: 25.2048, longitude: 55.2708, timeZoneIdentifier: "Asia/Dubai"),
        GeoPlace(name: "Istanbul", country: "Turkey", latitude: 41.0082, longitude: 28.9784, timeZoneIdentifier: "Europe/Istanbul"),
        GeoPlace(name: "Cairo", country: "Egypt", latitude: 30.0444, longitude: 31.2357, timeZoneIdentifier: "Africa/Cairo"),
        GeoPlace(name: "Jakarta", country: "Indonesia", latitude: -6.2088, longitude: 106.8456, timeZoneIdentifier: "Asia/Jakarta"),
        GeoPlace(name: "Kuala Lumpur", country: "Malaysia", latitude: 3.1390, longitude: 101.6869, timeZoneIdentifier: "Asia/Kuala_Lumpur"),
        GeoPlace(name: "Lagos", country: "Nigeria", latitude: 6.5244, longitude: 3.3792, timeZoneIdentifier: "Africa/Lagos"),
        GeoPlace(name: "Paris", country: "France", latitude: 48.8566, longitude: 2.3522, timeZoneIdentifier: "Europe/Paris"),
    ]

    static func city(named name: String) -> GeoPlace? {
        cities.first { $0.name == name }
    }
}

// MARK: - Results

struct PrayerOccurrence: Identifiable {
    var name: PrayerName
    var date: Date
    var id: String { name.rawValue }
}

struct PrayerTimes: Sendable {
    var date: Date
    var times: [PrayerName: Date]

    /// The five salahs in chronological order (sunrise is not a salah).
    static let salahOrder: [PrayerName] = [.fajr, .dhuhr, .asr, .maghrib, .isha]

    var salah: [PrayerName] { Self.salahOrder }

    var orderedTimes: [(prayer: PrayerName, date: Date)] {
        PrayerName.allCases.compactMap { name in
            times[name].map { (name, $0) }
        }
    }

    func date(for prayer: PrayerName) -> Date? {
        times[prayer]
    }

    /// The next entry (sunrise included) strictly after `date`, or nil when the day is over.
    func next(after date: Date) -> PrayerName? {
        orderedTimes.filter { $0.date > date }.min { $0.date < $1.date }?.prayer
    }

    /// The next salah (sunrise skipped) strictly after `date`, or nil when the day is over.
    func nextSalah(after date: Date) -> PrayerOccurrence? {
        guard let entry = nextSalahEntry(after: date) else { return nil }
        return PrayerOccurrence(name: entry.prayer, date: entry.date)
    }

    func activeSalah(at now: Date) -> PrayerOccurrence? {
        let items = salah.compactMap { name -> PrayerOccurrence? in
            times[name].map { PrayerOccurrence(name: name, date: $0) }
        }.sorted { $0.date < $1.date }
        for (i, item) in items.enumerated() {
            let end = i + 1 < items.count ? items[i + 1].date : item.date.addingTimeInterval(30 * 60)
            if now >= item.date && now < end { return item }
        }
        return nil
    }

    /// The next salah from now, or nil when today's schedule has ended.
    var upcomingSalah: (prayer: PrayerName, date: Date)? {
        nextSalahEntry(after: Date())
    }

    /// Whole minutes until `prayer` counting from `date` (defaults to now). nil when it already passed.
    func minutesUntil(_ prayer: PrayerName, from date: Date = Date()) -> Int? {
        guard let target = times[prayer], target > date else { return nil }
        return Int(ceil(target.timeIntervalSince(date) / 60.0))
    }

    /// Short clock string for one prayer, rendered in the given time zone.
    func formatted(_ prayer: PrayerName, in timeZone: TimeZone) -> String {
        guard let target = times[prayer] else { return "—" }
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: target)
    }

    func applying(clocks: [String: SalahClock], on day: Date, calendar: Calendar = .current) -> PrayerTimes {
        var next = times
        for name in Self.salahOrder {
            if let clock = clocks[name.rawValue], let date = clock.date(on: day, calendar: calendar) {
                next[name] = date
            }
        }
        return PrayerTimes(date: day, times: next)
    }

    static func fromMasjid(clocks: [String: SalahClock], on day: Date, calendar: Calendar = .current) -> PrayerTimes {
        var times: [PrayerName: Date] = [:]
        for name in salahOrder {
            let clock = clocks[name.rawValue] ?? SalahClock.placeholder(for: name)
            times[name] = clock.date(on: day, calendar: calendar)
        }
        return PrayerTimes(date: day, times: times)
    }

    private func nextSalahEntry(after date: Date) -> (prayer: PrayerName, date: Date)? {
        salah.compactMap { name -> (prayer: PrayerName, date: Date)? in
            guard let target = times[name], target > date else { return nil }
            return (name, target)
        }.min { $0.date < $1.date }
    }
}

// MARK: - Calculator

struct PrayerClock {
    /// Prayer times for one day at a place, computed offline from the Sun's position.
    static func compute(on date: Date, place: GeoPlace, method: CalculationMethod = .mwl, asr: AsrSchool = .standard) -> PrayerTimes {
        let timeZone = TimeZone(identifier: place.timeZoneIdentifier) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let julian = SolarMath.julianDate(year: year, month: month, day: day)

        let dayStart = calendar.startOfDay(for: date)
        // Sample the zone offset at noon so DST transition days stay consistent.
        let tzHours = Double(timeZone.secondsFromGMT(for: dayStart.addingTimeInterval(12 * 3600))) / 3600.0

        let hours = computeHours(
            julianDate: julian,
            latitude: place.latitude,
            longitude: place.longitude,
            tzHours: tzHours,
            method: method,
            asr: asr
        )

        var times: [PrayerName: Date] = [:]
        for name in PrayerName.allCases {
            if let hour = hours[name] {
                times[name] = dayStart.addingTimeInterval(hour * 3600.0)
            }
        }
        return PrayerTimes(date: date, times: times)
    }

    /// Raw times in local wall-clock hours since midnight. Never returns NaN.
    private static func computeHours(
        julianDate: Double,
        latitude: Double,
        longitude: Double,
        tzHours: Double,
        method: CalculationMethod,
        asr: AsrSchool
    ) -> [PrayerName: Double] {
        // Shift the julian date by longitude so the day fraction tracks local solar time.
        let jDate = julianDate - longitude / 360.0

        func sunPosition(at hour: Double) -> (declination: Double, equation: Double) {
            SolarMath.sunPosition(jd: jDate + hour / 24.0)
        }

        func localNoon(at hour: Double) -> Double {
            SolarMath.fixHour(12 - sunPosition(at: hour).equation)
        }

        func angleTime(_ angle: Double, at hour: Double, rising: Bool) -> Double {
            let declination = sunPosition(at: hour).declination
            let noon = localNoon(at: hour)
            let numerator = -sin(SolarMath.deg2rad(angle))
                - sin(SolarMath.deg2rad(declination)) * sin(SolarMath.deg2rad(latitude))
            let denominator = cos(SolarMath.deg2rad(declination)) * cos(SolarMath.deg2rad(latitude))
            let argument = denominator == 0 ? 2 : numerator / denominator
            guard (-1...1).contains(argument) else { return .nan }
            let offset = SolarMath.rad2deg(acos(argument)) / 15.0
            return rising ? noon - offset : noon + offset
        }

        func asrHour(factor: Double, at hour: Double) -> Double {
            let declination = sunPosition(at: hour).declination
            let altitude = -SolarMath.rad2deg(
                atan(1.0 / (factor + tan(SolarMath.deg2rad(abs(latitude - declination)))))
            )
            return angleTime(altitude, at: hour, rising: false)
        }

        let noon = localNoon(at: 5)

        let fajrAngle = method.fajrAngle
        var fajr = angleTime(fajrAngle, at: noon, rising: true)
        var sunrise = angleTime(0.833, at: noon, rising: true)
        let dhuhr = noon
        var asrTime = asrHour(factor: asr.shadowFactor, at: noon)
        var sunset = angleTime(0.833, at: noon, rising: false)
        let sunsetSolar = sunset
        var isha: Double
        if let angle = method.ishaAngle {
            isha = angleTime(angle, at: noon, rising: false)
        } else if let interval = method.ishaInterval {
            isha = sunsetSolar + interval / 60.0
        } else {
            isha = angleTime(17, at: noon, rising: false)
        }

        // Convert solar hours into the place's wall-clock hours.
        let adjustment = tzHours - longitude / 15.0
        fajr += adjustment
        sunrise += adjustment
        let dhuhrLocal = dhuhr + adjustment
        asrTime += adjustment
        sunset += adjustment
        isha += adjustment

        // High-latitude safety net: when the Sun barely rises or an angle can't be
        // solved, place Fajr and Isha by their angle as a fraction of the night.
        if !sunrise.isFinite { sunrise = 6 + adjustment }
        if !sunset.isFinite { sunset = 18 + adjustment }
        let maghrib = sunset
        let nightLength = (sunset.isFinite && sunrise.isFinite && sunset > sunrise)
            ? SolarMath.fixHour(sunrise - sunset)
            : 12.0

        let needsFallback = !fajr.isFinite || !isha.isFinite || !asrTime.isFinite
            || isha < maghrib || fajr > sunrise

        if needsFallback {
            if !fajr.isFinite || fajr > sunrise {
                fajr = sunrise - (fajrAngle / 60.0) * nightLength
            }
            if !isha.isFinite || isha < maghrib {
                if let angle = method.ishaAngle {
                    isha = maghrib + (angle / 60.0) * nightLength
                } else if let interval = method.ishaInterval {
                    isha = maghrib + interval / 60.0
                } else {
                    isha = maghrib + (17.0 / 60.0) * nightLength
                }
            }
            if !asrTime.isFinite {
                asrTime = dhuhrLocal + (maghrib - dhuhrLocal) * 0.5
            } else if asrTime >= maghrib {
                asrTime = maghrib - 0.5
            } else if asrTime <= dhuhrLocal {
                asrTime = dhuhrLocal + 0.5
            }
        }

        return [
            .fajr: fajr,
            .sunrise: sunrise,
            .dhuhr: dhuhrLocal,
            .asr: asrTime,
            .maghrib: maghrib,
            .isha: isha,
        ]
    }
}

// MARK: - Solar math

private enum SolarMath {
    /// Julian date at 00:00 of the given (proleptic Gregorian) date.
    static func julianDate(year: Int, month: Int, day: Int) -> Double {
        var y = year
        var m = month
        if m <= 2 {
            y -= 1
            m += 12
        }
        let a = floor(Double(y) / 100.0)
        let b = 2 - a + floor(a / 4.0)
        return floor(365.25 * Double(y + 4716))
            + floor(30.6001 * Double(m + 1)) + Double(day) + b - 1524.5
    }

    /// Solar declination (degrees) and equation of time (hours) for a julian date.
    static func sunPosition(jd: Double) -> (declination: Double, equation: Double) {
        let days = jd - 2451545.0
        let meanAnomaly = fixAngle(357.529 + 0.98560028 * days)
        let meanLongitude = fixAngle(280.459 + 0.98564736 * days)
        let eclipticLongitude = fixAngle(
            meanLongitude + 1.915 * sin(deg2rad(meanAnomaly)) + 0.020 * sin(deg2rad(2 * meanAnomaly))
        )
        let obliquity = 23.439 - 0.00000036 * days
        let rightAscension = rad2deg(
            atan2(cos(deg2rad(obliquity)) * sin(deg2rad(eclipticLongitude)), cos(deg2rad(eclipticLongitude)))
        ) / 15.0
        let equation = meanLongitude / 15.0 - fixHour(rightAscension)
        let declination = rad2deg(asin(sin(deg2rad(obliquity)) * sin(deg2rad(eclipticLongitude))))
        return (declination, equation)
    }

    static func fixAngle(_ degrees: Double) -> Double {
        degrees - 360.0 * floor(degrees / 360.0)
    }

    static func fixHour(_ hours: Double) -> Double {
        hours - 24.0 * floor(hours / 24.0)
    }

    static func deg2rad(_ degrees: Double) -> Double { degrees * .pi / 180.0 }
    static func rad2deg(_ radians: Double) -> Double { radians * 180.0 / .pi }
}
