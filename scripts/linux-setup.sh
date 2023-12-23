#!/bin/bash
set -e

# sudo sh -c 'echo "fs.inotify.max_user_watches=524288" >> /etc/sysctl.conf'

timedatectl set-local-rtc 1 --adjust-system-clock
gsettings set org.gnome.desktop.interface clock-format 12h

# sudo visudo
sudo systemctl enable sshd
sudo systemctl start sshd 


sudo dnf install fedora-workstation-repositories
sudo dnf check-update --refresh -y
sudo dnf update -y
sudo dnf install \
    zsh jq gh code fira-code-fonts util-linux-user p7zip p7zip-plugins php-cli \
    gnome-extensions-app gnome-tweak-tool \
    google-chrome-stable \
    remmina \
    -y

# add link to gnome-terminal so "desktopfolder" can open terminals
sudo ln -s $(which gnome-terminal) /usr/local/bin/x-terminal-emulator

sudo sh ./install_1password
# vscode repo
sudo sh ./install_vscode
# github cli repo
sudo sh ./install_github

#flathub
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

#flatpak install flathub com.github.maoschanz.DynamicWallpaperEditor
#flatpak install flathub com.spotify.Client

#sudo dnf install snapd -y
#sudo ln -s /var/lib/snapd/snap /snap


sh ./install-app-image-launcher


# configure emoji icons
mkdir -p ~/.config/fontconfig
cat <<FONTS > ~/.config/fontconfig/fonts.conf
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <alias>
    <family>serif</family>
    <prefer>
      <family>Noto Color Emoji</family>
    </prefer>
  </alias>
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Noto Color Emoji</family>
    </prefer>
  </alias>
  <alias>
    <family>monospace</family>
    <prefer>
      <family>Noto Color Emoji</family>
    </prefer>
  </alias>
</fontconfig>
FONTS
fc-cache --force

#Theme
# https://www.pling.com/p/1230631/ https://github.com/vinceliuice/Qogir-theme (Qogir-win-dark)
# https://www.pling.com/p/1166289/ (Papirus-Dark)
#Cursors:
# https://github.com/mustafaozhan/Breeze-Adapta-Cursor (Breeze-Adapta)

#Gnome Extentions
# https://extensions.gnome.org/extension/15/alternatetab/
# https://extensions.gnome.org/extension/3628/arcmenu/
# https://extensions.gnome.org/extension/751/audio-output-switcher/
# https://extensions.gnome.org/extension/517/caffeine/
# https://extensions.gnome.org/extension/1160/dash-to-panel/
# https://extensions.gnome.org/extension/2087/desktop-icons-ng-ding/ (using desktopfolder instead)
# https://extensions.gnome.org/extension/1166/extension-update-notifier/
# https://extensions.gnome.org/extension/841/freon/
# https://extensions.gnome.org/extension/1610/fullscreen-notifications/
# https://extensions.gnome.org/extension/1125/github-notifications/
# https://extensions.gnome.org/extension/2141/horizontal-workspaces/
# https://extensions.gnome.org/extension/36/lock-keys/
# https://extensions.gnome.org/extension/1526/notification-centerselenium-h/
# https://extensions.gnome.org/extension/750/openweather/
# https://extensions.gnome.org/extension/2863/power-menu-remover/
# https://extensions.gnome.org/extension/559/quit-from-dash/
# https://extensions.gnome.org/extension/7/removable-drive-menu/
# https://extensions.gnome.org/extension/3891/simple-monitor/
# https://extensions.gnome.org/extension/3681/top-indicator-app/
# https://extensions.gnome.org/extension/19/user-themes/

