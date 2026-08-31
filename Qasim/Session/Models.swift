import Foundation

enum FocusStrategy: String, CaseIterable, Identifiable, Codable {
    case allow
    case block
    case company

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allow: "Allowing"
        case .block: "Blocking"
        case .company: "Timer Only"
        }
    }

    var blurb: String {
        switch self {
        case .allow: "Allows only apps and websites you select."
        case .block: "Blocks only apps and websites you select."
        case .company: "Qasim keeps you company while you work."
        }
    }
}

enum SessionPhase: Equatable {
    case idle
    case running
    case paused
    case finished
}

enum BreakState: Equatable {
    case none
    case choice
    case running
    case repeatChoice
}

enum Escalation: Int, Comparable, Equatable {
    case calm = 0
    case glance
    case nudge
    case lights
    case fire
    case notes

    static func < (lhs: Escalation, rhs: Escalation) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum Temper: String, CaseIterable, Identifiable, Codable {
    case gentle
    case normal
    case ruthless

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gentle: "Gentle"
        case .normal: "Normal"
        case .ruthless: "Ruthless"
        }
    }

    /// Seconds of distraction before each escalation step.
    var thresholds: (glance: TimeInterval, nudge: TimeInterval, lights: TimeInterval, fire: TimeInterval) {
        switch self {
        case .gentle: (8, 16, 28, 42)
        case .normal: (1.5, 6, 12, 18)
        case .ruthless: (1, 2.5, 5, 8)
        }
    }
}

struct AppIdentity: Identifiable, Hashable, Codable, Sendable {
    var bundleID: String
    var name: String
    var path: String

    var id: String { bundleID.isEmpty ? path : bundleID }
}

struct SiteRule: Identifiable, Hashable, Codable, Sendable {
    var host: String

    var id: String { host }

    static func normalize(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        let candidate = value.contains("://") ? value : "https://\(value)"
        guard var host = URLComponents(string: candidate)?.host?.lowercased(), !host.isEmpty else { return nil }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        if host.hasSuffix(".") { host.removeLast() }
        return host.isEmpty ? nil : host
    }

#if DEBUG
    static func selfCheck() {
        assert(normalize("https://www.example.com/path?q=1") == "example.com")
        assert(normalize("example.com:443/path") == "example.com")
        assert(normalize("not a website") == nil)
    }
#endif

    func matches(_ host: String) -> Bool {
        let h = host.lowercased()
        return h == self.host || h.hasSuffix("." + self.host)
    }
}

enum QasimIdentity {
    static let bundleID = "computer.qasim.app"

    static let alwaysAllowed: Set<String> = [
        bundleID,
        "com.apple.loginwindow",
        "com.apple.SecurityAgent",
        "com.apple.systempreferences",
        "com.apple.LocalAuthentication.UI",
        "com.apple.UserNotificationCenter",
        "com.apple.notificationcenterui",
        "com.apple.controlcenter",
        "com.apple.Spotlight",
        "com.apple.dock"
    ]
}
