# Optional Confluence Discovery

This helper owns the optional Confluence config, schema, deterministic selection rules and outcomes. It is read only after repository discovery and only when Atlassian MCP is available and the repository config has not explicitly disabled Confluence. Confluence discovery supplements, not replaces, repository discovery.

## Repository-Owned Config

If the harness has Atlassian MCP available, the procedure **MAY** also use an optional repository-owned config file at `.opencode/project-context.json` to scope Confluence discovery. The config **MAY** contain a `confluence` object with these fields:

- `enabled`: boolean. `false` skips Confluence entirely for that run.
- `space`: string. The preferred primary Confluence scope.
- `rootPages`: array of page titles. These are guarded entry points and **MUST** resolve to exactly one page each before use.
- `labels`: array of label strings used to narrow candidate pages inside the chosen scope.

Example:

```json
{
  "confluence": {
    "enabled": true,
    "space": "ENG",
    "rootPages": ["Platform Architecture", "ADR Index"],
    "labels": ["architecture", "adr"]
  }
}
```

Malformed JSON, wrong field types, or any other parse or validation failure make the repository-owned Confluence config invalid for that run. A usable repository-owned config requires `space`, or `rootPages` together with a validated `space` or safe harness-provided mapping. `labels` alone, `rootPages` alone, or `enabled: true` with no scoping fields, is invalid for repository-owned scoping in that run.

## Optional Confluence Branch

Confluence discovery is an optional branch that supplements, not replaces, repository discovery.

1. Run repository discovery first.
2. Consider Confluence only when Atlassian MCP is available and Confluence is not disabled by config.
3. Use a harness-provided repository mapping when one exists. A harness mapping is validated when it resolves to exactly one Confluence space before page selection. A validated harness mapping is safe when it does not conflict with a higher-precedence valid repository-owned config. If `.opencode/project-context.json` is present, validate the `confluence` object before using it as repository-owned scope.
4. Repository-owned Confluence config is more specific than a harness-provided mapping. When both exist and disagree, valid repository config takes precedence. Invalid repository config does not block an otherwise safe harness mapping, but it is still unsafe for repository-owned scoping in the current run.
5. Treat `space` as the preferred primary scope when it is present.
6. If `rootPages` is configured, resolve each configured title inside the chosen space when a validated `space` or safe harness-provided mapping is available. `rootPages` alone do not establish scope. If no such scope is available, repository-owned scoping is unsafe for that run. If a safe harness-provided mapping still exists, continue with that mapping. Otherwise fall back to repository context with the harness note. Each configured title **MUST** resolve to exactly one page. If any configured title resolves to zero or multiple pages, repository-owned scoping is unsafe for that run. If a safe harness-provided mapping still exists, continue with that mapping. Otherwise fall back to repository context with the harness note.
7. If `space` is present without `rootPages`, run a bounded search inside that space using the brief-specific terms plus the standard documentation target terms from this procedure, such as `ADR`, `decision`, `architecture`, and `design`. Do not perform an unbounded crawl of the space.
8. Use configured `labels` only as narrowing signals within the chosen scope. They **MUST NOT** widen the search beyond the chosen space or resolved root pages.
9. For space-only discovery, and for relevant pages selected within `rootPages`-guarded discovery, select at most 3 Confluence pages total. Configured `rootPages` are scope guards, not part of the 3-page cap unless a root page is itself selected as relevant context. Rank by page score, deduplicate by page ID, then order by descending score and page ID.
10. Auto-use Confluence only when the chosen space is high confidence and every selected page is high confidence. Medium or low confidence **MUST NOT** auto-select and **MUST** fall back safely.
11. Keep the Confluence branch bounded and non-blocking. If safe scoping cannot be established quickly, continue with repository context.

## Deterministic Confluence Scoring

Confidence scoring **MUST** be deterministic and based on observed signals, not intuition.

### Space Scoring

Score candidate spaces as follows:

