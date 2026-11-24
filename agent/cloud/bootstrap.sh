#!/bin/sh
# bootstrap.sh — install this repo's agent toolkit into a cloud sandbox.
#
# The one line a Claude Code cloud environment's setup script holds, so that
# everything of substance stays here, versioned, instead of being pasted into a
# vendor configuration field (ADR-0016, principle 5):
#
#   sh bootstrap.sh <REF> [--profile <name>] [--with-X | --no-X ...]
#
# --profile names the composed context profile, defaulting to
# claude-cloud-sandbox, and is the only argument most environments need. It
# selects the AGENTS.md/CLAUDE.md to install AND, through the rules below the
# argument loop, which capabilities come with it. The environment declares
# which harness it is rather than this script sniffing for one: ADR-0018
# principle 1 puts surface differences in the delivery, and the caller is the
# only party that knows the answer without guessing.
#
# What each profile resolves to today:
#
#                          gcloud  pre-commit  hooks  gh  devknowledge
#   claude-cloud-sandbox     yes       yes      yes   no      yes
#   codex-cloud-sandbox      yes       yes      no    no      no
#   *-workstation            no        no       no    no      no
#
# Every capability takes --with-X to force it on and --no-X to force it off,
# and either beats the profile wherever it sits on the line. The capabilities:
#
# --with-gcloud installs the Google Cloud SDK, a ~96 MB download. On by default
# for a sandbox; --no-gcloud for an environment that does no GCP work.
#
# --with-precommit installs the pre-commit framework and the binaries this
# estate's hooks need, and points git at a global hook so every repo in the
# container is covered. Its binaries come from pinned GitHub releases and its
# tools from PyPI and npm, so --no-precommit is the escape for an environment
# that cannot reach those. It then WARMS the hook cache from cloud/precommit-warm.yaml
# and from any checkout it finds, because the alternative is the first commit in
# a fresh container building every hook environment inside a 120 s hook
# timeout (#441). The warm is its own capability, so `degraded=` can say which
# of the two failed.
#
# --with-hooks wires this estate's PreToolUse guards and PostToolUse terraform
# hooks into ~/.claude/settings.json. Separate from --with-precommit because
# they are different mechanisms: a git hook blocks the commit, a harness hook
# returns the failure into the agent's context where it can act on it. Claude
# profiles only -- Codex does not read that file.
#
# --with-gh installs the GitHub CLI from a pinned release tarball, for the
# session skills' gather scripts. NOT for Anthropic-hosted web sandboxes:
# there the egress proxy authenticates gh for identity endpoints only and
# 403s every repo-scoped API path, so the gather sections come back
# gh-unauthorized rather than populated — measured 2026-08-19, lane map on
# #257, cleanup on #273. Off for every profile; the flag exists for surfaces
# whose egress genuinely reaches the GitHub API, e.g. self-hosted environments.
#
# --with-terraform installs terraform, tflint and checkov, so a repo whose
# .pre-commit-config.yaml calls the Terraform hooks can actually run them. On
# by default for a sandbox, like pre-commit; --no-terraform is the refund for
# an environment that does no Terraform work and wants the download back.
# This buys coverage, not the ability to push: their absence no longer blocks
# anything, since precommit-claude-hook reports a hook whose binary is missing
# as not checked rather than failed (#335). Installed inside --with-precommit,
# since serving that config is the whole reason they are here:
# --with-terraform --no-precommit installs nothing.
#
# --with-devknowledge registers Google's Developer Knowledge MCP server
# (google-developer-knowledge) at user scope in ~/.claude.json, with NO auth
# header. The key is not the bootstrap's to supply: it comes from the
# environment's API credential (host developerknowledge.googleapis.com, header
# X-Goog-Api-Key), which the agent proxy attaches outside the VM. On by default
# for claude-cloud-sandbox, which makes that credential part of what the
# profile expects: an environment on this profile without it gets three tools
# that 401 on every call, and should pass --no-devknowledge (#439). Claude
# profiles only -- Codex does not read ~/.claude.json.
#
# --prefix DIR puts every binary this script installs under DIR: commands in
# DIR/bin, the gcloud SDK in DIR/opt. Without it the choice is made once, by
# the install-location block below the argument loop: /usr/local/bin and /opt
# where both are writable (a root sandbox, so a root run lands where it always
# did), otherwise $HOME/.local. An unprivileged runner whose $HOME may not
# survive into the agent phase -- Codex Cloud's, see cloud/README.md -- passes
# a directory that does. Policy, skills and the ~/.claude/bin session scripts
# stay under $HOME whatever the prefix: the harness and the skills address
# them by that path, so moving them would make them invisible rather than
# durable. Nothing here edits PATH for the caller; a bin dir that is not on it
# is logged loudly and recorded in the manifest.
#
# <REF> is what everything else is fetched from. It is resolved to one commit at
# the start and every file comes from that commit; a branch or tag run whose own
# copy differs from that commit's hands over to the commit's copy once, so a run
# cannot straddle two versions (#610). Pin it
# to a tag or commit in anything durable — a branch means
# any compromise of this repo reaches every sandbox that starts afterwards.
#
# WHERE IT IS FETCHED FROM: the published copy, not the repo this file is
# written in. The source is private; a publish job copies home/, profiles/,
# cloud/ and adrs/ into the public repository under agent/, in commits of its
# own (ADR-0028). So <REF> names a ref or commit of the PUBLIC repository. A
# source commit does not exist there, and passing one as a pin is refused
# rather than left to fail as a string of 404s.
#
#   BOOTSTRAP_SOURCE_REPO     owner/name on github.com, default
#                             pmgledhill102/dotfiles
#   BOOTSTRAP_SOURCE_PREFIX   the directory in it that holds home/, profiles/
#                             and cloud/, default agent; empty for the root
#
# --source-repo=<owner/name> and --source-prefix=<dir> say the same and win
# over the environment. <REF> then names a ref or commit of THAT repository.
#
# A run with a non-default source first checks that the copy of this script
# held by that source understands these settings (see source_aware), because
# the run may hand over to it. One that does not would ignore them, install
# from its own default and report success, so the run stops instead. The
# deferred toolchain run is handed the settings as flags, because it starts
# from a session that does not have the setup script's environment.
#
# HOW THIS SCRIPT FAILS: hard on the toolkit, visibly on capabilities.
#
# It used to fail loudly at the first problem of any kind, on the reasoning that
# a half-installed toolkit is worse than none. That is still true of the
# toolkit, and Tier 1 below still aborts the run. It was never true of the
# toolchains -- a container with skills, policy and hooks but no checkov is a
# working container missing one gate, and killing the run over it threw away
# everything of value to protect something of much less (#346).
#
# So Tier 2 records what it could not install and carries on, and the manifest
# says `status=degraded` with the names. Nothing is swallowed: #335 made a
# missing binary report as NOT CHECKED rather than passed, so lost coverage
# shows up downstream as unverified work rather than false green.
#
# A cloud setup script, which fails the whole session on a non-zero exit,
# should still end with `exit 0`.
#
# What it should NOT carry is a shebang. A vendor setup-script field is pasted
# into a generated script beneath a header of the harness's own, so the line is
# never line 1 and never selects an interpreter -- and a `#!` that loses its `#`
# somewhere in that journey becomes a command, exiting 127 before this script is
# even fetched. cloud/README.md carries the working snippet.
#
# It installs no credentials and reads none. What it places is public content
# from a public repo.

set -eu

log() { echo "[bootstrap] $*"; }

# --- timing -------------------------------------------------------------------
#
# The setup script runs BEFORE the agent launches, so no hook and no telemetry
# signal covers this phase: the bootstrap is the only thing that can measure the
# bootstrap. Without it, nobody can say whether a run crept from 5s to 25s over
# three months, and there is no history to bisect against (#324, #430).
#
# Second resolution, because `date +%s` is POSIX while `%N` is a GNU extension
# absent from the BSD userland this estate also targets. Phases here run in
# seconds to minutes, so a second is resolution enough to catch a regression.
#
# Assignments only, never a bare `$(( ))` as a command: it exits 1 when the
# result is 0, and `set -e` reads that as a failure.
now_s() { date +%s 2>/dev/null || echo 0; }
BOOT_START=$(now_s)
TIMINGS=

record_timing() { # name seconds
  TIMINGS="${TIMINGS:+$TIMINGS }$1=$2s"
}

# Per-tool timing inside a capability. A capability runs in a subshell, so
# record_timing there would be lost with it; these append to a file instead,
# and capability() folds the file into TIMINGS after its own entry. step_end
# records the time since the previous step_begin or step_end and restarts the
# clock, so consecutive tools need one call each.
step_begin() {
  STEP_T0=$(now_s)
  PIP_ATTEMPT=
  STEP_ROUTE=
}
step_end() { # step_end <name>
  _step_secs=$(($(now_s) - STEP_T0))
  # STEP_SUFFIX is `.retry` during precommit_retry, so a second attempt is
  # timed under its own name and does not repeat the first one's key.
  echo "$1${STEP_SUFFIX:-}=${_step_secs}s" >>"$TMP/step-timings"
  # Which pip attempt succeeded: 2 and 3 each re-resolve the whole
  # dependency set after the one before failed, so a high number is time
  # spent on fallbacks rather than on the tool.
  if [ -n "${PIP_ATTEMPT:-}" ]; then
    echo "$1.pip-attempt=$PIP_ATTEMPT" >>"$TMP/step-timings"
  fi
  # Which install route a step took, where it has more than one (semgrep:
  # uv, pip, prefix, or present when nothing was installed).
  if [ -n "${STEP_ROUTE:-}" ]; then
    echo "$1.route=$STEP_ROUTE" >>"$TMP/step-timings"
  fi
  log "time    : $1 ${_step_secs}s"
  step_begin
}

# Which session this run built for, so a later one can tell a cache rebuild from
# a snapshot restore EXACTLY rather than inferring it from clock arithmetic: if
# this id matches the session asking, the setup script ran for that session.
#
# The variable is known to be set in the agent phase. Whether the setup phase
# sees it is unverified, so an absent value is recorded as `unknown` and the
# reader falls back to a time delta, saying which method it used. The first
# rebuild carrying this line settles the question for good.
BOOTSTRAP_SESSION="${CLAUDE_CODE_REMOTE_SESSION_ID:-unknown}"

# FAILED_STEP is what the exit trap reports. `die` is the only place that can
# name the step in words, so it records one on the way past; a `set -e` death
# that never reaches `die` leaves it empty and the trap says so rather than
# inventing a cause.
FAILED_STEP=

# FAIL_FILE is how a reason escapes a Tier 2 capability, which runs in a
# subshell where an assignment to FAILED_STEP dies with the subshell. Empty
# until TMP exists; every Tier 2 capability runs long after that, and a Tier 1
# die is in this process and reads the variable directly.
FAIL_FILE=

die() {
  FAILED_STEP="$*"
  if [ -n "$FAIL_FILE" ]; then echo "$*" >"$FAIL_FILE" 2>/dev/null || true; fi
  echo "[bootstrap] error: $*" >&2
  exit 1
}

# Where the caller's setup script tees this run's output. cloud/README.md's
# snippet uses /tmp/bootstrap.log; an environment that puts it elsewhere can
# say so, because the path is quoted into the failure report and a wrong one
# sends a reader looking for a file that is not there.
BOOTSTRAP_LOG="${BOOTSTRAP_LOG:-/tmp/bootstrap.log}"

BANNER_START="<!-- acc:bootstrap-failed:start -->"
BANNER_END="<!-- acc:bootstrap-failed:end -->"

strip_banner() {
  # Drop a banner left by an earlier failed run, so repeated failures do not
  # stack. Success needs no equivalent: both policy files are overwritten
  # wholesale by a run that gets that far, which takes the banner with them.
  sed "/^${BANNER_START}\$/,/^${BANNER_END}\$/d" "$1"
}

# --- record_failure: leave something a session can actually find --------------
#
# The manifest is written at the very end of a successful run, so before this
# existed a run that died partway left no artefact at all -- and the setup
# script's `exit 0` (correct: a non-zero setup script fails the whole session)
# meant the container came up looking clean with half a toolkit in it. The log
# said so loudly and nothing read the log (#345).
#
# Two artefacts, because they cover different failures. The manifest is the
# structured one, and start-session reads it -- but start-session is itself
# installed near the end, so an early failure leaves nothing able to report the
# manifest. Hence the banner in the policy files, which are read unconditionally
# and by whatever is running (see the CLAUDE.md note further down): it is the
# only channel that survives a failure early enough to take the reporting skill
# out with it.
#
# Every step here is best-effort. This runs while the script is already failing,
# and a trap that dies on its own mkdir replaces a diagnosable failure with a
# confusing one.
record_failure() {
  _rc="$1"
  _step="${FAILED_STEP:-unknown - exited without reaching a die}"
  _when=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)

  _agents="${AGENTS_DIR:-$HOME/.agents}"
  mkdir -p "$_agents" 2>/dev/null || return 0

  # The deferred toolchain run reports into its own manifest and state file.
  # The setup run's manifest and the policy file describe a toolkit that did
  # install, so a toolchain failure must not overwrite them with a banner.
  if [ "${TOOLCHAIN:-}" = run ]; then
    mkdir -p "$_agents/toolchain" 2>/dev/null || return 0
    {
      echo "status=failed"
      echo "exit_code=$_rc"
      echo "failed_step=$_step"
      echo "failed_at=$_when"
      echo "ref=$REF"
      echo "log=$_agents/toolchain/install.log"
    } >"$_agents/toolchain/manifest" 2>/dev/null || true
    # tmp then mv: toolchain-start reads this file while the run is going, and
    # a plain `>` gives a reader an empty file between truncate and write.
    { echo failed >"$_agents/toolchain/state.tmp" \
      && mv -f "$_agents/toolchain/state.tmp" "$_agents/toolchain/state"; } 2>/dev/null || true
    if [ -x "${BIN_DIR:-/nonexistent}/agent-telemetry" ]; then
      "$BIN_DIR/agent-telemetry" record toolchain "$_agents/toolchain/manifest" >/dev/null 2>&1 || true
    fi
    return 0
  fi

  {
    echo "status=failed"
    echo "exit_code=$_rc"
    echo "failed_step=$_step"
    echo "failed_at=$_when"
    echo "ref=$REF"
    # As in the finished manifest: which repository the run was installing
    # from, so a failure from a moved source does not read as the default's.
    echo "source=$SOURCE_REPO"
    echo "source_prefix=$SOURCE_PREFIX"
    echo "profile=$PROFILE"
    echo "log=$BOOTSTRAP_LOG"
  } >"$_agents/.bootstrap-manifest" 2>/dev/null || true
  # Spooled too, if the helper got installed before the failure: a bootstrap
  # that died is the run most worth seeing.
  if [ -x "${BIN_DIR:-/nonexistent}/agent-telemetry" ]; then
    "$BIN_DIR/agent-telemetry" record bootstrap "$_agents/.bootstrap-manifest" >/dev/null 2>&1 || true
  fi

  # The one policy file this profile's agent reads: a banner anywhere else is
  # one nothing ever overwrites, or one nobody reads.
  case "$PROFILE" in
    claude-*) _targets="${CLAUDE_DIR:-$HOME/.claude}/CLAUDE.md" ;;
    *) _targets="$_agents/AGENTS.md" ;;
  esac

  for _t in $_targets; do
    mkdir -p "$(dirname "$_t")" 2>/dev/null || continue
    {
      echo "$BANNER_START"
      echo "# This container's toolkit is incomplete"
      echo
      echo "\`cloud/bootstrap.sh\` exited $_rc before it finished, so an unknown"
      echo "number of the skills, helper scripts, hooks and policy that normally"
      echo "arrive with this file were never installed."
      echo
      echo "- failed step: $_step"
      echo "- ref: $REF, profile: $PROFILE, at: $_when"
      echo "- full log: $BOOTSTRAP_LOG"
      echo
      echo "Do not read a missing skill, command or helper as \"this machine does"
      echo "not do that\" — check the log before concluding anything about what is"
      echo "available. Say so before starting work that depends on the toolkit."
      echo "Re-running the bootstrap fixes it and needs no restart, but it is the"
      echo "human's call: never re-run it unasked."
      echo "$BANNER_END"
      echo
    } >"$_t.bootstrap-tmp" 2>/dev/null || continue
    if [ -f "$_t" ]; then
      strip_banner "$_t" >>"$_t.bootstrap-tmp" 2>/dev/null || true
    fi
    mv "$_t.bootstrap-tmp" "$_t" 2>/dev/null || true
  done
  return 0
}

# The arguments as given, quoted for eval, so the self-check below can replay
# them into a fresh copy of this script after the loop has shifted them away.
ORIG_ARGS=
for _a in "$@"; do
  _q=$(printf '%s' "$_a" | sed "s/'/'\\\\''/g")
  ORIG_ARGS="$ORIG_ARGS '$_q'"
done

# The ref is positional and first. A leading flag is left for the argument loop
# rather than taken as the ref, so omitting the ref reports the real problem.
REF=main
case "${1:-}" in
  "") ;;
  -*) ;;
  *)
    REF="$1"
    shift
    ;;
esac
# Empty means "the caller did not say", which is distinct from --no-X. The
# profile fills in only the ones still empty, so a flag wins wherever it
# appears on the line -- including before the --profile it contradicts.
WITH_GCLOUD=
WITH_PRECOMMIT=
WITH_HOOKS=
WITH_GH=
WITH_TERRAFORM=
WITH_DEVKNOWLEDGE=
PROFILE=claude-cloud-sandbox
PREFIX=
# `-` rather than `:-` for the prefix: empty is a value (the repository root),
# and only unset takes the default.
DEFAULT_SOURCE_REPO=pmgledhill102/dotfiles
DEFAULT_SOURCE_PREFIX=agent
SOURCE_REPO=${BOOTSTRAP_SOURCE_REPO:-$DEFAULT_SOURCE_REPO}
SOURCE_PREFIX=${BOOTSTRAP_SOURCE_PREFIX-$DEFAULT_SOURCE_PREFIX}
# When the pre-commit toolchain installs (ADR-0021, 2026-11-10 amendment):
#   eager       in this run, before the first prompt
#   background  defer it: this run installs the git hook and leaves a copy of
#               itself for toolchain-start, which a SessionStart hook runs
#   run         internal: the deferred run itself, started by toolchain-start
# Unset, it follows the profile: see def_toolchain below.
TOOLCHAIN=

