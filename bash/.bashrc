# ~/.bashrc: executed by bash(1) for non-login shells.

###################################
### CONFIGURE VARS USED BY SCRIPTS

# MacOS or Linux?
export CURRENT_OS=$(uname)

#  Interactive Session?
case $- in
    *i*) export INTERACTIVE=1;;
      *) export INTERACTIVE=0;;
esac

###################################
### CUSTOMISATION SCRIPTS

# cycle all files in folder, in alphabetical order
export SH=bash
for DOTFILE in $(ls ~/.config/bash/*.sh | sort); do
	[ -r "$DOTFILE" ] && [ -f "$DOTFILE" ] && source "$DOTFILE";
done;
unset DOTFILE;
