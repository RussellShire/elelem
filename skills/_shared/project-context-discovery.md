# Project Context Discovery

This shared procedure applies to skills that perform project context exploration before proposing an implementation design. It helps agents find existing project documentation, architecture notes, ADRs, and related design context without turning discovery into an unbounded documentation audit.

Skills that explore project context **SHOULD** run this procedure after they understand the brief and before they propose design choices. Skills **MAY** run the narrowed revisit pass once later code exploration identifies an affected subsystem, framework, or architecture area.

## Purpose

Project documentation and ADRs can contain constraints that are not obvious from the current code. During planning, agents **MUST** consider relevant existing design context before proposing changes that affect architecture, public interfaces, operational behaviour, data flow, or developer workflows.

This procedure is intentionally bounded. It is not a request to read every document in a repository.

## Scope

This procedure covers bounded discovery and use of existing project documentation during planning. The helper itself **MUST NOT** create scratch files, caches, or summaries on disk, and it does not own workflow state or lifecycle. It returns evidence and citations to the calling phase and coordinator. When the active workflow permits repository writes, the coordinator may persist approved findings in its registered `.elelem/workflows/<ticket-or-slug>/research.md`; in plan mode, use only authorised staging until materialisation is permitted.

This file is the single shared project-context procedure for calling skills. Repository-local findings remain the default source of truth. Confluence discovery is optional, bounded, and non-blocking. The procedure remains a helper, not a replacement for conversational Research or Planning.

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

### Optional Confluence Activation

Run repository discovery first. Consider the optional Confluence helper only when Atlassian MCP is available. If Atlassian MCP is unavailable, do not load the optional helper or emit its harness note. Before loading it, check `.opencode/project-context.json` for a valid JSON `confluence.enabled` value of boolean `false`; when that is present, skip Confluence entirely and do not load the helper or emit its harness note. When Atlassian MCP is available and this activation check has not found an explicit disable, resolve `./confluence-discovery.md` relative to the directory of the actually loaded `project-context-discovery.md`, not the current working directory or repository checkout. Read that sibling helper before using its schema or procedure. Do not rely on a link-only reference.

## Bounded Search Procedure

1. Identify two to six search terms from the brief. Prefer concrete nouns from the requested change over generic terms.
2. Use targeted glob searches for likely documentation paths and names. Do not recursively read broad trees.
3. Use grep searches inside likely documentation paths for the brief-specific terms.
4. Inspect filenames, directory names, and headings before reading full documents where possible.
5. Read short directly relevant documents fully.
6. For long or partially relevant documents, read the table of contents, headings, summary sections, and the sections matching the brief. Summarise only the relevant parts into conversation context.
7. Stop once you have enough context to identify applicable constraints, prior decisions, or the absence of relevant documentation.

If a search returns many results, the agent **MUST** narrow before reading by using the brief, the affected subsystem, recent code exploration, or more specific terminology. Reading every result from `docs/**` or similar broad trees is forbidden.

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

## Output To The Calling Skill

The calling skill **MUST** carry forward a concise project-context note containing:

- Relevant documents found, with paths
- Relevant decisions, constraints, and conventions
- Documents inspected and found irrelevant, when that prevents repeat searching
- Conflicts, staleness, or uncertainty
- Whether the optional second pass was run and what narrowed terms it used

When the optional Confluence helper is loaded and discovery succeeds safely, append its separate Confluence context note after the local repository findings. Confluence context is supplementary, not authority over the repository.
