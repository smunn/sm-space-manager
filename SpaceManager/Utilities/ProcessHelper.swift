//
//  ProcessHelper.swift
//  SpaceManager
//
//  Queries process tree to find terminal shell CWDs. Results are cached
//  and resolved on a background queue to avoid blocking the main thread.
//

import Foundation

final class ProcessHelper {
    static let shared = ProcessHelper()

    private let queue = DispatchQueue(label: "com.smunn.SpaceManager.ProcessHelper")
    private var cwdCache: [pid_t: String] = [:]
    private let cacheLock = NSLock()

    func cachedProjectName(terminalPID: pid_t) -> String? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        guard let cwd = cwdCache[terminalPID] else { return nil }
        let name = (cwd as NSString).lastPathComponent
        return name.isEmpty ? nil : name
    }

    func resolveTerminalCWDs(pids: [pid_t], completion: @escaping () -> Void) {
        let uncached: [pid_t]
        cacheLock.lock()
        uncached = pids.filter { cwdCache[$0] == nil }
        cacheLock.unlock()

        if uncached.isEmpty {
            completion()
            return
        }

        queue.async { [weak self] in
            guard let self else { return }
            for pid in uncached {
                if let cwd = Self.resolveTerminalCWD(terminalPID: pid) {
                    self.cacheLock.lock()
                    self.cwdCache[pid] = cwd
                    self.cacheLock.unlock()
                }
            }
            DispatchQueue.main.async { completion() }
        }
    }

    func invalidateCache() {
        cacheLock.lock()
        cwdCache.removeAll()
        cacheLock.unlock()
    }

    private static func resolveTerminalCWD(terminalPID: pid_t) -> String? {
        let children = childPIDs(of: terminalPID)
        let home = NSHomeDirectory()
        for pid in children {
            guard let cwd = processCWD(pid: pid) else { continue }
            if cwd != "/" && cwd != home { return cwd }
        }
        return nil
    }

    private static func childPIDs(of parent: pid_t) -> [pid_t] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-P", String(parent)]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
        } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return output.split(separator: "\n").compactMap { pid_t(String($0)) }
    }

    private static func processCWD(pid: pid_t) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-a", "-d", "cwd", "-p", String(pid), "-Fn"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
        } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        for line in output.split(separator: "\n") {
            if line.hasPrefix("n/") {
                return String(line.dropFirst())
            }
        }
        return nil
    }
}
