#!/usr/bin/env bash
# Copy a locally built GhosttyKit.xcframework into TermBridgeKit's expected location.
# Usage:
#   scripts/install-ghosttykit.sh /path/to/GhosttyKit.xcframework
# or set GHOSTTYKIT_PATH=/path/to/GhosttyKit.xcframework

set -euo pipefail

XCFRAMEWORK_PATH="${1:-${GHOSTTYKIT_PATH:-}}"
DEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/vendor/ghostty/macos"

if [[ -z "${XCFRAMEWORK_PATH}" ]]; then
  echo "error: provide the path to GhosttyKit.xcframework as an argument or via GHOSTTYKIT_PATH" >&2
  exit 1
fi

if [[ ! -d "${XCFRAMEWORK_PATH}" ]]; then
  echo "error: '${XCFRAMEWORK_PATH}' does not exist or is not a directory" >&2
  exit 1
fi

mkdir -p "${DEST_DIR}"
rsync -a --delete "${XCFRAMEWORK_PATH%/}/" "${DEST_DIR}/GhosttyKit.xcframework/"

echo "Installed GhosttyKit.xcframework to ${DEST_DIR}"
