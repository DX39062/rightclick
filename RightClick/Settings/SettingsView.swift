import SwiftUI
import RightClickCore

struct SettingsView: View {
    @State private var settings: AppSettings = .default
    @State private var message: String?

    private let store = SettingsStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("settings.newFile", isOn: binding(\.isNewFileEnabled))
            Toggle("settings.cutPaste", isOn: binding(\.isCutPasteEnabled))

            Divider()

            Button("settings.restartFinder") {
                restartFinder()
            }

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 360, alignment: .leading)
        .onAppear {
            settings = (try? store.load()) ?? .default
        }
    }

    private func binding(_ keyPath: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in
                settings[keyPath: keyPath] = newValue
                saveSettings()
            }
        )
    }

    private func saveSettings() {
        do {
            try store.save(settings)
            message = String(localized: "settings.saved")
        } catch {
            message = L10n.actionErrorMessage(error)
        }
    }

    private func restartFinder() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Finder"]

        do {
            try process.run()
            message = String(localized: "settings.finderRestarted")
        } catch {
            message = error.localizedDescription
        }
    }
}