# The trap goes on before anything that can fail, which is why TMP is declared
# empty here and filled in much further down: an exit trap installed after the
# first `die` does not cover it. Both gaps that existed were real -- the arg
# loop immediately below, and `curl is required` -- so this sits above the
# earliest `die` in the file rather than next to the mktemp it also cleans up.
# Everything record_failure reads (REF, PROFILE, SOURCE_REPO, SOURCE_PREFIX,
# BOOTSTRAP_LOG) is defaulted by
# this point, so a usage error reports against the defaults rather than dying
# inside the handler.
TMP=
on_exit() {
  _rc=$?
  [ -n "$TMP" ] && rm -rf "$TMP"
  if [ "$_rc" -ne 0 ]; then
    record_failure "$_rc" || true
  fi
  return 0
}
# EXIT alone does not fire on a signal in every POSIX shell, so INT and TERM
# re-exit rather than being trapped directly -- one handler, one code path.
trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

while [ $# -gt 0 ]; do
  case "$1" in
    --with-gcloud) WITH_GCLOUD=1 ;;
    --no-gcloud) WITH_GCLOUD=0 ;;
    --with-precommit) WITH_PRECOMMIT=1 ;;
    --no-precommit) WITH_PRECOMMIT=0 ;;
    --with-hooks) WITH_HOOKS=1 ;;
    --no-hooks) WITH_HOOKS=0 ;;
    --with-gh) WITH_GH=1 ;;
    --no-gh) WITH_GH=0 ;;
    --with-terraform) WITH_TERRAFORM=1 ;;
    --no-terraform) WITH_TERRAFORM=0 ;;
    --with-devknowledge) WITH_DEVKNOWLEDGE=1 ;;
    --no-devknowledge) WITH_DEVKNOWLEDGE=0 ;;
    --profile)
      shift
      [ $# -gt 0 ] || die "--profile needs a value"
      PROFILE="$1"
      ;;
    --profile=*) PROFILE="${1#--profile=}" ;;
    --prefix)
      shift
      [ $# -gt 0 ] || die "--prefix needs a value"
      PREFIX="$1"
      ;;
    --prefix=*) PREFIX="${1#--prefix=}" ;;
    --source-repo=*) SOURCE_REPO="${1#--source-repo=}" ;;
    --source-prefix=*) SOURCE_PREFIX="${1#--source-prefix=}" ;;
    --toolchain=*) TOOLCHAIN="${1#--toolchain=}" ;;
    *) die "unknown argument: $1" ;;
  esac
  shift
done
case "$TOOLCHAIN" in
  "" | eager | background | run) ;;
  *) die "--toolchain takes eager, background or run, not '$TOOLCHAIN'" ;;
esac
# Both values are pasted into URLs, so anything that is not a plain path is
# refused here rather than fetched.
case "$SOURCE_REPO" in
  *[!A-Za-z0-9._/-]* | */*/* | /* | */ | "") die "the source repo must be <owner>/<name>, got: '$SOURCE_REPO'" ;;
  */*) ;;
  *) die "the source repo must be <owner>/<name>, got: '$SOURCE_REPO'" ;;
esac
case "$SOURCE_PREFIX" in
  *[!A-Za-z0-9._/-]* | /* | */ | *..*) die "the source prefix must be a relative directory with no leading or trailing slash, got: '$SOURCE_PREFIX'" ;;
esac
# Whether the caller moved the source. Everything the override adds to a run
# (a log line, the check of the source's own copy for a ref, two deferred-run
# flags) is conditional on this.
SOURCE_OVERRIDDEN=
if [ "$SOURCE_REPO" != "$DEFAULT_SOURCE_REPO" ] || [ "$SOURCE_PREFIX" != "$DEFAULT_SOURCE_PREFIX" ]; then
  SOURCE_OVERRIDDEN=yes
fi

# source_aware <file>: does that copy of this script take the source settings?
# A copy from before they existed reads neither the variables nor the flags.
# It would fetch from its own default, write that repository's sha into the
# manifest and exit 0. The test is the flag's own case label, which a copy
# cannot have without parsing the flag.
source_aware() {
  grep -q -e '^ *--source-repo=\*)' "$1" 2>/dev/null \
    && grep -q -e '^ *--source-prefix=\*)' "$1" 2>/dev/null
}
require_source_aware() {
  source_aware "$1" && return 0
  rm -f "$1"
  die "the bootstrap.sh that $SOURCE_REPO holds at $REF${SOURCE_PREFIX:+ under $SOURCE_PREFIX/} does not support --source-repo / --source-prefix. This run would hand over to it, and it would ignore the source set here, install from its own default and report success. Nothing was installed. Publish a bootstrap.sh that supports the source settings to $SOURCE_REPO, or give a REF that holds one"
}

# --- what the profile implies ------------------------------------------------
#
# The profile already states two facts, and the defaults are read off them
# rather than kept in a per-profile table that would need a row adding every
# time a profile is. A table of two columns and N rows says no more than the
# name does, and goes stale in a way the name cannot.
#
#   claude-*         -> hooks. ~/.claude/settings.json is a Claude mechanism;
#                      Codex does not read it. Installing the harness hooks
#                      alongside a Codex profile put four files in the
#                      container that nothing there consumes -- ADR-0016
#                      principle 3, provider-specific coupling belongs on
#                      provider-specific surfaces, applied to the installer.
#
#   *-cloud-sandbox  -> pre-commit, and gcloud. A sandbox is disposable and
#                      rebuilt from a script, so the argument for making a
#                      developer opt into enforcement does not apply: there is
#                      no laptop here whose setup someone is protecting. #254
#                      is what the absence cost.
#
# gh is the one capability with no sensible default. It is documented as
# actively counterproductive on Anthropic-hosted sandboxes, where the egress
# proxy 403s every repo-scoped path, so it stays off until a caller who knows
# their egress asks for it.
#
# gcloud on by default is a reversal, and worth naming as one. It used to be
# opt-in so that "the one line an environment carries declares what kind of
# environment it is" -- but the profile name declares that now, and better,
# so the flag was only restating what --profile already said. The 96 MB is the
# price; --no-gcloud is the refund for an environment that does no GCP work.
resolve() {
  # resolve <current> <default> -- echo the caller's answer, or the default
  if [ -n "$1" ]; then echo "$1"; else echo "$2"; fi
}

case "$PROFILE" in
  claude-*) def_hooks=1 ;;
  *) def_hooks=0 ;;
esac
case "$PROFILE" in
  *-cloud-sandbox)
    def_precommit=1
    def_gcloud=1
    def_terraform=1
    ;;
  *)
    def_precommit=0
    def_gcloud=0
    def_terraform=0
    ;;
esac

WITH_GCLOUD=$(resolve "$WITH_GCLOUD" "$def_gcloud")
WITH_PRECOMMIT=$(resolve "$WITH_PRECOMMIT" "$def_precommit")
WITH_HOOKS=$(resolve "$WITH_HOOKS" "$def_hooks")
WITH_GH=$(resolve "$WITH_GH" 0)
# terraform/tflint/checkov follow pre-commit: on for a sandbox, off elsewhere.
# Same argument as --with-precommit above -- a sandbox is disposable and rebuilt
# from a script, so there is no laptop here whose setup someone is protecting,
# and a gate that is present is worth more than a download that is avoided.
# --no-terraform is the refund for an environment that does no Terraform work.
#
# The download is the real cost and it is why this is a per-profile default
# rather than unconditional. What it is NOT is a way to unblock pushes:
# precommit-claude-hook reports a hook whose binary is missing as not checked
# rather than failed (#335), so a container without these tools pushes fine.
# Before that fix "off" meant every push needed --no-verify, which made
# installing them look mandatory for the wrong reason.
WITH_TERRAFORM=$(resolve "$WITH_TERRAFORM" "$def_terraform")

# Background for the Claude cloud sandbox, whose SessionStart hook starts the
# deferred run and whose agent phase has the network to finish it. Eager
# everywhere else: Codex's agent phase is offline, so a deferred download
# there could never finish (docs/cloud-sandbox-design.md section 5).
# --toolchain=eager is the refund.
case "$PROFILE" in
  claude-cloud-sandbox) def_toolchain=background ;;
  *) def_toolchain=eager ;;
esac
TOOLCHAIN=$(resolve "$TOOLCHAIN" "$def_toolchain")

# Developer Knowledge is on for claude-cloud-sandbox. Whether it works is a
# property of the environment's API credentials, which nothing here can check:
# setup-script requests never get a credential attached, so a probe at this
# point would fail even where the credential exists. The default is therefore
# a statement about what an environment on this profile is expected to hold,
# and --no-devknowledge is the refund for one that holds no credential. On a
# non-Claude profile the flag is refused rather than honoured, because the
# file it edits is Claude Code's.
case "$PROFILE" in
  claude-cloud-sandbox) def_devknowledge=1 ;;
  *) def_devknowledge=0 ;;
esac
WITH_DEVKNOWLEDGE=$(resolve "$WITH_DEVKNOWLEDGE" "$def_devknowledge")
case "$PROFILE" in
  claude-*) ;;
  *)
    if [ "$WITH_DEVKNOWLEDGE" -eq 1 ]; then
      log "WARN    : --with-devknowledge ignored: $PROFILE is not a Claude profile"
      WITH_DEVKNOWLEDGE=0
    fi
    ;;
esac

