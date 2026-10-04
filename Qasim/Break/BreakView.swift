import SwiftUI

/// The card that appears when a session ends: celebrate, offer a break, run
/// the break timer, then offer to go again.
struct BreakView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    CharacterView(
                        companion: model.prefs.companion,
                        pose: model.breakActivity?.pose ?? .idle,
                        facing: 1,
                        hopLift: 0,
                        breatheScale: 1,
                        pressed: false,
                        size: CGSize(width: 180, height: 194),
                        breakActivity: model.breakState == .running ? model.breakActivity : nil,
                        celebrating: model.breakState == .choice && !model.prefs.motionReduced
                    )
                    .frame(height: 230)
                    .padding(.top, 24)
                    .accessibilityHidden(true)

                    content
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            primaryButton
                .buttonStyle(BarButtonStyle())
                .keyboardShortcut(.defaultAction)
        }
        .background(Palette.ground)
        .foregroundStyle(Palette.ink)
        .preferredColorScheme(.light)
    }

    /// The session that just ended.
    private var lastRecord: SessionRecord? {
        model.progress.sessions(on: Date()).max { $0.date < $1.date }
    }

    @ViewBuilder
    private var content: some View {
        switch model.breakState {
        case .choice:
            let name = model.prefs.userName.trimmingCharacters(in: .whitespaces)
            title(name.isEmpty ? "Nice work." : "Nice work, \(name).")
            if let record = lastRecord {
                subtitle(record.taskTitle.isEmpty
                    ? "Session complete."
                    : "\(minutes(record.focusedSeconds + record.distractedSeconds)) on \u{201C}\(record.taskTitle)\u{201D}.")
                stats(record)
            }
            secondaryRow("Not now") { model.skipBreak() }
        case .running:
            title(model.breakActivity?.title ?? "Break")
            Text(model.breakRemainingLabel)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .accessibilityLabel("Time left: \(model.breakRemainingLabel)")
        case .repeatChoice:
            title("Ready for another?")
            subtitle("Same task, same settings.")
            secondaryRow("Back to home") { model.declineRepeat() }
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch model.breakState {
        case .choice:
            Button("Take a \(model.prefs.breakMinutes)-minute break") { model.startBreak() }
        case .running:
            Button("Skip break") { model.skipBreak() }
        case .repeatChoice:
            Button("Run it again") { model.repeatSession() }
        case .none:
            EmptyView()
        }
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 28, weight: .bold))
            .multilineTextAlignment(.center)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }

    private func subtitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16))
            .foregroundStyle(Palette.muted)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 24)
    }

    private func stats(_ record: SessionRecord) -> some View {
        HStack(spacing: 0) {
            stat(minutes(record.focusedSeconds), "focused")
            Palette.line.frame(width: 1)
            stat(minutes(record.distractedSeconds), "distracted")
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(Palette.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Palette.ink, lineWidth: 1.5))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 26, weight: .bold)).monospacedDigit()
            Text(label).font(.system(size: 13)).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    /// "Not now" / "Back to home" plus a link to analytics.
    private func secondaryRow(_ label: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Button(label, action: action)
                .buttonStyle(OutlineButtonStyle())
            Button("View stats") { model.openProgress(showStats: true) }
                .buttonStyle(.plain)
                .font(.system(size: 15, weight: .semibold))
                .frame(minHeight: 44)
                .padding(.horizontal, 12)
        }
        .padding(.top, 18)
    }

    private func minutes(_ seconds: TimeInterval) -> String {
        let m = Int((seconds / 60).rounded())
        return m < 60 ? "\(m) min" : "\(m / 60)h \(m % 60)m"
    }
}

private struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .overlay(Capsule().stroke(Palette.ink, lineWidth: 1.5))
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
