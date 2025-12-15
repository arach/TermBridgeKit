# TermBridgeKit

Drop a native terminal surface into a macOS SwiftUI app. Uses Ghostty today, but the SwiftUI API is kept small so the backend can change later.

## Requirements
- macOS 14+
- Swift 5.9 / Xcode 15+
- `vendor/ghostty/macos/GhosttyKit.xcframework` (git-ignored)

## Get GhosttyKit
This repo does not ship Ghostty binaries. Build `GhosttyKit.xcframework` from the Ghostty project, then copy it in:

```sh
# After building GhosttyKit.xcframework from Ghostty's embed instructions
./scripts/install-ghosttykit.sh /path/to/GhosttyKit.xcframework
```

The script just copies the framework into `vendor/ghostty/macos`.

## Usage
Add TermBridgeKit via SPM or as a local checkout, then render the view:

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

Set `TERMBRIDGEKIT_DEBUG_INPUT=1` to log keyboard/mouse events.

## Demo
```sh
swift run TermBridgeKitDemo
```
