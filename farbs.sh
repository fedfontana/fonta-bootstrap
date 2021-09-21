#!/usr/bin/env sh

### OPTIONS AND VARIABLES ###

while getopts ":a:r:c:b:p:h" o; do case "${o}" in
	h) printf "Optional arguments for custom use:\\n  -r: Dotfiles repository (local file or url)\\n  -c Config repository (local file or url)\\n  -p: Dependencies and programs csv (local file or url)\\n  -a: AUR helper (must have pacman-like syntax)\\n  -h: Show this message\\n" && exit 1 ;;
	r) dotfilesrepo=${OPTARG} && git ls-remote "$dotfilesrepo" || exit 1 ;;
	c) configrepo=${OPTARG} && git ls-remote "$configrepo" || exit 1;;
	a) aurhelper=${OPTARG} ;;
	*) printf "Invalid option: -%s\\n" "$OPTARG" && exit 1 ;;
esac done

[ -z "$dotfilesrepo" ] && dotfilesrepo="https://github.com/fedfontana/dotto.git"
[ -z "$configrepo" ] && configrepo="https://github.com/fedfontana/regolith-config"
[ -z "$aurhelper" ] && aurhelper="yay"

### FUNCTIONS ###

error() { printf "%s\n" "$1" >&2; exit 1; }

putgitrepo() 
{ # Downloads a gitrepo $1 and places the files in $2 only overwriting conflicts
	[ -z "$3" ] && branch="master" || branch="$repobranch"
	dir=$(mktemp -d)
	[ ! -d "$2" ] && mkdir -p "$2"
	chown "$SUDO_USER":wheel "$dir" "$2"
	sudo -u "$SUDO_USER" git clone --recursive -b "$branch" --depth 1 --recurse-submodules "$1" "$dir"
	sudo -u "$SUDO_USER" cp -rfT "$dir" "$2"
}

manualinstall() 
{ # Installs $1 manually. Used only for AUR helper here.
	sudo -u "$SUDO_USER" git clone --depth 1 "https://aur.archlinux.org/$1.git" "/tmp/$1" &>/dev/null
	cd "/tmp/$1"
	sudo -u "$SUDO_USER" makepkg --noconfirm -si &>/dev/null || return 1
	cd
}

### THE ACTUAL SCRIPT ###

# Update and install dialog.
pacman -Syu --noconfirm || error "Are you sure you're running this on an arch machine as the root user and have an internet connection?"

# Refresh Arch keyrings.
pacman --noconfirm -S archlinux-keyring || error "Error automatically refreshing Arch keyring. Consider doing so manually."

dialog --title "FARBS Installation" --infobox "Installing packages which are required to install and configure other programs." 5 70

pacman --noconfirm --needed -S git curl ntp zsh base-devel

# Make pacman and the AUR helper colorful and adds eye candy on the progress bar because why not.
grep -q "^Color" /etc/pacman.conf || sed -i "s/^#Color$/Color/" /etc/pacman.conf
grep -q "^VerbosePkgLists" /etc/pacman.conf || sed -i "s/^#VerbosePkgLists$/VerbosePkgLists/" /etc/pacman.conf

# Use all cores for compilation.
sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf

manualinstall yay || error "Failed to install AUR helper."

# The command that does all the installing. Reads the progs.csv file and
# installs each needed program the way required
#TODO add japanese fonts
pacman -S --needed --noconfirm xorg xorg-server xorg-xwininfo xorg-xinit \
									xorg-xprop bc arandr libnotify dunst feh ffmpeg gnome-keyring neovim man-db pulseaudio-alsa pulsemixer \
									unclutter unrar unzip xclip youtube-dl fzf xorg-xbacklight moreutils onefetch htop neofetch i3-gaps gnome-flashback \
									gnome-sistem-monitor firefox vlc i3blocks rofi network-manager-applet telegram-desktop wget alacritty gnome-control-center \
									gnome-tweajs bat gnome-boxes imagemagick jq lm_sensors npm ranger tree nautilus gnome-screenshot gnome-power-manager \
									gnome-disk-utility playerctl acpi xprop lightdm lightdm-webkit2-greeter ttf-jetbrains-mono adobe-source-code-pro-fonts papirus-icon-theme
sudo -u "$SUDO_USER" $aurhelper -S --noconfirm --needed i3-gnome-flashback picom-ibhagwan-git spotify visual-studio-code-insiders-bin kripton-theme-git

# Install the dotfiles in the user's home directory
putgitrepo "$dotfilesrepo" "/home/$SUDO_USER" "$repobranch"
putgitrepo "$configrepo" "/home/$SUDO_USER" "move_arch_stuff"

#rm -f "/home/$SUDO_USER/README.md" "/home/$SUDO_USER/LICENSE" "/home/$SUDO_USER/FUNDING.yml"
# make git ignore deleted LICENSE & README.md files
#git update-index --assume-unchanged "/home/$name/README.md" "/home/$name/LICENSE" "/home/$name/FUNDING.yml" #! interesting?

# Make zsh the default shell for the user.
chsh -s /bin/zsh "$SUDO_USER"

# Install lightdm theme, edit lightdm config files and enable lightdm
git clone https://github.com/Demonstrandum/Saluto.git /tmp/saluto
cd /tmp/saluto
sh install.sh
cd
systemctl enable lightdm
sed -i "s/^greeter-session=example-gtk-gnome$/greeter-session=lightdm-webkit2-greeter/" /etc/lightdm/lightdm.conf
sed -i "s/^webkit_theme.*/webkit_theme = sequoia/g" /etc/lightdm/lightdm-webkit2-greeter.conf

# Edit i3 gnome flashback startup script to source Xresources
sed -i "s/^i3$/ [ -f \$HOME\/\.Xresources ] && xrdb \$HOME\/\.Xresources\ni3 -c \$HOME\/\.config\/i3\/config/" /usr/bin/i3-gnome-flashback

pacman -S --needed --noconfirm 

# Change settings
gsettings set org.gnome.desktop.session idel-delay 3600
gsettings set org.gnome.desktop.screensaver lock-delay 180
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll true
gsettings set org.gnome.desktop.peripherals.touchpad click-method areas
gsettings set org.gnome.desktop.peripherals.touchpad disable-while-typing true
gsettings set org.gnome.settings-daemon.plugins.power lid-close-ac-action 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power lid-close-suspend-with-external-monitor 'nothing'
gsettings set org.gnome.desktop.interface gtk-enable-primary-paste false
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true

# Theming
#TODO download and set white cursor theme
#TODO Install a "normal" font and set it as default
#TODO Install the nerd-fonts versions of JetBrains Mono and Source Code Pro
gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
gsettings set org.gnome.desktop.interface gtk-theme "Kripton"
gsettings set org.gnome.desktop.wm.preferences theme "Kripton"

# Download and install vim-plug
sudo -u "$SUDO_USER" sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

# Tap to click
#[ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && printf 'Section "InputClass" #!
#        Identifier "libinput touchpad catchall"
#        MatchIsTouchpad "on"
#        MatchDevicePath "/dev/input/event*"
#        Driver "libinput"
#	# Enable left mouse button by tapping
#	Option "Tapping" "on"
#EndSection' > /etc/X11/xorg.conf.d/40-libinput.conf