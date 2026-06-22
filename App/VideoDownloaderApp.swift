import SwiftUI

@main
struct VideoDownloaderApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .frame(minWidth: 760, minHeight: 520)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}  // no "New Window"
        }

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}
