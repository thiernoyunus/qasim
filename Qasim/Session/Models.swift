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
    /// Set for a "single page" rule: only URLs starting with this path (and query) count.
    var path: String? = nil

    /// Also the display text: "youtube.com" or "youtube.com/watch?v=abc".
    var id: String { host + (path ?? "") }

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

    /// `path` is the page's path + query, when known. A whole-site rule also covers
    /// the brand's other addresses (youtube.com also covers youtu.be).
    func matches(_ host: String, path: String? = nil) -> Bool {
        let h = host.lowercased()
        if let rulePath = self.path {
            // ponytail: prefix match, so "/watch?v=abc" also matches "?v=abcd"; parse query items if that bites.
            return h == self.host && path?.hasPrefix(rulePath) == true
        }
        let hosts = [self.host] + (SiteBrand.forHost(self.host)?.hosts ?? [])
        return hosts.contains { h == $0 || h.hasSuffix("." + $0) }
    }
}

/// Popular sites that live at more than one address. Typing the brand name
/// suggests the site, and a rule for any of its hosts covers all of them.
struct SiteBrand {
    let name: String
    let hosts: [String]

    static let all: [SiteBrand] = [
        SiteBrand(name: "YouTube", hosts: ["youtube.com", "youtu.be"]),
        SiteBrand(name: "X (Twitter)", hosts: ["x.com", "twitter.com"]),
        SiteBrand(name: "Instagram", hosts: ["instagram.com", "instagr.am"]),
        SiteBrand(name: "Facebook", hosts: ["facebook.com", "fb.com", "messenger.com"]),
        SiteBrand(name: "Reddit", hosts: ["reddit.com", "redd.it"]),
        SiteBrand(name: "TikTok", hosts: ["tiktok.com"]),
        SiteBrand(name: "Netflix", hosts: ["netflix.com"]),
        SiteBrand(name: "Twitch", hosts: ["twitch.tv"]),
        SiteBrand(name: "LinkedIn", hosts: ["linkedin.com", "lnkd.in"]),
        SiteBrand(name: "Discord", hosts: ["discord.com", "discord.gg"]),
        SiteBrand(name: "Pinterest", hosts: ["pinterest.com", "pin.it"]),
        SiteBrand(name: "Snapchat", hosts: ["snapchat.com"]),
        SiteBrand(name: "WhatsApp", hosts: ["whatsapp.com", "wa.me"]),
        SiteBrand(name: "Amazon", hosts: ["amazon.com", "amzn.to"]),
        SiteBrand(name: "Hacker News", hosts: ["news.ycombinator.com"]),
        SiteBrand(name: "Gmail", hosts: ["mail.google.com"]),
        SiteBrand(name: "ChatGPT", hosts: ["chatgpt.com", "chat.openai.com"]),
        SiteBrand(name: "Claude", hosts: ["claude.ai"]),
        SiteBrand(name: "Spotify", hosts: ["spotify.com"]),
        SiteBrand(name: "Threads", hosts: ["threads.net", "threads.com"]),
        SiteBrand(name: "Bluesky", hosts: ["bsky.app"]),
    ]

    static func forHost(_ host: String) -> SiteBrand? {
        all.first { $0.hosts.contains(host) }
    }

    /// Brands whose name or address starts with the typed text.
    static func matching(_ query: String) -> [SiteBrand] {
        let q = query.lowercased().replacingOccurrences(of: " ", with: "")
        guard q.count >= 2 else { return [] }
        return all.filter { brand in
            brand.name.lowercased().replacingOccurrences(of: " ", with: "").hasPrefix(q)
                || brand.hosts.contains { $0.hasPrefix(q) }
        }
    }

#if DEBUG
    static func selfCheck() {
        let youtube = SiteRule(host: "youtube.com")
        assert(youtube.matches("youtu.be"))
        assert(youtube.matches("m.youtube.com"))
        assert(!youtube.matches("notyoutube.com"))
        let page = SiteRule(host: "youtube.com", path: "/watch?v=abc")
        assert(page.matches("youtube.com", path: "/watch?v=abc&t=30"))
        assert(!page.matches("youtube.com", path: "/watch?v=xyz"))
        assert(!page.matches("youtube.com"))
        assert(matching("yout").first?.name == "YouTube")
        assert(matching("y").isEmpty)
    }
#endif
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
