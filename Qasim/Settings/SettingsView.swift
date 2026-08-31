import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var prefs = model.prefs

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Make it yours.")
                    .font(Typeface.display(26))
                    .foregroundStyle(Palette.ink)

                CompanionVisibilityNotice()

                section("Who sits with you") {
                    characterGrid
                }

                section("Actions") {
                    ActionsCustomizeSection()
                }

                section("How they talk") {
                    Picker("Voice", selection: $prefs.voice) {
                        ForEach(VoiceStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .foregroundStyle(Palette.ink)
                    .onChange(of: prefs.voice) { _, _ in prefs.save() }
                    Text(prefs.voice.blurb)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.inkSoft)

                    Text("A line they can reuse when they're mad")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                    TextField("", text: $prefs.customAngryLine, prompt: Text("back to the ayah. or whatever you want.").foregroundStyle(Palette.ink.opacity(0.45)))
                        .textFieldStyle(.plain)
                        .foregroundStyle(Palette.ink)
                        .padding(10)
                        .background(Palette.cream, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Palette.ink.opacity(0.15), lineWidth: 1)
                        )
                        .onChange(of: prefs.customAngryLine) { _, _ in prefs.save() }
                }

                section("Salah") {
                    Text("A ping 10 minutes before, and another when it’s time. Nothing stays on the desktop.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.inkSoft)
                    toggle("Remind me about salah", $prefs.salahReminders)
                        .onChange(of: prefs.salahReminders) { _, on in
                            model.salah.invalidate()
                            if on { model.salah.start(prefs: prefs) }
                        }

                    toggle("Wait for an answer", $prefs.salahAsk)
                    Text("Before the prayer they ask, and the bubble stays until you answer. You can take one more minute twice.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.inkSoft)

                    if prefs.salahAsk {
                        toggle("Stand in the way", $prefs.salahStandInTheWay)
                        Text("When your borrowed minute runs out they walk to the middle of the screen and call you to prayer.")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.inkSoft)

                        toggle("Chime with the reminder", $prefs.salahChime)
                    }

                    Picker("Times from", selection: $prefs.salahSource) {
                        ForEach(SalahSource.allCases) { source in
                            Text(source.title).tag(source)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: prefs.salahSource) { _, source in
                        if source != .location {
                            prefs.salahLatitude = nil
                            prefs.salahLongitude = nil
                        }
                        prefs.save()
                        model.salah.invalidate()
                        if source == .location {
                            model.salah.useMyLocation(prefs: prefs)
                        }
                    }

                    if prefs.salahSource == .location {
                        Text(model.salah.status.isEmpty ? "Uses where this Mac is. You can turn that off and pick a city instead." : model.salah.status)
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.inkSoft)
                        Button("Use my location") {
                            model.salah.useMyLocation(prefs: prefs)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.ember)
                    }

                    if prefs.salahSource == .city || (prefs.salahSource == .location && model.salah.locator.denied) {
                        Picker("City", selection: $prefs.salahCityName) {
                            ForEach(GeoPlace.cities) { city in
                                Text(city.name).tag(city.name)
                            }
                        }
                        .foregroundStyle(Palette.ink)
                        .onChange(of: prefs.salahCityName) { _, _ in
                            prefs.save()
                            model.salah.invalidate()
                        }
                    }

                    if prefs.salahSource == .masjid {
                        Text("Type the times your masjid actually prays. Reminders follow these, not the calculated ones.")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.inkSoft)
                        ForEach(PrayerTimes.salahOrder, id: \.self) { name in
                            HStack {
                                Text(name.title)
                                    .foregroundStyle(Palette.ink)
                                    .frame(width: 72, alignment: .leading)
                                DatePicker(
                                    "",
                                    selection: masjidBinding(name),
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                                .foregroundStyle(Palette.ink)
                            }
                        }
                    }

                    if prefs.salahSource != .masjid {
                        Picker("Method", selection: $prefs.salahMethod) {
                            ForEach(CalculationMethod.allCases) { method in
                                Text(method.title).tag(method)
                            }
                        }
                        .foregroundStyle(Palette.ink)
                        .onChange(of: prefs.salahMethod) { _, _ in
                            prefs.save()
                            model.salah.invalidate()
                        }
                        Picker("Asr", selection: $prefs.asrSchool) {
                            ForEach(AsrSchool.allCases) { school in
                                Text(school.title).tag(school)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: prefs.asrSchool) { _, _ in
                            prefs.save()
                            model.salah.invalidate()
                        }
                    }

                    Picker("Warn me", selection: $prefs.salahLeadMinutes) {
                        Text("5 minutes before").tag(5)
                        Text("10 minutes before").tag(10)
                        Text("15 minutes before").tag(15)
                        Text("20 minutes before").tag(20)
                    }
                    .foregroundStyle(Palette.ink)
                    .onChange(of: prefs.salahLeadMinutes) { _, _ in
                        prefs.save()
                        model.salah.invalidate()
                    }

                    if let next = model.salah.nextOccurrence(after: Date()) {
                        Text("Next: \(next.name.title) at \(next.date.formatted(date: .omitted, time: .shortened)) · in \(TimePhrase.remaining(until: next.date))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                    }
                }

                section("Desktop") {
                    Picker("Home corner", selection: $prefs.perch) {
                        ForEach(PerchCorner.allCases) { corner in
                            Text(corner.title).tag(corner)
                        }
                    }
                    .foregroundStyle(Palette.ink)
                    .onChange(of: prefs.perch) { _, _ in prefs.save() }

                    HStack {
                        Text("Size")
                            .foregroundStyle(Palette.ink)
                        Slider(value: $prefs.characterScale, in: 0.7...1.55, step: 0.05)
                            .onChange(of: prefs.characterScale) { _, _ in prefs.save() }
                        Text(prefs.characterScale == 1 ? "Normal" : String(format: "%.0f%%", prefs.characterScale * 100))
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(Palette.inkSoft)
                            .frame(width: 56, alignment: .trailing)
                    }

                    toggle("Stay on the desktop even when you're not focusing", $prefs.alwaysOnDesktop)
                    toggle("Wander around when bored", $prefs.wanderWhenIdle)
                    toggle("Show the timer chip", $prefs.showTimerChip)
                    toggle("Keep Timer On Top", $prefs.timerOnTop)
                    Text("Timer window stays above all other windows")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.inkSoft)
                    toggle("Show them while you're focused, not only when you wander", $prefs.showWhileFocused)
                    toggle("Speech bubbles", $prefs.speechEnabled)
                    toggle("Less hopping", $prefs.reducedMotion)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("How loud they yell")
                            .foregroundStyle(Palette.ink)
                        HStack {
                            Image(systemName: "speaker.fill")
                                .foregroundStyle(Palette.inkSoft)
                            Slider(value: $prefs.yellVolume, in: 0...1)
                                .onChange(of: prefs.yellVolume) { _, _ in prefs.save() }
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundStyle(Palette.inkSoft)
                        }
                    }
                }

                section("Daily goal") {
                    Stepper(value: $prefs.dailyGoalMinutes, in: 15...480, step: 15) {
                        Text("\(prefs.dailyGoalMinutes) minutes a day")
                            .foregroundStyle(Palette.ink)
                    }
                    .foregroundStyle(Palette.ink)
                    .onChange(of: prefs.dailyGoalMinutes) { _, _ in prefs.save() }
                }

                section("Break length") {
                    Stepper(value: $prefs.breakMinutes, in: 1...30, step: 1) {
                        Text("\(prefs.breakMinutes) minute break")
                            .foregroundStyle(Palette.ink)
                    }
                    .foregroundStyle(Palette.ink)
                    .onChange(of: prefs.breakMinutes) { _, _ in prefs.save() }
                }


            }
            .padding(22)
            .padding(.top, 18)
        }
        .background(Palette.paper)
        .foregroundStyle(Palette.ink)
        .preferredColorScheme(.light)
        .tint(Palette.ember)
    }

    private var characterGrid: some View {
        return VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 10)], spacing: 10) {
                ForEach(CompanionID.allCases) { companion in
                    CharacterCard(companion: companion, selected: model.prefs.companion == companion) {
                        model.prefs.companion = companion
                        model.prefs.save()
                    }
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Typeface.display(20))
                .foregroundStyle(Palette.ink)
            content()
        }
    }

    private func masjidBinding(_ name: PrayerName) -> Binding<Date> {
        Binding(
            get: {
                let clock = model.prefs.customSalah[name.rawValue] ?? SalahClock.placeholder(for: name)
                return clock.date(on: Date()) ?? Date()
            },
            set: { date in
                model.prefs.customSalah[name.rawValue] = SalahClock.from(date)
                model.prefs.save()
                model.salah.invalidate()
            }
        )
    }

    private func toggle(_ title: String, _ value: Binding<Bool>) -> some View {
        Toggle(title, isOn: value)
            .tint(Palette.ember)
            .foregroundStyle(Palette.ink)
            .onChange(of: value.wrappedValue) { _, _ in model.prefs.save() }
    }

    private func actionPreviewRow(
        title: String,
        blurb: String,
        isPreviewing: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(blurb)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 4)
            Button(isPreviewing ? "Stop" : "Preview", action: action)
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.ember)
        }
    }
}

