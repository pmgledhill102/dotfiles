# ADR-0019: How far Homebrew reaches on Linux, tier by tier

- **Status**: Accepted. The work tier's move to Homebrew is conditional:
  its thresholds are checked in CI during implementation (see "Decision"),
  and it rests on the sudo assumption under "Install location".
- **Scope**: Repo — this record binds `dotfiles` only. It decides which
  package manager this repo drives for which tools on each Linux machine tier,
  which would bind nothing if this repo were archived.
- **Date**: 2026-11-19
- **Tags**: packages, linux, wsl
- **Amends**: [ADR-0004](0004-native-package-managers-per-platform.md) for
  `work` and `minimal` Linux machines, and
  [ADR-0017](0017-homebrew-on-personal-linux.md), whose rejection of
  "Homebrew on every Linux tier" this record partly reverses
- **Refs**: [#445](https://github.com/pmgledhill102/dotfiles/issues/445)

## Context

[#445](https://github.com/pmgledhill102/dotfiles/issues/445) asked whether
Homebrew on Linux (Linuxbrew) should manage developer CLI tools on
Ubuntu/WSL, because ADR-0004 never evaluated it and Linux provisioning had
grown about seven hand-written installers, each with its own update story.

Two days later [ADR-0017](0017-homebrew-on-personal-linux.md) answered that
question for the `personal` tier: personal Linux runs Homebrew and the shared
`home/Brewfile.tmpl`, and apt keeps only the bootstrap set. It answered the
other two tiers by assertion ("work and minimal machines value a small, fast,
native install") rather than by evaluation, and its cost line ("several GB",
"much slower") had no numbers behind it.

So this record does three things #445 still needs:

1. Evaluates the three options from #445 against each of its "Things to
   evaluate" points, for every tier, not only personal.
2. Records what ADR-0017 actually cost, from CI logs, and names the numbers
   still to be measured on WSL.
3. Settles the hand-written installers that remain. After ADR-0017 they
   serve `work` and `minimal` only, so the maintenance cost #445 complained
   about is now carried entirely by the two tiers that were not evaluated.

### What each tier gets today (`main` at the time of writing)

| | personal | work | minimal |
| --- | --- | --- | --- |
| apt list (`[data.packages.apt]`) | curl git unzip wget zip zsh | bat curl eza fd-find git git-delta jq ripgrep tmux unzip wget zoxide zsh | as work, minus unzip |
| Homebrew + Brewfile | yes (ADR-0017) | no | no |
| starship | Brewfile | curl installer | curl installer |
| fzf, lazygit, mdcat | Brewfile | GitHub release tarballs via `latest_release_tag()` | same as work |
| bat/fd name links | not needed | `~/.local/bin` symlinks | same as work |
| gh | Brewfile | cli.github.com apt repo | not installed |
| uv | Brewfile | curl installer | curl installer |
| nvm | install script (pinned) | install script (pinned) | not installed |
| PowerShell | Microsoft apt repo | Microsoft apt repo | not installed |
| Docker Engine | Docker apt repo (ADR-0018) | Docker apt repo | not installed |
| rustup, build-essential | yes | yes | not installed |
| `brewup` deployed | yes | no | no |

The `work` Brewfile tier already exists for work Macs; it has never been
rendered on Linux.

## Measured so far

From the `Test Install on ubuntu-latest` job (push to `main`, personal tier,
x86_64 GitHub-hosted runner). These are CI numbers, not WSL numbers: the
runner has fast Azure networking and no WSL layer, and the job removes the
runner's own `/home/linuxbrew` first so Homebrew is bootstrapped from scratch.

| Run | Image | Homebrew install | `brew bundle` | Job total | Disk overhead of apply |
| --- | --- | --- | --- | --- | --- |
| 2026-10-04 / 10-05, before ADR-0017 | ubuntu-24.04 | — | — | 61–83 s | 1.12 GB |
| 2026-10-06, first run after ADR-0017 | ubuntu-24.04 | 16.5 s | 11 min 10 s, 59 deps | 763 s | 10.17 GB |
| 2026-11-15 | ubuntu-26.04 | 16 s | 7 min 8 s, 60 deps | 513 s | 10.62 GB |

Across the 22 successful runs from 2026-10-06 to 2026-11-15 the job took
461–780 s. Across those from 2026-07-18 to 2026-10-05 it took 59–128 s.
So for the personal Brewfile, ADR-0017 added **about 7–11 minutes and about
9.5 GB** to a first apply in CI. Installing Homebrew itself is negligible
(about 16 s); the cost is the Brewfile's contents.

M1 on a fresh `Ubuntu-24.04` WSL distro, 2026-11-19 (x86_64, 32 CPUs,
16 GB, systemd, ext4 home; Homebrew 7.0.15). Times are wall-clock seconds;
disk is the change in used space on `/`:

| Quantity | Value |
| --- | --- |
| apt prerequisites (build-essential procps curl file git jq) | 20 s, 599 MB |
| Homebrew install, WSL | 17 s, 283 MB (prefix 222 MB) |
| Candidate tools (starship lazygit mdcat gh powershell nvm uv) | 78 s, 1,776 MB |
| apt-overlapping tools (bat git-delta jq fzf eza fd ripgrep zoxide tmux) | 26 s, 128 MB |
| Formulae built from source instead of poured | none: every formula and dependency poured a bottle |
| `brew doctor` on WSL | "Your system is ready to brew." |
| Warm `brew update` | 1 s |
| ARM64 Linux bottles, sampled from the formula API | 10 of 10 have `arm64_linux` and `x86_64_linux` bottles: bat, mdcat, lazygit, starship, uv, gh, fzf, eza, ripgrep, zoxide. The rest of the work slice is checked during implementation (see "Decision") |
| End-to-end first apply, `work` tier, status quo and with Homebrew | Measured in CI during implementation (see "Decision") |

What the per-formula figures show:

- **PowerShell is more than half of the candidate set's disk.** It pulls in
  `dotnet` (795 MB) and `icu4c@79` (96 MB); the prefix grew by 951 MB for
  that one formula. Every other candidate is under 50 MB of its own.
- **mdcat brings 23 dependencies**, including Homebrew's own `curl`,
  `openssl@4`, `krb5`, `ncurses` and `sqlite` (prefix +212 MB, 35 s). These
  duplicate apt's copies; `curl` is the one that also lands on `PATH`.
- **nvm via Homebrew is unsupported upstream.** Its caveat says so, and
  warns that leaving `NVM_DIR` inside the Cellar destroys installed Node
  versions on upgrade.
- The first M1 bottle table was wrong in two ways, both artefacts of the
  check rather than of Homebrew. `brew info --json` on an x86_64 Linux host
  lists only that host's tag, so the `arm64_linux` column could never be
  "yes". And formulae that ship a single architecture-independent `all`
  bottle (nvm, prettier, cspell, markdownlint-cli2, bitwarden-cli, gradle,
  maven, jenv, git-filter-repo) showed as missing on x86_64 too; nvm in fact
  poured `nvm--0.41.0.all.bottle.tar.gz`. The script below now reads the
  public formula API, which lists every tag.

## Options

1. **Status quo.** ADR-0017 for personal; apt plus hand-written installers
   for work and minimal.
2. **Hybrid.** apt owns the OS base and anything with system integration
   (git, zsh, build-essential, ncurses, Docker Engine, PowerShell's Microsoft
   repo). Homebrew owns developer CLI tools, rendered from the same
   `home/Brewfile.tmpl`. This is what ADR-0017 does for personal.
3. **Linuxbrew-first.** Everything with a Linux bottle comes from Homebrew;
   apt only bootstraps (curl, git, build-essential, procps, file).

## Evaluation

Each point from #445, per option, with tier differences where they exist.

### Brewfile sharing

- **Status quo:** personal already shares one file; work and minimal have no
  Linux Brewfile, so every tool added on a work Mac needs separate Linux code.
- **Hybrid:** keep what ADR-0017 established. One `home/Brewfile.tmpl`, with
  macOS-only entries behind chezmoi's `{{ if eq .chezmoi.os "darwin" }}`
  rather than Ruby `OS.mac?` blocks. The rendered `~/Brewfile` then lists
  exactly what this machine installs, so `brew bundle check` and
  `scripts/check-brewfile-manifest.sh` read it without evaluating Ruby, and
  one templating language gates both OS and tier. Split files would double
  the lists ADR-0004 already found costly. Extending hybrid to work means
  adding the same darwin guard inside the work tier (casks, colima, docker,
  nvm, powershell). "Casks don't work on Linux" is no longer strictly true:
  `azure-cli` is a Linux-capable cask and sits outside the guard.
- **Linuxbrew-first:** same file, but it would also absorb what apt owns
  today (git, zsh, wget, tmux), so the darwin guard shrinks and the bootstrap
  ordering gets harder (see PATH ordering).

### PATH ordering and one owner per tool

`dot_zshrc.tmpl` prepends `~/.local/bin`, then evaluates `brew shellenv`
(which prepends `/home/linuxbrew/.linuxbrew/bin`), then prepends
`~/.cargo/bin`. Effective order: cargo, Linuxbrew, `~/.local/bin`,
`/usr/bin`. That is the reverse of the fzf failure ADR-0004 records, where
apt's copy won.

- **Status quo:** no conflict on work and minimal, since brew is absent.
- **Hybrid:** brew wins every tie, so a stale apt copy is shadowed, not
  served. The rule should be stated, not implied: **a tool has exactly one
  owner per tier, except the bootstrap set** (`curl`, `git`, `wget`, `zsh`),
  which apt must provide before Homebrew exists. Today `git` and `wget` are in
  both the personal apt list and the personal Brewfile, which is that
  exception in practice but nowhere written down. A CI check that fails when
  a tier's apt list and its Linux-rendered Brewfile share a name outside the
  bootstrap set would make the rule enforceable.
- **Linuxbrew-first:** the login shell itself (`zsh`) would come from
  Homebrew, which means `/etc/shells` edits and a `chsh` to a path under
  `/home/linuxbrew`. A broken brew then breaks login. Not worth it.

### Bootstrap cost

- **Status quo:** CI first apply about 1–1.5 min, about 1.1 GB (personal
  before ADR-0017, the closest proxy for today's work tier). The real
  work-tier figure comes from the CI `work` leg (see "Decision").
- **Hybrid:** CI shows Homebrew itself costs about 16 s; the Brewfile is the
  cost (personal: 7–11 min, about 9.5 GB, 60 formulae). The work tier's
  Linux-capable slice is about 37 formulae (43 minus colima, the three
  docker formulae, nvm and the acli tap) and leaves out the heaviest
  personal entries (ffmpeg, imagemagick, ocrmypdf, pandoc, gradle, maven,
  hugo, typst, weasyprint), so it should cost well under the personal figure.
  Expected, not yet measured end to end: the CI `work` leg gives the real
  figure. A compiler is already present (build-essential, #442) on personal
  and work. M1 on WSL: Homebrew itself 17 s and 283 MB; the 16 candidate
  and overlap formulae together 104 s and about 1.9 GB, of which PowerShell
  (through `dotnet`) is 951 MB. Without PowerShell the same set is about
  0.95 GB. Nothing was built from source.
- **Linuxbrew-first:** strictly more than hybrid, for tools apt already
  serves in seconds.
- **ARM64:** every one of the 10 formulae sampled from the formula API,
  covering each hand-written installer that has a formula, has an
  `arm64_linux` bottle. The rest of the work slice is
  checked when its Linux rendering is written (see "Decision"). Any formula with neither an
  `arm64_linux` nor an `all` bottle either builds from source on ARM64
  Linux (slow, needs the toolchain) or goes behind a guard. mdcat shows the
  gain: its GitHub release is x86_64-only, so on ARM64 the status quo
  installs nothing, while Homebrew has a bottle.

### Install location

- **All options with brew:** the default prefix `/home/linuxbrew/.linuxbrew`
  is the only one with bottles; any other prefix builds everything from
  source. Creating it needs sudo once. The before-script already runs
  `apt-get` under sudo, so the installer's one sudo call reuses that, and
  `NONINTERACTIVE=1` removes the "Press RETURN" prompt. `install.sh` needs no
  change: it only guarantees git and curl, and the before-script installs
  Homebrew.
- **Work tier specifically:** a corporate Linux machine without sudo, or one
  whose policy forbids Homebrew, cannot use hybrid. The work tier needs a
  fallback, and the status quo is that fallback. **Assumed, not confirmed:**
  work Linux machines have sudo and allow Homebrew. No complete inventory
  exists to check this against, so it is a working assumption. If a work
  machine turns out to lack sudo or forbid Homebrew, the work tier needs a
  non-Homebrew path again: the installers listed under "What would be
  deleted" go ahead as planned on this assumption, and would have to be
  restored, or replaced, for that machine.
- **CI:** the runner image ships its own Linuxbrew; the full-install job
  deletes it before applying (already in place for ADR-0017).

### Updates

- **Status quo:** work and minimal have no update path for fzf, lazygit or
  mdcat after day one; starship is refreshed by `dotup` only when brew is
  absent; uv updates only via `uv self update`; gh and PowerShell follow `apt upgrade`.
- **Hybrid:** `brewup` (ADR-0009) already runs on personal Linux. Deploying
  it to work Linux changes nothing in ADR-0009's naming split: `brewup` is a
  `<tool>up` command and simply exists on more machines. `dotup`'s
  "update Starship (Linux)" branch remains only for machines without brew,
  which would then mean minimal alone.
- **Linuxbrew-first:** as hybrid, plus apt's security updates for tools that
  moved to brew stop arriving via unattended-upgrades. A regression for a
  server-like minimal machine.

### CI

- PR CI runs with `DOTFILES_SKIP_INSTALL=1` and is unaffected by any option.
- The push-to-`main` full install exercises the **personal** tier only, so
  today's work and minimal Linux paths (including `latest_release_tag()`)
  are never run in CI.
- **Status quo:** that blind spot stays.
- **Hybrid for work:** the work tier gains code CI does not run unless a
  `work` leg is added to the ubuntu matrix. Its cost is the work slice's
  bundle time per push to `main`, which that leg itself reports; PRs stay
  fast.
- **Linuxbrew-first:** personal job time grows further for no benefit.

### WSL specifics

- `/home/linuxbrew` sits on the distro's ext4 VHDX, not on `/mnt/c`, so the
  DrvFs performance and permission problems do not apply.
- Homebrew does not need systemd; Docker Engine does, and
  `run_once_configure-wsl` already enables it.
- `install.sh` strips `/mnt/*` from `PATH` on a first apply (#437), so the
  Windows `PATH` cannot shadow brew during bootstrap.
- M1: `brew doctor` on a fresh distro reports "Your system is ready to
  brew." The only WSL-specific output is a harmless warning on every fetch
  that the kernel's Landlock ABI (7) is older than the 10 Homebrew's network
  sandbox prefers; it applies the restrictions the kernel supports and
  carries on.

### What would be deleted

- **Status quo:** nothing.
- **Hybrid for work, minimal trimmed (the recommendation below):**
  `latest_release_tag()`; the fzf, lazygit and mdcat release-tarball blocks;
  the bat/fd symlink loop (Homebrew uses the upstream names, and minimal can
  use `batcat`/`fdfind` through aliases or do without); the gh apt-repo
  block. That is everything in `run_onchange_install-ubuntu-packages.sh.tmpl`
  that depends on GitHub release URLs, which is the code #429 had to harden
  and which CI never runs.
- **Linuxbrew-first:** the above plus most of the apt list, for no further
  maintenance saving: apt entries are one word each.

## Decision

| Tier | Option | In practice |
| --- | --- | --- |
| personal | 2, hybrid (unchanged from ADR-0017) | Write down the bootstrap-set exception to one-owner-per-tool. |
| work | 2, hybrid, if the thresholds below hold | Render the work Brewfile tier on Linux with a darwin guard; install Homebrew in the before-script; deploy `brewup`. Fall back to the status quo on machines without sudo. |
| minimal | 1, status quo, trimmed | apt only, plus the vendor installers for starship and uv. Drop the GitHub-release tarballs (fzf, lazygit, mdcat) and `latest_release_tag()`. |

Option 3 is rejected on every tier.

Two tools stay off Homebrew on every Linux tier, whatever else moves. On
personal Linux both are already macOS-only in the Brewfile (#435); M1 now
gives the reasons, and the work tier's Linux rendering must guard them the
same way:

- **PowerShell** stays on the packages.microsoft.com apt repo. Through
  Homebrew it pulls a private `dotnet` and costs 951 MB on its own; the
  Microsoft `.deb` bundles only the runtime it needs (its size is not
  measured here).
- **nvm** stays on its official installer (pinned, as today). Upstream does
  not support the Homebrew formula, and its default layout loses installed
  Node versions on upgrade.

Work-tier thresholds: a first apply of the work tier with Homebrew adds no
more than **5 minutes** and **4 GB** over the status-quo work apply, and no
formula in the work slice is built from source on x86_64. M1 already
suggests a comfortable pass (Homebrew plus 16 tools: about 2 minutes and
0.95 GB without PowerShell), so these are checked in CI during
implementation rather than by a manual end-to-end run before acceptance:

1. **Baseline first.** Add a `work` leg to the ubuntu full-install job on
   today's code. It closes the CI blind spot on its own merit, and its first
   runs on `main` give the status-quo work time and disk.
2. **Then the change.** The PR that moves work Linux to Homebrew lands only
   if that leg, run on `main` after merge (or via `workflow_dispatch` on the
   branch), stays within the thresholds against the baseline. The same PR
   runs the formula-API bottle check from M1 over the rendered work slice,
   and any formula without an `arm64_linux` or `all` bottle gets a guard.

If a threshold fails, the work tier stays on option 1 (revert that PR) and
only the minimal trim goes ahead. The real-machine figure is no longer
needed for acceptance: a CI runner is faster than a WSL distro, but the
comparison is like for like on the same runner.

### What this deviates from, and why

- **ADR-0004** (native managers, no second manager on a Linux host): for the
  work tier as well as personal. Reason: the hand-written installers that
  ADR-0004's model needs are now maintained for two tiers CI never runs, and
  have no update path.
- **ADR-0017**, alternative "Homebrew on every Linux tier", rejected because
  work and minimal "value a small, fast, native install": reversed for work,
  kept for minimal. Reason: the cost turned out to sit in the Brewfile's
  contents rather than in Homebrew, and the work slice is smaller than the
  personal one. Minimal keeps the rejection because it is the tier for
  servers and CI runners, where unattended apt security updates matter more
  than tool versions.
- **ADR-0009:** no rule changes, but `brewup` is deployed to work Linux and
  `dotup`'s Starship branch becomes minimal-only.

## Consequences

### Positive

- The GitHub-release installer code goes away entirely, including the
  rate-limit workaround (#429) that CI could not exercise.
- Work Linux gets the same tools and versions as a work Mac from one list,
  and an update command.
- The one-owner rule becomes explicit and checkable.

### Negative / trade-offs

- Work Linux first applies get slower and larger (the CI `work` leg
  reports by how much; M1 puts Homebrew plus the 16 tools measured at about 2 minutes and 1.9 GB,
  or 0.95 GB with PowerShell kept on apt).
- Formulae such as mdcat bring Homebrew copies of libraries apt already
  has, `curl` among them, so a tool can be on `PATH` twice. The PATH
  ordering rule above decides which one wins.
- Two managers on work hosts: the PATH ordering above must hold there too.
- Minimal machines lose fzf, lazygit and mdcat unless installed by hand.
- Work tier on Linux becomes a third rendering of the Brewfile to keep
  correct, and needs a CI leg to stay honest.

## Alternatives considered

- **Hybrid on every tier, minimal included.** Rejected for the minimal-tier
  reason above.
- **Keep work on the status quo but fix the updates** (a `linuxup` that
  re-runs the tarball installers). Keeps exactly the code #445 wanted gone.
- **Ruby `OS.mac?` blocks instead of chezmoi conditionals.** Hides the
  rendered package list behind Ruby evaluation and adds a second gating
  language next to chezmoi's tier conditionals.
- **Nix / home-manager, mise, pkgx.** Rejected in ADR-0004; nothing has
  changed.

## Follow-ups (file only once this record is accepted)

One issue per concern, as #445 asks: work-tier Brewfile darwin guard;
Homebrew in the before-script for work; `brewup` deployment in
`.chezmoiignore`; the bootstrap-set rule and its CI check; removing the
replaced installers; the minimal-tier trim. The `work` leg in the ubuntu
full-install job comes first of all, before any tier changes, so that it
records the status-quo baseline the thresholds compare against.

## Measurement procedure

Run on a throwaway distro, never on a machine you keep. From PowerShell:

```powershell
wsl --install -d Ubuntu-24.04 --name brewtest
```

Create the default user when prompted, then inside the distro run M1. M2
is optional: the thresholds are checked in CI instead (see "Decision"), so
run it only for a real-machine figure.

### M1: Homebrew and candidate tools

Save as `~/measure-linuxbrew.sh` and run `sh ~/measure-linuxbrew.sh` as the
normal user. It needs sudo once for apt and for `/home/linuxbrew`. Results go
to `~/brew-measure-<timestamp>.txt`; Homebrew's own output to the matching
`.install.log`.

```sh
#!/bin/sh
# Measure what Linuxbrew costs on a fresh Ubuntu 24.04 distro (ADR-0019).
# Throwaway distro only: it installs Homebrew and ~20 formulae. Run as the
# distro's normal (non-root) user; Homebrew refuses to run as root.
set -eu

OUT="$HOME/brew-measure-$(date +%Y%m%d-%H%M%S).txt"
CANDIDATES="starship lazygit mdcat gh powershell nvm uv"
OVERLAP="bat git-delta jq fzf eza fd ripgrep zoxide tmux"
# Linux arm of the personal Brewfile plus the work tier's extras (taps omitted).
BOTTLE_CHECK="actionlint aria2 aws-sam-cli awscli bat bitwarden-cli chafa
checkov cspell dotnet eza fd fzf gh github-mcp-server git git-delta
git-filter-repo gitleaks go-task go golangci-lint gradle ffmpeg hadolint hugo
imagemagick jenv jp2a jq lazygit lychee markdownlint-cli2 maven mdcat nano
ocrmypdf openjdk openssl pandoc poppler pre-commit prettier ripgrep semgrep
shellcheck starship tenv tmux trivy typst uv watch weasyprint wget yq zoxide
nvm powershell"
BREW_PREFIX=/home/linuxbrew/.linuxbrew

log() { printf '%s\n' "$*" | tee -a "$OUT"; }
used_mb() { df -Pm / | awk 'NR == 2 { print $3 }'; }
dir_mb() { du -sm "$1" 2>/dev/null | cut -f1; }

log "== host"
log "arch: $(uname -m)"
# shellcheck disable=SC1091
log "os: $(. /etc/os-release && echo "$PRETTY_NAME")"
log "wsl: $(grep -qi microsoft /proc/version && echo yes || echo no)"
log "pid1: $(ps -p 1 -o comm=)"
log "cpus: $(nproc)  mem_mb: $(free -m | awk '/^Mem:/ { print $2 }')"
log "home fs: $(df -PT /home | awk 'NR == 2 { print $2 }')"

log "== apt prerequisites (build-essential procps curl file git jq)"
disk0=$(used_mb)
t0=$(date +%s)
sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  build-essential procps curl file git jq >/dev/null
log "time_s: $(($(date +%s) - t0))  disk_delta_mb: $(($(used_mb) - disk0))"

log "== Homebrew install (NONINTERACTIVE=1)"
disk0=$(used_mb)
t0=$(date +%s)
NONINTERACTIVE=1 /bin/bash -c \
  "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
  >>"$OUT.install.log" 2>&1
log "time_s: $(($(date +%s) - t0))  disk_delta_mb: $(($(used_mb) - disk0))"
log "prefix_mb: $(dir_mb "$BREW_PREFIX")"
eval "$("$BREW_PREFIX/bin/brew" shellenv)"
export HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_ASK=1 HOMEBREW_NO_AUTO_UPDATE=1
log "brew: $(brew --version | head -n 1)"

install_set() {
  log "== brew install, one at a time: $1"
  disk0=$(used_mb)
  set_t0=$(date +%s)
  for f in $1; do
    t0=$(date +%s)
    if brew install --formula "$f" >>"$OUT.install.log" 2>&1; then
      res=ok
    else
      res=FAILED
    fi
    log "  $f: $res time_s=$(($(date +%s) - t0)) prefix_mb=$(dir_mb "$BREW_PREFIX")"
  done
  log "set time_s: $(($(date +%s) - set_t0))  disk_delta_mb: $(($(used_mb) - disk0))"
}
install_set "$CANDIDATES"
install_set "$OVERLAP"

log "== built from source rather than poured (should be empty)"
brew info --json=v2 --installed |
  jq -r '.formulae[] | select(.installed[0].poured_from_bottle | not) | .name' |
  tee -a "$OUT"

log "== warm brew update"
t0=$(date +%s)
brew update >>"$OUT.install.log" 2>&1 || log "brew update FAILED"
log "time_s: $(($(date +%s) - t0))"

log "== brew doctor (WSL check; warnings are listed, not fatal)"
brew doctor >>"$OUT" 2>&1 || log "brew doctor reported warnings (above)"

# Read the public formula API, not `brew info`: on a Linux host `brew info`
# lists only the host's own bottle tag, so it cannot answer for ARM64. An
# `all` bottle is architecture-independent and covers both. The Linux tags
# are printed verbatim, so a renamed tag shows up rather than reading as "no".
log "== Linux bottle availability (formula: x86 arm64 | linux tags seen)"
API=https://formulae.brew.sh/api/formula
for f in $BOTTLE_CHECK; do
  if json=$(curl -fsSL "$API/$f.json" 2>/dev/null); then
    printf '%s\n' "$json" |
      jq -r '(.bottle.stable.files // {} | keys) as $k |
        .name + ": " +
        (if ($k | index("all")) or ($k | index("x86_64_linux")) then "x86 " else "NO-x86 " end) +
        (if ($k | index("all")) or ($k | index("arm64_linux")) then "arm64" else "NO-arm64" end) +
        " | " + ([$k[] | select(test("linux|^all$"))] | join(" "))' |
      tee -a "$OUT"
  else
    log "$f: NOT-FOUND-IN-API"
  fi
done

log "== done; results in $OUT, brew output in $OUT.install.log"
```

Per-tool times in the first set include shared dependencies the first time
they appear, so read the set totals as the comparable figure. The bottle
table reads Homebrew's metadata, so it is valid on an x86_64 machine for
ARM64 coverage too.

### M2 (optional): end-to-end first apply, per tier

In a fresh distro, time the real bootstrap and answer `work` at the
`machine_type` prompt; answer `personal` in the second distro. (Seeding
`~/.config/chezmoi/chezmoi.toml` the way CI does will not work here:
`install.sh` deletes that directory before `chezmoi init`.)

```sh
df -Pm / | awk 'NR == 2 { print "used_mb_before:", $3 }'
time sh -c "$(curl -fsSL https://raw.githubusercontent.com/pmgledhill102/dotfiles/main/install.sh)"
df -Pm / | awk 'NR == 2 { print "used_mb_after:", $3 }'
```

Prompts during the apply (the tier choice, secrets setup) count towards the
wall-clock time, so answer them promptly or note how long they took.
