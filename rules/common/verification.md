# Verification

## The iron law

**You MUST NOT claim work is complete, fixed, passing, working, verified or
ready without fresh verification evidence produced in the current message.**

Fresh means the relevant verification ran after the last change to the files it
checks. Evidence is actual command output, including its exit status and
relevant counts or result. A worker report, prior run, review verdict, markdown
structure check or belief is not verification evidence.

If the user explicitly skips verification, record the exact scope, reason and
consequence. Mark it skipped and unverified, never passed or verified. You may
report that the requested workflow stopped with a verification phase skipped,
but must explicitly qualify the result as unverified and must not call the
work fixed, passing, complete or ready. A skip cannot waive this iron law or
authorise a misleading claim.

## Scope of claims

This rule applies to every statement that asserts or implies success, including
direct, hedged and implicit claims. Examples include tests passing, a build
succeeding, work being done or ready, a bug being fixed, a requirement being
met, or handing control back in a way that implies success. Do not evade this
rule by choosing different wording.

## When the rule fires

Run fresh verification before:

- Committing, pushing, opening or updating a pull request
- Claiming a task or subtask is complete
- Moving to the next task in a sequence
- Handing control back with any implication of success
- Accepting a subagent's report that it succeeded; inspect the diff and require
  applicable independent checks
- Stating that a bug is fixed, a regression is closed or a requirement is met

Invoke `verification-before-completion` for the verification procedure. In
coordinated work, task-local checks use stable inputs; broad checks wait until
all relevant writers stop. Explicitly skipped checks remain unverified.
