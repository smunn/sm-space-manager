//
//  WorkspaceEditorView.swift
//  SpaceManager
//

import SwiftUI

struct WorkspaceEditorView: View {
    @StateObject private var store = WorkspaceStore()
    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var deleteTarget: ManagedWorkspace?

    private var activeWorkspaces: [ManagedWorkspace] {
        filtered.filter { !$0.isArchived }
    }

    private var archivedWorkspaces: [ManagedWorkspace] {
        filtered.filter { $0.isArchived }
    }

    private var filtered: [ManagedWorkspace] {
        if searchText.isEmpty { return store.workspaces }
        return store.workspaces.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.key.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Filter", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)

                Spacer()

                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                }
                .help("Add workspace")
            }
            .padding()

            if store.workspaces.isEmpty {
                Spacer()
                Text("No workspaces found")
                    .foregroundStyle(.secondary)
                Text(WorkspaceStore.configPath)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
                Spacer()
            } else {
                List {
                    if !activeWorkspaces.isEmpty {
                        Section("Active (\(activeWorkspaces.count))") {
                            ForEach(activeWorkspaces) { workspace in
                                WorkspaceRow(workspace: workspace, onArchive: {
                                    store.setArchived(workspace, archived: true)
                                }, onDelete: {
                                    deleteTarget = workspace
                                })
                            }
                        }
                    }

                    if !archivedWorkspaces.isEmpty {
                        Section("Archived (\(archivedWorkspaces.count))") {
                            ForEach(archivedWorkspaces) { workspace in
                                WorkspaceRow(workspace: workspace, onArchive: {
                                    store.setArchived(workspace, archived: false)
                                }, onDelete: {
                                    deleteTarget = workspace
                                })
                            }
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .frame(width: 520, height: 480)
        .sheet(isPresented: $showAddSheet) {
            AddWorkspaceSheet(store: store)
        }
        .alert("Delete Workspace?", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let target = deleteTarget {
                    store.remove(target)
                }
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) {
                deleteTarget = nil
            }
        } message: {
            if let target = deleteTarget {
                Text("Remove \"\(target.displayName)\" from workspaces? This cannot be undone.")
            }
        }
        .debugLabel("workspaceEditorView")
    }
}

private struct WorkspaceRow: View {
    let workspace: ManagedWorkspace
    let onArchive: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(workspace.displayName)
                        .fontWeight(.medium)

                    if workspace.hasPrompt {
                        Text("prompt")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }

                if let path = workspace.projectPath {
                    Text(path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            Button(action: onArchive) {
                Image(systemName: workspace.isArchived ? "arrow.uturn.backward" : "archivebox")
            }
            .buttonStyle(.borderless)
            .help(workspace.isArchived ? "Unarchive" : "Archive")

            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
            .help("Delete")
        }
        .padding(.vertical, 2)
        .opacity(workspace.isArchived ? 0.6 : 1.0)
        .debugLabel("WorkspaceRow")
    }
}

private struct AddWorkspaceSheet: View {
    @ObservedObject var store: WorkspaceStore
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var key = ""
    @State private var projectPath = ""
    @State private var keyEdited = false

    private var generatedKey: String {
        displayName
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }

    private var effectiveKey: String {
        keyEdited ? key : generatedKey
    }

    private var keyConflict: Bool {
        !effectiveKey.isEmpty && store.workspaces.contains { $0.key == effectiveKey }
    }

    private var canSave: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !effectiveKey.isEmpty &&
        !keyConflict
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Workspace")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                TextField("Display Name", text: $displayName)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    TextField("Key", text: Binding(
                        get: { effectiveKey },
                        set: { key = $0; keyEdited = true }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                    if keyConflict {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                            .help("A workspace with this key already exists")
                    }
                }

                HStack {
                    TextField("Project Path", text: $projectPath)
                        .textFieldStyle(.roundedBorder)

                    Button("Browse...") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.url {
                            let home = FileManager.default.homeDirectoryForCurrentUser.path
                            let path = url.path
                            if path.hasPrefix(home) {
                                projectPath = "~" + path.dropFirst(home.count)
                            } else {
                                projectPath = path
                            }
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    store.add(
                        key: effectiveKey,
                        displayName: displayName.trimmingCharacters(in: .whitespaces),
                        projectPath: projectPath.isEmpty ? nil : projectPath
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 400)
        .debugLabel("addWorkspaceSheet")
    }
}
