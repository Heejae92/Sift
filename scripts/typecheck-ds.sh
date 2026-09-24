#!/bin/zsh
# Type-check the design-system token files without an Xcode project.
# `xcode-select -p` on this machine points at CommandLineTools, which has no iOS SDK,
# so DEVELOPER_DIR is pinned to Xcode.app (override by exporting DEVELOPER_DIR).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
SWIFT_VERSION="${SWIFT_VERSION:-6}"
echo "typecheck: swift-version $SWIFT_VERSION, target arm64-apple-ios17.0-simulator"
xcrun -sdk iphonesimulator swiftc -typecheck \
  -target arm64-apple-ios17.0-simulator \
  -swift-version "$SWIFT_VERSION" \
  "$ROOT"/Sift/DesignSystem/*.swift
echo "typecheck: OK"
