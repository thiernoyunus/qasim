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
        case .company: "Wick keeps you company while you work."
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
        case .normal: (2.5, 6, 12, 18)
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
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.isEmpty { return nil }
        value = value.replacingOccurrences(of: "https://", with: "")
        value = value.replacingOccurrences(of: "http://", with: "")
        if let slash = value.firstIndex(of: "/") {
            value = String(value[..<slash])
        }
        if value.hasPrefix("www.") {
            value.removeFirst(4)
        }
        return value.isEmpty ? nil : value
    }

    func matches(_ host: String) -> Bool {
        let h = host.lowercased()
        return h == self.host || h.hasSuffix("." + self.host)
    }
}

enum WickIdentity {
    static let bundleID = "computer.wick.app"

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
