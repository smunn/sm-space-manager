//
//  WorkspaceLauncher.swift
//  SpaceManager
//

import Foundation

enum WorkspaceLauncher {
    private static let scriptPath = NSString(
        string: "~/Sites/sm-mac-configuration-scripts/bin/launch-work.js"
    ).expandingTildeInPath

    static func launch(_ workspaceKey: String) {
        let escaped = workspaceKey.replacingOccurrences(of: "'", with: "'\\''")
        let command = "node '\(scriptPath)' '\(escaped)' --from-app"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", command]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
            } catch {
                NSLog("WorkspaceLauncher: failed to launch '%@': %@", workspaceKey, error.localizedDescription)
            }
        }
    }
}
