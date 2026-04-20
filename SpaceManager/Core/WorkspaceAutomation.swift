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
        displayGroupIndex: Int = 1,
        completion: @escaping (Bool) -> Void
    ) {
        SpaceCloser.addSpaceAndSwitch(toDesktopNumber: targetDesktopNumber, displayGroupIndex: displayGroupIndex) { success in
            guard success else {
                completion(false)
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                openTerminalWindow(completion: completion)
            }
        }
    }

    private static func openTerminalWindow(completion: @escaping (Bool) -> Void) {
        let script = """
        tell application "Terminal"
          activate
          do script ""
        end tell
        """

        DispatchQueue.global(qos: .userInitiated).async {
            let appleScript = NSAppleScript(source: script)
            var error: NSDictionary?
            appleScript?.executeAndReturnError(&error)
            if let error {
                NSLog("WorkspaceAutomation Terminal AppleScript failed: \(error)")
            }
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
    }
}
