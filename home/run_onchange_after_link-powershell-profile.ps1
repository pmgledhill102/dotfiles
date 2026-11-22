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
# Puts a marked loader block at the TOP of each profile rather than owning the
# file, so anything already there (or added by an installer later) is kept.
# The top, not the end: a hand-written profile can `return` early (a VS Code
# guard, a leftover debug line) and an appended loader never runs (#471). A
# block an earlier version appended is moved up. Already at the top: no-op.
#
# Written back as UTF-8 with a BOM: chezmoi runs this under Windows
# PowerShell 5.1, which reads a BOM-less profile as ANSI and would mangle any
# non-ASCII text in it.
#
# Exits 0 unconditionally. A profile that cannot be written must never fail
# a chezmoi apply.

$marker = "# dotfiles: load the chezmoi-managed profile (#467)"
$loader = @"
$marker
`$dotfilesProfile = Join-Path `$HOME '.config\powershell\Microsoft.PowerShell_profile.ps1'
if (Test-Path `$dotfilesProfile) { . `$dotfilesProfile }
"@ -replace '\r?\n', "`r`n"
# The block exactly as written, wherever it sits: the marker line and the two
# lines after it, plus a blank line before it if there is one.
$existing = '(\r?\n)?' + [regex]::Escape($marker) + '\r?\n[^\r\n]*\r?\n[^\r\n]*(\r?\n)?'
$utf8Bom = New-Object System.Text.UTF8Encoding $true

$docs = [Environment]::GetFolderPath('MyDocuments')
if (-not $docs) {
    Write-Host "link-powershell-profile: cannot resolve the Documents folder - skipping." -ForegroundColor Yellow
    exit 0
}

foreach ($shellDir in 'PowerShell', 'WindowsPowerShell') {
    $path = Join-Path (Join-Path $docs $shellDir) 'Microsoft.PowerShell_profile.ps1'
    try {
        $text = ''
        if (Test-Path -LiteralPath $path) {
            $text = [IO.File]::ReadAllText($path).TrimStart([char]0xFEFF)
        }
        if ($text.StartsWith($marker)) { continue }

        $rest = [regex]::Replace($text, $existing, "`r`n").TrimStart("`r", "`n")
        $new = if ($rest) { $loader + "`r`n`r`n" + $rest } else { $loader + "`r`n" }
        New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
        [IO.File]::WriteAllText($path, $new, $utf8Bom)
        Write-Host "[OK] Linked $path to the dotfiles profile" -ForegroundColor Green
    } catch {
        Write-Host "link-powershell-profile: could not update $path - $_" -ForegroundColor Yellow
    }
}

exit 0
