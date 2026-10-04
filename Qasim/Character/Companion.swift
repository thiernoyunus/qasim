import Foundation

enum CompanionID: String, CaseIterable, Identifiable, Codable {
    case qasim
    case hana
    case nur
    case ahmed
    case safa

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = CompanionID(rawValue: raw) ?? .qasim
    }

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .qasim: "Qasim"
        case .hana: "Hana"
        case .nur: "Nur"
        case .ahmed: "Ahmed"
        case .safa: "Safa"
        }
    }

    /// Short label shown under the name in the pickers.
    var personality: String {
        switch self {
        case .qasim: "Hype man"
        case .hana: "Dramatic big sister"
        case .nur: "Silent judge"
        case .ahmed: "Nonchalant"
        case .safa: "Sweet but savage"
        }
    }

    var blurb: String {
        switch self {
        case .qasim: "Thinks you're a legend, and takes it personally when you act otherwise."
        case .hana: "Every distraction is a personal betrayal. She will tell your mum."
        case .nur: "Barely says a word. Doesn't need to."
        case .ahmed: "Unbothered and deadpan. Roasts you without even trying."
        case .safa: "Polite, warm, and somehow every compliment stings."
        }
    }

    var groupTitle: String {
        "In thobe, hijab, niqab"
    }

    var isPixelCompanion: Bool { true }

    var remembersSalah: Bool { isPixelCompanion }

    func assetName(for pose: QasimPose, lightsOff: Bool = false, switchPressed: Bool = false) -> String {
        if pose == .flipSwitch {
            return "\(rawValue)-switch-\((lightsOff || switchPressed) ? "down" : "up")"
        }
        return "\(rawValue)-\(pose.rawValue)"
    }
}

enum VoiceStyle: String, CaseIterable, Identifiable, Codable {
    case dry
    case gentle
    case stern

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dry: "Roast me"
        case .gentle: "Gentle"
        case .stern: "Stern"
        }
    }

    var blurb: String {
        switch self {
        case .dry: "Real roasts, in your character\u{2019}s own style. About the distraction, never about you."
        case .gentle: "Warm reminders without the pressure."
        case .stern: "Short, direct, and not interested in excuses."
        }
    }
}

enum PerchCorner: String, CaseIterable, Identifiable, Codable {
    case bottomTrailing
    case bottomLeading
    case followWindow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bottomTrailing: "Bottom right"
        case .bottomLeading: "Bottom left"
        case .followWindow: "Follow the window"
        }
    }
}

enum AngryMove: String, CaseIterable, Identifiable, Codable {
    case glance
    case talk
    case lights
    case fire
    case notes
    case chase
    case sitOnWindow
    case sound

    var id: String { rawValue }

    var title: String {
        switch self {
        case .glance: "Look over"
        case .talk: "Comment while distracted"
        case .lights: "Flip the lights"
        case .fire: "Set the window on fire"
        case .notes: "Cover it in notes"
        case .chase: "Chase the mouse"
        case .sitOnWindow: "Sit on the window"
        case .sound: "Make a noise"
        }
    }

    var blurb: String {
        switch self {
        case .glance: "Turns and stares when you wander."
        case .talk: "Says something out loud whenever it escalates \u{2014} not just when it flips the lights or sets a fire, but any time it notices you\u{2019}ve wandered off."
        case .lights: "White flash, then the room goes dark."
        case .fire: "Cartoon flames on the off-task window."
        case .notes: "Sticky notes all over what you shouldn’t be doing."
        case .chase: "Hops after the cursor until you come back."
        case .sitOnWindow: "Parks on the window you opened."
        case .sound: "A little click when the lights go."
        }
    }

    var previewEscalation: Escalation {
        switch self {
        case .glance: .glance
        case .lights: .lights
        case .fire: .fire
        case .notes: .notes
        case .sitOnWindow: .fire
        case .talk, .chase, .sound: .nudge
        }
    }
}
