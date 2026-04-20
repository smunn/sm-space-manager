//
//  AppPermissions.swift
//  SpaceManager
//
//  Centralizes macOS privacy permission checks and System Settings deep links.
//

import Cocoa

enum AppPermission: CaseIterable, Identifiable, Hashable {
    case accessibility
    case automation
    case screenRecording

    var id: String { title }

    var title: String {
        switch self {
        case .accessibility:
            return "Accessibility"
        case .automation:
            return "Automation"
        case .screenRecording:
            return "Screen Recording"
        }
    }

    var purpose: String {
        switch self {
        case .accessibility:
            return "Switching"
        case .automation:
            return "System Events"
        case .screenRecording:
            return "Window names"
        }
    }
}

enum AppPermissions {
    static func check(_ permission: AppPermission) -> Bool {
        switch permission {
        case .accessibility:
            return AXIsProcessTrusted()
        case .automation:
            return checkAutomation()
        case .screenRecording:
            return checkScreenRecording()
        }
    }

    static func openSettings(for permission: AppPermission) {
        switch permission {
        case .accessibility:
            openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .automation:
            // Run a harmless System Events command first so macOS has an app entry to show.
            _ = checkAutomation()
            openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
        case .screenRecording:
            openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        }
    }

    private static func checkAutomation() -> Bool {
        let script = "tell application \"System Events\" to return name of first process"
        guard let scriptObject = NSAppleScript(source: script) else { return false }
        var error: NSDictionary?
        scriptObject.executeAndReturnError(&error)
        return error == nil
    }

    private static func checkScreenRecording() -> Bool {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        for window in windowList {
            let owner = window[kCGWindowOwnerName as String] as? String ?? ""
            if owner == "Finder" || owner == "Google Chrome" || owner == "Terminal" || owner == "Safari" {
                if window[kCGWindowName as String] as? String != nil {
                    return true
                }
            }
        }

        return false
    }

    private static func openSystemSettingsPane(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
