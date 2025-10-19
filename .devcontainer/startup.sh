#!/bin/bash
# Restart chrome remote desktop if available
if command -v chrome-remote-desktop &>/dev/null; then
    sudo /etc/init.d/chrome-remote-desktop restart || true
fi

# Clean PulseAudio runtime files to avoid stale state issues
rm -rf /var/run/pulse /var/lib/pulse /root/.config/pulse

# Start PulseAudio daemon with exit-idle-time disabled, disable console-kit module if needed
if command -v pulseaudio &>/dev/null; then
    pulseaudio -D --exit-idle-time=-1 || true
fi

#!/bin/bash

echo "Script started. Type 'sasi' to stop."

# Function to trigger terminal every 30 seconds
keep_alive() {
    while true; do
        echo "[Keep-alive] Terminal active at $(date)"
        sleep 30
    done
}

# Start keep_alive function in the background
keep_alive &
keep_alive_pid=$!

# Wait for user input to stop
while true; do
    read -r -t 1 -p "Enter command: " input
    if [[ "$input" == "sasi" ]]; then
        echo "Stopping script as requested."
        kill $keep_alive_pid
        wait $keep_alive_pid 2>/dev/null
        break
    fi
done

echo "Script ended."
