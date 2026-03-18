#!/bin/bash
set -e

BINARY_NAME="zeno_shell"
INSTALL_DIR="/usr/local/bin"
BINARY_PATH="$INSTALL_DIR/$BINARY_NAME"

ZSH_RC="$HOME/.zshrc"
BASH_RC="$HOME/.bashrc"
ZSH_INIT_LINE='eval "$(zeno_shell init zsh)"'
BASH_INIT_LINE='eval "$(zeno_shell init bash)"'

INDEX_DIR_LINUX="$HOME/.local/share/zeno-shell"
INDEX_DIR_MACOS="$HOME/Library/Application Support/zeno-shell"

# ── Remove binary ─────────────────────────────────────────────────────────────
if [[ -f "$BINARY_PATH" ]]; then
    echo "Removing $BINARY_PATH..."
    if [[ -w "$INSTALL_DIR" ]]; then
        rm "$BINARY_PATH"
    else
        sudo rm "$BINARY_PATH"
    fi
else
    echo "Binary not found at $BINARY_PATH — skipping."
fi

# ── Remove shell hooks ────────────────────────────────────────────────────────
remove_line() {
    local file="$1"
    local line="$2"
    if [[ -f "$file" ]] && grep -qF "$line" "$file" 2>/dev/null; then
        echo "Removing hook from $file..."
        # Use a temp file for portability across macOS and Linux sed
        local tmp
        tmp=$(mktemp)
        grep -vF "$line" "$file" > "$tmp"
        mv "$tmp" "$file"
    fi
}

remove_line "$ZSH_RC" "$ZSH_INIT_LINE"
remove_line "$BASH_RC" "$BASH_INIT_LINE"

# ── Optionally remove index data ──────────────────────────────────────────────
INDEX_DIR=""
if [[ -d "$INDEX_DIR_MACOS" ]]; then
    INDEX_DIR="$INDEX_DIR_MACOS"
elif [[ -d "$INDEX_DIR_LINUX" ]]; then
    INDEX_DIR="$INDEX_DIR_LINUX"
fi

if [[ -n "$INDEX_DIR" ]]; then
    echo ""
    read -r -p "Remove index data at '$INDEX_DIR'? This deletes your command history. [y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        rm -rf "$INDEX_DIR"
        echo "Index data removed."
    else
        echo "Index data kept at $INDEX_DIR."
    fi
fi

echo ""
echo "Done. Run the following to deactivate in your current session:"
echo ""
SHELL_NAME=$(basename "$SHELL")
case "$SHELL_NAME" in
    zsh)  echo "  source $ZSH_RC" ;;
    bash) echo "  source $BASH_RC" ;;
    *)    echo "  Reload your shell manually." ;;
esac