import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    /// Swaps the page for "What they do" inside the same window.
    @State private var showActions = false

    var body: some View {
        Group {
            if showActions {
                VStack(spacing: 0) {
                    ScreenHeader(title: "What they do", back: { showActions = false })
                    SettingsColumn {
                        Text("Some reactions are always part of \(model.prefs.companion.displayName). Tap Preview to watch any of them.")
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        ActionsCustomizeSection()
                    }
                }
            } else {
                VStack(spacing: 0) {
                    ScreenHeader(title: "Settings", back: { model.closeSettings() })
                    SettingsColumn {
                        CompanionVisibilityNotice()
                        companion
                        desktop
                        timer
                        sessions
                        salah
                    }
                }
            }
        }
        .background(Palette.ground)
        .foregroundStyle(Palette.ink)
        .tint(Palette.ink)
        .preferredColorScheme(.light)
    }

    // MARK: Sections

    private var companion: some View {
        let prefs = model.prefs
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Companion").padding(.leading, 4)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(CompanionID.allCases) { companion in
                    CompanionTile(companion: companion, selected: prefs.companion == companion) {
                        prefs.companion = companion
                        prefs.save()
                    }
                }
            }
            Text(prefs.companion.blurb)
                .font(.system(size: 12))
                .foregroundStyle(Palette.inkSoft)
                .padding(.bottom, 4)
            FieldBox {
                SettingsRow("Temper") {
                    segments("Temper", prefs.saving(\.temper), Temper.allCases) { $0.title }
                }
                RowLine()
                SettingsRow("Voice") {
                    segments("Voice", prefs.saving(\.voice), VoiceStyle.allCases) { $0.title }
                }
                RowLine()
                VStack(alignment: .leading, spacing: 6) {
                    Text("A line they say when they're mad").font(.system(size: 15))
                    TextField("A line they say when they're mad", text: prefs.saving(\.customAngryLine),
                              prompt: Text("back to the ayah. or whatever you want.").foregroundStyle(Palette.muted))
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .labelsHidden()
                        .padding(.horizontal, 10)
                        .frame(height: 38)
                        .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Palette.ink.opacity(0.25)))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                RowLine()
                Button { showActions = true } label: {
                    SettingsRow("What they do when you drift") {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.muted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var desktop: some View {
        let prefs = model.prefs
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel("On your desktop").padding(.leading, 4)
            FieldBox {
                SwitchRow(title: "Stay on the desktop between sessions", isOn: prefs.saving(\.alwaysOnDesktop))
                RowLine()
                SwitchRow(title: "Show while I'm focused", isOn: prefs.saving(\.showWhileFocused))
                RowLine()
                SwitchRow(title: "Wander around when bored", isOn: prefs.saving(\.wanderWhenIdle))
                RowLine()
                SwitchRow(title: "Speech bubbles", isOn: prefs.saving(\.speechEnabled))
                RowLine()
                SwitchRow(title: "Less motion", isOn: prefs.saving(\.reducedMotion))
                RowLine()
                SettingsRow("Home corner") {
                    segments("Home corner", prefs.saving(\.perch), PerchCorner.allCases) { corner in
                        switch corner {
                        case .bottomTrailing: "Right"
                        case .bottomLeading: "Left"
                        case .followWindow: "Follow window"
                        }
                    }
                }
                RowLine()
                sliderRow("Size", prefs.saving(\.characterScale), 0.7...1.55, step: 0.05)
                RowLine()
                sliderRow("Yell volume", prefs.saving(\.yellVolume), 0...1)
            }
        }
    }

    private var timer: some View {
        let prefs = model.prefs
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Timer").padding(.leading, 4)
            FieldBox {
                SwitchRow(title: "Show the timer", isOn: prefs.saving(\.showTimerChip))
                RowLine()
                SwitchRow(title: "Keep it above other windows", isOn: prefs.saving(\.timerOnTop))
            }
        }
    }

    private var sessions: some View {
        let prefs = model.prefs
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Sessions").padding(.leading, 4)
            FieldBox {
                stepperRow("Daily goal", prefs.saving(\.dailyGoalMinutes), 15...480, step: 15, less: "Less", more: "More")
                RowLine()
                stepperRow("Break length", prefs.saving(\.breakMinutes), 1...30, step: 1, less: "Shorter", more: "Longer")
            }
        }
    }

    private var salah: some View {
        let prefs = model.prefs
        let salah = model.salah
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Salah").padding(.leading, 4)
            FieldBox {
                SwitchRow(title: "Prayer reminders", isOn: prefs.saving(\.salahReminders) {
                    salah.invalidate()
                    if prefs.salahReminders { salah.start(prefs: prefs) }
                })
                RowLine()
                SettingsRow("Remind me") {
                    segments("How early", prefs.saving(\.salahLeadMinutes) { salah.invalidate() }, [5, 10, 15, 20]) {
                        $0 == 20 ? "20 min" : "\($0)"
                    }
                }
                RowLine()
                SwitchRow(title: "Wait for my answer", isOn: prefs.saving(\.salahAsk))
                if prefs.salahAsk {
                    RowLine()
                    SwitchRow(title: "Stand in the way if I stall", isOn: prefs.saving(\.salahStandInTheWay))
                    RowLine()
                    SwitchRow(title: "Chime with the reminder", isOn: prefs.saving(\.salahChime))
                }
                RowLine()
                SalahLocationSection()
            }
            if let next = salah.nextOccurrence(after: Date()) {
                Text("Next: \(next.name.title) at \(next.date.formatted(date: .omitted, time: .shortened)) · in \(TimePhrase.remaining(until: next.date))")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: Row builders

    private func sliderRow(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, step: Double = 0.01) -> some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 15)).frame(width: 104, alignment: .leading)
            Slider(value: value, in: range, step: step).accessibilityLabel(title)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
    }

    private func stepperRow(_ title: String, _ value: Binding<Int>, _ range: ClosedRange<Int>, step: Int, less: String, more: String) -> some View {
        HStack(spacing: 0) {
            Text(title).font(.system(size: 15))
            Spacer(minLength: 12)
            StepButton(symbol: "minus", label: "\(less) \(title.lowercased())", disabled: value.wrappedValue <= range.lowerBound) {
                value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
            }
            Text("\(value.wrappedValue) min")
                .font(.system(size: 15).monospacedDigit())
                .frame(width: 72)
                .accessibilityLabel("\(title), \(value.wrappedValue) minutes")
            StepButton(symbol: "plus", label: "\(more) \(title.lowercased())", disabled: value.wrappedValue >= range.upperBound) {
                value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .frame(minHeight: 50)
    }
}

// MARK: - Shared pieces

/// The centered scrolling column every settings page sits in.
private struct SettingsColumn<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) { content }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 32)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
        }
    }
}

