#!/usr/bin/env sh

### OPTIONS AND VARIABLES ###

while getopts ":a:r:c:h" o; do case "${o}" in
	h) printf "Optional arguments for custom use:\\n -a: AUR helper (must have pacman-like syntax)\\n  -h: Show this message\\n" && exit 1 ;;
	r) dotfilesrepo=${OPTARG} && git ls-remote "$dotfilesrepo" || exit 1 ;;
	c) configrepo=${OPTARG} && git ls-remote "$configrepo" || exit 1;;
	a) aurhelper=${OPTARG} ;;
	*) printf "Invalid option: -%s\\n" "$OPTARG" && exit 1 ;;
esac done

[ -z "$dotfilesrepo" ] && dotfilesrepo="https://github.com/fedfontana/dotto.git"
[ -z "$configrepo" ] && configrepo="https://github.com/fedfontana/regolith-config"
[ -z "$aurhelper" ] && aurhelper="yay"

sudo_usr="sudo -u \"$SUDO_USER\""
pm_inst="pacman -S --needed --noconfirm"
yay_inst="$aurhelper -S --needed --noconfirm"

### FUNCTIONS ###

error() { printf "%s\n" "$1" >&2; exit 1; }

putgitrepo() 
{ # Downloads a gitrepo $1 and places the files in $2 only overwriting conflicts
	[ -z "$3" ] && return 1
	branch="$3"
	dir=$(mktemp -d)
	[ ! -d "$2" ] && mkdir -p "$2"
	chown "$SUDO_USER":wheel "$dir" "$2"
	sudo -u "$SUDO_USER" git clone --recursive -b "$branch" --depth 1 --recurse-submodules "$1" "$dir"
	sudo -u "$SUDO_USER" cp -rfT "$dir" "$2"
}

manualinstall() 
{ # Installs $1 manually. Used only for AUR helper here.
	sudo -u "$SUDO_USER" git clone --depth 1 "https://aur.archlinux.org/$1.git" "/tmp/$1"
	cd "/tmp/$1"
	sudo -u "$SUDO_USER" makepkg --noconfirm -si || return 1
	cd
}

### THE ACTUAL SCRIPT ###

timedatectl set-ntp true

# Update and install dialog.
pacman -Syu --noconfirm || error "Are you sure you're running this on an arch machine as the root user and have an internet connection?"

# Refresh Arch keyrings.
pacman --noconfirm -S archlinux-keyring || error "Error automatically refreshing Arch keyring. Consider doing so manually."

# Install important packages
$pm_inst git ntp base-devel

# Make pacman and the AUR helper colorful and adds eye candy on the progress bar because why not.
grep -q "^Color" /etc/pacman.conf || sed -i "s/^#Color$/Color/" /etc/pacman.conf
grep -q "^VerbosePkgLists" /etc/pacman.conf || sed -i "s/^#VerbosePkgLists$/VerbosePkgLists/" /etc/pacman.conf

# Use all cores for compilation.
sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf

# Let anyone run all commands (needed for yay) without password
sed -i 's/^#\s*\(%wheel\s\+ALL=(ALL)\s\+NOPASSWD:\s\+ALL\)/\1/' /etc/sudoers

manualinstall yay-bin || error "Failed to install AUR helper."

# The command that does all the installing. Reads the progs.csv file and
# X.org
$pm_inst xorg xorg-xinit

# Strictly gnome stuff
$pm_inst gnome-flashback gnome-system-monitor gnome-control-center gnome-tweaks gnome-keyring gnome-power-manager gnome-disk-utility 

# System stuff
$pm_inst dunst feh pulseaudio-alsa pulsemixer unclutter i3-gaps i3blocks rofi network-manager-applet gnome-screenshot

# Lightdm stuff
$pm_inst lightdm lightdm-webkit2-greeter 

# Fonts
$pm_inst ttf-jetbrains-mono adobe-source-code-pro-fonts adobe-source-han-sans-jp-fonts adobe-source-han-sans-kr-fonts adobe-source-han-sans-cn-fonts 

