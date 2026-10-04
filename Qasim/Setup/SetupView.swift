import AppKit
import SwiftUI

/// First-launch onboarding: name, companion, prayer reminders. Three short
/// screens, one big Continue bar. Finishing goes straight into the first session.
struct SetupView: View {
    @Environment(AppModel.self) private var model
    @State private var step: Int = 0
    @FocusState private var nameFieldFocused: Bool

    private let totalSteps = 3

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                stepDots
                HStack {
                    if step > 0 {
                        IconButton(systemName: "arrow.left", label: "Back") { step -= 1 }
                    }
                    Spacer()
                }
            }
            .frame(height: 52)
            .padding(.horizontal, 12)

            ScrollView {
                VStack(spacing: 0) {
                    CompanionVisibilityNotice()
                    switch step {
                    case 0: nameStep
                    case 1: companionStep
                    default: salahStep
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }

            Group {
                if step < totalSteps - 1 {
                    Button("Continue") { step += 1 }
                } else {
                    Button("Start my first session") { model.finishOnboarding() }
                }
            }
            .buttonStyle(BarButtonStyle())
            .keyboardShortcut(.defaultAction)
        }
        .background(Palette.ground)
        .foregroundStyle(Palette.ink)
        .preferredColorScheme(.light)
    }

    private var stepDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i == step ? Palette.ink : Palette.ink.opacity(0.25))
                    .frame(width: i == step ? 22 : 6, height: 6)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(step + 1) of \(totalSteps)")
    }

    private var nameStep: some View {
        VStack(spacing: 0) {
            Image(model.prefs.companion.assetName(for: .idle))
                .resizable()
                .scaledToFit()
                .frame(height: 180)
                .padding(.top, 20)
                .padding(.bottom, 22)
                .accessibilityLabel("\(model.prefs.companion.displayName) says hello")
            Text("Assalamu alaikum.")
                .font(.system(size: 26, weight: .bold))
                .padding(.bottom, 8)
            Text("I\u{2019}ll sit on your screen while you work, and speak up when you drift.")
                .font(.system(size: 16))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 32)
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("What should I call you?")
                TextField("Your name", text: Bindable(model.prefs).userName)
                    .focused($nameFieldFocused)
                    .onAppear {
                        // The panel becomes key just after SwiftUI appears.
                        DispatchQueue.main.async { nameFieldFocused = true }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(Palette.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Palette.ink, lineWidth: 1.5))
                    .onSubmit { step += 1 }
            }
        }
    }

    private var companionStep: some View {
        let selected = model.prefs.companion
        return VStack(spacing: 0) {
            Text("Who keeps you company?")
                .font(.system(size: 26, weight: .bold))
                .padding(.top, 20)
                .padding(.bottom, 6)
            Text("You can switch anytime in Settings.")
                .font(.system(size: 16))
                .foregroundStyle(Palette.muted)
                .padding(.bottom, 24)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                ForEach(CompanionID.allCases) { companion in
                    let isOn = companion == selected
                    Button {
                        model.prefs.companion = companion
                        model.prefs.save()
                    } label: {
                        VStack(spacing: 8) {
                            Image(companion.assetName(for: .idle))
                                .resizable()
                                .scaledToFit()
                                .frame(height: 104)
                            Text(companion.displayName)
                                .font(.system(size: 15, weight: isOn ? .semibold : .regular))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isOn ? Palette.field : .clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isOn ? Palette.ink : Palette.ink.opacity(0.18), lineWidth: isOn ? 2 : 1.5)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(companion.displayName)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            Text("\(selected.displayName): \(selected.blurb)")
                .font(.system(size: 14))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
        }
    }

    private var salahStep: some View {
        @Bindable var prefs = model.prefs
        let name = prefs.userName.trimmingCharacters(in: .whitespaces)
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 6) {
                Image(prefs.companion.assetName(for: .idle))
                    .resizable()
                    .scaledToFit()
                    .frame(height: 108)
                    .padding(.top, 12)
                    .accessibilityHidden(true)
                Text(name.isEmpty ? "Asr is in 5 minutes. Getting up?" : "Asr is in 5 minutes, \(name). Getting up?")
                    .font(.system(size: 15, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: 190, alignment: .leading)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.ink, lineWidth: 1.5))
            }
            .padding(.top, 8)
            .padding(.bottom, 12)
            Text("Prayer reminders")
                .font(.system(size: 24, weight: .bold))
                .padding(.bottom, 6)
            Text("A nudge before each salah, and \(prefs.companion.displayName) prays on your desktop when it\u{2019}s time.")
                .font(.system(size: 15))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 18)
            FieldBox {
                SwitchRow(title: "Remind me about salah", isOn: $prefs.salahReminders)
                    .onChange(of: prefs.salahReminders) { _, _ in prefs.save() }
                if prefs.salahReminders {
                    RowLine()
                    SalahLocationSection()
                        .padding(14)
                }
            }
            Text("macOS will ask to send notifications, and to use your location if you chose that. You can change all of this in Settings.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
        }
    }
}

struct CompanionVisibilityNotice: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.prefs.isHiddenNow {
            HStack(spacing: 10) {
                Image(systemName: "eye.slash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.ember)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Companion hidden")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text("Bring them back whenever you want.")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.inkSoft)
                }

                Spacer(minLength: 4)

                Button("Show companion") {
                    model.prefs.unhide()
                }
                .buttonStyle(InkButtonStyle())
                .accessibilityLabel("Show companion")
            }
            .padding(12)
            .background(Palette.cream, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Palette.ink.opacity(0.15), lineWidth: 1)
            )
        }
    }
}

struct InkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(Palette.ink, in: Capsule())
            .foregroundStyle(Palette.cream)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
