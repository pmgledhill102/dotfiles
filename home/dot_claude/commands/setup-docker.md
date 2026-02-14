Set up Docker linting and security scanning for this project. Assumes `/setup-common` has already been run (pre-commit framework is in place).

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

No Docker-specific entries needed. Confirm `/setup-common` has already created a `.gitignore` with the standard entries.

### 3. Add pre-commit hooks

Append this repo to the existing `.pre-commit-config.yaml`:

```yaml
  - repo: https://github.com/hadolint/hadolint
    rev: <latest tag>
    hooks:
      - id: hadolint-docker
```

Look up the latest release tag and use it for the `rev:` value.

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
      - uses: actions/checkout@v4
      - uses: hadolint/hadolint-action@v3.1.0
        with:
          dockerfile: Dockerfile

  trivy:
    name: Trivy
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aquasecurity/trivy-action@master
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
```

### 6. Verify

Run `pre-commit run --all-files` to confirm hooks work. Fix any lint issues.

## Important

- Do NOT overwrite existing configs. Read first and merge.
- If `.pre-commit-config.yaml` doesn't exist, tell the user to run `/setup-common` first.
- If the project has multiple Dockerfiles, configure hadolint-action to scan all of them.
