# MacOS or Linux?
export CURRENT_OS=$(uname)

# Homebrew
if [ -d "/opt/homebrew" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -d "~/.linuxbrew" ]; then
  eval "$(~/.linuxbrew/bin/brew shellenv)"
elif [ -d "/home/linuxbrew" ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Oh My Posh
if [ "${CURRENT_OS}" = "Linux" ]; then
  # Required for Oh My Posh
  export PATH="$PATH:$HOME/bin"
fi