# --- where binaries go: decided once, used by both tiers ------------------
#
# Three outcomes, and every install below reads BIN_DIR and OPT_DIR rather
# than naming a path, so the toolkit helper and the Tier 2 toolchains cannot
# disagree about where they went:
#
#   --prefix DIR        DIR/bin and DIR/opt, as root or not. Explicit wins.
#   system (writable)   /usr/local/bin and /opt -- a root sandbox, unchanged.
#   user (otherwise)    $HOME/.local/bin and $HOME/.local/opt.
#
# Both system paths must be writable for the system layout, because gcloud
# needs the one and its wrapper the other; half of each would leave the SDK
# and its wrapper in different trees. `opt` under the prefix mirrors /opt, so
# the SDK path is the same shape either way and stays out of the XDG data dir
# that uv and pip use.
#
# INSTALL_MODE distinguishes system from the other two because the system
# layout keeps each tool's own default install route (a global npm, uv's
# default tool dir) exactly as before, where a prefix has to steer every
# one of them explicitly.
SYSTEM_BIN=/usr/local/bin
SYSTEM_OPT=/opt
if [ -n "$PREFIX" ]; then
  case "$PREFIX" in
    /*) ;;
    *) die "--prefix needs an absolute path, got: $PREFIX" ;;
  esac
  PREFIX="${PREFIX%/}"
  INSTALL_MODE=prefix
elif [ -w "$SYSTEM_BIN" ] && [ -w "$SYSTEM_OPT" ]; then
  INSTALL_MODE=system
else
  INSTALL_MODE=user
  PREFIX="$HOME/.local"
fi
if [ "$INSTALL_MODE" = system ]; then
  BIN_DIR="$SYSTEM_BIN"
  OPT_DIR="$SYSTEM_OPT"
else
  BIN_DIR="$PREFIX/bin"
  OPT_DIR="$PREFIX/opt"
fi
mkdir -p "$BIN_DIR" || die "could not create $BIN_DIR"

# Is $HOME writable? Codex Cloud runs a task with $HOME and the root filesystem
# read-only (#575), and everything below that lives under ~/.claude or
# ~/.agents would otherwise die at its first mkdir, taking every later install
# with it. The probe makes and removes a directory rather than creating
# ~/.claude, so a read-only answer leaves nothing behind either way.
#
# When it is read-only, the session scripts, the matrix, the standards and the
# manifest relocate under the prefix, where this run can write and a later step
# can still find them. The policy and the skills do NOT: nothing on that
# surface reads them from the prefix, so installing them there would report a
# success that changes no agent's behaviour. They are skipped, and the manifest
# says so (`policy=not-installed`, status degraded) rather than the run dying
# or the gap being silent. Which channel replaces them is open in #575/#495.
HOME_RW=yes
mkdir -p "$HOME" 2>/dev/null || true
if _probe=$(mktemp -d "$HOME/.bootstrap-probe.XXXXXX" 2>/dev/null); then
  rmdir "$_probe" 2>/dev/null || true
else
  HOME_RW=no
fi
if [ "$HOME_RW" = yes ]; then
  CLAUDE_DIR="$HOME/.claude"
  AGENTS_DIR="$HOME/.agents"
else
  STATE_DIR="${PREFIX:-$OPT_DIR}/.agent-state"
  CLAUDE_DIR="$STATE_DIR/claude"
  AGENTS_DIR="$STATE_DIR/agents"
  mkdir -p "$CLAUDE_DIR" "$AGENTS_DIR" \
    || die "\$HOME is read-only and the state directory $STATE_DIR could not be created"
  # Both write to ~/.claude/settings.json and ~/.claude.json, which this run
  # cannot reach, so they are off rather than failing partway.
  WITH_HOOKS=0
  WITH_DEVKNOWLEDGE=0
  log "home    : $HOME is read-only -- state, manifest and session scripts go to $STATE_DIR"
fi

# The caller's PATH is read before this script touches it: whether the bin dir
# is on it is a fact about the environment a session will inherit, and it is
# the one thing here that cannot fix it -- a setup script's exports do not
# reach the agent phase on every surface. So the gap is logged and recorded,
# and this process alone gets the bin dir prepended, which is what lets every
# `command -v` check below see what the run itself installed.
case ":$PATH:" in
  *":$BIN_DIR:"*) BIN_ON_PATH=yes ;;
  *)
    BIN_ON_PATH=no
    PATH="$BIN_DIR:$PATH"
    export PATH
    ;;
esac

# Resolve REF to one commit now, and fetch everything from that commit. A branch
# URL on the raw CDN can lag a merge by minutes, and a run that reads some files
# before the lag clears and some after straddles two versions (#610).
#
# `git ls-remote` rather than the GitHub API: no token, no JSON parsing, and git
# is already required to be here. A REF that is already a commit SHA will not
# match a ref name, which is not a failure -- it is a pin, and pinned is the
# recommended state. Recorded in the manifest as `pin` so a reader can tell
# "pinned" from "could not resolve". An annotated tag lists its tag object and,
# on a `^{}` line, the commit it points at; only the commit is addressable under
# raw.githubusercontent, so that line wins when present.
#
# Resolved against SOURCE_REPO, the repository the files are fetched from. A
# published copy's commits have different shas from this repo's, so no other
# repository can answer what REF means there.
resolved=$(git ls-remote "https://github.com/$SOURCE_REPO" "$REF" "$REF^{}" 2>/dev/null \
  | awk '{ if ($2 ~ /\^\{\}$/) peeled = $1; else if (first == "") first = $1 }
         END { print (peeled != "" ? peeled : first) }')
if [ -z "$resolved" ]; then
  case "$REF" in
    [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*)
      resolved="$REF"
      kind=pin
      ;;
    *)
      resolved="unresolved"
      kind=unresolved
      ;;
  esac
else
  kind=ref
fi

# An unresolved ref keeps today's behaviour and fetches by name. A harness may
# preset RAW to serve the files from disk; a preset RAW is the directory that
# holds home/, profiles/ and cloud/, so the prefix is not added to it.
_at=$resolved
[ "$kind" != unresolved ] || _at=$REF
RAW="${RAW:-https://raw.githubusercontent.com/$SOURCE_REPO/$_at${SOURCE_PREFIX:+/$SOURCE_PREFIX}}"

command -v curl >/dev/null 2>&1 || die "curl is required"

TMP=$(mktemp -d)
FAIL_FILE="$TMP/fail-reason"

# --- fetch: every download in this script goes through here ---------------
#
# A bare `curl -sSfL` is a single attempt. This script makes roughly a dozen
# of them across three hosts, so a run's success is the product of a dozen
# independent chances of a transient blip -- and a blip here fails the whole
# session, not just the fetch. Retries turn a class of failures that used to
# need a human back into a two-second pause.
#
# --retry-connrefused and --retry-all-errors are what make it cover the cases
# that actually happen: without them curl retries transient *transport*
# errors only, and a proxy answering 502 while it warms up is not one.
# --connect-timeout bounds a black-holed connection (no RST, no response),
# which otherwise hangs until the harness's own setup timeout kills the run
# with far less to go on than a curl error. --speed-limit/--speed-time bound
# the other stall -- a connection that opens, dribbles, and never finishes --
# without the collateral damage a tight --max-time would do to the gcloud
# tarball, which is 96 MB and legitimately slow on a bad link.
#
# --retry-all-errors landed in curl 7.71 (--retry-connrefused in 7.52); the
# sandbox image ships 8.5.0. An older curl rejects an unknown option rather
# than ignoring it, which would fail every fetch, so probe for the newer of
# the two and drop both if it is absent. `--help all` is itself 7.73+, so an
# older curl fails the probe and takes the fallback -- which is the answer
# wanted in that case anyway.
CURL_RETRY_OPTS='--retry 3 --retry-delay 2 --retry-connrefused --retry-all-errors'
if ! curl --help all 2>/dev/null | grep -q -- --retry-all-errors; then
  CURL_RETRY_OPTS='--retry 3 --retry-delay 2'
fi

fetch() {
  # fetch <url> <dest>
  # shellcheck disable=SC2086  # CURL_RETRY_OPTS is a deliberate word list
  curl -sSfL $CURL_RETRY_OPTS \
    --connect-timeout 15 --speed-limit 1024 --speed-time 30 --max-time 600 \
    "$1" -o "$2"
}

sha256_is() {
  # sha256_is <file> <hex digest>: GNU sha256sum, else BSD/perl shasum.
  _sum=$(sha256sum "$1" 2>/dev/null || shasum -a 256 "$1" 2>/dev/null) || return 1
  [ "${_sum%% *}" = "$2" ]
}

# --- self-check: is this the script the ref resolves to? -------------------
#
# Fetching everything else by sha does not help if the copy that is running was
# itself fetched from a lagging branch URL. Compare it with the sha-addressed
# copy and, if they differ, hand over to that one with the original arguments.
# Only a branch or tag can be stale: a pin is already exact, and an unresolved
# ref has nothing to compare against. BOOTSTRAP_REEXEC is the guard that stops a
# second hand-over; it holds the fetched copy's path so the new run removes it.
# A fetch failure here is logged and skipped -- the run still has its own copy.
case "${BOOTSTRAP_REEXEC:-}" in
  /*) rm -f "$BOOTSTRAP_REEXEC" 2>/dev/null || true ;;
esac

# With the source moved, look at the copy of this script that the source holds
# at this commit before anything is installed. Two later steps run that copy,
# not this one: the hand-over just below, and the deferred toolchain run, which
# saves it for a session to start. Checking once here, at the top level, makes
# a copy that cannot honour the source a failed run. Inside a capability the
# same finding would only degrade it, and the run would still exit 0.
#
# The same fetch settles a pin, which the resolution above takes on trust: any
# hex string that names no ref. A commit of the private source looks exactly
# like one and exists nowhere in the published repository, so a pin is checked
# whatever the source.
#
# The deferred run itself is skipped: it is the copy that was checked.
if { [ -n "$SOURCE_OVERRIDDEN" ] || [ "$kind" = pin ]; } && [ "$TOOLCHAIN" != run ]; then
  _probe=$(mktemp)
  if ! fetch "$RAW/cloud/bootstrap.sh" "$_probe" 2>/dev/null; then
    rm -f "$_probe"
    [ "$kind" != pin ] \
      || die "$REF is not a commit of $SOURCE_REPO with ${SOURCE_PREFIX:+$SOURCE_PREFIX/}cloud/bootstrap.sh in it -- a pin must be a commit of the repository the run fetches from"
    die "could not fetch ${SOURCE_PREFIX:+$SOURCE_PREFIX/}cloud/bootstrap.sh from $SOURCE_REPO at $REF, so nothing was installed"
  fi
  require_source_aware "$_probe"
  rm -f "$_probe"
fi
if [ "$kind" = ref ] && [ -z "${BOOTSTRAP_REEXEC:-}" ] && [ -f "$0" ]; then
  _fresh=$(mktemp)
  if fetch "$RAW/cloud/bootstrap.sh" "$_fresh" 2>/dev/null; then
    if ! cmp -s "$0" "$_fresh"; then
      log "ref     : /tmp copy is stale for $REF; re-running $(echo "$resolved" | cut -c1-12)"
      BOOTSTRAP_REEXEC="$_fresh"
      export BOOTSTRAP_REEXEC
      rm -rf "$TMP"
      TMP=
      eval "set -- $ORIG_ARGS"
      exec sh "$_fresh" "$@"
    fi
  else
    log "ref     : could not fetch $REF to compare with this copy; carrying on"
  fi
  rm -f "$_fresh"
fi

# --- pip_install: PyPI, whatever this image calls pip ----------------------
#
# `pip` is not always on PATH where `pip3` is, and Ubuntu 24.04 ships a PEP 668
# EXTERNALLY-MANAGED marker that makes a system-wide install refuse outright.
# Refusing is right on a workstation and pointless in a container that exists
# for one session and is thrown away, so retry with --break-system-packages --
# a flag pip only grew in 23.0, hence the retry rather than passing it first.
#
# The third attempt is for a different failure that looks the same in a log.
# Where a package needs to UPGRADE a dependency that apt installed, pip cannot
# uninstall the old one -- a dpkg-installed distribution carries no RECORD file
# -- and gives up with "Cannot uninstall packaging 24.0, RECORD file not found".
# --break-system-packages does not help: that bypasses the PEP 668 marker, and
# this is a missing-metadata problem in the package being replaced. Only
# --ignore-installed clears it, by installing over the top rather than removing
# first. That is why it is last: it skips the satisfied-dependency check for the
# whole transaction, so a run that reaches it re-downloads more than it needs.
# checkov against the sandbox image's apt-managed `packaging` is the case that
# found this, and it took the whole bootstrap down with it (#344).
#
# The optional second argument is extra flags for every attempt, word-split:
# py_tool_install passes `--user` through it.
pip_install() {
  _pkg="$1"
  _extra="${2:-}"
  for _pip in "pip" "pip3" "python3 -m pip"; do
    command -v "${_pip%% *}" >/dev/null 2>&1 || continue
    PIP_ATTEMPT=$((${PIP_ATTEMPT:-0} + 1))
    # shellcheck disable=SC2086  # deliberate word split: "python3 -m pip"
    $_pip install --quiet --no-input $_extra "$_pkg" >/dev/null 2>&1 && return 0
    PIP_ATTEMPT=$((PIP_ATTEMPT + 1))
    # shellcheck disable=SC2086
    $_pip install --quiet --no-input $_extra --break-system-packages "$_pkg" \
      >/dev/null 2>&1 && return 0
    PIP_ATTEMPT=$((PIP_ATTEMPT + 1))
    # shellcheck disable=SC2086
    $_pip install --quiet --no-input $_extra --break-system-packages \
      --ignore-installed "$_pkg" >/dev/null 2>&1 && return 0
  done
  return 1
}

# --- py_tool_install: a Python CLI into BIN_DIR, off the system layout -------
#
# Only for a prefix or user install; the system layout keeps each tool's
# existing route. A system pip cannot write site-packages unprivileged, and
# `pip --prefix` puts the library where the system interpreter never looks, so
# the console script installs and then fails to import.
#
# uv solves all of that: a venv per tool under the prefix, the shim in
# BIN_DIR, and any Python it has to fetch kept under the prefix too, so an
# explicit prefix holds everything a tool needs to run. Without uv, `pip
# --user` is right only when the prefix IS the user base, $HOME/.local, which
# is where it puts both halves; for any other prefix it would land the tool
# outside it, so that case fails with a reason instead.
py_tool_install() {
  _pkg="$1"
  if command -v uv >/dev/null 2>&1; then
    UV_TOOL_DIR="$PREFIX/share/uv/tools" UV_TOOL_BIN_DIR="$BIN_DIR" \
      UV_PYTHON_INSTALL_DIR="$PREFIX/share/uv/python" \
      uv tool install "$_pkg" >/dev/null 2>&1
    return
  fi
  [ "$PREFIX" = "$HOME/.local" ] || {
    log "        $_pkg under $PREFIX needs uv, which is not on PATH"
    return 1
  }
  pip_install "$_pkg" --user
}

# checkov and pre-commit. In the system layout uv comes first when it is on
# PATH: pip resolves checkov's dependency tree in ~64s where uv takes ~10s on a
# cold cache, and a venv per tool never has to replace the image's apt-managed
# `packaging` (#344). The shim goes to BIN_DIR, where pip's console script
# went, so `command -v` finds the same path either way. pip remains the route
# when uv is absent or fails.
python_cli_install() {
  if [ "$INSTALL_MODE" != system ]; then
    py_tool_install "$1"
    return
  fi
  if command -v uv >/dev/null 2>&1; then
    UV_TOOL_BIN_DIR="$BIN_DIR" uv tool install "$1" >/dev/null 2>&1 && return 0
    log "        uv could not install $1; falling back to pip"
  fi
  pip_install "$1"
}

# --- npm_global_install: a node CLI whose shim must land in BIN_DIR ----------
#
# npm's own global prefix is wherever this image's node put it, and is not
# writable unprivileged. `--prefix` puts the package under PREFIX/lib and the
# shim in PREFIX/bin, which is BIN_DIR. The system layout keeps npm's default.
npm_global_install() {
  if [ "$INSTALL_MODE" = system ]; then
    npm install -g --silent "$1" >/dev/null 2>&1
  else
    npm install -g --silent --prefix "$PREFIX" "$1" >/dev/null 2>&1
  fi
}

log "installing from ${REF} at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
[ -z "$SOURCE_OVERRIDDEN" ] || log "source  : $SOURCE_REPO, under '${SOURCE_PREFIX:-<the repository root>}' (overridden)"

# Print the resolved set, not the flags. With defaults in play the command line
# no longer says what a run will do, and a container is read afterwards far more
# often than the setup script that built it.
on_off() { [ "$1" -eq 1 ] && echo "yes" || echo "no"; }
log "profile -> $PROFILE"
log "caps    :  gcloud=$(on_off "$WITH_GCLOUD") precommit=$(on_off "$WITH_PRECOMMIT") hooks=$(on_off "$WITH_HOOKS") gh=$(on_off "$WITH_GH") terraform=$(on_off "$WITH_TERRAFORM") devknowledge=$(on_off "$WITH_DEVKNOWLEDGE")"
log "bin     -> $BIN_DIR ($INSTALL_MODE)"
if [ "$BIN_ON_PATH" = no ]; then
  log "WARN    : $BIN_DIR is NOT on PATH. Everything this run installs as a"
  log "          command goes there, and this script cannot change the PATH a"
  log "          session inherits. Add it in the environment's own settings,"
  log "          or sessions will not find gcloud, terraform, pre-commit et al."
fi

# There is deliberately no apt step here.
#
# An earlier draft installed curl, ca-certificates and openssl defensively, on
# the reasoning that the documented list of pre-installed tools does not mention
# curl. That list summarises rather than enumerates, and the sandbox image
# carries curl 8.5.0 against OpenSSL 3.0.13 — verified, not inferred. A working
# TLS fetch of this script proves ca-certificates too, since it could not have
# arrived otherwise.
#
# openssl was speculative convenience: nothing here uses it. Installing packages
# on a guess costs an apt-get update on every cache rebuild, needs the Ubuntu
# archives reachable, and bakes an assumption into a snapshot where nobody will
# revisit it. A task that genuinely needs a package can install it, having
# established that it is missing.
#
# --with-precommit is not a reversal of that. The objection above is to
# installing on a *guess*; a hook declared in a repo's committed
# .pre-commit-config.yaml that cannot run without shellcheck is a demonstrated
# dependency. It stays behind a flag so the install is opted into rather than
# imposed on every environment.

# =============================================================================
# TIER 1 -- the toolkit. Runs first, and a failure here is fatal.
# =============================================================================
#
# Policy, skills, helper scripts and hooks: the config channel this script
# exists to be. Every section below is a curl from raw.githubusercontent plus a
# file write, which makes it both the most valuable work in the file and the
# least likely to fail -- so it goes first, ahead of anything that downloads a
# toolchain. It used to go last, behind a 96 MB SDK, apt, npm, pip and three
# release tarballs, and a checkov that could not install took the skills down
# with it (#344, #346).
#
# Fatal is right here in a way it is not for Tier 2. A container with no policy
# and no skills is not a degraded sandbox, it is a different machine, and an
# agent cannot discover from the inside that its instructions never arrived.

TIER1_START=$(now_s)

# --- the helper --------------------------------------------------------------
#
# Into BIN_DIR, chosen once above: /usr/local/bin in a sandbox running as root,
# so the helper is on PATH for every shell without touching a profile, and the
# prefix's bin otherwise.

fetch "$RAW/home/bin/gcp-credentials" "$TMP/gcp-credentials" \
  || die "could not fetch the helper from $REF"
# Refuse an error page rendered as a script. A 404 from a bad ref is HTML, and
# `sh` would run it and report something baffling.
head -1 "$TMP/gcp-credentials" | grep -q '^#!' \
  || die "fetched helper is not a script — check that $REF exists"

install -m 0755 "$TMP/gcp-credentials" "$BIN_DIR/gcp-credentials"
log "helper  -> $BIN_DIR/gcp-credentials"

# agent-telemetry, the same shape: spools session metadata locally and ships it
# to the telemetry ingest when TELEMETRY_INGEST_URL is set (ADR 026 in the
# private infrastructure repository). Tier 1 because it is what records THIS run -- the manifest below is
# handed to it -- and because it is inert until an environment configures an
# ingest: with no URL it only spools. It is installed for every profile; the
# Claude hooks that drive it are wired separately, under --with-hooks.
fetch "$RAW/home/bin/agent-telemetry" "$TMP/agent-telemetry" \
  || die "could not fetch the telemetry helper from $REF"
head -1 "$TMP/agent-telemetry" | grep -q '^#!' \
  || die "fetched telemetry helper is not a script — check that $REF exists"
install -m 0755 "$TMP/agent-telemetry" "$BIN_DIR/agent-telemetry"
log "helper  -> $BIN_DIR/agent-telemetry"
mkdir -p "$CLAUDE_DIR/bin"
ln -sf "$BIN_DIR/agent-telemetry" "$CLAUDE_DIR/bin/agent-telemetry"

# The skill still spells its invocations ~/.claude/bin/gcp-credentials, because
# that is where chezmoi puts the helper on a laptop. Nothing here creates that
# path, so an agent following the documented command would hit "no such file"
# next to a perfectly good helper on PATH — or worse, find a stale vendored copy
# there and run that instead. Symlink until the skill stops naming a path at
# all, which is the real fix and is the corollary in ADR-0016 principle 3:
# delivery assumptions do not belong in portable text.
mkdir -p "$CLAUDE_DIR/bin"
ln -sf "$BIN_DIR/gcp-credentials" "$CLAUDE_DIR/bin/gcp-credentials"
log "compat  -> $CLAUDE_DIR/bin/gcp-credentials -> $BIN_DIR/gcp-credentials"

# --- the skill: one file, vendor paths as adapters ----------------------------
#
# The canonical copy goes to ~/.agents/skills, the vendor-neutral Agent Skills
# location that Codex, OpenCode and Gemini CLI scan natively. Claude Code does
# not read it — its documentation names only ~/.claude/skills and
# .claude/skills — so ~/.claude/skills gets a symlink pointing at the real
# thing.
#
# That direction is deliberate. Copying into each vendor's directory would work
# and would reintroduce the one failure this repo keeps meeting: two copies of
# the same content, diverging quietly. A symlink cannot drift, and a fourth
# provider costs another link rather than another copy. It is also ADR-0016
# principle 3 in the filesystem — the portable path holds the content, the
# vendor path is a thin adapter — rather than a paragraph asserting it.
#
# That a container-created ~/.claude/skills is read at all is no longer an open
# question: a sandbox session on 2026-08-13 discovered this skill there and
# invoked it unprompted. What a symlinked skill directory does is the part still
# worth watching; if Claude stops listing the skill, that is why.

if [ "$HOME_RW" = yes ]; then
  fetch "$RAW/home/commands/gcp-credentials.md" "$TMP/gcp-credentials.md" \
    || die "could not fetch the skill from $REF"

  # SKILL.md wants frontmatter the command format does not carry. The first line
  # of the command file is its description by convention, so lift it — single
  # quoted, with any internal quote doubled, because that description contains a
  # colon and would otherwise be read as a YAML mapping.
  SKILL_DIR="$AGENTS_DIR/skills/gcp-credentials"
  mkdir -p "$SKILL_DIR"
  DESC=$(head -1 "$TMP/gcp-credentials.md" | sed "s/'/''/g")
  {
    echo "---"
    echo "name: gcp-credentials"
    echo "description: '${DESC}'"
    echo "---"
    echo ""
    tail -n +2 "$TMP/gcp-credentials.md"
  } >"$SKILL_DIR/SKILL.md"
  log "skill   -> $SKILL_DIR/SKILL.md (canonical)"

  # An earlier run left a real directory here, and `ln -s` onto one links *inside*
  # it rather than replacing it. Remove first; the path is fixed and ours.
  rm -rf "$CLAUDE_DIR/skills/gcp-credentials"
  mkdir -p "$CLAUDE_DIR/skills"
  ln -sfn "$SKILL_DIR" "$CLAUDE_DIR/skills/gcp-credentials"
  log "adapter -> $CLAUDE_DIR/skills/gcp-credentials"

  # Claude merged custom commands into skills: a commands/*.md and a
  # skills/*/SKILL.md both register the same /name and behave the same way. So an
  # earlier run's commands copy is now a second, Claude-only registration of a
  # skill that already works from the neutral path. Remove it rather than leave
  # two sources for one command.
  rm -f "$CLAUDE_DIR/commands/gcp-credentials.md"
else
  log "skip    : gcp-credentials skill not installed (home-read-only)"
fi

# --- the agent policy ---------------------------------------------------------
#
# Delivers the working policy to a surface chezmoi never reaches, so a session
# is not left running on whatever the opened repo happens to commit (#245).
#
# What lands here is a COMPOSED PROFILE, not the raw fragments. ADR-0018
# resolves surface differences at delivery: the sandbox profile is built from
# the portable core, the os-ubuntu and persist-ephemeral fragments, and the
# provider fragment, and it deliberately excludes persist-durable. That is what
# stops "run chezmoi apply" reaching a container with no chezmoi -- confidently
# wrong policy, which is worse than none. CI fails the build if a durable-machine
# fragment ever reaches a sandbox profile (ADR-0020), so this fetch does not
# have to check.
#
# The file is complete, with no @imports to resolve. That matters for Codex,
# which rejects @file templating: an import here would arrive as literal text
# and the content it named would be lost silently.

# One composed file per profile, placed where that profile's agent reads it.
#
# Claude profiles ship CLAUDE.md to ~/.claude/. A container-created
# ~/.claude/CLAUDE.md is read: verified 2026-08-18 by planting a marker
# mid-session and finding it in context on resume, announced as the user's
# global instructions. The cloud docs list user-scope CLAUDE.md as
# unavailable, but that is about your laptop's copy not being transferred,
# which is a different claim -- the same distinction ADR-0016 already
# established for ~/.claude/skills.
#
# Codex profiles ship AGENTS.md to ~/.agents/. Codex Cloud does not read it
# there: its home is a managed CODEX_HOME and $HOME is read-only inside a task
# (#495). Which channel replaces it is open in #575.
#
# Claude profiles used to ship a neutral AGENTS.md to ~/.agents/ as well. Nothing
# read it, and it carried no environment fragment (#310), so it is no longer
# composed, and a copy an older run left in a resumed container is removed.

if [ "$HOME_RW" = yes ]; then
  PROFILE_DIR="$AGENTS_DIR"
  mkdir -p "$PROFILE_DIR"

  case "$PROFILE" in
    claude-*) POLICY_FILE=CLAUDE.md POLICY_DEST="$CLAUDE_DIR/CLAUDE.md" ;;
    *) POLICY_FILE=AGENTS.md POLICY_DEST="$PROFILE_DIR/AGENTS.md" ;;
  esac

  fetch "$RAW/profiles/$PROFILE/$POLICY_FILE" "$TMP/$POLICY_FILE" \
    || die "could not fetch profile '$PROFILE' ($POLICY_FILE) from $REF — check the name against profiles/ in the repo"

  # Same 404-as-content guard as everything else here: a bad ref or a mistyped
  # profile can return an HTML error page with a 200 from some proxies, and
  # policy whose first line is <!DOCTYPE reads as a broken agent rather than a
  # broken fetch.
  head -1 "$TMP/$POLICY_FILE" | grep -q "^<!-- GENERATED" \
    || die "fetched profile is not a composed artefact — check that $REF and profile '$PROFILE' exist"

  mkdir -p "$(dirname "$POLICY_DEST")"
  cp "$TMP/$POLICY_FILE" "$POLICY_DEST"
  log "policy  -> $POLICY_DEST (profile: $PROFILE)"

  case "$PROFILE" in
    claude-*) rm -f "$PROFILE_DIR/AGENTS.md" ;;
  esac
