# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not bash then quit
if [[ "$SH" != "zsh" ]]; then return; fi

# If not running interactively, don't do anything
if [[ $INTERACTIVE -eq 0 ]]; then return; fi

# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt extendedglob
bindkey -e
# End of lines configured by zsh-newuser-install

# The following lines were added by compinstall
zstyle :compinstall filename '/home/pmg102/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall
