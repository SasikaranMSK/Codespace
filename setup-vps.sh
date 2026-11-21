#!/usr/bin/env bash
###############################################################################
# Sasikaran Codespace — Automated VPS Setup Script
# Target: Ubuntu 22.04 (Jammy)
# Run as root or with sudo:  sudo ./setup-vps.sh
###############################################################################
set -Eeuo pipefail
trap 'echo "ERROR: Setup failed at line $LINENO: $BASH_COMMAND" >&2' ERR
REPAIR_DESKTOP=false
case "${1:-}" in
  --repair-desktop) REPAIR_DESKTOP=true ;;
  "") ;;
  *) echo "Usage: sudo bash setup-vps.sh [--repair-desktop]" >&2; exit 2 ;;
esac

if [ "$EUID" -ne 0 ]; then
  echo "Run this script as root: sudo bash setup-vps.sh" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
export TZ=Etc/UTC

log() { echo -e "\n\033[1;34m[SETUP]\033[0m $*"; }
ok() { echo -e "\033[1;32m  ✓\033[0m $*"; }

# Create the desktop account before any per-user installation. Let useradd
# allocate IDs so an existing Ubuntu account with UID 1000 is not a conflict.
USERNAME=sasi
if ! id "$USERNAME" &>/dev/null; then
  useradd --create-home --user-group --shell /bin/bash "$USERNAME"
  usermod -aG sudo "$USERNAME"
  install -d -m 0755 /etc/sudoers.d
  echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-${USERNAME}"
  chmod 0440 "/etc/sudoers.d/90-${USERNAME}"
fi
USER_HOME="$(getent passwd "$USERNAME" | cut -d: -f6)"
USER_GROUP="$(id -gn "$USERNAME")"
as_user() {
  sudo -H -u "$USERNAME" -- bash -c 'cd "$HOME"; exec "$@"' bash "$@"
}

###############################################################################
# 1. System update
###############################################################################
log "Updating package index and upgrading system..."
apt-get update -y
if ! "$REPAIR_DESKTOP"; then apt-get upgrade -y; fi

###############################################################################
# 2. Base packages
###############################################################################
log "Installing base packages..."
apt-get install -y --no-install-recommends \
  locales \
  wget curl gnupg sudo build-essential \
  dbus-x11 dbus-user-session xfce4 desktop-base xscreensaver \
  xrdp xorgxrdp xserver-xorg-core xauth ssl-cert \
  vlc file-roller screen mkvtoolnix mkvtoolnix-gui \
  qbittorrent thonny \
  libqt5webenginecore5 libqt5webenginewidgets5 \
  libqt5script5 libqt5scripttools5 \
  ffmpeg \
  pulseaudio \
  jq make htop git fuse3 libfuse2 python3-venv xdg-user-dirs

ok "Base packages installed."

# Common host libraries required by Qt/Electron/GTK AppImages on minimal VPSes.
# FUSE 2 and FUSE 3 libraries coexist; do not replace fuse3 with the fuse package.
log "Installing AppImage runtime libraries..."
apt-get install -y --no-install-recommends \
  libgtk-3-0 libnss3 libnspr4 libasound2 libgbm1 libdrm2 \
  libgl1 libegl1 libgl1-mesa-dri libxss1 libxtst6 \
  libx11-xcb1 libxcb-cursor0 libxcb-xinerama0 libxcb-icccm4 \
  libxcb-image0 libxcb-keysyms1 libxcb-render-util0 \
  libxkbcommon0 libxkbcommon-x11-0 fonts-dejavu-core
if [ ! -c /dev/fuse ]; then
  modprobe fuse || true
fi
if [ ! -c /dev/fuse ]; then
  echo "WARNING: /dev/fuse is unavailable. Your VPS provider must enable FUSE." >&2
  echo "For supported AppImages, try: app.AppImage --appimage-extract-and-run" >&2
fi
ok "AppImage runtime libraries installed."

as_user xdg-user-dirs-update
DESKTOP_DIR="$(as_user xdg-user-dir DESKTOP)"
APP_DIR="$USER_HOME/Applications"
LAUNCHER_DIR="$USER_HOME/.local/share/applications"
install -d -o "$USERNAME" -g "$USER_GROUP" \
  "$DESKTOP_DIR" "$APP_DIR" "$LAUNCHER_DIR"

