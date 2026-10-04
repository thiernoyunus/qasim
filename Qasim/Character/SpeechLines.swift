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
        guard escalation != .calm else { return nil }
        let trimmed = custom.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, escalation >= .nudge, Int.random(in: 0..<3) == 0 {
            return trimmed
        }
        let place = host ?? appName.lowercased()
        let raw = distractionLines(companion: companion, voice: voice, hot: escalation >= .lights, place: place).randomElement()
        return addressed(raw, name: name, escalation: escalation)
    }

    /// Personality comes from the character, how hard they push comes from the voice.
    /// `hot` is the second half of the escalation (lights, notes, fire).
    private static func distractionLines(companion: CompanionID, voice: VoiceStyle, hot: Bool, place: String) -> [String] {
        switch (companion, voice) {
        // Qasim — the hype man.
        case (.qasim, .dry):
            hot ? ["the comeback story starts… now? now? okay, NOW.",
                   "imagine losing the streak to \(place). IMAGINE.",
                   "I hyped you up to the whole desktop for this??",
                   "you're the GOAT and the GOAT is on \(place)."]
                : ["BRO. you were cooking. and you left for \(place)??",
                   "legends don't open \(place) mid-session. just saying.",
                   "main character energy, spent on side quests.",
                   "nah. you're better than \(place)."]
        case (.qasim, .gentle):
            hot ? ["one more push. you've got this.", "come on, I believe in you.", "let's finish strong. back to it."]
                : ["hey champ, little detour. come back.", "you were doing great. keep it going.", "\(place) can wait. you're on a roll."]
        case (.qasim, .stern):
            hot ? ["LOCK IN.", "back in the game. now.", "no more timeouts."]
                : ["nope. champions don't stop here.", "lock in.", "not now. focus."]

        // Hana — dramatic big sister.
        case (.hana, .dry):
            hot ? ["I'm telling your mum.",
                   "this is the most betrayed I've ever felt.",
                   "I'm writing about this in my diary tonight.",
                   "you've broken my heart AND your deadline."]
                : ["\(place)?? in THIS economy?",
                   "your future self just filed a complaint.",
                   "oh my days. \(place). again.",
                   "I turned around for ONE second."]
        case (.hana, .gentle):
            hot ? ["please. for me. back to the work.", "come back, I miss you already.", "you can do this, I promise."]
                : ["hey you. come back to me.", "I believe in you so much it hurts.", "\(place) doesn't love you like I do."]
        case (.hana, .stern):
            hot ? ["I am NOT doing this with you today.", "back. to. work.", "don't make me come over there."]
                : ["excuse me?", "close it. now.", "absolutely not."]

        // Nur — the silent judge.
        case (.nur, .dry):
            hot ? ["your task called. you let it go to voicemail.",
                   "the eyes have seen enough.",
                   "I'm not mad. I'm writing it down.",
                   "…\(place). bold."]
                : ["…", "noted.", "\(place). hm.", "the eyes saw that."]
        case (.nur, .gentle):
            hot ? ["your work is waiting.", "come back. quietly.", "enough now."]
                : ["…", "come back.", "mm."]
        case (.nur, .stern):
            hot ? ["now.", "back.", "I won't say it twice."]
                : ["no.", "close it.", "…no."]

        // Ahmed — nonchalant.
        case (.ahmed, .dry):
            hot ? ["I'm not even mad. I'm just watching this happen.",
                   "lowkey impressive how fast you left.",
                   "you're not procrastinating. you're doing unpaid research for \(place).",
                   "that video won't do your work. I checked."]
                : ["\(place) again. wild. anyway.",
                   "nah it's cool. deadlines are more of a suggestion.",
                   "you've opened that more than your notes this week.",
                   "it's whatever. it's your grade."]
        case (.ahmed, .gentle):
            hot ? ["no pressure. but like, come back.", "it's okay. we're good. back to the thing.", "relax. then come back."]
                : ["no stress. just come back.", "all good. back to it when you can.", "\(place)'s chill, but the work's waiting."]
        case (.ahmed, .stern):
            hot ? ["alright. that's enough.", "back to work. seriously.", "I'm done being chill."]
                : ["nah.", "close that.", "not right now."]

        // Safa — sweet but savage.
        case (.safa, .dry):
            hot ? ["no no, take your time. the deadline will wait. (it won't.)",
                   "bless your heart. now close it.",
                   "so proud of you. of what, I'm not sure.",
                   "I'll make du'a for your grade."]
                : ["MashaAllah, so dedicated… to \(place).",
                   "such a hard worker. at scrolling.",
                   "your assignment misses you, habibi.",
                   "aww, look at you. avoiding things."]
        case (.safa, .gentle):
            hot ? ["come on, you're doing so well.", "back to it, my dear.", "just a little more, then rest."]
                : ["habibi, come back.", "sweetheart, the work misses you.", "\(place) can wait, love."]
        case (.safa, .stern):
            hot ? ["I'm not asking nicely anymore.", "back. to. work. habibi.", "don't test me."]
                : ["habibi. no.", "close it, please. now.", "I asked nicely once."]
        }
    }

