#!/usr/bin/env bash

set -euo pipefail

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_NAME=$(basename "$0")
LOGFILE="install_visx.log"

# Spinner function
tspin() {
  local pid=$1
  local spinner='|/-\\'
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i+1) %4 ))
    printf "\r${BLUE}Installing... %c${NC}" "${spinner:$i:1}"
    sleep .1
  done
  printf "\r"
}

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [<path-to-visx-file> | <directory>]

Installs one or more VS Code extension packages (.vsix).

If no argument is provided, installs all .vsix files in the script's directory.
If a directory is provided, installs all .vsix files in that directory.
If a .vsix file is provided, installs that single file.

Options:
  -h, --help   Show this help message and exit.
EOF
}

log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOGFILE"
}

error_exit() {
  echo -e "${RED}Error:${NC} $*" >&2
  log "ERROR: $*"
  exit 1
}

cleanup() {
  rm -f /tmp/install_visx.tmp
}

trap cleanup EXIT

# Determine targets
declare -a VISX_FILES
if [ $# -eq 0 ]; then
  BASEDIR="$(cd "$(dirname "$0")" && pwd)"
  VISX_FILES=("$BASEDIR"/*.vsix)
elif [ $# -eq 1 ]; then
  if [ -d "$1" ]; then
    VISX_FILES=("$1"/*.vsix)
  elif [ -f "$1" ]; then
    VISX_FILES=("$1")
  else
    error_exit "Not a valid file or directory: $1"
  fi
else
  usage
  exit 1
fi

# Install loop
for VISX in "${VISX_FILES[@]}"; do
  [ -f "$VISX" ] || { log "No .vsix files found. Exiting."; exit 0; }
  EXT_ID=$(basename "$VISX" .vsix)

  # Skip if already installed
  if code --list-extensions | grep -Fxq "$EXT_ID"; then
    echo -e "${YELLOW}⚠ Extension '$EXT_ID' already installed, skipping.${NC}"
    log "Skipped $EXT_ID (already installed)"
    continue
  fi

  log "Installing $EXT_ID from $VISX"

  # Install with spinner
  {
    code --install-extension "$VISX" &> /tmp/install_visx.tmp &
    spin $!
  } || {
    cat /tmp/install_visx.tmp
    error_exit "Installation of $EXT_ID failed."
  }

  echo -e "${GREEN}✔ Extension '$EXT_ID' installed successfully!${NC}"
  log "Successfully installed $EXT_ID"

  # Cleanup
  rm -f /tmp/install_visx.tmp

done

exit 0
