---
name: detect-ticketing-system
description: Identifies which ticketing system the current project uses (GitHub Issues, Jira, GitLab, Linear, or none) by scanning available MCP tools, git remotes, and CLI binaries. Returns the detected system so a caller can pick the right API, or reports that no system is available so the caller can fall back.
metadata:
  model: openai/gpt-6-luna
  reasoning_effort: low
---

# Detect Ticketing System

This skill is a reusable detection capability invoked by `create-tickets`, `work-on-ticket`, and any other skill that needs to know where tickets live for the current project. It does not create or read tickets itself; it only identifies the system.

## Load the Ticketing Rules First

Before returning a system result to a ticketing consumer, read
`../_shared/tickets.md` relative to the directory of the actually loaded skill
using `{{READ_FILE_TOOL}}`. If it is missing or inaccessible, block the affected
action; do not use a checkout, history or link-only fallback.

## Result contract

Return one result with `status`, `system`, `matches`, `mechanism` and `evidence`. `status` is exactly one of `confirmed`, `candidate`, `ambiguous`, `unsupported` or `none`. Keep every detected match in `matches`, including its system, mechanism, evidence, confidence and whether that system is supported by this skill. Do not discard a lower-precedence match when it affects certainty. The summary `system`, `mechanism` and `evidence` describe the selected result; use `system: null` when no single system is selected.

Use the evidence precedence MCP > remote > CLI. An MCP match is a ticketing system, not an individual tool. A single supported MCP system is policy-confirmed, not proof of authentication or project access. A supported matching remote retains the current confirmed convention. A CLI-only result remains a candidate. Multiple unresolved matches are ambiguous. Azure DevOps and Bitbucket are detected but unsupported, not `none` and not actionable backends.

| Evidence scenario | Result | Resolution |
|---|---|---|
| one supported MCP | confirmed | select that MCP system; retain remote or CLI evidence without letting it override MCP |
| multiple MCP matches and a matching remote | ambiguous | retain every match; the remote does not resolve multiple MCP matches |
| one supported matching remote | confirmed | select that remote system |
| one CLI-only match | candidate | retain it as a candidate; do not auto-confirm |
| unsupported remote and supported CLI | unsupported | retain both matches; remote precedence does not authorise an unsupported backend or promote the CLI |
| no match | none | report no detected system |

For multiple matches at the winning evidence level, return `ambiguous` unless all matches are the same system and can be represented as one match. Preserve each match's confidence and support value. Never claim authentication, project visibility or ticket access based only on detected tools, remotes or binaries.

## Procedure

Inspect MCP tools, the origin remote and supported CLI binaries in precedence order. Do not stop before retaining lower-precedence evidence needed to explain a conflict or unsupported match. Apply the result contract above; this skill identifies evidence and does not call ticket APIs.

### 1. Available MCP Tools

Scan the MCP tools available in the current session for ticketing-system patterns:

| MCP Tool Pattern                    | System        |
|-------------------------------------|---------------|
| `mcp__*Atlassian*__*JiraIssue*`     | Jira          |
| `mcp__*github*__issue_*`            | GitHub Issues |
| `mcp__*linear*__*`                  | Linear        |
| `mcp__*gitlab*__*`                  | GitLab Issues |

Record every matching MCP system, its support status, confidence and evidence. A single supported MCP system has the policy-confirmed result described in the result contract. Multiple MCP systems remain ambiguous even when the remote matches one of them.

### 2. Git Remote

Inspect the origin remote as well, retaining it even when MCP evidence exists so conflicts and unsupported systems remain visible:

```bash
git remote get-url origin
```

| Remote contains | System        |
|-----------------|---------------|
| `github.com`    | GitHub Issues |
| `gitlab.com`    | GitLab Issues |
| `dev.azure.com` | Azure DevOps  |
| `bitbucket.org` | Bitbucket     |

A self-hosted instance (`github.mycorp.com`, `gitlab.internal`, on-prem Jira) may still match by substring. If the substring is ambiguous, record all plausible matches and mark the unresolved result ambiguous. Azure DevOps and Bitbucket are unsupported systems for this skill, but must remain detected unsupported matches.

### 3. CLI Binary Availability

Inspect supported CLI binaries as lower-precedence evidence, retaining them when a higher-precedence match exists:

| Binary | System        | Availability check |
|--------|---------------|--------------------|
| `gh`   | GitHub Issues | `command -v gh`    |
| `glab` | GitLab Issues | `command -v glab`  |

A CLI binary alone is weaker evidence than MCP tools or a matching git remote; a user may have `gh` installed without using GitHub Issues on this project. A unique CLI-only match is a candidate, not a confirmation. Multiple CLI-only systems are ambiguous.

## Worked Example

Session has the Atlassian MCP tools loaded (`mcp__Atlassian__getJiraIssue`, `mcp__Atlassian__createJiraIssue`, etc.), the git remote is `git@github.com:acme/widget.git`, and `gh` is installed.

1. MCP check: Atlassian Jira tools are present, no GitHub MCP tools. Jira is the sole MCP match.
2. Git remote check: `github.com` matches GitHub Issues, which is retained as lower-precedence evidence.
3. CLI check: `gh` is installed, which is retained as lower-precedence evidence.

Return: `{ status: "confirmed", system: "Jira", matches: [{ system: "Jira", mechanism: "MCP", confidence: "high", support: "supported", evidence: "Atlassian Jira issue tools are present" }, { system: "GitHub Issues", mechanism: "remote", confidence: "medium", support: "supported", evidence: "origin URL contains github.com" }, { system: "GitHub Issues", mechanism: "CLI", confidence: "low", support: "supported", evidence: "gh is installed" }], mechanism: "MCP", evidence: "One supported MCP system has precedence" }`.

Note that the git remote pointing at `github.com` did not override the Jira detection. A project can live in a GitHub repository while tracking tickets in Jira; the MCP tools reflect the user's actual ticketing workflow, so they win.
