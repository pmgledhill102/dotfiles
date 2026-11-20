# ADR-0020: Tool-selection criteria, and how to break them

- **Status**: Accepted
- **Scope**: Repo. This record binds `dotfiles` only. It sets the test for a
  tool this repo installs, which would bind nothing if the repo were archived.
- **Date**: 2026-11-20
- **Tags**: packages, dx
- **Refs**: [#509](https://github.com/pmgledhill102/dotfiles/issues/509)

## Context

`specs/REQUIREMENTS.md` lists principles for the repo as a whole:
idempotence, portability, simplicity. Individual ADRs record single choices,
such as Starship over Oh My Posh (ADR-0006) or Colima over Docker Desktop
(ADR-0018). Nothing states the test a tool has to pass to be installed at
all.

Without one, tools accumulate. Each addition is reasonable on the day, and
nothing asks later whether it still earns its place. There is also no
yardstick for a tools review, so a review ends up as a matter of taste.

## Decision

Every tool this repo installs is held to the seven criteria below. That
covers Homebrew formulae and casks, apt and winget packages, npm globals, and
shell plugins. A tool that fails a criterion can still be installed. The
failure is then recorded as an **exception** and is not left implicit.

### The criteria

| # | Criterion | Test |
| - | --------- | ---- |
| 1 | **Lightweight** | No background process unless running one is the tool's job. Adds no noticeable time to shell startup: measure with `time zsh -i -c exit` before and after, against the under-1-second budget in `specs/REQUIREMENTS.md`. Pulls in no language runtime the machine would not otherwise need. |
| 2 | **Current** | A release in the last 12 months. The repository is not archived. Homebrew does not mark the formula deprecated or disabled. Commit activity alone does not count, because bots commit to abandoned projects too. |
| 3 | **Well regarded** | Broadly used. Homebrew's 365-day install count is the first signal, and GitHub stars the second. Maintained by the original project or its recognised successor, not by a little-known fork. |
| 4 | **Cross-platform** | Installable on macOS and Linux, and on Windows where the tier has Windows, through the package manager ADR-0004, ADR-0017 and ADR-0019 assign. A tool whose job only exists on one platform (`xcodes`, `tart`) passes; that is not an exception. |
| 5 | **No duplicates** | One tool per job. A second tool for the same job has to name what the first cannot do. |
| 6 | **Plain-text config** | Any configuration the tool needs lives as a text file chezmoi manages, not only in a GUI or a database. |
| 7 | **Easy to remove** | Removing the tool means deleting its package line and a shell block guarded by `command -v`. Nothing else breaks when it is gone. |

### Exceptions

A tool may break any criterion when its value justifies the cost. The cost
is then written down **next to the line that installs the tool**, so anyone
removing or reviewing it sees the trade-off without having to look for it:

```text
# ADR-0020 exception (1 Lightweight): pulls in Python and ~16 dependencies.
# Earns it: the only way to OCR scanned PDFs from the command line.
brew "ocrmypdf"
```

An exception names the criterion it breaks, by number and name, and says
what the tool provides that justifies the cost. "We use it" is not a reason.
"Nothing else does X" or "the alternative costs more in Y" is.

### When the criteria are applied

- **On every addition.** A PR that adds a tool says in its description that
  the tool passes all seven criteria, or adds the exception comment.
- **In a periodic review**, roughly every six months, tracked as a GitHub
  issue. The review checks each installed tool against the criteria and
  produces one of three outcomes: keep, keep with an exception recorded, or
  remove. Currency (criterion 2) drifts, so it is the one most worth
  re-checking.

## Consequences

- Tool choices have a stated yardstick, and a review becomes a checklist
  rather than a debate.
- Heavy or overlapping tools stay possible, but carry a visible cost line
  that invites the question again at the next review.
- Comments in the Brewfile and package lists grow. That is deliberate: the
  reason sits where the tool is installed.
- Shell-startup measurements need a real machine, so a review run from a
  cloud sandbox can flag startup suspects but cannot confirm them.

## Alternatives considered

- **Keep the principles implicit.** Rejected: this is the status quo, and it
  gave no basis for reviewing the current tool list.
- **Hard rules with no exceptions.** Rejected: several tools here (Docker,
  JDKs, ffmpeg) fail "lightweight" and still earn their place. A rule that
  had to be ignored would stop being read.
- **Record exceptions in a separate register file.** Rejected: a register
  drifts from the package lists it describes. A comment on the install line
  is deleted together with the tool.
