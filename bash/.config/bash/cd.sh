# If not running interactively, don't do anything
if [[ $INTERACTIVE -eq 0 ]]; then return; fi

# CD to home folder (WSL hack)
cd ~