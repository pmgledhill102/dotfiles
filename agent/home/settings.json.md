# settings.json — Annotated Reference

This file documents `settings.json` with groupings and rationale.
**Keep this file in sync with `settings.json`** — when adding, removing, or
changing permission rules, update both files together.

## Permissions: allow

### BigQuery (read-only metadata)

`bq query` is **not** auto-approved — its `--use_legacy_sql=false` flag
doesn't constrain the query to SELECT, so it can execute DDL/DML.
Listing and schema-introspection are safe.

- `Bash(bq ls*)`
- `Bash(bq show*)`

### Brew (read-only + services)

- `Bash(brew --prefix *)`
- `Bash(brew info *)`
- `Bash(brew list *)`
- `Bash(brew search *)`
- `Bash(brew services *)`

### Chezmoi

- `Bash(chezmoi *)`

### Session-lifecycle scripts

The `/end-session` and `/start-session` slash commands delegate their
multi-line gather and pipeline steps to dotfiles-managed scripts in
`~/.claude/bin/`. Inline compound shell commands can't match
single-pattern allow rules (a command like `echo A; git status; echo B`
is one string to the matcher, not three matches), so extracting them to
scripts + one prefix rule per command removes recurring approval
prompts. Each rule covers current and future scripts of its respective
prefix; scoped narrowly so unrelated scripts in `~/.claude/bin/` still
prompt.

- `Bash(~/.claude/bin/end-session-*)`
- `Bash(~/.claude/bin/start-session-*)`

The matcher compares rule text against the command **before** shell expansion,
with `*` as the only wildcard. So a rule covering a command that contains a
shell variable has to contain that variable's characters *literally* — the
rule is never expanded, and neither is the command at match time.

There used to be a second pair carrying the full
`${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}` spelling, defaults and all, because the
skills emitted exactly that one string so a single line would work on both the
chezmoi and the plugin channel. Good design for execution, and unforgiving for
matching: that string is neither `~/.claude/bin/…` nor
`${CLAUDE_PLUGIN_ROOT}/bin/…`, so a rule written as either of those covered
nothing. That was the state from #139 until #237 — four rules, zero matches,
every `/start-session` and `/end-session` prompting on its first step with
nothing to indicate why.

