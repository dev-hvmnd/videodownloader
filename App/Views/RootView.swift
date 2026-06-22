import SwiftUI

/// Root view: shows onboarding until the tools are ready, then the main view.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.toolchain.isReady {
                MainView()
            } else {
                ToolchainSetupView(store: model.toolchain)
            }
        }
        .task {
            if case .unknown = model.toolchain.status {
                await model.toolchain.checkStatus()
            }
            if model.toolchain.isReady, model.settings.autoUpdateYTDLP {
                await model.toolchain.updateYTDLP(announceUnchanged: false)
            }
        }
    }
}
