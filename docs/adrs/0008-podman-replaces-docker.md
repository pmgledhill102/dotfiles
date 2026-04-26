# ADR-0008: Podman replaces Docker

- **Status**: Accepted (with caveats — monitor for compatibility gaps)
- **Date**: 2026-04-26
- **Tags**: containers, tooling

## Context

Container workflows on dev machines need a daemon and a CLI. Docker
Desktop is the obvious default but has two friction points:

1. **Licensing** — Docker Desktop requires a paid subscription for some
   employers and contexts.
2. **Weight** — Docker Desktop runs a full Linux VM with its own UI and
   updater, even for occasional ad-hoc container use.

Podman is a daemonless, rootless drop-in for the Docker CLI that solves
both. It is mature on Linux and good enough on macOS/Windows for the
container workflows this repo relies on (mostly `docker build`, ad-hoc
`docker run`, and the occasional small `docker compose` stack).

## Decision

Install Podman in place of Docker on every tier that runs a container
runtime.

- Brewfile installs `podman` (formula) on macOS personal and work tiers.
- apt list installs `podman` on Linux personal and work tiers.
- A zsh alias maps `docker → podman` when only Podman is on `PATH`, so
  scripts and muscle memory keep working.
- Docker Desktop is not installed by default on any tier.

The "with caveats" qualifier reflects current experience: most workflows
are working but compatibility gaps (BuildKit features, Compose v2
semantics, `/var/run/docker.sock` consumers) are watched and may
re-open the question.

## Consequences

### Positive

- Daemonless, rootless, no licensing concerns.
- CLI compatibility means scripts written against `docker` keep working
  via the alias.
- No always-on background VM/UI.

### Negative / trade-offs

- Some `docker compose` v2 plugin behaviour and BuildKit features lag
  Docker.
- Tooling that talks directly to the Docker socket (`/var/run/docker.sock`)
  needs the Podman socket workaround, or fails.
- The `podman machine` VM on macOS still has rough edges around volume
  mounts and networking compared to Docker Desktop.
- Status is "accepted with caveats" — if compatibility gaps grow, this
  ADR may be revisited.

## Alternatives considered

- **Docker Desktop** — easiest path, but licensing and weight are the
  reasons we left.
- **Colima** — adds a Lima/QEMU layer that's another moving part.
- **Rancher Desktop** — Kubernetes-centric; overkill for ad-hoc
  containers.
- **Lima alone** — too much manual VM management for daily use.
