//
//  LaunchAtLoginManager.swift
//  SpaceManager
//
//  Manages a LaunchAgent plist in ~/Library/LaunchAgents to open
//  the app at login. Uses launchd directly instead of SMAppService,
//  which requires a provisioning profile that free Apple Developer
//  accounts don't provide for macOS.
//

import AppKit
import Combine

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    @Published private(set) var isEnabled: Bool = false
    @Published var errorMessage: String?

    var canToggle: Bool { true }

    var needsApproval: Bool { false }

    var statusText: String {
        isEnabled ? "Enabled" : "Off"
    }

    private static let plistURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.smunn.SpaceManager.plist")
    }()

    init() {
        refresh()
    }

    func refresh() {
        isEnabled = FileManager.default.fileExists(atPath: Self.plistURL.path)
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled {
                try writePlist()
            } else {
                try removePlist()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    private func writePlist() throws {
        let dir = Self.plistURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let executablePath = Bundle.main.executablePath
            ?? "/Applications/Space Manager.app/Contents/MacOS/Space Manager"

        let plist: [String: Any] = [
            "Label": "com.smunn.SpaceManager",
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
        ]

        let data = try PropertyListSerialization.data(
            fromPropertyList: plist, format: .xml, options: 0
        )
        try data.write(to: Self.plistURL, options: .atomic)
    }

    private func removePlist() throws {
        guard FileManager.default.fileExists(atPath: Self.plistURL.path) else { return }
        try FileManager.default.removeItem(at: Self.plistURL)
    }
}
