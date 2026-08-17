import AppKit

@Observable
@MainActor
final class InstalledAppCatalog {
    private(set) var apps: [AppIdentity] = []
    private(set) var isLoading = false

    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            let scanned = await Task.detached(priority: .utility) {
                InstalledAppCatalog.scan()
            }.value
            apps = scanned
            isLoading = false
        }
    }

    func search(_ query: String) -> [AppIdentity] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return apps }
        return apps.filter { $0.name.lowercased().contains(q) || $0.bundleID.lowercased().contains(q) }
    }

    func icon(for app: AppIdentity) -> NSImage {
        NSWorkspace.shared.icon(forFile: app.path)
    }

    nonisolated static func scan() -> [AppIdentity] {
        let fm = FileManager.default
        var roots = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]
        if let local = fm.urls(for: .applicationDirectory, in: .localDomainMask).first {
            roots.append(local)
        }

        var seen = Set<String>()
        var result: [AppIdentity] = []

        for root in roots {
            guard let items = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in items where url.pathExtension == "app" {
                let bundle = Bundle(url: url)
                let bundleID = bundle?.bundleIdentifier ?? ""
                let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                let key = bundleID.isEmpty ? url.path : bundleID
                if seen.contains(key) { continue }
                if name == "Wick" { continue }
                seen.insert(key)
                result.append(AppIdentity(bundleID: bundleID, name: name, path: url.path))
            }
        }

        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
