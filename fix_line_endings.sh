#!/usr/bin/env bash
# -------------------------------------------------------------
# fix_line_endings.sh
#
# Converts CRLF → LF on all *.sh files under the current
# directory (recursively) and sets +x on them.
# -------------------------------------------------------------
set -euo pipefail

echo "🔧 Normalising line endings on *.sh files…"

# Find all .sh files (case-insensitive) and process them one by one
find . -type f \( -iname "*.sh" \) | while IFS= read -r file; do
    # Remove the carriage return at the end of every line (CRLF → LF)
    # The -i flag edits the file in place
    sed -i 's/\r$//' "$file"

    # Ensure the script is executable
    chmod +x "$file"

    printf "  • fixed %s\n" "$file"
done

echo "✅ Done - all shell scripts now use Unix line endings."
