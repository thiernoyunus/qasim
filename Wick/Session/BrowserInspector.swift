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
    static func currentHost(bundleID: String) -> String? {
        guard let kind = BrowserKind.identify(bundleID) else { return nil }
        guard let urlString = run(kind.script), !urlString.isEmpty else { return nil }
        return host(from: urlString)
    }

    static func host(from urlString: String) -> String? {
        if let url = URL(string: urlString), let host = url.host {
            return SiteRule.normalize(host)
        }
        return SiteRule.normalize(urlString)
    }

    private static func run(_ source: String) -> String? {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        let result = script?.executeAndReturnError(&error)
        if error != nil { return nil }
        return result?.stringValue
    }
}
