#!/bin/bash
# PostToolUse(Edit|Write): format the Swift file the agent just touched with the
# `swift format` bundled in Xcode (config: .swift-format). Never blocks.
FILE=$(jq -r '.tool_input.file_path // empty')
case "$FILE" in
  *.swift) [ -f "$FILE" ] && swift format --in-place "$FILE" 2>/dev/null ;;
esac
exit 0
