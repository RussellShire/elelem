# Subagents

These rules apply to every dispatch. The workflow coordinator owns shared state
and dispatch sequencing.

## Context and scope

Do not pass inherited session history. Supply the task, bounded relevant
context, acceptance criteria, constraints and exact allowed writes. Do not ask
workers to rediscover context already known to the coordinator. Worker briefs
must identify stable reads and known generated, formatter, test and resource
side effects. Concurrent tasks require disjoint writes and must not consume one
another's changing files.

Workers return reports and evidence to the coordinator; a report is not
independent review or verification. Workers do not modify shared workflow
state. Default to no nested delegation. A dispatch may permit it explicitly
only when required and when the harness supports it, to avoid uncontrolled
delegation depth.

## Git and privilege

Subagents **MUST NOT** commit, push, create branches, use worktrees, or perform
destructive Git operations. The coordinator owns Git state. Preserve the
user's Git preference, defaulting to leaving work uncommitted.

Subagents **MUST NOT** use `sudo` or elevated-privilege commands. If a task
requires elevation, report the blocker to the user.

## Models and dispatch procedure

Never invent or assume a model identifier. Follow
`skills/_shared/subagent-dispatch.md` for specialist selection, model
enumeration, routing and capability checks. Missing required routing or
capability is a blocker, not a reason for silent fallback.
