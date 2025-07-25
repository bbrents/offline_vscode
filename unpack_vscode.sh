#!/usr/bin/env bash
# -------------------------------------------------------------
# install-vscode-server-offline.sh
#
# Unpacks an *offline* VS Code CLI + Server cache into BOTH:
#   • ~/.vscode-server/cli/servers/<Channel>-<commit>/server   (new layout ≥1.82)
#   • ~/.vscode-server/bin/<commit>/                           (legacy layout)
# so Remote-SSH will never try to download.
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

### ── Find tarballs ------------------------------------------
SERVER_TAR=$(ls "$CACHE_DIR"/vscode-server-linux-*.tar.gz 2>/dev/null | head -n1)
[[ -f $SERVER_TAR ]] || { red "ERROR: no server tarball found"; exit 1; }

# Prefer to read commit from product.json (filename can be generic now)
commit=$(tar -xOf "$SERVER_TAR" product.json 2>/dev/null \
         | grep -oP '"commit"\s*:\s*"\K[0-9a-f]{40}' || true)
if [[ -z $commit ]]; then
  # fallback to old filename pattern
  commit=$(basename "$SERVER_TAR" | sed -E 's/.*-([0-9a-f]{40})\.tar\.gz/\1/')
fi
[[ -n $commit ]] || { red "ERROR: could not determine commit id"; exit 1; }
green "- commit: $commit"

# detect channel (stable/insider) from product.json (default Stable)
quality=$(tar -xOf "$SERVER_TAR" product.json 2>/dev/null \
          | grep -oP '"quality"\s*:\s*"\K[^"]+' || true)
CHANNEL=${quality:-stable}
# Capitalise first letter to match folder names (Stable / Insider)
CHANNEL_CAP=${CHANNEL^}

# CLI tarball: accept any name, just make sure it matches this commit
CLI_TAR=$(ls "$CACHE_DIR"/vscode-cli-*"$commit"*.tar.gz 2>/dev/null | head -n1 || true)
[[ -f $CLI_TAR ]] || { red "ERROR: matching CLI tarball not found for $commit"; exit 1; }

### ── Paths ---------------------------------------------------
AGENT_DIR=${VSCODE_AGENT_FOLDER:-"$HOME/.vscode-server"}
NEW_ROOT="$AGENT_DIR/cli/servers/${CHANNEL_CAP}-${commit}"
NEW_SERVER_DIR="$NEW_ROOT/server"
OLD_ROOT="$AGENT_DIR/bin/${commit}"

mkdir -p "$AGENT_DIR"

### ── Stage CLI tarball (marker files) -----------------------
green "• staging CLI helper"
cp -f "$CLI_TAR" "$AGENT_DIR/vscode-cli-${commit}.tar.gz"
cp -f "$CLI_TAR" "$AGENT_DIR/vscode-cli-${commit}.tar.gz.done"

### ── Unpack server: new layout ------------------------------
if [[ -d $NEW_SERVER_DIR ]]; then
  yellow "• server already present → $NEW_SERVER_DIR  (skipping)"
else
  green "• installing server to $NEW_SERVER_DIR"
  mkdir -p "$NEW_SERVER_DIR"
  tar -xzf "$SERVER_TAR" -C "$NEW_SERVER_DIR" --strip-components=1
fi

### ── Legacy layout mirror (/bin/<commit>) -------------------
green "• ensuring legacy layout ~/.vscode-server/bin/${commit}"
mkdir -p "$OLD_ROOT"

# Don’t waste space: symlink the 'server' dir if possible
if [[ -e "$OLD_ROOT/server" ]]; then
  : # already there
else
  ln -s "$NEW_SERVER_DIR" "$OLD_ROOT/server" 2>/dev/null || {
    # If symlink fails (weird FS), fall back to copy
    tar -xzf "$SERVER_TAR" -C "$OLD_ROOT"
  }
fi

# Minimal shim that some older probes still exec
cat > "$OLD_ROOT/server.sh" <<'EOF'
#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$DIR/server/bin/code" "$@"
EOF
chmod +x "$OLD_ROOT/server.sh"

### ── Done ----------------------------------------------------
green "✔ VS Code Server ready for offline Remote-SSH"
echo "  New layout : $NEW_SERVER_DIR"
echo "  Old layout : $OLD_ROOT"
echo "  CLI marker : $AGENT_DIR/vscode-cli-${commit}.tar.gz(.done)"
echo
echo "Tip (desktop settings to stay fully offline):"
echo '  "remote.SSH.localServerDownload": "off",'
echo '  "remote.SSH.useLocalServer": true'
