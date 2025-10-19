#!/usr/bin/env bash
set -euo pipefail

echo "[post-create] Updating apt package index..."
sudo apt-get update -y

# Add any extra apt packages you want in *addition* to what the Dockerfile installs.
EXTRA_APT_PACKAGES=(
  jq
  make
)
if [ ${#EXTRA_APT_PACKAGES[@]} -gt 0 ]; then
  echo "[post-create] Installing extra apt packages: ${EXTRA_APT_PACKAGES[*]}"
  sudo apt-get install -y "${EXTRA_APT_PACKAGES[@]}"
fi

# Python dependencies (project-level)
if [ -f "requirements.txt" ]; then
  echo "[post-create] Installing Python dependencies from requirements.txt"
  pip install --upgrade pip
  pip install -r requirements.txt
fi

# Node.js dependencies (project-level)
if [ -f "package-lock.json" ] || [ -f "pnpm-lock.yaml" ] || [ -f "yarn.lock" ]; then
  echo "[post-create] Installing Node dependencies"
  if command -v pnpm >/dev/null 2>&1 && [ -f "pnpm-lock.yaml" ]; then
    pnpm install --frozen-lockfile
  elif command -v yarn >/dev/null 2>&1 && [ -f "yarn.lock" ]; then
    yarn install --frozen-lockfile
  else
    npm ci || npm install
  fi
fi

# Pre-commit hooks (optional)
if [ -f ".pre-commit-config.yaml" ]; then
  echo "[post-create] Installing pre-commit hooks"
  pip install pre-commit
  pre-commit install
fi

echo "[post-create] Done."