###############################################################################
# 3. Locale
###############################################################################
log "Generating locale..."
locale-gen en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
ok "Locale configured."

###############################################################################
# XRDP: Xorg backend with the desktop user's XFCE session
###############################################################################
log "Configuring XRDP and XFCE..."
usermod -aG ssl-cert xrdp
if [ ! -e /etc/xrdp/startwm.sh.before-codespace ]; then
  cp -p /etc/xrdp/startwm.sh /etc/xrdp/startwm.sh.before-codespace
fi
cat > /etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh
if [ -r /etc/profile ]; then
  . /etc/profile
fi
if [ -r "$HOME/.profile" ]; then
  . "$HOME/.profile"
fi
unset DBUS_SESSION_BUS_ADDRESS
unset SESSION_MANAGER
exec /etc/X11/Xsession
EOF
chmod 0755 /etc/xrdp/startwm.sh
if [ -e "$USER_HOME/.xsession" ] && [ ! -e "$USER_HOME/.xsession.before-codespace" ]; then
  cp -p "$USER_HOME/.xsession" "$USER_HOME/.xsession.before-codespace"
fi
printf '#!/bin/sh\nexec dbus-run-session -- startxfce4\n' > "$USER_HOME/.xsession"
chown "$USERNAME:$USER_GROUP" "$USER_HOME/.xsession"
chmod 0755 "$USER_HOME/.xsession"
# Never remove the existing root RDP login before sasi has a usable password.
if [ "$(passwd -S "$USERNAME" | awk '{print $2}')" != P ] && [ -t 0 ]; then
  log "Set the RDP login password for $USERNAME..."
  passwd "$USERNAME"
fi
if [ "$(passwd -S "$USERNAME" | awk '{print $2}')" = P ]; then
  sed -i 's/^AllowRootLogin=.*/AllowRootLogin=false/' /etc/xrdp/sesman.ini
else
  echo "WARNING: Run passwd $USERNAME before logging in through RDP. Existing root RDP policy was preserved." >&2
fi
systemctl enable xrdp xrdp-sesman
systemctl restart xrdp-sesman xrdp
systemctl is-active --quiet xrdp-sesman xrdp
ok "XRDP configured on TCP 3389; select Xorg and log in as $USERNAME."

###############################################################################
# 7. Firefox (official Mozilla repo)
###############################################################################
log "Installing Firefox..."
install -d -m 0755 /etc/apt/keyrings
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg \
  -O- | tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
  | tee /etc/apt/sources.list.d/mozilla.list > /dev/null
printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' \
  > /etc/apt/preferences.d/mozilla
# Prefer the native Mozilla package even if Ubuntu's versioned Snap stub is
# already installed. Priority above 1000 permits replacing that newer stub.
printf 'Package: firefox*\nPin: origin packages.mozilla.org\nPin-Priority: 1001\n\nPackage: firefox*\nPin: release o=Ubuntu\nPin-Priority: -1\n' \
  > /etc/apt/preferences.d/mozilla-firefox
apt-get update -y
apt-get install -y --allow-downgrades firefox
# Fail if APT installed Ubuntu's Snap transition package instead of Mozilla Firefox.
if ! dpkg-query -L firefox | grep -qx '/usr/share/applications/firefox.desktop'; then
  echo "Firefox desktop launcher missing; check apt-cache policy firefox." >&2
  exit 1
fi
as_user firefox --version
install -m 0755 -o "$USERNAME" -g "$USER_GROUP" \
  /usr/share/applications/firefox.desktop "$DESKTOP_DIR/firefox.desktop"
as_user xdg-settings set default-web-browser firefox.desktop
ok "Firefox verified and its desktop launcher installed for $USERNAME."


