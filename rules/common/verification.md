# Verification

**You MUST NOT claim work is complete, fixed, passing, working, verified or
ready without evidence that the relevant check succeeded against the inputs
being claimed.** This applies to direct, hedged and implicit success claims,
including before a commit, moving to another task or handing work back.

Invoke `verification-before-completion` before such a claim. Its gate identifies
the claim, check, scope and relevant inputs; validates accessible execution
output, exit status, provenance, verifier independence and material environment
or resources; runs the affected check when evidence is absent or equivalence is
uncertain; reads and compares the result; and cites the actual output. A commit
alone does not identify dirty or untracked inputs. Self-reports, reviews and
structure checks do not replace independent inspection or required execution.

Evidence can be reused across messages or sessions only while its relevant
inputs and assumptions remain valid. Cite reused output as prior execution.
Relevant changes invalidate affected evidence; demonstrably unrelated changes
do not. Final integrated checks cover settled combined inputs after relevant
writers and corrections stop.

Only an explicit scoped user instruction may skip verification. Record its exact
source, scope, reason and consequence. The skipped scope remains unverified and
must never be described as passed, fixed, complete or ready. Other checks and
truthful reporting remain required.
