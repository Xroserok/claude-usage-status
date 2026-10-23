#!/bin/bash
# PreToolUse(Bash): the "Hard rules" of CLAUDE.md as a guarantee, not a wish.
# Receives the tool call as JSON on stdin; exit 2 blocks the command and
# returns stderr to the agent.
CMD=$(jq -r '.tool_input.command // empty')
[ -z "$CMD" ] && exit 0

deny() {
  echo "Blocked by ClaudeUsageStatus policy: $1. See CLAUDE.md 'Hard rules'. If you believe this is needed, stop and ask." >&2
  exit 2
}

# `sudo` only in command position (line start, after ; & | or $( ), so the
# word inside a commit message or a comment does not trip the rule.
if printf '%s' "$CMD" | grep -Eq '(^|[;&|]|\$\()[[:space:]]*sudo([[:space:]]|$)'; then
  deny "sudo is never allowed"
fi

case "$CMD" in
  *"defaults write"*|*launchctl*|*tccutil*|*csrutil*)
                                            deny "system-state changes are a human decision" ;;
  *"security add-generic-password"*|*"security delete-generic-password"*|*"security set-generic-password"*|*"security add-internet-password"*|*"security delete-internet-password"*)
                                            deny "Claude Code's Keychain item is read-only for this project" ;;
  *"pkill -f"*|*"killall -9"*)              deny "use pkill -x ClaudeUsageStatus (pkill -f matches the editor/claude running in this folder)" ;;
esac

# `rm -rf` of the root, the home directory or a wildcard under them; not of
# a path such as /tmp/x or ~/project/.build.
if printf '%s' "$CMD" | grep -Eq 'rm[[:space:]]+-[a-zA-Z]*[rR][a-zA-Z]*[[:space:]]+(/|~|\$HOME)/?(\*)?([[:space:]]|$)'; then
  deny "rm -rf of / or the home directory"
fi

# Only ad-hoc signing: `codesign -s -`. Any other identity is denied.
if printf '%s' "$CMD" | grep -Eq 'codesign[^|;&]*(-s|--sign)[[:space:]]+[^-[:space:]]'; then
  deny "only ad-hoc signing (codesign -s -) in this project"
fi

# A token must never travel anywhere but api.anthropic.com.
if printf '%s' "$CMD" | grep -Eq 'sk-ant-oat01-[A-Za-z0-9_-]{20,}'; then
  deny "an OAuth token appeared in a command; tokens stay inside the app and usage-probe"
fi
exit 0
