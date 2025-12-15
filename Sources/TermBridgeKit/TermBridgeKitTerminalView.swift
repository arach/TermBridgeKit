import SwiftUI

/// SwiftUI wrapper for the live Ghostty surface.
public struct TermBridgeKitTerminalView: View {
    public init() {}

    public var body: some View {
        TermBridgeKitSurfaceView()
            .background(.black)
    }
}
