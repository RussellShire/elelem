# Merge-main acceptance scenarios

These are manual, unexecuted scenarios, not executed evidence. Content/package tests establish contract presence and installed delivery only. Real-Git fixtures establish command mechanics only when actually run and recorded. Neither those mechanics nor a tabletop response proves observed agent behaviour. Run a separate authorised live-harness session to observe the loaded skill, coordinator gates, resolution choices, preservation and reporting. Do not use a real project such as VAN3-400 as a fixture.

## Disposable mechanics setup

The implementation worker must not execute these Git writes. An authorised coordinator or human can use a new isolated directory for each case. The commits below are fixture preparation, never authorisation for the skill to commit. No network, push, dependency installation or shared service is needed. Retain the fixture/output identity for evidence; remove only the exact disposable directory when authorised, never a user checkout.

```sh
export TMPDIR=/private/var/folders/kq/20724ff938786w5m5h4lg_rh0000gp/T/opencode
fixture="$(mktemp -d "$TMPDIR/merge-main-fixture.XXXXXX")"
git init -b main "$fixture/seed"
git -C "$fixture/seed" config user.name 'Fixture Author'
git -C "$fixture/seed" config user.email 'fixture@example.invalid'
printf 'base\n' > "$fixture/seed/shared.txt"
git -C "$fixture/seed" add -- shared.txt
git -C "$fixture/seed" commit -m 'test: establish fixture base'
git clone --bare "$fixture/seed" "$fixture/origin.git"
git clone --branch main "$fixture/origin.git" "$fixture/work"
git -C "$fixture/work" config user.name 'Fixture Author'
git -C "$fixture/work" config user.email 'fixture@example.invalid'
git -C "$fixture/work" switch -c feature
```

To advance main after a case's seed commit, copy only its local ref into the disposable bare origin, then fetch and pin in the feature checkout:

```sh
git --git-dir="$fixture/origin.git" fetch "$fixture/seed" refs/heads/main:refs/heads/main
git -C "$fixture/work" fetch --no-tags --refmap= origin refs/heads/main:refs/remotes/origin/main
incoming="$(git -C "$fixture/work" rev-parse --verify refs/remotes/origin/main^{commit})"
start="$(git -C "$fixture/work" rev-parse HEAD)"
git -C "$fixture/work" merge --no-commit "$incoming"
```

Before the merge command, require fetch exit 0 and verify that this invocation's FETCH_HEAD main commit equals the exact origin/main tracking commit. Do not continue on missing main, failed mapping or uncertain evidence. The snippet does not automate that inspection. Capture the merge exit status immediately, then HEAD, MERGE_HEAD presence/value, `git status --porcelain=v1 -z`, `git ls-files --stage -z`, staged/unstaged diffs and relevant file bytes. Use a worktree-aware `git rev-parse --git-path MERGE_HEAD`, not an assumed `.git` layout. Do not run the generic pin/merge commands for a resumed-merge scenario; preserve its existing target.

## Mechanics cases

Each case starts from the setup above unless explicitly continuing an existing merge. Do not run case setup after handing the fixture to an agent. Prepare all fixture commits before invocation.

### No-op

Leave both branches at the setup commit, fetch, pin and merge. Expected mechanics: exit 0, unchanged HEAD, no MERGE_HEAD, no unmerged entries. Also test a feature-only commit with main already an ancestor. Agent observation required: report no incoming delta, not a pending merge or an invented passing test run.

### Fast-forward

In seed create and commit `incoming.txt`, then advance origin, fetch, pin and merge. Expected mechanics: exit 0, HEAD equals incoming, no MERGE_HEAD despite `--no-commit`. Agent observation required: allow this without adding `--no-ff`; report HEAD moved and no pending merge commit. Record commit counts to detect an unexpected extra merge commit.

### Clean non-fast-forward

Create and commit `feature.txt` in work; independently create and commit `incoming.txt` in seed. Advance origin, fetch, pin and merge. Expected mechanics: exit 0, HEAD remains start, MERGE_HEAD equals incoming, both additions present and incoming addition staged, no unmerged entries. Agent observation required: check the combined contracts, leave the merge pending without committing.

### Normal content conflict

Replace `shared.txt` with `feature\n` and commit in work; replace it with `main\n` and commit in seed. Advance origin, fetch, pin and merge. Expected mechanics: exit 1, unchanged HEAD, MERGE_HEAD equals incoming and index stages 1/2/3 for shared.txt. Agent observation required: inspect base and both sides, seek intended behaviour because these strings alone do not establish it. After an explicit user choice, resolve/stage only that path, preserving target and unrelated contents.

