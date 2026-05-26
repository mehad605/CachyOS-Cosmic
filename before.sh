#!/usr/bin/env bash
# ============================================================
# before.sh — CachyOS COSMIC Setup (before first reboot)
# Run this first, then restart, then run after.sh
# ============================================================

set -uo pipefail
trap 'echo "[ERROR] Command failed on line $LINENO. Check the log for details."' ERR

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOGFILE="$SCRIPT_DIR/before-$(date +%Y%m%d-%H%M%S).log"
ERRORS=0

# Duplicate stdout to both terminal and log file
exec > >(tee -a "$LOGFILE") 2>&1

log() { echo "[$(date '+%H:%M:%S')] $*"; }
section() { echo ""; echo "============================================================"; echo "  $*"; echo "============================================================"; }
warn() { echo "[WARN] $*"; }
ok()   { echo "[OK]   $*"; }

# Helper: download a file with update prompting.
# Usage: _download_or_update <path> <url> <name>
_download_or_update() {
    local path="$1" url="$2" name="$3"

    if [ ! -f "$path" ]; then
        wget -O "$path" "$url" && chmod +x "$path" && ok "$name installed" || warn "$name download failed"
        return
    fi

    # File exists — back up and use wget --timestamping to check remote
    cp "$path" "${path}.bak"
    if wget -N -O "$path" "$url" 2>/dev/null; then
        if cmp -s "$path" "${path}.bak" 2>/dev/null; then
            rm -f "${path}.bak"
            ok "$name is up to date"
        else
            chmod +x "$path"
            echo ""
            echo "  A newer version of $name is available."
            read -r -p "  Apply update? [Y/n] " choice
            if [ "$choice" = "n" ] || [ "$choice" = "N" ]; then
                mv "${path}.bak" "$path"
                ok "keeping existing $name"
            else
                rm -f "${path}.bak"
                ok "$name updated"
            fi
        fi
    else
        mv "${path}.bak" "$path"
        warn "$name update check failed (network error?) — keeping existing"
    fi
}

echo "# before.sh log — $(date)"
echo "# Log file: $LOGFILE"
echo ""

# ============================================================
section "System Update"
# ============================================================
echo "Checking for system updates..."
sudo pacman -Syu || { warn "System update had issues (continuing)"; ERRORS=$((ERRORS + 1)); }

# ============================================================
section "Installing pacman packages"
# ============================================================
echo "Installing/upgrading the following packages..."
echo "(already-installed up-to-date packages will be skipped)"
sudo pacman -S --noconfirm --needed \
    proton-vpn-gtk-app \
    brave-bin \
    zen-browser-bin \
    asusctl \
    syncthing \
    zathura \
    opencode \
    android-tools \
    scrcpy \
    zed \
    uv \
    keepassxc \
    qbittorrent \
    nvm \
    nwg-look \
    anki \
    fzf \
    zsh \
    zsh-completions \
    zoxide \
    vlc \
    bat \
    obsidian \
    nano-syntax-highlighting \
    base-devel \
    rustup \
    git \
    unzip \
    curl \
    cmake \
    ninja \
    mesa \
    jdk21-openjdk \
    qemu-full \
    virt-manager \
    virt-viewer \
    dnsmasq \
    vde2 \
    openbsd-netcat \
    protonup-qt \
    obs-studio-browser \
    flatpak \
    flameshot \
    grim \
    slurp \
    loupe \
    evtest \
    linux-cachyos-headers \
    virtualbox \
    virtualbox-host-dkms \
    virtualbox-guest-iso \
    edk2-ovmf \
    btrfs-assistant \
    mission-center \
    stow \
    flatpak-builder \
    appstream \
    desktop-file-utils \
    dpkg \
    libappindicator \
    fuse2 \
    squashfs-tools \
    libappimage \
    appstream-glib \
    perl-file-mimeinfo \
    rpm-tools \
    wl-clipboard \
    wtype \
    gvfs \
    gvfs-mtp \
    mtpfs \
    android-udev \
    nautilus \
    zathura-pdf-mupdf \
    tesseract-data-eng \
    tesseract-data-ben \
    zathura-cb \
    imv \
    shelly \
    cliphist \
    rofi \
    yt-dlp \
    thermald \
    github-cli \
    go \
    lsp-plugins \
    easyeffects
ok "pacman packages done"

