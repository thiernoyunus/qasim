import SwiftUI

@Observable
@MainActor
final class TimerChipState {
    var remaining = ""
    var angry = false
    var task = ""
    var paused = false
    var expanded = false
    var quickToggleTitle: String?

    func update(
        remaining: String,
        angry: Bool,
        task: String,
        paused: Bool,
        expanded: Bool,
        quickToggleTitle: String?
    ) {
        if self.remaining != remaining { self.remaining = remaining }
        if self.angry != angry { self.angry = angry }
        if self.task != task { self.task = task }
        if self.paused != paused { self.paused = paused }
        if self.expanded != expanded { self.expanded = expanded }
        if self.quickToggleTitle != quickToggleTitle { self.quickToggleTitle = quickToggleTitle }
    }
}

struct TimerChipView: View {
    var state: TimerChipState
    var size: CGSize?
    var onToggleExpanded: (() -> Void)?
    var onTogglePause: (() -> Void)?
    var onEdit: (() -> Void)?
    var onStop: (() -> Void)?
    var onFinish: (() -> Void)?
    var onResizeChanged: ((CGSize) -> Void)?
    var onResizeEnded: (() -> Void)?
    var onQuickToggle: (() -> Void)?
    var onSnooze: (() -> Void)?

    private var remaining: String { state.remaining }
    private var angry: Bool { state.angry }
    private var task: String { state.task }
    private var paused: Bool { state.paused }
    private var expanded: Bool { state.expanded }
    private var quickToggleTitle: String? { state.quickToggleTitle }

    @State private var isHovering = false
    @State private var showingEndChoice = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerBar
            screen
            if expanded { controlsRow }
        }
        .padding(9)
        // Fill whatever size the hosting NSPanel gives us, instead of locking to a
        // fixed frame. The host panel resizes via setFrame (cheap) without rebuilding
        // the SwiftUI tree, which is what was making drag-resize feel sluggish.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .fill(Palette.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .stroke(Palette.ink, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.22), radius: 8, y: 4)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .popover(isPresented: $showingEndChoice, arrowEdge: .trailing) {
            EndSessionChoiceView(
                onFinish: finishFromChoice,
                onStop: stopFromChoice,
                onCancel: cancelEndChoice
            )
        }
        .overlay(alignment: .bottomTrailing) {
            if onResizeChanged != nil {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Palette.ink.opacity(0.35))
                    .padding(6)
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 2)
                            .onChanged { value in onResizeChanged?(value.translation) }
                            .onEnded { _ in onResizeEnded?() }
                    )
                    .accessibilityLabel("Resize timer")
            }
        }
    }

    // Header mimics a little sticky-note window chrome: a close button, a dotted
    // "drag me" rule (the whole card is draggable, this just signals it), and an
    // edit toggle — instead of the old solid-color status bar.
    private var headerBar: some View {
        HStack(spacing: 8) {
            Button {
                requestEnd()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("End session")

            DottedRule()
                .stroke(Palette.ink.opacity(0.7), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.5, 8]))
                .frame(height: 2)

            if paused {
                Text("PAUSED")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Palette.ink.opacity(0.55))
                    .fixedSize()
            }

            Button {
                onToggleExpanded?()
            } label: {
                Image(systemName: expanded ? "chevron.up" : "pencil")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(expanded ? "Hide timer controls" : "Show timer controls")
        }
    }

    // The "screen": a black inset panel that holds the time, echoing a little
    // desk-clock display set into the cream card.
    private var screen: some View {
        // Hovering swaps the digital-clock face for quick actions, same trick
        // as the reference chip: no extra chrome, the card just reveals more.
        let showingHover = isHovering && !expanded
        return ZStack {
            timeDisplay.opacity(showingHover ? 0 : 1)
            hoverActions.opacity(showingHover ? 1 : 0)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(showingHover ? Color.clear : (angry ? Palette.ember : Palette.soot))
        )
    }

    private var timeDisplay: some View {
        VStack(spacing: 4) {
            Text(angry ? "FOCUS!" : remaining)
                .font(.system(size: 48, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.cream)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if !task.isEmpty && !angry {
                Text(task)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.cream.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    // Quick-action row shown on hover: block/allow whatever app is currently
    // stealing focus, plus stop and a 2-minute "leave me alone" snooze.
    private var hoverActions: some View {
        VStack(spacing: 6) {
            if let quickToggleTitle {
                Button {
                    onQuickToggle?()
                } label: {
                    Text(quickToggleTitle.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.cream)
                .background(Capsule().fill(Palette.ink))
            }
            HStack(spacing: 8) {
                hoverPill(icon: "stop.fill", text: nil, label: "End session", action: requestEnd)
                hoverPill(icon: nil, text: "ZZ", label: "Snooze for 2 minutes", action: onSnooze)
            }
        }
    }

    private func hoverPill(icon: String?, text: String?, label: String, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            Group {
                if let icon {
                    Image(systemName: icon).font(.system(size: 13, weight: .bold))
                } else if let text {
                    Text(text).font(.system(size: 12, weight: .bold))
                }
            }
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, minHeight: 28)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Palette.ink, lineWidth: 1.5)
        )
        .accessibilityLabel(label)
    }

    private var controlsRow: some View {
        HStack(spacing: 16) {
            Spacer()
            iconButton(icon: paused ? "play.fill" : "pause.fill", label: paused ? "Resume session" : "Pause session", action: onTogglePause)
            iconButton(icon: "pencil", label: "Edit session", action: onEdit)
            iconButton(icon: "stop.fill", label: "End session", action: requestEnd)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func iconButton(icon: String, label: String, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Palette.ink.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func requestEnd() {
        showingEndChoice = true
    }

    private func finishFromChoice() {
        showingEndChoice = false
        onFinish?()
    }

    private func stopFromChoice() {
        showingEndChoice = false
        onStop?()
    }

    private func cancelEndChoice() {
        showingEndChoice = false
    }
}

private struct EndSessionChoiceView: View {
    var onFinish: () -> Void
    var onStop: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("End this session?")
                .font(Typeface.display(17, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Text("Choose how it should appear in your stats.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.inkSoft)

            VStack(spacing: 6) {
                choiceButton(
                    title: "I'm done",
                    detail: "Counts as completed",
                    filled: true,
                    action: onFinish
                )
                choiceButton(
                    title: "Give up",
                    detail: "Saves time as unfinished",
                    destructive: true,
                    action: onStop
                )
                choiceButton(
                    title: "Keep focusing",
                    detail: "No session record yet",
                    action: onCancel
                )
            }
        }
        .padding(14)
        .frame(width: 236)
        .background(Palette.paper)
        .preferredColorScheme(.light)
    }

    private func choiceButton(
        title: String,
        detail: String,
        filled: Bool = false,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                Text(detail)
                    .font(.system(size: 10, weight: .medium))
                    .opacity(filled ? 0.78 : 0.65)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .buttonStyle(EndChoiceButtonStyle(filled: filled, destructive: destructive))
    }
}

private struct EndChoiceButtonStyle: ButtonStyle {
    var filled: Bool
    var destructive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(filled ? Palette.cream : destructive ? Palette.ember : Palette.ink)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(filled ? Palette.ink : destructive ? Palette.ember.opacity(0.10) : Palette.cream)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        filled ? Color.clear : destructive ? Palette.ember.opacity(0.45) : Palette.ink.opacity(0.25),
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

/// A single horizontal dotted rule, used as decorative "drag handle" chrome
/// in the header — the whole card is already draggable via the gesture above.
private struct DottedRule: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
