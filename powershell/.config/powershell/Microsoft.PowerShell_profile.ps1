# Exit if env var TERM_PROGRAM is set to vscode
# This prevents oh-my-posh from disrupting CoPilot terminal commands
if ($env:TERM_PROGRAM -eq "vscode") { return }

# Constants
$ThemeUrl = "https://raw.githubusercontent.com/pmgledhill102/dotfiles/main/ohmyposh/theme.yaml"
$CacheDir = Join-Path $HOME ".cache\ohmyposh"
$LocalTheme = Join-Path $CacheDir "cached-theme.yaml"
$EtagFile = Join-Path $CacheDir "etag.txt"

# Ensure cache dir exists
if (-not (Test-Path $CacheDir)) {
    New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null
}

# Function to update theme in background
function Update-ThemeInBackground {
    Start-Job -ScriptBlock {
        param($ThemeUrl, $LocalTheme, $EtagFile)

        try {
            $headers = @{}
            if (Test-Path $EtagFile) {
                $etag = Get-Content $EtagFile -ErrorAction SilentlyContinue
                if ($etag) {
                    $headers["If-None-Match"] = $etag
                }
            }

            $response = Invoke-WebRequest -Uri $ThemeUrl -Headers $headers -UseBasicParsing -ErrorAction Stop

            if ($response.StatusCode -eq 200) {
                $response.Content | Set-Content $LocalTheme -Encoding UTF8
                if ($response.Headers.ETag) {
                    $response.Headers.ETag | Set-Content $EtagFile
                }
            }
        } catch {
            # Silent fail
        }
    } -ArgumentList $ThemeUrl, $LocalTheme, $EtagFile | Out-Null
}

# Load Oh My Posh with local cached theme
if (Test-Path $LocalTheme) {
    oh-my-posh init pwsh --config $LocalTheme | Invoke-Expression
} else {
    # fallback (blocking) on first launch
    try {
        Invoke-WebRequest -Uri $ThemeUrl -OutFile $LocalTheme -UseBasicParsing -ErrorAction Stop
        oh-my-posh init pwsh --config $LocalTheme | Invoke-Expression
    } catch {
        Write-Warning "Unable to load Oh My Posh theme."
    }
}

# Update the theme in the background
Update-ThemeInBackground
