# Point Windows' PowerShell profiles at the chezmoi-managed one — Windows.
#
# The profile lives at ~/.config/powershell/Microsoft.PowerShell_profile.ps1,
# which is where pwsh looks on macOS and Linux. On Windows neither PowerShell
# reads it: pwsh 7 reads <Documents>\PowerShell\ and Windows PowerShell 5.1
# reads <Documents>\WindowsPowerShell\. Without this script, dotup and every
# other custom function is missing from a fresh Windows terminal (#467).
#
# <Documents> comes from GetFolderPath rather than $HOME\Documents because
# OneDrive commonly redirects it, and $PROFILE follows the redirect.
#
# Appends a marked loader block rather than owning the file, so anything
# already in a profile (or added by an installer later) is kept. The marker
# makes re-runs a no-op.
#
# Exits 0 unconditionally. A profile that cannot be written must never fail
# a chezmoi apply.

$marker = "# dotfiles: load the chezmoi-managed profile (#467)"
$loader = @"

$marker
`$dotfilesProfile = Join-Path `$HOME '.config\powershell\Microsoft.PowerShell_profile.ps1'
if (Test-Path `$dotfilesProfile) { . `$dotfilesProfile }
"@

$docs = [Environment]::GetFolderPath('MyDocuments')
if (-not $docs) {
    Write-Host "link-powershell-profile: cannot resolve the Documents folder - skipping." -ForegroundColor Yellow
    exit 0
}

foreach ($shellDir in 'PowerShell', 'WindowsPowerShell') {
    $path = Join-Path (Join-Path $docs $shellDir) 'Microsoft.PowerShell_profile.ps1'
    try {
        if ((Test-Path -LiteralPath $path) -and
            (Select-String -LiteralPath $path -SimpleMatch $marker -Quiet)) {
            continue
        }
        New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
        Add-Content -LiteralPath $path -Value $loader
        Write-Host "[OK] Linked $path to the dotfiles profile" -ForegroundColor Green
    } catch {
        Write-Host "link-powershell-profile: could not update $path - $_" -ForegroundColor Yellow
    }
}

exit 0