else
  log "skip    : policy not installed (home-read-only)"
fi

# --- the workflow skills ------------------------------------------------------
#
# Everything above installs the credential client. This section is what makes
# the script a config channel rather than a credential one: an explicit list of
# skills that a sandbox should have, fetched by name.
#
# WHY A WHITELIST AND NOT `home/skills/*`: there is no directory listing over
# raw.githubusercontent.com, so a wildcard would need the GitHub API, a token,
# and a JSON parser — three dependencies for a list that changes a few times a
# year. Naming them is also the review point: a skill reaches every sandbox the
# moment it is added here, so the addition should be a decision rather than a
# side effect of creating a file. The 15 `setup-*` skills are deliberately
# absent pending a currency review: they are repo-scaffolding procedures that a
# sandbox session rarely needs, and they predate this surface by some months.
#
# WHY THESE FETCH A PRE-BUILT SKILL.md AND gcp-credentials DOES NOT: every
# skill named in the two lists below is already a finished SKILL.md with its
# frontmatter written — checked in under `home/skills/`, or, for a composed
# skill, built under `profiles/<profile>/skills/` and checked in there. There
# is nothing to synthesise, so this loop just fetches. The credential skill
# above predates that machinery and is still generated from its command file
# at install time; when it joins the checked-in set these two paths merge.
#
# TWO LISTS, BECAUSE THERE ARE TWO SOURCES (#265). A composed skill has a
# per-surface body: the sandbox variant calls the GitHub MCP server where the
# workstation variant reads what `gh` put in the gather output, resolved at
# composition rather than by the session working out which half of one text
# applies to it (ADR-0018 principle 1). Its artefact therefore lives under
# profiles/<profile>/skills/, next to that profile's composed policy, and is
# fetched by profile exactly as AGENTS.md and CLAUDE.md are above. A plain
# skill has one body for every surface and still comes from home/skills/.
#
# Adding a composed variant of an existing skill means moving its name from
# SKILLS to COMPOSED_SKILLS in the same change that adds the manifest entry.
# Getting that backwards is caught at install: the fetch 404s and the script
# dies naming the skill, rather than a session quietly running the wrong body.
#
# SKILLS holds the two skills that need no composition. promote-journal-inbox
# drains the journal-draft Issues a retro files when it cannot write its entry
# straight to paul-context journal/ (a gitleaks finding, a refused write). One
# body serves both surfaces — its pre-flight tests the repo rather than a path,
# and it already prefers MCP with gh as the fallback — so it needs no
# composition, which is ADR-0018 principle 8 working as intended rather than an
# omission (#289).
#
# bundle-issues is here for the same reason and not because it is simple
# (#456). It triages the whole backlog in a session of its own and writes
# Bundle Issues, which start-session then surfaces and any session can pick up.
# It needs no composing: its GitHub calls prefer MCP with gh as the fallback,
# exactly as the journal promoter's do.
#
# There is no consumer skill beside it. #456 shipped one and then retired it in
# the same change (see home/retired-paths): once the Bundle Issue carries the
# files, the gates and the stop rule, working one is ordinary session work.

SKILLS="promote-journal-inbox bundle-issues env-conformance sandbox-docker"
COMPOSED_SKILLS="retrospective start-session end-session"

# Path-scoped rule files, for Claude profiles only: Claude Code loads
# ~/.claude/rules/<name>.md once a file matching its `paths:` frontmatter has
# been read or written, so a rule about shell scripts costs nothing in a
# session that never opens one. They are composed from context/rules/ into
# home/rules/, the same files chezmoi delivers on a durable machine. Codex has
# no path scoping and keeps the same rules inline in its AGENTS.md.
#
# Fetched by name, like the skills, and for the same reason. The list must
# match rules.files in context/manifest.json: tests/compose-context.py fails
# when it does not.
RULES="shell-scripts terraform decision-records"

# Helper scripts the session skills shell out to. They are NOT optional: the
# skills invoke them by name, and a skill whose helper is missing fails at the
# point of use rather than at install, which is the worst time to find out.
#
# start-session-claude-drift and session-repo-resolve are here because the
# gather scripts run them as "$(dirname "$0")/<name>" -- sibling dependencies
# that nothing in the skill text mentions, so they would be easy to omit and
# hard to diagnose. session-repo-resolve is the shared one: both gathers call
# it, and without it both silently fall back to the old cwd-only check.
#
# They land in ~/.claude/bin because that is where the skills spell their
# invocation: "~/.claude/bin/<script>", on every surface.
#
# session-cache-verdict is here rather than with the hook scripts below because
# start-session reads its marker whether or not hooks were installed -- and a
# container with the reader but not the writer reports "no marker" honestly,
# which beats a missing script failing at the point of use.
#
# env-conformance is start-session's too: its gather runs the fast subset, and
# reads the matrix from ../conformance/ beside it, installed just below.
# env-conformance-stamp is the env-conformance skill's, for its scheduled mode.
BIN_SCRIPTS="start-session-gather-state start-session-claude-drift session-repo-resolve end-session-gather-state end-session-squash-merged session-cache-verdict env-conformance env-conformance-stamp toolchain-start"

# Defensive: the credential-helper section above already creates this, but the
# dependency is invisible from here and a reordering would break it silently.
mkdir -p "$CLAUDE_DIR/bin"

for script in $BIN_SCRIPTS; do
  fetch "$RAW/home/bin/$script" "$TMP/$script" \
    || die "could not fetch helper script $script from $REF"
  head -1 "$TMP/$script" | grep -q '^#!' \
    || die "fetched $script is not a script — check that $REF exists"
  install -m 0755 "$TMP/$script" "$CLAUDE_DIR/bin/$script"
done
log "helpers -> $CLAUDE_DIR/bin/ ($(echo "$BIN_SCRIPTS" | wc -w | tr -d ' ') session scripts)"

# The capability matrix env-conformance probes. Data, not a script, so the
# shebang guard above does not fit; a stanza header is what a bad ref's HTML
# error page will not have.
mkdir -p "$CLAUDE_DIR/conformance"
fetch "$RAW/home/conformance/matrix.conf" "$TMP/matrix.conf" \
  || die "could not fetch the capability matrix from $REF"
grep -q '^\[[a-z0-9-]*\]$' "$TMP/matrix.conf" \
  || die "fetched matrix.conf has no stanzas — check that $REF exists"
install -m 0644 "$TMP/matrix.conf" "$CLAUDE_DIR/conformance/matrix.conf"
log "matrix  -> $CLAUDE_DIR/conformance/matrix.conf"

# --- the standards ------------------------------------------------------------
#
# The estate standard, in both its forms: the machine-readable spec that
# setup-repo applies and paul-context's sweep diffs against, and the prose it
# is derived from.
#
# WHY A LOCAL COPY AT ALL, when raw.githubusercontent.com is plainly reachable
# from here -- everything above this line came through it. Because a fetch at
# read time fails at the moment it is needed, and worse, a failed fetch is
# indistinguishable from a standard that says nothing. That is the same defect
# as an unrun check reading as clean, one layer down. paul-context's
# find_spec() already resolves local-copy-first with the URL as the documented
# fallback; this is what makes the local copy exist on this surface.
#
# ~/.claude/standards/ is the same path chezmoi writes on a workstation, so a
# skill or a tool naming it works unchanged on both.
mkdir -p "$CLAUDE_DIR/standards"

for standard in github-repo.json github-standards.md; do
  fetch "$RAW/home/standards/$standard" "$TMP/$standard" \
    || die "could not fetch $standard from $REF"
  # Same 404-as-content guard the helpers and skills use: a bad ref returns
  # an HTML error page, and a standard that is silently HTML is worse than
  # one that is absent, because nothing downstream will notice.
  case "$standard" in
    *.json) head -1 "$TMP/$standard" | grep -q '^{' \
      || die "fetched $standard is not JSON — check that $REF exists" ;;
    *.md) head -1 "$TMP/$standard" | grep -q '^#' \
      || die "fetched $standard is not markdown — check that $REF exists" ;;
  esac
  install -m 0644 "$TMP/$standard" "$CLAUDE_DIR/standards/$standard"
done
log "standards -> $CLAUDE_DIR/standards/ (spec + prose)"

if [ "$HOME_RW" = yes ]; then
  for skill in $SKILLS $COMPOSED_SKILLS; do
    # One loop, one difference: where the body comes from. Recomputing it per
    # skill keeps the install, symlink and de-duplication steps below in a
    # single place rather than duplicated per source.
    case " $COMPOSED_SKILLS " in
      *" $skill "*) src="profiles/$PROFILE/skills/$skill/SKILL.md" ;;
      *) src="home/skills/$skill/SKILL.md" ;;
    esac

    fetch "$RAW/$src" "$TMP/$skill.SKILL.md" \
      || die "could not fetch the $skill skill from $REF ($src) — a composed skill needs a profiles/$PROFILE/skills/ entry in context/manifest.json"

    # Same 404-as-content guard as the helper: a bad ref returns an HTML error
    # page with a 200 from some proxies, and a skill whose body is HTML fails
    # in a way that reads like the skill being wrong rather than absent.
    head -1 "$TMP/$skill.SKILL.md" | grep -q '^---$' \
      || die "fetched $skill skill has no frontmatter — check that $REF exists"

    dir="$AGENTS_DIR/skills/$skill"
    mkdir -p "$dir"
    cp "$TMP/$skill.SKILL.md" "$dir/SKILL.md"

    # Same canonical/adapter split as the credential skill above: the real file
    # lives in the vendor-neutral tree, each vendor path is a symlink that
    # cannot drift. See that comment for the reasoning.
    rm -rf "$CLAUDE_DIR/skills/$skill"
    ln -sfn "$dir" "$CLAUDE_DIR/skills/$skill"
    log "skill   -> $dir/SKILL.md (+ ~/.claude/skills/$skill)"

    # A previous chezmoi-era or hand-copied command file registers the same
    # /name a second time. Same reasoning as gcp-credentials above.
    rm -f "$CLAUDE_DIR/commands/$skill.md"
  done
else
  log "skip    : workflow skills not installed (home-read-only)"
fi

# RULES_INSTALLED is what the manifest reports: what landed, not what was meant.
RULES_INSTALLED=""
case "$PROFILE" in
  claude-*)
    if [ "$HOME_RW" = yes ]; then
      mkdir -p "$CLAUDE_DIR/rules"
      for rule in $RULES; do
        fetch "$RAW/home/rules/$rule.md" "$TMP/$rule.rule.md" \
          || die "could not fetch the $rule rule file from $REF (home/rules/$rule.md)"
        # A rule file opens with its `paths:` frontmatter. Without it Claude
        # Code loads the file into every session, and an HTML error page from
        # a bad ref would load as policy.
        head -1 "$TMP/$rule.rule.md" | grep -q '^---$' \
          || die "fetched $rule rule file has no frontmatter — check that $REF exists"
        install -m 0644 "$TMP/$rule.rule.md" "$CLAUDE_DIR/rules/$rule.md"
        RULES_INSTALLED="${RULES_INSTALLED:+$RULES_INSTALLED }$rule"
      done
      log "rules   -> $CLAUDE_DIR/rules/ ($RULES_INSTALLED)"
    else
      log "skip    : rule files not installed (home-read-only)"
    fi
    ;;
esac

# --- harness hooks, on request ------------------------------------------------
#
# The other half of enforcement. #256 ships the pre-commit framework and a
# native git hook, which blocks a bad commit; these run inside the agent loop
# and return the failure into its context, where it can read the message and
# fix the cause rather than just being stopped. Both are worth having.
#
# Viable because a container-created ~/.claude/settings.json IS honoured, with
# no session restart -- despite user scope being documented as unavailable from
# inside the container, as it also is for ~/.claude/skills and CLAUDE.md (#254).
#
# The wiring is taken from home/settings.json rather than restated here. That
# file is the workstation's, and it already invokes ~/.claude/bin/<hook>
# directly -- the same paths this script installs to -- so the two surfaces run
# identical hooks from one source instead of a copy that drifts.
#
# There is one copy of each hook and one declaration of it: the settings file
# names each script directly, exactly as chezmoi's does.

if [ "$WITH_HOOKS" -eq 1 ]; then
  command -v jq >/dev/null 2>&1 || die "--with-hooks needs jq to merge settings.json"

  # Keep this list in step with the hook commands in
  # home/settings.json: the .hooks block below is taken from that file, so a
  # hook named there but missing here installs a settings.json pointing at a
  # script this container never fetched. credguard is the one that matters
  # most, because permissions.deny does not travel to a sandbox at all --
  # this hook is the only credential guard that reaches this surface (#440).
  for script in credguard-claude-hook prchecks-wait-claude-hook prepush-guard-claude-hook precommit-claude-hook agent-telemetry-claude-hook wsl-mnt-guard-claude-hook dockerd-start-claude-hook; do
    fetch "$RAW/home/bin/$script" "$TMP/$script" \
      || die "could not fetch hook script $script from $REF"
    head -1 "$TMP/$script" | grep -q '^#!' || die "fetched $script is not a script"
    install -m 0755 "$TMP/$script" "$CLAUDE_DIR/bin/$script"
  done

  # Sourced (not run) by prepush-guard and precommit, from lib/ next to
  # themselves. Without it both hooks stand down, so any new home/bin/lib/
  # file a hook above sources needs fetching here too.
  mkdir -p "$CLAUDE_DIR/bin/lib"
  fetch "$RAW/home/bin/lib/resolve-command-dir" "$TMP/resolve-command-dir" \
    || die "could not fetch hook library lib/resolve-command-dir from $REF"
  head -1 "$TMP/resolve-command-dir" | grep -q '^#!' \
    || die "fetched lib/resolve-command-dir is not a script"
  install -m 0644 "$TMP/resolve-command-dir" "$CLAUDE_DIR/bin/lib/resolve-command-dir"

  fetch "$RAW/home/settings.json" "$TMP/settings.json" \
    || die "could not fetch home/settings.json from $REF"
  jq -e '.hooks' "$TMP/settings.json" >"$TMP/hooks.json" \
    || die "home/settings.json has no .hooks block"

  # Merge rather than overwrite. A container may already have a settings.json
  # -- this script's own earlier run, or something the environment put there
  # -- and replacing it wholesale would silently drop whatever else it holds.
  # `*` deep-merges objects and replaces arrays, so the hook lists this repo
  # owns are replaced while any other key survives untouched.
  #
  # Note ~/.claude/launcher-settings.json is a DIFFERENT file with its own
  # hooks, written by the harness. Nothing here touches it, and both are read.
  SETTINGS="$CLAUDE_DIR/settings.json"
  if [ -f "$SETTINGS" ]; then
    jq -s '.[0] * {hooks: .[1]}' "$SETTINGS" "$TMP/hooks.json" >"$TMP/merged.json" \
      || die "could not merge into existing $SETTINGS"
    mv "$TMP/merged.json" "$SETTINGS"
    log "hooks   -> $SETTINGS (merged into existing)"
  else
    jq -n --slurpfile h "$TMP/hooks.json" '{hooks: $h[0]}' >"$SETTINGS" \
      || die "could not write $SETTINGS"
    log "hooks   -> $SETTINGS (created)"
  fi

  # prepush-guard needs gh on PATH, and exits 0 without it. --with-gh governs
  # only this script's own install: the platform may preinstall gh, and the
  # guard looks PRs up through REST, which a sandbox allows. So gate the note
  # on gh being there, not on the flag. precommit-claude-hook needs the
  # pre-commit framework and is a no-op without it. Both degrade rather than
  # failing, which is why hooks have no hard dependency on those -- but the
  # trio is what makes them worth having.
  #
  # Report the resolved state rather than naming flags: either capability can
  # arrive from the profile with no flag typed.
  if [ "$WITH_GH" -eq 1 ] || command -v gh >/dev/null 2>&1; then gh_note=""; else gh_note=" (inactive: no gh)"; fi
  if [ "$WITH_PRECOMMIT" -eq 1 ]; then pc_note=""; else pc_note=" (inactive: no pre-commit)"; fi
  log "hooks   :  prchecks-wait, prepush-guard$gh_note, precommit$pc_note"
fi

TIER1_SECS=$(($(now_s) - TIER1_START))
record_timing toolkit "$TIER1_SECS"

# =============================================================================
# TIER 2 -- capabilities. Runs after the toolkit, and degrades instead of dying.
# =============================================================================
#
# Toolchains a repo's own tooling calls: the GCP SDK, the pre-commit framework
# and its linters, gh. Expensive, network-heavy, and each new one is another
# chance to abort the run -- #254, #240, #316 and #344 are the same failure
# arriving through four different tools, and the list only grows.
#
# So a capability that cannot install is recorded and skipped rather than
# fatal. Each runs in a subshell with `set -e` re-armed, which is what lets the
# `die` calls inside them stay as they are: a die exits the subshell, the
# wrapper reads the reason it left behind, and the next capability still gets
# its turn. Verified in dash and bash that the EXIT trap does not misfire on
# subshell exit.
#
# WHY THIS IS NOT SILENTLY LOWERING THE BAR: #335 made precommit-claude-hook
# report a missing binary as NOT CHECKED rather than passed. A degraded
# capability therefore surfaces downstream as unverified work rather than as
# false green -- it loses coverage without manufacturing confidence. The
# manifest records `status=degraded` and names what is missing, and
# start-session reports it. Degrading quietly would be the sloppy version;
# this is the visible one.

# --- gcloud, on request -------------------------------------------------------
#
# Opt-in, because a repo with no GCP work should not pay a 96 MB download, and
# because an environment naming --with-gcloud in its one line is declaring what
# kind of environment it is. That is the capability-profile model ADR-0016
# describes, made visible in the place the choice is actually made.
#
# It must land BEFORE the first `gcp-credentials request`: the helper wires up a
# gcloud configuration only if gcloud is on PATH at that moment. Installed
# afterwards, the token file ends up with nothing pointing at it, and correcting
# that costs a second human approval.

