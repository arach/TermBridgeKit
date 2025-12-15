import SwiftUI
import TermBridgeKit

@main
struct TermBridgeKitDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 700)
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
    }
}
