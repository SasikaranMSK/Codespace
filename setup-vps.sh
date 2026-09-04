#!/usr/bin/env bash
###############################################################################
# Sasikaran Codespace — Automated VPS Setup Script
# Target: Ubuntu 22.04 (Jammy)
# Run as root or with sudo:  sudo ./setup-vps.sh
###############################################################################
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export TZ=Etc/UTC

log() { echo -e "\n\033[1;34m[SETUP]\033[0m $*"; }
ok() { echo -e "\033[1;32m  ✓\033[0m $*"; }

###############################################################################
# 1. System update
###############################################################################
log "Updating package index and upgrading system..."
apt-get update -y
apt-get upgrade -y

###############################################################################
# 2. Base packages
###############################################################################
log "Installing base packages..."
apt-get install -y --no-install-recommends \
  locales \
  wget curl gnupg sudo build-essential \
  dbus-x11 xfce4 desktop-base xscreensaver \
  vlc file-roller screen mkvtoolnix mkvtoolnix-gui \
  qbittorrent thonny \
  libqt5webenginecore5 libqt5webenginewidgets5 \
  libqt5script5 libqt5scripttools5 \
  ffmpeg \
  pulseaudio \
  jq make htop git fuse3

ok "Base packages installed."

###############################################################################
# 3. Locale
###############################################################################
log "Generating locale..."
locale-gen en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
ok "Locale configured."

###############################################################################
# 4. yt-dlp
###############################################################################
log "Installing yt-dlp..."
mkdir -p /usr/local/bin
curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
  -o /usr/local/bin/yt-dlp
chmod a+rx /usr/local/bin/yt-dlp

# Add to PATH for all users
if ! grep -q '\.local/bin' /etc/profile.d/local-bin.sh 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' > /etc/profile.d/local-bin.sh
fi
ok "yt-dlp installed."

###############################################################################
# 5. Chrome Remote Desktop
###############################################################################
log "Installing Chrome Remote Desktop..."
CRD_DEB="/tmp/chrome-remote-desktop_current_amd64.deb"
wget -q "https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb" \
  -O "$CRD_DEB"
apt-get update -y
apt-get install -y "$CRD_DEB"
rm -f "$CRD_DEB"

echo "exec /etc/X11/Xsession /usr/bin/xfce4-session" \
  > /etc/chrome-remote-desktop-session
ok "Chrome Remote Desktop installed."

###############################################################################
# 6. AB Download Manager
###############################################################################
log "Installing AB Download Manager..."
AB_DEB="/tmp/ABDownloadManager_1.5.4_linux_x64.deb"
wget -q "https://github.com/amir1376/ab-download-manager/releases/download/v1.5.4/ABDownloadManager_1.5.4_linux_x64.deb" \
  -O "$AB_DEB"
apt-get install -y "$AB_DEB"
rm -f "$AB_DEB"
ok "AB Download Manager installed."

###############################################################################
# 7. Firefox (official Mozilla repo)
###############################################################################
log "Installing Firefox..."
install -d -m 0755 /etc/apt/keyrings
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg \
  -O- | tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
  | tee -a /etc/apt/sources.list.d/mozilla.list > /dev/null
echo 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000' \
  > /etc/apt/preferences.d/mozilla
apt-get update -y
apt-get install -y firefox
ok "Firefox installed."

###############################################################################
# 8. Video DownloadHelper Companion App
###############################################################################
log "Installing Video DownloadHelper Companion App..."
curl -sSLf https://github.com/aclap-dev/vdhcoapp/releases/latest/download/install.sh | bash || true
ok "Video DownloadHelper installed (or already present)."

###############################################################################
# 9. AppImages (Avidemux & Telegram)
###############################################################################
log "Downloading AppImages..."
for user_dir in /root /home/*; do
  [ -d "$user_dir" ] || continue
  desktop_dir="$user_dir/Desktop"
  mkdir -p "$desktop_dir"

  wget -q -O "$desktop_dir/avidemux.AppImage" \
    "https://www.dropbox.com/scl/fi/c2vo7dc9blemneue71owr/avidemux_2.8.1.appImage?rlkey=4zodz3mtwt418r8n3x5k2ep78&st=y53w0p0j&dl=1" || true
  chmod +x "$desktop_dir/avidemux.AppImage" 2>/dev/null || true

  wget -q -O "$desktop_dir/telegram.AppImage" \
    "https://www.dropbox.com/scl/fi/h3szk2c2gscmvu7rfp2ty/Telegram.AppImage?rlkey=hmfixuty7btwfdbxbmakmyri&st=h0mjn9aw&dl=1" || true
  chmod +x "$desktop_dir/telegram.AppImage" 2>/dev/null || true
done
ok "AppImages downloaded."

###############################################################################
# 10. Create non-root user (skip if vscode user exists)
###############################################################################
USERNAME=vscode
USER_UID=1000
USER_GID=1000

if ! id "$USERNAME" &>/dev/null; then
  log "Creating user '$USERNAME'..."
  groupadd --gid ${USER_GID} ${USERNAME} || true
  useradd -s /bin/bash --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME}
  usermod -aG sudo ${USERNAME}
  echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-${USERNAME}
  chmod 0440 /etc/sudoers.d/90-${USERNAME}
  ok "User '$USERNAME' created."
else
  ok "User '$USERNAME' already exists."
fi

###############################################################################
# 11. Python virtual environment
###############################################################################
log "Setting up Python virtual environment..."
mkdir -p /home/${USERNAME}/.venvs
python3 -m venv /home/${USERNAME}/.venvs/default
chown -R ${USERNAME}:${USER_GID} /home/${USERNAME}/.venvs

# Auto-activate for the user
PROFILE="/home/${USERNAME}/.bashrc"
if ! grep -q 'venvs/default' "$PROFILE"; then
  echo 'source ~/.venvs/default/bin/activate' >> "$PROFILE"
fi
ok "Python venv ready at /home/${USERNAME}/.venvs/default"

###############################################################################
# 12. PulseAudio cleanup
###############################################################################
log "Configuring PulseAudio..."
rm -rf /var/run/pulse /var/lib/pulse /root/.config/pulse
ok "PulseAudio runtime files cleaned."

###############################################################################
# 13. Restart services
###############################################################################
log "Starting services..."
service chrome-remote-desktop restart || true
pulseaudio -D --exit-idle-time=-1 2>/dev/null || true
ok "Services started."

###############################################################################
# Done
###############################################################################
echo ""
echo -e "\033[1;32m═══════════════════════════════════════════════════════════\033[0m"
echo -e "\033[1;32m  ✅ Setup complete!\033[0m"
echo -e "\033[1;32m═══════════════════════════════════════════════════════════\033[0m"
echo ""
echo "  Next steps:"
echo "  1. Reboot the VPS:  sudo reboot"
echo "  2. Open https://remotedesktop.google.com in Chrome"
echo "  3. Sign in and enable remote access with a PIN"
echo "  4. Connect to your desktop!"
echo ""
