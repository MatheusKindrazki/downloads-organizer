#!/bin/bash
#
# Smart Downloads Organizer - Uninstall Script
#

set -e

CONFIG_DIR="$HOME/.downloads-organizer"
PLIST_FILE="$HOME/Library/LaunchAgents/com.user.downloads-organizer.plist"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       Smart Downloads Organizer - Uninstall                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

read -p "⚠️  Are you sure you want to uninstall? [y/N] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "🗑️  Removing LaunchAgent..."
launchctl unload "$PLIST_FILE" 2>/dev/null || true
rm -f "$PLIST_FILE"

echo "🗑️  Removing configuration files..."
rm -rf "$CONFIG_DIR"

echo "🗑️  Removing shell aliases..."
for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
    if [ -f "$rc" ]; then
        # Remove lines related to Smart Downloads Organizer
        sed -i '' '/# Smart Downloads Organizer/d' "$rc" 2>/dev/null || true
        sed -i '' '/alias organize-downloads/d' "$rc" 2>/dev/null || true
    fi
done

echo ""
echo "✅ Smart Downloads Organizer uninstalled successfully!"
echo ""
echo "Note: Destination directories (Images, PDFs, etc.) were NOT removed."
echo "      Files that were organized remain in their new locations."
