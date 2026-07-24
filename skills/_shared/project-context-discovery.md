# Project Context Discovery

This shared procedure applies to skills that perform project context exploration before proposing an implementation design. It helps agents find existing project documentation, architecture notes, ADRs, and related design context without turning discovery into an unbounded documentation audit.

Skills that explore project context **SHOULD** run this procedure after they understand the brief and before they propose design choices. Skills **MAY** run the narrowed revisit pass once later code exploration identifies an affected subsystem, framework, or architecture area.

## Purpose

Project documentation and ADRs can contain constraints that are not obvious from the current code. During planning, agents **MUST** consider relevant existing design context before proposing changes that affect architecture, public interfaces, operational behaviour, data flow, or developer workflows.

This procedure is intentionally bounded. It is not a request to read every document in a repository.

## Scope

This procedure covers discovery and use of existing project documentation during planning. It **MUST NOT** create temporary files or summaries on disk.

This file is the single shared project-context procedure for calling skills. Repository-local findings remain the default source of truth. Confluence discovery is optional, bounded, and non-blocking.

## When To Run

Run the first pass after the skill has enough understanding of the brief to form search terms, but before design alternatives are finalised.

Run the optional second pass only when code exploration reveals a narrower area that may have dedicated documentation, such as:

- A subsystem name
- A framework or integration name
- A package, module, service, or bounded context
- A data model, protocol, API, or deployment area
- An architecture pattern or decision family

## Discovery Targets

Search common documentation and decision locations first:

- `README*`
- `docs/**`
- `doc/**`
- `adr/**`
- `adrs/**`
- `architecture/**`
- `decisions/**`
- `rfcs/**`

Also search for filenames containing these terms, case-insensitively where the tooling supports it:

- `ADR`
- `decision`
- `architecture`
- `design`

The search **SHOULD** also include brief-specific terms once known, such as the feature name, subsystem name, framework name, or affected domain language.

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

## Bounded Search Procedure

1. Identify two to six search terms from the brief. Prefer concrete nouns from the requested change over generic terms.
2. Use targeted glob searches for likely documentation paths and names. Do not recursively read broad trees.
3. Use grep searches inside likely documentation paths for the brief-specific terms.
4. Inspect filenames, directory names, and headings before reading full documents where possible.
5. Read short directly relevant documents fully.
6. For long or partially relevant documents, read the table of contents, headings, summary sections, and the sections matching the brief. Summarise only the relevant parts into conversation context.
7. Stop once you have enough context to identify applicable constraints, prior decisions, or the absence of relevant documentation.

If a search returns many results, the agent **MUST** narrow before reading by using the brief, the affected subsystem, recent code exploration, or more specific terminology. Reading every result from `docs/**` or similar broad trees is forbidden.

### Optional Confluence Branch

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

### Deterministic Confluence Scoring

Confidence scoring **MUST** be deterministic and based on observed signals, not intuition.

#### Space Scoring

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

#### Page Scoring

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

## Two-Pass Model

### First Pass: Lightweight Brief-Based Discovery

After understanding the brief, run a lightweight pass that answers:

- Is there a README or project overview that affects this work?
- Is there documentation for the feature area or subsystem named in the brief?
- Are there ADRs, RFCs, architecture notes, or design documents that appear relevant?

This pass **SHOULD** be fast and targeted. Its purpose is to avoid missing obvious documented constraints before design work starts.

### Optional Second Pass: Narrowed Revisit

After code exploration, run one narrowed revisit if a specific subsystem, framework, or architecture area emerges. This revisit **MUST** use the narrower terms from code exploration rather than repeating the broad first pass.

Examples:

- A brief mentions authentication, then code exploration identifies OAuth token rotation. Revisit docs for `oauth`, `token`, and the auth package name.
- A brief mentions background jobs, then code exploration identifies a queue adapter. Revisit docs for the queue technology, worker package, and deployment notes.
- A brief mentions API changes, then code exploration identifies an OpenAPI or SDK generation path. Revisit docs for API design, client generation, and versioning.

