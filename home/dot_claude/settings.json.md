# settings.json — Annotated Reference

This file documents `settings.json` with groupings and rationale.
**Keep this file in sync with `settings.json`** — when adding, removing, or
changing permission rules, update both files together.

## Permissions: allow

### Beads / BD (task management)

- `Bash(bd *)`
- `Bash(beads *)`

### Brew (read-only + services)

- `Bash(brew --prefix *)`
- `Bash(brew info *)`
- `Bash(brew list *)`
- `Bash(brew search *)`
- `Bash(brew services *)`

### Chezmoi

- `Bash(chezmoi *)`

### Dolt (database for beads)

- `Bash(dolt *)`

### draw.io (CLI export, read-only)

- `Bash(/Applications/draw.io.app/Contents/MacOS/draw.io *)`

### Containers (Podman)

- `Bash(hadolint *)`
- `Bash(podman build *)`
- `Bash(podman compose *)`
- `Bash(podman container prune *)`
- `Bash(podman info *)`
- `Bash(podman inspect *)`
- `Bash(podman logs *)`
- `Bash(podman machine *)`
- `Bash(podman network prune *)`
- `Bash(podman ps *)`
- `Bash(podman rm *)`
- `Bash(podman run *)`
- `Bash(podman push *)`
- `Bash(podman stop *)`

### GCloud (read-only operations only)

Enumerate specific subcommands rather than using wildcards in the middle
of commands. `gcloud storage` is restricted to `cat` and `ls` — no `cp`,
`rm`, or `mv`.

#### Artifacts

- `Bash(gcloud artifacts docker images list *)`
- `Bash(gcloud artifacts repositories describe *)`
- `Bash(gcloud artifacts repositories list *)`

#### Auth and config

- `Bash(gcloud auth list *)`
- `Bash(gcloud auth print-access-token *)`
- `Bash(gcloud auth print-identity-token *)`
- `Bash(gcloud config *)`
- `Bash(gcloud info *)`

#### Builds

- `Bash(gcloud builds describe *)`
- `Bash(gcloud builds list *)`
- `Bash(gcloud builds log *)`

#### Compute

- `Bash(gcloud compute firewall-rules describe *)`
- `Bash(gcloud compute firewall-rules list *)`
- `Bash(gcloud compute instances describe *)`
- `Bash(gcloud compute instances get-serial-port-output *)`
- `Bash(gcloud compute instances list *)`
- `Bash(gcloud compute instances reset *)`
- `Bash(gcloud compute networks describe *)`
- `Bash(gcloud compute networks list *)`

#### Containers (GKE)

- `Bash(gcloud container clusters describe *)`
- `Bash(gcloud container clusters list *)`

#### DNS

- `Bash(gcloud dns managed-zones describe *)`
- `Bash(gcloud dns managed-zones list *)`
- `Bash(gcloud dns record-sets list *)`

#### Functions

- `Bash(gcloud functions describe *)`
- `Bash(gcloud functions list *)`

#### IAM

- `Bash(gcloud iam service-accounts describe *)`
- `Bash(gcloud iam service-accounts list *)`

#### Logging

- `Bash(gcloud logging read *)`

#### Projects and services

- `Bash(gcloud projects describe *)`
- `Bash(gcloud projects list *)`
- `Bash(gcloud services list *)`

#### Pub/Sub

- `Bash(gcloud pubsub subscriptions describe *)`
- `Bash(gcloud pubsub subscriptions list *)`
- `Bash(gcloud pubsub topics describe *)`
- `Bash(gcloud pubsub topics list *)`

#### Cloud Run

- `Bash(gcloud run jobs describe *)`
- `Bash(gcloud run jobs executions describe *)`
- `Bash(gcloud run jobs executions list *)`
- `Bash(gcloud run jobs list *)`
- `Bash(gcloud run revisions describe *)`
- `Bash(gcloud run revisions list *)`
- `Bash(gcloud run services describe *)`
- `Bash(gcloud run services list *)`

#### Scheduler

