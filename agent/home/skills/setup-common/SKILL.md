---
name: setup-common
description: Set up the baseline development tooling for a project — pre-commit framework, gitleaks secret scanning, spell checking, Dependabot and the shared CI workflow. Run this first; the language-specific setup skills build on it.
---

# Set up common project tooling

## What to install and configure

### 1. EditorConfig

Create `.editorconfig` in the project root (if it doesn't already exist). If one exists, review it and suggest additions for any missing settings.

```ini
root = true

[*]
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
charset = utf-8
indent_style = space
indent_size = 2

# Go and Python both indent by 4, but they cannot share a section: gofmt emits
# tabs and has no option not to, so a Go file left on the `[*]` default of
# `space` puts the editor and the formatter in a fight from the moment this
# file is stamped.
[*.go]
indent_style = tab
indent_size = 4

[*.py]
indent_size = 4

[Makefile]
indent_style = tab
```

### 2. pre-commit framework

Create `.pre-commit-config.yaml` in the project root (if it doesn't already exist). If one exists, review it and suggest adding any missing hooks from below.

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v6.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: check-merge-conflict

  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.30.1
    hooks:
      # The v8.30.1 manifest lacks pass_filenames: false, and `gitleaks git`
      # takes no file arguments, so pre-commit's appended filenames fail every run.
      - id: gitleaks-system
        pass_filenames: false
```

Use the `rev:` shown, not the latest tag. It is the estate pin from agentic-coding-config's `cloud/precommit-warm.yaml`, which the cloud bootstrap pre-builds, so a new repo's first commit in a sandbox needs no hook build. Bumps go through that file.

Use `gitleaks-system`, not `gitleaks`. The plain id is `language: golang`, so pre-commit compiles gitleaks from source the first time it runs in a container, which takes about 30 seconds. The `-system` id runs the `gitleaks` binary on `PATH`; the workstation Brewfile and the cloud bootstrap both install it. It needs gitleaks 8.19 or later.

Keep `pass_filenames: false` on the hook. Without it, pre-commit appends the staged filenames to the command and `gitleaks git`, which takes at most one `[repo]` argument, exits 1 with `accepts at most 1 arg(s), received N` on every run that touches more than one file. This was reproduced on v8.30.1, the version the claim is verified for. If a later release's manifest sets it itself the line is redundant but harmless.

This hook is one of three gitleaks layers. Keep all three. On a personal account, GitHub's secret scanning and push protection are not available on private repos, so gitleaks is the only secret control those repos have:

- **The hook gives fast feedback.** It stops a secret before it becomes a commit, which is the only point where removing it is free. It only runs where pre-commit runs, though. A web edit on github.com, a fresh clone, or a `--no-verify` commit never meets it.
- **The CI job (step 7) is the layer that can't be skipped.** It runs on the server for every push and PR, whatever the committer's machine had installed. It scans only the commits being pushed, though.
- **The scheduled history scan (step 7) covers what both of those miss.** A secret committed before the hook existed, or one that got past both layers and was later deleted, is in history but not in any diff. So the diff-shaped layers report the repo as clean.

Do **not** run `pre-commit install` — nothing should write to `.git/hooks`. The config file is the source of truth, and it is enforced from two directions: a global pre-tool hook runs pre-commit on every `git commit`/`git push` the agent makes, and CI runs the same scanners as jobs of their own on every push (step 7). CI does not run pre-commit itself, so a `-system` hook needs nothing installed on the runner. Manual terminal commits are CI-backed. Mention this model in the closing summary so the user knows why no git hook was installed.

If `pre-commit` is not installed, tell the user to install it (`brew install pre-commit`) and stop.

When adding hooks for a tool that is already a project or system dependency (prettier, eslint, golangci-lint, …), prefer a `repo: local` hook invoking the project's own binary over a `pre-commit/mirrors-*` repo — the mirrors pin their own copy of the tool, so the hook and the project can silently run different versions (and several mirrors are archived).

### 3. cspell (spell checking)

Create `cspell.json` in the project root (if it doesn't already exist). If one exists, review and suggest additions.

```json
{
  "version": "0.2",
  "language": "en-GB",
  "files": "\\.(md|txt|rst|yaml|yml)$",
  "ignorePaths": [
    "node_modules",
    "go.sum",
    "*.lock",
    ".git"
  ],
  "words": [
    "actionlint",
    "aquasecurity",
    "bandit",
    "brakeman",
    "bridgecrewio",
    "checkov",
    "chezmoi",
    "chezmoiexternal",
    "cleanups",
    "clippy",
    "coreutils",
    "cspell",
    "dependabot",
    "dotnet",
    "editorconfig",
    "errcheck",
    "eslint",
    "footgun",
    "frontmatter",
    "gitleaks",
    "godoc",
    "gofmt",
    "gofumpt",
    "goimports",
    "golangci",
    "gomod",
    "gosec",
    "gotchas",
    "govet",
    "govulncheck",
    "hadolint",
    "handoff",
    "hashicorp",
    "ineffassign",
    "jsdoc",
    "linters",
    "lockfiles",
    "markdownlint",
    "mkdocs",
    "mypy",
    "nuget",
    "phpdoc",
    "phpstan",
    "pipx",
    "pkill",
    "pytest",
    "pyupgrade",
    "rhysd",
    "rubocop",
    "ruff",
    "rustdoc",
    "rustfmt",
    "rustsec",
    "semgrep",
    "shellcheck",
    "shfmt",
    "shivammathur",
    "siloed",
    "speedup",
    "staticcheck",
    "streetsidesoftware",
    "subdirs",
    "temurin",
    "tflint",
    "tradeoffs",
    "trivy",
    "tseslint",
    "typecheck",
    "worktree"
  ],
  "dictionaries": ["en_GB", "softwareTerms", "companies", "misc"]
}
```

The `files` pattern limits cspell to prose-heavy file types — markdown, plain text, reStructuredText, and YAML. This avoids noise from code identifiers.

The seeded `words` list is deliberate, not decoration: it covers the names of every tool these setup skills install and the config identifiers their own templates write (the YAML samples above are spell-checked too, since `.yml` matches the `files` pattern), plus recurring dev jargon the base dictionaries miss. Without the seed, the very first `pre-commit run --all-files` flags dozens of words the skill itself just wrote. Do **not** seed user- or project-specific proper nouns (personal handles, repo names) — leave those for the consumer to add as they surface — and never add a word that is actually a typo.

Add a cspell pre-commit hook to `.pre-commit-config.yaml`:

```yaml
  - repo: https://github.com/streetsidesoftware/cspell-cli
    rev: v10.3.0
    hooks:
      - id: cspell
        types_or: [markdown, plain-text, yaml]
```

Use the `rev:` shown, not the latest tag. It is the estate pin from agentic-coding-config's `cloud/precommit-warm.yaml`, which the cloud bootstrap pre-builds, so a new repo's first commit in a sandbox needs no hook build. Bumps go through that file.

The `words` array is the project-specific dictionary. As cspell flags legitimate words during the verify step, add them here.

### 4. actionlint (GitHub Actions linting)

Add an actionlint pre-commit hook to `.pre-commit-config.yaml`:

```yaml
  - repo: https://github.com/rhysd/actionlint
    rev: v1.7.12
    hooks:
      - id: actionlint-system
```

Use the `rev:` shown, not the latest tag. It is the estate pin from agentic-coding-config's `cloud/precommit-warm.yaml`, which the cloud bootstrap pre-builds, so a new repo's first commit in a sandbox needs no hook build. Bumps go through that file. Use `actionlint-system` rather than `actionlint`, for the same reason as `gitleaks-system`: the plain id compiles from source, and the binary is already installed in both environments.

### 5. semgrep (static analysis)

Add a semgrep pre-commit hook to `.pre-commit-config.yaml`, as a `repo: local` system hook:

```yaml
  - repo: local
    hooks:
      - id: semgrep
        name: semgrep
        language: system
        entry: semgrep scan --config auto --error
        pass_filenames: false
```

Use the system binary, never the upstream `repo: https://github.com/semgrep/semgrep` hook. That hook is `language: python`, so pre-commit clones the whole semgrep monorepo and builds a venv in it, about 1.1 GB and 200 s per container. A cloud bootstrap warms every hook in every cloned repo's config, so each session on the repo pays that before its first prompt. The binary is already installed in both environments: the cloud bootstrap installs it, and on a workstation it comes from the Brewfile. With no `semgrep` on PATH the hook fails with "Executable `semgrep` not found", which is loud rather than a silent pass.

The `--config auto` flag uses Semgrep's curated rulesets appropriate for the languages detected in the repo. The other two lines matter:

- `--error` — semgrep exits 0 on findings by default, so without it the hook always passes and the gate is decorative.
- `pass_filenames: false` — pre-commit hands hooks explicit filenames, and giving semgrep explicit paths makes it bypass its own default excludes (notably `*_test.go`), reporting findings CI never sees. Scanning the repo instead keeps hook and CI seeing the same thing.

### 6. .gitignore

Create `.gitignore` if it doesn't exist, or append missing entries. Ensure it includes at least:

```gitignore
# OS
.DS_Store
Thumbs.db

# Editors
*.swp
*.swo
*~
.vscode/
.idea/

# Environment
.env
.env.local
.env.*.local
```

Read any existing `.gitignore` first and only add lines that are missing.

### 7. GitHub Actions workflows

Create or update CI workflows. Gitleaks, cspell, and semgrep run on all files (no path filter). Actionlint only needs to run when workflow files change.

Add to `.github/workflows/ci.yml` (or create if needed). The trigger below is part of the snippet, not a placeholder: if the repo's existing `ci.yml` carries `branches:` under `pull_request`, drop it. A branch filter on `pull_request` gives a stacked PR (one whose base is another feature branch) no run at all, while GitHub still reports every check passing (the standard's Checks and CI section carries the rule). The `branches:` filter on `push` stays, because it only limits post-merge runs:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  gitleaks:
    name: Gitleaks
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: read
    steps:
      - uses: actions/checkout@<full-sha> # <version>
        with:
          fetch-depth: 0
      - uses: gitleaks/gitleaks-action@<full-sha> # <version>
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          # Same value as gitleaks-history.yml, whose canary vouches for it.
          GITLEAKS_VERSION: <gitleaks version, no leading v>

  cspell:
    name: Spell Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<full-sha> # <version>
      - uses: streetsidesoftware/cspell-action@<full-sha> # <version>
        with:
          files: '**/*.{md,txt,rst,yaml,yml}'

  semgrep:
    name: Semgrep
    runs-on: ubuntu-latest
    container:
      image: semgrep/semgrep
    steps:
      - uses: actions/checkout@<full-sha> # <version>
      - run: semgrep scan --config auto --error
```

(`--error` for the same reason as the hook: without it findings don't fail the job.)

The gitleaks job's `permissions:` block is required: the default `GITHUB_TOKEN` no longer grants `pull-requests: read`, and `gitleaks-action` needs it in PR context to fetch the PR's commit list — without it, the first PR run fails with `403 Resource not accessible by integration`. Job-level rather than workflow-level keeps it least-privilege; cspell and semgrep don't need it.

The gitleaks job scans only the pushed or PR commits; `fetch-depth: 0` gives it the history but does not make it scan that history. Create `.github/workflows/gitleaks-history.yml` to scan every ref's full history once a week. Before the scan, the workflow runs a canary to prove the scanner can still find a secret. A scanner that has stopped matching, because of a rule change, a config that allowlists too much, or a broken install, reports a repo with secrets in it as clean. The canary is what tells those two results apart:

```yaml
name: Gitleaks history
# Scheduled, not on pull_request: never add this context to the ruleset's
# required checks — a PR would block on a Pending check forever.
on:
  schedule:
    - cron: '<minute> <hour> * * <weekday>'
  workflow_dispatch:

permissions:
  contents: read

env:
  GITLEAKS_VERSION: <gitleaks version, no leading v>
  GITLEAKS_SHA256: <sha256 of gitleaks_<version>_linux_x64.tar.gz>

jobs:
  history:
    name: Gitleaks history
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<full-sha> # <version>
        with:
          fetch-depth: 0

      - name: Install gitleaks
        run: |
          tarball="gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz"
          mkdir -p "$RUNNER_TEMP/bin"
          curl -fsSL -o "$RUNNER_TEMP/$tarball" \
            "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/$tarball"
          echo "$GITLEAKS_SHA256  $RUNNER_TEMP/$tarball" | sha256sum -c -
          tar -xzf "$RUNNER_TEMP/$tarball" -C "$RUNNER_TEMP/bin" gitleaks
          echo "$RUNNER_TEMP/bin" >> "$GITHUB_PATH"
          # The canary scans a different directory, so the repo's config has
          # to be passed explicitly for it to judge the same rules.
          if [ -f .gitleaks.toml ]; then
            echo "GITLEAKS_CONFIG=$PWD/.gitleaks.toml" >> "$GITHUB_ENV"
          fi

      - name: Canary — a history-only secret must be found
        run: |
          canary="$RUNNER_TEMP/canary"
          git init -q "$canary"
          # Random per run: a fixed or low-entropy token is suppressed by the
          # rule's entropy floor, and a committed one would trip the scan.
          printf 'token = "ghp_%s"\n' "$(openssl rand -hex 18)" > "$canary/leak.txt"
          git -C "$canary" add leak.txt
          git -C "$canary" -c user.name=canary -c user.email=canary@example.invalid commit -qm plant
          git -C "$canary" rm -q leak.txt
          git -C "$canary" -c user.name=canary -c user.email=canary@example.invalid commit -qm remove
          # --exit-code 0 so a gitleaks error (also exit 1) can't pass as a find.
          gitleaks git --redact --no-banner --exit-code 0 \
            --report-format json --report-path "$RUNNER_TEMP/canary.json" "$canary"
          found=$(jq '[.[] | select(.RuleID == "github-pat")] | length' "$RUNNER_TEMP/canary.json")
          if [ "$found" -lt 1 ]; then
            echo "::error::gitleaks missed the canary secret, so a clean history scan would prove nothing"
            exit 1
          fi

      - name: Scan full history
        run: gitleaks git --redact --no-banner --verbose --log-opts="--all" .
```

Use the same `GITLEAKS_VERSION` in both workflows. The canary then also vouches for the binary the PR job runs. Pin `GITLEAKS_SHA256` from the release's `gitleaks_<version>_checksums.txt` at setup time, not at run time: a checksum fetched from the same release in the same run only checks that the download completed. Pick a cron minute and hour other than `0`, because scheduled runs on the hour are delayed the most.

The canary has to be a **history-only**, **high-entropy** secret. It is history-only because history is what this workflow is for: a canary that sat in `HEAD` would pass even if history scanning had broken. It is high-entropy because gitleaks' rules have an entropy floor, so an obviously fake key like `ghp_aaaa…` is suppressed. A canary built from one comes back clean and proves the opposite of what it looks like.

A finding from this workflow is a secret already in history. The fix is to rotate the secret, not to rewrite history: once a secret has been pushed, it has been exposed. Add an entry to `.gitleaksignore` only after the secret has been rotated. GitHub notifies whoever last edited the `cron` line when a scheduled run fails. On a public repo, it also disables scheduled workflows after 60 days with no activity, so re-enable this one if a quiet repo goes silent.

Create a separate `.github/workflows/actionlint.yml` with a path filter. Because the filter is at the trigger, this workflow is **ineligible as a required check**: a required context whose workflow a PR's paths skip stays Pending forever and blocks the merge (the standard's Checks and CI section carries the rule), so keep `Actionlint` out of the ruleset's contexts list. `rhysd/actionlint` publishes no GitHub Action to pin, so use the official download script rather than `rhysd/actionlint@main` (a mutable branch reference that fails the repo's own semgrep gate):

```yaml
name: Actionlint
# Path-filtered at the trigger: never add this context to the ruleset's
# required checks — a PR that skips it would block on a Pending check forever.
on:
  push:
    paths: ['.github/workflows/**']
  pull_request:
    paths: ['.github/workflows/**']

jobs:
  actionlint:
    name: Actionlint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<full-sha> # <version>
      - name: Download actionlint
        run: bash <(curl https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash)
      - name: Run actionlint
        run: ./actionlint -color
```

Don't duplicate if any of these jobs already exist. Every `uses:` reference must be pinned to a full commit SHA with a version comment — look up the latest release of each action and substitute the real SHA for `<full-sha>`, e.g.:

```yaml
- uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
```

A floating tag (`@v4`) or branch (`@main`) is a mutable reference — it fails the semgrep gate installed above (`github-actions-mutable-action-tag` is a blocking finding), so samples committed with floating tags fail their own repo's CI.

### 8. Dependabot

The normative standard is [`home/standards/github-standards.md`](https://github.com/pmgledhill102/dotfiles/blob/main/agent/home/standards/github-standards.md) — read it rather than treating the samples below as the source of truth. The estate's private infrastructure repository is the reference implementation; its two files carry inline rationale worth reading before copying.

**Dependabot has two halves and each is invisible from the other.** Repo *settings* (dependency graph, alerts, security updates) raise the alarm when an advisory lands; repo *files* decide how routine bumps arrive. Weekly bump PRs prove only the file half — a repo shipped them for months, on schedule, correctly labelled, while alerts were off. Steps 8a and 8b are not optional halves of each other.

#### 8a. Settings (every repo — two API calls, never wrong)

```sh
gh api -X PUT "repos/{owner}/{repo}/vulnerability-alerts"
gh api -X PUT "repos/{owner}/{repo}/automated-security-fixes"
```

Dependency graph must be on (private repos need it enabled explicitly; nothing below works without it), plus grouped security updates. Those sit under `security_and_analysis` on `PATCH /repos/{owner}/{repo}`, a surface that has changed shape more than once — **don't assume a scripted write took**: `GET` the repo back and read `security_and_analysis`. For a handful of repos the UI (Settings → Advanced Security) is the reliable path.

#### 8b. `.github/dependabot.yml` (every repo)

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directories:
      - "/"
    schedule:
      interval: weekly
      day: monday
    open-pull-requests-limit: 5
    cooldown:
      default-days: 7
    groups:
      actions:
        patterns: ["*"]
        update-types: [minor, patch]
      actions-major:
        patterns: ["*"]
        update-types: [major]
    commit-message:
      prefix: "ci"
    assignees:
      - "<the repo owner>"
```

If the file already exists, read it first and add only the missing ecosystem entry. Five things about this shape are load-bearing:

- **`cooldown` is not a lint nit.** This skill also installs auto-merge, so without it a freshly published malicious or broken version lands on the default branch with nobody looking. `dependabot-missing-cooldown` is a blocking semgrep rule. **But cooldown is not universally effective** — the docker ecosystem provides no publication date, so docker PRs carry *"Cooldown could not be applied"* and merge with no delay. For docker, required status checks are the only gate.
- **Per-severity cooldown keys (`semver-patch-days` and friends) are accepted by some ecosystems only** — `gomod` takes them, `github-actions` and `terraform` reject them. A rejected key **invalidates the entire file**, silently stopping every update stream in the repo, not just that setting. Add one to a new ecosystem only after checking it is accepted.
- **Group across directories, not per directory.** Use `directories:` (plural) with a list; the same dependency bumped in N directories otherwise arrives as N near-identical PRs that put each other behind under a strict up-to-date rule, each needing its own CI cycle.
- **Only name labels that already exist.** Dependabot does not create labels it is told to use, and naming an absent one risks it applying **none**. Check first, or omit the key.
- **`assignees` is what makes the pull request visible at all**, and the key is not the obvious one. Dependabot PRs are authored by `app/dependabot`, and the GitHub mobile app's filters are *Created by me / Assigned to me / Mentions me / Review requested / Involved* — a Dependabot PR matches **none** of them. Without an assignee the only way to see one is typing `is:open is:pr author:app/dependabot` into search, which the app does not save. One such pull request, in a private repository, was a **patch** bump on an `automerge`-tier repo, open from 2026-04-06 to 2026-09-05, with nothing surfacing it. Note that `reviewers` would be the more natural key and **no longer exists** — GitHub removed it from the Dependabot options reference (verified 2026-09-05, zero occurrences). `assignees` remains, and is documented for both version *and* security updates, which matters for a repo whose only Dependabot activity is security-driven. **It does not gate auto-merge**: on the pilot, a pull request was created, assigned and auto-merged within the same minute.

#### 8c. Auto-merge (only repos whose CI proves something)

A repo without a check worth requiring does not get auto-merge — see the never-combination at the end of this section.

```yaml
name: Dependabot Auto-merge
on: pull_request

# Read-only is sufficient: fetch-metadata only reads, and both writes go
# through the PAT. Raising these grants nothing, and GitHub would still
# refuse an Actions-token approval.
permissions:
  contents: read
  pull-requests: read

jobs:
  automerge:
    if: github.event.pull_request.user.login == 'dependabot[bot]' && github.repository == '<owner>/<repo>'
    runs-on: ubuntu-slim
    steps:
      # A grouped bump whose commit message exceeds 64 KiB loses its metadata
      # block to truncation, and fetch-metadata fails. continue-on-error makes
      # that a clean skip rather than a red check on a healthy PR; every later
      # step is gated on the step's outcome, so nothing approves or merges
      # without metadata, whatever made the fetch fail.
      - name: Fetch update metadata
        id: metadata
        continue-on-error: true
        uses: dependabot/fetch-metadata@<full-sha> # <version>
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}

      - name: Leave PRs without metadata for a human
        if: steps.metadata.outcome == 'failure'
        run: echo "::notice::No Dependabot metadata on this PR (commit message likely truncated past 64 KiB). Deliberately not auto-merged -- merge by hand."

      # Below 1.0.0 the MINOR position is the breaking one: semver promises
      # nothing there, and the convention is that 0.x shifts every position up.
      # fetch-metadata compares positions literally with no 0.x case, so its
      # major branch is unreachable below 1.0.0 and `0.21.4 -> 0.33.0` reports
      # semver-minor. Refuse that; keep auto-merging a 0.x bump that moves only
      # the patch position, which is the 0.x equivalent of a patch.
      #
      # Scan updated-dependencies-json, NOT previous-version: update-type is
      # the largest jump across a group, but previous-version is
      # updatedDependencies[0] alone, so reading it passes a 0.x dependency
      # whenever a 1.x one sorts first.
      - name: Check for breaking pre-1.0 bumps
        id: pre_release
        if: steps.metadata.outcome == 'success'
        env:
          DEPS_JSON: ${{ steps.metadata.outputs.updated-dependencies-json }}
        run: |
          names="$(printf '%s' "$DEPS_JSON" | jq -r '
            [ .[]
              | . as $d
              | (($d.prevVersion // "") | ltrimstr("v") | split(".")) as $p
              | (($d.newVersion  // "") | ltrimstr("v") | split(".")) as $n
              | select($p[0] == "0" and ($p[0] != $n[0] or $p[1] != $n[1]))
              | "\($d.dependencyName) \($d.prevVersion) -> \($d.newVersion)"
            ] | join("; ")')"
          if [ -n "$names" ]; then
            echo "::notice::Pre-1.0 dependency whose minor position moved. Below 1.0.0 that is the breaking position, even though update-type reports it as a minor. Left for a human: $names"
            echo "blocked=true" >> "$GITHUB_OUTPUT"
          else
            echo "blocked=false" >> "$GITHUB_OUTPUT"
          fi

      # For a grouped PR, update-type is the LARGEST jump in the group, so a
      # group containing one major is treated as a major and skipped.
      - name: Approve and enable auto-merge (patch/minor)
        if: steps.metadata.outcome == 'success' && steps.pre_release.outputs.blocked == 'false' && (steps.metadata.outputs.update-type == 'version-update:semver-patch' || steps.metadata.outputs.update-type == 'version-update:semver-minor')
        env:
          GH_TOKEN: ${{ secrets.AUTOMERGE_PAT }}
          PR_URL: ${{ github.event.pull_request.html_url }}
        run: |
          if [ -z "$GH_TOKEN" ]; then
            echo "::error::AUTOMERGE_PAT is not set in the Dependabot secret store. Refusing to fall back to GITHUB_TOKEN: Actions may not approve pull requests, and a GITHUB_TOKEN merge does not trigger workflows that run on push to the default branch."
            exit 1
          fi
          if ! gh pr review --approve "$PR_URL"; then
            echo "::error::Approval failed with a non-empty AUTOMERGE_PAT. The most likely cause is that this repository is not on the token's selected-repositories list -- a fine-grained PAT's scope cannot be read from outside the token, so this is where a missed repo surfaces. Add ${{ github.repository }} to the AUTOMERGE_PAT repository list."
            exit 1
          fi
          gh pr merge --auto --merge "$PR_URL"

      - name: Leave majors for a human
        if: steps.metadata.outputs.update-type == 'version-update:semver-major'
        run: echo "Major update -- deliberately not auto-merged."
```

**What makes this workflow work is declared, not described here.** The ten properties — the PAT rather than `GITHUB_TOKEN` for both calls, the gate on the PR *author* rather than the actor, the `update-type` gate that leaves majors alone, the pre-1.0 gate that catches the breaking `0.x` bumps `update-type` reports as minors, `--merge` rather than `--squash`, the loud failure on a missing PAT, and the clean skip that leaves a PR without Dependabot metadata for a human — live in [`home/standards/github-repo.json`](../../standards/github-repo.json) under the `automerge` tier's `files` block, each with the reason it is there. The sample above satisfies all ten. `paul-context`'s `tools/repo-spec-diff.py` checks every `automerge` repo against that block, so a change made here and not there — or there and not here — is reported on the next sweep rather than discovered five days later.

Restating those reasons here is what produced the failure the spec exists to end: prose cannot be diffed, so four of five `automerge` repos ran a superseded copy of this workflow while reporting zero settings drift. **The half of the loop the sweep cannot close is this one** — a property added to the spec does not propagate into the sample above. Change both in the same PR.

If the repo has a `cspell.json`, add `ltrimstr` to its `words` list in the same change. The sample text above uses it and is byte-compared, so do not reword it.

#### 8d. The `AUTOMERGE_PAT` — do this when installing 8c and 8e

**One shared fine-grained token serves the whole estate**; installing the workflow means adding this repo to its list, not minting a new token. Both steps, in order:

1. **Add this repository to the `AUTOMERGE_PAT` token's selected-repositories list.** Skipping this is the failure the workflow's second guard exists to catch — the secret is present and non-empty, so the missing-PAT check passes and the approval fails with a bare 403. **A PAT's scope cannot be audited from outside**, so this step at install time is the only real control.
2. Store the token **twice, under the same name**: as a **Dependabot** secret for 8c and as an **Actions** secret for 8e. Dependabot-triggered runs read only the Dependabot store and push-triggered runs read only the Actions store; either reads a secret held in the other store as empty, with no error.

```sh
printf 'Fine-grained PAT (input hidden): '
read -rs TOKEN; echo
for app in dependabot actions; do
  printf '%s' "$TOKEN" | gh secret set AUTOMERGE_PAT --app "$app" --repo "<owner>/<repo>"
done
unset TOKEN
```

The token goes in on stdin rather than `--body`: `--body` puts the secret in `argv`, visible to `ps` while the command runs, and whatever set the variable sits in shell history.

**In this estate the token is not kept anywhere after it is distributed**, so step 2 cannot be done for one repo on its own. Getting a value means regenerating the token, and regenerating invalidates every other repo's copy. Adding a repo is therefore a tier-wide redistribution: assign the repo to `automerge` in `paul-context`'s `registry/repo-tiers.json`, add it to the token's repository list, regenerate, and run `paul-context`'s `tools/set-automerge-pat.sh`. That script derives the repo list from the registry and writes every repo in the tier. The single-repo loop above is for an estate that does keep the token.

Permissions are Contents, Pull requests and Workflows (all read/write), and no more. Contents write is the floor, not an over-grant: the merge writes to the base branch, and GitHub has no narrower "may merge but not push" permission. Workflows write is needed because 8e pushes a merge commit into the PR head, and GitHub refuses any push touching `.github/workflows/` without it, which covers every Dependabot `github-actions` bump.

Also enable **Allow auto-merge** in Settings → General (`/setup-repo` does this).

> **The combination that must never exist: auto-merge enabled with no required status checks on the default branch.** Without required checks `gh pr merge --auto` merges *immediately* — the "wait for CI" everyone assumes comes from the ruleset, not the flag. If a repo has no check worth requiring, it does not get 8c.

#### 8e. Keep armed PRs up to date (every repo that gets 8c)

The standard ruleset requires branches to be up to date before merging, so every open PR goes stale the moment another merges, and arming auto-merge does not update a branch. This workflow merges the default branch into each armed PR that is behind it, so parallel PRs land in turn without anyone clicking **Update branch**. Install it as `.github/workflows/update-auto-merge-prs.yaml`:

```yaml
# Keeps auto-merge-armed PRs up to date with main, so the strict
# required-checks rule never needs a manual "Update branch" click.
#
# For each open PR into main, from this repo, with auto-merge armed and
# behind main, it calls the update-branch API, which merges main into the
# PR head with a merge commit. Arming auto-merge is the owner's approval;
# this workflow never arms or merges anything itself.
#
# It authenticates with AUTOMERGE_PAT, not GITHUB_TOKEN: a push made with
# GITHUB_TOKEN does not trigger pull_request workflows, so the required
# checks would never run on the updated head and auto-merge would stall.
# A missing secret fails the run rather than falling back.
#
# Required on every automerge-tier repo. agentic-coding-config declares its
# properties in home/standards/github-repo.json, keeps the installable copy in
# setup-common's SKILL.md, and gives the reasoning in github-standards.md
# ("Keeping armed PRs current"). Change them together.
name: Update auto-merge PRs

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
    types: [auto_merge_enabled]
  workflow_dispatch: {}

permissions: {}

# Runs are serialised, not cancelled: two concurrent runs would both update
# the same PR, and the second would fail on its stale expected_head_sha.
concurrency:
  group: "${{ github.workflow }}"
  cancel-in-progress: false

jobs:
  update:
    name: Update armed PRs behind main
    # A fork PR's run gets no secrets, and fork PRs are skipped anyway.
    if: github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository
    runs-on: ubuntu-slim
    steps:
      - name: Update branches
        shell: sh
        env:
          GH_TOKEN: ${{ secrets.AUTOMERGE_PAT }}
          R: ${{ github.repository }}
        run: |
          set -eu
          if [ -z "${GH_TOKEN}" ]; then
            echo "::error::AUTOMERGE_PAT is not set as an Actions secret in ${R}; refusing to fall back to GITHUB_TOKEN, whose pushes would not trigger CI."
            exit 1
          fi

          prs="${RUNNER_TEMP}/prs.tsv"
          # number, head SHA, head repo ("-" when the fork is gone), armed, head branch.
          # No empty fields: tab is IFS whitespace, so read would collapse them.
          if ! gh api --paginate "repos/${R}/pulls?state=open&base=main&per_page=100" \
            --jq '.[] | [.number, .head.sha, (.head.repo.full_name // "-"), (.auto_merge != null), .head.ref] | @tsv' \
            > "${prs}"; then
            echo "::error::Could not list pull requests with a non-empty AUTOMERGE_PAT. The most likely cause is that ${R} is not on the token's selected-repositories list -- a fine-grained PAT's scope cannot be read from outside the token, so this is where a missed repo surfaces. Add ${R} to the AUTOMERGE_PAT repository list."
            exit 1
          fi

          # update N SHA: merge main into PR N's head, asserting it is at SHA.
          # Prints the API's error output, and returns non-zero, on failure.
          update() {
            { gh api -X PUT "repos/${R}/pulls/$1/update-branch" -f "expected_head_sha=$2" >/dev/null; } 2>&1
          }

          failed=0
          while IFS="$(printf '\t')" read -r n sha head_repo armed ref; do
            if [ "${head_repo}" != "${R}" ]; then
              echo "#${n}: skipped (head is not in ${R})"
              continue
            fi
            if [ "${armed}" != "true" ]; then
              echo "#${n}: skipped (auto-merge not armed)"
              continue
            fi
            # compare/BASE...HEAD: behind_by counts main's commits the head lacks.
            if ! behind="$(gh api "repos/${R}/compare/main...${sha}" --jq '.behind_by')"; then
              echo "::error::#${n}: could not compare ${sha} with main"
              failed=$((failed + 1))
              continue
            fi
            if [ "${behind}" -eq 0 ]; then
              echo "#${n}: up to date"
              continue
            fi
            if err="$(update "${n}" "${sha}")"; then
              echo "#${n}: updated (was ${behind} behind main)"
              continue
            fi
            # The PR's head record can lag its branch, even after an update
            # this workflow made itself, and GitHub then refuses the recorded
            # head with 422 "expected head sha didn't match". Re-read the
            # branch and retry once from it, so one stale record cannot fail
            # every push. Only that message is retried: a conflicted PR is
            # also a 422 ("merge conflict between base and head") and must
            # stay red. The match stops before "didn't", whose apostrophe
            # GitHub sends as U+2019.
            case "${err}" in
              *"expected head sha"*) ;;
              *)
                echo "::error::#${n}: update-branch failed (was ${behind} behind main at ${sha}): ${err} (a 403/404 here can also mean ${R} is missing from the AUTOMERGE_PAT repository list, or the token lacks Workflows write when the PR touches .github/workflows/)"
                failed=$((failed + 1))
                continue
                ;;
            esac
            cur="$(gh api "repos/${R}/git/ref/heads/${ref}" --jq '.object.sha' 2>/dev/null || true)"
            if [ -z "${cur}" ] || [ "${cur}" = "${sha}" ]; then
              echo "::warning::#${n}: update-branch refused the recorded head ${sha}, but the branch is at it (or could not be read); skipped"
              continue
            fi
            if ! behind="$(gh api "repos/${R}/compare/main...${cur}" --jq '.behind_by')"; then
              echo "::warning::#${n}: PR record is stale (records ${sha}, branch is at ${cur}) and the branch could not be compared with main; skipped"
              continue
            fi
            if [ "${behind}" -eq 0 ]; then
              echo "#${n}: up to date (PR record is stale: records ${sha}, branch is at ${cur})"
            elif err="$(update "${n}" "${cur}")"; then
              echo "#${n}: updated from the branch head ${cur} (was ${behind} behind main; PR record was stale at ${sha})"
            else
              case "${err}" in
                *"expected head sha"*)
                  echo "::warning::#${n}: PR record is stale (records ${sha}, branch is at ${cur}), and update-branch from the branch head was refused too: ${err}; skipped"
                  ;;
                *)
                  echo "::error::#${n}: update-branch from the branch head ${cur} failed: ${err}"
                  failed=$((failed + 1))
                  ;;
              esac
            fi
          done < "${prs}"

          if [ "${failed}" -gt 0 ]; then
            echo "::error::${failed} PR(s) could not be updated"
            exit 1
          fi
```

If the repo has a `cspell.json`, add `agentic` to its `words` list in the same change. The sample text uses it and is byte-compared, so do not reword it.

It needs the Actions copy of the `AUTOMERGE_PAT` from 8d. It uses only the runner's preinstalled `gh`, so there is no action to pin. If the repo's default branch is not `main`, change the two `branches:` filters, the `base=` query and the `compare/` base. The comments and log messages say `main` too, but changing them is cosmetic.

**Arming auto-merge is the approval** on a repo with this workflow: the ruleset requires no review, so an armed PR merges once its checks pass. Never arm auto-merge on a PR you opened yourself; that would be an agent merging its own work.

The reasons behind each property are in [github-standards.md](../../standards/github-standards.md#keeping-armed-prs-current), and the properties themselves are declared in [`home/standards/github-repo.json`](../../standards/github-repo.json) under the `automerge` tier's `files` block, the same arrangement as 8c. Change the sample above and the spec in the same PR.

### 9. Agent permissions for cloud sessions

A cloud session reads the project repo's `.claude/` and **nothing** from
`~/.claude/`, so anything it needs has to arrive by a route the repo or the
environment controls.

Do **not** stamp a marketplace or `enabledPlugins` declaration here. This
estate published its config as a Claude Code plugin for a while; that channel
was withdrawn, and a repo enabling it now would point at a marketplace that no
longer exists. Agent config reaches a sandbox through the environment's setup
script running `cloud/bootstrap.sh`, which is a property of the environment
rather than of any one repo — see `cloud/README.md`.

What *does* belong in the repo's `.claude/settings.json` is the **permission
allowlist**: it is the only place a cloud session reads permissions from, and
no delivery channel can carry it. Stamping a core allowlist is a reasonable
follow-on, deliberately not done automatically here — permissions are the one
thing worth deciding per repo rather than by template.

Whatever you put there, commit it; it is meant to be shared, not gitignored,
and if the repo already has `.claude/settings.json`, merge alongside whatever
is there rather than replacing it.

### 10. Repo-level agent instructions

One file. **`AGENTS.md` holds the instructions, and Claude Code reads it
directly when the repo has no `CLAUDE.md`** —
[ADR-0019](https://github.com/pmgledhill102/dotfiles/blob/main/agent/adrs/0019-agents-md-is-the-repo-instruction-source.md)
for `AGENTS.md` as the source,
[ADR-0023](https://github.com/pmgledhill102/dotfiles/blob/main/agent/adrs/0023-claude-code-reads-agents-md-as-a-fallback.md)
for dropping the pointer file.

If the repo already has an `AGENTS.md`, leave its content alone. If it has
instructions in `CLAUDE.md` and no `AGENTS.md`, **move** the content across
rather than copying it, and delete `CLAUDE.md` unless something
Claude-specific is left over (below). Do not generate a `CLAUDE.md` otherwise.

`AGENTS.md`:

```markdown
# Project Instructions for AI Agents

## Build & Test

<the commands, and anything non-obvious about running them>

## Architecture Overview

## Conventions & Patterns
```

**Only if the repo has Claude-specific guidance**, add a `CLAUDE.md` that
imports `AGENTS.md` and adds to it:

```markdown
# Claude Code

@AGENTS.md

<Claude-specific guidance, as an addition to AGENTS.md rather than a copy of it>
```

The import is not optional. Claude Code reads `AGENTS.md` only as a fallback
for a repo with no `CLAUDE.md`: once a `CLAUDE.md` exists, `AGENTS.md` is
dropped unless `CLAUDE.md` imports it, and nothing reports the loss. Through
the import it is loaded once, not twice. Never write the shared instructions
into `CLAUDE.md` itself, where they become a second copy that drifts.

### 11. Verify

Run `pre-commit run --all-files` to confirm everything works. Fix any issues that come up.

### 12. Closing summary

End the closing summary with this reminder (verbatim or close to it):

```text
Local baseline applied. Run /setup-repo next to apply the GitHub-side
settings (branch ruleset, merge methods, secret scanning, labels).
```

The two commands are a pair that is easy to half-apply: this one writes local files, `setup-repo` configures the remote (different preconditions, different blast radius — the split is deliberate). Naming what `setup-repo` adds is the load-bearing part of the reminder; skip it only if `setup-repo` was already run this session.

## Important

- Do NOT blindly overwrite existing config files. Read them first and merge.
