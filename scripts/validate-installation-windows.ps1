# Windows Post-Installation Validation Script
# Validates that the Windows dotfiles installation is working correctly

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"

if ($Verbose) {
    $VerbosePreference = "Continue"
}

# Refresh PATH from registry to pick up newly installed tools
# This is necessary because the installation runs in a different session
Write-Host "Refreshing environment PATH..."
try {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
    Write-Host "PATH refreshed from registry"
    Write-Host ""
} catch {
    Write-Host "WARNING: Failed to refresh PATH"
    Write-Host "Error: $_"
    Write-Host ""
}

Write-Host "=================================="
Write-Host "Post-Installation Validation (Windows)"
Write-Host "=================================="
Write-Host ""

$script:FailedTests = 0
$script:PassedTests = 0

function Test-Validation {
    param(
        [string]$Description,
        [scriptblock]$TestCommand
    )
    
    try {
        $result = & $TestCommand
        if ($result -or $LASTEXITCODE -eq 0) {
            Write-Host "[PASS] $Description" -ForegroundColor Green
            $script:PassedTests++
            return $true
        } else {
            Write-Host "[FAIL] $Description" -ForegroundColor Red
            $script:FailedTests++
            return $false
        }
    } catch {
        Write-Host "[FAIL] $Description" -ForegroundColor Red
        if ($Verbose) {
            Write-Host "  Error: $_" -ForegroundColor Red
        }
        $script:FailedTests++
        return $false
    }
}

# Validate PowerShell Configuration
Write-Host "Validating PowerShell configuration..."
Write-Host "-----------------------------------"

Test-Validation "PowerShell profile exists" {
    $profilePath = "$HOME\.config\powershell\Microsoft.PowerShell_profile.ps1"
    Test-Path $profilePath
}

Test-Validation "PowerShell profile uses Starship" {
    $profilePath = "$HOME\.config\powershell\Microsoft.PowerShell_profile.ps1"
    if (Test-Path $profilePath) {
        (Get-Content $profilePath -Raw) -match "starship init"
    } else {
        $false
    }
}

# Validate Starship Prompt
Write-Host ""
Write-Host "Validating Starship prompt..."
Write-Host "-----------------------------------"

Test-Validation "Starship is in PATH" {
    Get-Command starship -ErrorAction SilentlyContinue
}

Test-Validation "Starship config exists" {
    Test-Path "$HOME\.config\starship.toml"
}

Test-Validation "Starship version can be queried" {
    starship --version | Out-Null
    $LASTEXITCODE -eq 0
}

# Additional prompt functionality tests (T024)
Write-Host ""
Write-Host "Validating prompt theme functionality..."
Write-Host "-----------------------------------"

Test-Validation "Starship config has directory customization" {
    $configPath = "$HOME\.config\starship.toml"
    if (Test-Path $configPath) {
        (Get-Content $configPath -Raw) -match "directory"
    } else {
        $false
    }
}

Test-Validation "Starship config has git_branch customization" {
    $configPath = "$HOME\.config\starship.toml"
    if (Test-Path $configPath) {
        (Get-Content $configPath -Raw) -match "git_branch"
    } else {
        $false
    }
}

Test-Validation "Starship config has character customization" {
    $configPath = "$HOME\.config\starship.toml"
    if (Test-Path $configPath) {
        (Get-Content $configPath -Raw) -match "character"
    } else {
        $false
    }
}

# Test prompt rendering
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Test-Validation "Prompt renders in current directory" {
        $prompt = starship prompt --terminal-width=80 -ErrorAction SilentlyContinue 2>&1
        -not [string]::IsNullOrWhiteSpace($prompt)
    }
} else {
    Write-Host "⚠ Prompt rendering test skipped (starship not in PATH)" -ForegroundColor Yellow
}

# Validate Windows Terminal Configuration
Write-Host ""
Write-Host "Validating Windows Terminal configuration..."
Write-Host "-----------------------------------"

$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
Test-Validation "Windows Terminal settings exist" {
    Test-Path $wtSettingsPath
}

if (Test-Path $wtSettingsPath) {
    Test-Validation "Windows Terminal uses JetBrains Mono Nerd Font" {
        (Get-Content $wtSettingsPath -Raw) -match "JetBrainsMono Nerd Font"
    }
}

# Validate Installed Tools
Write-Host ""
Write-Host "Validating installed tools..."
Write-Host "-----------------------------------"

$tools = @(
    "git",
    "chezmoi",
    "starship",
    "age",
    "pwsh"
)

foreach ($tool in $tools) {
    Test-Validation "$tool is installed" {
        Get-Command $tool -ErrorAction SilentlyContinue
    }
}

# Validate optional power user tools
$optionalTools = @(
    "delta",
    "lazygit",
    "code"
)

Write-Host ""
Write-Host "Validating optional tools..."
Write-Host "-----------------------------------"

