import AppKit
import SwiftUI

struct SetupView: View {
    @Environment(AppModel.self) private var model
    @State private var step: Int = 0

    private let totalSteps = 3

    var body: some View {
        @Bindable var session = model.session
        @Bindable var prefs = model.prefs

        VStack(spacing: 0) {
            header
            stepDots
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    CompanionVisibilityNotice()

                    switch step {
                    case 0: nameStep(prefs: prefs)
                    case 1: CharacterPickerStrip()
                    default: actionsStep()
                    }
                }
                .padding(22)
            }
            footer()
        }
        .background(Palette.paper)
        .foregroundStyle(Palette.ink)
        .preferredColorScheme(.light)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(model.prefs.companion.assetName(for: .idle))
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.prefs.companion.displayName)
                    .font(Typeface.display(28))
                    .foregroundStyle(Palette.ink)
                Text("One thing. Or the lights go out.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer()
            Button("Customize") {
                model.openSettings()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Palette.inkSoft)
            .accessibilityLabel("Customize")
            Button(model.isPreviewing ? "Stop preview" : "Preview") {
                model.togglePreview()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Palette.ember)
            .accessibilityLabel(model.isPreviewing ? "Stop preview" : "Preview")
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private var stepDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i == step ? Palette.ember : Palette.ink.opacity(0.15))
                    .frame(width: i == step ? 22 : 8, height: 8)
            }
        }
        .padding(.bottom, 4)
    }

    private func nameStep(prefs: Preferences) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What's your name?")
                .font(Typeface.display(22))
                .foregroundStyle(Palette.ink)
            Text("So they know who they're sitting with.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.inkSoft)
            TextField("Your name", text: Bindable(model.prefs).userName)
                .textFieldStyle(.plain)
                .font(Typeface.display(20))
                .padding(14)
                .background(Palette.cream, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Palette.ink, lineWidth: 2)
                )
        }
    }

    private func actionsStep() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What can they do?")
                .font(Typeface.display(22))
                .foregroundStyle(Palette.ink)
            ActionsCustomizeSection()
        }
    }

    private func footer() -> some View {
        HStack {
            if step > 0 {
                Button("Back") { step -= 1 }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.inkSoft)
                    .accessibilityLabel("Back")
            }
            Spacer()
            // Onboarding is just name -> character -> actions. Done finishes
            // onboarding and hands off to the regular new-session UI.
            if step < 2 {
                Button("Next") { step += 1 }
                    .buttonStyle(InkButtonStyle())
                    .accessibilityLabel("Next")
            } else {
                Button("Done") {
                    model.prefs.hasCompletedSetup = true
                    model.prefs.save()
                    model.openSetup()
                }
                .buttonStyle(InkButtonStyle())
                .accessibilityLabel("Done")
            }
        }
        .padding(18)
        .background(Palette.paperDeep.opacity(0.5))
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

struct FlowWrap<Item: Identifiable, Content: View>: View {
    var items: [Item]
    @ViewBuilder var content: (Item) -> Content

    var body: some View {
        FlexibleStack {
            ForEach(items) { item in
                content(item)
            }
        }
    }
}

/// Simple wrapping HStack for a handful of chips.
struct FlexibleStack<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            content
        }
    }
}