/// A 50pt settings row: title on the left, a control on the right.
/// Wide controls (segmented pickers) drop below the title when the window is narrow.
struct SettingsRow<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                Text(title).font(.system(size: 15))
                Spacer(minLength: 0)
                trailing
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.system(size: 15))
                trailing
            }
            .padding(.vertical, 10)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
    }
}

/// A native segmented picker sized to its content.
@MainActor
func segments<T: Hashable>(_ label: String, _ selection: Binding<T>, _ options: [T], title: @escaping (T) -> String) -> some View {
    Picker(label, selection: selection) {
        ForEach(options, id: \.self) { Text(title($0)).tag($0) }
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    .fixedSize()
}

private struct StepButton: View {
    let symbol: String
    let label: String
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(Palette.ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .accessibilityLabel(label)
    }
}

private struct CompanionTile: View {
    let companion: CompanionID
    let selected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                Image(companion.assetName(for: .idle))
                    .resizable()
                    .scaledToFit()
                    .frame(height: 64)
                Text(companion.displayName)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(companion.personality)
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(selected ? Palette.field : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? Palette.ink : .clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(companion.displayName), \(companion.personality)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

extension Preferences {
    /// A binding that saves on every change, then runs `after` for side effects.
    func saving<T>(_ keyPath: ReferenceWritableKeyPath<Preferences, T>, after: @escaping () -> Void = {}) -> Binding<T> {
        Binding(
            get: { self[keyPath: keyPath] },
            set: {
                self[keyPath: keyPath] = $0
                self.save()
                after()
            }
        )
    }
}

// MARK: - Onboarding character picker (old style, kept for SetupView)

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

// MARK: - What they do

/// The "What they do" list: drift reactions (some always on), salah and break previews.
struct ActionsCustomizeSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let prefs = model.prefs
        VStack(alignment: .leading, spacing: 24) {
            group("When you drift · always on") {
                rows(AngryMove.allCases.filter { Preferences.alwaysOnMoves.contains($0) }) { move in
                    actionRow(move.title, move.blurb, previewing: model.previewingMove == move, preview: { model.preview(move) }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 44)
                            .accessibilityLabel("Always on")
                    }
                }
            }
            group("When you drift · your choice") {
                rows([AngryMove.chase, .sound]) { move in
                    actionRow(move.title, move.blurb, previewing: model.previewingMove == move, preview: { model.preview(move) }) {
                        Toggle(move.title, isOn: Binding(get: { prefs.allows(move) }, set: { _ in prefs.toggle(move) }))
                            .toggleStyle(.switch)
                            .tint(Palette.ink)
                            .labelsHidden()
                            .frame(width: 44)
                    }
                }
            }
            group("At salah time") {
                actionRow("Pray on the desktop", "Qiyam, Ruku, and Sujood on the prayer mat when it\u{2019}s time.",
                          previewing: model.previewingSalah, preview: model.previewSalah) {
                    onOff("Pray on the desktop", \.prayOnDesktop)
                }
            }
            group("On breaks") {
                rows(BreakActivity.allCases.filter { $0 != .rest }) { activity in
                    actionRow(activity.title, activity.blurb,
                              previewing: model.actionPreview == .breakActivity(activity),
                              preview: { model.preview(activity) }) {
                        onOff(activity.title, activity == .adhkar ? \.breakAdhkar : \.breakQuran)
                    }
                }
            }
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title).padding(.leading, 4)
            FieldBox { content() }
        }
    }

    private func rows<Item: Hashable, Row: View>(_ items: [Item], @ViewBuilder row: @escaping (Item) -> Row) -> some View {
        ForEach(items, id: \.self) { item in
            if item != items.first { RowLine() }
            row(item)
        }
    }

    private func onOff(_ title: String, _ key: ReferenceWritableKeyPath<Preferences, Bool>) -> some View {
        let prefs = model.prefs
        return Toggle(title, isOn: Binding(get: { prefs[keyPath: key] }, set: { prefs[keyPath: key] = $0; prefs.save() }))
            .toggleStyle(.switch)
            .tint(Palette.ink)
            .labelsHidden()
            .frame(width: 44)
    }

    private func actionRow<Leading: View>(
        _ title: String,
        _ blurb: String,
        previewing: Bool,
        preview: @escaping () -> Void,
        @ViewBuilder leading: () -> Leading
    ) -> some View {
        HStack(spacing: 12) {
            leading()
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(blurb)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button(action: preview) {
                Text(previewing ? "Stop" : "Preview")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .overlay(Capsule().stroke(Palette.ink, lineWidth: 1.5))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(previewing ? "Stop preview of \(title)" : "Preview \(title)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: 64)
    }
}

// MARK: - Salah times source

/// "Times from" plus what follows it: location status, city, masjid times, method and Asr.
/// Rows meant to sit inside a FieldBox. Shared by Settings and onboarding.
struct SalahLocationSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let prefs = model.prefs
        let salah = model.salah
        VStack(alignment: .leading, spacing: 0) {
            SettingsRow("Times from") {
                segments("Prayer times from", sourceBinding, SalahSource.allCases) { $0 == .masjid ? "My masjid" : $0.title }
            }

            if prefs.salahSource == .location {
                RowLine()
                HStack(spacing: 12) {
                    Text(salah.status.isEmpty ? "Uses where this Mac is. You can pick a city instead." : salah.status)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("Use my location") { salah.useMyLocation(prefs: prefs) }
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(minHeight: 44)
                }
                .padding(.horizontal, 14)
            }

            if prefs.salahSource == .city || (prefs.salahSource == .location && salah.locator.denied) {
                RowLine()
                SettingsRow("City") {
                    Picker("City", selection: prefs.saving(\.salahCityName) { salah.invalidate() }) {
                        ForEach(GeoPlace.cities) { Text($0.name).tag($0.name) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }

            if prefs.salahSource == .masjid {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(PrayerTimes.salahOrder, id: \.self) { name in
                        HStack {
                            Text(name.title).font(.system(size: 15))
                            Spacer()
                            DatePicker(name.title, selection: masjidBinding(name), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                        .frame(minHeight: 34)
                    }
                    Text("Type the times your masjid actually prays. Reminders follow these, not the calculated ones.")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 12)
            } else {
                RowLine()
                SettingsRow("Method") {
                    Picker("Method", selection: prefs.saving(\.salahMethod) { salah.invalidate() }) {
                        ForEach(CalculationMethod.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                RowLine()
                SettingsRow("Asr") {
                    segments("Asr school", prefs.saving(\.asrSchool) { salah.invalidate() }, AsrSchool.allCases) { $0.title }
                }
            }
        }
    }

    private var sourceBinding: Binding<SalahSource> {
        let prefs = model.prefs
        let salah = model.salah
        return Binding(
            get: { prefs.salahSource },
            set: { source in
                prefs.salahSource = source
                if source != .location {
                    prefs.salahLatitude = nil
                    prefs.salahLongitude = nil
                }
                prefs.save()
                salah.invalidate()
                if source == .location {
                    salah.useMyLocation(prefs: prefs)
                }
            }
        )
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
}