foreach ($tool in $optionalTools) {
    if (Get-Command $tool -ErrorAction SilentlyContinue) {
        Write-Host "[PASS] $tool is installed" -ForegroundColor Green
        $script:PassedTests++
    } else {
        Write-Host "[WARN] $tool is not installed (optional)" -ForegroundColor Yellow
    }
}

# Validate Git Configuration
Write-Host ""
Write-Host "Validating Git configuration..."
Write-Host "-----------------------------------"

Test-Validation "Git config exists" {
    Test-Path "$HOME\.gitconfig"
}

Test-Validation "Global gitignore exists" {
    Test-Path "$HOME\.gitignore_global"
}

if (Get-Command delta -ErrorAction SilentlyContinue) {
    Test-Validation "Git is configured to use delta" {
        $pager = git config --get core.pager
        $pager -match "delta"
    }
}

# Validate Chezmoi
Write-Host ""
Write-Host "Validating chezmoi..."
Write-Host "-----------------------------------"

Test-Validation "Chezmoi is in PATH" {
    Get-Command chezmoi -ErrorAction SilentlyContinue
}

Test-Validation "Chezmoi source directory exists" {
    $sourcePath = chezmoi source-path 2>&1
    $LASTEXITCODE -eq 0
}

Test-Validation "Chezmoi can list managed files" {
    chezmoi managed | Out-Null
    $LASTEXITCODE -eq 0
}

# Validate Age Encryption
Write-Host ""
Write-Host "Validating age encryption..."
Write-Host "-----------------------------------"

Test-Validation "Age is in PATH" {
    Get-Command age -ErrorAction SilentlyContinue
}

Test-Validation "Age-keygen is in PATH" {
    Get-Command age-keygen -ErrorAction SilentlyContinue
}

# Validate Registry Settings
Write-Host ""
Write-Host "Validating Windows registry settings..."
Write-Host "-----------------------------------"

Test-Validation "Long Paths are enabled" {
    $longPathsKey = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
    $value = Get-ItemProperty -Path $longPathsKey -Name "LongPathsEnabled" -ErrorAction SilentlyContinue
    $value.LongPathsEnabled -eq 1
}

Test-Validation "Developer Mode is enabled" {
    $devModeKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
    $value = Get-ItemProperty -Path $devModeKey -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
    $value.AllowDevelopmentWithoutDevLicense -eq 1
}

# Validate Environment Variables
Write-Host ""
Write-Host "Validating environment variables..."
Write-Host "-----------------------------------"

Test-Validation "HOME environment variable is set" {
    -not [string]::IsNullOrEmpty($env:HOME)
}

Test-Validation "XDG_CONFIG_HOME is set" {
    -not [string]::IsNullOrEmpty($env:XDG_CONFIG_HOME)
}

# VS Code Configuration
Write-Host ""
Write-Host "Validating VS Code configuration..."
Write-Host "-----------------------------------"

Test-Validation "VS Code settings exist" {
    Test-Path "$HOME\.config\Code\User\settings.json"
}

Test-Validation "VS Code keybindings exist" {
    Test-Path "$HOME\.config\Code\User\keybindings.json"
}

# Validate JetBrains Mono Nerd Font
Write-Host ""
Write-Host "Validating fonts..."
Write-Host "-----------------------------------"

Test-Validation "JetBrains Mono Nerd Font is installed" {
    # Check if font is installed in Windows
    $fontPath1 = "$env:WINDIR\Fonts\JetBrainsMonoNerdFont-Regular.ttf"
    $fontPath2 = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts\JetBrainsMonoNerdFont-Regular.ttf"
    (Test-Path $fontPath1) -or (Test-Path $fontPath2)
}

# Summary
Write-Host ""
Write-Host "=================================="
Write-Host "Validation Summary"
Write-Host "=================================="
Write-Host "Passed: $script:PassedTests" -ForegroundColor Green
Write-Host "Failed: $script:FailedTests" -ForegroundColor Red
Write-Host ""

$totalTests = $script:PassedTests + $script:FailedTests
$percentPassed = if ($totalTests -gt 0) { [math]::Round(($script:PassedTests / $totalTests) * 100, 2) } else { 0 }
Write-Host "Success Rate: $percentPassed%" -ForegroundColor $(if ($percentPassed -ge 80) { "Green" } elseif ($percentPassed -ge 50) { "Yellow" } else { "Red" })
Write-Host ""

# Export test counts for CI reporting
$countsFile = "$env:TEMP\validation_counts.txt"
@"
PASSED_TESTS=$($script:PassedTests)
FAILED_TESTS=$($script:FailedTests)
TOTAL_TESTS=$totalTests
"@ | Out-File -FilePath $countsFile -Encoding utf8
Write-Verbose "Test counts written to $countsFile"

if ($script:FailedTests -eq 0) {
    Write-Host "All validations passed! Your dotfiles are properly installed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some validations failed. Please review the output above." -ForegroundColor Red
    exit 1
}