cap_gcloud() {
  # An SDK already on PATH is wrapped, not skipped: the Claude cloud image
  # ships gcloud preinstalled, and skipping it left the preset token below
  # unhandled. Only the download is skipped.
  _existing=$(command -v gcloud 2>/dev/null || true)
  _fresh=0
  if [ -n "$_existing" ] && grep -q '^# Installed by agentic-coding-config cloud/bootstrap.sh' "$_existing" 2>/dev/null; then
    # Our own wrapper, from an earlier run: rewrite it from the current
    # template, keeping the SDK it already points at.
    _sdk=$(sed -n 's#^exec \(.*\)/bin/gcloud "\$@"$#\1#p' "$_existing" | tail -1)
  elif [ -n "$_existing" ]; then
    _real=$(readlink -f "$_existing" 2>/dev/null || echo "$_existing")
    _sdk=$(dirname "$(dirname "$_real")")
  else
    fetch https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz \
      "$TMP/gcloud.tar.gz" \
      || die "could not download the gcloud SDK — is dl.google.com on the allowlist?"
    mkdir -p "$OPT_DIR" || die "could not create $OPT_DIR"
    tar -xzf "$TMP/gcloud.tar.gz" -C "$OPT_DIR" || die "could not unpack the gcloud SDK"
    _sdk="$OPT_DIR/google-cloud-sdk"
    # --path-update false, then a wrapper on BIN_DIR: a PATH line appended to
    # a shell profile is not reliably sourced by the non-interactive shells
    # tool calls run in.
    "$_sdk/install.sh" --quiet --usage-reporting false \
      --path-update false --command-completion false >/dev/null || true
    _fresh=1
  fi
  if [ -z "$_sdk" ] || [ ! -x "$_sdk/bin/gcloud" ]; then
    die "gcloud at $_existing is not inside an SDK tree, so it cannot be wrapped"
  fi
  [ "$_fresh" -eq 1 ] || log "gcloud  : SDK already at $_sdk; wrapping it"
  # A wrapper rather than a symlink, because the agent proxy presets
  # CLOUDSDK_AUTH_ACCESS_TOKEN in every tool-call shell (the agent process
  # itself does not carry it, so no environment setting removes it), and that
  # variable outranks the
  # auth/access_token_file the broker configures. Every call then fails
  # ACCESS_TOKEN_TYPE_UNSUPPORTED while the helper, `status` and the token file
  # all report healthy — confirmed in two independent fresh sandboxes.
  #
  # The documented workaround is `env -u CLOUDSDK_AUTH_ACCESS_TOKEN` on every
  # invocation, which fails the moment anyone forgets, and fails silently by
  # picking the wrong identity rather than erroring. Better to make the right
  # thing the default.
  #
  # Narrow on purpose: it drops the variable only when a broker token actually
  # exists. With no grant installed, the preset token is whatever the sandbox
  # intended and is left alone.
  #
  # The body is quoted so its own $-expansions stay literal; the SDK path is
  # the one value it needs from here, filled in by sed. In the system layout
  # that yields /opt/google-cloud-sdk, the path it always carried.
  #
  # rm first: $BIN_DIR/gcloud can be the image's symlink into the SDK, and a
  # redirect writes THROUGH a symlink -- replacing the SDK's own gcloud with a
  # wrapper that execs itself.
  rm -f "$BIN_DIR/gcloud"
  sed "s#@GCLOUD_SDK@#$_sdk#g" >"$BIN_DIR/gcloud" <<'WRAPPER'
#!/bin/sh
# Installed by agentic-coding-config cloud/bootstrap.sh.
#
# Two jobs, both because gcloud otherwise gets the wrong credential:
#
#   1. Prefer a broker-issued token over the sandbox image's preset
#      CLOUDSDK_AUTH_ACCESS_TOKEN, which outranks auth/access_token_file.
#   2. Re-mint a stale token before the call, rather than relying on a
#      background loop that this environment reaps.
#
# The second replaces a daemon with a check. Detached refresh loops die here --
# twice in one session, once across an idle gap and once during active work --
# and when they do the grant stays valid for days while the token quietly ages
# out. Checking an mtime at the point of use has nothing to keep alive and
# nothing to reap, and it covers gcloud called from inside a script, which a
# session hook never sees.
CB_HOME="${CREDENTIAL_BROKER_HOME:-$HOME/.config/claude/credential-broker}"
CB_TOKEN="$CB_HOME/access_token"
CB_RENEW_ARGS=""

# The broker has two tiers, each with its own token, and which one this call
# uses is decided by its gcloud configuration: agent-broker-estate is the
# readonly-estate tier's (gcp-credentials keeps the name in step). Read the way
# gcloud reads it -- --configuration, then CLOUDSDK_ACTIVE_CONFIG_NAME, then the
# active_config file -- so a call that selects the estate configuration gets the
# estate token renewed and preferred, and every other call behaves as before.
cb_config="${CLOUDSDK_ACTIVE_CONFIG_NAME:-}"
cb_next=""
for cb_arg in "$@"; do
    if [ -n "$cb_next" ]; then cb_config="$cb_arg"; cb_next=""; continue; fi
    case "$cb_arg" in
        --configuration=*) cb_config="${cb_arg#--configuration=}" ;;
        --configuration) cb_next=1 ;;
    esac
done
if [ -z "$cb_config" ]; then
    cb_config=$(cat "${CLOUDSDK_CONFIG:-$HOME/.config/gcloud}/active_config" 2> /dev/null || true)
fi
if [ "$cb_config" = agent-broker-estate ]; then
    CB_TOKEN="$CB_HOME/access_token-readonly-estate"
    CB_RENEW_ARGS="--tier readonly-estate"
fi

# The threshold is really a floor on how much token life a call can start with:
# a token renewed at age T has 3600 - T seconds left, so T is chosen from how
# long a single invocation might run.
#
# 1800 against a 3600s token guarantees 30 minutes in hand. Observed scripts
# here run 10-25 minutes, which 2700 would have failed -- it leaves as little as
# 15. The extra renewals cost one HTTP call each and are not worth optimising.
#
# A script that calls gcloud repeatedly is covered for any duration, because
# every invocation re-checks and renews when stale. What this cannot save is a
# *single* call that blocks longer than the remaining life: Apigee provisioning
# at 70-80 minutes will still expire mid-flight and need re-running. That is
# accepted rather than solved, and it is why the floor matters more than the
# ceiling.
CB_MAX_AGE="${CREDENTIAL_BROKER_MAX_TOKEN_AGE:-1800}"

# CB_NO_RENEW stops a renew that shells out to gcloud from recursing. It does
# not today, but a wrapper that can loop forever is not worth the risk.
if [ -f "$CB_TOKEN" ] && [ -z "${CB_NO_RENEW:-}" ]; then
    cb_now=$(date +%s)
    cb_mtime=$(stat -c %Y "$CB_TOKEN" 2> /dev/null || stat -f %m "$CB_TOKEN" 2> /dev/null || echo "$cb_now")
    if [ $((cb_now - cb_mtime)) -ge "$CB_MAX_AGE" ]; then
        cb_helper=$(command -v gcp-credentials 2> /dev/null || echo "$CLAUDE_DIR/bin/gcp-credentials")
        if [ -x "$cb_helper" ]; then
            # Quiet on success: this runs before an unrelated command and must
            # not pollute output a script may be parsing. Failure is worth a
            # line, but is not fatal here -- gcloud reports its own auth error
            # better than a wrapper can guess at one.
            # shellcheck disable=SC2086 # CB_RENEW_ARGS is empty or two words
            CB_NO_RENEW=1 "$cb_helper" renew $CB_RENEW_ARGS > /dev/null 2>&1 ||
                echo "gcloud: broker token is stale and renew failed; run 'gcp-credentials status'" >&2
        fi
    fi
fi

# An agent has no tty, so a prompt would wait forever. With prompts disabled
# every one takes its default answer, which is "no" for a destructive confirm
# and for "enable this API and retry?". The one default that is "yes" is
# installing a missing component (`gcloud beta ...`): that installs and carries
# on rather than hanging. The `:-1` form leaves a caller free to set 0.
CLOUDSDK_CORE_DISABLE_PROMPTS="${CLOUDSDK_CORE_DISABLE_PROMPTS:-1}"
export CLOUDSDK_CORE_DISABLE_PROMPTS

if [ -n "${CLOUDSDK_AUTH_ACCESS_TOKEN:-}" ] && [ -f "$CB_TOKEN" ]; then
    exec env -u CLOUDSDK_AUTH_ACCESS_TOKEN @GCLOUD_SDK@/bin/gcloud "$@"
fi
exec @GCLOUD_SDK@/bin/gcloud "$@"
WRAPPER
  chmod 0755 "$BIN_DIR/gcloud" || true
  # gsutil needs no wrapper; link it only where this run installed the SDK,
  # and leave an image's own entry alone.
  [ "$_fresh" -eq 0 ] || ln -sf "$_sdk/bin/gsutil" "$BIN_DIR/gsutil" || true
  log "gcloud  -> $(gcloud --version 2>/dev/null | head -1 || echo 'installed')"
}

# --- pre-commit, on request ---------------------------------------------------
#
# Installs the pre-commit framework and the linters its config calls, so a
# repo's committed .pre-commit-config.yaml actually runs here (#254).
#
# This is the vendor-neutral half of enforcement, and the reason it is worth
# doing before the harness-hook half: git runs .git/hooks itself, so nothing
# here depends on agent configuration, on which harness is running, or on the
# unsettled question of whether a container-created ~/.claude/settings.json is
# honoured. It covers Codex, Claude, and a human typing `git commit`, all the
# same way.

# --- pre-commit tools, one at a time ------------------------------------------
#
# Each tool cap_precommit installs is its own function, run by pc_tool in a
# subshell of its own. A `die` in one tool then costs that tool, not the
# capability. In one shared subshell, a single stalled download took every
# tool after it out too, pre-commit itself included, so the gate was missing
# for the whole session.
#
# A failed tool is listed in $TMP/precommit-failed as "<name> <function>".
# precommit_retry, after the other capabilities, tries each one once more,
# and anything that still fails is named in `degraded=` as precommit.<name>.
# The retry comes late on purpose: the stalls seen so far cleared within a few
# minutes of container start, and the other capabilities fill that gap.
pc_tool() { # pc_tool <name> <function>
  step_begin
  set +e
  (
    set -e
    "$2"
  )
  _pc_rc=$?
  set -e
  [ "$_pc_rc" -eq 0 ] && return 0
  _pc_why=$(cat "$FAIL_FILE" 2>/dev/null || echo "no reason recorded")
  : >"$FAIL_FILE" 2>/dev/null || true
  # The tool's own step_end never ran, so time it here. A tool that spent 90 s
  # stalling and then failed is the case the timings exist to show.
  step_end "precommit.$1"
  echo "$1 $2" >>"$TMP/precommit-failed"
  log "WARN    : precommit.$1 did not install -- $_pc_why"
  return 0
}

pc_shellcheck() {
  # Both linters are `language: system` hooks in this estate's config -- they
  # run the binary on PATH rather than a pinned mirror, so the hook and CI
  # cannot drift to different versions.
  #
  # (Written as "both linters" rather than naming the first one at the start
  # of a comment line: `# shellcheck ...` is parsed as a shellcheck directive
  # and fails the lint, which this script is itself subject to.) That only works if the
  # binaries are here. Installing them is the whole point; SKIP= exists for a
  # laptop missing one, and normalising it would leave enforcement that is
  # routinely skipped, which is not enforcement.
  #
  # The binary comes from the pinned release on every layout, the same pattern
  # as actionlint below. Ubuntu's package is 0.9.0, so an apt fallback would
  # put the CLI and the hook on different versions exactly when GitHub is
  # unreachable; failing loudly, as the other pinned binaries do, is the point.
  if ! command -v shellcheck >/dev/null 2>&1; then
    SC_VER=0.11.0
    fetch "https://github.com/koalaman/shellcheck/releases/download/v${SC_VER}/shellcheck-v${SC_VER}.linux.x86_64.tar.xz" \
      "$TMP/shellcheck.tar.xz" \
      || die "could not download shellcheck ${SC_VER}"
    tar -xJf "$TMP/shellcheck.tar.xz" -C "$TMP" "shellcheck-v${SC_VER}/shellcheck" \
      || die "could not unpack shellcheck — is xz present?"
    install -m 0755 "$TMP/shellcheck-v${SC_VER}/shellcheck" "$BIN_DIR/shellcheck" \
      || die "could not install shellcheck"
  fi
  log "shellck -> $(command -v shellcheck)"
  step_end precommit.shellcheck
}

pc_actionlint() {

  # actionlint is not packaged in Ubuntu, so it comes from a pinned release.
  # Note github.com answers 403 to this sandbox's curl while the release asset
  # itself resolves fine through the redirect -- a naive reachability probe
  # against github.com reads as an egress block and is not one.
  if ! command -v actionlint >/dev/null 2>&1; then
    AL_VER=1.7.12
    fetch "https://github.com/rhysd/actionlint/releases/download/v${AL_VER}/actionlint_${AL_VER}_linux_amd64.tar.gz" \
      "$TMP/actionlint.tar.gz" \
      || die "could not download actionlint ${AL_VER}"
    tar -xzf "$TMP/actionlint.tar.gz" -C "$TMP" actionlint || die "could not unpack actionlint"
    install -m 0755 "$TMP/actionlint" "$BIN_DIR/actionlint" || die "could not install actionlint"
  fi
  log "actionl -> $(command -v actionlint)"
  step_end precommit.actionlint
}

pc_gitleaks() {

  # gitleaks for the `gitleaks-system` hook /setup-common stamps. The
  # `gitleaks` id is `language: golang` and compiles from source on a cold
  # cache, ~30s per container. The `-system` entry uses `gitleaks git`, which
  # needs 8.19 or later. Bump with the gitleaks rev in setup-common.
  if ! command -v gitleaks >/dev/null 2>&1; then
    GL_VER=8.30.1
    fetch "https://github.com/gitleaks/gitleaks/releases/download/v${GL_VER}/gitleaks_${GL_VER}_linux_x64.tar.gz" \
      "$TMP/gitleaks.tar.gz" \
      || die "could not download gitleaks ${GL_VER}"
    tar -xzf "$TMP/gitleaks.tar.gz" -C "$TMP" gitleaks || die "could not unpack gitleaks"
    install -m 0755 "$TMP/gitleaks" "$BIN_DIR/gitleaks" || die "could not install gitleaks"
  fi
  log "gitleak -> $(command -v gitleaks)"
  step_end precommit.gitleaks
}

pc_hadolint() {

  # hadolint for the upstream `hadolint` hook /setup-docker stamps, which runs
  # the binary on PATH. Not packaged in Ubuntu. The `hadolint-docker` variant
  # is no substitute: with no daemon it aborts the whole pre-commit run.
  #
  # The release publishes no checksum asset, so HL_SHA256 is the digest of
  # the asset as first fetched. Pinning it still turns a replaced asset into
  # a failed install rather than a silent one. Bump the two together.
  if ! command -v hadolint >/dev/null 2>&1; then
    HL_VER=2.15.1
    HL_SHA256=c7187db94eeeeca956519a6af171adc31453941a1e777961f6e680f697c8c507
    fetch "https://github.com/hadolint/hadolint/releases/download/v${HL_VER}/hadolint-linux-x86_64" \
      "$TMP/hadolint" \
      || die "could not download hadolint ${HL_VER}"
    sha256_is "$TMP/hadolint" "$HL_SHA256" \
      || die "hadolint ${HL_VER} does not match its pinned sha256"
    install -m 0755 "$TMP/hadolint" "$BIN_DIR/hadolint" || die "could not install hadolint"
  fi
  log "hadolnt -> $(command -v hadolint)"
  step_end precommit.hadolint
}

pc_trivy() {

  # trivy for `trivy config` (/setup-docker's CI scan, run locally before a
  # push) and the `terraform_trivy` hook /setup-terraform stamps, which shells
  # out to the binary on PATH. TV_SHA256 is checked against the release's
  # trivy_<v>_checksums.txt when bumped; bump the two together.
  if ! command -v trivy >/dev/null 2>&1; then
    TV_VER=0.76.2
    TV_SHA256=bc0fc726e017b8927a62b2d3531d7a84ee01769daf5c99ed866dced54089fdbf
    fetch "https://github.com/aquasecurity/trivy/releases/download/v${TV_VER}/trivy_${TV_VER}_Linux-64bit.tar.gz" \
      "$TMP/trivy.tar.gz" \
      || die "could not download trivy ${TV_VER}"
    sha256_is "$TMP/trivy.tar.gz" "$TV_SHA256" \
      || die "trivy ${TV_VER} does not match its pinned sha256"
    tar -xzf "$TMP/trivy.tar.gz" -C "$TMP" trivy || die "could not unpack trivy"
    install -m 0755 "$TMP/trivy" "$BIN_DIR/trivy" || die "could not install trivy"
  fi
  log "trivy   -> $(command -v trivy)"
  step_end precommit.trivy
}

pc_markdownlint_cli2() {

  # Serves `markdownlint-cli2 "**/*.md"`, the gate CLAUDE.md documents, which
  # needs the binary on PATH. Unlike the three above this is not a
  # `language: system` hook -- the pre-commit hook builds its own node
  # environment -- so the pin here and the rev in .pre-commit-config.yaml are
  # two versions of the same tool. Bump them together.
  if ! command -v markdownlint-cli2 >/dev/null 2>&1; then
    ML_VER=0.23.2
    command -v npm >/dev/null 2>&1 \
      || die "markdownlint-cli2 needs npm, which is not on PATH"
    npm_global_install "markdownlint-cli2@${ML_VER}" \
      || die "could not install markdownlint-cli2 ${ML_VER} from npm"
  fi
  # This image carries several node installs with different global prefixes,
  # so npm exiting 0 does not mean the shim landed anywhere on PATH.
  command -v markdownlint-cli2 >/dev/null 2>&1 \
    || die "markdownlint-cli2 installed but is not on PATH"
  log "mdlint  -> $(command -v markdownlint-cli2) ($(markdownlint-cli2 --version 2>&1 | head -1))"
  step_end precommit.markdownlint-cli2
}

