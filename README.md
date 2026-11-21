# Sasikaran Codespace — Ubuntu VPS Setup Guide

A fully-featured Ubuntu 22.04 development desktop environment with Chrome Remote Desktop, media tools, and development utilities.

## 📋 What's Included

| Category | Packages |
|---|---|
| **Desktop** | XFCE4, xscreensaver, desktop themes |
| **Remote Access** | XRDP (XFCE/Xorg), Chrome Remote Desktop |
| **Browser** | Firefox (official Mozilla repo) |
| **Media** | VLC, ffmpeg, mkvtoolnix, avidemux (AppImage) |
| **Download** | yt-dlp, qBittorrent, AB Download Manager, Video DownloadHelper |
| **Communication** | Telegram (AppImage) |
| **Audio** | PulseAudio |
| **Development** | build-essential, Python 3 + venv, Thonny IDE, C/C++ tools |
| **Utilities** | curl, wget, gnupg, jq, make, htop |

---

## 🚀 Installation on a Fresh Ubuntu VPS

> **Requirements:** Ubuntu 22.04 (Jammy) VPS with at least **2 GB RAM** and **20 GB disk**. Root or sudo access required.

### Step 1: Connect to Your VPS

```bash
ssh root@your_vps_ip
```

### Step 2: Clone This Repository

```bash
# Install git if not already present
sudo apt-get update && sudo apt-get install -y git

# Clone the repository
cd ~
git clone https://github.com/SasikaranMSK/Codespace.git codespace-setup
cd codespace-setup
```

### Step 3: Run the Setup Script

You have two options:

#### Option A — Automated Setup (Recommended)

```bash
# Make the setup script executable and run it
chmod +x setup-vps.sh
sudo ./setup-vps.sh
```

### Repair an Existing VPS (Missing sasi User or Firefox)

Use the updated script from this repository on the VPS. From its directory, run
these commands in an SSH terminal as root (or with sudo):

```bash
sudo bash setup-vps.sh --repair-desktop
sudo passwd sasi
```

Repair mode creates `sasi` before package installation, installs desktop and
AppImage dependencies, configures XRDP/XFCE, and installs native Mozilla Firefox
with a desktop shortcut. It skips the system upgrade and optional third-party
downloads. If prompted during setup, set the password for `sasi` then; the
second command above can also set or change it afterward.

Log out of the root desktop and reconnect through RDP. Select **Xorg**, username
**sasi**, and its new password. Allow TCP 3389 from your client IP in the VPS
firewall if needed. Applications appear in the XFCE Applications menu; Firefox
also has a shortcut in `sasi`'s Desktop directory.

Setup preserves the existing root RDP policy until `sasi` has a password.
Configuration changes restart XRDP, so use SSH to run the repair. If setup fails,
it prints the failing command and line; resolve that error and rerun it. Verify:

```bash
getent passwd sasi
sudo -H -u sasi firefox --version
systemctl is-active xrdp xrdp-sesman
```

#### Option B — Manual Step-by-Step (Legacy Reference)

Follow each step below if you prefer full control.

---

## 🛠 Manual Setup Steps

### 1. System Update & Base Dependencies

```bash
export DEBIAN_FRONTEND=noninteractive
export TZ=Etc/UTC

sudo apt-get update && sudo apt-get upgrade -y

sudo apt-get install -y --no-install-recommends \
  locales \
  wget curl gnupg sudo build-essential \
  dbus-x11 xfce4 desktop-base xscreensaver \
  vlc file-roller screen mkvtoolnix mkvtoolnix-gui \
  qbittorrent thonny \
  libqt5webenginecore5 libqt5webenginewidgets5 \
  libqt5script5 libqt5scripttools5 \
  ffmpeg \
  pulseaudio \
  jq make htop
```

### 2. Set Locale

```bash
sudo locale-gen en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
```

### 3. Install yt-dlp

```bash
mkdir -p ~/.local/bin
curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o ~/.local/bin/yt-dlp
chmod a+rx ~/.local/bin/yt-dlp

# Add to PATH permanently
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.profile
source ~/.bashrc
```

### 4. Install Chrome Remote Desktop

```bash
wget https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb
sudo apt-get update
sudo apt-get install -y ./chrome-remote-desktop_current_amd64.deb
rm chrome-remote-desktop_current_amd64.deb

# Configure XFCE session
echo "exec /etc/X11/Xsession /usr/bin/xfce4-session" | sudo tee /etc/chrome-remote-desktop-session
```

> **After installation**, open Chrome Remote Desktop in your browser, sign in, and follow the prompts to enable remote access and set a PIN.

### 5. Install AB Download Manager

