# ~/.bashrc: executed by bash(1) for non-login shells.

# Env Var for the shell name
export SH=bash

###################################
### QUIT ON MAC
### - only zsh and pwsh supported

if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "Only zsh and pwsh are supported on MacOS"
  return
fi

###################################
### CONFIGURE VARS USED BY SCRIPTS

#  Interactive Session?
case $- in
    *i*) export INTERACTIVE=1;;
      *) export INTERACTIVE=0;;
esac

###################################
### CUSTOMISATION SCRIPTS

# cycle all files in folder, in alphabetical order
for DOTFILE in $(ls ~/.config/bash/*.sh | sort); do
	[ -r "$DOTFILE" ] && [ -f "$DOTFILE" ] && source "$DOTFILE";
done;
unset DOTFILE;
