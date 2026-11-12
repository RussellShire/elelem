# Implementer Worker Prompt Template

Before dispatch, load `../_shared/subagent-dispatch.md` and
`../_shared/worker-contract.md`. Apply dispatch prerequisites and routing
outside the worker packet. Paste the applicable worker-contract sections
verbatim with source path and identity, together with applicable standing rules
and task-specific method instructions. Do not send dispatcher routing or
prerequisite algorithms to the worker.

```text
{{DISPATCH_AGENT_TOOL}} ([SPECIALISED_SUBAGENT_TYPE]):
  description: "Implement [TASK_ID]: [task name]"
  prompt: |
    Implement exactly the approved task described below.

    ## Worker obligations and source identity

    [Paste the complete All workers and Implementation workers sections from
    worker-contract.md verbatim, including source path and content identity.]

    ## Task brief

    [Paste the complete approved task brief: requirement mapping, objective,
    acceptance criteria, interfaces, dependencies, exclusions, exact allowed
    writes, stable reads, prohibited concurrent reads, known side effects,
    resource limits, verification commands and expected evidence.]

    ## Baseline, context and methods

    [Supply immutable task-start HEAD and relevant dirty/untracked contents,
    exact identities or snapshots, relevant stable source context, applicable
    standing rules, authorised scoped skips with source and consequences, and
    method instructions or explicit required skill invocation.]

    ## Return

    Return exactly one status, DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT or
    BLOCKED, with the structured worker return from the supplied brief. Include
    each acceptance criterion and evidence, actual touched paths including
    reverted edits and renames, command outputs and exit codes, per-behaviour
    TDD evidence where applicable, deferred checks and questions. Do not claim
    independent verification or integration.
```
