---
name: env-conformance
description: 'Check that the platform behaviours this repo relies on still hold in this sandbox: run the capability-matrix probes, then answer the checks only the agent can make (is the composed policy in context, are the delivered skills listed), each with a negative control. Use when asked to check conformance, verify the environment, or test for platform drift.'
---

# Environment conformance

Some claims about the platform can only be checked from inside the agent's
own context. Is the container-written policy file loaded? Do
container-written skills appear in the skill list? A script cannot see your
context, so for these you report what you see and
`~/.claude/bin/env-conformance` checks it against the files on disk. The
design and the status meanings are in `docs/environment-conformance.md` in
`agentic-coding-config`.

## 1. Answer from context first, before reading any file

**Do these four before running any command or reading any file.** Answer
from what is already in your context: the system prompt, loaded policy and
the skill list. Do not use what a file read could tell you. Reading the file
first turns an observation into a copy, and the copy always passes.

**If this session has already read `~/.claude/CLAUDE.md`, a
`context/fragments/` file, or `~/.claude/skills/end-session/SKILL.md`, stop
here.** Report the agent checks as `unknown (context contaminated by a file
read)` and go to step 3. A verbatim quote is only evidence when it could not
have come from somewhere else.

Write down each answer exactly. Use the literal word `absent` when you
cannot see the thing. Never reconstruct or guess.

1. **`policy`**: in your loaded policy, find the heading **This container is
   the whole environment**. Quote the first eight or more words of the
   paragraph under it.
2. **`policy-control`**: the same for the heading **Conformance control
   heading**.
3. **`skill`**: in your list of available skills, find **`end-session`**.
   Quote the first eight or more words of its description.
4. **`skill-control`**: the same for the skill
   **`conformance-no-such-skill`**.

Items 2 and 4 are the negative controls. Neither exists anywhere, so the
right answer to both is `absent`. If you find yourself quoting text for
either, every answer from this step is suspect. Give your answers as you
have them anyway: the runner marks the check `unproven`, which is the
honest result.

## 2. Hand the answers to the runner

Put each answer in single quotes. If one contains a `'`, replace it with a
space; punctuation is ignored when comparing.

```sh
~/.claude/bin/env-conformance --agent --answer 'policy=<answer 1>' --answer 'policy-control=<answer 2>' --answer 'skill=<answer 3>' --answer 'skill-control=<answer 4>'
```

## 3. Run the script-checkable probes

```sh
~/.claude/bin/env-conformance
```

This is the full mode: every non-agent entry. It takes about 6 seconds and
only reads. Expect a few lines of proxy chatter about refused connections:
those are the negative controls, aimed at hosts that must be blocked.

## 4. Report

Give one summary that combines both runs:

- The `state=` line of each run.
- Every `FAIL`, quoted with its `invalidates:` line. That line names the
  decision, script or skill that is now unproven. Say which of them the
  current task relies on.
- Every `unproven` or `invalid` entry, and what it means for this run.
- The environment header line (date, os, CLI version, bootstrap sha), so the
  result can be dated.

On this surface, `unknown` and `not-applicable` are not failures. Say what
went unchecked and stop there.

## 5. Scheduled mode: only when invoked as `/env-conformance scheduled`

A weekly scheduled task invokes this skill in a fresh session
(`docs/runbooks/env-conformance-scheduled.md` holds its prompt and schedule).
A fresh session is the cleanest place for step 1, because nothing has read a
file yet. Do steps 1–4 exactly as above, then the following, all against
`pmgledhill102/agentic-coding-config` through the GitHub MCP tools.

**a. One issue per broken assertion, never two.** List the open issues once,
paging to the end (`list_issues` with `state: "OPEN"` and
`fields: ["number", "title"]`). Never use issue search: it is eventually
consistent, so it can miss an issue filed by last week's run. For each entry
that did not pass, look for an open issue with exactly this title:

| Status | Title | Labels |
| --- | --- | --- |
| `FAIL` | `Conformance drift: <id>` | `P1`, `type: bug` |
| `invalid` | `Conformance matrix invalid: <id>` | `P2`, `type: bug` |
| `unproven` | `Conformance unproven: <id>` | `P3`, `type: task` |

- **If one is open**, comment on it with this run's environment header and
  the entry's lines from the report.
- **If none is open**, create it, as a sub-issue of #260. The body holds the
  observed and expected values, the claim, the `invalidates:` line verbatim,
  the environment header, and one sentence on what the dependants mean for
  someone relying on them today.
- `unknown` and `not-applicable` file nothing.

**b. Log the run on #260.** Post one comment on #260, even if it is closed.
It holds the environment header, both `state=` lines, and either the issues
from (a) as links or the word `clean`. That comment is the dated record of
the last run, whatever happens to `measured=`.

**c. Refresh `measured=` once a month, and only after a clean run.** A clean
run means both runs report `state=ok`, with no `FAIL`, `unproven` or
`invalid`. Stamp only the ids that printed `pass`: an `unknown` entry was not
observed, so its date stays put. If the clean run qualifies, check whether
any passing entry's `measured=` is earlier than the current month (compare
`YYYY-MM`). If one is, and no open PR is titled
`Conformance: refresh measured= dates (<YYYY-MM>)`, then:

```sh
~/.claude/bin/env-conformance-stamp home/conformance/matrix.conf <YYYY-MM-DD> <passing ids...>
```

Run it in the `agentic-coding-config` checkout, on the branch this session
was assigned, or else on `claude/conformance-stamp-<YYYY-MM>` cut from
`main`. Commit only `home/conformance/matrix.conf`, push, and open that PR
with `Refs #260` and the environment header in the body. **Never merge it.**
If no checkout is available, skip this step and say so in (b) rather than
editing anything else.

**d. End with a summary**: the two `state=` lines, the issues filed or
commented on, and whether a stamp PR was opened. Someone reading the run
later should not have to open the issues to know whether anything broke.

## Guardrails

- **Never edit the matrix, the runner or the deployed files to make a check
  pass.** A FAIL means a recorded measurement no longer holds. Whether the
  claim, the matrix or what depends on it changes is for a human to decide.
  If the user asks for follow-up, file it as an issue on
  `pmgledhill102/agentic-coding-config` naming the failing entry ids.
  Scheduled mode files those issues itself (step 5a). Its date stamp (5c)
  is the one matrix write allowed: it changes only `measured=` on entries
  that just passed, and it goes through a PR a human merges.
- **Never retry step 1 after seeing a result.** A second answer, given
  after the runner said the first was wrong, is no longer an observation.
- On a workstation, or any surface other than a Claude cloud sandbox, both
  runs report `not-applicable`, because the matrix records sandbox behaviour
  only. Report that and stop.
