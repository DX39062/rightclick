import SwiftUI

@main
struct RightClickApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("New File") {
            NewFileView(
                viewModel: NewFileViewModel(targetDirectory: appDelegate.latestTargetDirectory())
            )
        }
        .windowResizability(.contentSize)
    }
}
