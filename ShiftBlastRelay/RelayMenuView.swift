import SwiftUI
import AppKit

struct RelayMenuView: View {
    @ObservedObject var coordinator: RelayCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            statusSection
            Divider()
            foldersSection
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 340)
    }

    private var header: some View {
        HStack {
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.tint)
            Text("ShiftBlast Relay")
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Spacer()
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(coordinator.iCloudReady ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(coordinator.iCloudReady ? "iCloud collegato" : "iCloud non pronto")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Text(coordinator.sentinelStatus)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
            if let reason = coordinator.lastReason {
                Text(reason)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Button("Invia segnale di test") {
                coordinator.sendTestSignal()
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11, weight: .semibold))
            .padding(.top, 2)
        }
    }

    private var foldersSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CARTELLE AGENT MONITORATE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)

            ForEach(coordinator.suggestedSlugs(), id: \.slug) { item in
                folderRow(slug: item.slug, displayName: item.displayName, defaultPath: item.defaultPath)
            }

            Text("Autorizza ~/.codex/sessions: il relay rileva quando Codex sta rispondendo e quando smette di scrivere.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private func folderRow(slug: String, displayName: String, defaultPath: URL) -> some View {
        let isGranted = coordinator.grantedSlugs.contains(slug)
        return HStack {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "folder")
                .foregroundStyle(isGranted ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("~/\(displayName)")
                    .font(.system(size: 12, weight: .medium))
            }
            Spacer()
            if isGranted {
                Button("Revoca") {
                    coordinator.revokeBookmark(slug: slug)
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11))
            } else {
                Button("Autorizza") {
                    openFolderPicker(slug: slug, defaultPath: defaultPath)
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11))
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Avvia al login", isOn: Binding(
                get: { coordinator.loginItemEnabled },
                set: { coordinator.setLoginItemEnabled($0) }
            ))
            .toggleStyle(.checkbox)
            .font(.system(size: 12))

            HStack {
                Spacer()
                Button("Esci") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11))
            }
        }
    }

    private func openFolderPicker(slug: String, defaultPath: URL) {
        let panel = NSOpenPanel()
        panel.title = "Autorizza cartella agent"
        panel.message = "Seleziona la cartella ~/\(slug)"
        panel.prompt = "Autorizza"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = FileManager.default.fileExists(atPath: defaultPath.path)
            ? defaultPath
            : FileManager.default.homeDirectoryForCurrentUser

        guard panel.runModal() == .OK, let url = panel.url else { return }
        coordinator.grantBookmark(slug: slug, url: url)
    }
}
