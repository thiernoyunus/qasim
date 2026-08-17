import Foundation

enum PrayerAPI {
    static func fetchByCoordinate(
        day: Date,
        latitude: Double,
        longitude: Double,
        method: CalculationMethod,
        asr: AsrSchool
    ) async throws -> PrayerTimes {
        try await fetch(
            day: day,
            path: "timings",
            query: [
                URLQueryItem(name: "latitude", value: String(latitude)),
                URLQueryItem(name: "longitude", value: String(longitude)),
                URLQueryItem(name: "method", value: String(method.aladhanID)),
                URLQueryItem(name: "school", value: asr == .hanafi ? "1" : "0"),
            ]
        )
    }

    static func fetchByCity(
        day: Date,
        city: String,
        country: String,
        method: CalculationMethod,
        asr: AsrSchool
    ) async throws -> PrayerTimes {
        try await fetch(
            day: day,
            path: "timingsByCity",
            query: [
                URLQueryItem(name: "city", value: city),
                URLQueryItem(name: "country", value: country),
                URLQueryItem(name: "method", value: String(method.aladhanID)),
                URLQueryItem(name: "school", value: asr == .hanafi ? "1" : "0"),
            ]
        )
    }

    private static func fetch(day: Date, path: String, query: [URLQueryItem]) async throws -> PrayerTimes {
        let calendar = Calendar(identifier: .gregorian)
        let y = calendar.component(.year, from: day)
        let m = calendar.component(.month, from: day)
        let d = calendar.component(.day, from: day)
        let stamp = String(format: "%02d-%02d-%04d", d, m, y)

        var parts = URLComponents(string: "https://api.aladhan.com/v1/\(path)/\(stamp)")
        parts?.queryItems = query
        guard let url = parts?.url else { throw URLError(.badURL) }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(Envelope.self, from: data)
        guard decoded.code == 200 else { throw URLError(.cannotParseResponse) }

        var zone = TimeZone.current
        if let name = decoded.data.meta?.timezone, let parsed = TimeZone(identifier: name) {
            zone = parsed
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone

        let keys: [(PrayerName, String)] = [
            (.fajr, "Fajr"),
            (.sunrise, "Sunrise"),
            (.dhuhr, "Dhuhr"),
            (.asr, "Asr"),
            (.maghrib, "Maghrib"),
            (.isha, "Isha"),
        ]
        var times: [PrayerName: Date] = [:]
        for (name, key) in keys {
            if let raw = decoded.data.timings[key], let date = clock(raw, on: day, calendar: cal) {
                times[name] = date
            }
        }
        return PrayerTimes(date: day, times: times)
    }

    static func offline(
        day: Date,
        latitude: Double,
        longitude: Double,
        method: CalculationMethod,
        asr: AsrSchool,
        label: String
    ) -> PrayerTimes {
        let place = GeoPlace(
            name: label.isEmpty ? "Here" : label,
            country: "",
            latitude: latitude,
            longitude: longitude,
            timeZoneIdentifier: TimeZone.current.identifier
        )
        return PrayerClock.compute(on: day, place: place, method: method, asr: asr)
    }

    private static func clock(_ raw: String, on day: Date, calendar: Calendar) -> Date? {
        let token = raw.split(whereSeparator: { $0 == " " || $0 == "(" }).first.map(String.init) ?? raw
        let bits = token.split(separator: ":")
        guard bits.count >= 2, let hour = Int(bits[0]), let minute = Int(bits[1]) else { return nil }
        var parts = calendar.dateComponents([.year, .month, .day], from: day)
        parts.hour = hour
        parts.minute = minute
        parts.second = 0
        return calendar.date(from: parts)
    }

    private struct Envelope: Decodable {
        var code: Int
        var data: Payload
    }

    private struct Payload: Decodable {
        var timings: [String: String]
        var meta: Meta?
    }

    private struct Meta: Decodable {
        var timezone: String?
    }
}
