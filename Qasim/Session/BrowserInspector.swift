import AppKit
import Foundation

enum BrowserKind: String {
    case safari = "com.apple.Safari"
    case chrome = "com.google.Chrome"
    case brave = "com.brave.Browser"
    case arc = "company.thebrowser.Browser"
    case edge = "com.microsoft.edgemac"
    case dia = "company.thebrowser.dia"
    case orion = "com.kagi.kagimacOS"

    static func identify(_ bundleID: String) -> BrowserKind? {
        BrowserKind(rawValue: bundleID)
    }

    var script: String {
        switch self {
        case .safari:
            """
            tell application "Safari"
                if (count of windows) is 0 then return ""
                return URL of current tab of front window
            end tell
            """
        case .chrome:
            """
            tell application "Google Chrome"
                if (count of windows) is 0 then return ""
                return URL of active tab of front window
            end tell
            """
        case .brave:
            """
            tell application "Brave Browser"
                if (count of windows) is 0 then return ""
                return URL of active tab of front window
            end tell
            """
        case .arc:
            """
            tell application "Arc"
                if (count of windows) is 0 then return ""
                return URL of active tab of front window
            end tell
            """
        case .edge:
            """
            tell application "Microsoft Edge"
                if (count of windows) is 0 then return ""
                return URL of active tab of front window
            end tell
            """
        case .dia:
            """
            tell application "Dia"
                if (count of windows) is 0 then return ""
                return URL of active tab of front window
            end tell
            """
        case .orion:
            """
            tell application "Orion"
                if (count of windows) is 0 then return ""
                return URL of current tab of front window
            end tell
            """
        }
    }
}

enum BrowserInspector {
    /// The front tab's site and its path + query (for single-page rules).
    static func currentPage(bundleID: String) -> (host: String, path: String)? {
        guard let kind = BrowserKind.identify(bundleID) else { return nil }
        guard let urlString = run(kind.script), !urlString.isEmpty else { return nil }
        return page(from: urlString)
    }

    static func page(from urlString: String) -> (host: String, path: String)? {
        guard let host = host(from: urlString) else { return nil }
        let raw = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = URLComponents(string: raw.contains("://") ? raw : "https://\(raw)")
        var path = parts?.percentEncodedPath ?? ""
        if let query = parts?.percentEncodedQuery { path += "?" + query }
        return (host, path)
    }

    static func host(from urlString: String) -> String? {
        let value = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if let url = URL(string: value), let scheme = url.scheme {
            guard scheme.lowercased() == "http" || scheme.lowercased() == "https",
                  let host = url.host else { return nil }
            return SiteRule.normalize(host)
        }
        return SiteRule.normalize(value)
    }

    static func selfCheck() {
        assert(host(from: "https://www.example.com/path") == "example.com")
        assert(host(from: "about:blank") == nil)
        assert(host(from: "chrome://newtab/") == nil)
        assert(page(from: "https://www.youtube.com/watch?v=abc#t")?.path == "/watch?v=abc")
        assert(page(from: "youtube.com/watch?v=abc")?.path == "/watch?v=abc")
    }

    private static func run(_ source: String) -> String? {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        let result = script?.executeAndReturnError(&error)
        if error != nil { return nil }
        return result?.stringValue
    }
}
