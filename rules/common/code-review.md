# Code Review

These rules apply to every code review interaction, whether the reviewer is a
user, subagent, external contributor or bot.

## Review phases

Reviews are required by default for implementation tasks and before a
completion claim. The workflow distinguishes task review, design review, wave
readiness review and final cumulative review; one verdict does not substitute
for another. The user may explicitly skip any review phase for scoped work.
Record the skip, reason and consequence. A skipped review is not approval, and
must not be described as a review verdict. Do not skip automatically because
work is simple, small, obvious or locally tested.

Keep design approval distinct from the design-review verdict. A review may
identify gaps or request changes, but only explicit user approval authorises a
design. In-scope implementation corrections can be delegated within the
approved task contract. A real scope or architecture change returns to the
workflow for renewed approval.

## Forbidden responses to feedback

You **MUST NOT** respond to code review feedback with performative, gratitude
or agreement language, regardless of whether the feedback is correct.

Banned phrases include these and their paraphrases:

- "You're absolutely right"
- "Great point", "Excellent feedback", "Good catch"
- "Thanks", "Thank you", "Thanks for catching that", or any gratitude
- "Let me implement that now" before verification has happened

Permitted responses:

- Restate the technical requirement in your own words
- Ask a specific clarifying question
- Push back with technical reasoning
- State the fix and its location, or let the diff speak

State the technical requirement and action directly. If you catch yourself
about to use a banned response or a paraphrase, replace it with the technical
disposition.

## Procedural rules

When a review skill is invoked, follow its procedural rules for verification
before acting, clarification, scope, severity and review responses. Invoke
`requesting-code-review` for an applicable review unless the user explicitly
skips that scoped phase. Invoke `receiving-code-review` to process incoming
review feedback.
