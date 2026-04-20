//
//  SettingsView.swift
//  SpaceManager
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var launchAtLogin = LaunchAtLoginManager()
    @State private var permissionStates: [AppPermission: Bool] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)

            GroupBox("General") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(
                        "Open at login",
                        isOn: Binding(
                            get: { launchAtLogin.isEnabled },
                            set: { launchAtLogin.setEnabled($0) }
                        )
                    )
                    .disabled(!launchAtLogin.canToggle)

                    HStack(spacing: 8) {
                        Text(launchAtLogin.statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if launchAtLogin.needsApproval {
                            Button("Open Login Items") {
                                launchAtLogin.openLoginItemsSettings()
                            }
                            .buttonStyle(.link)
                            .font(.caption)
                        }
                    }

                    if let errorMessage = launchAtLogin.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Permissions") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(AppPermission.allCases, id: \.self) { permission in
                        PermissionStatusRow(
                            permission: permission,
                            isGranted: permissionStates[permission] ?? false
                        )
                    }

                    Button("Refresh") {
                        refresh()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(width: 430)
        .onAppear {
            launchAtLogin.refresh()
            refresh()
        }
        .debugLabel("settingsView")
    }

    private func refresh() {
        permissionStates = Dictionary(
            uniqueKeysWithValues: AppPermission.allCases.map { permission in
                (permission, AppPermissions.check(permission))
            }
        )
    }
}

private struct PermissionStatusRow: View {
    let permission: AppPermission
    let isGranted: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(permission.title)
                Text(permission.purpose)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(isGranted ? "Granted" : "Needed")
                .font(.caption)
                .foregroundStyle(isGranted ? Color.secondary : Color.red)

            Button("Open") {
                AppPermissions.openSettings(for: permission)
            }
        }
        .debugLabel("PermissionStatusRow")
    }
}