# ============================================================
section "Installing AUR packages via paru"
# ============================================================
echo "Checking if paru is installed..."
if ! command -v paru &>/dev/null; then
    echo "paru not found — installing it first..."
    sudo pacman -S --noconfirm --needed paru
fi

echo "Installing AUR packages..."
paru -S --needed \
    visual-studio-code-bin \
    icu69-bin \
    antigravity \
    android-studio \
    claude-code-stable \
    flutter-bin \
    envycontrol \
    virtualbox-ext-oracle \
    vmware-keymaps \
    vmware-workstation \
    libcroco \
    nautilus-open-any-terminal \
    lmstudio-bin || { warn "Some AUR packages failed (continuing)"; ERRORS=$((ERRORS + 1)); }
ok "AUR packages done"

# ============================================================
section "Configuring xdg-desktop-portal for COSMIC"
# ============================================================
mkdir -p "$HOME/.config/xdg-desktop-portal"
cat > "$HOME/.config/xdg-desktop-portal/portals.conf" << 'EOF'
[preferred]
default=cosmic
org.freedesktop.impl.portal.FileChooser=gtk
org.freedesktop.impl.portal.Settings=cosmic
EOF
systemctl --user restart xdg-desktop-portal 2>/dev/null && ok "xdg-desktop-portal restarted" || warn "Could not restart xdg-desktop-portal (may not be running yet)"
systemctl enable --now asusd
# ============================================================
section "Setting up linuxdeploy"
# ============================================================
mkdir -p "$HOME/.local/bin"

_download_or_update "$HOME/.local/bin/linuxdeploy-plugin-gtk" \
    "https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh" \
    "linuxdeploy-plugin-gtk"

# appdir-lint.sh was removed from AppImageKit upstream (returns 404)
# Skipped — non-essential validation tool

_download_or_update "$HOME/.local/bin/linuxdeploy" \
    "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage" \
    "linuxdeploy"

_download_or_update "$HOME/.local/bin/linuxdeploy-plugin-qt" \
    "https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage" \
    "linuxdeploy-plugin-qt"

_download_or_update "$HOME/.local/bin/linuxdeploy-plugin-python" \
    "https://github.com/niess/linuxdeploy-plugin-python/releases/download/continuous/linuxdeploy-plugin-python-x86_64.AppImage" \
    "linuxdeploy-plugin-python"

# ============================================================
section "Installing tauri-cli"
# ============================================================
if command -v cargo &>/dev/null; then
    cargo install tauri-cli 2>&1 | tail -5 || warn "tauri-cli install failed (may already be installed)"
    ok "tauri-cli done"
else
    warn "cargo not available — skipping tauri-cli"
fi

# ============================================================
section "Setting up Flatpak"
# ============================================================
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && ok "Flathub remote added" || warn "Flathub remote failed"

if ! flatpak list | grep -q "org.freedesktop.Sdk//24.08" 2>/dev/null; then
    flatpak install -y flathub org.freedesktop.Sdk//24.08 org.freedesktop.Platform//24.08 && ok "Flatpak runtimes installed" || warn "Flatpak runtime install failed"
else
    ok "Flatpak runtimes already installed"
fi

# ============================================================
section "Setting up libvirt"
# ============================================================
sudo systemctl enable --now libvirtd && ok "libvirtd enabled" || { warn "libvirtd enable failed"; ERRORS=$((ERRORS + 1)); }
sudo systemctl enable --now virtlogd && ok "virtlogd enabled" || { warn "virtlogd enable failed"; ERRORS=$((ERRORS + 1)); }
sudo usermod -aG libvirt,kvm "$USER" && ok "User added to libvirt,kvm groups" || warn "usermod failed"

sudo virsh net-autostart default 2>/dev/null && ok "libvirt default net set to autostart" || warn "Could not set default net autostart"
sudo virsh net-start default 2>/dev/null && ok "libvirt default net started" || warn "Could not start default net (may already be running)"

# ============================================================
section "Setting up VirtualBox"
# ============================================================
sudo gpasswd -a "$USER" vboxusers && ok "User added to vboxusers" || warn "gpasswd failed"
sudo modprobe vboxdrv && ok "vboxdrv module loaded" || warn "Could not load vboxdrv (may need reboot)"

