# ADR-0024: How GitHub Actions workflows are named

- **Status**: Proposed (2026-10-27)
- **Date**: 2026-10-27
- **Tags**: github, ci, conventions
- **Scope**: user (applies to all personal repos)

## Context

An agent reading CI status is the common case now, and two workflows that share
a display name are a trap for that reader. In one repo, `terraform.yaml` (the
plan/apply pipeline) and `terraform.yml` (fmt, tflint, trivy) both declared
`name: Terraform`. `gh pr checks` listed four green checks and exited, and the
Terraform run was reported as passing. It was the lint workflow. The pipeline
had not started, and when it did, one job failed. The only field that tells the
two apart is `path` in the Actions API, which `gh run list` and `gh pr checks`
do not show.

The collision was in one repo and has been fixed there. The convention is what
was missing, and without it the next repo that adds a second workflow for the
same tool lands in the same place.

## Decision

**Name a workflow for what it does, not for the tool it runs.**

1. **`<tool>-<role>.yaml`** wherever a tool has more than one workflow:
   `terraform-pipeline.yaml`, `terraform-lint.yaml`. A tool with a single
   workflow may stay bare (`actionlint.yaml`).
2. **The top-level `name:` is the filename in title case**: `Terraform
   Pipeline`, `Terraform Lint`. **No two workflows in a repo share a `name:`.**
3. **`.yaml` for new workflows, and for any workflow being renamed anyway.** Do
   not rename an existing `.yml` file solely to change its extension. The
   extension only made the colliding pair look alike in a directory listing;
   rules 1 and 2 are what prevent a recurrence. The estate keeps a permanent
   mix of `.yml` and `.yaml`, and nobody opens a sweep-up issue on the strength
   of this rule.
4. **No `_` prefix for reusable workflows.** The underscore marked "not directly
   triggered" in repos where triggered and callable workflows sat side by side.
   Once application repos call one shared reusable workflow instead of carrying
   a local copy, almost none has a `workflow_call` target left, and the role
   suffix already says what a workflow is for (`terraform-apply` against
   `terraform-job`). Existing underscore-prefixed files are not renamed (rule
   3's reasoning), and a repo that still has a local `workflow_call` target may
   keep the prefix.

### What a rename may and may not touch

**Renaming a workflow file, or its top-level `name:`, is safe. Renaming a
`jobs.*.name` is not.** Branch-protection required status checks are keyed on
job names, so a renamed job leaves pull requests blocked on a context that will
never report again. Confirmed in both directions by the rename that fixed the
collision: the file and workflow names changed and the required contexts did
not move.

The tempting tidy-up is exactly the breaking move. A workflow named `Terraform
Lint` that contains a job named `Terraform Lint` looks like a mistake and is
not: only jobs produce check contexts, so the workflow name never appears in the
checks list and the duplication is invisible. **Do not "fix" it.**

A reusable workflow that other repos call by `uses:` is pinned by SHA in every
caller. Renaming it means every caller's pin moves in lockstep, so spend that
cost during a conversion that is touching the callers anyway, never as its own
change.

## Consequences

- A reader, human or agent, can tell what a workflow is from its name alone, and
  two workflows never present as one.
- The convention applies to new and renamed workflows only, so nothing has to be
  swept up. Existing files that do not conform are left alone unless they are
  being renamed for another reason.
- Rule 4 is the one point that was a judgement call rather than a derivation. It
  is recorded here as proposed, and reversing it costs only a note in this
  record.

## References

- Issue #366, where the collision, the rename that fixed it and the `.yml`
  decision were worked out
- [ADR-0015](0015-tiered-adrs.md): why this is user tier, not repo tier
