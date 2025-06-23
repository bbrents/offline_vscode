cd
commit=$(ls vscode-offline/vscode-server-linux-x64-*.tar.gz | \
         sed -E 's/.*-([0-9a-f]{40})\.tar\.gz/\1/')

# ── 2-A  VS Code Server ───────────────────────────────────────────────
mkdir -p ~/.vscode-server/bin/$commit
tar -xzf vscode-offline/vscode-server-linux-x64-$commit.tar.gz \
    -C   ~/.vscode-server/bin/$commit --strip-components=1
touch ~/.vscode-server/bin/$commit/0          # tells Remote-SSH “it’s ready”

# ── 2-B  CLI helper (required for VS Code ≥ 1.90) ─────────────────────
mkdir -p ~/.vscode-server/cli/servers/Stable-$commit
tar -xzf vscode-offline/vscode-cli-alpine-x64-$commit.tar.gz \
    -C   ~/.vscode-server/cli/servers/Stable-$commit --strip-components=1
