import Foundation

enum SpeechLines {
    static let adhkarLines = [
        "Subhanallah",
        "Alhamdulillah",
        "La ilaha illallah",
        "Astaghfirullah"
    ]

    static func line(
        for escalation: Escalation,
        appName: String,
        host: String?,
        companion: CompanionID,
        voice: VoiceStyle,
        name: String,
        custom: String
    ) -> String? {
        let trimmed = custom.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, escalation >= .nudge, Int.random(in: 0..<3) == 0 {
            return trimmed
        }
        let place = host ?? appName.lowercased()
        let raw: String?
        switch (voice, escalation) {
        case (_, .calm):
            raw = nil
        case (.gentle, .glance):
            raw = ["hmm.", "you still there?", "just checking."].randomElement()
        case (.gentle, .nudge):
            raw = ["come back when you can.", "\(place) can wait.", "one thing, remember?"].randomElement()
        case (.gentle, .lights), (.gentle, .notes):
            raw = ["a little reminder.", "come back to your work.", "back to the thing, please."].randomElement()
        case (.gentle, .fire):
            raw = ["okay, this is the last nudge.", "back to the work.", "come back to the thing."].randomElement()
        case (.stern, .glance):
            raw = ["no.", "look at me.", "that's not it."].randomElement()
        case (.stern, .nudge):
            raw = ["sit down.", "\(place) is closed.", "do the thing."].randomElement()
        case (.stern, .lights), (.stern, .notes):
            raw = ["Get back to work.", "Now. Back to the thing.", "I said now."].randomElement()
        case (.stern, .fire):
            raw = ["FOCUS.", "Get back to work.", "Put it away."].randomElement()
        case (.dry, .glance):
            raw = roastLines(companion: companion, escalation: escalation, place: place).randomElement()
        case (.dry, .nudge):
            raw = roastLines(companion: companion, escalation: escalation, place: place).randomElement()
        case (.dry, .lights), (.dry, .notes):
            raw = roastLines(companion: companion, escalation: escalation, place: place).randomElement()
        case (.dry, .fire):
            raw = roastLines(companion: companion, escalation: escalation, place: place).randomElement()
        }
        return addressed(raw, name: name, escalation: escalation)
    }

    private static func roastLines(companion: CompanionID, escalation: Escalation, place: String) -> [String] {
        let personality: [String] = switch companion {
        case .qasim:
            ["\(place)? Be serious.", "I closed the laptop for this?", "The task is still right there."]
        case .hana:
            ["Cute tab. Wrong tab.", "That scroll was very productive. For \(place).", "You chose focus, remember?"]
        case .nur:
            ["…\(place). Bold.", "The eyes saw that.", "Interesting definition of focus."]
        }
        let pressure: [String] = switch escalation {
        case .calm: []
        case .glance: ["We had a deal.", "That's not the thing."]
        case .nudge: ["Your focus left before I did.", "Back to the assignment."]
        case .lights, .notes: ["The warning label was me.", "Lights. Since subtlety failed."]
        case .fire: ["I am not a decoration.", "Even the window is tired of this."]
        }
        return personality + pressure
    }

#if DEBUG
    static func selfCheck() {
        for companion in CompanionID.allCases {
            for escalation in [Escalation.glance, .nudge, .lights, .fire] {
                assert(!roastLines(companion: companion, escalation: escalation, place: "example.com").isEmpty)
            }
        }
    }
#endif

    /// Occasionally leads a distraction line with the user's name ("Thierno, back to work.").
    /// ponytail: coin-flip personalization instead of a full per-line name-aware phrase set.
    private static func addressed(_ raw: String?, name: String, escalation: Escalation) -> String? {
        guard let raw, escalation >= .nudge else { return raw }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, Int.random(in: 0..<2) == 0 else { return raw }
        return "\(trimmed), \(raw)"
    }

    static func pokeLine(companion: CompanionID, voice: VoiceStyle) -> String {
        let personal: [String]
        switch companion {
        case .qasim:
            personal = ["akhi. hands off the thobe.", "don't press me.", "that tickles, actually.", "I saw that."]
        case .hana:
            personal = ["excuse you.", "don't poke the hijab.", "that tickles!", "I am not a button."]
        case .nur:
            personal = ["…the eyes said don't.", "don't press me.", "that tickles. somehow.", "bold of you."]
        }
        let flavor: [String]
        switch voice {
        case .gentle: flavor = ["oh.", "hi.", "still here.", "yes?"]
        case .stern: flavor = ["working.", "don't.", "later."]
        case .dry: flavor = ["ow.", "working.", "yes?", "that tickles."]
        }
        return (personal + flavor).randomElement() ?? "hey."
    }

    static func previewStartLine(companion: CompanionID) -> String {
        switch companion {
        case .qasim: "this is the look. click Stop preview if you've seen enough."
        case .hana: "don't say I didn't warn you. click Stop preview to leave."
        case .nur: "watch. click Stop preview when you're done staring."
        }
    }

