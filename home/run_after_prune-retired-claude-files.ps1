# Remove Claude config files that agentic-coding-config has retired — Windows.
#
# PowerShell sibling of run_after_prune-retired-claude-files.sh, which is
# ignored on Windows because there is no /bin/sh to execute it. See #375.
#
# The .sh script is deliberately dumb: it delegates to the upstream pruner at
# ~/.claude/bin/claude-prune-retired, so all the logic lives in the repo that
# owns the retirements. That option is not available here — the upstream
# pruner is POSIX shell, so a native-Windows machine cannot run it. This
# script therefore reimplements it against the same input file,
# ~/.claude/retired-paths.
#
# The duplication is the accepted cost of covering Windows at all. What bounds
# the drift is that the *list* stays upstream and upstream CI validates it —
# only the removal logic exists twice, and that is the half least likely to
# change. Any change to the pruning contract needs both implementations.
#
# run_after_ (not run_onchange_): what actually changes is
# ~/.claude/retired-paths, which arrives via the external and is invisible to
# this script's hash, so run_onchange_ would fire once and never again. The
# pruning is idempotent and cheap, so running it on every apply is both
# correct and simpler. Same reasoning as the .sh sibling.
#
# Exits 0 unconditionally. A bad list entry must never fail a chezmoi apply.
#
# Usage: run_after_prune-retired-claude-files.ps1 [-DryRun]
# chezmoi invokes it with no arguments; -DryRun is for running it by hand.

param([switch]$DryRun)

$ErrorActionPreference = "Stop"

$claudeDir = if ($env:CLAUDE_DIR) { $env:CLAUDE_DIR } else { Join-Path $HOME ".claude" }
$list = Join-Path $claudeDir "retired-paths"

# No list means nothing has been retired yet, or this machine predates the
# mechanism. Either way there is nothing to do. Also covers the machine types
# where the ~/.claude external does not deploy at all (see #389).
if (-not (Test-Path -LiteralPath $list -PathType Leaf)) { exit 0 }

try {
    $lines = Get-Content -LiteralPath $list
} catch {
    Write-Warning "prune-retired-claude-files: cannot read ${list}: $_"
    exit 0
}

$pruned = 0

foreach ($line in $lines) {
    # Cast guards against $null from an empty file; strip trailing whitespace
    # (including the CR of a CRLF line ending) then skip blanks and comments.
    $path = ([string]$line) -replace '\s+$', ''
    if ($path -eq '' -or $path.StartsWith('#')) { continue }

    # Refuse anything that could escape ~/.claude/. A typo upstream would
    # otherwise delete an arbitrary file on every machine, on every apply.
    #
    # Deliberately broader than the POSIX pruner's "starts with /" test:
    # Windows also has drive-qualified (C:\...) and UNC (\\host\share)
    # absolute paths, neither of which that test catches. Refusing any '..'
    # anywhere — rather than just a '..' path segment — mirrors the upstream
    # check exactly, so the two agree on what counts as unsafe.
    if ($path -match '\.\.' -or $path -match '^[\\/]' -or $path -match '^[A-Za-z]:') {
        Write-Warning "prune-retired-claude-files: refusing unsafe entry: $path"
        continue
    }

    # The list is written with POSIX separators; normalise so log lines read
    # as native paths. Windows accepts either, so this is cosmetic there — but
    # using the platform separator rather than a hardcoded '\' keeps the script
    # runnable (and therefore testable) on a POSIX host too.
    $sep = [string][IO.Path]::DirectorySeparatorChar
    $target = Join-Path $claudeDir ($path -replace '/', $sep)

    # Already gone is a no-op — this is what makes repeated applies converge.
    if (-not (Test-Path -LiteralPath $target)) { continue }

    # Directories are out of scope: the retired set is individual commands and
    # scripts, and a stray directory entry should be looked at by a human.
    if (Test-Path -LiteralPath $target -PathType Container) {
        Write-Warning "prune-retired-claude-files: skipping directory: $path"
        continue
    }

    if ($DryRun) {
        Write-Host "would prune $target"
        $pruned++
        continue
    }

    # Per-entry catch, so one undeletable file (locked, permissions) does not
    # stop the remaining entries from being pruned.
    try {
        Remove-Item -LiteralPath $target -Force
        Write-Host "pruned $target"
        $pruned++
    } catch {
        Write-Warning "prune-retired-claude-files: could not remove ${target}: $_"
    }
}

if ($pruned -gt 0) {
    $verb = if ($DryRun) { "would prune" } else { "pruned" }
    Write-Host "prune-retired-claude-files: $verb $pruned path(s)"
}

exit 0