- `Bash(gcloud scheduler jobs describe *)`
- `Bash(gcloud scheduler jobs list *)`

#### Secrets Manager

- `Bash(gcloud secrets describe *)`
- `Bash(gcloud secrets list *)`
- `Bash(gcloud secrets versions describe *)`
- `Bash(gcloud secrets versions list *)`

#### Cloud SQL

- `Bash(gcloud sql instances describe *)`
- `Bash(gcloud sql instances list *)`

#### Storage (read-only)

- `Bash(gcloud storage cat *)`
- `Bash(gcloud storage ls *)`

### gsutil (read-only, legacy CLI)

- `Bash(gsutil cat *)`
- `Bash(gsutil ls *)`
- `Bash(gsutil stat *)`

### GitHub CLI

Read/view operations, PR creation, and CI re-runs. PR merging is handled
manually (see Never Allow). Closing PRs/issues and `gh api` (which can
POST/DELETE) require prompting. These entries will be retired once the
GitHub MCP server is validated — see GitHub MCP section below.

- `Bash(gh issue list *)`
- `Bash(gh issue view *)`
- `Bash(gh pr checks *)`
- `Bash(gh pr create *)`
- `Bash(gh pr diff *)`
- `Bash(gh pr list *)`
- `Bash(gh pr view *)`
- `Bash(gh repo view *)`
- `Bash(gh run list *)`
- `Bash(gh run rerun *)`
- `Bash(gh run view *)`
- `Bash(gh run watch *)`
- `Bash(gh workflow list *)`
- `Bash(gh workflow view *)`

### Git

Standard git workflow operations. Destructive operations (`reset --hard`,
`push --force`, `clean`) still require prompting.

- `Bash(git add *)`
- `Bash(git branch *)`
- `Bash(git checkout *)`
- `Bash(git cherry-pick *)`
- `Bash(git commit *)`
- `Bash(git diff *)`
- `Bash(git fetch *)`
- `Bash(git log *)`
- `Bash(git ls-tree *)`
- `Bash(git merge *)`
- `Bash(git pull *)`
- `Bash(git push *)`
- `Bash(git remote *)`
- `Bash(git rm *)`
- `Bash(git show *)`
- `Bash(git stash *)`
- `Bash(git status *)`
- `Bash(git tag *)`
- `Bash(git worktree *)`

### Go (build, test, and lint only)

`go run`, `go get`, and `go install` require prompting as they execute
or download code. Bare `go mod tidy` (no args) needs its own entry since
`go mod tidy *` only matches when arguments follow.

- `Bash(go build *)`
- `Bash(go doc *)`
- `Bash(go env *)`
- `Bash(go fmt *)`
- `Bash(go mod tidy)`
- `Bash(go mod tidy *)`
- `Bash(go test *)`
- `Bash(go version *)`
- `Bash(go vet *)`
- `Bash(gofmt *)`
- `Bash(goimports *)`
- `Bash(golangci-lint *)`
- `Bash(govulncheck *)`

### Java / JVM (specific safe goals only)

Catch-all `gradle *` and `mvn *` removed — both can execute arbitrary
tasks. Only known-safe build/test/check goals are allowed.

- `Bash(gradle build *)`
- `Bash(gradle check *)`
- `Bash(gradle dependencies *)`
- `Bash(gradle test *)`
- `Bash(java -version *)`
- `Bash(mvn compile *)`
- `Bash(mvn dependency:tree *)`
- `Bash(mvn test *)`
- `Bash(mvn validate *)`

### JavaScript / Node (run scripts and query only)

`npm install`, `node *` (arbitrary execution), and `npx *` (downloads
and runs packages) require prompting. Only `npm run` and read-only
subcommands are auto-allowed.

- `Bash(eslint *)`
- `Bash(npm list *)`
- `Bash(npm outdated *)`
- `Bash(npm run *)`
- `Bash(npm test *)`
- `Bash(pnpm list *)`
- `Bash(pnpm run *)`
- `Bash(pnpm test *)`
- `Bash(yarn list *)`
- `Bash(yarn run *)`
- `Bash(yarn test *)`

