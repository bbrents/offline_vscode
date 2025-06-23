for v in vscode-offline/vsix/*.vsix; do
  ~/.vscode-server/bin/$commit/server/bin/code-server \
        --install-extension "$v" --force
done
# Or just unzip each VSIX under ~/.vscode-server/extensions/
