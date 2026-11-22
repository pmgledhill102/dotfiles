---
name: sandbox-docker
description: 'Build or run Docker images inside a Claude Code cloud sandbox, where the daemon sits behind the egress proxy: the Dockerfile pattern that keeps the proxy CA out of image layers, the build flags that route a build through the proxy, and the Playwright browser-path fix. Use when asked to build or run an image, run docker compose, or run e2e tests in containers in a cloud sandbox. Not for linting or scanning Dockerfiles (setup-docker).'
---

# Docker in a cloud sandbox

Cloud sandboxes can run real Docker builds. Nothing about this is specific to
one repo, so it lives here and not in each repo's own scripts. Every fact below
was measured in a Claude Code cloud sandbox (a Firecracker microVM, running as
root with `CAP_SYS_ADMIN`, so there is no container-in-container to work
around). Re-check one before relying on it if it looks stale. For linting and
scanning Dockerfiles, use `setup-docker`; this skill is about building and
running.

## The daemon

`dockerd` is installed but not running. On a bootstrap with `--with-hooks`, the
`dockerd-start-claude-hook` `SessionStart` hook starts it for you, on every
session start and resume, and writes `/etc/docker/daemon.json` with a
`mirror.gcr.io` registry mirror when none exists. Check before you start
anything yourself:

```sh
docker info >/dev/null 2>&1 && echo up || echo down
```

If it is down, the bootstrap was probably run without `--with-hooks`, so the
hook is not installed; say so rather than improvising a daemon, and ask for the
bootstrap to be re-run with that flag. If you do start `dockerd` by hand, start
it from a shell that has `HTTPS_PROXY` set: the daemon inherits the proxy from
the shell that starts it, and without it image pulls and `ADD <url>` fail. `/var/lib/docker` (images and build cache) survives a worker
restart; the process does not.

## Pulls: use the mirror

Docker Hub answers **429** to the sandbox's shared egress IP on anonymous pulls.
That is a different failure from the layer-CDN host in `cloud/README.md` §2,
which only gets a pull past the redirect. The mirror fixes it:
`mirror.gcr.io/library/<image>` also pulls directly, if you would rather name
it in a `FROM`.

## Builds and runs have no egress of their own

A build or run container on the default bridge cannot resolve DNS. All traffic
has to go through the agent proxy on the VM's `127.0.0.1`, which needs:

- `--network host`, and
- the proxy variables as build args: `HTTPS_PROXY`, `https_proxy`, `NO_PROXY`
  and `no_proxy` (predefined build args, so no `ARG` line is needed).

The proxy re-terminates TLS, so a `RUN` step that downloads also needs the
proxy's CA bundle, at `/root/.ccr/ca-bundle.crt` (see `/root/.ccr/README.md`).
**Do not copy it into a layer.** Mount it for the one step that needs it:

```dockerfile
# Empty by default; `--build-context proxy-ca=DIR` overrides it.
FROM scratch AS proxy-ca

FROM alpine:3.19
RUN --mount=type=bind,from=proxy-ca,target=/proxy-ca \
    if [ -f /proxy-ca/ca-bundle.crt ]; then export SSL_CERT_FILE=/proxy-ca/ca-bundle.crt; fi; \
    apk add --no-cache ca-certificates
```

With no build context the `scratch` stage mounts as an empty directory and the
`if` is skipped, so the same Dockerfile builds unchanged in CI and Cloud Build.
Stage the bundle somewhere gitignored and listed in `.dockerignore`, and pass the flags only
when it exists:

```sh
mkdir -p .runtime/proxy-ca && cp /root/.ccr/ca-bundle.crt .runtime/proxy-ca/
docker build --network host \
  --build-context proxy-ca=.runtime/proxy-ca \
  --build-arg HTTPS_PROXY --build-arg https_proxy \
  --build-arg NO_PROXY --build-arg no_proxy \
  -t app-image .
```

Without those flags, a build in a sandbox fails at the first download with
`certificate verify failed`. That is the proxy, not the image.

Tools differ in how they find the CA. Alpine `apk`, GNU `wget` and Go honour
`SSL_CERT_FILE`. **Node ignores the system store**: export
`NODE_EXTRA_CA_CERTS=/proxy-ca/ca-bundle.crt` in the step instead, or npm dies
with `Exit handler never called!`.

**Prefer `ADD <url>` over `RUN wget` for tarballs.** The daemon fetches an `ADD`
itself, through the proxy with the system trust store, so it needs none of the
CA plumbing above.

### Prove the CA stayed out of the image

A grep that finds nothing proves nothing until it has been shown able to find
something. Compare certificate fingerprints, and keep the control:

```sh
fps() { # fingerprint every cert in the PEM bundle on stdin, sorted
  d=$(mktemp -d)
  awk -v d="$d" '/-----BEGIN CERT/{n++} {print > (d "/c" n ".pem")}'
  for f in "$d"/*.pem; do openssl x509 -in "$f" -noout -fingerprint -sha256; done | sort
  rm -rf "$d"
}
fps <.runtime/proxy-ca/ca-bundle.crt >/tmp/bundle.fp
docker run --rm app-image cat /etc/ssl/certs/ca-certificates.crt | fps >/tmp/image.fp
comm -23 /tmp/bundle.fp /tmp/image.fp   # the proxy's own CAs: expected to list them
comm -23 /tmp/bundle.fp /tmp/bundle.fp  # control: must print nothing
```

The first `comm` lists the certificates in the proxy bundle that the image does
not hold, and the proxy's own CAs must be among them. If it lists nothing, the
CA leaked into the image (or the image has no trust store to compare). Do not
grep for a single base64 line instead: the bundle also holds public roots, and a
line the image's own store shares reads as a leak that is not one.

## Hosts a build can reach

Allowed (see `cloud/README.md` §2): `mirror.gcr.io`, `dl-cdn.alpinelinux.org`
(Alpine packages), `dl.google.com`. **Blocked**: `go.dev` and `deb.debian.org`.
Fetch Go toolchains from `https://dl.google.com/go/<file>`, which serves the
same tarballs, and prefer Alpine bases. A blocked host shows up as a DNS or
connect error inside the build, not as a clear refusal; ask for the host if you
need it.

## Playwright

The sandbox's pre-installed Chromium (`/opt/pw-browsers/chromium-<build>`) is
not the build a pinned `@playwright/test` expects, so every spec fails in a few
milliseconds. Point the config at the installed browser:

```ts
use: { launchOptions: { executablePath: process.env.PW_CHROMIUM_PATH } }
```

and set `PW_CHROMIUM_PATH` to the installed executable. The directory layout
changes between builds (`chrome-linux/` once, `chrome-linux64/` now), so look it
up rather than copying a path:

```sh
find /opt/pw-browsers -maxdepth 4 -name chrome -type f
```

Do not run `playwright install`: another version will not find the
pre-installed browser.
