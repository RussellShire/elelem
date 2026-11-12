---
name: fast-path-implementation
description: Compatibility entry point for one bounded task explicitly scheduled by the workflow coordinator in an approved wave with an independent READY verdict or an explicitly authorised, planner-checked readiness-review skip; reuses standard execution gates and scoped skips.
metadata:
  model: openai/gpt-6.1-sol
  reasoning_effort: medium
---

# Fast-Path Implementation

This compatibility entry point does not own an execution or review algorithm.
It applies only to one bounded task explicitly scheduled by the coordinator in
an approved workflow. If there is no active valid workflow, invoke
`workflow-coordinator` through `{{INVOKE_SKILL_TOOL}}` and return the request.

For the scheduled task, invoke `subagent-driven-development` through
`{{INVOKE_SKILL_TOOL}}`. Supply the approved task and wave record and any
explicitly authorised scoped skips. The standard executor applies its own
entry, readiness, dispatch, standard independent task reviewer, checks,
barriers and final gates. Do not substitute another reviewer template, improvise
parallel work or infer a skip from task size. Return the executor result through
the existing coordinator handoff.