pc_semgrep() {

  # semgrep is a `language: system` hook across this estate, so the hook runs
  # whatever is on PATH and fails hard with "Executable `semgrep` not found"
  # when nothing is -- which is why every commit in one paul-context sandbox
  # session had to be issued as SKIP=semgrep (#407). The hook was moved to
  # system deliberately: pre-commit's own python route costs 1.1G and ~200s
  # per container. This route is cheaper but not cheap: about a minute on a
  # cold uv cache, most of it the semgrep-core download (73s in one
  # rebuild). STEP_ROUTE puts precommit.semgrep.route=<route> into the
  # timings, so a slow install can be attributed to uv, pip or the prefix
  # layout rather than guessed at. pip is the fallback rather than the
  # route: uv sits at /root/.local/bin in this image, but one image is not
  # the contract.
  if ! command -v semgrep >/dev/null 2>&1; then
    if [ "$INSTALL_MODE" != system ]; then
      STEP_ROUTE=prefix
      py_tool_install semgrep \
        || die "could not install semgrep under $PREFIX"
    elif command -v uv >/dev/null 2>&1; then
      STEP_ROUTE=uv
      uv tool install semgrep >/dev/null 2>&1 \
        || die "could not install semgrep with uv"
    else
      STEP_ROUTE=pip
      pip_install semgrep \
        || die "could not install semgrep from PyPI"
    fi
  else
    STEP_ROUTE=present
  fi
  command -v semgrep >/dev/null 2>&1 \
    || die "semgrep reported installed but is not on PATH"
  log "semgrep -> $(command -v semgrep)"
  step_end precommit.semgrep
}

pc_cspell() {

  # cspell already runs inside pre-commit's own node environment, so the hook
  # passes without this. What does not work without it is the documented
  # pre-push check -- several repos tell contributors to run cspell directly
  # before committing, so absence from PATH makes that instruction
  # unfollowable and turns four batches of proper nouns into four failed
  # commits (#407). Pinned like markdownlint-cli2 above, but not coupled to a
  # hook rev: the cspell hook tracks the latest tag rather than a version this
  # script could match.
  if ! command -v cspell >/dev/null 2>&1; then
    CS_VER=10.3.3
    command -v npm >/dev/null 2>&1 \
      || die "cspell needs npm, which is not on PATH"
    npm_global_install "cspell@${CS_VER}" \
      || die "could not install cspell ${CS_VER} from npm"
  fi
  # Same several-node-prefixes caveat as markdownlint-cli2: npm exiting 0
  # does not mean the shim landed anywhere on PATH.
  command -v cspell >/dev/null 2>&1 \
    || die "cspell installed but is not on PATH"
  log "cspell  -> $(command -v cspell) ($(cspell --version 2>&1 | head -1))"
  step_end precommit.cspell
}

pc_terraform() {
  # Same pinned-release pattern, and the same github.com 403 note, as
  # actionlint above.
  # The pin is compared against what is installed, not merely against
  # whether anything is. The image ships its own terraform at 1.9.8, and
  # every root in the private infrastructure repository declares
  # required_version >= 1.11,
  # so terraform_validate fails init in all 16 layers (#369) -- with a
  # bare `command -v` guard the install is skipped and that stays true
  # however the pin is bumped. An installed version NEWER than the pin is
  # left alone, so this never walks a container backwards.
  #
  # The version is the spec's terraform.pin, not this line's to choose:
  # this runs before anything here can parse JSON, so it is a literal,
  # and tests/github-repo-standard.py fails CI when the two differ. Move
  # it in the same change as the spec and every repo's CI -- a sandbox
  # ahead of CI can write state CI cannot read back (github-standards.md,
  # Terraform versions).
  TF_VER=1.16.3
  tf_have=$(terraform version 2>/dev/null | sed -n '1s/^Terraform v//p')
  if [ -z "$tf_have" ] \
    || [ "$(printf '%s\n%s\n' "$TF_VER" "$tf_have" | sort -V | head -1)" != "$TF_VER" ]; then
    fetch "https://releases.hashicorp.com/terraform/${TF_VER}/terraform_${TF_VER}_linux_amd64.zip" \
      "$TMP/terraform.zip" \
      || die "could not download terraform ${TF_VER}"
    unzip -o -q "$TMP/terraform.zip" -d "$TMP" terraform \
      || die "could not unpack terraform — is unzip present?"
    install -m 0755 "$TMP/terraform" "$BIN_DIR/terraform" \
      || die "could not install terraform"
  fi
  log "terrafm -> $(command -v terraform) ($(terraform version | head -1))"
  step_end precommit.terraform
  # The manifest's terraform= reads this, not WITH_TERRAFORM. This
  # capability runs in a subshell, so a file is the only way the outcome
  # gets out of it.
  : >"$TMP/terraform-installed"
}

pc_tflint() {

  if ! command -v tflint >/dev/null 2>&1; then
    TFL_VER=0.53.0
    fetch "https://github.com/terraform-linters/tflint/releases/download/v${TFL_VER}/tflint_linux_amd64.zip" \
      "$TMP/tflint.zip" \
      || die "could not download tflint ${TFL_VER}"
    unzip -o -q "$TMP/tflint.zip" -d "$TMP" tflint \
      || die "could not unpack tflint"
    install -m 0755 "$TMP/tflint" "$BIN_DIR/tflint" \
      || die "could not install tflint"
  fi
  log "tflint  -> $(command -v tflint)"
  step_end precommit.tflint
}

# workspace_find <name> <out>: every file called <name> in the checkouts the
# harness may have cloned, one path per line, sorted, written to <out>.
#
# Bounded on purpose. -maxdepth 3 from a handful of candidate roots covers
# the layouts in use (the CLI clones to /home/user/<repo>, and a session may
# start in the parent of its repos; $PWD and $HOME cover the rest) without
# walking a whole filesystem inside a five-minute setup budget. The prunes
# keep it off vendored trees: pre-commit's own cache clones repos that carry
# a .pre-commit-config.yaml of their own, and a .terraform module cache
# carries other people's .tflint.hcl.
#
# WARM_ROOTS is a test seam. It is word-split, so no root may hold a space.
workspace_find() {
  : >"$2"
  for _wf_root in ${WARM_ROOTS:-"$PWD" "$HOME" /home/user /workspace /workspaces}; do
    [ -d "$_wf_root" ] || continue
    find "$_wf_root" -maxdepth 3 \
      \( -name .cache -o -name node_modules -o -name .venv -o -name .git -o -name .terraform \) -prune -o \
      -name "$1" -print 2>/dev/null >>"$2" || true
  done
  sort -u "$2" -o "$2" 2>/dev/null || true
}

# tflint_google_pins <.tflint.hcl>: the version of each plugin block whose
# source is the Google ruleset, one per line. Not an HCL parser: it reads the
# shape tflint documents, a `plugin "<name>" {` line, one attribute per line,
# and a closing brace. A pin written any other way (a one-line block, a
# version built from a variable) is not seen, and that repo keeps the
# fallback. Only an x.y.z version is printed, because it becomes a path and a
# URL below.
tflint_google_pins() {
  awk '
    /^[[:space:]]*(#|\/\/)/ { next }
    /^[[:space:]]*plugin[[:space:]]+"[^"]*"[[:space:]]*\{/ { inb = 1; v = ""; s = ""; next }
    inb && /^[[:space:]]*version[[:space:]]*=/ { v = $0; sub(/^[^"]*"/, "", v); sub(/".*$/, "", v) }
    inb && /^[[:space:]]*source[[:space:]]*=/ { s = $0; sub(/^[^"]*"/, "", s); sub(/".*$/, "", s) }
    inb && /^[[:space:]]*}/ {
      if (s == "github.com/terraform-linters/tflint-ruleset-google" && v != "") print v
      inb = 0
    }
  ' "$1" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' || true
}

# tflint_google_seed <version>: put that release of the Google ruleset where
# tflint --init looks for it, after checking the asset against the release's
# own checksums.txt. Skipped when the plugin is already in place. Returns 1
# with the reason in TFG_WHY rather than dying, so each caller decides what a
# failure costs. The binary is unpacked to scratch and installed whole, so a
# failed run never leaves a directory the skip test would mistake for done.
tflint_google_seed() {
  _tg_v=$1
  _tg_dir="$HOME/.tflint.d/plugins/github.com/terraform-linters/tflint-ruleset-google/$_tg_v"
  TFG_DIR=$_tg_dir
  TFG_WHY=
  [ -x "$_tg_dir/tflint-ruleset-google" ] && return 0
  _tg_tmp="$TMP/tflint-ruleset-google-$_tg_v"
  rm -rf "$_tg_tmp"
  mkdir -p "$_tg_tmp/x" || {
    TFG_WHY="could not create $_tg_tmp"
    return 1
  }
  fetch "https://github.com/terraform-linters/tflint-ruleset-google/releases/download/v${_tg_v}/tflint-ruleset-google_linux_amd64.zip" \
    "$_tg_tmp/ruleset.zip" || {
    TFG_WHY="could not download tflint-ruleset-google $_tg_v"
    return 1
  }
  fetch "https://github.com/terraform-linters/tflint-ruleset-google/releases/download/v${_tg_v}/checksums.txt" \
    "$_tg_tmp/checksums.txt" || {
    TFG_WHY="could not download checksums.txt for tflint-ruleset-google $_tg_v"
    return 1
  }
  _tg_sum=$(awk '$2 == "tflint-ruleset-google_linux_amd64.zip" { print $1; exit }' "$_tg_tmp/checksums.txt")
  [ -n "$_tg_sum" ] || {
    TFG_WHY="checksums.txt for tflint-ruleset-google $_tg_v lists no linux_amd64 zip"
    return 1
  }
  sha256_is "$_tg_tmp/ruleset.zip" "$_tg_sum" || {
    TFG_WHY="tflint-ruleset-google $_tg_v does not match its checksums.txt"
    return 1
  }
  unzip -o -q "$_tg_tmp/ruleset.zip" tflint-ruleset-google -d "$_tg_tmp/x" || {
    TFG_WHY="could not unpack tflint-ruleset-google $_tg_v"
    return 1
  }
  if ! mkdir -p "$_tg_dir" \
    || ! install -m 0755 "$_tg_tmp/x/tflint-ruleset-google" "$_tg_dir/tflint-ruleset-google"; then
    TFG_WHY="could not install tflint-ruleset-google $_tg_v into $_tg_dir"
    return 1
  fi
  rm -rf "$_tg_tmp"
}

pc_tflint_ruleset_google() {

  # tflint --init resolves plugins through the GitHub releases API, which
  # the sandbox proxy 403s, so the ruleset is seeded from its release
  # asset instead -- that URL redirects to a host the proxy does allow,
  # the same asymmetry the actionlint note above records. Without this,
  # the tflint stage of the pre-push hook cannot pass in a container at
  # all.
  #
  # tflint looks a plugin up under the version the repo's .tflint.hcl pins,
  # not under any version present, so a seed of the wrong version is no seed
  # at all. Every version pinned in a checkout found here is seeded, and so
  # is TFL_GOOGLE_VER, for a repo that pins nothing or arrives later. A repo
  # pin that cannot be fetched or verified is a warning: it costs that repo's
  # tflint hook, which cloud/README.md says how to seed by hand. The fallback
  # failing is this tool failing, and degrades it as before.
  TFL_GOOGLE_VER=0.31.0
  workspace_find .tflint.hcl "$TMP/tflint-configs"
  _tg_pins=$(while IFS= read -r _tg_cfg; do
    [ -n "$_tg_cfg" ] && tflint_google_pins "$_tg_cfg"
  done <"$TMP/tflint-configs" | sort -u)
  for _tg_pin in $_tg_pins; do
    [ "$_tg_pin" = "$TFL_GOOGLE_VER" ] && continue
    if tflint_google_seed "$_tg_pin"; then
      log "tflplug -> $TFG_DIR (pinned in a checkout)"
    else
      log "WARN    : tflint-ruleset-google $_tg_pin, pinned in a checkout, not seeded -- $TFG_WHY"
    fi
  done
  tflint_google_seed "$TFL_GOOGLE_VER" || die "$TFG_WHY"
  log "tflplug -> $TFG_DIR"
  step_end precommit.tflint-ruleset-google
}

pc_checkov() {

  # checkov is a Python tool, so it takes the same uv-or-pip route as
  # pre-commit rather than a release tarball.
  command -v checkov >/dev/null 2>&1 \
    || python_cli_install checkov \
    || die "could not install checkov from PyPI"
  command -v checkov >/dev/null 2>&1 \
    || die "checkov reported installed but is not on PATH"
  log "checkov -> $(command -v checkov)"
  step_end precommit.checkov
}

cap_precommit() {
  pc_tool shellcheck pc_shellcheck
  pc_tool actionlint pc_actionlint
  pc_tool gitleaks pc_gitleaks
  pc_tool hadolint pc_hadolint
  pc_tool trivy pc_trivy
  pc_tool markdownlint-cli2 pc_markdownlint_cli2
  pc_tool semgrep pc_semgrep
  pc_tool cspell pc_cspell

  # The Terraform toolchain, opt-in. A repo's .pre-commit-config.yaml can
  # call terraform_fmt, terraform_validate, terraform_tflint and checkov;
  # without the binaries those hooks fail with exit 127 rather than finding
  # anything. precommit-claude-hook classifies that as not-checked and lets
  # the push through (#335), so this is about being able to CHECK, not about
  # being able to push.
  #
  # On by default for a sandbox, off elsewhere -- the same reasoning as
  # pre-commit itself: a disposable container rebuilt from a script has no
  # developer setup to protect, so enforcement that is present beats a
  # download that is avoided. --no-terraform is the refund.
  if [ "$WITH_TERRAFORM" -eq 1 ]; then
    pc_tool terraform pc_terraform
    pc_tool tflint pc_tflint
    pc_tool tflint-ruleset-google pc_tflint_ruleset_google
    pc_tool checkov pc_checkov
  fi

  step_begin

  command -v pre-commit >/dev/null 2>&1 \
    || python_cli_install pre-commit \
    || die "could not install pre-commit from PyPI"
  # pip exiting 0 is not the same as the console script existing: an image
  # carrying the pre_commit package without its shim, or a pip whose scripts
  # directory is off PATH, both satisfy the install and leave nothing to run.
  # The manifest's precommit= is read as an attestation that the gate is
  # present, so observe the binary rather than infer it from an exit code.
  command -v pre-commit >/dev/null 2>&1 \
    || die "pre-commit reported installed but is not on PATH"
  log "precmit -> $(command -v pre-commit) ($(pre-commit --version))"
  step_end precommit.pre-commit

  install_git_hook
}

# install_git_hook: the global pre-commit hook. In eager and run modes
# cap_precommit installs it last. In background mode it installs on its own,
# at setup time, because the hook is what makes a commit wait for the deferred
# toolchain rather than skip a gate that has not arrived yet.
install_git_hook() {
  # A GLOBAL hook via core.hooksPath, not `pre-commit install` per repo.
  #
  # `pre-commit install` writes into an existing clone's .git/hooks, and this
  # script runs from an environment setup script whose ordering against the
  # session's clone is not something it can rely on -- the repository may not
  # exist yet, and may not be the only one. core.hooksPath is set once and
  # applies to every repo in the container however and whenever it arrives.
  #
  # The trade-off, stated because it is real: core.hooksPath REPLACES a repo's
  # own .git/hooks rather than adding to it. In this estate hooks come from
  # pre-commit anyway, so nothing is lost; a container that needed bespoke
  # per-repo hooks would want the other mechanism.
  #
  # The part that bites something else: `pre-commit install` does not warn
  # under core.hooksPath, it REFUSES -- "Cowardly refusing to install hooks
  # with `core.hooksPath` set", exit 1 (measured 2026-09-15). So a repo-side
  # SessionStart hook running it under `set -e` fails session start in exactly
  # the containers this line got right. `pre-commit install-hooks` is
  # unaffected -- exit 0, builds environments, writes no hook -- which is what
  # cap_precommit_warm below uses and why the two are called separately.
  # cloud/README.md carries this for the repos that have to write against it.
  HOOK_DIR="$HOME/.config/git/hooks"
  mkdir -p "$HOOK_DIR"
  sed -e "s#@TOOLCHAIN_DIR@#$AGENTS_DIR/toolchain#g" \
    -e "s#@AGENT_TELEMETRY@#$BIN_DIR/agent-telemetry#g" >"$HOOK_DIR/pre-commit" <<'HOOK'
#!/bin/sh
# Installed by agentic-coding-config cloud/bootstrap.sh.
#
# Global pre-commit hook: runs the repo's own pre-commit configuration when it
# has one, and gets out of the way when it does not. A repo with no
# .pre-commit-config.yaml is not opting out of anything -- it simply has no
# configuration to run, and blocking its commits would be this container
# inventing policy the repo never asked for.
[ -f .pre-commit-config.yaml ] || exit 0

# A container bootstrapped with --toolchain=background installs pre-commit
# after the session starts. A commit that arrives first WAITS for it, and never
# passes unchecked (ADR-0021, 2026-11-10 amendment). The wait is bounded well
# under an agent's 120 s foreground timeout, and a commit still waiting at the
# bound fails loudly. The launcher also restarts an install whose process died.
tc_dir="${TOOLCHAIN_DIR:-@TOOLCHAIN_DIR@}"
if [ -x "$tc_dir/start" ] && [ -f "$tc_dir/args" ]; then
  tc_ms=$(TOOLCHAIN_DIR="$tc_dir" "$tc_dir/start" --wait "${TOOLCHAIN_WAIT_S:-75}")
  tc_rc=$?
  case "$tc_ms" in '' | *[!0-9]*) tc_ms=0 ;; esac
  # A commit that waited is the wait ADR-0021's classification predicts, and the
  # shims never see it: by the time pre-commit runs, the install has finished.
  # So record it here, detached and with stdio closed, so telemetry can never
  # change the commit's result. A wait under a second is noise, not a block.
  if [ "$tc_ms" -ge 1000 ]; then
    case $tc_rc in 0) tc_out=done ;; 2) tc_out=still-running ;; *) tc_out=failed ;; esac
    tc_tel="${AGENT_TELEMETRY:-@AGENT_TELEMETRY@}"
    if [ -x "$tc_tel" ]; then
      "$tc_tel" event hook toolchain-wait blocked_ms="$tc_ms" outcome="$tc_out" \
        < /dev/null > /dev/null 2>&1 &
    fi
  fi
  case $tc_rc in
    0) ;;
    2)
      echo "pre-commit: the background toolchain install is still running (log: $tc_dir/install.log)." >&2
      echo "pre-commit: this commit was NOT checked and was stopped. Retry it in a minute." >&2
      exit 1
      ;;
    *)
      echo "pre-commit: the background toolchain install FAILED (manifest: $tc_dir/manifest, log: $tc_dir/install.log)." >&2
      echo "pre-commit: running whatever hooks can run; anything missing is reported below, not passed." >&2
      ;;
  esac
