---
name: step
description: Implement one numbered step of PLAN.md exactly as written there, run its oracle and quote the output. Usage - /step 3
disable-model-invocation: true
---
Step to implement: $ARGUMENTS

1. Read `CLAUDE.md`, `progress.md` and `PLAN.md` fully. Find the section `### $ARGUMENTS.` in
   "Implementation order". If the number is missing, or `progress.md` says an earlier step is
   not done, stop and say which.
2. Open every spec section the step refers to (and §2 / §3 when the step touches data or UI).
   The step text plus those sections are the whole task. Nothing else is in scope: not the
   next step, not the "Tempting, explicitly not planned" list, not a refactor "while here".
3. Implement the step. Touch only the files the step names or implies; if you believe another
   file must change, say why in one sentence and wait.
4. Run the step's **Oracle** commands exactly as written in `PLAN.md`. Quote their output
   verbatim. If a command prints FAIL or a test is red, fix the root cause and re-run; never
   edit a script, a fixture or a test to make it pass. After two failed fixes, stop and report.
5. Finish with:
   - `Step $ARGUMENTS: done` or `Step $ARGUMENTS: blocked — <reason>`
   - the quoted oracle output
   - the list of files changed
   - one line "Not done / deferred" if anything in the step was skipped, and why
   Do not commit, do not update `progress.md`; the owner asks for that separately.