- +4 if the candidate exactly matches configured `space` and resolves to a unique space
- +4 if the candidate exactly matches a validated harness-provided mapping and resolves to a unique space
- +2 if the candidate name or key exactly matches a brief term or standard documentation target term
- +1 if the candidate is the only returned space after applying configured scope and brief terms
- -2 if multiple candidate spaces remain tied on the same best signals

Thresholds:

- High confidence: score 4 or more, with no tie for the best score
- Medium confidence: score 2 to 3, or any tied best score
- Low confidence: score 1 or less

### Page Scoring

Score candidate pages as follows:

- +4 if the page title exactly matches a configured `rootPages` entry
- +2 if the page title exactly matches a brief term or standard documentation target term
- +1 for each matching configured label, up to +2 total
- +1 if the page is a direct child of a resolved root page
- -2 if the same title resolves to multiple pages within the active scope

Thresholds:

- High confidence: score 4 or more, with a unique page ID after deduplication
- Medium confidence: score 2 to 3
- Low confidence: score 1 or less

If scoring produces medium or low confidence for the chosen space or any selected page, do not auto-use Confluence for that run.

## Handling Outcomes

### Confluence Disabled By Config

If `.opencode/project-context.json` sets `confluence.enabled` to `false`, skip Confluence entirely. Do not emit the harness note.

### Confluence Config Is Invalid Or Unsafe

If the repository-owned Confluence config is invalid, or any configured `rootPages` title resolves to zero or multiple pages, treat repository-owned scoping as unsafe for that run. If a safe harness-provided mapping still exists, continue with that mapping. Otherwise continue with repository context and emit the once-per-run harness note when Atlassian MCP is available.

### Confluence Discovery Is Medium Or Low Confidence

If Confluence discovery yields medium or low confidence for the chosen space or any selected page, do not auto-select Confluence pages. Continue with repository context. Emit the once-per-run harness note only when Atlassian MCP is available and no safe harness-provided mapping or validated usable repository-owned config is already in use.

### No Safe Confluence Mapping Available

If Atlassian MCP is available but there is no safe harness-provided mapping or usable repository-owned config to scope Confluence safely, continue with repository context and emit the once-per-run harness note. If Atlassian MCP is unavailable, skip the note.

### Merge Behaviour For Successful Confluence Discovery

When Confluence discovery succeeds safely, the calling skill **MUST** append a separate Confluence context note after the local repository findings. Local code and local documentation remain primary when they conflict with Confluence. The Confluence note is supplementary context, not authority over the repository.

## Output To The Calling Skill

If Confluence discovery succeeded safely, append a separate Confluence context note after the repository note, including:

- The Confluence space used
- The selected pages, with titles and page IDs
- The confidence level for the chosen space and each selected page
- Any labels or root page constraints that shaped the selection

The procedure **MUST** show this harness note at most once per run, and only when Confluence could help but is not safely scoped:

- Atlassian MCP is available but there is neither a safe harness-provided mapping nor a validated usable repository-owned config
- Confluence discovery is medium or low confidence without a safe harness-provided mapping or validated usable repository-owned config already in use
- The Confluence config is invalid and no safe harness mapping remains
- A configured `rootPages` title resolves to zero or multiple pages and no safe harness mapping remains

Do not show the note when Confluence is disabled, when a valid mapping or valid config is in use including `space`-only config, or when Atlassian MCP is unavailable.

Harness note copy:

> Confluence context is available but not safely scoped for this run. If this repository has a stable Confluence mapping, add `.opencode/project-context.json` with a `confluence` object such as `{ "enabled": true, "space": "<space>", "rootPages": ["<page title>"], "labels": ["<label>"] }`. `space` is the preferred primary scope, `rootPages` pins exact entry pages, `labels` further narrow candidates, and `enabled: false` disables Confluence for this repository.

This note is returned in conversation context only and is not written to scratch files or a context cache by this procedure. If relevant to the active workflow, the coordinator may include it in registered `research.md` under the workflow artefact contract.
