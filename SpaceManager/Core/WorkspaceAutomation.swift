//
//  WorkspaceAutomation.swift
//  SpaceManager
//
//  Higher-level space automation built on the same Mission Control accessibility
//  actions as SpaceCloser. macOS has no public API to create a named desktop or
//  assign an app to it directly, so templates have to compose UI automation:
//  create a desktop, switch to it, then launch the desired app/window.
//

import Cocoa

enum WorkspaceAutomation {
    static func createTerminalSpace(
        targetDesktopNumber: Int,
        spaceSwitcher: SpaceSwitcher,
        completion: @escaping (Bool) -> Void
    ) {
        SpaceCloser.addSpace { success in
            guard success else {
                completion(false)
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                spaceSwitcher.switchViaMissionControl(desktopNumber: targetDesktopNumber)

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    openTerminal(completion: completion)
                }
            }
        }
    }

    private static func openTerminal(completion: @escaping (Bool) -> Void) {
        guard let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
            completion(false)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: terminalURL, configuration: configuration) { _, error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
    }
}
