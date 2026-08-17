import AppKit
import SwiftUI

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class TimerOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class FlippedContainer: NSView {
    override var isFlipped: Bool { true }
}

enum OverlayChrome {
    static func panel(on screen: NSScreen, clickable: Bool) -> OverlayPanel {
        let panel = OverlayPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = clickable
            ? NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
            : NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.ignoresMouseEvents = !clickable
        panel.isReleasedWhenClosed = false
        panel.setFrame(screen.frame, display: true)
        return panel
    }
}
