import SwiftUI
import TermBridgeKit

struct ContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Upper canvas to simulate host app content
            GeometryReader { geo in
                Canvas { context, size in
                    let gradient = Gradient(colors: [.blue.opacity(0.6), .mint.opacity(0.5), .cyan.opacity(0.4)])
                    let rect = CGRect(origin: .zero, size: size)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 24),
                        with: .linearGradient(
                            gradient,
                            startPoint: .zero,
                            endPoint: CGPoint(x: size.width, y: size.height)
                        )
                    )

                    let text = Text("TermBridgeKit demo workspace")
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                    context.draw(text, at: CGPoint(x: rect.midX, y: rect.midY))
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .padding()
            }
            .frame(maxHeight: .infinity)

            Divider()

            // Bottom region is where Ghostty goes
            TermBridgeKitTerminalView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
