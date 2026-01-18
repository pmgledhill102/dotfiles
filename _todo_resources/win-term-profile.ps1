# Generate a new GUID
$newGuid = [guid]::NewGuid()

# Define the new profile
$newProfile = @{
    "name" = "Dev"
    "colorScheme" = "Campbell"
    "commandline" = "\"C:\\Program Files\\PowerShell\\7\\pwsh.exe\""
    "font" = @{
        "face" = "JetBrainsMonoNL NFP"
    }
    "guid" = $newGuid
    "hidden" = $false
    "icon" = "ms-appx:///ProfileIcons/pwsh.png"
    "startingDirectory" = "c:\\dev"
}

# Load the current settings
$settingsPath = "$env:LOCALAPPDATA\\Packages\\Microsoft.WindowsTerminal_8wekyb3d8bbwe\\LocalState\\settings.json"
$settings = Get-Content -Path $settingsPath | ConvertFrom-Json

# Add the new profile
$settings.profiles.list += $newProfile

# Set the new profile as the default
$settings.defaultProfile = $newGuid

# Save the updated settings
$settings | ConvertTo-Json -Depth 100 | Set-Content -Path $settingsPath
