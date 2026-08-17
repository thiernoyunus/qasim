import AppKit
import CoreGraphics

struct FrontContext: Equatable {
    var bundleID: String
    var appName: String
    var host: String?
    var windowFrame: CGRect
}

@Observable
@MainActor
final class DistractionMonitor {
    private(set) var context = FrontContext(
        bundleID: "",
        appName: "",
        host: nil,
        windowFrame: .zero
    )

    private var lastBrowserCheck: Date = .distantPast
    private var lastHost: String?
    private var lastPoll: Date = .distantPast

    func poll() {
        // ponytail: poll focus context at 8 Hz; per-frame window scans make drag less responsive.
        let now = Date()
        guard now.timeIntervalSince(lastPoll) >= 0.12 else { return }
        lastPoll = now

        let app = NSWorkspace.shared.frontmostApplication
        let bundleID = app?.bundleIdentifier ?? ""
        let name = app?.localizedName ?? "Something"
        var host = lastHost

        if let kind = BrowserKind.identify(bundleID) {
            _ = kind
            if now.timeIntervalSince(lastBrowserCheck) > 1.2 {
                lastBrowserCheck = now
                lastHost = BrowserInspector.currentHost(bundleID: bundleID)
                host = lastHost
            }
        } else {
            lastHost = nil
            host = nil
        }

        let frame = Self.frontWindowFrame(excluding: WickIdentity.bundleID) ?? .zero
        context = FrontContext(bundleID: bundleID, appName: name, host: host, windowFrame: frame)
    }

    func isOnTask(
        strategy: FocusStrategy,
        allowedApps: Set<String>,
        blockedApps: Set<String>,
        allowedSites: [SiteRule],
        blockedSites: [SiteRule]
    ) -> Bool {
        let bundleID = context.bundleID
        if bundleID.isEmpty { return true }
        if WickIdentity.alwaysAllowed.contains(bundleID) { return true }
        if bundleID == WickIdentity.bundleID { return true }

        switch strategy {
        case .company:
            return true
        case .allow:
            if let host = context.host, !allowedSites.isEmpty {
                if allowedSites.contains(where: { $0.matches(host) }) { return true }
                // Allowed site list is in play — being on some other page is off-task,
                // even if the browser itself is on the allow list.
                return false
            }
            return allowedApps.contains(bundleID)
        case .block:
            if let host = context.host, blockedSites.contains(where: { $0.matches(host) }) {
                return false
            }
            return !blockedApps.contains(bundleID)
        }
    }

    static func frontWindowFrame(excluding bundleID: String) -> CGRect? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        let screenHeight = NSScreen.screens.map(\.frame.maxY).max() ?? 0

        for window in info {
            let owner = window[kCGWindowOwnerName as String] as? String ?? ""
            if owner == "Wick" || owner == "Window Server" { continue }
            let layer = window[kCGWindowLayer as String] as? Int ?? 0
            if layer != 0 { continue }
            let alpha = window[kCGWindowAlpha as String] as? CGFloat ?? 1
            if alpha < 0.05 { continue }
            guard let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let x = bounds["X"] ?? 0
            let y = bounds["Y"] ?? 0
            let w = bounds["Width"] ?? 0
            let h = bounds["Height"] ?? 0
            if w < 80 || h < 80 { continue }
            // CG window bounds are top-left global. Convert to AppKit bottom-left.
            let appKitY = screenHeight - (y + h)
            return CGRect(x: x, y: appKitY, width: w, height: h)
        }
        return nil
    }
}
