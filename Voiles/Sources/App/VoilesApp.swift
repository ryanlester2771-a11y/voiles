import SwiftUI

/// Main entry point for the Voiles AR Wall Art Visualizer application
@main
struct VoilesApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}
