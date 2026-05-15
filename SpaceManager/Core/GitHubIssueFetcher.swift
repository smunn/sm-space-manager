//
//  GitHubIssueFetcher.swift
//  SpaceManager
//

import Foundation

class GitHubIssueFetcher {
    static let shared = GitHubIssueFetcher()

    private(set) var issues: [GitHubIssue] = []
    private(set) var isFetching = false
    private(set) var lastError: String?
    private var lastFetchTime: Date?
    private var refreshTimer: Timer?
    private let minInterval: TimeInterval = 300

    var isStale: Bool {
        guard let last = lastFetchTime else { return true }
        return Date().timeIntervalSince(last) >= minInterval
    }

    var hasFetched: Bool { lastFetchTime != nil }

    func startPeriodicRefresh() {
        fetch()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: minInterval, repeats: true) { [weak self] _ in
            self?.fetch()
        }
    }

    func refreshIfNeeded(completion: (() -> Void)? = nil) {
        guard isStale, !isFetching else {
            completion?()
            return
        }
        fetch(completion: completion)
    }

    func fetch(completion: (() -> Void)? = nil) {
        guard !isFetching else {
            completion?()
            return
        }
        isFetching = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let (result, error) = Self.runSearch()
            DispatchQueue.main.async {
                self?.issues = result ?? self?.issues ?? []
                self?.lastError = error
                self?.lastFetchTime = Date()
                self?.isFetching = false
                completion?()
            }
        }
    }

    // MARK: - Project Path Resolution

    static func localProjectPath(for repoName: String, repoFullName: String) -> String? {
        let sitesPath = NSString(string: "~/Sites").expandingTildeInPath
        let fm = FileManager.default

        // Direct name match
        let directPath = (sitesPath as NSString).appendingPathComponent(repoName)
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: directPath, isDirectory: &isDir), isDir.boolValue {
            return directPath
        }

        // Scan ~/Sites for a git repo whose remote matches
        guard let entries = try? fm.contentsOfDirectory(atPath: sitesPath) else { return nil }
        for entry in entries where !entry.hasPrefix(".") {
            let entryPath = (sitesPath as NSString).appendingPathComponent(entry)
            if hasGitRemote(at: entryPath, matching: repoFullName) {
                return entryPath
            }

            // One level deeper for container directories (_clients/, etc.)
            let gitPath = (entryPath as NSString).appendingPathComponent(".git")
            if !fm.fileExists(atPath: gitPath) {
                guard let subEntries = try? fm.contentsOfDirectory(atPath: entryPath) else { continue }
                for subEntry in subEntries where !subEntry.hasPrefix(".") {
                    let subPath = (entryPath as NSString).appendingPathComponent(subEntry)
                    if hasGitRemote(at: subPath, matching: repoFullName) {
                        return subPath
                    }
                }
            }
        }

        return nil
    }

    private static func hasGitRemote(at path: String, matching repoFullName: String) -> Bool {
        let gitConfigPath = (path as NSString).appendingPathComponent(".git/config")
        guard let config = try? String(contentsOfFile: gitConfigPath, encoding: .utf8) else { return false }
        return config.contains(repoFullName)
    }

    // MARK: - gh CLI

    private static func runSearch() -> ([GitHubIssue]?, String?) {
        let command = "gh search issues --author=@me --state=open --json repository,title,number,url,labels,updatedAt --sort updated -L 30"

        let process = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", command]
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (nil, "Failed to run gh: \(error.localizedDescription)")
        }

        guard process.terminationStatus == 0 else {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errString = String(data: errData, encoding: .utf8) ?? "exit \(process.terminationStatus)"
            NSLog("GitHubIssueFetcher: gh failed: %@", errString)
            return (nil, "gh exited with status \(process.terminationStatus)")
        }

        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        guard !data.isEmpty else { return ([], nil) }

        do {
            let issues = try JSONDecoder().decode([GitHubIssue].self, from: data)
            return (issues, nil)
        } catch {
            NSLog("GitHubIssueFetcher: JSON decode failed: %@", error.localizedDescription)
            return (nil, "Failed to parse issues")
        }
    }
}