The plugin channel was withdrawn (#312), so there is one delivery route and one
spelling. The skills now emit `~/.claude/bin/<script>` on every surface — the
chezmoi path on a workstation, the same path `cloud/bootstrap.sh` installs to
in a sandbox — and the pair above is what carries them. The variable pair went
with the plugin: it matched a string nothing emits any more, which is the same
silent no-match #237 was, just aimed at a command that no longer exists.

`tests/allowlist-covers-commands.py` now checks this mechanically — see the
note there on the one thing it cannot check.

See `docs/end-session-design.md` for the full rationale.

### SessionStart: `session-cache-verdict`

The first `SessionStart` hook (the others are `agent-telemetry-claude-hook` and `wsl-mnt-guard-claude-hook`, below), and
it exists because the question it answers is **only true if asked at the start**.

A cloud environment runs its setup script once, snapshots the filesystem, and
restores that snapshot for later sessions — so a container either rebuilt or
restored, and nothing in the session says which. The fallback way to tell is
elapsed time since the bootstrap installed; run twenty minutes into a session,
that arithmetic reports "hours ago" for a container that rebuilt at startup.
A hook is the only thing that observes early enough for the answer to mean
anything.

It writes `~/.agents/.session-marker` and prints nothing. A `SessionStart`
hook's stdout lands in the agent's context, and build trivia at the top of
every session is a cost paid every time for something read occasionally;
`/start-session` surfaces it when a human is actually looking.

**A no-op off a cloud sandbox.** The first thing it does is test for the
bootstrap manifest and exit 0 when there is none, so a workstation — which has
no manifest, and may have no `jq` — pays a process spawn and nothing else. It
exits 0 unconditionally, because instrumentation must never be why a session
fails to start.

No allow rule is needed: hooks are executed by the harness, not proposed as
tool calls, so the permission matcher is not involved. It rides the existing
`Bash(~/.claude/bin/session-*)` family only if a human runs it by hand.

Why it matters: see [#430](https://github.com/pmgledhill102/agentic-coding-config/issues/430)
and [`docs/cloud-sandbox-design.md`](https://github.com/pmgledhill102/agentic-coding-config/blob/main/docs/cloud-sandbox-design.md)
§2 — the rebuild rate is what decides whether deferring a tool install buys
anything. The full URL rather than a relative path because this file deploys to
`~/.claude/`, where `docs/` does not exist.

### Agent telemetry client

- `Bash(~/.claude/bin/agent-telemetry event *)`
- `Bash(~/.claude/bin/agent-telemetry session-end)`
- `Bash(~/.claude/bin/agent-telemetry session-end *)`
- `Bash(~/.claude/bin/agent-telemetry ship)`
- `Bash(~/.claude/bin/agent-telemetry status)`

The four subcommands an agent runs by hand: `event` (skill step records, #629),
`session-end` (the end-session record), `ship` and `status`. All of them only
append to, read, or send from a local spool, and none can print a secret: the
write key travels in a mode-0600 curl config file and never in argv or output.
`event` additionally drops any key not in the helper's metadata allowlist, so
approving it unattended cannot be turned into a channel for session content.

`record` and `upload-transcript` are deliberately not listed. Only the hooks
below run them, and the hooks are executed by the harness, not proposed as tool
calls, so no rule is needed; a human running one by hand can answer the prompt.

With no `TELEMETRY_INGEST_URL` every one of these only spools and exits 0, which
is why they are safe to allow before the ingest exists. See `cloud/README.md`
("Telemetry") and ADR 026 in the private infrastructure repository.

### GCP credential broker client

- `Bash(~/.claude/bin/gcp-credentials status)`
- `Bash(~/.claude/bin/gcp-credentials release)`

Exact commands, not a prefix — the deliberate omissions are the point.
`status` only reports local state and `release` only undoes local state, so
both are safe to run unattended. `request` is left prompting because it posts
an approval card to Discord and pings a human, and `revoke` because it ends a
grant the human granted; neither should happen without the user seeing it go
by. `refresh` is started by `request` and is not meant to be invoked directly.

See `home/commands/gcp-credentials.md` for the flow, and ADR 021 in
the private infrastructure repository for the design.

### Environment conformance

- `Bash(~/.claude/bin/env-conformance)`
- `Bash(~/.claude/bin/env-conformance *)`

The same two-rule shape as the estate report below, for the same reason: the
bare command is the full run, and `env-conformance *` needs an argument.

Approved unattended because the runner only reads. Every probe is an HTTP
`GET` (a one-byte ranged request, or `gh api` with no method override), a
`command -v`, an environment-variable test or a file read, and
`tests/env-conformance-test.sh` asserts a full run leaves `HOME` and cwd
unchanged. No flag can make it write. `--matrix` names a file to read,
`--answer` carries the agent's own observations into a comparison, and the
rest only select entries or the output format. `env_set` prints only whether
a variable is set, never its value, which matters because the variable it
exists for holds a bearer token. That read-only property is what this rule
relies on, so re-check it whenever a probe function is added.

- `Bash(~/.claude/bin/env-conformance-stamp *)`

The one tool in the suite that writes, approved because of how little it can
write. It rewrites `measured=` lines, only in the stanzas it is named, only in
the matrix file it is given, and it does all or nothing: an unknown id writes
nothing. A single prefix rule is enough because the bare command is a usage
error. The scheduled run uses it on the repo checkout, and the result reaches
`main` only through a PR a human merges.

### Estate report

- `Bash(~/.claude/bin/estate-report)`
- `Bash(~/.claude/bin/estate-report *)`

Two rules because the bare command is the common case and the matcher treats
`estate-report *` as requiring at least one argument — a single prefix rule
would leave the no-argument form prompting every time, which is the failure
[#237](https://github.com/pmgledhill102/agentic-coding-config/issues/237)
found across all four session-lifecycle rules.

Approved unattended because the script is read-only in the strongest sense:
every call it makes is a `GET`, it writes nothing outside a `mktemp -d` it
removes on exit, and it has no flag that changes anything. Every flag it
takes only narrows what it reads or changes how the result is rendered, so
`estate-report *` cannot reach a destructive mode — there isn't one. That
property is what this rule relies on, and it is the thing to re-check when a
flag is added; the flags themselves are listed in the script's `# Usage:`
header and the `estate` skill, not here.

Note what this does *not* approve: the report's **output** is estate evidence,
naming private repos and what is wrong in them. Running it freely is fine;
committing or pasting a run into a public issue is not. See the `estate`
skill for that rule.

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

### GCloud (read-only operations, plus noted exceptions)

Enumerate specific subcommands rather than using wildcards in the middle
of commands. `gcloud storage` is restricted to `cat` and `ls` — no `cp`,
`rm`, or `mv`. Anything that isn't read-only carries its rationale under
its own heading — currently just `gcloud builds` (see below).

#### Artifacts

- `Bash(gcloud artifacts docker images list *)`
- `Bash(gcloud artifacts repositories describe *)`
- `Bash(gcloud artifacts repositories list *)`

#### Auth and config

`gcloud auth list` reports which accounts are configured; it prints no
credential material. The two `print-*-token` forms do, and are in the
Never Allow list below.

- `Bash(gcloud auth list *)`
- `Bash(gcloud config *)`
- `Bash(gcloud info *)`

#### Builds

**The one deliberate non-read-only rule in this section.** The wildcard
covers `gcloud builds submit`, which stages source, runs a build, and
pushes an image — it burns CPU time and money, but it is not
destructive: it creates new artifacts rather than mutating or deleting
existing ones, and a bad build fails without touching what is already
deployed. The read-only inspection calls (`log`, `describe`, `list`)
were the observed friction, but splitting them out while `submit` still
prompts leaves the prompts in place for the calls that actually recur
inside committed build scripts. Approving the whole subcommand is the
simpler rule.

- `Bash(gcloud builds *)`

#### Compute

- `Bash(gcloud compute backend-services describe *)`
- `Bash(gcloud compute backend-services list *)`
- `Bash(gcloud compute firewall-rules describe *)`
- `Bash(gcloud compute firewall-rules list *)`
- `Bash(gcloud compute forwarding-rules describe *)`
- `Bash(gcloud compute forwarding-rules list *)`
- `Bash(gcloud compute images list *)`
- `Bash(gcloud compute instances describe *)`
- `Bash(gcloud compute instances get-serial-port-output *)`
- `Bash(gcloud compute instances list *)`
- `Bash(gcloud compute instances reset *)`
- `Bash(gcloud compute network-endpoint-groups describe *)`
- `Bash(gcloud compute network-endpoint-groups list *)`
- `Bash(gcloud compute networks describe *)`
- `Bash(gcloud compute networks list *)`
- `Bash(gcloud compute networks subnets describe *)`
- `Bash(gcloud compute networks subnets list *)`
- `Bash(gcloud compute operations list *)`
- `Bash(gcloud compute shared-vpc *)`
- `Bash(gcloud compute target-http-proxies describe *)`
- `Bash(gcloud compute target-http-proxies list *)`
- `Bash(gcloud compute url-maps describe *)`
- `Bash(gcloud compute url-maps list *)`

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
- `Bash(gcloud iam workload-identity-pools describe *)`
- `Bash(gcloud iam workload-identity-pools providers describe *)`

#### Logging

`gcloud beta logging tail` streams log entries — read-only despite the
`beta` prefix. `gcloud secrets versions access` is **not** auto-approved
(reads secret material — credential-exfiltration risk).

- `Bash(gcloud beta logging tail *)`
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

`gcloud storage` is restricted to read-only subcommands — `cat`, `ls`,
`du`, and `buckets describe` / `buckets get-iam-policy`. No `cp`, `rm`,
or `mv`.

- `Bash(gcloud storage buckets describe*)`
- `Bash(gcloud storage buckets get-iam-policy*)`
- `Bash(gcloud storage cat *)`
- `Bash(gcloud storage du*)`
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

- `Bash(gh issue create --repo pmgledhill102/*)` — narrower than `gh issue create *`. Restricts auto-approval to issues filed against the user's own repos. **Caveat**: Claude Code's Bash matcher is literal-prefix, so `--repo pmgledhill102/<name>` must be the **first flag** after `gh issue create` for the rule to match. Putting `--title` or `--body-file` first will fall back to manual approval. Symmetric `gh issue comment/edit/close --repo pmgledhill102/*` rules are deliberately deferred — they share the same shape and can be added when the friction surfaces.
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
- `Bash(gh variable list *)`
- `Bash(gh workflow list *)`
- `Bash(gh workflow view *)`

### Git

Standard git workflow operations plus read-only porcelain/plumbing.
Destructive operations (`reset --hard`, `push --force`, `clean`,
`gc`, `prune`) still require prompting.

Deliberately **not** auto-allowed:

- `git config *` — the `--set` form mutates config; per CLAUDE.md,
  Claude must never update git config. Use an explicit prompt.
- `git symbolic-ref *` — has a set form (`git symbolic-ref <name>
  <ref>`). If needed, allow narrowly or prompt.
- `git reflog *` — `expire` / `delete` subcommands mutate the reflog.
- `git gc *`, `git prune *`, `git clean *`, `git fsck *`,
  `git archive *` — rewrite objects, remove data, or slow/specialised.

- `Bash(git add *)`
- `Bash(git blame *)`
- `Bash(git branch *)`
- `Bash(git check-ignore *)`
- `Bash(git checkout *)`
- `Bash(git cherry-pick *)`
- `Bash(git commit *)`
- `Bash(git describe *)`
- `Bash(git diff *)`
- `Bash(git fetch *)`
- `Bash(git for-each-ref *)`
- `Bash(git log *)`
- `Bash(git ls-files *)`
- `Bash(git ls-remote *)`
- `Bash(git ls-tree *)`
- `Bash(git merge *)`
- `Bash(git name-rev *)`
- `Bash(git pull *)`
- `Bash(git push *)`
- `Bash(git range-diff *)`
- `Bash(git remote *)`
- `Bash(git rev-list *)`
- `Bash(git rev-parse *)`
- `Bash(git rm *)`
- `Bash(git shortlog *)`
- `Bash(git show *)`
- `Bash(git stash *)`
- `Bash(git status *)`
- `Bash(git switch *)`
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
- `Bash(go list *)`
- `Bash(go mod tidy)`
- `Bash(go mod tidy *)`
- `Bash(go test *)`
- `Bash(go tool cover *)`
- `Bash(go version *)`
- `Bash(go vet *)`
- `Bash(go-mod-outdated *)`
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

`npm install`, `node *` (arbitrary execution), and bare `npx *` (downloads
and runs arbitrary packages) require prompting. Specific `npx <tool>`
forms for known-safe packages are allowed individually — `playwright`
(test runner) and `slidev` (slide dev server). Add new ones explicitly
when friction surfaces; don't re-broaden to bare `npx *`.

- `Bash(eslint *)`
- `Bash(knip *)`
- `Bash(npm list *)`
- `Bash(npm outdated *)`
- `Bash(npm run *)`
- `Bash(npm test *)`
- `Bash(npm-check-updates *)`
- `Bash(npx playwright *)`
- `Bash(npx slidev *)`
- `Bash(pnpm list *)`
- `Bash(pnpm outdated *)`
- `Bash(pnpm run *)`
- `Bash(pnpm test *)`
- `Bash(yarn list *)`
- `Bash(yarn outdated *)`
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
- `Bash(deptry *)`
- `Bash(mypy *)`
- `Bash(pip list *)`
- `Bash(pip-audit *)`
- `Bash(pylint *)`
- `Bash(pytest *)`
- `Bash(ruff *)`
- `Bash(vulture *)`

### Ruby

`gem install` and `bundle install` require prompting. Linters and
security scanners are safe.

- `Bash(brakeman *)`
- `Bash(bundle-audit *)`
- `Bash(rubocop *)`

### Rust (build, test, and lint only)

`cargo run`, `cargo install`, and `cargo publish` require prompting.

- `Bash(cargo audit *)`
- `Bash(cargo bench *)`
- `Bash(cargo build *)`
- `Bash(cargo check *)`
- `Bash(cargo clippy *)`
- `Bash(cargo doc *)`
- `Bash(cargo fmt *)`
- `Bash(cargo deny *)`
- `Bash(cargo outdated *)`
- `Bash(cargo test *)`
- `Bash(cargo udeps *)`

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
- `Bash(lychee *)`
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
prompting. `command -v` and `which` are both allowed — they are POSIX
equivalents for tool-availability checks, and compound commands like
`command -v X && X --version` need the leading `command -v` matched
separately.

- `Bash(awk *)`
- `Bash(command -v *)`
- `Bash(cp *)`
- `Bash(diff *)`
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

### Process management

Threat model: process kills affect running processes only — not files,
not credentials, not privilege boundaries (the agent already runs as
the user). Worst case is killing the wrong process, which is "annoying"
(restart a dev server, lose unsaved terminal scratch) but never silent
or unrecoverable. The friction relief from not approving every
`pkill -9 -f "<name>"` is worth the recoverable blast radius.

- `Bash(kill *)`
- `Bash(pkill *)` — subsumes `pkill -f *`

### Network diagnostics (read-only)

Port-reachability probes, DNS lookups, and SSH config/auth diagnostics.
All are read-only: `nc -zv` / `nc -uvz` are pure port probes (the `-z`
zero-I/O flag prevents sending data; the `-u` variant probes UDP), `dig`
and `host` are DNS queries, `ssh -G` dumps resolved SSH config without
connecting, and `ssh -o BatchMode=yes -T` is an auth test only (the `-T`
disables PTY allocation so remote command execution is impossible).
`curl` is deliberately NOT listed here — it can exfiltrate data via
arbitrary POSTs (and `curl -s -H 'Authorization: Bearer …'` likewise
remains in the Never Allow list).

- `Bash(dig *)`
- `Bash(host *)`
- `Bash(nc -uvz *)`
- `Bash(nc -zv *)`
- `Bash(ssh -G *)`
- `Bash(ssh -o BatchMode=yes -T *)`

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

- `mcp__google-developer-knowledge__answer_query`
- `mcp__google-developer-knowledge__get_documents`
- `mcp__google-developer-knowledge__search_documents`

### Read permissions (config files)

Auto-approve reading config files accessed during every `/retrospective`
run. Write/Edit access remains gated.

- `Read(~/.claude/retros.md)`
- `Read(~/.claude/settings.json)`

### File-write permissions (scratch space)

**Use `Edit(path)`, never `Write(path)`.** Path-scoped `Write(...)`
rules are not consulted by the file permission check at all — only
`Edit(...)` rules are, and an `Edit` rule covers *every* file-editing
tool, `Write` included. A `Write(...)` rule is therefore dead config:
it grants nothing and the CLI prints a warning about it on every
start. This bit us for months — the two rules below were written as
`Write(...)`, silently granted nothing, and the resulting prompts were
misdiagnosed as a `/tmp` symlink problem (see the `/private/tmp` note
below).

`/tmp` on macOS is per-user, ephemeral, and the standard scratch space —
nothing durable or shared lives there. The blast radius of allowing
writes is "Claude can scribble in scratch space," which is exactly
what scratch space is for.

User-level CLAUDE.md forbids heredocs (`cat <<'EOF'`) and ANSI-C
quoting in bash commands, so any multi-line content for `gh issue
create --body-file`, `gh pr create --body-file`, etc. has to flow
through a temp file. Auto-approving `Edit(/tmp/**)` removes the
double-prompt friction (one for the command, one for the temp file)
that otherwise discourages the structured-body pattern.

- `Edit(/tmp/**)` — scratch space for staging long, structured content
  (issue bodies, PR bodies, etc.) before passing to a CLI via
  `--body-file` or `$(cat ...)`. Restrict scope further to
  `Edit(/tmp/claude-*)` (with a naming-convention discipline) if the
  broad rule ever feels uncomfortable.
- `Edit(/private/tmp/**)` — the same grant, spelled the way macOS
  resolves it. `/tmp` is a symlink to `/private/tmp` there, and paths
  reach the permission check already resolved (the session scratchpad
  is handed to Claude as `/private/tmp/claude-<uid>/...`), so the
  `/tmp/**` glob alone can miss. Both spellings are kept: Linux has no
  such symlink and uses the `/tmp/**` form.

**Removed: `Edit(~/dev/paul-context/_incoming/**)`.** This granted the
journal-draft inbox for the cross-repo retrospective skill, naming one
machine's layout. #300 taught that skill to discover a `paul-context`
checkout wherever it sits, which left the rule covering only the
conventional location — so a retro standing in a checkout anywhere else
(a cloud session has it at `/home/user/paul-context`) picked the
filesystem route and only then hit the allow rules. Interactively that
is a prompt; headless it is a denial with no recovery, because the
skill's guard is `[ -w "<pc>/_incoming" ]` — a *filesystem* writability
test, not a permission test — so the Issue fallback had already been
skipped by the time the write failed, and the retro's whole output was
lost at the last step (#303).

The fix is in the skill, not in a broader rule. `/retrospective` now
stages every draft to `/tmp/<filename>` first and copies it into
`<pc>/_incoming/` from there, so the only write path is one that
`Edit(/tmp/**)` and `Bash(cp *)` already cover — on any checkout root,
on any surface — and a failed copy falls through to the Issue route
with the draft still on disk. That makes this rule dead config, and a
rule granting nothing is worse than no rule: it reads as coverage.

The alternative was broadening the glob to something like
`Edit(**/paul-context/_incoming/**)`. Not taken, because whether a
leading `**/` is honoured by the permission matcher is unverified —
the three surviving `Edit` rules are all anchored absolute paths, and
the `/tmp` vs `/private/tmp` pair above is this file's own precedent
for enumerating spellings rather than trusting the matcher to unify
them. Staging through `/tmp` sidesteps the question entirely.

Unchanged: `_incoming/` is `.gitignored` in `paul-context`, so drafts
are local-only until `/promote-journal-inbox` drains them into
`journal/`; that command runs from a `paul-context` checkout, wherever
it sits. See
`paul-context/decisions/2026-05-05-journal-inbox-promotion.md` for the
full rationale.

## Permissions: deny

```json
"deny": [
  "Bash(gcloud auth print-access-token:*)",
  "Bash(gcloud auth print-identity-token:*)",
  "Bash(gcloud auth application-default print-access-token:*)"
]
```

The three token-printing forms the broker policy forbids. Until this block
existed, `permissions` had exactly one key — `allow` — which is why removing
`Bash(gcloud auth print-access-token *)` from the allowlist in 2026-08 did
less than it looked: **removing a command from the allowlist only makes it
prompt, it does not block it** (#440). What stood between an agent and a live
token in the transcript was a prose rule and a permission prompt.

**`deny` is the workstation half only, and that is the smaller half.** The
permission allowlist travels in a repo's own `.claude/settings.json` and no
delivery channel carries it to a cloud session, so these rules do nothing on
the surface where a brokered token actually lives. The `credguard-claude-hook`
entry under PreToolUse below is the half that reaches both surfaces, which is
why the same three forms are matched twice rather than once. Keep them in
step: a form added here and not there is enforced on the machine that needs it
least.

## Never allow

These tools have been explicitly reviewed and rejected for auto-approval.
Do not add them in future retrospectives — the decision is final unless
the user revisits it.

| Pattern | Reason |
| ------- | ------ |
| `Bash(python3 *)` / `Bash(python *)` | Arbitrary code execution — too broad |
| `Bash(go run *)` | Arbitrary code execution — same shape as `python *` |
| `Bash(curl *)` / `Bash(curl -s *)` / `Bash(curl -s -H Authorization: Bearer*)` | Can exfiltrate data to arbitrary endpoints; auth-header + URL form is especially dangerous |
| `Bash(yq *)` | `yq -i` mutates files in place — flag isn't constrainable here |
| `Bash(bq query --use_legacy_sql=false*)` | Flag doesn't constrain to SELECT; can run DDL/DML |
| `Bash(gcloud storage cp *)` | Write operation — uploads to GCS |
| `Bash(gcloud run services update-traffic *)` | Mutates production Cloud Run traffic |
| `Bash(gcloud secrets versions access *)` | Reads secret values — credential-exfiltration risk |
| `Bash(gcloud auth print-access-token *)` / `Bash(gcloud auth print-identity-token *)` | Prints a live credential to stdout, i.e. into the transcript and therefore into model context — the exact exfiltration path the credential broker exists to close. `home/commands/gcp-credentials.md` forbids running these in bold ("Never run `gcloud auth print-access-token`"), so auto-approving them made the forbidden action the frictionless one on every local machine. Removed 2026-08; do not re-add |
| `Bash(gcloud monitoring *)` / `Bash(gcloud beta monitoring *)` / `Bash(gcloud alpha monitoring *)` | Can modify alerts and dashboards, not read-only |
| `Bash(gh api *)` / `Bash(gh api repos/*)` | Full GitHub API including POST/PATCH/DELETE — prefer `mcp__github__*` |
| `Bash(gh repo create *)` | Creates repositories — infrequent, should always prompt |
| `Bash(gh pr merge *)` / `mcp__github__merge_pull_request` | PRs should be merged manually, never by Claude Code |

## Hooks

This file is the only declaration of the hooks below; `cloud/bootstrap.sh`
fetches it and merges its `.hooks` block, which is what carries them to a
cloud session — see "One set of hooks, two surfaces, one declaration" at the
end of this section. The `home/hooks/hooks.json` plugin copy this note used to
point at went away with the plugin in #312.

### PreToolUse (Bash)

1. **Credential-printing guard** — `~/.claude/bin/credguard-claude-hook`.
   **Blocks** with `exit 2` when a Bash command would print a live credential:
   the three `gcloud` token-printing forms from the deny block above, tolerant
   of interleaved flags and line continuations, plus an
   `Authorization: Bearer` header anywhere in a command — that one because
   `/proc/<pid>/cmdline` is world-readable, so a token in argv is exposed to
   every other process for the life of the call (#375). 5s timeout, and it
   runs first in the array because it is the cheapest and the only blocker
   whose whole job is to fire before anything else happens.

   **This is a guardrail, not a security boundary.** It matches strings in a
   Bash command, so `eval`, variable indirection, `$(printf …)` and aliases
   all defeat it — `tests/credguard-test.sh` asserts two such evasions are
   *allowed*, so the limit is visible rather than assumed. It is not trying to
   contain a hostile agent. It is trying to stop drift, and to stop a
   **compliant** agent faithfully following installed instruction text that
   tells it to print a token — which is exactly what #439 found shipped in a
   third-party skill, and what #377 showed beating the broker in a live
   sandbox. Resist making it cleverer: a guard that looks airtight invites
   someone to trust it as containment.

   One accepted false positive: the phrase blocks even inside an `echo`.
   `precommit-claude-hook` matches positionally to avoid exactly this (#191),
   and the trade is deliberately the other way here — telling an echo from an
   invocation needs real parsing, and the costs are asymmetric: a blocked echo
   is rephrased, a leaked token is rotated.

   **One carve-out (#691):** the body of a heredoc fed to `cat`, `tee`,
   `python*`, `node`, `ruby` or `perl` is not scanned for the bearer header.
   That body travels on stdin, never in argv, so writing a Go file or patching
   docs that mention the header is not the exposure the check exists for. It is
   deliberately narrow. A heredoc whose line names a shell (`bash <<EOF`,
   `cat <<EOF | sh`) stays in view, because its body is code and a `curl -H` in
   it is argv; an unterminated heredoc is left whole; and the `gcloud` forms are
   still matched against the whole command. The wider fix the issue floated,
   blocking only next to a network tool, was rejected: it would let
   `printf '…Bearer %s' "$(cat token)"` through, and that `printf` puts the
   live token in its own argv. `tests/credguard-test.sh` pins each of these,
   and records a `python3` body that shells out to `curl` as *allowed*, the
   same way the guard already accepts being evaded.

   **Considered and rejected: `terraform output`.** The broker skill names it
   as a third way a token can reach the transcript, and the guard deliberately
   does not match it (#520). Do not re-file it without one of the triggers
   below.

   - **The guard sees the command, not the value.** The `gcloud` forms are
     caught because the command *is* the tell. `terraform output` is an
     ordinary command whose danger depends on which output it names and what
     that output holds, and neither is in the Bash string.
   - **A broad match blocks a normal workflow.** `terraform output` and
     `terraform output -json` are how Terraform state is read — the allow rule
     under Terraform above exists for that reason — and a guard that stops
     them is one people switch off.
   - **A narrow match needs a naming convention that does not exist.** A
     pattern on `token|secret|key|password` in the output name catches
     `db_password`, misses `sa_credential` and blocks `token_bucket_name`.
   - **`sensitive = true` already redacts.** Terraform will not print a
     sensitive output in plain form, so the correctly declared case never
     reaches a hook. The uncovered case is an output that should be sensitive
     and is not — a Terraform defect, better caught where it is written
     (`tflint`/`checkov`) than by string-matching a command line.

   Revisit only if an output-naming convention lands and is checked, or a
   session actually prints a credential this way.

   Fail-open when `jq` is missing or the payload carries no command.

2. **pr-checks registration-race rewrite** —
   `~/.claude/bin/prchecks-wait-claude-hook`. Rewrites
   `gh pr checks ... --watch` commands (via `hookSpecificOutput.updatedInput`,
   which replaces the tool's arguments before execution) to run through
   `~/.claude/bin/gh-pr-checks-wait`. The wrapper polls until GitHub has
   registered at least one check run (5s interval, ~2 min cap), then execs
   the real `gh pr checks` with the original arguments. 10s timeout — the
   hook itself only inspects and rewrites; the waiting happens in the
   rewritten command.

   Why: check runs register a variable 0-60s+ after `gh pr create`, and
   `--watch` treats "no checks yet" as terminal ("no checks reported")
   rather than pending — gh has no native wait-for-registration flag. A
   deterministic rewrite beats a prose note that gets skipped under
   momentum, and attaching the wait to the *checking* side (only when
   `--watch` is present) beats a fixed sleep after `pr create`, which
   penalises every PR creation and can still lose the race.

   Fail-open/no-op when: the command isn't `gh pr checks ... --watch`,
   it's already wrapped (never rewrites twice), `jq` is missing, or the
   wrapper isn't deployed yet (fresh machine before `chezmoi apply`).
   The wrapper itself gives up early (3 consecutive probe errors that
   aren't "no checks reported" — bad selector, offline, auth) and always
   falls through to the real command, so the worst case is gh's own error,
   never a hang. The companion allow rule
   `Bash(~/.claude/bin/gh-pr-checks-wait *)` keeps the rewritten command
   auto-approved, matching the existing `Bash(gh pr checks *)` grant.

3. **PR-state push guard** — `~/.claude/bin/prepush-guard-claude-hook`.
   Before any `git push` Claude makes, asks GitHub (`gh api
   repos/<owner>/<repo>/pulls?head=<owner>:<branch>&state=all`, REST because
   cloud sandboxes refuse the GraphQL behind `gh pr view`) whether the pushed branch's PR is already `MERGED`/`CLOSED`, and if so
   **blocks** with `exit 2` and instructions to restart the branch from the
   latest default branch. 30s timeout.

   This enforces mechanically what the CLAUDE.md prose rule ("check the PR is
   still open before pushing follow-up commits") failed to: the user merges a
   PR via the GitHub UI mid-session, the branch auto-deletes, and the next
   push silently recreates it as an orphan — `* [new branch]` in unread output
   is the only tell, and recovery costs a cleanup cycle. GitHub is the
   authority because local state is useless here: the stale remote-tracking
   ref survives the remote deletion until a `fetch --prune`.

   **Fail-open by design** — the guard stops one specific silent mistake
   without making pushing fragile. It allows the push when: the command isn't
   a `git push`; `--no-verify` is present (still honoured, but never
   suggested: an auto-mode classifier denies it as weakening a safeguard, so
   advice to use it strands an agent); the push is `--delete`/`-d` or `--tags`; `gh` or
   `jq` is missing; HEAD is detached; the branch is the default branch; the
   branch has no PR; the PR is open; or the lookup fails for any reason
   (offline, auth, a proxy 403), or origin is not a github.com remote; each
   of those prints a `not checked` line rather than passing silently. An open
   PR for the branch wins over older closed ones, so re-using a branch name under a new PR is not a false positive.

   **A merged PR's branch name may be reused for new work** — the cloud
   harness instructs exactly that — so a branch **restarted from the up-to-date
   default branch** is allowed, with one notice line (#651). The test is two
   `merge-base` calls: the merged PR's head is already in `origin/<base>`, and
   the pushed tip forks from `origin/<base>` somewhere the old head does not
   reach. What stays blocked is the orphan shape — new commits stacked on the
   merged PR's own history — and a branch whose PR closed unmerged. No fetch:
   an `origin/<base>` older than the merge fails the first test, which errs
   towards blocking, and the block message says to fetch.

   **It judges the branch the push targets**: each refspec's destination
   (`origin x`, `HEAD`, `src:dst`, `refs/heads/` stripped, deletions skipped),
   or the checked-out branch when none is named. A refspec-less push after a
   `checkout`/`switch` in the same command stands down as not checked, because
   the hook runs before the checkout does.

   **Which repo it judges is the whole of #404.** A PreToolUse hook fires
   before the command runs, so the payload's `cwd` is where the shell already
   is, not where `cd /other/clone && git push` is about to be. Reading `cwd`
   blindly blocked three pushes in one session, each naming a merged branch in
   a repository the push was not aimed at — and since a PreToolUse denial
   rejects the *whole* Bash call, one of them discarded a heredoc written
   earlier in the same command, so the guard destroyed work it was not
   guarding. It now walks the command's segments in order, following `cd` and
   `git -C` to the directory the push will actually run in.

   Anything it cannot resolve statically — a variable, a glob, a command
   substitution, a quoted path — **skips the guard** rather than guessing. The
   costs are asymmetric and that asymmetry is the design: an unguarded push
   costs one orphan branch, a false positive costs the entire tool call.

   Fixed in the same pass: the fast-exit matched the literal phrase
   `git push`, so `git -C <path> push` never reached the guard at all — one of
   the two shapes #404 is about was silently waved through. It now matches
   positionally, the way `precommit-claude-hook` classifies.

4. **pre-commit lint gate** — `~/.claude/bin/precommit-claude-hook`. A single
   script that runs the pre-commit framework against the repo's
   `.pre-commit-config.yaml` on the `git commit` / `git push` commands Claude
   makes via its Bash tool, **blocking** on failure with `exit 2` (the only
   PreToolUse exit code that both stops the tool call and feeds stderr back to
   Claude — `exit 1` and other non-zero codes are non-blocking). 120s timeout.

   This is the global replacement for the commit/push-stage hooks that
   `init.templatedir` git-templates used to install per-repo — part of the
   vanilla-git migration that removed those templates.

   Two stages:
   - `git commit` → `--hook-stage pre-commit` on the **staged delta** (fast;
     correct commit-stage semantics). Falls back to `--all-files` for
     `git commit -a`/`--all`, where git stages files *after* the hook fires.
     A `git add` earlier in the same command is the same situation, but is
     deliberately **not** widened to `--all-files` (that would turn a
     commit-stage check into a whole-tree one); a block there instead ends with
     a note that the staged set was read before the command ran, so the fix is
     to stage in a separate call (#696).
   - `git push` → `--hook-stage pre-push --all-files` (whole-tree backstop
     before CI; also covers manual / `--no-verify` commits the commit stage
     never saw).

   **Silent on success:** output is captured and emitted only on failure, so
   passing checks add nothing to the transcript or to context. Fast-exits
   (no-op) when: the command isn't a `git commit`/`git push`, `--no-verify`/`-n`
   is present, no `.pre-commit-config.yaml` exists, or `pre-commit` isn't
   installed. Only governs commands Claude runs via its Bash tool — manual
   terminal commits/pushes are CI-backed.

### SessionStart, Stop, UserPromptSubmit, UserPromptExpansion and PreToolUse (Skill): `agent-telemetry-claude-hook`

Five entries that drive the telemetry helper (agentic-coding-config#431, #625
and #788).

1. **SessionStart** (`agent-telemetry-claude-hook session-start`), beside
   `session-cache-verdict`. Records the session marker into the spool, then
   ships. Hooks matching one event run side by side with no ordering guarantee,
   so it cannot assume the marker is written yet: it waits for it (up to five
   seconds) in a **detached** subshell, so the session never waits on telemetry.
   Prints nothing, because a SessionStart hook's stdout reaches the agent's
   context.
2. **Stop**, throttled to once per five minutes by a timestamp file (Stop fires
   after every turn). Ships the spool and uploads the transcript tail, both
   detached. The transcript path comes from `transcript_path` in the hook
   payload, which is why the Claude-specific parsing lives in a wrapper and the
   helper itself stays vendor-neutral.

   It also records a `hook stop` event on **every** turn, unthrottled, and on
   the throttled path a `session shape` snapshot before the ship (#625).
3. **UserPromptSubmit** (`agent-telemetry-claude-hook prompt-submit`) records
   one `hook prompt-submit` event, detached. With `hook stop` it is the raw
   material for "was someone watching?": a prompt soon after a Stop marks that
   stretch as watched. That verdict is computed offline from the timestamps,
   never in the session. Prints nothing, because this hook's stdout is added
   to the prompt's context.
4. **PreToolUse, matcher `Skill`** and
5. **UserPromptExpansion**, both `agent-telemetry-claude-hook skill`. Each
   records one `skill invoke` event carrying two fields: `skill`, the skill's
   name, and `via`, which is `tool` when the model called the Skill tool and
   `slash` when someone typed `/name`. They are two entries because they are two
   paths: a typed command expands into the prompt and never reaches
   `PreToolUse`, so the Skill matcher alone would miss every skill a person
   starts by hand.

   **Why a hook at all.** Claude Code's own `skill_activated` event names
   built-in skills but reports every user-defined one as `custom_skill` unless
   `OTEL_LOG_TOOL_DETAILS=1`, and that switch also logs every tool's parameters
   and input. This estate's skills are user-defined, so the hook is how their
   names are recorded with that switch left off.

   **What it does not record.** It reads `tool_input.skill` (or `command_name`)
   and nothing else: not the skill's arguments, not the prompt, not the working
   directory. A name with a character outside the helper's value charset
   (`A-Za-z0-9._:/@+,#=-`), or longer than 120 characters, is recorded as the
   literal `invalid` rather than cleaned up, so text passed off as a skill name
   leaves nothing of itself behind. `UserPromptExpansion` also fires for custom
   slash commands, so a command's name is recorded the same way; an MCP prompt
   is not.

   **It cannot hold up a skill.** Inline it reads stdin and runs one `jq`; the
   helper call is detached, so a slow or hung helper costs the Skill call
   nothing. It prints nothing, because a `PreToolUse` hook's stdout is read as
   a decision about the tool call, and it exits 0 on every path, including no
   `jq`, an empty payload and a payload it cannot parse.

The SessionStart entry also puts the toolchain shims (`~/.claude/bin/shims/`,
made by the cloud bootstrap) ahead on the Bash tool's `PATH`, by appending to
`CLAUDE_ENV_FILE`. That is how a hook changes the agent's environment without
a second SessionStart entry or a `PATH` in `env`, which cannot reference the
inherited value. No shims directory, no line: laptops are unaffected.

All exit 0 unconditionally: instrumentation must never be why a session fails
to start, a turn fails to end or a skill fails to run. With no `TELEMETRY_INGEST_URL` they spool and
do nothing else, so wiring them before the ingest exists is safe. 5 s timeouts,
because nothing they do inline is slow.

### SessionStart: `wsl-mnt-guard-claude-hook`

The third `SessionStart` hook, and the only one that prints. On WSL the Windows
host is mounted at `/mnt/<drive>`, and the WSL profile's policy is that an agent
works only on the distro's own filesystem (#569). A session whose `cwd` is under
`/mnt/<drive>` gets one line of context saying so, and asking it to check with
the user before working there. Printing is the point here: a `SessionStart`
hook's stdout is how a fact reaches the agent before its first turn.

**A no-op off WSL**, so it ships in this one shared file. It reads
`/proc/version` before anything else and exits 0 unless the kernel is
Microsoft's. macOS has no `/proc`, and a cloud sandbox's kernel is not
Microsoft's, so both pay a process spawn and print nothing.

Fail-open and exit 0 unconditionally, following `credguard-claude-hook`: no
`jq`, a payload it cannot parse, or no `cwd` prints nothing. It is a
guardrail, not a security boundary. It advises once at the start and does not
stop a later `cd /mnt/c` or a write there.

**A `PreToolUse` block on `Write|Edit` under `/mnt/<drive>` is not wired.** It
would catch work drifting there mid-session, but it would also block a write the
user asked for, so it needs a session override to be livable. That decision
belongs on #569. `SessionStart` alone is the minimum the issue sets.

### SessionStart: `toolchain-start --hook`

The fifth `SessionStart` hook (#631). It starts the deferred toolchain install
in a container bootstrapped with `--toolchain=background`: the pre-commit
toolchain and its hook-environment warm, which ADR-0021's 2026-11-10 amendment
moves out of the setup phase, because a rebuild's setup is watched and the
toolchain is first needed minutes later.

It launches the bootstrap again at the same resolved sha, as `--toolchain=run`,
with `setsid nohup`, and returns at once. The install writes its own manifest
and state file under `~/.agents/toolchain/`. The global git hook and the shims
wait on that state, and the same helper restarts a run whose process died, so a
reaped install is restarted rather than waited on forever.

**A no-op wherever nothing was deferred.** It does nothing unless
`~/.agents/toolchain/args` exists, which only a background-mode bootstrap
writes. So it ships in this one shared file and is silent on workstations and
eager-mode containers. It prints nothing and exits 0 unconditionally, and the
5 s timeout is generous for a launcher that forks and returns.

### SessionStart: `dockerd-start-claude-hook`

The fourth `SessionStart` hook (#683). A Claude Code cloud sandbox ships
`dockerd`, `containerd` and `runc` but starts no daemon, so `docker info` fails
until something starts one. This starts `dockerd` once per session and again
after a resume, because the process does not survive a worker restart while
`/var/lib/docker` (images and build cache) does.

It writes `/etc/docker/daemon.json` with a `mirror.gcr.io` registry mirror only
when no `daemon.json` exists: Docker Hub answers 429 to the sandbox's shared
egress IP on anonymous pulls, and the mirror is what makes base images pull. The
daemon is started with `setsid nohup` from the hook's own environment, so it
inherits `HTTPS_PROXY` and image pulls and `ADD <url>` go through the agent
proxy. It waits up to 10 s for the socket, hence the 20 s timeout.

**A no-op off a cloud sandbox**, so it ships in this one shared file: it exits 0
unless `CLAUDE_CODE_REMOTE=true`, the user is root, and both `dockerd` and
`docker` are on `PATH`. A daemon that already answers `docker info` is left
alone, which is what makes it idempotent. It prints nothing and exits 0
unconditionally: a session must not fail to start over a daemon.

The bootstrap delivers it under `--with-hooks`, not from the setup script,
because a hook-started daemon is proven to survive the hook and a resume
(#683), where one started during the setup phase is not.

### PostToolUse (Write|Edit)

1. **terraform fmt** — Auto-formats `.tf` files after every Write or Edit.
   Parses the file path from hook stdin JSON via `jq`, skips non-`.tf` files.

2. **terraform validate** — Validates the module directory after `.tf` file
   changes. Only runs if `.terraform/` exists in the file's directory
   (i.e., `terraform init` has been run). 30s timeout.

Both are written in POSIX `sh` (`case`, not `[[ ]]`) and lead with
`command -v terraform || exit 0`. The bash-only test was fine on a workstation
and silently never matched under `dash`, which is what a Linux sandbox is
likely to run these with; the `command -v` guard keeps a sandbox that edits a
`.tf` file from emitting "terraform: not found" on every Write.

### One set of hooks, two surfaces, one declaration

This block is the only declaration of the hooks above, and both surfaces read it:

- **workstation** — chezmoi deploys this file to `~/.claude/settings.json`
- **cloud sandbox** — `cloud/bootstrap.sh --with-hooks` fetches *this* file and
  merges its `.hooks` into the container's `~/.claude/settings.json`, rather
  than restating the wiring in the script where it would drift

Both spell the commands `~/.claude/bin/<hook>`, and both install the scripts
there, so one source serves both.

It was declared twice until #312. `home/hooks/hooks.json` carried a plugin copy,
and because Claude Code runs every matching hook from every source, a machine in
a plugin-enabled repo had both live at once — `precommit-claude-hook` running
pre-commit twice on every commit is up to 120s of duplicated work on the hottest
path there is. The three script hooks therefore went through
`bin/plugin-hook-dispatch`, which stood down when `~/.claude/bin/<hook>` existed
so the chezmoi copy won wherever it was deployed. The two terraform hooks are
inline commands with no dispatcher and did run twice where both channels were
live — accepted at the time, since `fmt` is idempotent and instant and
`validate` re-reads an already-initialised module. With the plugin withdrawn
there is one copy, and the dispatcher went with it.

`prchecks-wait-claude-hook` still resolves its wrapper as
`$(dirname "$0")/gh-pr-checks-wait` rather than at a fixed `~/.claude/bin` path.
That was what let one file serve both channels; it now simply keeps the hook
working from wherever it was installed, which is what the sandbox needs.

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
