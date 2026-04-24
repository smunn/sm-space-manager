//
//  WorkspaceConfig.swift
//  SpaceManager
//

import Foundation

struct WorkspaceEntry {
    let key: String
    let displayName: String
}

enum WorkspaceConfig {
    private static let configPath = NSString(
        string: "~/Sites/sm-mac-configuration-scripts/config/workspaces.json"
    ).expandingTildeInPath

    static func loadWorkspaces() -> [WorkspaceEntry] {
        let url = URL(fileURLWithPath: configPath)
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let workspaces = json["workspaces"] as? [String: [String: Any]]
        else { return [] }

        return workspaces.compactMap { key, value in
            guard value["prompt"] == nil else { return nil }
            let displayName = value["displayName"] as? String ?? key
            return WorkspaceEntry(key: key, displayName: displayName)
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}