# ============================================================
section "Setting up VMware"
# ============================================================
sudo systemctl enable --now vmware-networks.service vmware-usbarbitrator.service 2>/dev/null && ok "VMware services enabled" || warn "VMware services could not be enabled (may not be needed)"
sudo modprobe -a vmw_vmci vmmon 2>/dev/null && ok "VMware modules loaded" || warn "Could not load VMware modules"

# ============================================================
section "Setting Java 21 as default"
# ============================================================
if /usr/lib/jvm/java-21-openjdk/bin/java -version &>/dev/null; then
    sudo archlinux-java set java-21-openjdk && ok "Java 21 set as default" || warn "Could not set Java 21"
else
    warn "Java 21 not found — skipping"
fi

# ============================================================
section "Setting rustup default"
# ============================================================
if command -v rustup &>/dev/null; then
    rustup default stable && ok "rustup default set to stable" || warn "rustup default failed"
else
    warn "rustup not found — skipping"
fi

# ============================================================
section "Nautilus open any terminal"
# ============================================================
gsettings set com.github.stunkymonkey.nautilus-open-any-terminal terminal kitty && ok "Nautilus terminal set to kitty" || warn "gsettings failed (nautilus-open-any-terminal may not be installed yet)"

# ============================================================
section "Creating Templates"
# ============================================================
mkdir -p "$HOME/Templates"
touch "$HOME/Templates/New Document" && ok "Template created" || warn "Template creation failed"

# ============================================================
section "Flutter setup"
# ============================================================
sudo usermod -a -G flutter "$USER" 2>/dev/null && ok "User added to flutter group" || warn "Could not add to flutter group"
if [ -d /opt/flutter ]; then
    sudo chown -R :flutter /opt/flutter 2>/dev/null && ok "/opt/flutter ownership set" || warn "Could not set /opt/flutter ownership"
    sudo chmod -R g+w /opt/flutter 2>/dev/null && ok "/opt/flutter permissions set" || warn "Could not set /opt/flutter permissions"
else
    warn "/opt/flutter does not exist — skipping permissions (will be handled after flutter-bin installs)"
fi

# ============================================================
section "Setting up syncthing user service"
# ============================================================
systemctl --user enable --now syncthing.service && ok "syncthing user service enabled" || warn "Could not enable syncthing user service"

# ============================================================
section "Cliphist autostart entries"
# ============================================================
mkdir -p "$HOME/.config/autostart"

if [ ! -f "$HOME/.config/autostart/cliphist-text.desktop" ]; then
    cat > "$HOME/.config/autostart/cliphist-text.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Cliphist Text
Exec=wl-paste --type text --watch cliphist store -max-items 200
Terminal=false
EOF
    ok "cliphist-text autostart created"
else
    ok "cliphist-text autostart already exists"
fi

if [ ! -f "$HOME/.config/autostart/cliphist-image.desktop" ]; then
    cat > "$HOME/.config/autostart/cliphist-image.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Cliphist Image
Exec=wl-paste --type image --watch cliphist store -max-items 200
Terminal=false
EOF
    ok "cliphist-image autostart created"
else
    ok "cliphist-image autostart already exists"
fi

# ============================================================
section "Rofi theme (Catppuccin)"
# ============================================================
mkdir -p "$HOME/.config/rofi/themes"

_download_or_update "$HOME/.config/rofi/themes/catppuccin-mocha.rasi" \
    "https://raw.githubusercontent.com/catppuccin/rofi/main/themes/catppuccin-mocha.rasi" \
    "Catppuccin mocha theme"

_download_or_update "$HOME/.config/rofi/themes/catppuccin-default.rasi" \
    "https://raw.githubusercontent.com/catppuccin/rofi/main/catppuccin-default.rasi" \
    "Catppuccin default theme"

cat > "$HOME/.config/rofi/config.rasi" << 'EOF'
@theme "/home/maruf/.config/rofi/themes/catppuccin-default.rasi"
EOF
ok "rofi config.rasi written"

# ============================================================
section "Touchpad Toggle Script"
# ============================================================
if [ ! -f /usr/local/bin/touchpad-toggle.sh ]; then
    # Install evtest if missing
    if ! command -v evtest &>/dev/null; then
        sudo pacman -S --noconfirm evtest && ok "evtest installed" || warn "evtest install failed"
    fi

    sudo tee /usr/local/bin/touchpad-toggle.sh > /dev/null << 'TOUCHPADEOF'
#!/bin/bash

