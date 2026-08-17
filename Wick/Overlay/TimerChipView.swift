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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            mainTime
            taskLine
            if expanded { controlsRow }
        }
        .padding(14)
        // Fill whatever size the hosting NSPanel gives us, instead of locking to a
        // fixed frame. The host panel resizes via setFrame (cheap) without rebuilding
        // the SwiftUI tree, which is what was making drag-resize feel sluggish.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(angry ? Palette.ember : Palette.soot)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Palette.cream.opacity(0.15), lineWidth: 2)
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
                    .foregroundStyle(Palette.cream.opacity(0.45))
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

    private var headerBar: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(angry ? Palette.ember : Palette.paperDeep)
                .frame(width: 6, height: 6)
            Text(paused ? "PAUSED" : "FOCUS")
                .font(.system(size: 10, weight: .semibold))
            Spacer()
            Button {
                onToggleExpanded?()
            } label: {
                Image(systemName: expanded ? "chevron.up" : "pencil")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.cream)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(expanded ? "Hide timer controls" : "Show timer controls")
        }
        .foregroundStyle(angry ? Palette.cream : Palette.paper.opacity(0.7))
        .padding(.bottom, 4)
    }

    private var mainTime: some View {
        Text(angry ? "FOCUS!" : remaining)
            .font(.system(size: 56, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Palette.cream)
            .frame(maxWidth: .infinity, alignment: .center)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .padding(.vertical, 4)
    }

    @ViewBuilder
    private var taskLine: some View {
        if !task.isEmpty && !angry {
            Text(task)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.cream.opacity(0.85))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
        }
    }

    private var controlsRow: some View {
        HStack(spacing: 16) {
            Spacer()
            iconButton(icon: paused ? "play.fill" : "pause.fill", action: onTogglePause)
            iconButton(icon: "pencil", action: onEdit)
            iconButton(icon: "stop.fill", action: onStop)
            Spacer()
        }
        .padding(.top, 6)
        .frame(maxWidth: .infinity)
    }

    private func iconButton(icon: String, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Palette.cream)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Palette.cream.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}