#if DEBUG
    static func selfCheck() {
        for companion in CompanionID.allCases {
            for voice in VoiceStyle.allCases {
                for hot in [false, true] {
                    assert(!distractionLines(companion: companion, voice: voice, hot: hot, place: "example.com").isEmpty)
                }
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

    static func pokeLine(companion: CompanionID) -> String {
        let lines: [String] = switch companion {
        case .qasim: ["ayy! hands off the thobe.", "you poked a legend.", "that tickles, akhi!", "save that energy for the work!"]
        case .hana: ["excuse you!", "don't poke the hijab!", "rude. I'm telling.", "I am NOT a button."]
        case .nur: ["…", "the eyes said don't.", "bold of you.", "noted."]
        case .ahmed: ["careful with the kufi.", "eh. it's fine.", "that tickles, I guess.", "cool. cool cool."]
        case .safa: ["careful with the niqab, sweetie.", "aww, you poked me. don't.", "habibi. hands.", "bold of you."]
        }
        return lines.randomElement() ?? "hey."
    }

    static func previewStartLine(companion: CompanionID) -> String {
        switch companion {
        case .qasim: "watch this. click Stop preview when you're hyped enough."
        case .hana: "don't say I didn't warn you. click Stop preview to leave."
        case .nur: "watch. click Stop preview when you're done staring."
        case .ahmed: "this is the look. click Stop preview whenever."
        case .safa: "watch, sweetie. click Stop preview when you're done."
        }
    }

    static func previewStopLine(companion: CompanionID) -> String {
        switch companion {
        case .qasim: "show's over. now go cook."
        case .hana: "enough of that. I'm here."
        case .nur: "that's enough."
        case .ahmed: "show's over. anyway."
        case .safa: "that's enough, habibi."
        }
    }

    static func previewLine(for move: AngryMove) -> String {
        "Previewing \(move.title.lowercased()). Click Stop when you've seen enough."
    }

    static func doneLine(companion: CompanionID, name: String = "") -> String {
        let lines: [String] = switch companion {
        case .qasim: ["THAT'S WHAT I'M TALKING ABOUT.", "session DONE. you're unstoppable.", "LET'S GOOO. go stretch, champ."]
        case .hana: ["I'm literally so proud of you.", "you did it! I'm crying.", "look at you, finishing things!"]
        case .nur: ["good.", "done.", "…well done."]
        case .ahmed: ["done. easy.", "that's a session. not bad.", "see? no big deal."]
        case .safa: ["MashaAllah, you actually finished!", "so proud of you, habibi.", "look at you. a whole session."]
        }
        let line = lines.randomElement() ?? "done."
        return addressed(line, name: name, escalation: .nudge) ?? line
    }

    static func startLine(companion: CompanionID, name: String = "") -> String {
        let lines: [String] = switch companion {
        case .qasim: ["LET'S GOOO. bismillah.", "bismillah. we're locking in.", "game time."]
        case .hana: ["bismillah. I'm so excited for you.", "okay okay okay. let's do this.", "bismillah. make me proud."]
        case .nur: ["bismillah.", "begin.", "…go."]
        case .ahmed: ["bismillah. no rush.", "aight. let's do this.", "cool. we're working."]
        case .safa: ["bismillah, habibi.", "let's go, my dear.", "bismillah. I'm watching. lovingly."]
        }
        let line = lines.randomElement() ?? "bismillah."
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
        let title = ask.name.title
        // The nudge can outlive the adhan (a borrowed minute, a late wake), so
        // it must not keep counting down to a time that has already come.
        let started = ask.due <= now
        let when = started
            ? "\(title) has started"
            : "\(title) in \(TimePhrase.remaining(until: ask.due, from: now))"
        switch ask.snoozes {
        case 0:
            return started
                ? "It's time for \(title). Getting up?"
                : "\(title) is in \(TimePhrase.remaining(until: ask.due, from: now)). Getting up?"
        // Once he's standing in the middle of the screen he uses the words of the
        // adhan rather than a countdown.
        case 1: return "Hayya 'ala-s-salah.\nCome to prayer. \(when)."
        default: return "Hayya 'ala-l-falah.\nCome to success. \(when)."
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
            return leftover <= 1 ? "1 minute" : "\(leftover) minutes"
        }
        let hourBit = hours == 1 ? "1 hour" : "\(hours) hours"
        if leftover == 0 { return hourBit }
        let minuteBit = leftover == 1 ? "1 minute" : "\(leftover) minutes"
        return "\(hourBit) and \(minuteBit)"
    }
}