fi

# Is a REAL pre-commit installed? `command -v` is not enough here: the
# toolchain shims sit first on a session's PATH and include pre-commit, so the
# shim answers even when nothing is behind it. A shim is a symlink to
# agent-shim, so skip those. The exec below still goes through PATH, shim
# included, so the call is timed as usual.
have_pc=no
tc_ifs=$IFS
IFS=:
for tc_d in $PATH; do
  [ -x "$tc_d/pre-commit" ] || continue
  case "$(readlink "$tc_d/pre-commit" 2> /dev/null)" in
    *agent-shim) continue ;;
  esac
  have_pc=yes
  break
done
IFS=$tc_ifs
if [ "$have_pc" = no ]; then
  # Loud only where pre-commit was meant to be here. A workstation without it
  # is not this hook's business.
  [ -f "$tc_dir/args" ] && echo "pre-commit: NOT CHECKED -- pre-commit is not installed in this container." >&2
  exit 0
fi
exec pre-commit run --hook-stage pre-commit
HOOK
  chmod 0755 "$HOOK_DIR/pre-commit"
  git config --global core.hooksPath "$HOOK_DIR"
  log "githook -> $HOOK_DIR/pre-commit (core.hooksPath, all repos)"
}

# --- deferring the toolchain to the session (--toolchain=background) ----------
#
# Leaves everything toolchain-start needs to re-run this script later, at the
# same commit, as `--toolchain=run`:
#   bootstrap.sh  this commit's script, fetched by sha, so the deferred run
#                 installs the same pins as the toolkit already in place
#   args          the resolved sha and this run's resolved flags, one per line
#   start         the launcher, copied here so the git hook can find it by a
#                 path fixed at install time
#   state         `pending` until the launcher starts the run
# A ref that did not resolve (no network at setup) is passed as the ref itself,
# and the deferred run resolves it again.
on_off_flag() { # on_off_flag <0|1> <name> -> --with-<name> | --no-<name>
  if [ "$1" -eq 1 ]; then echo "--with-$2"; else echo "--no-$2"; fi
}
cap_toolchain_defer() {
  _tc="$AGENTS_DIR/toolchain"
  mkdir -p "$_tc" || die "could not create $_tc"
  fetch "$RAW/cloud/bootstrap.sh" "$_tc/bootstrap.sh" \
    || die "could not fetch this commit's bootstrap.sh for the deferred run"
  install -m 0755 "$CLAUDE_DIR/bin/toolchain-start" "$_tc/start" \
    || die "toolchain-start is not installed, so nothing could start the deferred run"
  _ref=$resolved
  [ "$kind" != unresolved ] || _ref=$REF
  {
    echo "$_ref"
    echo "--profile=$PROFILE"
    on_off_flag "$WITH_PRECOMMIT" precommit
    on_off_flag "$WITH_TERRAFORM" terraform
    on_off_flag "$WITH_HOOKS" hooks
    # The deferred run installs the toolchain and nothing else, so the
    # capabilities this run already handled are switched off for it.
    echo "--no-gcloud"
    echo "--no-gh"
    echo "--no-devknowledge"
    if [ -n "$PREFIX" ]; then echo "--prefix=$PREFIX"; fi
    if [ -n "$SOURCE_OVERRIDDEN" ]; then
      echo "--source-repo=$SOURCE_REPO"
      echo "--source-prefix=$SOURCE_PREFIX"
    fi
    echo "--toolchain=run"
  } >"$_tc/args.tmp" || die "could not write $_tc/args"
  rm -f "$_tc/pid" "$_tc/manifest" "$_tc/lock" 2>/dev/null || true
  echo pending >"$_tc/state" || die "could not write $_tc/state"
  mv "$_tc/args.tmp" "$_tc/args" || die "could not write $_tc/args"
  log "toolchn -> deferred to the session: $_tc (started by toolchain-start)"
}

# --- warming the pre-commit cache ---------------------------------------------
#
# `pre-commit install-hooks` builds a hook's environment; the first run that
# meets a cold cache builds it instead. In this estate that first run is a
# COMMIT, inside two 120 s timeouts -- precommit-claude-hook's, and the Bash
# tool's. For the estate set that is ~20 s of python and node builds; it was
# two minutes while gitleaks and actionlint compiled from source, before they
# moved to their `-system` ids (#609), and a repo's own golang hooks still
# can be. Every outcome of
# that race is wrong: a hook that times out and lets the commit through is a
# gate that silently did not run, and a commit killed for a reason unrelated to
# its content is a failure that succeeds on retry (#441).
#
# The fix is a matter of WHICH FILESYSTEM. The setup script's is snapshotted and
# restored for about seven days; the session's is not, so a cache built
# in-session is rebuilt in every container. Warming here is paid once per
# snapshot and is free at every session start.
#
# TWO MECHANISMS, and cap_precommit's own note on core.hooksPath says why one is
# not enough: at setup-script time "the repository may not exist yet, and may not
# be the only one".
#
#   1. The estate standard -- cloud/precommit-warm.yaml, pinned. pre-commit keys
#      its cache on (repo URL, rev), so warming those pins warms every repo
#      pinned to the same ones, whether or not a clone is here. This is the
#      guarantee, and a failure of it is what degrades the capability.
#   2. The exact match -- every .pre-commit-config.yaml found in the workspace.
#      The CLI clones before running the setup script, so this is the common
#      case; it cannot be relied on, and it catches the revs the estate file
#      does not pin.
#
# A repo on a rev the estate file does not carry gets a partial warm, never a
# failure: the hooks it shares are cached and the rest build on first use.
#
# Measured 2026-09-15 in a claude-cloud-sandbox container, pre-commit 4.6.2:
# 88 s and 222 MB for the seven pinned repos on a genuinely cold container
# (50 s on a later rebuild, once Go's own module cache was populated), against
# 31 s / 120 MB for the three golang repos alone. A `pre-commit run --all-files`
# afterwards is 2 s with no environment build. §"Warming the pre-commit cache"
# in docs/cloud-sandbox-design.md carries the budget arithmetic.

# Where pre-commit keeps the cache, by its own resolution order. Read after the
# warm to record what actually landed, so "the cache is present" is asserted
# rather than inferred from an exit code.
precommit_home() {
  if [ -n "${PRE_COMMIT_HOME:-}" ]; then
    echo "$PRE_COMMIT_HOME"
  elif [ -n "${XDG_CACHE_HOME:-}" ]; then
    echo "$XDG_CACHE_HOME/pre-commit"
  else
    echo "$HOME/.cache/pre-commit"
  fi
}

# warm_install <dir> <config> <prefix>: `pre-commit install-hooks` with each
# hook repo's environment build timed, into the step-timings file as
# <prefix>.<repo>=Ns, plus <prefix>.clone for the fetches before the first
# build. pre-commit prints "Installing environment for <url>." as each build
# starts, so stamping lines as they arrive splits one invocation by repo
# without changing what it does. PYTHONUNBUFFERED because a pipe otherwise
# delivers those lines in one burst at exit, stamping them all the same second.
# A repo already in the cache prints nothing and is not timed. Output lands in
# $TMP/warm.log, as before; returns pre-commit's status.
warm_install() {
  : >"$TMP/warm.log"
  : >"$TMP/warm.stamped"
  rm -f "$TMP/warm.rc"
  _w_start=$(now_s)
  (
    cd "$1" || exit 1
    if PYTHONUNBUFFERED=1 pre-commit install-hooks -c "$2" 2>&1; then
      echo 0 >"$TMP/warm.rc"
    else
      echo "$?" >"$TMP/warm.rc"
    fi
  ) | while IFS= read -r _l; do
    printf '%s\n' "$_l" >>"$TMP/warm.log"
    printf '%s %s\n' "$(now_s)" "$_l" >>"$TMP/warm.stamped"
  done
  _w_end=$(now_s)
  awk -v s="$_w_start" -v e="$_w_end" -v p="$3" '
        / Installing environment for / {
            n = $NF; sub(/\.$/, "", n); sub(/\/$/, "", n); sub(/.*\//, "", n); sub(/\.git$/, "", n)
            if (cur != "") printf "%s.%s=%ds\n", p, cur, $1 - t
            else printf "%s.clone=%ds\n", p, $1 - s
            cur = n; t = $1
        }
        END { if (cur != "") printf "%s.%s=%ds\n", p, cur, e - t }
    ' "$TMP/warm.stamped" >>"$TMP/step-timings" 2>/dev/null || true
  return "$(cat "$TMP/warm.rc" 2>/dev/null || echo 1)"
}

cap_precommit_warm() {
  # cap_precommit is what installs pre-commit, and it already names itself in
  # `degraded=` when it cannot. Reporting one root cause under two names makes
  # that list harder to act on, so this stands down quietly instead.
  if ! command -v pre-commit >/dev/null 2>&1; then
    log "warm    : no pre-commit on PATH, nothing to warm"
    return 0
  fi

  # install-hooks shells out to git and refuses outside a work tree -- "git
  # failed. Is it installed, and are you in a Git repository directory?",
  # exit 1. The setup script's cwd belongs to the harness and is frequently
  # not a checkout, so make one. An empty repo is enough: the cache it fills
  # is global and has nothing to do with the repo the command ran from.
  _warm_repo="$TMP/warm-repo"
  mkdir -p "$_warm_repo"
  git -C "$_warm_repo" init -q >/dev/null 2>&1 \
    || die "could not create the scratch repo to warm from"

  # When `go` is absent pre-commit fetches its own toolchain, and the first
  # call is https://go.dev/dl/?mode=json -- which this sandbox's egress proxy
  # answers 403 (measured 2026-09-15), so a golang hook fails rather than
  # falling back. The estate set has none; a checkout found in step 2 may. The image ships Go at /usr/local/go/bin, so this warns about
  # an image change rather than a routine path; the remedy is allowlisting
  # go.dev or putting Go back, and it is not something this script can do.
  command -v go >/dev/null 2>&1 \
    || log "warn    : no go on PATH — golang hooks will try go.dev, which this egress blocks"

  # --- 1. the estate standard, the half that does not need a clone ---------
  fetch "$RAW/cloud/precommit-warm.yaml" "$TMP/precommit-warm.yaml" \
    || die "could not fetch cloud/precommit-warm.yaml from $REF"
  # Same 404-as-content guard as every other fetch here: raw.githubusercontent
  # answers a missing path with a plain "404: Not Found" body, and handing that
  # to pre-commit produces a parse error rather than a fetch error.
  grep -q '^repos:' "$TMP/precommit-warm.yaml" \
    || die "fetched warm config has no repos: block — check that $REF exists"

  if warm_install "$_warm_repo" "$TMP/precommit-warm.yaml" warm; then
    log "warm    -> estate hook set (cloud/precommit-warm.yaml)"
  else
    # TMP is cleaned on exit, so quote the tail into this log rather than
    # sending a reader to a path that will not be there.
    tail -5 "$TMP/warm.log" 2>/dev/null | while IFS= read -r _l; do
      log "warm    ! $_l"
    done
    die "could not warm the estate hook set"
  fi

  # --- 2. the exact match, for whatever the harness cloned -----------------
  #
  # workspace_find says where it looks and what it skips. Warming a vendored
  # tree's config would be this container inventing hooks nobody asked for.
  _found="$TMP/warm-configs"
  workspace_find .pre-commit-config.yaml "$_found"

  # A cap, because this is an unbounded input: a container holding twenty
  # checkouts must not spend the snapshot budget on them. The estate warm
  # above is the guarantee, so what is skipped here costs a slower first
  # commit in one repo, not a missing gate.
  _n=0
  while IFS= read -r _cfg; do
    [ -n "$_cfg" ] || continue
    _dir=$(dirname "$_cfg")
    # install-hooks needs a work tree, and a stray config in a plain
    # directory is not one.
    git -C "$_dir" rev-parse --git-dir >/dev/null 2>&1 || continue
    _n=$((_n + 1))
    if [ "$_n" -gt 5 ]; then
      log "warm    : more than 5 checkouts found, stopping at $_cfg"
      break
    fi
    # Per-config failures are logged, not fatal. A repo whose config names a
    # hook this container cannot build is a slow first commit in that repo;
    # the estate warm has already delivered the guarantee.
    if warm_install "$_dir" "$_cfg" "warm.$(basename "$_dir")"; then
      log "warm    -> $_cfg"
    else
      log "warn    : could not warm $_cfg — its first commit pays the build"
    fi
  done <"$_found"

  # What actually landed, counted from the cache rather than from exit codes.
  # pre-commit names each cloned hook repo repo<something>; an empty cache
  # after a successful run means the warm did nothing and should be visible.
  _cache=$(precommit_home)
  _envs=$(find "$_cache" -maxdepth 1 -type d -name 'repo*' 2>/dev/null | wc -l | tr -d ' ')
  [ -n "$_envs" ] || _envs=0
  # Out through a file: capability() runs this in a subshell, so an assignment
  # here dies with it -- the same reason FAIL_FILE exists.
  echo "$_envs" >"$TMP/warm-envs" 2>/dev/null || true
  log "warm    -> $_envs hook environments cached in $_cache"
  [ "$_envs" -gt 0 ] || die "the warm reported success but cached nothing"
}

# --- gh, on request -----------------------------------------------------------
#
# From a pinned release tarball, exactly like actionlint above: no
# Ubuntu-archive dependency, so an environment that cannot reach the archives
# can still have it, and the version is a decision rather than whatever the
# distro froze. The same 403-vs-redirect note as actionlint applies — a naive
# reachability probe against github.com reads as an egress block and is not
# one.
#
# No auth step, deliberately. These containers carry a GH_TOKEN sentinel the
# egress proxy substitutes with a real credential — but on Anthropic-hosted
# web sandboxes only for identity endpoints (user, rate_limit); every
# repo-scoped API path 403s by policy, which is why the flag is not for that
# surface (#257 lane map, #273). The gather scripts probe once and degrade to
# a gh-unauthorized sentinel there, and pass -R explicitly everywhere rather
# than trusting repo inference behind a proxy.

cap_gh() {
  if command -v gh >/dev/null 2>&1; then
    log "gh      : already present, left alone"
    return 0
  fi
  GH_VER=2.97.0
  fetch "https://github.com/cli/cli/releases/download/v${GH_VER}/gh_${GH_VER}_linux_amd64.tar.gz" \
    "$TMP/gh.tar.gz" \
    || die "could not download gh ${GH_VER}"
  tar -xzf "$TMP/gh.tar.gz" -C "$TMP" "gh_${GH_VER}_linux_amd64/bin/gh" \
    || die "could not unpack gh"
  install -m 0755 "$TMP/gh_${GH_VER}_linux_amd64/bin/gh" "$BIN_DIR/gh" \
    || die "could not install gh"
  log "gh      -> $(gh --version 2>/dev/null | head -1 || echo 'installed')"
}

# --- Developer Knowledge MCP, on request ---------------------------------------
#
# Registers one MCP server at user scope. The server needs an API key, and this
# function deliberately writes none: the environment that passes the flag holds
# an API credential (host developerknowledge.googleapis.com, header
# X-Goog-Api-Key) that the agent proxy attaches after the request leaves the VM,
# so the key never reaches the container. That works because Claude Code's own
# MCP connections go through the agent proxy too, not just the commands it runs
# -- which is what makes a keyless entry correct rather than broken.
#
# User scope, not a .mcp.json per repo, so the server travels with the
# environment that holds the credential rather than being an opt-in in every
# repo (#439). It cannot clobber repo config: .mcp.json is project scope, a
# different file, and outranks user scope when both name the same server --
# Claude Code loads the entry from the highest-precedence source whole.
#
# jq rather than `claude mcp add`, for the same reason --with-hooks merges
# settings.json with jq: the claude binary is not guaranteed to be on PATH at
# setup-script time, and jq edits exactly one key. Everything else in
# ~/.claude.json -- account state, other servers -- is carried through
# unchanged, and the file stays 0600. A file that is not a JSON object is left
# alone and the capability degrades, rather than being replaced.
cap_devknowledge() {
  command -v jq >/dev/null 2>&1 || die "needs jq to edit ~/.claude.json"
  _dk_cfg="$HOME/.claude.json"
  _dk_src="$_dk_cfg"
  if [ -f "$_dk_cfg" ]; then
    jq -e 'type == "object"' "$_dk_cfg" >/dev/null 2>&1 \
      || die "$_dk_cfg is not a JSON object; left it untouched"
  else
    _dk_src="$TMP/claude-json-empty"
    echo '{}' >"$_dk_src"
  fi
  jq --arg name google-developer-knowledge \
    --arg url https://developerknowledge.googleapis.com/mcp \
    '.mcpServers[$name] = {type: "http", url: $url}' \
    "$_dk_src" >"$TMP/claude-json-merged" \
    || die "could not add google-developer-knowledge to $_dk_cfg"
  # Written beside the target and renamed, so a failure cannot leave a
  # half-written ~/.claude.json, and created 0600 because the file holds
  # account state.
  (umask 077 && cat "$TMP/claude-json-merged" >"$_dk_cfg.bootstrap-tmp") \
    || die "could not write $_dk_cfg"
  mv "$_dk_cfg.bootstrap-tmp" "$_dk_cfg" || die "could not replace $_dk_cfg"
  log "mcp     -> google-developer-knowledge in $_dk_cfg (user scope; no key -- the environment's API credential supplies it)"
}

# --- golangci-lint, always ----------------------------------------------------
#
# Unconditional, unlike every other capability, because it replaces a binary
# rather than adding one: the sandbox image ships a golangci-lint built with an
# older Go, and golangci-lint refuses to lint a module whose go.mod targets a
# newer Go than the one it was built with. A flag would leave every Go session
# that did not know to pass it unable to lint at all (#280). Still a Tier 2
# capability -- a failed download degrades the container rather than aborting
# the run, the same as any other toolchain.
#
# The image's copy is overwritten in place, so there is one golangci-lint on
# PATH. A copy at or above the pin is left alone, so a resume downloads nothing
# and this never walks a container backwards.
#
# The pin is not a floor, it is CI's version. Two releases can disagree on
# formatting (their embedded gofmt differs), so a locally clean tree only stays
# clean in CI when both run the same release. The CI pin lives in
# the private infrastructure repository's Go workflows; move the two together. The same 403-vs-redirect note as actionlint applies to the download.
GCL_VER=2.14.0

golangci_ver() {
  # Prints the version of the golangci-lint on PATH, empty when there is none.
  # `--version` rather than `version --short`, which older releases lack.
  golangci-lint --version 2>/dev/null \
    | sed -n '1s/^golangci-lint has version v\{0,1\}\([0-9][0-9.]*\).*/\1/p'
}

cap_golangci() {
  _gcl_have=$(golangci_ver)
  if [ -n "$_gcl_have" ] \
    && [ "$(printf '%s\n%s\n' "$GCL_VER" "$_gcl_have" | sort -V | head -1)" = "$GCL_VER" ]; then
    log "golangci: $_gcl_have already present, left alone"
    return 0
  fi
  fetch "https://github.com/golangci/golangci-lint/releases/download/v${GCL_VER}/golangci-lint-${GCL_VER}-linux-amd64.tar.gz" \
    "$TMP/golangci-lint.tar.gz" \
    || die "could not download golangci-lint ${GCL_VER}"
  tar -xzf "$TMP/golangci-lint.tar.gz" -C "$TMP" "golangci-lint-${GCL_VER}-linux-amd64/golangci-lint" \
    || die "could not unpack golangci-lint"
  install -m 0755 "$TMP/golangci-lint-${GCL_VER}-linux-amd64/golangci-lint" "$BIN_DIR/golangci-lint" \
    || die "could not install golangci-lint"
  # A copy earlier on PATH would still be the one a session runs.
  [ "$(golangci_ver)" = "$GCL_VER" ] \
    || die "installed golangci-lint ${GCL_VER}, but PATH resolves $(command -v golangci-lint) at $(golangci_ver)"
  log "golangci-> $(command -v golangci-lint) ${GCL_VER} (was ${_gcl_have:-absent})"
}

# --- shims: timing wrappers for the toolchain (#625) ---------------------------
#
# One script, agent-shim, and a symlink to it per tool in ~/.claude/bin/shims/.
# The SessionStart telemetry hook puts that directory ahead on the Bash tool's
# PATH; nothing here edits PATH. Each call is timed and spooled through
# agent-telemetry, which is what says how long a watching user waits on these
# tools. git is shimmed only to see a session's first commit.
#
# Only for tools that resolve now. A shim for a tool that is not installed
# would make `command -v` lie to every script that asks whether it is there,
# precommit-claude-hook's missing-binary check among them. Rebuilt from empty
# each run, so a tool that has gone stops being shimmed.
#
# Runs after every other capability so the tools it looks for are installed,
# and only with --with-hooks, because the hook is what makes the shims reachable.
SHIM_TOOLS="semgrep markdownlint-cli2 cspell checkov terraform tflint shellcheck gitleaks actionlint hadolint trivy pre-commit git"

cap_shims() {
  fetch "$RAW/home/bin/agent-shim" "$TMP/agent-shim" \
    || die "could not fetch agent-shim from $REF"
  head -1 "$TMP/agent-shim" | grep -q '^#!' || die "fetched agent-shim is not a script"
  install -m 0755 "$TMP/agent-shim" "$CLAUDE_DIR/bin/agent-shim" \
    || die "could not install agent-shim"
  _sd="$CLAUDE_DIR/bin/shims"
  rm -rf "$_sd" || die "could not clear $_sd"
  mkdir -p "$_sd" || die "could not create $_sd"
  _made=""
  for _t in $SHIM_TOOLS; do
    # A tool not on PATH gets no shim, except in background mode: there the
    # toolchain is deferred, so nothing is on PATH yet. A shim with nothing
    # behind it waits for the deferred install, then runs the tool or says it
    # was not provided (agent-shim), and the git hook ignores a bare shim when
    # it looks for pre-commit.
    [ "$TOOLCHAIN" = background ] || command -v "$_t" >/dev/null 2>&1 || continue
    ln -s ../agent-shim "$_sd/$_t" || die "could not create the $_t shim"
    _made="${_made:+$_made }$_t"
  done
  log "shims   -> $_sd (${_made:-none})"
}

DEGRADED=

capability() {
  # capability <enabled> <name> <function>
  [ "$1" -eq 1 ] || return 0

  # set +e around the call because the subshell's status is the whole point
  # here: under the outer `set -e` a non-zero one would kill the script,
  # which is the behaviour this wrapper exists to prevent.
  _cap_start=$(now_s)
  set +e
  (
    set -e
    "$3"
  )
  _cap_rc=$?
  set -e
  # Timed whatever the outcome: a capability that spent 40s and then failed is
  # the interesting case, and recording only successes would hide it.
  _cap_secs=$(($(now_s) - _cap_start))
  record_timing "$2" "$_cap_secs"
  if [ -s "$TMP/step-timings" ]; then
    TIMINGS="$TIMINGS $(tr '\n' ' ' <"$TMP/step-timings" | sed 's/ $//')"
    : >"$TMP/step-timings"
  fi
  [ "$_cap_rc" -eq 0 ] && return 0

  # die wrote its message here on the way out of the subshell, where a
  # variable assignment could not have survived.
  _why=$(cat "$FAIL_FILE" 2>/dev/null || echo "no reason recorded")
  : >"$FAIL_FILE" 2>/dev/null || true
  DEGRADED="${DEGRADED:+$DEGRADED }$2"
  log "WARN    : $2 did not install -- $_why"
  log "          continuing without it; this container is degraded, not broken"
  return 0
}

# Which capabilities this run owns. Eager does everything. Background defers
# the toolchain (precommit, its warm, golangci) and installs the git hook in its
# place. Run is that deferred toolchain and nothing else (ADR-0021, 2026-11-10
# amendment).
TC_TOOLS=1
TC_SETUP=1
TC_DEFER=0
case "$TOOLCHAIN" in
  background)
    TC_TOOLS=0
    TC_DEFER=1
    ;;
  run) TC_SETUP=0 ;;