### PHP

`composer install`/`composer require` require prompting as they modify
dependencies.

- `Bash(composer list *)`
- `Bash(composer show *)`
- `Bash(composer validate *)`
- `Bash(php-cs-fixer *)`
- `Bash(phpstan *)`

### .NET (build, test, and format only)

`dotnet run`, `dotnet publish`, and `dotnet add` require prompting.

- `Bash(dotnet build *)`
- `Bash(dotnet format *)`
- `Bash(dotnet --info *)`
- `Bash(dotnet --version *)`
- `Bash(dotnet test *)`

### Python (linting and testing only)

`python *`/`python3 *` (arbitrary execution) and `pip install`
(installs packages) require prompting. Linters and test runners are safe.

- `Bash(bandit *)`
- `Bash(mypy *)`
- `Bash(pylint *)`
- `Bash(pytest *)`
- `Bash(ruff *)`

### Ruby

`gem install` and `bundle install` require prompting. Linters and
security scanners are safe.

- `Bash(brakeman *)`
- `Bash(bundle-audit *)`
- `Bash(rubocop *)`

### Rust (build, test, and lint only)

`cargo run`, `cargo install`, and `cargo publish` require prompting.

- `Bash(cargo bench *)`
- `Bash(cargo build *)`
- `Bash(cargo check *)`
- `Bash(cargo clippy *)`
- `Bash(cargo doc *)`
- `Bash(cargo fmt *)`
- `Bash(cargo deny *)`
- `Bash(cargo test *)`

### Terraform

- `Bash(checkov *)`
- `Bash(terraform fmt *)`
- `Bash(terraform init *)`
- `Bash(terraform output *)`
- `Bash(terraform plan *)`
- `Bash(terraform state list *)`
- `Bash(terraform validate *)`
- `Bash(tflint *)`
- `Bash(tfsec *)`

### Linting and formatting (cross-language)

- `Bash(actionlint *)`
- `Bash(cspell *)`
- `Bash(markdownlint *)`
- `Bash(markdownlint-cli2 *)`
- `Bash(pre-commit *)`
- `Bash(prettier *)`
- `Bash(shellcheck *)`
- `Bash(shfmt *)`
- `Bash(yamllint *)`

### TypeScript

- `Bash(tsc *)`

### Security scanning

- `Bash(gitleaks *)`
- `Bash(semgrep *)`
- `Bash(trivy *)`

### PDF processing

- `Bash(ocrmypdf *)`
- `Bash(pandoc *)`
- `Bash(pdfinfo *)`
- `Bash(pdftotext *)`
- `Bash(weasyprint *)`

### Steampipe (read-only cloud queries)

- `Bash(steampipe *)`

### Hugo (static site generator)

- `Bash(hugo *)`

### macOS utilities (read-only)

- `Bash(defaults find *)`
- `Bash(defaults read *)`
- `Bash(sips *)`

### Make (specific safe targets only)

Catch-all `make *` is not allowed — it executes arbitrary targets.
Only known-safe build/lint goals are permitted.

- `Bash(make build)`
- `Bash(make lint)`

### Shell utilities (read-only)

`curl` (can exfiltrate data) and `chmod` (changes permissions) require
prompting.

- `Bash(cp *)`
- `Bash(echo *)`
- `Bash(find *)`
- `Bash(grep *)`
- `Bash(jq *)`
- `Bash(ls *)`
- `Bash(lsof *)`
- `Bash(mkdir *)`
- `Bash(pgrep *)`
- `Bash(sed *)`
- `Bash(wc *)`
- `Bash(which *)`

### GitHub MCP server

The GitHub MCP server (`github/github-mcp-server`) provides structured
API access without shell escaping issues. Configured per-machine via
`claude mcp add` (stored in `~/.claude.json`, not in dotfiles). The
permissions below control which MCP tools are auto-approved.

**Read tools** (all auto-approved):

