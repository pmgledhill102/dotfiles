# settings.json — Annotated Reference

This file documents `settings.json` with groupings and rationale.
**Keep this file in sync with `settings.json`** — when adding, removing, or
changing permission rules, update both files together.

## Permissions: allow

### Beads / BD (task management)

- `Bash(bd *)`
- `Bash(beads *)`

### Brew (read-only)

- `Bash(brew --prefix *)`
- `Bash(brew info *)`
- `Bash(brew list *)`
- `Bash(brew search *)`

### Chezmoi

- `Bash(chezmoi -h)`
- `Bash(chezmoi --help)`

### Docker

- `Bash(hadolint *)`
- `Bash(docker build *)`
- `Bash(docker compose *)`
- `Bash(docker container prune *)`
- `Bash(docker info *)`
- `Bash(docker inspect *)`
- `Bash(docker logs *)`
- `Bash(docker network prune *)`
- `Bash(docker ps *)`
- `Bash(docker rm *)`
- `Bash(docker run *)`
- `Bash(docker stop *)`

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
- `Bash(gcloud compute instances list *)`
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

### GitHub CLI (read-only, plus PR creation)

Read/view operations and PR creation. Merging, closing PRs/issues
and `gh api` (which can POST/DELETE) require prompting.

- `Bash(gh issue list *)`
- `Bash(gh issue view *)`
- `Bash(gh pr checks *)`
- `Bash(gh pr create *)`
- `Bash(gh pr diff *)`
- `Bash(gh pr list *)`
- `Bash(gh pr view *)`
- `Bash(gh repo view *)`
- `Bash(gh run list *)`
- `Bash(gh run view *)`
- `Bash(gh run watch *)`
- `Bash(gh workflow list *)`
- `Bash(gh workflow view *)`

### Git

Read-only and local-only operations. Remote operations (`push`, `rebase`,
`reset`) require prompting.

- `Bash(git add *)`
- `Bash(git branch *)`
- `Bash(git checkout *)`
- `Bash(git commit *)`
- `Bash(git diff *)`
- `Bash(git fetch *)`
- `Bash(git log *)`
- `Bash(git ls-tree *)`
- `Bash(git remote *)`
- `Bash(git show *)`
- `Bash(git stash *)`
- `Bash(git status *)`
- `Bash(git tag *)`
- `Bash(git worktree *)`

### Go (build, test, and lint only)

`go run`, `go get`, and `go install` require prompting as they execute
or download code.

- `Bash(go build *)`
- `Bash(go doc *)`
- `Bash(go env *)`
- `Bash(go fmt *)`
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

### Shell utilities (read-only)

`curl` (can exfiltrate data), `chmod` (changes permissions), and `make`
(executes arbitrary targets) require prompting.

- `Bash(echo *)`
- `Bash(find *)`
- `Bash(grep *)`
- `Bash(jq *)`
- `Bash(ls *)`
- `Bash(lsof *)`
- `Bash(which *)`

## Hooks

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