# Theming
$pm_inst papirus-icon-theme

# Terminal stuff
$pm_inst zsh unrar unzip xclip youtube-dl fzf moreutils wget bat imagemagick lm_sensors tree onefetch htop neofetch neovim ranger findutils mlocate

# Graphical stuff
$pm_inst firefox vlc telegram-desktop alacritty gnome-boxes gimp nautilus discord libreoffice

# Programming language stuff
$pm_inst npm texlive-most dart gdb python-pip jdk-openjdk

# Other
$pm_inst libnotify ffmpeg man-db jq acpi playerctl sysstat

# AUR stuff
sudo -u "$SUDO_USER" $yay_inst picom-ibhagwan-git spotify visual-studio-code-insiders-bin kripton-theme-git lightdm-webkit-theme-sequoia-git remontoire-git flutter android-studio datagrip teams google-chrome

# i3-gnome-flashback
sudo -u "$SUDO_USER" git clone https://github.com/deuill/i3-gnome-flashback /tmp/i3gf
cd /tmp/i3gf
sudo make install
cd

# Install the dotfiles in the user's home directory
putgitrepo "$dotfilesrepo" "/home/$SUDO_USER" "master"
putgitrepo "$configrepo" "/home/$SUDO_USER" "move_stuff_arch"

# Make zsh the default shell for the user.
chsh -s /bin/zsh "$SUDO_USER"

# Edit lightdm config files and enable lightdm
sed -i "s/#greeter-session=example-gtk-gnome$/greeter-session=lightdm-webkit2-greeter/" /etc/lightdm/lightdm.conf
sed -i "s/^webkit_theme.*/webkit_theme = sequoia/g" /etc/lightdm/lightdm-webkit2-greeter.conf
systemctl enable lightdm

# Edit i3 gnome flashback startup script to source Xresources
sed -i "s/^i3$/[ -f \$HOME\/\.Xresources ] \&\& xrdb \$HOME\/\.Xresources\ni3 -c \$HOME\/\.config\/i3\/config/" /usr/bin/i3-gnome-flashback

# Change settings
sudo -u "$SUDO_USER" dbus-launch --exit-with-session gsettings set org.gnome.desktop.session idle-delay 3600
sudo -u "$SUDO_USER" dbus-launch --exit-with-session gsettings set org.gnome.desktop.screensaver lock-delay 180
sudo -u "$SUDO_USER" dbus-launch --exit-with-session gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll true
sudo -u "$SUDO_USER" dbus-launch --exit-with-session gsettings set org.gnome.desktop.peripherals.touchpad click-method areas
sudo -u "$SUDO_USER" dbus-launch --exit-with-session gsettings set org.gnome.desktop.peripherals.touchpad disable-while-typing true
sudo -u "$SUDO_USER" dbus-launch --exit-with-session gsettings set org.gnome.settings-daemon.plugins.power lid-close-ac-action 'nothing'
sudo -u "$SUDO_USER" dbus-launch --exit-with-session gsettings set org.gnome.settings-daemon.plugins.power lid-close-suspend-with-external-monitor 'nothing'
sudo -u "$SUDO_USER" dbus-launch --exit-with-session gsettings set org.gnome.desktop.interface gtk-enable-primary-paste false
sudo -u "$SUDO_USER" dbus-launch --exit-with-session gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true

# Theming
sudo -u "$SUDO_USER" dbus-launch --exit-with-session gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
sudo -u "$SUDO_USER" dbus-launch --exit-with-session gsettings set org.gnome.desktop.interface gtk-theme "Kripton"
sudo -u "$SUDO_USER" dbus-launch --exit-with-session gsettings set org.gnome.desktop.wm.preferences theme "Kripton"

# Download and install vim-plug
sudo -u "$SUDO_USER" sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

# Add back the restrictions before exiting the script
sed -i 's/^\s*\(%wheel\s\+ALL=(ALL)\s\+NOPASSWD:\s\+ALL\)$/#\1/' /etc/sudoers

updatedb
