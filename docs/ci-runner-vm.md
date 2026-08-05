# Self-hosted CI runner in a Tart VM

A self-hosted GitHub Actions runner for macOS builds, running inside a
[Tart](https://tart.run) VM rather than on the host user account. Four scripts
build, start, stop and destroy it. Which repo it registers against is machine
configuration, not something this repo records — see [Configuration](#configuration).

| Script | Does |
| --- | --- |
| `ci-vm-build` | Clone the Xcode image, size it, boot it, push an SSH key, install the build tooling, register the runner, install it as a launchd service. Idempotent. |
| `ci-vm-up` | Start headless and detached, wait for an IP, wait for the guest to boot and its runner agent to start, then poll GitHub until the runner reports online. Non-zero exit if any of that times out. |
| `ci-vm-down` | Graceful `tart stop`. Refuses while the runner is mid-job unless `--force`. |
| `ci-vm-destroy` | Deregister the runner from GitHub, then delete the VM. Prompts first. |

They live in `home/dot_local/bin/` and land on `PATH` at `~/.local/bin/` after a
`chezmoi apply`.

## Why a VM

The runner previously executed as `paul`, directly on the laptop. Every workflow
therefore ran as the daily-use user, with that user's keychain and login session
in reach. Moving the runner into a VM fixes that class of problem once, rather
than case by case.

## Why one persistent VM, not ephemeral per-job VMs

These are private repos, so run-to-run spillover isn't a threat worth paying
for. Persistence keeps DerivedData warm between jobs, which is what makes
incremental builds fast; an ephemeral VM would throw that away on every job.

That decision is also why [Tartelet](https://github.com/shapehq/tartelet) isn't
in the picture. Its whole purpose is spawning fresh VMs with just-in-time runner
registration. Skip that and what remains is an ordinary runner installed inside
a VM and registered as a launchd service: boot the VM, the service starts, the
runner appears online; `tart stop`, it goes offline. No orchestration daemon,
nothing to maintain. (Tartelet has also had no release in roughly twelve months
and a growing issue backlog.)

## Prerequisites

- Apple silicon Mac. Tart uses Virtualization.framework.
- `tart`, `gh`, `expect` — all installed by the Brewfile, `expect` ships with macOS.
- `gh` authenticated with a token carrying `repo` scope; runner registration
  tokens come from the API.
- Roughly 150 GB free. The image is ~66 GB compressed and expands to a 140 GB
  sparse disk.
- Tart is fair-source: free for personal use, commercial use is gated. Check the
  [current terms](https://tart.run/licensing/) before using it for work.

## Everyday use

```bash
ci-vm-up        # before opening a PR or shipping
ci-vm-down      # when done
```

`ci-vm-up` is the one to remember. With the VM down, jobs on
`[self-hosted, macOS]` **queue rather than fail**, and GitHub gives up on them
after about 24 hours. If any such job is a required PR check, a PR cannot go
green with the VM off — "start the VM when I need a runner" means starting it to
*open* a PR, not only to ship. Giving those jobs a `timeout-minutes` is worth
doing alongside, so a forgotten VM fails fast instead of hanging for a day.

Other useful states:

```bash
tart list                                  # is it running?
tart ip ci-runner                          # address for ad-hoc SSH
ssh -i ~/.ssh/ci-vm_ed25519 admin@$(tart ip ci-runner)
gh api "repos/$CI_VM_REPO/actions/runners" --jq '.runners[].name'
```

## Configuration

Every setting is a `CI_VM_*` variable with a default at the top of each script.
Override per-machine in `~/.config/ci-vm.conf`, which all four scripts source if
it exists, or via the environment for a one-off.

`CI_VM_REPO` has no default and must be set — this repo is public, so which
repo the runner attaches to is deliberately machine configuration rather than
something recorded here. `~/.config/ci-vm.conf` is not chezmoi-managed, so it
stays local:

```sh
# ~/.config/ci-vm.conf
CI_VM_REPO=owner/repo
CI_VM_CPU=8
CI_VM_MEMORY=16384
```

| Variable | Default | Notes |
| --- | --- | --- |
| `CI_VM_IMAGE` | `ghcr.io/cirruslabs/macos-sequoia-xcode:26.6` | Pins the Xcode version |
| `CI_VM_XCODE` | `26.6` | Asserted against the booted VM; build fails on mismatch |
| `CI_VM_NAME` | `ci-runner` | Tart VM name |
| `CI_VM_CPU` | `6` | Of 10 on an M5 Air |
| `CI_VM_MEMORY` | `12288` | MB |
| `CI_VM_DISK` | `250` | GB, sparse |
| `CI_VM_REPO` | *(none — required)* | Repo the runner registers against |
| `CI_VM_RUNNER_NAME` | `$CI_VM_NAME` | Name shown in GitHub's runner list |
| `CI_VM_USER` / `CI_VM_PASSWORD` | `admin` / `admin` | Cirrus image defaults |
| `CI_VM_KEY` | `~/.ssh/ci-vm_ed25519` | Generated on first build |
| `CI_VM_PATH` | Homebrew + system paths | Baked into the runner's `.path` |
| `CI_VM_BREW_PACKAGES` | `xcodegen fastlane` | Preinstalled into the guest |

## Picking an image tag

The tag pins Xcode, and a mismatch with what the workflows assume shows up as an
opaque build failure — so `ci-vm-build` refuses to continue when the booted VM's
`xcodebuild -version` doesn't equal `CI_VM_XCODE`.

Cirrus publishes each Xcode release against two macOS bases. Both carry the same
Xcode; only the host OS differs, and for `xcodebuild` the SDK comes from Xcode:

```bash
crane ls ghcr.io/cirruslabs/macos-sequoia-xcode
crane ls ghcr.io/cirruslabs/macos-tahoe-xcode
```

`macos-runner:tahoe` bundles many Xcode versions at once and needs a 520 GB
disk — too large for a laptop.

## How the runner survives reboots

`config.sh` registers the runner and `svc.sh install` writes a LaunchAgent with
`RunAtLoad`, so the runner starts whenever `admin` logs in. The Cirrus images
auto-login `admin`, so booting the VM is enough. Two details make this work that
are easy to get wrong by hand:

- **The agent must be loaded into the GUI session.** `svc.sh start` runs
  `launchctl load` in whatever session invokes it; over SSH that's a background
  session, and the agent dies with the connection. `ci-vm-build` instead uses
  `sudo launchctl asuser "$(id -u)" launchctl load -w …`, which targets the
  auto-logged-in Aqua session — the same domain the agent lands in on every
  later boot.
- **`.path` is pinned explicitly.** `config.sh` records whatever `PATH` it saw at
  registration time. Over SSH that can omit `/opt/homebrew/bin`, and the
  workflows call `brew install xcodegen` — so `ci-vm-build` overwrites `.path`
  with `CI_VM_PATH` afterwards.

## Why `ci-vm-up` doesn't just trust the API

GitHub keeps reporting a runner as `online` for up to a minute after its VM
stops. A `ci-vm-down; ci-vm-up` pair therefore reads that stale status and
returns success while the guest is still booting — observed in practice, with
`ci-vm-up` exiting successfully 0.4s after `tart run`.

So `ci-vm-up` gates on evidence the API cannot provide, in order:

1. `tart ip` returns an address,
2. the guest answers on port 22 — it has actually booted,
3. `launchctl` in the guest's GUI session shows a live pid for the runner
   agent — it is alive in *this* boot,
4. only then, the API reports `online`.

A warm cycle takes about ten seconds end to end; the first boot after
provisioning takes closer to 75.

## Labels

GitHub adds `self-hosted`, `macOS` and `ARM64` automatically, which is what a
`runs-on: [self-hosted, macOS]` job already asks for — so workflows written
against the old host runner need no changes.

## Signing and secrets

Nothing sensitive is baked into the VM, and nothing should be. Jobs that need
signing material are expected to bring it themselves at run time and dispose of
it afterwards, so the VM holds no credentials, needs no manual keychain setup,
and can be destroyed and rebuilt without losing anything irrecoverable.

## Troubleshooting

**Runner won't come online after `ci-vm-up`.** The VM is up; the LaunchAgent is
the suspect. Check its log inside the guest:

```bash
ssh -i ~/.ssh/ci-vm_ed25519 admin@$(tart ip ci-runner) \
  'tail -50 ~/Library/Logs/actions.runner.*/stderr.log'
```

**`ci-vm-down` refuses to stop.** A job is running. Wait, or `--force` and
accept that GitHub reports the job as lost rather than failed.

**Builds fail with `brew: command not found`.** `.path` in the guest's
`actions-runner/` has drifted. Re-run `ci-vm-build`; it rewrites the file every
time.

**Disk fills up.** The VM keeps DerivedData between jobs by design. Clear it in
the guest, or raise `CI_VM_DISK` and re-run `ci-vm-build` — it grows the APFS
container to match.

**Starting over.** `ci-vm-destroy` then `ci-vm-build`. Deregistration goes
through the API rather than `config.sh remove`, so it works even if the VM no
longer boots.