struct CharacterCard: View {
    var companion: CompanionID
    var selected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                Image(companion.assetName(for: .idle))
                    .resizable()
                    .scaledToFit()
                    .frame(height: 78)
                Text(companion.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(companion.blurb)
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 168)
            .background(Palette.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? Palette.ink : Palette.ink.opacity(0.12), lineWidth: selected ? 2.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(companion.displayName)
    }
}

struct CharacterPickerStrip: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Who sits with you?")
                .font(Typeface.display(22))
                .foregroundStyle(Palette.ink)
            Text("Three companions, each with the same movement set.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.inkSoft)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 8)], spacing: 8) {
                ForEach(CompanionID.allCases) { companion in
                    CharacterCard(companion: companion, selected: model.prefs.companion == companion) {
                        model.prefs.companion = companion
                        model.prefs.save()
                    }
                }
            }
            Text("How should they talk?")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
                .padding(.top, 4)
            Picker("Voice", selection: Bindable(model.prefs).voice) {
                ForEach(VoiceStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: model.prefs.voice) { _, _ in model.prefs.save() }
            Text(model.prefs.voice.blurb)
                .font(.system(size: 11))
                .foregroundStyle(Palette.inkSoft)
        }
    }
}

/// The "what can this character do" toggle list, shared by Settings and first-run setup.
struct ActionsCustomizeSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var prefs = model.prefs

        VStack(alignment: .leading, spacing: 10) {
            Text("What this character can do. Preview an action before deciding when it is allowed.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.inkSoft)
            Text("Distraction actions")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
            ForEach(AngryMove.allCases.filter { ![.sound, .chase, .sitOnWindow, .glance].contains($0) }) { move in
                HStack(alignment: .center, spacing: 10) {
                    Toggle(isOn: Binding(
                        get: { prefs.allows(move) },
                        set: { _ in prefs.toggle(move); prefs.save() }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(move.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                            Text(move.blurb)
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.inkSoft)
                        }
                    }
                    .tint(Palette.ember)
                    .foregroundStyle(Palette.ink)

                    Spacer(minLength: 4)

                    Button(model.previewingMove == move ? "Stop" : "Preview") {
                        model.preview(move)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.ember)
                    .accessibilityLabel(model.previewingMove == move ? "Stop preview for \(move.title)" : "Preview \(move.title)")
                }
            }

            Divider()

            Text("Salah")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
            actionPreviewRow(
                title: "Salah",
                blurb: "Preview Qiyam, Ruku, and Sujood on the prayer mat.",
                isPreviewing: model.previewingSalah,
                action: model.previewSalah
            )

            Text("Break actions")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
            ForEach(BreakActivity.allCases.filter { $0 != .rest }) { activity in
                actionPreviewRow(
                    title: activity.title,
                    blurb: activity.blurb,
                    isPreviewing: model.actionPreview == .breakActivity(activity),
                    action: { model.preview(activity) }
                )
            }
        }
    }

    private func actionPreviewRow(
        title: String,
        blurb: String,
        isPreviewing: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(blurb)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 4)
            Button(isPreviewing ? "Stop" : "Preview", action: action)
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.ember)
        }
    }
}

