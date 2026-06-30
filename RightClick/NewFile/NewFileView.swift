import SwiftUI
import RightClickCore

struct NewFileView: View {
    @ObservedObject var viewModel: NewFileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("newFile.title")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("newFile.fileName")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(String(localized: "newFile.untitled"), text: $viewModel.baseName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("newFile.format")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker(String(localized: "newFile.format"), selection: $viewModel.selectedFormat) {
                    ForEach(FileFormat.builtIn) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("newFile.location")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.targetDirectory.path)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: 320, alignment: .leading)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(width: 320, alignment: .leading)
            }

            HStack {
                Spacer()
                Button("newFile.cancel") {
                    dismiss()
                }
                Button("newFile.create") {
                    viewModel.create()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .fixedSize()
        .onReceive(NotificationCenter.default.publisher(for: .rightClickTargetDirectoryDidChange)) { notification in
            guard let targetDirectory = notification.userInfo?["targetDirectory"] as? URL else {
                return
            }
            viewModel.targetDirectory = targetDirectory
        }
    }
}
