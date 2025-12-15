# TermBridgeKit

TermBridgeKit is a thin embedding layer that lets you drop a native terminal surface into a macOS SwiftUI app. It currently ships with Ghostty's runtime (`GhosttyKit.xcframework`) but is intentionally positioned as a general bridge so we can follow Ghostty's direction—and, if needed, pivot to other backends—without pretending to be "just a Ghostty wrapper."

## Requirements
- macOS 14+
- Swift 5.9 / Xcode 15+
- `GhosttyKit.xcframework` available at `vendor/ghostty/macos/GhosttyKit.xcframework` (the repo vendors the current build)

## Usage
Add TermBridgeKit to your project (via SPM or a local checkout) and render the SwiftUI view:

```swift
import SwiftUI
import TermBridgeKit

struct TerminalPane: View {
    var body: some View {
        TermBridgeKitTerminalView()
            .frame(minWidth: 600, minHeight: 400)
    }
}
```

Set `TERMBRIDGEKIT_DEBUG_INPUT=1` when running if you want verbose keyboard/mouse logging.

## Demo
Run the bundled sample app to see the terminal surface embedded under a bit of host UI chrome:

```sh
swift run TermBridgeKitDemo
```
