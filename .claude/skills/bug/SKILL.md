---
name: bug
description: Fix a bug test-first - reproduce it with an oracle, write the failing test, fix the root cause, quote the green output. Usage - /bug <what you see, and what spec says should happen>
disable-model-invocation: true
---
Bug report: $ARGUMENTS

1. Read `CLAUDE.md` and the spec section that defines the expected behaviour. Quote that
   sentence of `spec.md`. If the spec is silent or contradicts the report, stop and say so:
   that is a spec change, not a bug fix.
2. Reproduce before touching code. Pick the cheapest oracle that shows the bug and quote its
   output: a package `swift test`, `usage-probe` (with `--simulate …` if it is an error path),
   `scripts/verify-ui.sh`, or `log show --predicate 'subsystem == "com.xroserok.yourlimitbar"' --last 10m`.
   If you cannot reproduce, report that and stop; do not fix blind.
3. Write the failing test first, in the package that owns the behaviour (Presentation for
   state/formatting, Data for parsing/network/Keychain, Domain for models). Quote the red run.
4. Fix the root cause in the smallest change. No refactors, no "while here", no new strings
   without their `ru` counterpart. Never weaken a test, a script or a hook to pass.
5. Run the test (green), then the stop-gate set: `for p in Packages/*; do (cd $p && swift test); done`.
   If the bug was visible in the UI, say that `/verify` is due and stop; do not run it yourself.
6. Finish with: `Bug: fixed` / `Bug: not reproduced` / `Bug: spec question`, the quoted outputs,
   the files changed, and one line on whether `CLAUDE.md` or a hook should learn from it.
   After two failed fixes, stop and report. Do not commit or update `progress.md`.
