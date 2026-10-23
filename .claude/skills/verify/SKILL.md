---
name: verify
description: Build ClaudeUsageStatus.app, launch it and verify the status item and the dropdown through System Events. Run after any change that touches the app or the presentation layer.
disable-model-invocation: true
---
Run, in this order, and quote each script's output verbatim:

1. `for p in Packages/*; do (cd $p && swift test 2>&1 | tail -1); done`
2. `scripts/build.sh`
3. `scripts/verify-ui.sh`

If a step prints FAIL, read the reason, fix the root cause in the code and re-run from step 1.
Never edit `scripts/` to make a check pass; if a check itself is wrong, say so and stop.
If `verify-ui.sh` reports that Accessibility is not granted, stop: that is a TCC permission for the
terminal and a human changes it in System Settings.
If the title is `⚠︎` or `—`, run `swift run --package-path Tools/usage-probe usage-probe` and report its
output before touching any code: the cause is usually the token or the network, not the app.