esac
WANT_PRECOMMIT=$((WITH_PRECOMMIT * TC_TOOLS))
WANT_DEFER=$((WITH_PRECOMMIT * TC_DEFER))

capability $((WITH_GCLOUD * TC_SETUP)) gcloud cap_gcloud
capability "$WANT_PRECOMMIT" precommit cap_precommit
capability "$WANT_DEFER" githook install_git_hook
capability "$WANT_DEFER" toolchain-defer cap_toolchain_defer
# Separate from cap_precommit, not folded into it, because they fail
# differently. Without pre-commit there is no gate at all; without the warm the
# gate is present and the first commit in a fresh container pays the build for
# it. Its own entry means `degraded=` says which of the two happened, and
# `timings` carries its duration rather than burying it in the install's (#441).
capability "$WANT_PRECOMMIT" precommit-warm cap_precommit_warm
capability $((WITH_GH * TC_SETUP)) gh cap_gh
capability $((WITH_DEVKNOWLEDGE * TC_SETUP)) devknowledge cap_devknowledge
capability "$TC_TOOLS" golangci cap_golangci
capability $((WITH_HOOKS * TC_SETUP)) shims cap_shims

# precommit_retry: one more attempt at each tool pc_tool recorded as failed,
# now that every other capability has run (see pc_tool). It runs at the top
# level, not in a capability subshell, so pc_tool's own subshell is what keeps
# a second `die` from ending the run. Whatever still fails is named in
# `degraded=` as precommit.<name>.
precommit_retry() {
  # Eager: one retry, straight away, because the first prompt is waiting.
  # Run (the deferred toolchain): nobody is watching, so up to three more
  # rounds 30, 60 and 120 s apart, which covers the minutes-long stalls seen
  # at container start.
  _pr_rounds=1
  _pr_gap=0
  if [ "$TOOLCHAIN" = run ]; then
    _pr_rounds=3
    _pr_gap=30
  fi
  _pr_round=0
  while [ -s "$TMP/precommit-failed" ] && [ "$_pr_round" -lt "$_pr_rounds" ]; do
    _pr_round=$((_pr_round + 1))
    # .retry, then .retry2 and .retry3: one timing key per attempt.
    STEP_SUFFIX=.retry
    [ "$_pr_round" -eq 1 ] || STEP_SUFFIX=".retry$_pr_round"
    if [ "$_pr_gap" -gt 0 ]; then
      log "retry   : waiting ${_pr_gap}s before retry round $_pr_round"
      sleep "$_pr_gap"
      _pr_gap=$((_pr_gap * 2))
    fi
    mv "$TMP/precommit-failed" "$TMP/precommit-failed.prev"
    while read -r _pr_name _pr_fn; do
      log "retry   : precommit.$_pr_name, once more after the other capabilities"
      pc_tool "$_pr_name" "$_pr_fn" </dev/null
    done <"$TMP/precommit-failed.prev"
  done
  STEP_SUFFIX=
  if [ -s "$TMP/step-timings" ]; then
    TIMINGS="$TIMINGS $(tr '\n' ' ' <"$TMP/step-timings" | sed 's/ $//')"
    : >"$TMP/step-timings"
  fi
  if [ -s "$TMP/precommit-failed" ]; then
    while read -r _pr_name _pr_fn; do
      DEGRADED="${DEGRADED:+$DEGRADED }precommit.$_pr_name"
    done <"$TMP/precommit-failed"
  fi
}
if [ "$WANT_PRECOMMIT" -eq 1 ]; then
  precommit_retry
fi

# terraform_outcome: the manifest's terraform= value. It reports what happened,
# not what was requested, because the manifest is read as an attestation.
# Terraform installs partway through cap_precommit, so a precommit capability
# that dies before that step (a stalled hadolint download, say) leaves no
# terraform here, and the requested flag would still say 1. Prints 1
# (installed), 0 (not attempted: --no-terraform or
# --no-precommit, which installs nothing, per cloud/README.md) or `missing`
# (attempted, not installed).
terraform_outcome() {
  if [ "$WITH_TERRAFORM" -ne 1 ] || [ "$WITH_PRECOMMIT" -ne 1 ]; then
    echo 0
  elif [ "${TOOLCHAIN:-eager}" = background ]; then
    # Not installed by this run, and not missing: the deferred run reports it
    # in the toolchain manifest.
    echo deferred
  elif [ -f "$TMP/terraform-installed" ]; then
    echo 1
  else
    echo missing
  fi
}
TERRAFORM_OUTCOME=$(terraform_outcome)
if [ "$TERRAFORM_OUTCOME" = missing ]; then
  # Named separately from `precommit`, which may also be degraded. That says why
  # the gate is short; this says which tool a session cannot run. A failed
  # pc_terraform has already said so as precommit.terraform.
  case " $DEGRADED " in
    *" precommit.terraform "*) ;;
    *) DEGRADED="${DEGRADED:+$DEGRADED }terraform" ;;
  esac
  TERRAFORM_OUTCOME=0
fi

# --- the manifest -------------------------------------------------------------
#
# Records what this run installed, so a later session can tell how old its
# container is. Nothing else knows: a cloud environment re-runs its setup script
# only when the script text changes, the allowed hosts change, or roughly seven
# days pass, so pushing to a branch does not reach new sessions -- they keep
# restoring the snapshot built the first time (#246).
#
# Skills, policy and helper scripts have no server on the other end to refuse a
# stale client the way the credential helper's broker can (#182), so the skew is
# silent unless something writes down what it did.
#
# `resolved` and `kind` (ref | pin | unresolved) were worked out at the top of
# the run, because everything is fetched from that commit; the manifest records
# them.

MANIFEST="$AGENTS_DIR/.bootstrap-manifest"
RECORD_KIND=bootstrap
# The deferred toolchain run writes the same fields into a manifest of its own,
# and spools it under its own kind: the setup run's manifest is what a session
# reads to judge the container's age, and a build must not be counted twice.
if [ "$TOOLCHAIN" = run ]; then
  MANIFEST="$AGENTS_DIR/toolchain/manifest"
  RECORD_KIND=toolchain
fi
mkdir -p "$(dirname "$MANIFEST")"

TOTAL_SECS=$(($(now_s) - BOOT_START))
record_timing total "$TOTAL_SECS"

# ok vs degraded is the Tier 2 verdict: the toolkit is present either way --
# a missing one is fatal and never reaches here -- and `degraded` says some
# capability is not. Named rather than counted, because "which" is the only
# form of the answer anyone can act on.
if [ "$HOME_RW" = no ]; then
  DEGRADED="${DEGRADED:+$DEGRADED }policy-and-skills:home-read-only"
fi
if [ -n "$DEGRADED" ]; then
  manifest_status=degraded
else
  manifest_status=ok
fi

{
  # Written only here, at the end of a run that reached it. The exit trap
  # writes status=failed instead, so the three are mutually exclusive and a
  # reader never has to date one against another. A manifest from before
  # this line existed carries no status at all, which readers take as ok --
  # it could only have been written by a run that finished.
  echo "status=$manifest_status"
  echo "degraded=$DEGRADED"
  echo "ref=$REF"
  echo "ref_kind=$kind"
  echo "sha=$resolved"
  # Which repository `sha` is a commit of. The currency check resolves the ref
  # against this, so a rehearsal container is compared with what it was built
  # from.
  echo "source=$SOURCE_REPO"
  echo "source_prefix=$SOURCE_PREFIX"
  echo "installed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "profile=$PROFILE"
  # Empty when $HOME was read-only: the list says what is installed, and
  # nothing is.
  if [ "$HOME_RW" = yes ]; then
    echo "skills=$SKILLS $COMPOSED_SKILLS"
    echo "composed_skills=$COMPOSED_SKILLS"
  else
    echo "skills="
    echo "composed_skills="
  fi
  # Path-scoped rule files under ~/.claude/rules/. Empty for a Codex profile
  # and for a read-only $HOME.
  echo "rules=$RULES_INSTALLED"
  echo "helpers=$BIN_SCRIPTS"
  # Where the commands went (system, user or an explicit prefix), and whether
  # the caller's PATH reaches them. `no` is the line to read when a session
  # cannot find a tool this run reports installing.
  echo "install_mode=$INSTALL_MODE"
  # no = $HOME was read-only: state lives under agents_dir, and policy and
  # skills were not installed. The reader finds the manifest by this path.
  echo "home_writable=$HOME_RW"
  echo "agents_dir=$AGENTS_DIR"
  if [ "$HOME_RW" = no ]; then
    echo "policy=not-installed reason=home-read-only"
  fi
  echo "bin_dir=$BIN_DIR"
  echo "bin_dir_on_path=$BIN_ON_PATH"
  echo "precommit=$WITH_PRECOMMIT"
  # eager, background (deferred: see toolchain/manifest) or run
  echo "toolchain=$TOOLCHAIN"
  # How many pre-commit hook environments the warm left in the cache. 0 on a
  # container that never warmed one, which is the difference between "the gate
  # is installed" and "the gate can run without a two-minute build" (#441).
  # The duration is in `timings` as precommit-warm.
  echo "precommit_envs=$(cat "$TMP/warm-envs" 2>/dev/null || echo 0)"
  echo "gcloud=$WITH_GCLOUD"
  echo "terraform=$TERRAFORM_OUTCOME"
  echo "hooks=$WITH_HOOKS"
  echo "gh=$WITH_GH"
  echo "devknowledge=$WITH_DEVKNOWLEDGE"
  # The version a session will actually run, not the pin: a degraded install
  # leaves the image's own copy, and `none` means there is none on PATH.
  echo "golangci=$(golangci_ver | grep . || echo none)"
  # Machine-readable timing, so a regression is a diff between two runs rather
  # than someone's memory of how long it used to take. `timings` is
  # space-separated name=Ns pairs; absent names did not run.
  echo "duration_seconds=$TOTAL_SECS"
  echo "timings=$TIMINGS"
  # See BOOTSTRAP_SESSION above: `unknown` means the setup phase could not see
  # a session id, and session-cache-verdict falls back to a time delta.
  echo "built_in_session=$BOOTSTRAP_SESSION"
} >"$MANIFEST"
log "manifst -> $MANIFEST ($kind $(echo "$resolved" | cut -c1-12))"

# Hand the manifest to the telemetry spool. Spool-first on purpose: the setup
# phase runs before Claude Code launches, and the vendor documents that setup
# script requests never receive a network secret, so a ship from here would be
# unauthenticated in a proxy-injected environment. The spool is shipped later, by
# the SessionStart hook. Best effort: telemetry is never why a bootstrap fails.
"$BIN_DIR/agent-telemetry" record "$RECORD_KIND" "$MANIFEST" >/dev/null 2>&1 || true

# The deferred run's outcome, for toolchain-start and the git hook that wait on
# it. Written last, so `done` never precedes the manifest it summarises.
if [ "$TOOLCHAIN" = run ]; then
  # tmp then mv, for the same reason as record_failure: a reader polls this.
  case "$manifest_status" in
    ok) echo "done" >"$AGENTS_DIR/toolchain/state.tmp" ;;
    *) echo "$manifest_status" >"$AGENTS_DIR/toolchain/state.tmp" ;;
  esac
  mv -f "$AGENTS_DIR/toolchain/state.tmp" "$AGENTS_DIR/toolchain/state"
fi

# --- report -------------------------------------------------------------------
#
# The pinned ref is logged because a cached cloud environment can serve an older
# bootstrap than the one in main, and nothing else in a session says which
# vintage it is running.

log "timing : $TIMINGS"

if [ -n "$DEGRADED" ]; then
  log "done, from ${REF} at $(date -u +%Y-%m-%dT%H:%M:%SZ) -- DEGRADED, missing: $DEGRADED"
  log "note: the toolkit installed; the capabilities above did not. Re-running"
  log "      the bootstrap retries them."
else
  log "done, from ${REF} at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
fi
# Repeated at the end, where a reader of the log actually looks.
if [ "$BIN_ON_PATH" = no ]; then
  log "WARN    : $BIN_DIR is not on PATH -- add it to the environment, or"
  log "          sessions will not find what this run installed there."
fi
log "note: commands and skills are read when Claude Code starts, so a session"
log "      already running will not see them until it restarts or resumes."
