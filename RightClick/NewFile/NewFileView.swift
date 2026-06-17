import SwiftUI
import RightClickCore

struct NewFileView: View {
    @ObservedObject var viewModel: NewFileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New File")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("File name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Untitled", text: $viewModel.baseName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Format")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Format", selection: $viewModel.selectedFormat) {
                    ForEach(FileFormat.builtIn) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Location")
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
                Button("Cancel") {
                    dismiss()
                }
                Button("Create") {
                    viewModel.create()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .fixedSize()
    }
}