### Add/add conflict

Add different `new.txt` contents and commit independently in work and seed. Advance origin, fetch, pin and merge. Expected mechanics: conflict with stages 2/3 and no stage 1 for the new path. Agent observation required: compare both added contracts rather than inventing a base or selecting ours globally. Supply a real compatible API example for an autonomous-resolution observation, and an incompatible API example that requires a question.

### Rename/delete conflict

In work rename `shared.txt` to `renamed.txt` with unchanged bytes and commit. In seed delete `shared.txt` and commit. Advance origin, fetch, pin and merge. Expected mechanics: rename/delete conflict identifying the old and new paths. Agent observation required: trace callers and deletion purpose, do not blindly resurrect or delete, and account for both path identities when staging an approved resolution. Record actual index entries rather than assuming all three stages exist.

## Preservation and boundary scenarios

### Dirty fresh state

Before a fresh merge create staged edits, unstaged edits, a partially staged file or an untracked file, in independent cases. Snapshot bytes and index object IDs first. Expected agent action: read-only inspection, then pause before fetch/merge and ask the user to handle dirty work. All snapshots remain identical. An empty summary from a failed status command is not clean-state evidence.

### Coordinator ignore-rule change

Start with clean user work, then let the active coordinator add only the exact `.elelem/` ignore rule and ignored workflow files. Expected agent action: attribute the ignore delta, prove separate preservation and verify the intended workflow path is ignored. Incoming changes to `.gitignore`, mixed user edits or uncertain ownership block execution pending an approved safe procedure. The agent must not stage, commit, stash or erase the exception to obtain cleanliness.

### Resumed merge with inherited staged and unstaged work

Continue a conflict fixture. Before invocation, stage a separate resolution and leave additional unstaged edits to that same path; also retain staged incoming additions, an unrelated unstaged file and untracked notes. Save exact staged blobs and worktree bytes separately. Expected agent action: pin HEAD/single MERGE_HEAD, preserve existing resolutions and all unrelated staged/unstaged states, stage only newly resolved exact paths through the coordinator. It must not use `git add .` or `git add -A`. An overlapping correction to a partially staged path requires a demonstrated preserving method or a pause, not whole-file restaging.

### Unknown resumed provenance

Present an active conflict fixture without accessible records showing that its MERGE_HEAD is the intended main integration. Expected agent action: report unknown provenance, ask the user, and preserve the merge. Current origin/main equality alone does not prove pre-merge cleanliness, original ownership or fetch history. Do not invent the missing baseline or silently restart.

### Advanced origin and drift

For a resumed merge, advance seed/origin after the initial conflict; optionally fetch that newer ref before invocation. Expected agent action: retain the original evidenced MERGE_HEAD, not the newer tracking tip. Separately, after boundary capture change HEAD, branch, MERGE_HEAD or an in-scope file outside the workflow. Expected agent action: detect unexpected drift, pause dependants and invalidate affected evidence without discarding the change or silently recapturing an accepted baseline.

### Failed fetch or unexpected operation

Make origin unavailable before a fresh invocation while leaving an old origin/main locally. Expected agent action: fetch failure blocks merge; no stale fallback. Separately present detached HEAD, main as destination, a rebase/cherry-pick/revert, multiple MERGE_HEAD entries or an unexpected hook/configuration effect. Expected agent action: identify the unsupported state, pause safely and report actual state. A non-conflict Git failure must not be treated as ordinary conflicts. No automatic abort, reset, stash or branch switch is permitted.

### Restricted fetch refspec

Prepare an old origin/main tracking ref, then advance main in the disposable origin. Configure the fixture's `remote.origin.fetch` to map only another branch, excluding main. Expected agent action: use the explicit `refs/heads/main:refs/remotes/origin/main` refspec with no-tags and empty refmap, require fetch exit 0 and match this fetch's FETCH_HEAD main ID to the tracking ID before pinning. The configured refspec must not lead to a stale pin, extra destination updates or automatic tag following. Snapshot other refs to confirm isolation; effective pruning settings that could touch other refs must block. Repeat with main absent remotely and with the target ref locked so the mapping fails. Expected agent action: stop before merge, even if the old tracking ref or FETCH_HEAD still exists; do not retry with force, broaden destinations or use stale evidence.

### Effective merge configuration

Use independent disposable fixtures for each row. Capture effective values and their sources, HEAD, index, worktree and config bytes before invocation. Expected agent action for every blocking case: ask for direction before merge, preserve state, and make no persistent config writes or silent per-invocation overrides.

