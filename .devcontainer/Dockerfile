FROM ubuntu:22.04

# Avoid interactive prompts during package installs
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC

# Update + upgrade base system
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    locales \
        wget curl gnupg sudo build-essential \
        dbus-x11 xfce4 desktop-base xscreensaver \
        vlc file-roller screen mkvtoolnix mkvtoolnix-gui \
        qbittorrent thonny \
        libqt5webenginecore5 libqt5webenginewidgets5 \
        libqt5script5 libqt5scripttools5 \
    && rm -rf /var/lib/apt/lists/*

# Chrome Remote Desktop
RUN wget https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb && \
    apt-get update && apt-get install -y ./chrome-remote-desktop_current_amd64.deb && \
    rm chrome-remote-desktop_current_amd64.deb

# AB Download Manager
RUN wget https://github.com/amir1376/ab-download-manager/releases/download/v1.5.4/ABDownloadManager_1.5.4_linux_x64.deb && \
    apt-get update && apt-get install -y ./ABDownloadManager_1.5.4_linux_x64.deb && \
    rm ABDownloadManager_1.5.4_linux_x64.deb

# Avidemux AppImage (downloaded into /opt)
RUN wget -O /opt/avidemux.AppImage "https://www.dropbox.com/scl/fi/c2vo7dc9blemneue71owr/avidemux_2.8.1.appImage?rlkey=4zodz3mtwt418r8n3x5k2ep78&st=y53w0p0j&dl=1" && \
    chmod +x /opt/avidemux.AppImage

# Telegram AppImage (downloaded into /opt)
RUN wget -O /opt/telegram.AppImage "https://www.dropbox.com/scl/fi/h3szk2c2gscmvu7rfp2ty/Telegram.AppImage?rlkey=hmfixuty7bt9wfdbxbmakmyri&st=h0mjn9aw&dl=1" && \
    chmod +x /opt/telegram.AppImage

# Firefox (official Mozilla repo)
RUN install -d -m 0755 /etc/apt/keyrings && \
    wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null && \
    echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | tee -a /etc/apt/sources.list.d/mozilla.list > /dev/null && \
    echo 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000' > /etc/apt/preferences.d/mozilla && \
    apt-get update && apt-get install -y firefox

# Video DownloadHelper Companion App
RUN curl -sSLf https://github.com/aclap-dev/vdhcoapp/releases/latest/download/install.sh | bash || true

# Chrome Remote Desktop session config
RUN bash -c 'echo "exec /etc/X11/Xsession /usr/bin/xfce4-session" > /etc/chrome-remote-desktop-session'

# Locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# Create a non-root user (vscode) with sudo
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000
RUN groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd -s /bin/bash --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-${USERNAME} \
    && chmod 0440 /etc/sudoers.d/90-${USERNAME}

# Optional: create a default Python virtualenv for the user
RUN mkdir -p /home/${USERNAME}/.venvs && chown -R ${USERNAME}:${USER_GID} /home/${USERNAME}/.venvs
USER ${USERNAME}
RUN python3 -m venv /home/${USERNAME}/.venvs/default
ENV VIRTUAL_ENV=/home/${USERNAME}/.venvs/default
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Switch back to root for any final tweaks
USER root

# Codespaces mounts the repo at /workspaces/<repo>, but setting a sane default doesn't hurt
WORKDIR /workspaces

# Use non-root user by default
USER ${USERNAME}
