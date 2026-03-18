#!/bin/bash
set -e

BINARY_NAME="zeno_shell"
INSTALL_DIR="/usr/local/bin"

echo "Building zeno-shell..."
zig build -Doptimize=ReleaseFast

echo "Installing to $INSTALL_DIR/$BINARY_NAME..."
if [[ -w "$INSTALL_DIR" ]]; then
    cp "zig-out/bin/$BINARY_NAME" "$INSTALL_DIR/$BINARY_NAME"
else
    sudo cp "zig-out/bin/$BINARY_NAME" "$INSTALL_DIR/$BINARY_NAME"
fi

echo "Detecting shell..."
SHELL_NAME=$(basename "$SHELL")

case "$SHELL_NAME" in
    zsh)
        RC_FILE="$HOME/.zshrc"
        INIT_LINE='eval "$(zeno_shell init zsh)"'
        ;;
    bash)
        RC_FILE="$HOME/.bashrc"
        INIT_LINE='eval "$(zeno_shell init bash)"'
        ;;
    *)
        echo "Shell '$SHELL_NAME' not supported yet. Add the init line manually."
        echo "  zsh:  eval \"\$(zeno_shell init zsh)\""
        echo "  bash: eval \"\$(zeno_shell init bash)\""
        exit 0
        ;;
esac

if grep -qF "$INIT_LINE" "$RC_FILE" 2>/dev/null; then
    echo "Hook already present in $RC_FILE — skipping."
else
    echo "Adding hook to $RC_FILE..."
    echo "$INIT_LINE" >> "$RC_FILE"
fi

echo ""
echo "Done. Run the following to activate in your current session:"
echo ""
echo "  source $RC_FILE"