get_touchpad_event() {
    grep -iE 'name=.*(touchpad|trackpad)' -A 5 /proc/bus/input/devices | grep -oP 'event\d+' | head -n 1
}

mouse_connected() {
    if awk -v RS='' '/Handlers=.*mouse/ && /Bus=(0003|0005)/ {m=1} END{exit !m}' /proc/bus/input/devices; then
        return 0
    else
        return 1
    fi
}

toggle_touchpad() {
    TOUCHPAD_EVENT=$(get_touchpad_event)

    if [ -z "$TOUCHPAD_EVENT" ]; then
        return
    fi

    if mouse_connected; then
        if ! pgrep -f "evtest --grab /dev/input/$TOUCHPAD_EVENT" > /dev/null; then
            evtest --grab /dev/input/"$TOUCHPAD_EVENT" > /dev/null 2>&1 &
        fi
    else
        if pgrep -f "evtest --grab /dev/input/$TOUCHPAD_EVENT" > /dev/null; then
            pkill -f "evtest --grab /dev/input/$TOUCHPAD_EVENT"
        fi
    fi
}

toggle_touchpad

udevadm monitor --subsystem-match=input | while read -r line; do
    if echo "$line" | grep -qE 'add|remove'; then
        sleep 1
        toggle_touchpad
    fi
done
TOUCHPADEOF

    sudo chmod +x /usr/local/bin/touchpad-toggle.sh && ok "touchpad-toggle.sh installed"

    sudo tee /etc/systemd/system/touchpad-toggle.service > /dev/null << 'SERVICEEOF'
[Unit]
Description=Auto-toggle Touchpad based on External Mouse
After=multi-user.target

[Service]
ExecStart=/usr/local/bin/touchpad-toggle.sh
Restart=always
User=root

[Install]
WantedBy=multi-user.target
SERVICEEOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now touchpad-toggle.service && ok "touchpad-toggle service installed and started"
else
    ok "touchpad-toggle already installed"
fi

# ============================================================
section "Adding NVM sourcing to .zshrc"
# ============================================================
if [ -f "$HOME/.zshrc" ] && ! grep -q "nvm/init-nvm.sh" "$HOME/.zshrc" 2>/dev/null; then
    cat >> "$HOME/.zshrc" << 'NVMEOF'

# NVM (Node Version Manager)
export NVM_DIR="$HOME/.nvm"
[ -s "/usr/share/nvm/init-nvm.sh" ] && source "/usr/share/nvm/init-nvm.sh"
NVMEOF
    ok "NVM sourcing added to .zshrc"
elif [ ! -f "$HOME/.zshrc" ]; then
    cat > "$HOME/.zshrc" << 'NVMEOF'
# Default .zshrc for CachyOS COSMIC setup

# NVM (Node Version Manager)
export NVM_DIR="$HOME/.nvm"
[ -s "/usr/share/nvm/init-nvm.sh" ] && source "/usr/share/nvm/init-nvm.sh"
NVMEOF
    ok ".zshrc created with NVM sourcing"
else
    ok "NVM sourcing already in .zshrc"
fi

# ============================================================
section "Changing default shell to zsh"
# ============================================================
if [ "$SHELL" != "$(which zsh 2>/dev/null)" ]; then
    if grep -q "$(which zsh)" /etc/shells 2>/dev/null; then
        chsh -s "$(which zsh)" && ok "Default shell changed to zsh" || warn "Could not change shell"
    else
        echo "  Adding $(which zsh) to /etc/shells..."
        echo "$(which zsh)" | sudo tee -a /etc/shells > /dev/null && ok "zsh added to /etc/shells" || warn "Could not add zsh to /etc/shells"
        chsh -s "$(which zsh)" && ok "Default shell changed to zsh" || warn "Could not change shell"
    fi
else
    ok "zsh is already the default shell"
fi

#enable thermadd
sudo systemctl enable --now thermald
# Disable Turbo
echo "1" | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo
# ============================================================
section "Summary"
# ============================================================
echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo "  Finished with $ERRORS warning(s). Check the log for details."
else
    echo "  All steps completed successfully!"
fi
echo ""
echo "  Log saved to: $LOGFILE"
echo ""
echo "  Next steps:"
echo "  1. Log out and log back in (or reboot)"
echo "     — This applies group changes (libvirt, kvm,"
echo "       vboxusers, flutter) and the new shell (zsh)"
echo "  2. Run: ~/scripts/after.sh"
echo ""
