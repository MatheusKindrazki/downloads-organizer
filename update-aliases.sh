#!/bin/bash
#
# Smart Downloads Organizer - Update Aliases Script
# Updates shell aliases to use the ultra-fast version
#

set -e

CONFIG_DIR="$HOME/.downloads-organizer"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       Smart Downloads Organizer - Update Aliases            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

update_aliases() {
    local rc_file="$1"
    local is_fish="$2"
    local shell_name="$3"

    if [ ! -f "$rc_file" ]; then
        return
    fi

    echo "🔄 Updating $shell_name aliases..."

    # Remove old aliases
    sed -i '' '/# Smart Downloads Organizer/d' "$rc_file" 2>/dev/null || true
    sed -i '' '/alias organize-downloads/d' "$rc_file" 2>/dev/null || true

    # Add new aliases
    echo "" >> "$rc_file"
    echo "# Smart Downloads Organizer" >> "$rc_file"

    if [ "$is_fish" = "true" ]; then
        # Fish shell syntax (no equals sign)
        echo "alias organize-downloads '$CONFIG_DIR/organize-downloads-ultra.sh'" >> "$rc_file"
        echo "alias organize-downloads-dry '$CONFIG_DIR/organize-downloads-ultra.sh --dry-run --verbose'" >> "$rc_file"
        echo "alias organize-downloads-standard '$CONFIG_DIR/organize-downloads.sh'" >> "$rc_file"
        echo "alias organize-downloads-standard-dry '$CONFIG_DIR/organize-downloads.sh --dry-run --verbose'" >> "$rc_file"
    else
        # Bash/Zsh syntax (with equals sign)
        echo "alias organize-downloads='$CONFIG_DIR/organize-downloads-ultra.sh'" >> "$rc_file"
        echo "alias organize-downloads-dry='$CONFIG_DIR/organize-downloads-ultra.sh --dry-run --verbose'" >> "$rc_file"
        echo "alias organize-downloads-standard='$CONFIG_DIR/organize-downloads.sh'" >> "$rc_file"
        echo "alias organize-downloads-standard-dry='$CONFIG_DIR/organize-downloads.sh --dry-run --verbose'" >> "$rc_file"
    fi

    echo "   ✅ Updated $rc_file"
}

# Update all shell configs
update_aliases "$HOME/.zshrc" "false" "Zsh"
update_aliases "$HOME/.bashrc" "false" "Bash"
update_aliases "$HOME/.bash_profile" "false" "Bash"

if [ -f "$HOME/.config/fish/config.fish" ] || command -v fish &>/dev/null; then
    mkdir -p "$HOME/.config/fish"
    touch "$HOME/.config/fish/config.fish"
    update_aliases "$HOME/.config/fish/config.fish" "true" "Fish"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ Aliases Updated!                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "🔄 To apply changes:"
echo "   Zsh:  source ~/.zshrc"
echo "   Bash: source ~/.bashrc"
echo "   Fish: source ~/.config/fish/config.fish"
echo ""
echo "   Or just open a new terminal!"
echo ""