Do not run repeated discovery passes. If the second pass still leaves uncertainty, surface the uncertainty to the human partner instead of expanding into an unbounded search.

## Full-Text And Summary Handling

Agents **MUST** preserve useful source context in the conversation without flooding it.

- Read short directly relevant documents fully and cite their paths.
- For long directly relevant documents, read the relevant sections fully and summarise surrounding context.
- For broad or partially relevant documents, summarise only the parts that affect the current brief.
- Cite source paths for every constraint, prior decision, or design fact carried into the proposed design.
- Distinguish facts from documents from inferences made by the agent.

When summarising, include:

- The source path
- The relevant heading or section when available
- The decision, constraint, or convention that affects the current work
- Any uncertainty about freshness, scope, or applicability

## Handling Outcomes

### Confluence Disabled By Config

If `.opencode/project-context.json` sets `confluence.enabled` to `false`, skip Confluence entirely. Do not emit the harness note.

### Confluence Config Is Invalid Or Unsafe

If the repository-owned Confluence config is invalid, or any configured `rootPages` title resolves to zero or multiple pages, treat repository-owned scoping as unsafe for that run. If a safe harness-provided mapping still exists, continue with that mapping. Otherwise continue with repository context and emit the once-per-run harness note when Atlassian MCP is available.

### Confluence Discovery Is Medium Or Low Confidence

If Confluence discovery yields medium or low confidence for the chosen space or any selected page, do not auto-select Confluence pages. Continue with repository context. Emit the once-per-run harness note only when Atlassian MCP is available and no safe harness-provided mapping or validated usable repository-owned config is already in use.

### No Safe Confluence Mapping Available

If Atlassian MCP is available but there is no safe harness-provided mapping or usable repository-owned config to scope Confluence safely, continue with repository context and emit the once-per-run harness note. If Atlassian MCP is unavailable, skip the note.

### No Relevant Documentation Found

If no relevant documentation is found after the bounded first pass, state that explicitly in the design context and continue with code exploration. Absence of documentation is not proof that no constraints exist.

### Documentation Is Broad Or Irrelevant

If documentation exists but is too broad or irrelevant to the brief, cite the inspected paths and explain why they do not affect the design. Do not read broad documents in full unless they are short and clearly relevant.

### Documentation Conflicts With Code Or Other Documentation

If documentation conflicts with current code, another document, or the user's approved direction, agents **MUST** surface the conflict before relying on either source. The report **SHOULD** include:

- The conflicting source paths
- The specific disagreement
- Any freshness signals such as dates, ADR status, changelog entries, or code ownership hints
- The proposed way to resolve the conflict, or a request for human direction when resolution would affect scope

Do not silently choose the source that is easiest to implement.

### Documentation Appears Stale

If a document appears stale, agents **SHOULD** treat it as context, not authority. Freshness signals include document dates, ADR status, links to removed code, references to old package names, or code that no longer matches the described architecture. Cite the stale source and explain the uncertainty.

### Search Tools Are Unavailable

If glob or grep tooling is unavailable, use the most targeted available alternatives, such as listing top-level directories, reading known README files, or using language and shell tools already available in the environment. Keep the search bounded and report the limitation. Do not compensate for missing search tools by reading entire documentation trees.

### Merge Behaviour For Successful Confluence Discovery

When Confluence discovery succeeds safely, the calling skill **MUST** append a separate Confluence context note after the local repository findings. Local code and local documentation remain primary when they conflict with Confluence. The Confluence note is supplementary context, not authority over the repository.

## Output To The Calling Skill

The calling skill **MUST** carry forward a concise project-context note containing:

- Relevant documents found, with paths
- Relevant decisions, constraints, and conventions
- Documents inspected and found irrelevant, when that prevents repeat searching
- Conflicts, staleness, or uncertainty
- Whether the optional second pass was run and what narrowed terms it used

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

This note lives in conversation context only. It **MUST NOT** be written to temporary files or a context cache by this procedure.
