#!/bin/sh
# Fonta's arch bootstrap script

### OPTIONS AND VARIABLES ###

while getopts ":a:r:b:p:h" o; do case "${o}" in
	h) printf "Optional arguments for custom use:\\n  -r: Dotfiles repository (local file or url)\\n  -p: Dependencies and programs csv (local file or url)\\n  -a: AUR helper (must have pacman-like syntax)\\n  -h: Show this message\\n" && exit 1 ;;
	r) dotfilesrepo=${OPTARG} && git ls-remote "$dotfilesrepo" || exit 1 ;;
	b) repobranch=${OPTARG} ;;
	p) progsfile=${OPTARG} ;;
	a) aurhelper=${OPTARG} ;;
	*) printf "Invalid option: -%s\\n" "$OPTARG" && exit 1 ;;
esac done

[ -z "$dotfilesrepo" ] && dotfilesrepo="https://github.com/fedfontana/dotto.git"
[ -z "$progsfile" ] && progsfile="https://raw.githubusercontent.com/fedfontana/fonta-bootstrap/master/progs.csv"
[ -z "$aurhelper" ] && aurhelper="yay"
[ -z "$repobranch" ] && repobranch="master"

### FUNCTIONS ###

installpkg(){ pacman --noconfirm --needed -S "$1" >/dev/null 2>&1 ;}

error() { printf "%s\n" "$1" >&2; exit 1; }

welcomemsg() 
{
	dialog --title "Welcome!" --msgbox "Welcome to Fonta's arch boostrap script!\\n\\nThis script will automatically install a fully-featured Linux desktop, which I use as my main machine.\\n\\n-Fonta" 10 60
}

preinstallmsg() 
{
	dialog --title "Let's get this party started!" --yes-label "Let's go!" --no-label "No, nevermind!" --yesno "The rest of the installation will now be totally automated, so you can sit back and relax.\\n\\nIt will take some time, but when done, you can relax even more with your complete system.\\n\\nNow just press <Let's go!> and the system will begin installation!" 13 60 || { clear; exit 1; }
}

refreshkeys() 
{
	dialog --infobox "Refreshing Arch Keyring..." 4 40
	pacman --noconfirm -S archlinux-keyring >/dev/null 2>&1
}

old_manualinstall() #something in the last line doesnt work???
{ # Installs $1 manually. Used only for AUR helper here.
	dialog --infobox "Installing \"$1\", an AUR helper..." 4 50
	mkdir -p "/tmp/$1"
	git clone --depth 1 "https://aur.archlinux.org/$1.git" "/tmp/$1" >/dev/null 2>&1
	sudo -u "$SUDO_USER" -D "/tmp/$1" makepkg --noconfirm -si >/dev/null 2>&1 || return 1
}

manualinstall() 
{ # Installs $1 manually. Used only for AUR helper here.
	dialog --infobox "Installing \"$1\", an AUR helper..." 4 50
	sudo -u "$SUDO_USER" git clone --depth 1 "https://aur.archlinux.org/$1.git" "/tmp/$1" >/dev/null 2>&1 ||
	cd "/tmp/$1"
	sudo -u "$SUDO_USER" makepkg --noconfirm -si >/dev/null 2>&1 || return 1
	cd
}

maininstall() 
{ # Installs all needed programs from main repo.
	dialog --title "FARBS Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 5 70
	installpkg "$1"
}

gitmakeinstall() 
{
	progname="$(basename "$1" .git)"
	dir="$repodir/$progname"
	dialog --title "FARBS Installation" --infobox "Installing \`$progname\` ($n of $total) via \`git\` and \`make\`. $(basename "$1") $2" 5 70
	sudo -u "$SUDO_USER" git clone --depth 1 "$1" "$dir" >/dev/null 2>&1 || { cd "$dir" || return 1 ; sudo -u "$SUDO_USER" git pull --force origin master;}
	cd "$dir" || exit 1
	make >/dev/null 2>&1
	make install >/dev/null 2>&1
	cd /tmp || return 1 ;
}

aurinstall() 
{
	dialog --title "FARBS Installation" --infobox "Installing \`$1\` ($n of $total) from the AUR. $1 $2" 5 70
	echo "$aurinstalled" | grep -q "^$1$" && return 1 #! isnt this the same as --needed???
	sudo -u "$SUDO_USER" $aurhelper -S --noconfirm "$1" >/dev/null 2>&1
}

pipinstall() 
{
	dialog --title "FARBS Installation" --infobox "Installing the Python package \`$1\` ($n of $total). $1 $2" 5 70
	[ -x "$(command -v "pip")" ] || installpkg python-pip >/dev/null 2>&1
	yes | pip install "$1"
}

#npminstall() {}

installationloop() 
{
	([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) || curl -Ls "$progsfile" | sed '/^#/d' > /tmp/progs.csv
	total=$(wc -l < /tmp/progs.csv)
	aurinstalled=$(pacman -Qqm)
	while IFS=, read -r tag program comment; do
		n=$((n+1))
		echo "$comment" | grep -q "^\".*\"$" && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
		case "$tag" in
			"A") aurinstall "$program" "$comment" ;;
			"G") gitmakeinstall "$program" "$comment" ;;
			"P") pipinstall "$program" "$comment" ;;
			*) maininstall "$program" "$comment" ;;
		esac
	done < /tmp/progs.csv ;
}