- `mcp__github__get_commit`
- `mcp__github__get_file_contents`
- `mcp__github__get_latest_release`
- `mcp__github__get_me`
- `mcp__github__get_release_by_tag`
- `mcp__github__get_tag`
- `mcp__github__get_team_members`
- `mcp__github__get_teams`
- `mcp__github__issue_read`
- `mcp__github__list_branches`
- `mcp__github__list_commits`
- `mcp__github__list_issues`
- `mcp__github__list_pull_requests`
- `mcp__github__list_releases`
- `mcp__github__list_tags`
- `mcp__github__pull_request_read`
- `mcp__github__search_code`
- `mcp__github__search_issues`
- `mcp__github__search_pull_requests`
- `mcp__github__search_repositories`
- `mcp__github__search_users`

**Write tools** (selectively auto-approved):

- `mcp__github__add_comment_to_pending_review`
- `mcp__github__add_issue_comment`
- `mcp__github__add_reply_to_pull_request_comment`
- `mcp__github__create_branch`
- `mcp__github__create_or_update_file`
- `mcp__github__create_pull_request`
- `mcp__github__issue_write`
- `mcp__github__push_files`
- `mcp__github__sub_issue_write`
- `mcp__github__update_pull_request`
- `mcp__github__update_pull_request_branch`

**Write tools left to prompt** (not in allowedTools):
`create_repository`, `delete_file`, `fork_repository`,
`merge_pull_request` (see Never Allow), `pull_request_review_write`.

### Google Developer Knowledge MCP server (read-only)

- `mcp__google-developer-knowledge__get_documents`
- `mcp__google-developer-knowledge__search_documents`

### Read permissions (config files)

Auto-approve reading config files accessed during every `/retrospective`
run. Write/Edit access remains gated.

- `Read(~/.claude/retros.md)`
- `Read(~/.claude/settings.json)`

## Never allow

These tools have been explicitly reviewed and rejected for auto-approval.
Do not add them in future retrospectives — the decision is final unless
the user revisits it.

| Pattern | Reason |
| ------- | ------ |
| `Bash(python3 *)` / `Bash(python *)` | Arbitrary code execution — too broad |
| `Bash(curl *)` / `Bash(curl -s *)` | Can exfiltrate data to arbitrary endpoints |
| `Bash(gcloud storage cp *)` | Write operation — uploads to GCS |
| `Bash(gcloud monitoring *)` / `Bash(gcloud beta monitoring *)` / `Bash(gcloud alpha monitoring *)` | Can modify alerts and dashboards, not read-only |
| `Bash(gh repo create *)` | Creates repositories — infrequent, should always prompt |
| `Bash(gh pr merge *)` / `mcp__github__merge_pull_request` | PRs should be merged manually, never by Claude Code |

## Hooks

### PreToolUse (Bash)

1. **Pre-push lint gate** — Intercepts `git push` commands and runs
   `pre-commit run --all-files` if a `.pre-commit-config.yaml` exists in
   the repo. Blocks the push if linting fails. 120s timeout. Repos without
   pre-commit config are unaffected.

### PostToolUse (Write|Edit)

1. **terraform fmt** — Auto-formats `.tf` files after every Write or Edit.
   Parses the file path from hook stdin JSON via `jq`, skips non-`.tf` files.

2. **terraform validate** — Validates the module directory after `.tf` file
   changes. Only runs if `.terraform/` exists in the file's directory
   (i.e., `terraform init` has been run). 30s timeout.

### PreCompact

Runs `bd prime` before context compaction to preserve task state.

### SessionStart

Runs `bd prime` at session start to load task context.

## StatusLine

Custom status line rendered by [cship](https://github.com/stephenleo/cship)
(v1.4.1, pinned to commit `1e5940e`). Claude Code pipes session JSON to
cship's stdin on every render cycle; cship outputs styled ANSI text for
the TUI status bar.

Config lives at `~/.config/cship.toml`. Usage limits module is disabled
(credential access not needed — `/usage` and the built-in 90% warning
are sufficient).

```json
"statusLine": {
  "type": "command",
  "command": "cship"
}
```

On machines without `cship` installed, Claude Code silently falls back
to the default status line.
