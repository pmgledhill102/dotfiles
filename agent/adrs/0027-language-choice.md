# ADR-0027: Language choice for new code

- **Status**: Accepted (2026-11-21)
- **Date**: 2026-11-21
- **Tags**: languages, standards
- **Scope**: user (applies to all personal repos and agent surfaces)

## Context

Nothing in the agent policy said which language to write new code in, so an
agent chose by habit. For a quick script, the habit is Python.

That cost an afternoon once. A session extending a project whose scripts are
all Perl wrote a new helper in Python. The owner rejected it, and it was
rewritten in Perl to match. The rewrite, the re-test and the re-upload took
about an hour, and the discarded file could not be removed from the store it
had already been uploaded to.

The owner's position, in his words at the time: Python is disliked, but "it
should still be used where it is the absolute best language to use for a
requirement", with machine learning and many AI uses as the examples. By
default, for scripts, services, daemons and websites, he would prefer it not
be used.

Parts of the answer already existed, unstated or stated elsewhere:

- New services in the estate are written in Go.
- The agent policy's Shell Scripts rules already make POSIX `sh` the target
  for scripts.
- [ADR-0026](0026-front-end-stack-standard.md) makes TypeScript mandatory
  wherever JavaScript would be written.

What was missing was one place that says so, and a statement of where Python
fits.

## Decision

### 1. A default by kind of work

| Kind | Language |
| --- | --- |
| Services, command-line tools and daemons | Go, standard library first |
| Scripts | POSIX `sh`, per the Shell Scripts rules in the agent policy |
| Anything in a browser | TypeScript, per [ADR-0026](0026-front-end-stack-standard.md) |

### 2. Python only where it is clearly the best tool

Python is used where it is clearly the best tool for the requirement:
machine learning, or an AI library whose best-supported SDK is Python. When
an agent picks it, it says why.

It is a dislike, not a ban.

### 3. Extending a project uses that project's language

This overrides the defaults in section 1. A helper added to a Perl codebase
is written in Perl.

### 4. Nothing is decided for other languages

No rule is written for Rust, Java or any other language, and they are not
ranked. A project that wants one decides for itself, in its own ADR.

## Alternatives considered

- **Ban Python.** Rejected by the owner: there are requirements it is the
  best tool for, and a ban would force a worse choice there.
- **A ranked order of every language.** Nothing calls for one yet. A rank
  with no case behind it is a rule nobody can defend.
- **Leave it to each project.** This was the position before, and it is how
  the rewrite described under Context happened.

## Consequences

### Positive

- An agent starting new code has a default, and no longer reaches for Python
  by habit.
- The rule for extending a project is stated, so a helper matches the code
  around it.
- When Python is chosen, the reason is on the record.

### Negative / trade-offs

- "Clearly the best tool" is a judgement. The stated reason is what makes a
  poor one visible.
- Some scripts are longer or harder to read in `sh` than they would be in
  Python. Where a script outgrows `sh`, the default for a tool is Go.
- Existing Python is not scheduled for conversion. Section 3 applies to it:
  a project already in Python is extended in Python.

### What this does not decide

- Any preference among languages other than those named here.
- Which libraries or frameworks to use within a language, beyond "standard
  library first" for Go and what ADR-0026 says for the front end.

## Revisit triggers

- Agents choose Python with a stated reason that the owner keeps rejecting.
  Section 2's wording is too loose.
- Scripts written in `sh` under this rule keep being rewritten in Go. The
  line between a script and a tool needs stating.
- A second language starts to be reached for by habit, as Python was. It
  needs a rule of its own.
- The with and without comparison in
  [`evals/guidance/`](../evals/guidance/README.md) shows the rule makes no
  difference on a current model. It is then a candidate for removal from the
  always-loaded policy.

## References

- [#772](https://github.com/pmgledhill102/agentic-coding-config/issues/772):
  the question, and the owner's decision in its comments
- [ADR-0026](0026-front-end-stack-standard.md): the front-end stack, which
  holds the browser half of this decision
- [ADR-0015](0015-tiered-adrs.md): why this is a user-tier decision, and how
  a repo deviates from it
- [`evals/guidance/`](../evals/guidance/README.md): the suite that tests
  whether the rule changes behaviour, in the case `lang-quick-script`