    static func previewStopLine(companion: CompanionID) -> String {
        switch companion {
        case .qasim: "show's over. go on."
        case .hana: "enough of that. I'm here."
        case .nur: "that's enough."
        }
    }

    static func previewLine(for move: AngryMove) -> String {
        "Previewing \(move.title.lowercased()). Click Stop when you've seen enough."
    }

    static func doneLine(voice: VoiceStyle, name: String = "") -> String {
        let line: String
        switch voice {
        case .gentle: line = ["you did it.", "that was a good one.", "go stretch."].randomElement() ?? "done."
        case .stern: line = ["finished. good.", "next."].randomElement() ?? "done."
        case .dry: line = ["done. you did it.", "that's a session.", "see? you can finish things."].randomElement() ?? "done."
        }
        return addressed(line, name: name, escalation: .nudge) ?? line
    }

    static func startLine(voice: VoiceStyle, name: String = "") -> String {
        let line: String
        switch voice {
        case .gentle: line = ["bismillah.", "together.", "one thing."].randomElement() ?? "okay."
        case .stern: line = ["begin.", "timer's on.", "work."].randomElement() ?? "begin."
        case .dry: line = ["bismillah. one thing.", "let's go.", "I'm watching."].randomElement() ?? "okay."
        }
        return addressed(line, name: name, escalation: .nudge) ?? line
    }

    static func breakLine(for activity: BreakActivity) -> String {
        switch activity {
        case .adhkar:
            return adhkarLines[0]
        case .quran:
            return [
                "Hey, I'm gonna read some Quran.",
                "Let's read some Quran.",
                "A quiet page of Quran."
            ].randomElement() ?? "Let's read some Quran."
        case .rest:
            return [
                "A quiet break.",
                "Rest your eyes. Remember Allah.",
                "Breathe. The work can wait."
            ].randomElement() ?? "A quiet break."
        }
    }

    static func breakFinishedLine() -> String {
        ["Break's over.", "Ready for one more?", "Back to it when you are."].randomElement() ?? "Break's over."
    }

    static func salahSoon(_ name: PrayerName, at date: Date) -> String {
        let wait = TimePhrase.remaining(until: date)
        return [
            "\(name.title) is in \(wait).",
            "hey. \(name.title) in \(wait).",
            "wrap this thought. \(name.title) in \(wait)."
        ].randomElement() ?? "\(name.title) is in \(wait)."
    }

    static func salahNow(_ name: PrayerName) -> String {
        [
            "time for \(name.title).",
            "\(name.title). the work will wait.",
            "come pray."
        ].randomElement() ?? "time to pray."
    }

    /// The nudge that waits for an answer. Gets shorter and firmer each snooze.
    static func salahAsk(_ ask: SalahAsk, now: Date = Date()) -> String {
        let wait = TimePhrase.remaining(until: ask.due, from: now)
        switch ask.snoozes {
        case 0: return "\(ask.name.title) is in \(wait). Getting up?"
        // Once he's standing in the middle of the screen he uses the words of the
        // adhan rather than a countdown.
        case 1: return "Hayya 'ala-s-salah.\nCome to prayer. \(ask.name.title) in \(wait)."
        default: return "Hayya 'ala-l-falah.\nCome to success. \(ask.name.title) in \(wait)."
        }
    }

    static func salahRising() -> String {
        ["good. go.", "Allah accept it.", "I'll be here."].randomElement() ?? "go."
    }

    static func salahSnooze(times: Int) -> String {
        times >= 1
            ? ["one. I'm counting.", "last minute."].randomElement() ?? "one minute."
            : ["one minute.", "I'll be back.", "counting."].randomElement() ?? "one minute."
    }

    /// After he finishes praying he picks your task back up by name.
    static func salahDone(voice: VoiceStyle, task: String) -> String {
        let name = task.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            return ["back. \(name).", "done. \(name) — where were we?"].randomElement() ?? "back. \(name)."
        }
        switch voice {
        case .gentle: return "back. take your time."
        case .stern: return "back. work."
        case .dry: return "back. where were we?"
        }
    }
}

enum TimePhrase {
    static func remaining(until date: Date, from now: Date = Date()) -> String {
        let minutes = max(0, Int(ceil(date.timeIntervalSince(now) / 60)))
        return minutesOnly(minutes)
    }

    static func minutesOnly(_ minutes: Int) -> String {
        let hours = minutes / 60
        let leftover = minutes % 60
        if hours == 0 {
            return leftover == 1 ? "1 minute" : "\(max(leftover, 1)) minutes"
        }
        let hourBit = hours == 1 ? "1 hour" : "\(hours) hours"
        if leftover == 0 { return hourBit }
        let minuteBit = leftover == 1 ? "1 minute" : "\(leftover) minutes"
        return "\(hourBit) and \(minuteBit)"
    }
}
