# GhosttyKit 0.1.5 patch series

This patch turns upstream Ghostty `2cc7341b08ca66d9efdfdd97b1ab3d49898d2677`
into the source tree used to build `GhosttyKit.xcframework` 0.1.5.

## What's in it

- **`src/renderer/Metal.zig`** — two iOS fixes:
  1. iOS surface attach: send `addSublayer:` (with the colon) to
     `view.layer` (the UIView's CALayer), not the no-arg `addSublayer`
     to the UIView itself. The 0.1.3 release shipped the broken form
     and crashed on iOS with `unrecognized selector`.
  2. Default Metal storage mode: force `.shared` on iOS unconditionally.
     `hasUnifiedMemory` returns `false` on the iOS Simulator, which made
     the renderer pick `.managed` — iOS Metal does not support `.managed`
     at all and asserts `Invalid storageMode 1`.

- **`include/ghostty.h`, `src/config/CApi.zig`** — exposes the runtime
  font config C APIs (`ghostty_config_set_font_size`,
  `ghostty_config_set_font_family`, `ghostty_config_font_family_count`,
  `ghostty_config_font_family_get`) that Termini uses to honor
  `TerminiTerminalAppearance.fontSize` / `.fontFamily` overrides.

- **`src/Surface.zig`, `src/apprt/embedded.zig`, `src/termio.zig`,
  `src/termio/backend.zig`, `src/termio/Host.zig`** — host-output
  backend additions used by Termini's iOS PTY transport
  (`ghostty_surface_process_output`).

- **`src/build/GhosttyXCFramework.zig`** — adds x86_64 iOS Simulator
  to the lipo target list so the xcframework is universal.

## How to apply

```bash
GHOSTTY_DIR=/path/to/ghostty
git -C "${GHOSTTY_DIR}" checkout 2cc7341b08ca66d9efdfdd97b1ab3d49898d2677
git -C "${GHOSTTY_DIR}" apply /path/to/this/ghostty-2cc7341b-to-0.1.5.patch
```

Then run `scripts/build-ghosttykit.sh` from the TermBridgeKit root.

## Provenance

- Built artifact: `dist/GhosttyKit.xcframework.zip`
- SwiftPM checksum: `d9246242185d9ce5d4ee45fb0ff3fbc520aa995641dea9b198e43e1e4538b759`
- GitHub release: <https://github.com/arach/TermBridgeKit/releases/tag/0.1.5>
