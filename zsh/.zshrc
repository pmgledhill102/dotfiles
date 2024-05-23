# Load all global dotfiles
export SH=zsh

for DOTFILE in $(ls ~/.config/bash/*.sh | sort); do
	[ -r "$DOTFILE" ] && [ -f "$DOTFILE" ] && source "$DOTFILE";
done;
unset DOTFILE;

# If not running interactively, don't do anything more
case $- in
    *i*) ;;
      *) return;;
esac

