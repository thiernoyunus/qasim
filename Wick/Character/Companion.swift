import Foundation

enum CompanionID: String, CaseIterable, Identifiable, Codable {
    case qasim
    case hana
    case nur

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
        }
    }

    var blurb: String {
        switch self {
        case .qasim: "Thobe, kufi, and a look that says go back to work."
        case .hana: "Hijab, warm eyes, zero patience for scrolling."
        case .nur: "Niqab. You only see the eyes. That’s enough."
        }
    }

    var groupTitle: String {
        "In thobe, hijab, niqab"
    }

    var isPixelCompanion: Bool { true }

    var remembersSalah: Bool { isPixelCompanion }

    func assetName(for pose: WickPose) -> String {
        "\(rawValue)-\(pose.rawValue == "flipSwitch" ? "switch" : pose.rawValue)"
    }
}

enum VoiceStyle: String, CaseIterable, Identifiable, Codable {
    case dry
    case gentle
    case stern

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dry: "Dry"
        case .gentle: "Gentle"
        case .stern: "Stern"
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
        case .talk: "Talk back"
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
        case .talk: "Short sentences. Judgmental."
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
