#!/bin/bash
#
# Smart Downloads Organizer - Installation Script
# Sets up automatic scheduling on macOS
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.downloads-organizer"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       Smart Downloads Organizer - Installation               ║"
echo "║       Powered by Claude Code                                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if it's macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "❌ This script is for macOS only."
    echo "   For Linux, use cron manually."
    exit 1
fi

# Check if Claude Code is installed
echo "🔍 Checking dependencies..."

if ! command -v claude &> /dev/null; then
    echo ""
    echo "⚠️  Claude Code CLI not found!"
    echo ""
    echo "Install Claude Code first:"
    echo "  npm install -g @anthropic-ai/claude-code"
    echo ""
    echo "After installing, run this script again."
    exit 1
fi

echo "✅ Claude Code CLI found: $(which claude)"

# Create configuration directory
echo ""
echo "📁 Creating configuration directory..."
mkdir -p "$CONFIG_DIR"
mkdir -p "$LAUNCH_AGENTS_DIR"

# Copy scripts
echo "📋 Copying scripts..."
cp "$SCRIPT_DIR/organize-downloads-ultra.sh" "$CONFIG_DIR/"
cp "$SCRIPT_DIR/organize-downloads.sh" "$CONFIG_DIR/"
cp "$SCRIPT_DIR/organize-downloads-fast.sh" "$CONFIG_DIR/" 2>/dev/null || true
chmod +x "$CONFIG_DIR/organize-downloads-ultra.sh"
chmod +x "$CONFIG_DIR/organize-downloads.sh"
chmod +x "$CONFIG_DIR/organize-downloads-fast.sh" 2>/dev/null || true

echo "✅ Ultra-fast version installed as default"

# Copy configuration if it doesn't exist
if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
    cp "$SCRIPT_DIR/config.yaml" "$CONFIG_DIR/"
    echo "✅ Configuration file created at: $CONFIG_DIR/config.yaml"
else
    echo "ℹ️  Configuration file already exists, keeping current"
fi

# Process plist replacing $HOME
echo ""
echo "⏰ Setting up schedule for every Sunday at 10:00 AM..."

PLIST_FILE="$LAUNCH_AGENTS_DIR/com.user.downloads-organizer.plist"

# Replace $HOME with real path
sed "s|\$HOME|$HOME|g" "$SCRIPT_DIR/com.user.downloads-organizer.plist" > "$PLIST_FILE"

# Unload if already loaded
launchctl unload "$PLIST_FILE" 2>/dev/null || true

# Load new LaunchAgent
launchctl load "$PLIST_FILE"

echo "✅ LaunchAgent installed and loaded"

# Create destination directories
echo ""
echo "📂 Creating destination directories..."

mkdir -p "$HOME/Documents/Images"
mkdir -p "$HOME/Documents/PDFs"
mkdir -p "$HOME/Documents/Code"
mkdir -p "$HOME/Documents/Videos"
mkdir -p "$HOME/Documents/Audio"
mkdir -p "$HOME/Documents/Installers"
mkdir -p "$HOME/Documents/_Archive"

echo "✅ Directories created"

# Create aliases for easy access
echo ""
echo "🔗 Creating shortcuts..."

ALIASES_ADDED=false

# Function to add/update aliases
add_aliases() {
    local rc_file="$1"
    local is_fish="$2"

    # Remove old aliases if they exist
    if [ "$is_fish" = "true" ]; then
        sed -i '' '/# Smart Downloads Organizer/d' "$rc_file" 2>/dev/null || true
        sed -i '' '/alias organize-downloads/d' "$rc_file" 2>/dev/null || true
    else
        sed -i '' '/# Smart Downloads Organizer/d' "$rc_file" 2>/dev/null || true
        sed -i '' '/alias organize-downloads/d' "$rc_file" 2>/dev/null || true
    fi

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
}

# Zsh
if [ -f "$HOME/.zshrc" ]; then
    add_aliases "$HOME/.zshrc" "false"
    echo "✅ Aliases added to ~/.zshrc"
    ALIASES_ADDED=true
fi

# Bash
if [ -f "$HOME/.bashrc" ]; then
    add_aliases "$HOME/.bashrc" "false"
    echo "✅ Aliases added to ~/.bashrc"
    ALIASES_ADDED=true
fi

if [ -f "$HOME/.bash_profile" ]; then
    add_aliases "$HOME/.bash_profile" "false"
    echo "✅ Aliases added to ~/.bash_profile"
    ALIASES_ADDED=true
fi

# Fish
if [ -f "$HOME/.config/fish/config.fish" ]; then
    add_aliases "$HOME/.config/fish/config.fish" "true"
    echo "✅ Aliases added to ~/.config/fish/config.fish"
    ALIASES_ADDED=true
elif command -v fish &>/dev/null; then
    # Fish is installed but config doesn't exist, create it
    mkdir -p "$HOME/.config/fish"
    touch "$HOME/.config/fish/config.fish"
    add_aliases "$HOME/.config/fish/config.fish" "true"
    echo "✅ Aliases added to ~/.config/fish/config.fish"
    ALIASES_ADDED=true
fi

if [ "$ALIASES_ADDED" = true ]; then
    echo "   Restart your terminal or run 'source <rc-file>' to use the commands"
else
    echo "⚠️  No shell RC file found. Add aliases manually if needed."
fi

# Summary
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ Installation Complete!                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📍 File locations:"
echo "   Script:      $CONFIG_DIR/organize-downloads.sh"
echo "   Config:      $CONFIG_DIR/config.yaml"
echo "   Logs:        $CONFIG_DIR/organize.log"
echo "   LaunchAgent: $PLIST_FILE"
echo ""
echo "📅 Schedule:"
echo "   The script will run automatically every SUNDAY at 10:00 AM"
echo "   Using ULTRA-FAST version (10-50x faster!)"
echo ""
echo "🚀 Useful commands:"
echo "   organize-downloads              # Run ultra-fast version (DEFAULT)"
echo "   organize-downloads-dry          # Test without moving files"
echo "   organize-downloads-standard     # Run standard version (slower)"
echo "   organize-downloads-standard-dry # Test standard version"
echo ""
echo "🔧 To modify the schedule:"
echo "   1. Edit: $PLIST_FILE"
echo "   2. Change Weekday (0=Sun, 1=Mon...) and Hour (0-23)"
echo "   3. Run: launchctl unload $PLIST_FILE"
echo "   4. Run: launchctl load $PLIST_FILE"
echo ""
echo "❓ To uninstall:"
echo "   launchctl unload $PLIST_FILE"
echo "   rm -rf $CONFIG_DIR"
echo "   rm $PLIST_FILE"
echo ""

# Ask if want to run a test
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -p "🧪 Do you want to run a test now (dry-run)? [y/N] " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Running test..."
    echo ""
    "$CONFIG_DIR/organize-downloads.sh" --dry-run --verbose
fi
