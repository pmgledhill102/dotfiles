# Powerlevel10k configuration

# For a list of all options, see:
# https://github.com/romkatv/powerlevel10k/blob/master/config/p10k-rainbow.zsh

# You can edit this file directly and save it to ~/.p10k.zsh.
# Or, you can run `p10k configure` to launch the configuration wizard.

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Theme for Powerlevel10k
# See https://github.com/romkatv/powerlevel10k#themes
POWERLEVEL9K_MODE='nerdfont-complete'

# Left prompt segments.
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(os_icon dir vcs)

# Right prompt segments.
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status command_execution_time background_jobs)
