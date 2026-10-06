# ADR-0018: Docker without Docker Desktop: Colima on macOS, Docker Engine on Linux

- **Status**: Accepted
- **Scope**: Repo — this record binds `dotfiles` only. It picks the container
  runtime this repo installs per platform and tier, which would bind nothing
  if this repo were archived.
- **Date**: 2026-10-06
- **Tags**: containers, tooling
- **Supersedes**: [ADR-0008](0008-podman-replaces-docker.md)
- **Implements**: [#453](https://github.com/pmgledhill102/dotfiles/issues/453)

## Context

[ADR-0008](0008-podman-replaces-docker.md) replaced Docker with Podman to
avoid Docker Desktop's weight and licensing. It was accepted "with caveats",
and the caveats it listed are what went wrong in practice:

- `docker compose` behaviour and BuildKit features lagging Docker
- tools that talk to `/var/run/docker.sock` directly (Testcontainers, Dev
  Containers, act) needing workarounds or failing
- the `podman machine` VM on macOS being rough around mounts and networking

The `docker → podman` alias hid the difference until something depended on
real Docker behaviour.

The goal behind ADR-0008 still holds: no Docker Desktop. That GUI app is the
thing being avoided, not Docker itself. The Docker CLI, Compose v2, buildx and
the Docker Engine are all open source and run without it.

## Decision

Use the real Docker CLI, Compose v2 and buildx on every tier that runs
containers, with the engine supplied natively per platform:

| Machine | Engine | Installed by |
| --- | --- | --- |
| macOS, personal + work | **Colima**: the Docker Engine in a headless Lima VM | Brewfile: `colima`, `docker`, `docker-compose`, `docker-buildx` |
| Ubuntu / WSL, personal + work | **Docker Engine**, native | Docker's apt repo: `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin` |
| minimal, any OS | none | — |

- **macOS wiring.**
  - `~/.docker/config.json` gets `cliPluginsExtraDirs` pointing at Homebrew's
    `lib/docker/cli-plugins`, via a chezmoi modify-template. Docker's own keys
    (`auths`, `currentContext`) are left alone.
  - Colima is **started on demand** (`colima start` / `colima stop`), not at
    login, so the VM costs nothing between uses
    ([#455](https://github.com/pmgledhill102/dotfiles/issues/455)).
  - `dot_zshrc` exports `DOCKER_HOST` at Colima's socket, for tools that ignore
    Docker contexts.
- **Linux wiring.** The user joins the `docker` group, to run `docker` without
  sudo. WSL already has systemd enabled by `run_once_configure-wsl`, which the
  Docker service needs.
- Podman, `podman-compose` and the `docker → podman` alias are removed.

**Colima rather than OrbStack.** OrbStack is faster and smoother on macOS, but
it needs a paid licence for commercial use, and the `work` tier runs on a work
laptop. Colima is MIT-licensed and command-line only. The same tool on both
Macs keeps one setup to maintain. This reverses ADR-0008's rejection of Colima
as "another moving part": a Lima VM is exactly what `podman machine` was too,
and Colima's runs the real Docker engine.

## Consequences

### Positive

- The same `docker` and `docker compose` commands behave the same way on every
  machine, and the same as in CI.
- Socket consumers work: the standard socket on Linux, `DOCKER_HOST` on macOS.
- No GUI app and no licence on any tier.

### Negative / trade-offs

- **macOS still runs a VM**, as every option there must. Colima's file sharing
  is slower than OrbStack's or Docker Desktop's, and it occasionally needs
  `colima stop && colima start` after sleep or an OS update. Its CPU and memory
  are set with `colima start --cpu N --memory N`, which persists.
- **Docker on Linux is root-equivalent** for members of the `docker` group.
  This is the usual trade-off; rootless Docker is available if it matters.
- **CI cannot start Colima.** GitHub's macOS runners have no nested
  virtualisation, so CI checks the Docker CLI and plugins, not a running
  engine.
- **One extra step on macOS:** `colima start` before using Docker. A `docker`
  command with Colima stopped fails with "Cannot connect to the Docker
  daemon", which is the cue.
- Existing machines keep their Podman install until it is removed by hand.

## Alternatives considered

- **Keep Podman (ADR-0008).** The caveats became daily friction.
- **OrbStack.** Best macOS experience, but commercial use needs a paid
  licence, which rules it out for the work tier.
- **Docker Desktop.** The thing this repo set out to avoid: a heavy GUI app,
  and a paid licence for many employers.
- **Rancher Desktop / Podman Desktop.** GUI apps, and either
  Kubernetes-centric or still Podman underneath.
- **Apple's `container` tool.** Not Docker-API compatible: no socket and no
  Compose, so it is not a drop-in replacement.
