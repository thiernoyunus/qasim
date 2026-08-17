import SwiftUI

struct TimerChipView: View {
    var remaining: String
    var angry: Bool
    var task: String
    var size: CGSize?
    var paused = false
    var expanded = false
    var onToggleExpanded: (() -> Void)?
    var onTogglePause: (() -> Void)?
    var onEdit: (() -> Void)?
    var onStop: (() -> Void)?
    var onDragChanged: ((CGSize) -> Void)?
    var onDragEnded: (() -> Void)?
    var onResizeChanged: ((CGSize) -> Void)?
    var onResizeEnded: (() -> Void)?
    var quickToggleTitle: String?
    var onQuickToggle: (() -> Void)?

    var body: some View {
        let panelSize = size ?? CGSize(width: expanded ? 220 : 160, height: expanded ? 170 : 110)

        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Circle().fill(angry ? Palette.ember : Palette.paperDeep).frame(width: 6, height: 6)
                Text(paused ? "PAUSED" : "FOCUS")
                    .font(.system(size: 9, weight: .semibold))
                Spacer()
                Button {
                    onToggleExpanded?()
                } label: {
                    Image(systemName: expanded ? "chevron.down" : "pencil")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(expanded ? "Hide timer controls" : "Show timer controls")
            }
            .foregroundStyle(angry ? Palette.cream : Palette.paper)

            Text(angry ? "FOCUS!" : remaining)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.cream)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 2)

            if !task.isEmpty && !angry {
                Text(task)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Palette.cream.opacity(0.7))
                    .lineLimit(1)
            }

            if expanded {
                HStack(spacing: 5) {
                    actionButton(
                        icon: paused ? "play.fill" : "pause.fill",
                        title: paused ? "Resume" : "Pause",
                        action: onTogglePause
                    )
                    actionButton(icon: "pencil", title: "Edit", action: onEdit)
                    actionButton(icon: "stop.fill", title: "Stop", action: onStop)
                    if let quickToggleTitle {
                        let isBlock = quickToggleTitle.hasPrefix("Block")
                        actionButton(
                            icon: isBlock ? "xmark.shield" : "checkmark.shield",
                            title: quickToggleTitle,
                            action: onQuickToggle
                        )
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(10)
        .frame(width: panelSize.width, height: panelSize.height, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(angry ? Palette.ember : Palette.soot)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(angry ? Palette.ink : Palette.cream.opacity(0.18), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.28), radius: 10, y: 6)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in onDragChanged?(value.translation) }
                .onEnded { _ in onDragEnded?() }
        )
        .overlay(alignment: .bottomTrailing) {
            if onResizeChanged != nil {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Palette.cream.opacity(0.55))
                    .padding(5)
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

    private func actionButton(
        icon: String,
        title: String,
        action: (() -> Void)?
    ) -> some View {
        Button {
            action?()
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Palette.cream.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.cream)
        .accessibilityLabel(title)
    }
}
