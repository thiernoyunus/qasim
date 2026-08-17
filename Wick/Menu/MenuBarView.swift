import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(UpdaterController.self) private var updater

    var body: some View {
        if model.breakState == .running {
            Text("Break · (model.breakRemainingLabel)")
            Button("Skip break") { model.skipBreak() }
        } else if model.breakState == .choice {
            Text("Nice work. Break?")
            Button("Take a break") { model.startBreak() }
            Button("Skip break") { model.skipBreak() }
        } else if model.breakState == .repeatChoice {
            Text("Repeat session?")
            Button("Yes") { model.repeatSession() }
            Button("No") { model.declineRepeat() }
        } else if model.session.phase == .running || model.session.phase == .paused {
            Text(model.session.taskTitle.isEmpty ? "Focusing" : model.session.taskTitle)
            Text(model.session.phase == .paused ? "Paused · \(model.session.remainingLabel)" : model.session.remainingLabel)
            if !model.session.isOnTask {
                Text("Distracted · \(model.session.monitor.context.appName)")
            }
            Divider()
            if model.session.phase == .paused {
                Button("Resume") { model.session.resume() }
            } else {
                Button("Pause") { model.session.pause() }
            }
            Button("I'm done") { model.stopSession(finished: true) }
            Button("Give up") { model.stopSession(finished: false) }
            if let toggle = model.currentQuickToggleTitle() {
                Button(toggle) { model.quickToggleCurrentApp() }
            }
        } else if model.session.phase == .finished {
            Text("Session finished")
            Button("Start another") { model.openSetup() }
        } else {
            Button("New focus session") { model.openSetup() }
        }

        if model.prefs.isHiddenNow {
            Button("Show companion") { model.prefs.unhide() }
        } else {
            Button("Hide for 15 minutes") { model.prefs.hide(for: 15 * 60) }
        }
        Divider()
        Button("Customize…") { model.openSettings() }
        Button("Progress") { model.openProgress() }
        Button("Check for Updates…") { updater.checkForUpdates() }
            .disabled(!updater.canCheckForUpdates)
        Button(model.isPreviewing ? "Stop preview" : "Preview lights + fire (⌥⇧L)") {
            model.togglePreview()
        }
        if model.session.phase == .running {
            Button(model.session.forceDistracted ? "Stop pretending" : "Pretend I'm distracted") {
                model.session.forceDistracted.toggle()
            }
        }
        Divider()
        Button("Quit Wick") {
            if model.session.phase == .running || model.session.phase == .paused {
                model.stopSession(finished: false)
            }
            NSApplication.shared.terminate(nil)
        }
    }
}
