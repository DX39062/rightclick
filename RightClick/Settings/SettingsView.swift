import SwiftUI
import RightClickCore

struct SettingsView: View {
    @State private var settings: AppSettings = .default
    @State private var message: String?

    private let store = SettingsStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("New File", isOn: binding(\.isNewFileEnabled))
            Toggle("Cut / Paste", isOn: binding(\.isCutPasteEnabled))

            Divider()

            Button("Restart Finder") {
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
            message = "Settings saved. They usually apply on the next right-click."
        } catch {
            message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func restartFinder() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Finder"]

        do {
            try process.run()
            message = "Finder restarted."
        } catch {
            message = error.localizedDescription
        }
    }
}