```bash
wget https://github.com/amir1376/ab-download-manager/releases/download/v1.5.4/ABDownloadManager_1.5.4_linux_x64.deb
sudo apt-get install -y ./ABDownloadManager_1.5.4_linux_x64.deb
rm ABDownloadManager_1.5.4_linux_x64.deb
```

### 6. Install Firefox (Official Mozilla Repo)

```bash
sudo install -d -m 0755 /etc/apt/keyrings
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | sudo tee -a /etc/apt/sources.list.d/mozilla.list > /dev/null
echo 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000' | sudo tee /etc/apt/preferences.d/mozilla > /dev/null
sudo apt-get update
sudo apt-get install -y firefox
```

### 7. Install Video DownloadHelper Companion App

```bash
curl -sSLf https://github.com/aclap-dev/vdhcoapp/releases/latest/download/install.sh | bash || true
```

### 8. Download AppImages (Avidemux & Telegram)

```bash
# Create Desktop directory if it doesn't exist
mkdir -p ~/Desktop

# Avidemux
wget -O ~/Desktop/avidemux.AppImage "https://www.dropbox.com/scl/fi/c2vo7dc9blemneue71owr/avidemux_2.8.1.appImage?rlkey=4zodz3mtwt418r8n3x5k2ep78&st=y53w0p0j&dl=1"
chmod +x ~/Desktop/avidemux.AppImage

# Telegram
wget -O ~/Desktop/telegram.AppImage "https://www.dropbox.com/scl/fi/h3szk2c2gscmvu7rfp2ty/Telegram.AppImage?rlkey=hmfixuty7btwfdbxbmakmyri&st=h0mjn9aw&dl=1"
chmod +x ~/Desktop/telegram.AppImage
```

### 9. Create Non-Root User (Optional — Recommended for Security)

```bash
USERNAME=sasi
USER_UID=1000
USER_GID=1000

sudo groupadd --gid ${USER_GID} ${USERNAME}
sudo useradd -s /bin/bash --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME}
sudo usermod -aG sudo ${USERNAME}
echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-${USERNAME} > /dev/null
sudo chmod 0440 /etc/sudoers.d/90-${USERNAME}
```

### 10. Set Up Python Virtual Environment

```bash
# Create venvs directory
mkdir -p ~/.venvs

# Create default virtual environment
python3 -m venv ~/.venvs/default

# Activate it
source ~/.venvs/default/bin/activate

# Add activation to .bashrc for convenience
echo 'source ~/.venvs/default/bin/activate' >> ~/.bashrc
```

### 11. Configure PulseAudio

```bash
# Clean any stale PulseAudio files
rm -rf /var/run/pulse /var/lib/pulse /root/.config/pulse

# Start PulseAudio daemon
pulseaudio -D --exit-idle-time=-1 || true
```

### 12. Start Chrome Remote Desktop Service

```bash
sudo service chrome-remote-desktop restart
```

---

## 🔧 Post-Installation

### Verify Installation

```bash
# Check yt-dlp
yt-dlp --version

# Check Firefox
firefox --version

# Check ffmpeg
ffmpeg -version

# Check Chrome Remote Desktop status
sudo service chrome-remote-desktop status
```

### Reboot (Recommended)

```bash
sudo reboot
```

---

## 🔌 Accessing Your Desktop via Chrome Remote Desktop

1. Open [remotedesktop.google.com](https://remotedesktop.google.com) in your Chrome browser.
2. Sign in with your Google account.
3. Under **Remote Devices**, you should see your VPS listed.
4. Click on it and enter the PIN you set during configuration.
5. You'll now have full access to the XFCE desktop environment.

---

## 🐛 Troubleshooting

| Issue | Solution |
|---|---|
| **Chrome Remote Desktop not connecting** | Run `sudo service chrome-remote-desktop restart` and verify your PIN. |
| **No audio in remote session** | Run `pulseaudio -D --exit-idle-time=-1` or use the `startup.sh` script. |
| **AppImage won't launch** | On Ubuntu 22.04 install `libfuse2` alongside `fuse3`; verify `/dev/fuse` exists. |
| **yt-dlp not found** | Make sure `~/.local/bin` is in your PATH: `export PATH="$HOME/.local/bin:$PATH"`. |

---

## 📁 Repository Structure

```
.
├── .devcontainer/
│   ├── devcontainer.json    # Dev container configuration
│   ├── Dockerfile           # Docker image build instructions
│   ├── apt-packages.txt     # Package listing reference
│   ├── post-create.sh       # Post-creation setup script
│   └── startup.sh           # Runtime startup script (keep-alive)
├── README.md                # This file
└── setup-vps.sh             # Automated VPS setup script (generated)
```

---

## 📝 License

This project is provided as-is for personal development use.