putgitrepo() 
{ # Downloads a gitrepo $1 and places the files in $2 only overwriting conflicts
	dialog --infobox "Downloading and installing config files..." 4 60
	[ -z "$3" ] && branch="master" || branch="$repobranch"
	dir=$(mktemp -d)
	[ ! -d "$2" ] && mkdir -p "$2"
	chown "$SUDO_USER":wheel "$dir" "$2"
	sudo -u "$SUDO_USER" git clone --recursive -b "$branch" --depth 1 --recurse-submodules "$1" "$dir" >/dev/null 2>&1
	sudo -u "$SUDO_USER" cp -rfT "$dir" "$2"
}

systembeepoff() 
{ 
	dialog --infobox "Getting rid of that retarded error beep sound..." 10 50
	rmmod pcspkr
	echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf ;
}

finalize()
{
	dialog --infobox "Preparing welcome message..." 4 50
	dialog --title "All done!" --msgbox "Congrats! Provided there were no hidden errors, the script completed successfully and all the programs and configuration files should be in place.\\n\\nTo run the new graphical environment, log out and log back in as your new user, then run the command \"startx\" to start the graphical environment (it will start automatically in tty1).\\n\\n.t Fonta" 12 80
}

### THE ACTUAL SCRIPT ###

# Update and install dialog.
pacman -Syu --noconfirm || error "Are you sure you're running this as the root user, are on an Arch-based distribution and have an internet connection?"

# Check if user is root on Arch distro. 
pacman --noconfirm --needed -Sy dialog 

# Welcome user and pick dotfiles.
welcomemsg || error "User exited."

# Last chance for user to back out before install.
preinstallmsg || error "User exited."

### The rest of the script requires no user input.

# Refresh Arch keyrings.
refreshkeys || error "Error automatically refreshing Arch keyring. Consider doing so manually." #! da cambiare

dialog --title "FARBS Installation" --infobox "Installing packages which are required to install and configure other programs." 5 70
pacman --noconfirm --needed -S git curl ntp zsh base-devel >/dev/null 2>&1

#dialog --title "FARBS Installation" --infobox "Synchronizing system time to ensure successful and secure installation of software..." 4 70
#ntpdate 0.us.pool.ntp.org >/dev/null 2>&1

# Allow user to run sudo without password. Since AUR programs must be installed
# in a fakeroot environment, this is required for all builds with AUR.
#newperms "%wheel ALL=(ALL) NOPASSWD: ALL"

# Make pacman and the AUR helper colorful and adds eye candy on the progress bar because why not.
grep -q "^Color" /etc/pacman.conf || sed -i "s/^#Color$/Color/" /etc/pacman.conf
grep -q "^VerbosePkgLists" /etc/pacman.conf || sed -i "s/^#VerbosePkgLists$/VerbosePkgLists/" /etc/pacman.conf

# Use all cores for compilation.
sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf

manualinstall yay || error "Failed to install AUR helper."

# The command that does all the installing. Reads the progs.csv file and
# installs each needed program the way required. Be sure to run this only after
# the user has been created and has priviledges to run sudo without a password
# and all build dependencies are installed.

installationloop

#dialog --title "LARBS Installation" --infobox "Finally, installing \`libxft-bgra\` to enable color emoji in suckless software without crashes." 5 70
#yes | sudo -u "$name" $aurhelper -S libxft-bgra-git >/dev/null 2>&1

# Install the dotfiles in the user's home directory
putgitrepo "$dotfilesrepo" "/home/$SUDO_USER" "$repobranch"

#rm -f "/home/$SUDO_USER/README.md" "/home/$SUDO_USER/LICENSE" "/home/$SUDO_USER/FUNDING.yml"
# make git ignore deleted LICENSE & README.md files
#git update-index --assume-unchanged "/home/$name/README.md" "/home/$name/LICENSE" "/home/$name/FUNDING.yml" #! interesting?

# Most important command! Get rid of the beep!
#systembeepoff

# Make zsh the default shell for the user.
chsh -s /bin/zsh "$SUDO_USER" >/dev/null 2>&1
#sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"

# Tap to click
#[ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && printf 'Section "InputClass" #!
#        Identifier "libinput touchpad catchall"
#        MatchIsTouchpad "on"
#        MatchDevicePath "/dev/input/event*"
#        Driver "libinput"
#	# Enable left mouse button by tapping
#	Option "Tapping" "on"
#EndSection' > /etc/X11/xorg.conf.d/40-libinput.conf

# Fix fluidsynth/pulseaudio issue.
#grep -q "OTHER_OPTS='-a pulseaudio -m alsa_seq -r 48000'" /etc/conf.d/fluidsynth || #!
#	echo "OTHER_OPTS='-a pulseaudio -m alsa_seq -r 48000'" >> /etc/conf.d/fluidsynth

# Start/restart PulseAudio.
#pkill -15 -x 'pulseaudio'; sudo -u "$SUDO_USER" pulseaudio --start

# This line, overwriting the `newperms` command above will allow the user to run
# serveral important commands, `shutdown`, `reboot`, updating, etc. without a password.
#newperms "%wheel ALL=(ALL) ALL #LARBS
#%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/packer -Syu,/usr/bin/packer -Syyu,/usr/bin/systemctl restart NetworkManager,/usr/bin/rc-service NetworkManager restart,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/paru,/usr/bin/pacman -Syyuw --noconfirm"

# Last message! Install complete!
finalize
clear