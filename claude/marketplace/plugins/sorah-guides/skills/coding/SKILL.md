---
name: coding
description: This skill should be used when writing or reviewing code in any language. Provides language-agnostic coding conventions for code quality, comments, error handling, and formatting. Project-specific conventions always take priority.
version: 0.2.0
---

# General Coding Guidelines

Language-agnostic coding conventions applicable across all projects. Project-specific conventions (CLAUDE.md, style guides) always take priority over this guidance.

## Code Quality

- Do not leave empty lines containing only whitespace
- Write clean, readable code that follows the language's established conventions
- Use consistent indentation and formatting

## Code Comments

Comments must not repeat what the code already expresses. Use comments to explain **why** something is done, or to record context that cannot be recovered from the code itself.

Three rules govern everything below.

**Write for a stranger reading the file, not a reviewer reading the diff.** The reader has never seen the pull request, the spec, the ticket, the review discussion, or the previous version of the code. A comment that only makes sense with that context is noise to everyone else.

**Keep them short.** Default to a single line. Use two or three only when one genuinely cannot carry the constraint. This applies to doc comments too: a class or method doc comment states what the thing is and what it guarantees, in a sentence or two. It is not a design document.

**Avoid narrative.** A comment states a fact. It does not build to a point, weigh alternatives, or qualify itself. Punctuation is a reliable tell: reaching for an em dash, a semicolon, or a colon that introduces an explanation is the signal to stop and cut, not to keep writing. So is a second sentence opening with "But", "So", "Note that", or "In practice".

**When to comment:**

- To explain why a non-obvious approach or workaround was chosen
- To clarify intent when the code could be misread or misunderstood
- To record an external constraint (protocol, spec, upstream bug, API quirk) the code must satisfy
- To document an assumption, edge case, or limitation a reader would otherwise have to rediscover

**When not to comment:**

- Do not narrate what the code is doing, the code already says that
- Do not duplicate function or variable names in plain English
- Do not leave stale comments that contradict the code
- Do not reference removed or obsolete code paths

**Never write these:**

- **Change narration.** Anything phrased against a previous state of the code: "now falls back to ...", "no longer needed", "same answer as before", "pre-existing behaviour". The comment outlives the change. The diff and the commit message own that story.
- **Retold discussion.** Summarising the spec, the ticket, or the review instead of citing it: "beyond what the spec anticipated", "as discussed", "which is accepted", "the spec called this out".
- **Alternatives-considered essays.** Defending the chosen design against a design that is not in the file, or explaining at length why some other class was not extended instead.
- **Tutorial voice.** Addressing a future implementer rather than a reader: "the obvious implementation is X and it is wrong", "a consumer that wants Y calls Z".
- **Speculative threat or failure narratives.** Name the risk in a clause. Do not write out the attack or the hypothetical incident.
- **Inventories of sibling code.** Listing the other classes that do the same thing, or asserting what none of them do. It goes stale silently, and grep answers it anyway.
- **Markdown emphasis** (`**bold**`, `*italics*`) inside comments.

Test and spec files follow the same rules. Let the example name carry the intent instead of narrating the setup.

When the rationale is genuinely valuable but too long for a line or two, it belongs where a reader will look for it: the pull request description, the commit message, `docs/`, or the spec.

**Cite a discussion rather than retelling it.** A bare reference to a pull request, a GitHub or Linear issue, or an upstream bug is the compact form of context too large for a comment, and beats a paragraph whenever the reasoning behind the code is genuinely complex: `# Bound set from the measurements in #1234.` The reference still has to earn its line. Straightforward code with nothing hidden behind it gets no comment and no link.

**Example.** The same fact, before and after:

```ruby
# Retries with a fresh connection rather than reusing the pooled one — the
# pooled connection is what went stale in the first place, so reusing it is
# the obvious implementation and it is wrong: the second attempt then fails
# exactly as the first did, which is what happened before this changed.
```

```ruby
# A pooled connection may be stale, so the retry opens its own.
```

## Error Handling

- Avoid blanket exception handling unless absolutely necessary — error logging is typically handled by the runtime or framework
- Prefer letting exceptions propagate up the call stack
- Only catch specific exceptions when there is a meaningful reason:
  - Adding context to the error
  - Performing cleanup operations
  - Converting one exception type to another with additional information
  - Recovering from expected error conditions