if ! "$REPAIR_DESKTOP"; then
###############################################################################
# 4. yt-dlp
###############################################################################
log "Installing yt-dlp..."
mkdir -p /usr/local/bin
curl -fL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
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
# 8. Video DownloadHelper Companion App
###############################################################################
log "Installing Video DownloadHelper Companion App..."
curl -sSLf https://github.com/aclap-dev/vdhcoapp/releases/latest/download/install.sh | as_user bash
ok "Video DownloadHelper installed for $USERNAME."

###############################################################################
# 9. AppImages (Avidemux & Telegram)
###############################################################################
log "Installing AppImages for $USERNAME..."
install_appimage() {
  local name="$1" title="$2" url="$3" category="$4"
  local destination="$APP_DIR/$name.AppImage"
  local temporary
  temporary="$(mktemp "$APP_DIR/.$name.XXXXXX")"
  if ! curl -fL --retry 3 "$url" -o "$temporary"; then
    rm -f "$temporary"
    echo "Failed to download $title" >&2
    return 1
  fi
  # Reject empty downloads and HTML error pages returned with HTTP 200.
  if [ "$(head -c 4 "$temporary" | od -An -tx1 | tr -d ' \n')" != "7f454c46" ]; then
    rm -f "$temporary"
    echo "$title download is not an executable AppImage" >&2
    return 1
  fi
  chmod 0755 "$temporary"
  chown "$USERNAME:$USER_GROUP" "$temporary"
  mv -f "$temporary" "$destination"
  local launcher="$LAUNCHER_DIR/$name.desktop"
  cat > "$launcher" <<EOF
[Desktop Entry]
Type=Application
Name=$title
Exec="$destination" %U
Icon=application-x-executable
Terminal=false
Categories=$category;
EOF
  install -m 0755 -o "$USERNAME" -g "$USER_GROUP" \
    "$launcher" "$DESKTOP_DIR/$name.desktop"
  chown "$USERNAME:$USER_GROUP" "$launcher"
  chmod 0644 "$launcher"
}

install_appimage avidemux Avidemux \
  "https://www.dropbox.com/scl/fi/c2vo7dc9blemneue71owr/avidemux_2.8.1.appImage?rlkey=4zodz3mtwt418r8n3x5k2ep78&st=y53w0p0j&dl=1" AudioVideo
install_appimage telegram Telegram \
  "https://www.dropbox.com/scl/fi/h3szk2c2gscmvu7rfp2ty/Telegram.AppImage?rlkey=hmfixuty7btwfdbxbmakmyri&st=h0mjn9aw&dl=1" Network
ok "AppImages installed in $APP_DIR with desktop and application-menu launchers."

###############################################################################
# 11. Python virtual environment
###############################################################################
log "Setting up Python virtual environment..."
as_user mkdir -p "$USER_HOME/.venvs"
chown -R "$USERNAME:$USER_GROUP" "$USER_HOME/.venvs"
as_user python3 -m venv "$USER_HOME/.venvs/default"

# Auto-activate for the user
PROFILE="$USER_HOME/.bashrc"
if ! grep -q 'venvs/default' "$PROFILE"; then
  echo 'source ~/.venvs/default/bin/activate' >> "$PROFILE"
fi
chown "$USERNAME:$USER_GROUP" "$PROFILE"
ok "Python venv ready at $USER_HOME/.venvs/default"

fi # Full setup only: optional third-party applications and Python environment.

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
if ! "$REPAIR_DESKTOP"; then
  service chrome-remote-desktop restart || true
fi
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
echo "  XRDP: set a login password with: sudo passwd $USERNAME"
echo "  Allow TCP 3389 from your client IP in your VPS provider firewall."
echo "  If UFW is active: sudo ufw allow from YOUR_CLIENT_IP to any port 3389 proto tcp"
echo "  Connect your RDP client to VPS_IP:3389; choose Xorg and log in as $USERNAME."
echo "  Log out of other desktop sessions for $USERNAME before using XRDP."
echo ""
echo "  1. Reboot the VPS:  sudo reboot"
if ! "$REPAIR_DESKTOP"; then
echo "  2. Open https://remotedesktop.google.com in Chrome"
echo "  3. Run the remote-access registration command as $USERNAME (not root), and set a PIN"
echo "  4. Connect as $USERNAME; desktop files are in $DESKTOP_DIR"
fi
echo ""
