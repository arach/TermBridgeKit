# TermBridgeKit

TermBridgeKit is a thin embedding layer that lets you drop a native terminal surface into a macOS SwiftUI app. It currently ships with Ghostty's runtime (`GhosttyKit.xcframework`) but is intentionally positioned as a general bridge so we can follow Ghostty's direction—and, if needed, pivot to other backends—without pretending to be "just a Ghostty wrapper."

## Requirements
- macOS 14+
- Swift 5.9 / Xcode 15+
- `GhosttyKit.xcframework` available at `vendor/ghostty/macos/GhosttyKit.xcframework`

## Getting GhosttyKit
TermBridgeKit does not ship Ghostty binaries. Build `GhosttyKit.xcframework` directly from the Ghostty project (follow their embed instructions), then install it into this repo:

1) Clone Ghostty (or point to your existing checkout).  
2) Follow Ghostty's documented steps to build `GhosttyKit.xcframework` for macOS.  
3) Copy the resulting framework into place:

```sh
# Example: after building GhosttyKit.xcframework from the Ghostty repo
./scripts/install-ghosttykit.sh /path/to/GhosttyKit.xcframework
```

The install script simply copies the framework into `vendor/ghostty/macos`, which is git-ignored.

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
