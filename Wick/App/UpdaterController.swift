import Sparkle
import Observation

/// Thin wrapper so the rest of the app doesn't touch Sparkle directly.
/// `SPUStandardUpdaterController` starts the updater on init and handles
/// its own scheduled background checks (see SUEnableAutomaticChecks in Info.plist).
@Observable
@MainActor
final class UpdaterController {
    private let controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    var canCheckForUpdates: Bool { controller.updater.canCheckForUpdates }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
