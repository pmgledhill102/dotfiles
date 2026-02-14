Set up Terraform linting, formatting, and security scanning for this project. Assumes `/setup-common` has already been run (pre-commit framework is in place).

## What to install and configure

### 1. tflint

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

### 2. .gitignore

Append these lines to `.gitignore` if they aren't already present:

```gitignore
# Terraform
.terraform/
*.tfstate
*.tfstate.backup
*.tfplan
.terraform.lock.hcl
crash.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
```

### 3. Add pre-commit hooks

Append these repos to the existing `.pre-commit-config.yaml`:

```yaml
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: <latest tag>
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tflint
      - id: terraform_tfsec
      - id: terraform_checkov
```

Look up the latest release tag and use it for the `rev:` value.

### 4. GitHub Actions workflow

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
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - run: terraform fmt -check -recursive
      - run: terraform init -backend=false
      - run: terraform validate

  tflint:
    name: TFLint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: terraform-linters/setup-tflint@v4
      - run: tflint --init
      - run: tflint --recursive

  security:
    name: Security Scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aquasecurity/tfsec-action@v1.0.3
      - uses: bridgecrewio/checkov-action@v12
        with:
          directory: .
          framework: terraform
```

Don't duplicate if Terraform lint jobs already exist. Look up latest action versions.

### 5. Dependabot ecosystem

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
```

### 6. Verify

Run `pre-commit run --all-files` to confirm hooks work. Fix any lint or formatting issues.

## Important

- Do NOT overwrite existing configs. Read first and merge.
- If `.pre-commit-config.yaml` doesn't exist, tell the user to run `/setup-common` first.
- Ask the user which cloud provider(s) the project targets before configuring tflint plugins.
