#!/usr/bin/env bash
# -------------------------------------------------------------
# install-vscode-server-offline.sh
#
# Unpacks an *offline* VS Code Server + CLI tarball cache into
# ~/.vscode-server so the Remote-SSH extension can launch
# without any Internet access.
#
# Usage:  ./install-vscode-server-offline.sh [<cache-dir>]
# -------------------------------------------------------------

set -euo pipefail

########################################
# ── Pretty colours (no external deps)
########################################
green()  { printf '\e[32m%s\e[0m\n' "$*"; }
yellow() { printf '\e[33m%s\e[0m\n' "$*"; }
red()    { printf '\e[31m%s\e[0m\n' "$*"; }

########################################
# ── Locate cache directory
########################################
CACHE_DIR=${1:-./vscode-offline}

if [[ ! -d $CACHE_DIR ]]; then
  red "ERROR: Cache directory '$CACHE_DIR' not found"; exit 1
fi

########################################
# ── Detect commit hash
########################################
mapfile -t SERVER_TARS < <(ls "$CACHE_DIR"/vscode-server-linux-x64-*.tar.gz 2>/dev/null || true)

if (( ${#SERVER_TARS[@]} == 0 )); then
  red "ERROR: No vscode-server-linux-x64-*.tar.gz found in $CACHE_DIR"; exit 1
elif (( ${#SERVER_TARS[@]} > 1 )); then
  yellow "WARNING: Multiple server tarballs found, using the first one:"
  for t in "${SERVER_TARS[@]}"; do echo "  $t"; done
fi

SERVER_TAR=${SERVER_TARS[0]}
commit=$(echo "$SERVER_TAR" | sed -E 's/.*-([0-9a-f]{40})\.tar\.gz/\1/')

green "- Using commit hash: $commit"

########################################
# ── Paths VS Code Remote-SSH expects
########################################
BIN_DIR="$HOME/.vscode-server/bin/$commit"
CLI_DIR="$HOME/.vscode-server/cli/servers/Stable-$commit"

########################################
# ── 1. Install VS Code Server
########################################
if [[ -d $BIN_DIR ]]; then
  yellow "Server already present → $BIN_DIR (skipping)"
else
  green "Installing VS Code Server to $BIN_DIR"
  mkdir -p "$BIN_DIR"
  tar -xzf "$SERVER_TAR" -C "$BIN_DIR" --strip-components=1
  touch "$BIN_DIR/0"     # signal “ready” to Remote-SSH
fi

########################################
# ── 2. Install CLI helper (VS Code ≥ 1.90)
########################################
CLI_TAR="$CACHE_DIR/vscode-cli-alpine-x64-$commit.tar.gz"
if [[ -f $CLI_TAR ]]; then
  if [[ -d $CLI_DIR ]]; then
    yellow "CLI already present → $CLI_DIR (skipping)"
  else
    green "Installing CLI helper to $CLI_DIR"
    mkdir -p "$CLI_DIR"
    tar -xzf "$CLI_TAR" -C "$CLI_DIR" --strip-components=1
  fi
else
  yellow "NOTE: No CLI tarball found – assuming VS Code < 1.90"
fi

########################################
# ── Success
########################################
green "✔ VS Code Server offline install complete"

echo "
Next steps:
1. Set these *desktop* VS Code settings to prevent network downloads:
   \"remote.SSH.localServerDownload\": \"off\",
   \"remote.SSH.useLocalServer\": true

2. Use the Remote-SSH extension to connect - startup should be immediate
   and fully offline.
"
