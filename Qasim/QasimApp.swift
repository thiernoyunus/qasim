import SwiftUI

@main
struct QasimApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(delegate.model)
                .environment(delegate.updater)
        } label: {
            MenuBarGlyph()
                .environment(delegate.model)
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    let updater = UpdaterController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.start()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        model.openSetup()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if model.session.phase == .running || model.session.phase == .paused {
            model.stopSession(finished: false)
        }
        model.shutdown()
    }
}

struct MenuBarGlyph: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.breakState == .running {
            Text(model.breakRemainingLabel)
                .monospacedDigit()
        } else if model.session.phase == .running {
            Text(model.session.remainingLabel)
                .monospacedDigit()
        } else {
            Image(systemName: "flame.fill")
        }
    }
}
