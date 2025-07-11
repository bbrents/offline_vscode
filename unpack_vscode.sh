#!/usr/bin/env bash
# -------------------------------------------------------------
# install-vscode-server-offline.sh
#
# Unpacks an *offline* VS Code CLI + Server cache into the
# exact folders that the Remote-SSH exec-server bootstrap
# looks for (VS Code ≥ 1.82) – completely offline.
#
# Usage:  ./install-vscode-server-offline.sh  [<cache-dir>]
#         (default <cache-dir> is ./vscode-offline)
# -------------------------------------------------------------
set -euo pipefail

### ── Colours -------------------------------------------------
green()  { printf '\e[32m%s\e[0m\n' "$*"; }
yellow() { printf '\e[33m%s\e[0m\n' "$*"; }
red()    { printf '\e[31m%s\e[0m\n' "$*"; }

### ── Locate cache dir ---------------------------------------
CACHE_DIR=${1:-./vscode-offline}
[[ -d $CACHE_DIR ]] || { red "ERROR: '$CACHE_DIR' not found"; exit 1; }

### ── Detect commit hash (from server tar) -------------------
SERVER_TAR=$(ls "$CACHE_DIR"/vscode-server-linux-x64-*.tar.gz | head -n1)
[[ -f $SERVER_TAR ]] || { red "ERROR: no server tarball found"; exit 1; }
commit=$(basename "$SERVER_TAR" | sed -E 's/.*-([0-9a-f]{40})\.tar\.gz/\1/')
green "- commit: $commit"

CLI_TAR=$(ls "$CACHE_DIR"/vscode-cli-alpine-x64-"$commit".tar.gz 2>/dev/null || true)
[[ -f $CLI_TAR ]] || { red "ERROR: matching CLI tarball not found"; exit 1; }

### ── Stage CLI tarball (just copy + .done flag) -------------
green "• staging CLI helper"
mkdir -p "$HOME/.vscode-server"
cp -f "$CLI_TAR" "$HOME/.vscode-server/vscode-cli-alpine-x64-${commit}.tar.gz.done"

### ── Unpack server under exec-server path -------------------
SERVER_DIR="$HOME/.vscode-server/cli/servers/Stable-${commit}/server"
if [[ -d $SERVER_DIR ]]; then
  yellow "• server already present → $SERVER_DIR  (skipping)"
else
  green "• installing server to $SERVER_DIR"
  mkdir -p "$SERVER_DIR"
  tar -xzf "$SERVER_TAR" -C "$SERVER_DIR" --strip-components=1
fi

### ── Done ----------------------------------------------------
green "✔ VS Code Server ready for offline Remote-SSH"
echo "  Tip: Set these *desktop* settings to avoid any network traffic:"
echo '        "remote.SSH.localServerDownload": "off",'
echo '        "remote.SSH.useLocalServer": true'
