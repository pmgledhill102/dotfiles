---
name: setup-terraform
description: Set up Terraform formatting, linting and security scanning for a project — terraform fmt and validate, tflint, tfsec and checkov, wired into pre-commit and CI.
---

# Set up Terraform tooling

## What to install and configure

### 1. Terraform version

The estate declares two values in the spec's `terraform` block, and this repo
takes both from there rather than choosing its own. Read them from the local
copy, which every surface carries:

```sh
SPEC="${CLAUDE_STANDARDS_SPEC:-$HOME/.claude/standards/github-repo.json}"
python3 -c 'import json, sys; t = json.load(open(sys.argv[1]))["terraform"]; print("floor", t["floor"]); print("pin", t["pin"])' "$SPEC"
```

- **`floor`** is what every root and module declares, as a bare lower bound
  — no `~>`, no `<`:

  ```hcl
  terraform {
    required_version = ">= <floor>"
  }
  ```

  Declare an *older* floor only if the configuration is known to run on it,
  and a newer one only when it uses a feature that needs it. Never raise it
  to match the pin.
- **`pin`** is the exact version CI installs: it goes in the workflow's
  `terraform_version` (step 5), or the `terraform-version` input if the repo
  calls the shared reusable workflow. The cloud sandbox runs the same version.

If an existing repo's floor is above the pin, or its CI runs another version,
stop and report it rather than editing either: moving the pin is one change
across the estate, because state written by a newer Terraform cannot be read
by an older one. The rationale is [github-standards.md, Terraform
versions](../../standards/github-standards.md#terraform-versions).

### 2. tflint

Create `.tflint.hcl` in the project root (if it doesn't already exist). If one exists, review and suggest additions.

```hcl
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.31.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
```

Adjust the cloud provider plugin based on what the project uses (AWS, Azure, GCP). Remove the AWS plugin if not applicable and add the relevant one. If unsure, ask the user.

### 3. .gitignore

Append these lines to `.gitignore` if they aren't already present:

```gitignore
# Terraform
.terraform/
*.tfstate
*.tfstate.backup
crash.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Saved plans. `*.tfplan` alone does not match `tf.plan`, which is the name
# every `-out=` example produces, so a plan can sit untracked-but-not-ignored
# until a `git add -A` sweeps it in. A plan file is a zip of resource
# attributes, so it is the wrong thing to publish by accident.
*.tfplan
tf.plan
*.plan

# Lock files: commit a ROOT's, ignore a MODULE's.
#
# A root lock pins the provider version a plan and apply actually use, so
# HashiCorp recommends committing it -- and it is what gives Dependabot a
# pinned version to raise a pull request against. A blanket ignore leaves a
# repo with no lock and therefore nothing to watch.
#
# A child module inherits the calling root's provider selection, so a lock
# there pins nothing that reaches a plan, and it records a hash per platform,
# so the next `init` on another machine rewrites it and the pre-commit hook
# fails the push.
modules/*/.terraform.lock.hcl
```

**Generate root locks for every platform that runs `init`**, not just the one
that happened to run it:

```sh
terraform -chdir=<root> providers lock \
  -platform=linux_amd64 -platform=darwin_amd64 -platform=darwin_arm64
```

A single-hash lock rewrites itself on the next machine, which surfaces as the
pre-commit hook failing a push with `files were modified by this hook`.

### 4. Add pre-commit hooks

Append these repos to the existing `.pre-commit-config.yaml`:

```yaml
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: <latest tag>
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tflint
        args:
          - --args=--config=__GIT_WORKING_DIR__/.tflint.hcl
      - id: terraform_trivy
        args:
          - --args=--ignorefile=__GIT_WORKING_DIR__/.trivyignore
      - id: terraform_checkov
        args:
          - --args=--config-file=__GIT_WORKING_DIR__/.checkov.yaml
```

Look up the latest release tag and use it for the `rev:` value.

Keep those `args:` even though the bare hook ids look correct and test clean:
each of these three hooks runs once per scanned directory and resolves a
relative config path against *that* directory, so a repo-root `.tflint.hcl`,
`.trivyignore` or `.checkov.yaml` is picked up under `pre-commit run
--all-files` — where the run starts at the root — and silently ignored on an
ordinary commit that touches only a subdirectory. `__GIT_WORKING_DIR__` is
pre-commit-terraform's placeholder for the repository root, so the explicit
path makes both runs read the same config.

### 5. GitHub Actions workflow

Create or update the CI workflow to include Terraform linting and security scanning jobs that only run when Terraform files change. Use a separate workflow file (e.g., `.github/workflows/terraform.yml`) with path filters, or add jobs to an existing workflow.

```yaml
name: Terraform
on:
  push:
    paths: ['**/*.tf', '**/*.tfvars']
  pull_request:
    paths: ['**/*.tf', '**/*.tfvars']

jobs:
  lint:
    name: Terraform Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<full-sha> # <version>
      - uses: hashicorp/setup-terraform@<full-sha> # <version>
        with:
          terraform_version: <pin>  # the spec's terraform.pin, never unset
      - run: terraform fmt -check -recursive
      - run: terraform init -backend=false
      - run: terraform validate

  tflint:
    name: TFLint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<full-sha> # <version>
      - uses: terraform-linters/setup-tflint@<full-sha> # <version>
      - run: tflint --init
      - run: tflint --recursive

  security:
    name: Security Scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<full-sha> # <version>
      - uses: aquasecurity/trivy-action@<full-sha> # <version>
        with:
          scan-type: config
          scan-ref: .
      - uses: bridgecrewio/checkov-action@<full-sha> # <version>
        with:
          directory: .
          framework: terraform
```

Don't duplicate if Terraform lint jobs already exist. Look up latest action versions.

### 6. Dependabot ecosystem

Read `.github/dependabot.yml` and add the `terraform` ecosystem entry if it isn't already present. Don't duplicate entries.

```yaml
  - package-ecosystem: "terraform"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    commit-message:
      prefix: "deps"
      include: "scope"
    labels:
      - "dependencies"
      - "terraform"
    open-pull-requests-limit: 5
    cooldown:
      default-days: 7
```

### 7. Verify

Run `pre-commit run --all-files` to confirm hooks work. Fix any lint or formatting issues.

## Important

- Do NOT overwrite existing configs. Read first and merge.
- If `.pre-commit-config.yaml` doesn't exist, tell the user to run `setup-common` first.
- Ask the user which cloud provider(s) the project targets before configuring tflint plugins.