/// The salah location/method picker, shared by Settings and first-run setup.
struct SalahLocationSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var prefs = model.prefs

        VStack(alignment: .leading, spacing: 10) {
            Picker("Times from", selection: $prefs.salahSource) {
                ForEach(SalahSource.allCases) { source in
                    Text(source.title).tag(source)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: prefs.salahSource) { _, source in
                if source != .location {
                    prefs.salahLatitude = nil
                    prefs.salahLongitude = nil
                }
                prefs.save()
                model.salah.invalidate()
                if source == .location {
                    model.salah.useMyLocation(prefs: prefs)
                }
            }

            if prefs.salahSource == .location {
                Text(model.salah.status.isEmpty ? "Uses where this Mac is. You can turn that off and pick a city instead." : model.salah.status)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.inkSoft)
                Button("Use my location") {
                    model.salah.useMyLocation(prefs: prefs)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.ember)
            }

            if prefs.salahSource == .city || (prefs.salahSource == .location && model.salah.locator.denied) {
                Picker("City", selection: $prefs.salahCityName) {
                    ForEach(GeoPlace.cities) { city in
                        Text(city.name).tag(city.name)
                    }
                }
                .foregroundStyle(Palette.ink)
                .onChange(of: prefs.salahCityName) { _, _ in
                    prefs.save()
                    model.salah.invalidate()
                }
            }

            if prefs.salahSource != .masjid {
                Picker("Method", selection: $prefs.salahMethod) {
                    ForEach(CalculationMethod.allCases) { method in
                        Text(method.title).tag(method)
                    }
                }
                .foregroundStyle(Palette.ink)
                .onChange(of: prefs.salahMethod) { _, _ in
                    prefs.save()
                    model.salah.invalidate()
                }
                Picker("Asr", selection: $prefs.asrSchool) {
                    ForEach(AsrSchool.allCases) { school in
                        Text(school.title).tag(school)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: prefs.asrSchool) { _, _ in
                    prefs.save()
                    model.salah.invalidate()
                }
            }
        }
    }
}
