if ($env:VSCODE_COPILOT_CHAT_TERMINAL -ne "1") {
    $env:STARSHIP_CONFIG = "$HOME/.config/starship.toml"
    Invoke-Expression (&starship init powershell)
}
