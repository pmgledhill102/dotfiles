# PowerShell Profile - Cross-platform configuration
# This profile is managed by chezmoi and provides a consistent experience across Windows and WSL

# Initialize Starship prompt (unless in VS Code Copilot Chat terminal)
if ($env:VSCODE_COPILOT_CHAT_TERMINAL -ne "1") {
    $env:STARSHIP_CONFIG = "$HOME/.config/starship.toml"
    Invoke-Expression (&starship init powershell)
}

# Set PSReadLine options for better command line editing
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine
    
    # Enable predictive IntelliSense
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
    
    # Set up key handlers for navigation
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    
    # Enable syntax highlighting
    Set-PSReadLineOption -Colors @{
        Command = 'Yellow'
        Parameter = 'Green'
        Operator = 'Magenta'
        Variable = 'DarkGreen'
        String = 'Cyan'
        Number = 'DarkCyan'
        Type = 'DarkYellow'
        Comment = 'DarkGray'
    }
}

# Useful aliases
Set-Alias -Name g -Value git -ErrorAction SilentlyContinue
Set-Alias -Name ll -Value Get-ChildItem -ErrorAction SilentlyContinue
Set-Alias -Name la -Value Get-ChildItem -ErrorAction SilentlyContinue

# Custom functions
function .. { Set-Location .. }
function ... { Set-Location ../.. }
function .... { Set-Location ../../.. }

function touch {
    param([string]$file)
    if (Test-Path $file) {
        (Get-Item $file).LastWriteTime = Get-Date
    } else {
        New-Item -ItemType File -Path $file | Out-Null
    }
}

function which {
    param([string]$command)
    Get-Command -Name $command -ErrorAction SilentlyContinue | 
        Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}

# Git shortcuts
function gs { git status }
function ga { git add $args }
function gc { git commit $args }
function gp { git push $args }
function gl { git pull $args }
function gd { git diff $args }
function gco { git checkout $args }

# Chezmoi shortcuts
function cm { chezmoi $args }
function cma { chezmoi apply }
function cms { chezmoi status }
function cmd { chezmoi diff }

# Set environment variables for better Windows development experience
if ($IsWindows) {
    # Enable UTF-8 encoding
    $OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    
    # Set default editor if not already set
    if (-not $env:EDITOR) {
        if (Get-Command code -ErrorAction SilentlyContinue) {
            $env:EDITOR = "code --wait"
        } elseif (Get-Command notepad -ErrorAction SilentlyContinue) {
            $env:EDITOR = "notepad"
        }
    }
    
    # Set VISUAL to same as EDITOR
    if ($env:EDITOR -and -not $env:VISUAL) {
        $env:VISUAL = $env:EDITOR
    }
}

# Display welcome message
if ($Host.Name -eq "ConsoleHost") {
    Write-Host "PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor Cyan
    if (Get-Command starship -ErrorAction SilentlyContinue) {
        Write-Host "Starship prompt initialized" -ForegroundColor Green
    }
}
