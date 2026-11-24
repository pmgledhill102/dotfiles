# Cloud sandbox environments

Everything a vendor's cloud sandbox needs to gain this repo's capabilities,
without the repo you are working on carrying any of it.

`bootstrap.sh` is the whole mechanism: an environment's setup script fetches it
by ref and runs it, and it installs the credential helper, a named set of
skills, and the composed agent policy into the container. See
[ADR-0016](../adrs/0016-capability-delivery-principles.md) for why the substance
lives here rather than in the setup script itself.

**This file is the operator manual — what to set, what each flag does, how to
recover.** For what the layers are, what runs when, what it all costs and how
the surfaces differ, see
[`docs/cloud-sandbox-design.md`](../docs/cloud-sandbox-design.md).

Which skills is an explicit whitelist — the `SKILLS` and `COMPOSED_SKILLS`
variables in the script — rather than everything under `home/skills/`. Raw
GitHub offers no directory listing, so a wildcard would need the API, a token
and a JSON parser; and the list being hand-maintained means adding a skill to
every sandbox is a decision someone makes rather than a side effect of creating
a file.

## Claude Code

Set these three things once per environment, at
[claude.ai/code](https://claude.ai/code) → the environment's settings.

### 1. Setup script

```sh
PROFILE=claude-cloud-sandbox
REF=main
# Rev: 1

curl -sSL --retry 3 --retry-delay 2 \
  "https://raw.githubusercontent.com/pmgledhill102/dotfiles/$REF/agent/cloud/bootstrap.sh" \
  -o /tmp/bootstrap.sh || echo "[setup] could not fetch bootstrap.sh"

{ sh /tmp/bootstrap.sh "$REF" --profile "$PROFILE"; echo $? > /tmp/bootstrap.rc; } 2>&1 \
  | tee /tmp/bootstrap.log

echo "[setup] bootstrap exit=$(cat /tmp/bootstrap.rc 2>/dev/null) at $(date -u +%FT%TZ)"
exit 0
```

**The first three lines are the whole per-environment configuration.** Below
them the script is byte-identical on every Claude environment, which is the
point: a pinned environment differs from a tracking one by one word, in a
place obvious enough that nobody has to read the rest to find it. Codex is
the exception for now; see its section.

`REF` is a variable rather than typed twice because it appears in two places —
the ref this script is fetched from, and the ref it installs everything else
from. Those straddling different versions is precisely the failure the pin
exists to prevent, and two literals are two chances to update only one.

**`REF` is a ref of the published repository, `pmgledhill102/dotfiles`, not of
this one.** This repo is the private source; a publish job copies `home/`,
`profiles/`, `cloud/` and `adrs/` into the public repository under `agent/`, in
commits of its own
([ADR-0028](../adrs/0028-private-sources-one-public-output.md)). The bootstrap
resolves `REF` against the public repository and fetches every file from that
commit. So a pin is a **public** sha, read from
`git ls-remote https://github.com/pmgledhill102/dotfiles main` or from the
`sha=` line of a container's manifest. A commit sha from this repo's history
does not exist there: the bootstrap refuses it by name before installing
anything.

### Fetching from somewhere else: `BOOTSTRAP_SOURCE_REPO`, `BOOTSTRAP_SOURCE_PREFIX`

Two environment variables say where the bootstrap fetches from. Both have
defaults, and a normal environment sets neither.

| Variable | Default | Meaning |
| --- | --- | --- |
| `BOOTSTRAP_SOURCE_REPO` | `pmgledhill102/dotfiles` | `<owner>/<name>` on github.com. `REF` is resolved against it, and every file is fetched from it |
| `BOOTSTRAP_SOURCE_PREFIX` | `agent` | The directory in it that holds `home/`, `profiles/` and `cloud/`. No leading or trailing slash. Set but empty means the repository root |

`--source-repo=<owner>/<name>` and `--source-prefix=<dir>` are the same two
settings as flags, and win over the variables. The bootstrap writes them into
the deferred toolchain run's arguments itself, because that run starts from a
session, which does not have the setup script's environment.

With the source moved, `REF` is a ref of **that** repository, and a pin is
one of its shas, read from
`git ls-remote https://github.com/<owner>/<name> main`.

The manifest records both settings, as `source=` and `source_prefix=`, and
`start-session`'s currency check resolves the ref against `source=`. A
container built from a rehearsal repository is therefore compared with that
repository, not reported as behind the real one.

**The source's own copy of `bootstrap.sh` has to support these settings**, and
a run with a non-default source checks that before it installs anything. The
reason is that the run does not always finish in the copy that started it: a
copy that is stale for `REF` hands over to the one the source holds at that
commit, and the deferred toolchain run saves and later runs that same copy. A
copy from before the settings existed reads neither the variables nor the
flags, so it would fetch everything from its own default, write that
repository's sha into the manifest and exit 0 with `status=ok`. So the run
fetches `cloud/bootstrap.sh` from the source at the resolved commit, and stops
with a non-zero exit and `does not support --source-repo / --source-prefix` in
the log and the manifest's `failed_step` if that copy lacks them. The remedy
is to publish a current `bootstrap.sh` to the source, then re-run.

**To rehearse against another repository**, export the variables in the setup
script and fetch the script from the same place. The bootstrap reads the
variables; the first `curl` does not, so its URL has to change too:

```sh
PROFILE=claude-cloud-sandbox
REF=main
# Rev: 1
export BOOTSTRAP_SOURCE_REPO=<owner>/<rehearsal-repo>
export BOOTSTRAP_SOURCE_PREFIX=agent

curl -sSL --retry 3 --retry-delay 2 \
  "https://raw.githubusercontent.com/$BOOTSTRAP_SOURCE_REPO/$REF/$BOOTSTRAP_SOURCE_PREFIX/cloud/bootstrap.sh" \
  -o /tmp/bootstrap.sh || echo "[setup] could not fetch bootstrap.sh"

{ sh /tmp/bootstrap.sh "$REF" --profile "$PROFILE"; echo $? > /tmp/bootstrap.rc; } 2>&1 \
  | tee /tmp/bootstrap.log

echo "[setup] bootstrap exit=$(cat /tmp/bootstrap.rc 2>/dev/null) at $(date -u +%FT%TZ)"
exit 0
```

Afterwards `~/.agents/.bootstrap-manifest` should say `status=ok` and
`source=<owner>/<rehearsal-repo>`, with a `sha=` that
`git ls-remote https://github.com/<owner>/<rehearsal-repo> main` agrees with.

This repo's own CI uses the same two variables to point
`tests/bootstrap-failure-test.sh` back at this repo's layout
(`BOOTSTRAP_SOURCE_PREFIX` empty), because the published copy can never hold
the branch under test.

**Do not put a shebang in this field.** The harness writes the field's contents
into a generated `/tmp/init-script-*.sh` beneath a header of its own and runs
that, so a `#!/bin/bash` you paste is never line 1 and never takes effect. Intact
it is a comment; lose the `#` in transit and it becomes a command, which is how a
live environment produced this:

```text
Setup script failed with exit code 127.
/tmp/init-script-2496021182.sh: line 3: !/bin/bash: No such file or directory
```

Line 3 is the field's line 1. Nothing had run yet — not `curl`, not the
bootstrap — and the session was already over. Omitting the line removes the whole
class of failure, and costs nothing, because the harness supplies the interpreter.

For the same reason, keep the field POSIX. Which shell the harness uses is its
choice, not yours, so a bashism only works by luck — the form above avoids
`PIPESTATUS` by parking the exit status in a file, which is why the bootstrap
runs inside `{ … }` rather than being piped directly into `tee`.

Downloading the bootstrap to a file rather than piping it into `sh` is also
deliberate: it separates "could not fetch" from "ran and failed", and it keeps
the run's own exit status reachable.

### What a profile includes

The profile selects the capabilities as well as the context, so most
environments need no capability flags at all:

| Profile | gcloud | pre-commit | hooks | gh | devknowledge |
| --- | --- | --- | --- | --- | --- |
| `claude-cloud-sandbox` | yes | yes | yes | no | yes |
| `codex-cloud-sandbox` | yes | yes | no | no | no (Claude only) |
| `*-workstation` | no | no | no | no | no |

These are read off the profile name rather than held in a table the script
would have to grow a row in per profile. A `claude-*` profile gets the harness
hooks because `~/.claude/settings.json` is a Claude mechanism and Codex does not
read it — ADR-0016 principle 3, provider-specific coupling on provider-specific
surfaces, applied to the installer. Anything `*-cloud-sandbox` gets pre-commit
and gcloud, because a sandbox is disposable and rebuilt from a script: the
argument for making a developer opt into enforcement is about protecting
somebody's laptop, and there is no laptop here. #254 is what its absence cost.

`gh` is off everywhere. It is documented below as counterproductive on
Anthropic-hosted sandboxes, so it waits for a caller who knows their egress.
`devknowledge` is **on for `claude-cloud-sandbox`**. That makes the
Developer Knowledge API credential ([step 4](#4-api-credentials)) part of what
this profile expects. An environment on this profile **without** it gets three
tools that 401 on every call, so either add the credential or pass
`--no-devknowledge`. Nothing in the bootstrap can check this for you, because
setup-script requests never get a credential attached, so a probe at setup
time would fail even where the credential exists.

### Overriding a profile

Every capability takes `--with-X` to force it on and `--no-X` to force it off.
Either beats the profile wherever it sits on the line, so ordering against
`--profile` does not matter:

```sh
sh /tmp/bootstrap.sh "$REF" --profile "$PROFILE" --no-gcloud
```

`--no-gcloud` is the one worth knowing: it saves a ~96 MB download in an
environment that does no Google Cloud work. `--no-precommit` is the escape for
an environment that cannot reach GitHub's release downloads or the package
indexes, since the pre-commit tooling needs them.

The run reports what it resolved, because with defaults in play the command
line no longer says what happened:

```text
[bootstrap] profile -> claude-cloud-sandbox
[bootstrap] caps    :  gcloud=yes precommit=yes hooks=yes gh=no terraform=yes devknowledge=yes
```

The same set is written to `~/.agents/.bootstrap-manifest`, which is where to
look when a container is behaving as though something is missing.

`--with-terraform` installs `terraform`, `tflint` and `checkov`, and seeds
the tflint google ruleset that `tflint --init` cannot fetch here, so a repo
whose `.pre-commit-config.yaml` calls the Terraform hooks can actually run
them. **On by default for a sandbox**, like `--with-precommit` and for the
same reason: a disposable container rebuilt from a script has no developer
setup to protect, so a gate that is present beats a download that is avoided.
`--no-terraform` is the refund for an environment that does no Terraform work.
It installs inside `--with-precommit`, since serving that config is the whole
reason the binaries are here: `--with-terraform --no-precommit` installs
nothing.

**The tflint ruleset seed.** `tflint --init` resolves a plugin through the
GitHub releases API, which the proxy refuses with a 403, but the release
asset itself downloads. tflint looks a plugin up under the exact version
`.tflint.hcl` pins, so a seed of any other version does not count. The
bootstrap therefore reads every `.tflint.hcl` in the checkouts it can see,
the same places the hook warm looks. From each `plugin` block whose `source`
is `github.com/terraform-linters/tflint-ruleset-google`, it takes the
`version` and seeds that version. It also seeds the estate pin
(`TFL_GOOGLE_VER`) for a repo that pins nothing. Each one is checked against
its release's `checksums.txt` before it is installed, and a version already in
place is skipped. A repo pin that cannot be fetched or verified logs a `WARN`
and the run goes on: it costs that repo's `terraform_tflint` hook, nothing
else. A failure of the estate pin degrades `precommit.tflint-ruleset-google`.

A repo attached with `add_repo` after the setup script ran was never seen, so
its pin is not seeded. The hook then fails with `Failed to fetch GitHub
releases: ... 403`. Attaching the repo does not help, because it grants git
reads, not the releases API. Seed the pin by hand instead, with the version
from that repo's `.tflint.hcl`:

```sh
v=0.39.0
d="$HOME/.tflint.d/plugins/github.com/terraform-linters/tflint-ruleset-google/$v"
u="https://github.com/terraform-linters/tflint-ruleset-google/releases/download/v$v"
t=$(mktemp -d) && cd "$t" \
  && curl -sSfLO "$u/tflint-ruleset-google_linux_amd64.zip" \
  && curl -sSfLO "$u/checksums.txt" \
  && grep ' tflint-ruleset-google_linux_amd64.zip$' checksums.txt | sha256sum -c - \
  && mkdir -p "$d" && unzip -o -q tflint-ruleset-google_linux_amd64.zip -d "$d" \
  && chmod 0755 "$d/tflint-ruleset-google"
```

Then `tflint --init` finds the plugin in place and makes no API call. This is
a manual step rather than a helper the commit hook runs, because the seed
belongs to the bootstrap: its download URLs, the fixtures that test them and
its failure accounting all live there. A second copy in a hook would have to
be kept in step with all three, to save one paste in a case that comes up only
when a repo is attached mid-session.

`--toolchain=background` defers the pre-commit toolchain (pre-commit, its
linters, the Terraform tools, golangci-lint and the hook-environment warm) from
the setup phase to the session (ADR-0021, 2026-11-10 amendment; #631). Most
sessions are rebuilds, so the setup phase is watched by the user waiting for the
first prompt, while the toolchain is first needed minutes later. The setup run
installs the toolkit and the global git hook, then leaves its own sha-addressed
copy, its flags and a launcher under `~/.agents/toolchain/`. The
`toolchain-start --hook` SessionStart entry re-runs it there as
`--toolchain=run`, in the background. That run reports to
`~/.agents/toolchain/manifest` and `state`, and spools a `toolchain` telemetry
record rather than a second `bootstrap` one. A commit that arrives first waits
for the install, up to 75 s. If it is still running after that, the commit is
stopped with a message, never passed unchecked. A shimmed tool waits the same
way and records the time in `blocked_ms`. It is the default for `claude-cloud-sandbox`; every other profile stays `eager`, and `--toolchain=eager` is the refund.

This buys **coverage**, not the ability to push. A container without these
tools pushes fine: `precommit-claude-hook` classifies a hook that fails purely
because its binary is missing as *not checked* and lets the command through,
naming what went unchecked (#335). Before that fix, every push in such a
container needed `--no-verify` — five out of five in one session, which is how
a guard stops being a guard.

`--with-gh` installs the GitHub CLI from a pinned release — but **do not add
it to Anthropic-hosted environments**. Measured 2026-08-19: the egress proxy
authenticates `gh` for identity endpoints (`user`, `rate_limit`) yet 403s
every repo-scoped API path, and GraphQL serves only a pinned PR-review set —
so the session skills' gather sections come back `gh-unauthorized` rather
than populated (lane map on #257, cleanup on #273). The flag exists for
surfaces whose egress genuinely reaches the GitHub API, e.g. self-hosted
environments. On Anthropic-hosted sandboxes the GitHub MCP server remains the
only repo-data route, and the sandbox bodies of the session skills call it
directly rather than treating it as a fallback (#265).

`--with-devknowledge` registers Google's Developer Knowledge MCP server as
`google-developer-knowledge`, at **user scope** in `~/.claude.json`, with no
auth header. It depends on the Developer Knowledge API credential
([step 4](#4-api-credentials)): the agent proxy attaches the key outside the
VM, so the key never enters the container. **On by default for
`claude-cloud-sandbox`**, so every Claude environment on that profile should
carry the credential. Without it, the server's tools appear but return 401 on
every call, the worst failure shape. Pass `--no-devknowledge` from any such
environment that can't hold the credential, e.g. on a plan without API
credentials (#439).

- **Why the environment, not the repo:** this couples the server to the
  environment that can authenticate it, rather than requiring a `.mcp.json`
  in every repo.
- **A repo can still override it.** Claude Code loads a server named in
  several scopes once, from the highest-precedence source: local, then
  project (`.mcp.json`), then user. So a repo that declares the same name
  wins, and one that declares nothing inherits this entry.
- **It touches one key only.** The bootstrap edits
  `mcpServers."google-developer-knowledge"` with `jq`, the same way
  `--with-hooks` merges `settings.json`. Every other key in `~/.claude.json`,
  including account state and other servers, is carried through, and the
  file stays `0600`.
- **A `~/.claude.json` that isn't a JSON object is left alone.** The
  capability degrades instead of replacing it.

```sh
# claude-cloud-sandbox gets it with no flag; opting out:
sh /tmp/bootstrap.sh "$REF" --profile "$PROFILE" --no-devknowledge
```

The tool names match the allowlist `home/settings.json` already carries
(`mcp__google-developer-knowledge__*`). Verified end to end in
a private scratch repository with the same keyless entry declared at
project scope. At user scope, delivered by the bootstrap, it is **unverified
until a fresh session on this profile confirms the entry survives session
start**.

**The `Rev:` comment is load-bearing.** The environment snapshots the setup
script's result and re-runs it only when the script text changes, the allowed
domains change, or roughly seven days pass. Because `main` never changes *as a
string*, pushing to `main` does not reach new sessions — they keep restoring the
snapshot built the first time. Bump the number to force a rebuild.

Pin a tag instead of `main` for anything beyond development:

```sh
REF=v0.1.0
```

One word, one place — which is why `REF` is a variable rather than the two
literals it replaced.

A mutable ref means any compromise of this repo reaches every sandbox that
starts afterwards. A tag also names, in the session's own log, which version it
is running.

The trailing `exit 0` belongs to the caller, not the script: a non-zero exit
fails the whole session, while `bootstrap.sh` deliberately fails loudly so that
a partial install is visible rather than silent. Swallowing the status is a
choice the environment makes, which is why the snippet still records the real
one in its `[setup] bootstrap exit=` line and keeps `/tmp/bootstrap.log` — a
session that came up half-installed can be diagnosed from inside itself.

### Where the binaries go: `--prefix`

The bootstrap decides once where every command it installs goes, and the
helper and every toolchain follow that decision:

| Run | Commands | gcloud SDK |
| --- | --- | --- |
| `--prefix DIR` | `DIR/bin` | `DIR/opt/google-cloud-sdk` |
| `/usr/local/bin` and `/opt` writable (a root sandbox) | `/usr/local/bin` | `/opt/google-cloud-sdk` |
| otherwise (unprivileged) | `~/.local/bin` | `~/.local/opt/google-cloud-sdk` |

A root run with no `--prefix` lands exactly where it always did, so a Claude
environment needs no change. Off the root layout, each install route is
steered into the prefix rather than skipped: release binaries are installed
into its `bin`, `shellcheck` comes from its pinned release because `apt`
needs root, `npm` gets `--prefix`, and the Python tools (`pre-commit`,
`checkov`, `semgrep`) go through `uv tool install` with uv's tool, bin and
Python directories under the prefix. Without uv, the `~/.local` default falls
back to `pip --user`; any other prefix needs uv. The root layout prefers uv
too, for `pre-commit` and `checkov` with their shims in `/usr/local/bin`, and
uses the system `pip` only when uv is absent or fails.

```sh
sh /tmp/bootstrap.sh "$REF" --profile "$PROFILE" --prefix /workspace/.tools
```

`--prefix` moves **commands only**. The policy, the skills and the
`~/.claude/bin` session scripts stay under `$HOME`, because the harness and
the skills find them by that path. The pre-commit cache, the git hook and the
tflint ruleset stay there for the same reason.

**The bootstrap cannot put the bin dir on `PATH` for you.** A setup script's
exports do not reach the agent phase on every surface, so the run logs a
`WARN … is NOT on PATH` line, both early and at the end, and the manifest
records `bin_dir=` and `bin_dir_on_path=`. `start-session` reports
`bin_dir_off_path=` when the session it runs in still cannot reach them. The
fix is in the environment's settings, not in a re-run.

### 2. Allowed domains

Select **Custom**, tick *also include default list*, and add:

```text
credential-broker-<hash>-nw.a.run.app
dl.google.com
registry.terraform.io
developer.hashicorp.com
semgrep.dev
production.cloudfront.docker.com
mirror.gcr.io
dl-cdn.alpinelinux.org
docs.github.com
docs.cloud.google.com
support.google.com
knowledge.workspace.google.com
developers.google.com
*.googleblog.com
```

Obtain the broker hostname with `gcloud run services describe credential-broker`
against the project it is deployed to — named, with the region, in the
`sandbox-gcp-credentials` runbook in the private infrastructure repository. It
is deliberately
not written here: this repo is public, and while the URL is not a credential,
publishing it hands a stranger the rate limit. The other thirteen are ordinary
public hosts and carry no such exposure.

The first two are what the bootstrap and the broker flow need; the rest are
what agent work in the sandbox needs. None is on the Trusted default list, and
each fails in a way that reads as something else:

| Missing | Symptom | Actually |
| ------- | ------- | -------- |
| broker host | `could not resolve host` | the environment was never allowed to call it |
| `dl.google.com` | gcloud install fails | `cloud.google.com` and `gcloud.google.com` are on the default list and neither serves the tarball |
| `registry.terraform.io` | `terraform init` fails, so `validate` and `plan` cannot run | providers come from the registry; without it every Terraform check silently defers to CI |
| `developer.hashicorp.com` | Terraform and provider documentation will not load | HashiCorp's docs live here now; `terraform.io` documentation links redirect to it |
| `semgrep.dev` | `semgrep --config auto` fails before scanning anything | the rulesets are fetched from the registry at scan time, so it reads as a broken install, not a network block |
| `production.cloudfront.docker.com` | `docker pull` resolves the image and then fails on its layers | Docker Hub redirects layer downloads to a CDN host; the registry host answering proves nothing about it |
| `mirror.gcr.io` | `docker pull` of a Docker Hub base image fails with `429 Too Many Requests` | Docker Hub rate-limits anonymous pulls from the sandbox's shared egress IP; the CDN host above only gets a pull past the redirect. `dockerd-start-claude-hook` points the daemon at this mirror (#683) |
| `dl-cdn.alpinelinux.org` | `apk add` inside a build fails with a DNS or fetch error | Alpine packages come from this CDN; any Alpine-based image build needs it |
| `docs.github.com` | GitHub documentation will not load | a separate host from `github.com` and the API |
| `docs.cloud.google.com` | GCP documentation returns `EGRESS_BLOCKED` | `cloud.google.com` docs pages redirect here, so the default-list entry no longer reaches the content |
| `support.google.com` | Google help-centre articles will not load | a separate host from the documentation sites |
| `knowledge.workspace.google.com` | Workspace knowledge articles will not load | a separate host from `support.google.com`, though the two cross-link |
| `developers.google.com` | Google API and library reference will not load | a separate host from `docs.cloud.google.com` |
| `*.googleblog.com` | release and deprecation announcements will not load | each Google blog is its own subdomain, hence the wildcard |

`raw.githubusercontent.com` is already on the default list, so fetching the
bootstrap itself needs nothing added.

**This list is a snapshot of a platform setting, not of anything committed**,
and the setting changes without a commit. Re-run this before trusting it:

```sh
# verified 2026-10-31 in a Claude sandbox; re-run before trusting this list
for d in dl.google.com registry.terraform.io developer.hashicorp.com \
  semgrep.dev production.cloudfront.docker.com mirror.gcr.io \
  dl-cdn.alpinelinux.org docs.github.com \
  docs.cloud.google.com support.google.com knowledge.workspace.google.com \
  developers.google.com developers.googleblog.com \
  tunnel.cloudproxy.app endoflife.date agents.md; do
  printf '%-34s %s\n' "$d" "$(curl -s -o /dev/null -w '%{http_code}' -m 12 -I "https://$d/")"
done
```

How to read it:

- **Any HTTP status means allowed; `000` means blocked.** An egress denial
  returns no HTTP status at all. The last three hosts are the negative
  control — not allowed, and expected to print `000`. If they print anything
  else, the check has stopped being able to tell the difference and an
  all-statuses result means nothing.
- **Two allowed hosts answer a bare root request with an error, and that is
  the origin, not the proxy.** `production.cloudfront.docker.com` returns
  `403` and `mirror.gcr.io` returns `405` to `HEAD`; `support.google.com` returns `404` to `HEAD` (and `200` to `GET`).
  Read either as "blocked" and the list looks wrong when it is not.
- **The broker host is not in the loop**, because it is not written here.
  Probe it with `"$CREDENTIAL_BROKER_URL/"` instead; any status (its root is a
  `404`) means it is reachable. `developers.googleblog.com` stands in for the
  wildcard.

**Two hosts a Docker build might want are not allowed**, and are not on the list
above: `go.dev` (`000`) and `deb.debian.org` (`000`). Fetch Go toolchain
tarballs from `https://dl.google.com/go/`, which serves the same files and is
already allowed. Nothing measured needed `deb.debian.org`; use an Alpine base
image, or ask for the host before building on Debian.

On 2026-10-04 every listed host returned a status (`200`, `301`, `302`, or the
two origin errors above) and all three negative controls returned `000`.

### 3. Environment variables

| Variable | Value |
| -------- | ----- |
| `CREDENTIAL_BROKER_URL` | the broker hostname above, with scheme |
| `CREDENTIAL_BROKER_REQUEST_KEY` | `proxy-injected`, with the key held as an API credential (below). Or, where that isn't available, this environment's own key itself |

Each cloud environment has its **own** request key, named after it
(`claude-cloud-sandbox-access` here); the shared `cloud` key is retired. The
approval card names which key was used, so a per-environment key tells you
which environment asked, and "a cloud key while I am at my laptop" stays
information worth having. Creating and distributing keys is in the
`sandbox-gcp-credentials` runbook in the private infrastructure repository.

**Preferred: hold the key as an API credential.** Environment variables are
readable by anything running in the session. On Pro and Max, add the key in
[step 4](#4-api-credentials) instead, and set the variable to the literal
`proxy-injected`:

| Field | Value |
| --- | --- |
| Name | `Credential broker` |
| Allowed websites | the broker's host, **exactly** (the same `credential-broker-<hash>-nw.a.run.app` as step 2). Not `*.run.app`: two credentials whose hosts overlap without matching exactly get no marker, and only one is sent |
| Custom header name | `X-Request-Key` |
| Prefix | **empty** |
| Value | this environment's key |

The helper then sends no key of its own, and `gcp-credentials status` reports
`key : proxy-supplied`. The key can no longer be *copied out* of a sandbox by
`env`, a log or a prompt-injected `cat`. A process inside can still *use* it,
by calling the broker through the proxy, so this protects against
exfiltration, not against use.

- **Needs a broker that reads the header on `POST /request`.** That's
  a broker change in the private infrastructure repository. An older broker reads the key only
  from the request body, so `request` returns 401 in this mode.
- **Only for Claude cloud environments on Pro and Max.** Team and Enterprise
  keep the key in the variable. Codex has its own equivalent, a network
  secret: see the Codex section.

Where the variable does hold the key itself, that's a deliberate exception to
"no credentials in environment variables". It only gates *opening* a request,
the human approval is the real control, and rotation is documented. Treat it
as a knowing decision rather than a default.

### 4. API credentials

Pro and Max environments have an **API credentials** section (edit the
environment, below Environment variables). The agent proxy attaches a stored
credential to requests for the listed hosts after they leave the VM. Per the
[docs](https://code.claude.com/docs/en/cloud-environments#add-api-credentials),
"the key never reaches Claude, the commands it runs, or the session's
environment variables."

For `--with-devknowledge`, add one:

| Field | Value |
| --- | --- |
| Name | `Google Developer Knowledge` |
| Credential type | Bearer (the default) |
| Allowed websites | `developerknowledge.googleapis.com`, **exactly**. `*.googleapis.com` would send the key with every Google API call, gcloud's included |
| Custom header name | `X-Goog-Api-Key` |
| Prefix | **empty** (clear the default `Bearer`) |
| Value | the key: the private infrastructure repository's output `developer_knowledge_api_key`, restricted to the Developer Knowledge API |

Check **See resolved curl example** before saving. It should show one
`X-Goog-Api-Key:` header with no `Bearer` in front of the key. A credential has
no edit: to rotate the key, delete it and add it again.

Two things observed on 2026-09-30:

- **A new credential applies to sessions already running.** No restart is
  needed.
- **A plain `curl` gets the key.** With the credential in place, `curl` to
  `https://developerknowledge.googleapis.com/v1/documents:searchDocumentChunks?query=…`
  returns 200 with no key in the command. That is also the fallback when the
  MCP tools are absent.

### 5. Telemetry (optional)

Agent sessions can ship metadata about themselves to the telemetry ingest
(ADR 026 in the private infrastructure repository, #631): bootstrap manifest and timings, the
cache-hit marker, skill step records, an end-of-session record, the transcript
as it grows, and Claude Code's own OpenTelemetry metrics and logs. **Until you
set the pieces below nothing leaves the container**: `agent-telemetry` spools to
`~/.agents/telemetry/` and `ship` does nothing, silently. `agent-telemetry
status` says which state a session is in, and prints no secret.

**What is a secret and what is not.** The ingest key is. The URL is not.

| Where | Name | Value |
| --- | --- | --- |
| Environment variables | `TELEMETRY_INGEST_URL` | the ingest's base URL, with scheme |
| Environment variables | `TELEMETRY_INGEST_KEY` | the literal `proxy-injected` |
| API credentials (step 4) | `Telemetry ingest` | below |

The credential, for the `claude-cloud` key (issued with
the private infrastructure repository's `tools/telemetry-key create claude-cloud …`,
which prints it once):

| Field | Value |
| --- | --- |
| Name | `Telemetry ingest` |
| Credential type | Bearer (the default) |
| Allowed websites | the ingest's host, **exactly** |
| Custom header name | `Authorization` |
| Prefix | `Bearer` (the default) |
| Value | the `claude-cloud` key |

The helper then sends no key of its own. The ingest also accepts the bare key in
`X-Telemetry-Key`, for a credential form that cannot set `Authorization`; that
fallback exists, and nothing here needs it.

**What the session records about itself**, beyond the bootstrap manifest and
the step records skills emit. All of it is spooled by `agent-telemetry` and
none of it needs an exporter variable:

| Record | Field | Value |
| --- | --- | --- |
| `session-marker`, and the `session shape` event | `entrypoint` | which client started the session, from `CLAUDE_CODE_ENTRYPOINT` |
| `skill invoke` event | `skill` | the skill's name |
| `skill invoke` event | `via` | `tool` when the model called the Skill tool, `slash` when someone typed `/name` |

`entrypoint` is one of `cli`, `sdk-cli`, `sdk-ts`, `sdk-py`, `claude-vscode`,
`claude-desktop`, `claude-desktop-3p`, `claude-in-slack`, `local-agent`,
`remote`, `remote_desktop` and `remote_mobile`; `unknown` when the variable is
unset; and `other` for anything else, so the variable's text is never recorded.
A session started from the mobile app reads `remote_mobile`. **It is where the
session started, not where each prompt came from:** one opened on a phone and
continued on a desktop reads as mobile throughout. It is written by the
`SessionStart` hook that writes the session marker, so it exists only where the
bootstrap ran.

`skill invoke` comes from a hook on the Skill tool and on typed commands
(`home/settings.json.md` has the detail). It carries the name and nothing else:
never the skill's arguments or the prompt, and a name that is not a plain token
is recorded as `invalid`. This is the reason `OTEL_LOG_TOOL_DETAILS` can stay
unset below: the exporter's own `skill_activated` event reports every
user-defined skill as `custom_skill` without it.

**Which requests get the key.** The proxy attaches it to commands the session
runs, which is everything `agent-telemetry` does from the `SessionStart` and
`Stop` hooks and from end-session. It does **not** reach:

- **Setup-script requests.** Claude Code connects to the proxy after the setup
  script has run. This is the answer to the injection probe in #260: a `ship`
  from the bootstrap would be unauthenticated. The bootstrap therefore only
  spools its manifest (`agent-telemetry record bootstrap …`), and the
  `SessionStart` hook ships it once the session is up.
- **Claude Code's own OpenTelemetry export.** The documentation says so
  directly: "Claude Code's own telemetry export is one of the requests that
  never get the secret", because the exporter sends its own requests rather than
  going through the agent proxy
  ([cloud environments](https://code.claude.com/docs/en/cloud-environments#requests-that-never-get-the-credential),
  [monitoring](https://code.claude.com/docs/en/monitoring-usage#telemetry-from-cloud-sessions-and-claude-tag)).
  **So the exporter cannot authenticate to the ingest through this credential.**

  **Decision (owner):** the exporter carries its own key in
  `OTEL_EXPORTER_OTLP_HEADERS`. The documentation advises against a collector
  credential there, because anyone who uses the environment can read its
  variables; the credential-safe route, server-managed settings, needs a Team or
  Enterprise plan. The exposure is accepted on these terms: the key is
  write-only, so the worst a reader can do is write junk under its own prefix,
  and a **separate** key, `claude-cloud-otlp`, with a small daily quota, keeps
  that off the proxy-held `claude-cloud` key. Create it with
  `tools/telemetry-key create claude-cloud-otlp --quota-bytes N --quota-requests N`
  and rotate by creating a new one, updating the variable and disabling the old.

**Exporter configuration** (checked against the
[monitoring docs](https://code.claude.com/docs/en/monitoring-usage) on
2026-10-19; all but the last row hold no secret):

| Variable | Value | Why |
| --- | --- | --- |
| `CLAUDE_CODE_ENABLE_TELEMETRY` | `1` | required; telemetry is off without it |
| `OTEL_METRICS_EXPORTER` | `otlp` | |
| `OTEL_LOGS_EXPORTER` | `otlp` | logs carry the events |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `http/protobuf` | has no default, so it must be set |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | the ingest's base URL | the exporter appends `/v1/metrics` and `/v1/logs` itself |
| `OTEL_EXPORTER_OTLP_HEADERS` | `Authorization=Bearer <claude-cloud-otlp key>` | **a secret, readable by anyone who uses the environment**; see the decision above |
| `OTEL_METRIC_EXPORT_INTERVAL` | `30000` | default is 60000 ms |
| `OTEL_LOGS_EXPORT_INTERVAL` | `5000` | already the default; a short interval is the point, because what is lost when a container is reclaimed is the batch still pending |

Trade-off on the intervals: shorter loses less at reclamation and sends more
requests, and the ingest caps requests per day (ADR 026), so do not go below the
defaults without reading its cost model.

**Leave every content opt-in unset:** `OTEL_LOG_USER_PROMPTS`,
`OTEL_LOG_ASSISTANT_RESPONSES`, `OTEL_LOG_TOOL_DETAILS`, `OTEL_LOG_TOOL_CONTENT`,
`OTEL_LOG_RAW_API_BODIES`, `OTEL_LOG_MANAGED_SETTINGS`. They put prompts, tool
input or whole API bodies into telemetry. Traces
(`OTEL_TRACES_EXPORTER`, `CLAUDE_CODE_ENHANCED_TELEMETRY_BETA`) are beta and
are not configured here. `otelHeadersHelper` is not used: the key is static.

Exporter writes carry no `X-Session-Id` (the exporter's headers are fixed at
launch, before a session id exists), so they land under `_nosession/` in the
bucket; each payload carries `session.id` inside it and the offline reader joins
on that.

**Allowed domains.** The exporter uses the session's own network, so if you turn
it on the ingest's host must be in step 2's list. Commands the session runs
reach the credential's host through the proxy regardless; that is a different
path.

**Check it worked**, from a session, once the environment is configured:

```sh
agent-telemetry event setup verify
agent-telemetry ship
agent-telemetry status
```

`status` should show the endpoint configured, the credential as `proxy`, and a
last ship ending `204`. A `401` is a missing or wrong key or a source address the
key does not allow; `429` and `503` are the ingest's quota and its closed state
(see ADR 026). This writes one small record to the bucket.

**After changing any of this**, bump the setup script's `Rev:` line, for the same
reason as everything else in step 1.

Owner steps, in order: create the keys; add the credential; add the host to the
allowed domains; set the two variables and the exporter ones (including
`OTEL_EXPORTER_OTLP_HEADERS` with the separate `claude-cloud-otlp` key); bump
`Rev:`.

## Codex

**Status: blocked.** Codex Cloud can use the credential broker, but it can't
yet be given a usable environment, because its provisioning script doesn't
take effect. Tracked in #575. This section records what testing on
2026-10-10 established, not what the documentation implies. Some of it
reverses the 2026-08-13 findings it replaces.

### What works

- **The broker, end to end.** `gcp-credentials request` from a Codex task
  produced a phrase. After approval it provisioned the sandbox project,
  installed a token and started refresh, and gcloud picked the token up.
- **Holding the key without exposing it.** In the personal vault, add a
  **Network secret** with key `CREDENTIAL_BROKER_REQUEST_KEY`, the
  environment's own key as the value (`codex-cloud`), and scope it to that
  environment. The task sees a placeholder: the variable's length is 83
  characters, against the key's 44. Codex's proxy swaps in the real key on
  requests to allowed domains. The broker accepted it, and the approval card
  read "Requested by key `codex-cloud`".
  - This is Codex's equivalent of Claude's `proxy-injected`, by a different
    route. `gcp-credentials status` reports `key : $CREDENTIAL_BROKER_REQUEST_KEY`
    here, not `proxy-supplied`, because the helper does read the variable.
    The length check above is how to confirm it holds a placeholder.
  - As on Claude, this protects against the key being copied out, not
    against it being used.
- **`CREDENTIAL_BROKER_URL`** is an ordinary environment variable: the broker
  host with scheme.

### What a Codex task can and can't touch

- **Only `/workspace` is writable and persists.** `$HOME` (`/home/agent`,
  uid 1000) and the root filesystem are read-only. `/tmp` is writable but
  fresh in each task. The sandbox also mounts `.agents`, `.codex`, `.git` and
  `.aws` read-only under both `/workspace` and `/tmp`.
- **`CODEX_HOME` is managed** (`/run/codex-environment/codex-home`). Codex
  doesn't read `~/.agents/AGENTS.md`, so this profile's policy file, as the
  bootstrap installs it, reaches nothing (#495). Each repo's own `AGENTS.md`
  is read when working in that repo.
- **There's no per-task shell hook.** The environment's "start skill" is
  instructions to the agent, not a script, so an `export PATH=…` in it
  affects nothing. Each command runs in a fresh shell.
- **The provisioning (install) script doesn't take effect.** Neither the
  standard bootstrap block nor a trivial probe writing to `/workspace` left
  anything behind for the task to find. Until that changes, everything above
  depended on installing by hand inside a task:
  `cloud/bootstrap.sh … --prefix /workspace/.tools`, which itself stops at
  `mkdir ~/.claude` (#575), with `CREDENTIAL_BROKER_HOME` and
  `CLOUDSDK_CONFIG` pointed under `/workspace/.tools` for that shell.
- **Commands run without network until the agent asks.** The first broker
  request failed with a proxy-connect error and worked once re-run with
  network permission. That's Codex's per-command sandbox, not a broker fault.

### Allowed domains

The Claude section's list, plus **`googleapis.com` and `*.googleapis.com`**.
Codex's common-domains preset doesn't cover Google's API hosts, which Claude's
trusted defaults do, and gcloud calls returned `403` without them. Keep the
common-domains preset on as well: `releases.hashicorp.com`, `pypi.org` and
`raw.githubusercontent.com` come from it.

Two settings matter more than the list, because neither fails in a way that
points at itself:

- **Agent-phase internet must be on.** The whole broker flow (request, wait,
  renew) happens in the agent phase.
- **Don't restrict methods to `GET`/`HEAD`/`OPTIONS`.** The broker's endpoints
  are all `POST`.

### What #575 has to solve before this is usable

- The provisioning script taking effect at all.
- ~~The bootstrap not dying when `$HOME` is read-only.~~ Done: the run probes
  `$HOME`, and when it cannot write there it relocates the session scripts, the
  matrix, the standards and the manifest under `<prefix>/.agent-state/`, skips
  the policy and the skills, and finishes `status=degraded` with
  `degraded=policy-and-skills:home-read-only` and `policy=not-installed
  reason=home-read-only`. `agents_dir=` in the manifest says where it went.
  Still open: the gcp-credentials helper's own state directory and gcloud's
  config default to `$HOME`, so a read-only task still needs
  `CREDENTIAL_BROKER_HOME` and `CLOUDSDK_CONFIG` pointed at the prefix.
- Commands on `PATH` without per-command exports. The preferred route is
  `~/.local/bin`, already first on Codex's PATH, if setup can write there.
- Policy and skills through a channel Codex actually reads.

## Local machines

Not this. `~/.claude` is chezmoi-managed from `home/`; the bootstrap is for
containers that start empty.

Telemetry on a local machine is the exception worth knowing: chezmoi deploys
`agent-telemetry` with the rest of `home/bin`, it spools under
`~/.agents/telemetry/`, and
sends nothing until `TELEMETRY_INGEST_URL` (or `~/.config/claude/telemetry/url`)
is set. The key is a `local-<machine>` key in `~/.config/claude/telemetry/key`,
mode 0600, issued with `tools/telemetry-key`. A Codex cloud environment holds its
`codex-cloud` key as an environment secret in `TELEMETRY_INGEST_KEY` instead, so
that key is inside the container; give it the tighter quota.

## Ending access, and incident response

Revocation levels and what to do about a possibly-exposed token or request key:
[`docs/runbooks/sandbox-gcp-credentials.md`](../docs/runbooks/sandbox-gcp-credentials.md).

## What lands where

The `/usr/local/bin` and `/opt` paths below are the root layout. On an
unprivileged run, or with `--prefix`, read them as `<prefix>/bin` and
`<prefix>/opt`. That includes `shellcheck` and the npm and uv tools, which
then also land in `<prefix>/bin`. The manifest's `bin_dir=` names which.

| Path | What |
| ---- | ---- |
| `~/.agents/skills/gcp-credentials/SKILL.md` | the skill, canonical, vendor-neutral |
| `~/.claude/skills/gcp-credentials` | symlink to the above, for Claude Code |
| `/usr/local/bin/gcp-credentials` | the helper (or `~/.local/bin` unprivileged) |
| `~/.claude/bin/gcp-credentials` | symlink, because the skill still names that path |
| `/usr/local/bin/gcloud` | wrapper: prefers the broker token, renews it when stale |
| `~/.agents/skills/<name>/SKILL.md` | each whitelisted skill, canonical — the sandbox body for a composed one |
| `~/.claude/skills/<name>` | symlink to the above, for Claude Code |
| `~/.claude/CLAUDE.md` | the composed policy profile (Claude profiles) |
| `~/.agents/AGENTS.md` | the composed policy profile (Codex profiles) |
| `~/.claude/bin/<script>` | the session helper scripts (`BIN_SCRIPTS` in `bootstrap.sh`) |
| `~/.claude/conformance/matrix.conf` | the capability matrix `env-conformance` probes |
| `~/.agents/.bootstrap-manifest` | what this run installed: ref, SHA, profile, skills, helpers, and `bin_dir=` (where the commands went) |
| `~/.config/git/hooks/pre-commit` | global git hook, with `--with-precommit` |
| `~/.cache/pre-commit/` | the warmed hook environments, with `--with-precommit` (~126 MB) |
| `~/.claude/settings.json` | harness hook wiring, with `--with-hooks` (merged, not replaced) |
| `~/.claude/bin/*-claude-hook` | the harness hook scripts (`credguard`, `prchecks-wait`, `prepush-guard`, `precommit`), with `--with-hooks` |
| `~/.claude/bin/lib/resolve-command-dir` | the `cd` / `pushd` / `git -C` resolution the commit and push hooks source to find the repo a command targets; a hook that cannot source it reports "not checked" and stands down. With `--with-hooks` |
| `/usr/local/bin/pre-commit`, `/usr/local/bin/shellcheck`, `/usr/local/bin/actionlint`, `/usr/local/bin/gitleaks`, `/usr/local/bin/hadolint`, `/usr/local/bin/trivy`, `markdownlint-cli2` (npm global), `cspell` (npm global), `semgrep` (uv tool) | with `--with-precommit` |
| `/usr/local/bin/gh` | the GitHub CLI, pinned release, with `--with-gh` |
| `/usr/local/bin/golangci-lint` | always: pinned to the estate's CI version, overwriting the image's older copy (`golangci=` in the manifest) |
| `~/.claude.json` → `mcpServers."google-developer-knowledge"` | one user-scope MCP entry, no key, with `--with-devknowledge` (merged, not replaced) |
| `/usr/local/bin/terraform`, `/usr/local/bin/tflint`, `checkov` | the Terraform toolchain, with `--with-terraform` |
| `~/.tflint.d/plugins/…/tflint-ruleset-google/` | the tflint google ruleset, seeded because `tflint --init` is 403ed here: every version a checkout's `.tflint.hcl` pins, plus the estate pin, each verified against its `checksums.txt`. With `--with-terraform` |

Whitelisted today: `promote-journal-inbox`, `retrospective`, `start-session`,
`end-session`. The other **16** skills under `home/skills/` are held back
pending the currency review on
[#247](https://github.com/pmgledhill102/agentic-coding-config/issues/247):

- the **15 `setup-*` skills** — repo-scaffolding procedures a sandbox session
  rarely needs, and they predate this surface;
- **`repo-review`**, added to that hold on 2026-08-28. It was absent without
  ever having been decided about — the arithmetic never closed, and #239 found
  it as the unaccounted sixteenth. Folding it in rather than whitelisting it
  keeps one decision in one place, but note what the hold costs while it
  stands: `README.md` calls the skill portable, and ADR-0015 names it as the
  audit for whether an ADR still fits its tier, so a decision recorded from a
  sandbox cannot be currency-checked from one.

That list being 16 rather than 15 is the only thing the hold is claiming. It is
not a claim that any of the 16 is unwanted here — #247 is where that is decided.

The script keeps two lists, because there are two sources:

- **`COMPOSED_SKILLS`** — the three session skills (#265, #288). Each has a
  workstation body and a cloud-sandbox body built from one shared fragment set,
  so its artefact lives at `profiles/<profile>/skills/<name>/SKILL.md` and is
  fetched by profile, exactly as `AGENTS.md` and `CLAUDE.md` are.
- **`SKILLS`** — one body for every surface, fetched from `home/skills/`.
  `promote-journal-inbox` is the only entry (#289): its pre-flight tests the
  repo rather than a path, and it already prefers MCP with `gh` as the
  fallback, so nothing about it differs by surface. That is ADR-0018 principle
  8 working as intended — one body is the default, and a per-surface pair has
  to earn itself.

Moving a skill between the lists is part of adding or removing its manifest
entry; get it backwards and the fetch 404s at install, naming the skill.

The session skills shell out to four helper scripts, delivered alongside them
into `~/.claude/bin/`. They are not optional: the skills invoke them by name, so
a missing helper fails at the point of use rather than at install.
`start-session-claude-drift` is among them because
`start-session-gather-state` runs it as a sibling — a dependency nothing in the
skill text mentions.

**`gh` does not answer repo questions in these containers**, whether it is
absent or installed-and-403ed (#273, #276), so the gather scripts' GitHub
sections always come back `gh-unavailable` or `gh-unauthorized`. That is no
longer something a session has to notice and route around: the sandbox bodies
of both session skills issue the MCP queries as ordinary steps and never
mention `gh` at all. What those queries cannot express — a `-is:blocked` filter
on issues, an author filter on PRs — the sandbox text states outright rather
than implying a filter that was not applied.

## Pre-commit enforcement

Sandboxes bypassed the pre-commit framework entirely until `--with-precommit`:
the binary was absent and no `.git/hooks/pre-commit` existed, so a repo's
committed `.pre-commit-config.yaml` did nothing here (#254).

On by default for every `*-cloud-sandbox` profile; `--no-precommit` opts out.

It installs `pre-commit`, plus `shellcheck`, `actionlint`, `gitleaks`, `hadolint` and `trivy`, which this
estate's config runs as `language: system` hooks — they use the binary on
`PATH` so the hook and CI cannot drift to different versions, which only works
if the binaries are present. Installing them is the point; the config's `SKIP=`
escape is for a laptop missing one, and normalising it would leave enforcement
that is routinely skipped.

It also installs `markdownlint-cli2` from npm, pinned to the rev
`.pre-commit-config.yaml` declares — bump the two together. That one is *not* a
`language: system` hook: the pre-commit hook builds its own node environment
and CI uses the action, so this install is what makes `markdownlint-cli2
"**/*.md"` — the gate this repo documents first — runnable, since that needs
the binary on `PATH`.

It used to be opt-in for two reasons: it needs GitHub's release downloads and
the package indexes, so an environment that cannot reach them keeps working by
not asking; and the one line an environment carries should declare what kind of
environment it is.

The second reason is now served better by `--profile`, which declares the same
thing at less cost. The first survives as `--no-precommit`, but it is an escape
rather than a default: an enforcement mechanism that arrives only when someone
remembers to ask for it is the state #254 described, and the whole point of a
sandbox being rebuilt from a script is that nobody has to remember.

**It also warms the hook cache, so the first commit does not pay for it.**
`pre-commit` builds a hook's environment on first use, and in this estate that
first use is a *commit* — inside `precommit-claude-hook`'s 120-second timeout.
Cold, the estate's hook set is about 20 seconds of python and node environment
builds. It used to be about two minutes, when `gitleaks` and `actionlint` ran
as `language: golang` hooks compiled from source; they now use their `-system`
ids against binaries this script installs (#609). Both
outcomes of that race are wrong: a hook that times out and lets the commit
through is a gate that silently did not run, and a commit killed for a reason
unrelated to its content is a failure that succeeds on retry (#441).

What makes warming work is *which filesystem*: the setup script's is
snapshotted and reused for about seven days, the session's is not — so a cache
built in-session is rebuilt in every container, and one built here is free at
every session start. It runs as its own capability, `precommit-warm`, and
`degraded=` therefore distinguishes "no gate" from "a gate with a slow first
commit".

Two mechanisms, for the reason the global hook exists at all — at setup-script
time the repository may not exist yet, and may not be the only one:

1. [`cloud/precommit-warm.yaml`](precommit-warm.yaml), the estate's standard
   hook set with pinned revs. pre-commit keys its cache on `(repo URL, rev)`, so
   warming those pins warms every repo pinned to the same ones, clone or no
   clone. This is the guarantee.
2. Every `.pre-commit-config.yaml` found in the workspace, up to five, for the
   revs the pinned file does not carry.

A repo on a different rev gets a **partial** warm, never a failure: the hooks it
shares are cached and the rest build on first use. Keeping that rare is #442.
The measured cost is in
[`docs/cloud-sandbox-design.md`](../docs/cloud-sandbox-design.md) §3.

One dependency worth knowing about: a `language: golang` hook needs `go` on
`PATH`. The estate set has none now, but a repo's own config can. The
sandbox image ships Go at `/usr/local/go/bin`, and when it is absent pre-commit
fetches its own toolchain from `https://go.dev/dl/?mode=json` — which this
egress proxy answers 403. The warm logs a warning and degrades rather than
hanging; the remedy is allowlisting `go.dev` or putting Go back.

**The hook is global, via `core.hooksPath`, not `pre-commit install` per repo.**
This script runs from an environment setup script whose ordering against the
session's clone it cannot rely on — the repository may not exist yet, and may
not be the only one. A global hook is set once and applies however and whenever
a repo arrives. The trade-off is real and worth knowing: `core.hooksPath`
*replaces* a repo's own `.git/hooks` rather than adding to it. In this estate
hooks come from pre-commit anyway.

**`pre-commit install` does not warn under `core.hooksPath` — it refuses, and
exits 1.** Measured 2026-09-15:

```text
$ git config core.hooksPath /root/.config/git/hooks
$ pre-commit install
[ERROR] Cowardly refusing to install hooks with `core.hooksPath` set.
hint: `git config --unset-all core.hooksPath`
$ echo $?
1
```

This is the thing to write a repo-side hook against, because the failure lands
in exactly the containers the bootstrap got *right*: a `SessionStart` hook that
runs `pre-commit install` under `set -e` fails session start wherever the global
hook is correctly installed. Anything belt-and-bracing the gate from inside a
repo has to call `install` only when `core.hooksPath` is unset.

**`pre-commit install-hooks` is unaffected** — exit 0, builds the environments,
writes no hook — which is why the two have to be called separately, and why the
warm above uses it. A repo that genuinely needed bespoke per-repo hooks would
want the other mechanism, and would have to unset `core.hooksPath` to get it.

The hook exits 0 in a repo with no `.pre-commit-config.yaml`. Such a repo is
not opting out of anything — it has no configuration to run, and blocking its
commits would be the container inventing policy the repo never asked for.

This is the vendor-neutral half of enforcement: git runs `.git/hooks` itself,
so it needs no agent configuration and covers Claude, Codex and a human typing
`git commit` identically. The harness-hook half — the one that feeds failures
back into the agent's context — is delivered by `--with-hooks`, and the next
section covers how. It was once blocked on whether a container-created
`~/.claude/settings.json` registers hooks at all (#254); it does, measured, and
the declaration it merges is `home/settings.json`. The `home/hooks/hooks.json`
this paragraph used to name was the plugin copy, withdrawn with the plugin
in #312.

## Harness hooks

`--with-precommit` gives you a native git hook, which blocks a bad commit.
`--with-hooks` adds the harness layer, which runs inside the agent loop and
returns the failure into its context — so the agent reads the message and fixes
the cause rather than simply being stopped. Both are worth having; neither
replaces the other.

Both are on by default for `claude-*` sandbox profiles. A Codex profile gets
pre-commit but not the harness hooks, because Codex does not read
`~/.claude/settings.json`.

Viable because a container-created `~/.claude/settings.json` **is** honoured —
measured 2026-08-18 by planting one and watching a `PreToolUse` hook fire eight
seconds later, with no session restart. That is the third
documented-as-unavailable user-scope path to work from inside a container, after
`~/.claude/skills/` and `~/.claude/CLAUDE.md`.

The wiring is taken from `home/settings.json` rather than restated in the
script. That file is the workstation's, and it already invokes
`~/.claude/bin/<hook>` directly — the same paths the bootstrap installs to — so
both surfaces run identical hooks from one source instead of a copy that drifts.
A dispatcher used to sit in front of the three script hooks, standing down when
a `~/.claude/bin` copy was present so a plugin-enabled workstation would not run
each hook twice; it was withdrawn with the plugin channel (#312), and each
script is now named directly.

**Merged, not overwritten.** A container may already have a `settings.json`, and
replacing it wholesale would silently drop whatever else it holds. Note
`~/.claude/launcher-settings.json` is a different file with its own hooks,
written by the harness; nothing here touches it, and both are read.

Two of the three can degrade rather than fail in a sandbox.
`prepush-guard-claude-hook` needs `gh`: without `--with-gh` it allows each
push with a `not checked -- gh unavailable` line, and with it the guard works,
because it asks the REST pulls API, which the sandbox serves, rather than the
GraphQL behind `gh pr view`, which the sandbox refuses (#317).
`precommit-claude-hook` needs the pre-commit framework, so it does nothing
without `--with-precommit`.

## When the bootstrap never ran at all

Everything above assumes the bootstrap ran, at least partway: a failed run
leaves `status=failed` in the manifest and a banner in the policy file. A
container whose setup script was empty, stale or absent leaves neither, and
looks normal: no `~/.claude/bin`, no managed `CLAUDE.md`, no `/end-session`.
One session worked five days like that (#545).

Nothing the bootstrap installs can report its own absence, so the check is
committed in the repo instead: `.claude/hooks/bootstrap-absent-check.sh`,
registered as a `SessionStart` hook in `.claude/settings.json`. In a cloud
session (`CLAUDE_CODE_REMOTE=true`) with neither `~/.agents/.bootstrap-manifest`
nor `~/.claude/bin`, it prints one fixed warning that the model reads as
context. It starts no program and cannot fail a session.

**What it does not cover.** A repo's `.claude/settings.json` is read only when
the session is in that repo, so this protects sessions in this repo and reports
nothing in any other. A repo that wants the same warning copies the script and
the `settings.json` entry; the repo-footprint cost is deliberate, because
there is no bootstrap-independent route that costs less. The other half of
issue 545, why that environment skipped its setup script, is a setting in the
vendor's environment configuration and cannot be found from here.

## Knowing whether a container is stale

The environment re-runs its setup script only when the script text changes, the
allowed hosts change, or roughly seven days pass — so a push does not reach new
sessions and a sandbox can be running week-old content with nothing saying so.
The credential helper solved its half server-side, by sending a version the
broker can refuse (#182); skills, policy and helper scripts have no server on
the other end.

So the bootstrap writes `~/.agents/.bootstrap-manifest` recording the ref, the
resolved SHA, the timestamp, the profile, and what it installed. `start-session`
reads it in its `bootstrap_currency` section and reports `current`, `behind`,
`pinned`, `no-manifest` or `unknown`. On `behind` it gives the remedy, which is
re-running the bootstrap — immediate, no restart.

`git ls-remote` resolves the ref rather than the GitHub API: no token, no JSON
parsing, and git is already required to be here. It asks the repository the
manifest's `source=` line names, which is the published one unless the
environment overrode it; a manifest from before that line existed is compared
with the published repository and reads as `behind`.

**What this guarantees, precisely.** Not that every session starts fresh. The
check ships inside the thing it checks, so a container older than the check
cannot report it — that self-heals after one cache cycle rather than
immediately. And it runs only when `start-session` runs. It is advisory. The
automatic version would be a `SessionStart` hook, which is blocked on whether
hooks in a container-created `~/.claude/settings.json` are honoured at all
(#254).

## Which profile

`--profile <name>` selects the composed context profile, defaulting to
`claude-cloud-sandbox`. A Codex environment passes `--profile
codex-cloud-sandbox`:

```sh
PROFILE=codex-cloud-sandbox
```

The environment declares which harness it is rather than the script sniffing
for one. Per ADR-0018 principle 1 surface differences are resolved at delivery,
and the caller is the only party that knows the answer without guessing.

Profiles are built and verified in CI by `tests/compose-context.py`, which also
refuses to compose a sandbox profile that includes a workstation fragment. That
is what stops "run `chezmoi apply`" reaching a container with no chezmoi, so
this script does not have to check.

Each profile ships one policy file, where its agent reads it. Claude profiles
ship `CLAUDE.md` to `~/.claude/`; the neutral `AGENTS.md` they also used to
ship was read by nothing and is retired (#310). Codex profiles ship `AGENTS.md`,
and it lands in `~/.agents/`. **On Codex Cloud nothing reads it there (#495).** Codex's home is
a managed `CODEX_HOME`, `$HOME` is read-only inside a task, and Codex reported
loading no user-level `AGENTS.md` at all. The failure is the silent kind: the
file could be present and correct and still never be seen. Which channel
replaces it (`CODEX_HOME` written during setup, Codex's own instructions
setting, or repo `AGENTS.md` files) is open in #575.

## Updating a running session

Re-run the bootstrap directly; no environment edit, no restart:

```sh
curl -sSL https://raw.githubusercontent.com/pmgledhill102/dotfiles/main/agent/cloud/bootstrap.sh \
  -o /tmp/bootstrap.sh
sh /tmp/bootstrap.sh main --profile claude-cloud-sandbox
```

Do not add `--no-gcloud` here even where gcloud already exists: the download
is skipped when an SDK is already on `PATH`, but the same capability is what
wraps that SDK so the preset `CLOUDSDK_AUTH_ACCESS_TOKEN` does not beat a broker
grant.

Skills are read when the agent starts, so a newly installed skill appears after
the session restarts or resumes. The helper is usable immediately.

## When the broker says the helper is too old (exit 8)

The helper sends a `X-Client-Version` header on `/request` and `/poll`, and the
broker refuses anything below its minimum with HTTP 426 — **before** posting an
approval card, so a stale client never spends a human approval it cannot
complete. The helper exits 8 and renders the broker's hint.

This exists because a client too old to understand a new broker state is also
too old to know that the state exists: three broker releases in a row
(`warming`, `failed`, `provisioning`) each broke running sessions with
`unexpected state: <name>`. Self-checking asks the stale component to detect its
own staleness, which only works for cases it already anticipated. The broker
always knows what it needs, so the check belongs there.

**Why this bites cloud sessions specifically.** The environment snapshots the
setup script's result and re-runs it only when the script *text* changes, the
allowed domains change, or roughly seven days pass. Because `main` never changes
as a string, **pushing to `main` does not reach new sessions** — they keep
restoring a snapshot built with whatever helper was current then. A cloud
session can be running a week-old client with nothing to indicate it.

Two remedies, in the order you want them:

| Situation | Do this |
| --- | --- |
| The session in front of you | Re-run the bootstrap (above). Takes effect immediately for the helper |
| Every session from now on | Bump `Rev:` in the setup script, forcing a rebuild |

Do both. The re-run unblocks the task at hand; the `Rev:` bump is what stops the
next session hitting the same wall. On a local machine the equivalent is
`chezmoi apply --refresh-externals` — see the skill doc.

**The version constant is bumped in the same commit as the wire change that
needs it**, on both sides. That is the whole value of the mechanism: the bump is
the moment someone notices a client change is required, rather than a session
discovering it mid-task. The helper's `CLIENT_VERSION` carries a comment saying
so; the broker's `clientversion.go` keeps the authoritative history.

Do **not** make the skill fetch and install a newer helper before running. The
helper is what displays the verification phrase, which makes it the one
client-side component that is security-relevant — a compromised helper could
show a phrase that does not match the request it made and walk a human into
approving something else. Updating that component *inside* the credential flow
means the code implementing the phrase check can change during the request it is
checking. Detect and instruct; do not self-modify.
