# Debugging

Use `workflow-coordinator` as the entry point for debugging and fixes. These
evidence requirements apply whether or not the `debugging` skill is invoked.

## The hard gate

Do not attempt a fix until both conditions are met:

1. Reproduce the bug against the current state, or explicitly record that it
   could not be reproduced and adjust confidence accordingly.
2. Identify the root cause with evidence from code read, captured program
   output or an observed reproduction.

"I can see the problem" and an error message alone are not evidence. Do not
waive this gate because the bug looks simple, obvious or quicker to fix than
investigate. A user may explicitly skip the debugging phase, but that skip is
not reproduction or root-cause evidence. If required evidence is missing, block
the fix or qualify the result; never claim the issue is fixed or understood
without support.

## Evidence over intuition

Support every claim about what is wrong with actual code, captured output or
observations from reproduction. Pattern-matching an error message without
reproduction is not enough. If evidence is missing, gather it before changing
code.

## Bug fixes are still changes

Bug fixes do not waive `workflow.md`, `testing.md` or `verification.md`:

- A bug fix requires an explicitly approved design, which records the
  reproduction approach and intended module or change. Use the active workflow
  approval; do not send the user through the Planning router again when the
  current approved design covers the fix.
- By default, begin with a failing regression test that reproduces the bug.
  The test goes red, the fix goes in, and the test goes green. A user may
  explicitly skip TDD for scoped work. Record that skip; it does not waive
  reproduction, root-cause evidence or truthful verification claims.
- Report a fix as fixed only after fresh verification and cite its evidence.
  If verification is explicitly skipped, report the result as unverified.

## Procedural rules

When invoked, the `debugging` skill governs investigation scope, reproduction,
root-cause analysis, evidence, and the minimal fix procedure. Use the approved
workflow design as the fix approval; do not restart Planning when the active
approved design already covers the change.
