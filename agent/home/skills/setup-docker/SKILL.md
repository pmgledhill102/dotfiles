---
name: setup-docker
description: Set up container linting and image security scanning for a project that has a Dockerfile or Containerfile — hadolint and trivy, wired into pre-commit and CI.
---

# Set up Docker linting and scanning

This skill is about linting and scanning. To build or run images in a cloud sandbox, see `sandbox-docker`.

## What to install and configure

### 1. Hadolint

Create `.hadolint.yaml` in the project root (if it doesn't already exist). If one exists, review and suggest additions.

```yaml
ignored:
  - DL3008  # Pin versions in apt-get install
  - DL3018  # Pin versions in apk add

trustedRegistries:
  - docker.io
  - gcr.io
  - ghcr.io
```

### 2. .gitignore

No Docker-specific entries needed. Confirm `setup-common` has already created a `.gitignore` with the standard entries.

### 3. Add pre-commit hooks

Append this repo to the existing `.pre-commit-config.yaml`:

```yaml
  - repo: https://github.com/hadolint/hadolint
    rev: <latest tag>
    hooks:
      - id: hadolint
```

Look up the latest release tag and use it for the `rev:` value.

`id: hadolint` runs the locally installed `hadolint` binary, so it is a
prerequisite: check it is on `PATH` and, if it isn't, tell the user to install
it (`brew install hadolint`) and stop. Use it in preference to the
`hadolint-docker` variant, which runs the linter in a container: on a machine
with no working Docker daemon that hook does not skip, it aborts the entire
pre-commit run with exit 3, which blocks every commit in the repo rather than
just the Dockerfile check.

### 4. GitHub Actions workflow

Create or update the CI workflow to include Docker linting and security scanning jobs that only run when Dockerfiles change. Use a separate workflow file (e.g., `.github/workflows/docker.yml`) with path filters, or add jobs to an existing workflow.

```yaml
name: Docker
on:
  push:
    paths: ['**/Dockerfile*', '**/docker-compose*.yml']
  pull_request:
    paths: ['**/Dockerfile*', '**/docker-compose*.yml']

jobs:
  hadolint:
    name: Hadolint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<full-sha> # <version>
      - uses: hadolint/hadolint-action@<full-sha> # <version>
        with:
          dockerfile: Dockerfile

  trivy:
    name: Trivy
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<full-sha> # <version>
      - uses: aquasecurity/trivy-action@<full-sha> # <version>
        with:
          scan-type: 'fs'
          scanners: 'misconfig'
```

Don't duplicate if Docker lint jobs already exist. Look up latest action versions.

If the project builds container images, suggest also adding an image scan step that runs `trivy image` after the build.

### 5. Dependabot ecosystem

Read `.github/dependabot.yml` and add the `docker` ecosystem entry if it isn't already present. Don't duplicate entries.

```yaml
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    commit-message:
      prefix: "deps"
      include: "scope"
    labels:
      - "dependencies"
      - "docker"
    open-pull-requests-limit: 5
    cooldown:
      default-days: 7
```

### 6. Verify

Run `pre-commit run --all-files` to confirm hooks work. Fix any lint issues.

Check the command's exit code, not just the per-hook lines: a hook whose
runtime is missing aborts the whole run and is reported as neither `Passed` nor
`Failed` against any hook. Exit 0 means every hook passed and exit 1 means a
hook found issues — anything else is a broken hook configuration, not a lint
failure, and must be fixed before the setup is finished.

## Important

- Do NOT overwrite existing configs. Read first and merge.
- If `.pre-commit-config.yaml` doesn't exist, tell the user to run `setup-common` first.
- If the project has multiple Dockerfiles, configure hadolint-action to scan all of them.
