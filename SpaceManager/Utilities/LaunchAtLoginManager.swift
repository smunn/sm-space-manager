//
//  LaunchAtLoginManager.swift
//  SpaceManager
//
//  Wraps SMAppService.mainApp for the Settings UI.
//

import Combine
import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    @Published private(set) var status: SMAppService.Status = SMAppService.mainApp.status
    @Published var errorMessage: String?

    var isEnabled: Bool {
        status == .enabled || status == .requiresApproval
    }

    var canToggle: Bool {
        status != .notFound
    }

    var needsApproval: Bool {
        status == .requiresApproval
    }

    var statusText: String {
        switch status {
        case .enabled:
            return "Enabled"
        case .requiresApproval:
            return "Needs approval"
        case .notRegistered:
            return "Off"
        case .notFound:
            return "Unavailable"
        @unknown default:
            return "Unknown"
        }
    }

    func refresh() {
        status = SMAppService.mainApp.status
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil

        do {
            if enabled {
                guard status != .enabled && status != .requiresApproval else { return }
                try SMAppService.mainApp.register()
            } else {
                guard status != .notRegistered else { return }
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        refresh()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
