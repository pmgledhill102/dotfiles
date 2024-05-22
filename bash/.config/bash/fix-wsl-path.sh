# WSL appends all Windows PATH folders to the Linux PATH. This can cause issues with some tools. This
# script removes all Windows PATH folders from the Linux PATH.
# See <https://stackoverflow.com/questions/51336147/how-to-remove-the-win10s-path-from-wsl>

PATH=$(/usr/bin/printenv PATH | /usr/bin/perl -ne 'print join(":", grep { !/\/mnt\/[a-z]/ } split(/:/));')
