# Update dotfiles and reload the shell (does not install/upgrade packages)
#
# Windows counterpart to ~/.config/zsh/functions/dotup.zsh, and it keeps that
# function's most important property: it does not touch packages. An unguarded
# package install here would fire on every chezmoi update, which is the trap
# ADR-0005's dotup/brewup split exists to prevent.
#
# There is deliberately NO Windows counterpart to brewup (dotfiles#271). On
# macOS, Homebrew *is* the package manager, so brewup is a complete answer. On
# Windows it would cover winget only, while this machine also carries global
# npm packages, uv/Python tooling, cargo via Rustup and .NET SDK tools — so a
# "wingetup" would look symmetrical with macOS while covering a fraction of
# what brewup does. UniGetUI owns upgrades here instead; it spans all of those
# sources, and upgrading on a desktop is a discretionary act better done
# somewhere you can see what is changing.
#
# What stays declarative in this repo is the part that has to be: the package
# list and the pins in .chezmoi.toml, applied by
# run_once_install-packages-windows.ps1 on a fresh machine. Install is
# reproducible; upgrade is a judgement call.

function dotup {
    Write-Host "==> Updating dotfiles..." -ForegroundColor Cyan

    if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
        Write-Host "dotup: chezmoi is not installed or not in PATH." -ForegroundColor Red
        return
    }

    # --refresh-externals forces chezmoi externals (agentic-coding-config,
    # mounted at ~/.claude/) to re-fetch, bypassing their 168h refreshPeriod.
    # Without it a plain update re-applies the cached archive, so a merge
    # upstream can take up to a week to arrive. Cheap for a repo this small.
    #
    # No -v: verbose prints a full unified diff of every changed file, which
    # buries the run. The "config file template has changed" warning below is a
    # warning rather than verbose output, so it still surfaces either way.
    $updateLog = chezmoi update --refresh-externals 2>&1 | Tee-Object -Variable captured
    $captured | ForEach-Object { Write-Host $_ }

    # Auto-recover when chezmoi warns the rendered chezmoi.toml is stale —
    # typically a new [data.*] block was added to .chezmoi.toml.tmpl since the
    # last init, so downstream templates referencing the new key fail with
    # "map has no entry for key X". Re-init reuses stored promptChoiceOnce
    # answers, so it is non-interactive.
    if ($captured -match 'config file template has changed') {
        Write-Host "`n==> Config template changed - regenerating with 'chezmoi init'..." -ForegroundColor Yellow
        chezmoi init
        Write-Host "`n==> Re-applying with refreshed config..." -ForegroundColor Yellow
        chezmoi apply
    }

    Write-Host "`n==> Reloading PowerShell profile..." -ForegroundColor Cyan
    if (Test-Path $PROFILE) {
        # Dot-sourcing re-runs the profile in the current scope, which
        # re-imports every function in ~/.config/powershell/functions/ —
        # including any that only arrived in the update that just ran.
        . $PROFILE
        Write-Host "Profile reloaded."
    } else {
        Write-Host "No profile at $PROFILE - skipping reload." -ForegroundColor Yellow
    }

    Write-Host "`n==> All updates complete." -ForegroundColor Green
    Write-Host "Packages are not touched by dotup - UniGetUI owns upgrades on Windows (#271)." -ForegroundColor DarkGray
}
