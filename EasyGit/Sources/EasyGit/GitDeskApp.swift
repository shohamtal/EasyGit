import SwiftUI

@main
struct EasyGitApp: App {
    @State private var appVM = AppViewModel()
    private var themeManager = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            MainContentView()
                .environment(appVM)
                .environment(themeManager)
                .frame(
                    minWidth: Theme.minWindowWidth,
                    minHeight: Theme.minWindowHeight
                )
                .background(Theme.mainBG)
                .preferredColorScheme(themeManager.current.preferredColorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 700)
    }
}
