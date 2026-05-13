//
//  WorkspaceStore.swift
//  SpaceManager
//

import Cocoa

struct ManagedWorkspace: Identifiable {
    let key: String
    var displayName: String
    var projectPath: String?
    var isArchived: Bool
    var hasPrompt: Bool

    var id: String { key }
}

final class WorkspaceStore: ObservableObject {
    @Published var workspaces: [ManagedWorkspace] = []

    static let configPath = NSString(
        string: "~/Sites/sm-mac-configuration-scripts/config/workspaces.json"
    ).expandingTildeInPath

    private var fullJSON: [String: Any] = [:]

    init() {
        reload()
    }

    func reload() {
        let url = URL(fileURLWithPath: Self.configPath)
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dict = json["workspaces"] as? [String: [String: Any]]
        else {
            workspaces = []
            return
        }

        fullJSON = json

        workspaces = dict.map { key, value in
            ManagedWorkspace(
                key: key,
                displayName: value["displayName"] as? String ?? key,
                projectPath: value["projectPath"] as? String,
                isArchived: value["archived"] as? Bool ?? false,
                hasPrompt: value["prompt"] != nil
            )
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func setArchived(_ workspace: ManagedWorkspace, archived: Bool) {
        guard var dict = fullJSON["workspaces"] as? [String: [String: Any]],
              var entry = dict[workspace.key]
        else { return }

        if archived {
            entry["archived"] = true
        } else {
            entry.removeValue(forKey: "archived")
        }

        dict[workspace.key] = entry
        fullJSON["workspaces"] = dict
        save()
        reload()
    }

    func remove(_ workspace: ManagedWorkspace) {
        guard var dict = fullJSON["workspaces"] as? [String: [String: Any]] else { return }
        dict.removeValue(forKey: workspace.key)
        fullJSON["workspaces"] = dict
        save()
        reload()
    }

    func add(key: String, displayName: String, projectPath: String?) {
        guard var dict = fullJSON["workspaces"] as? [String: [String: Any]] else { return }
        guard !key.isEmpty, dict[key] == nil else { return }

        var entry: [String: Any] = ["displayName": displayName]
        if let path = projectPath, !path.isEmpty {
            entry["projectPath"] = path
        }

        dict[key] = entry
        fullJSON["workspaces"] = dict
        save()
        reload()
    }

    private static let repoPath = NSString(
        string: "~/Sites/sm-mac-configuration-scripts"
    ).expandingTildeInPath

    private func save() {
        let url = URL(fileURLWithPath: Self.configPath)
        guard let data = try? JSONSerialization.data(
            withJSONObject: fullJSON,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ) else { return }
        try? data.write(to: url, options: [.atomic])
        commitAndPush()
    }

    private func commitAndPush() {
        DispatchQueue.global(qos: .utility).async {
            let pipe = Pipe()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", """
                cd '\(Self.repoPath)' && \
                git add config/workspaces.json && \
                (git diff --cached --quiet || \
                (git commit -m 'Update workspaces config' && \
                git pull --rebase --quiet && \
                git push --quiet))
                """]
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                Self.showSyncError("Failed to run git: \(error.localizedDescription)")
                return
            }

            guard process.terminationStatus == 0 else {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
                Self.showSyncError(output)
                return
            }
        }
    }

    private static func showSyncError(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Workspace Sync Failed"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
