#!/bin/bash
# Stop: the agent may not finish a turn while the fast checks are red.
# Fast only: `swift build` + `swift test` of the local packages (seconds).
# UI checks and xcodebuild are deliberately not here — they belong to /verify.
INPUT=$(cat)
# Claude Code sets stop_hook_active when the stop was already triggered by
# this hook; exit 0 then, otherwise the gate loops forever.
if [ "$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false')" = "true" ]; then
  exit 0
fi

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
FAILED=""
for PKG in "$ROOT"/Packages/*/; do
  NAME=$(basename "$PKG")
  if ! OUT=$(cd "$PKG" && swift test 2>&1); then
    FAILED+="== $NAME"$'\n'"$(printf '%s\n' "$OUT" | grep -E 'error:|failed|Fatal' | head -20)"$'\n'
  fi
done

if [ -n "$FAILED" ]; then
  echo "Stop gate: swift test is red. Fix before finishing." >&2
  printf '%s' "$FAILED" >&2
  exit 2
fi
exit 0
