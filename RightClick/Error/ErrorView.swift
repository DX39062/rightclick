import SwiftUI

struct ErrorView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RightClick")
                .font(.headline)
            Text(message)
                .font(.body)
                .frame(width: 360, alignment: .leading)
            HStack {
                Spacer()
                Button("error.ok") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .fixedSize()
    }
}