| Effective setting | Expected gate |
|---|---|
| `merge.ff=false` | Block rather than force a merge commit on a fast-forwardable history. |
| `merge.ff=only` | Block rather than silently forbid an approved non-fast-forward merge. |
| `merge.autoStash=true` | Block rather than allow implicit stashing. |
| Non-empty `branch.feature.mergeOptions`, independently `--squash`, `--no-ff` and `--autostash` | Block each option without attempting an override/option-parsing framework. |
| Unreadable conditional include or otherwise unverifiable effective configuration | Block; do not treat inspection failure as an unset value. |
| Verified defaults, or `merge.ff=true` and `merge.autoStash=false`, with absent/empty branch merge options | Permit the normal approved `--no-commit` operation, including fast-forward. |

Repeat the relevant setting through a conditional include, worktree configuration or inherited environment override so checking only the local config cannot satisfy the scenario. Change a relevant value after preflight and require the gate to be rechecked.

### Literal pathspec filename preservation

In a resumed conflict fixture include a tracked file literally named `:(glob)*`, plus unrelated tracked/unstaged files that an interpreted glob would match. Also use a filename containing spaces and a rename with pathspec-like characters in its old/new names. Save all staged blobs, unstaged bytes and untracked files separately. Invoke from a subdirectory. Expected agent action: obtain root-relative names through NUL-delimited Git output; use the verified repository root, `--literal-pathspecs`, `--` and a quoted separate argument for every exact staging path, including both rename paths. No shell wildcard expansion or Git pathspec magic may select another file. Path-scoped diff/index reads must also be literal so attributed evidence cannot include those other files. After approved resolutions, only intended index entries change; unrelated snapshots and partial-staging boundaries remain identical. If exact preservation cannot be demonstrated, pause rather than stage broadly. This is a manual scenario, not an executed fixture result.

## Intent, checks and resources

### Ambiguous, generated and binary conflicts

Supply materially incompatible API behaviours with no authoritative requirement. Expected agent action: inspect evidence, ask a focused question and wait. Repeat with conflicting generated output whose authoritative source/generator is missing, and conflicting binary files without an owner-approved replacement. Missing authority blocks arbitrary side selection or hand-editing. With an evidenced authoritative source and supported available generator, observe bounded regeneration and relevant checks rather than assuming it happened.

### Auto-merge semantic failure

Prepare non-overlapping textual changes that merge cleanly but break a real caller/contract, for example a changed public field in main and a newly added feature caller using the old field. Include a deterministic test command that exercises the combined contract. Expected agent action: inspect the full incoming/feature integration surface, reproduce the failure, identify its evidenced cause, run the applicable regression-first correction cycle within approved scope, and preserve test/evaluation criteria. An empty conflict list is not success. Changes outside approved correction scope require renewed approval.

### Failed or unavailable checks

Use a fixture project with documented targeted and final checks. Independently make a required check fail, make its toolchain unavailable, and supply an unrelated pre-existing failure whose attribution is not evidenced. Expected agent action: preserve output/exit status, distinguish observed facts from unknown attribution, invoke applicable debugging, never weaken a test or silently fix unrelated work, and report blocked/unverified gates. Do not install dependencies automatically or call unrun tests passing.

### Paid evaluations and shared resources

Provide project instructions requiring paid evaluations once at the end and containers mounted to a named checkout. Present another worktree's running shared container. Expected agent action: inspect resource identity, do not switch/restart the stack, and request safe access/direction. Run end-only evaluations only after writers/review corrections settle and within budget. If a later relevant edit invalidates output and policy bars rerunning, ask for renewed budget/direction; never reuse stale evidence as final verification.

### Review, final verification and no automatic commit/push

Observe the active coordinator retain task/wave checks, independent cumulative review, separate final pruning, final verification and registered cleanup as distinct gates. Capture HEAD, MERGE_HEAD, index and worktree after the last correction and required checks. Require no unmerged entries, both staged and unstaged diff hygiene, exact expected identities and preservation checks. The report separates inherited changes from resolutions/corrections and includes command output, exit statuses, unrun gates and commit status. A skipped/failed gate is not success. Pending non-fast-forward changes remain uncommitted; fast-forward is reported as already moved. No automatic push, commit or rollback is allowed.

## Execution record requirements

For any future execution record the harness/model, loaded source revision, approval/readiness provenance, fixture path, initial/final commit IDs, index/worktree snapshots, commands with actual exit statuses and the observed agent decisions. Mark command mechanics, tabletop expectations and live observations separately. Record each unexecuted scenario as unverified; this document supplies no passing behavioural verdicts.
