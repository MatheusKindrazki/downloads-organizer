# 📁 Smart Downloads Organizer

Automated Downloads organization system using **Claude Code CLI** for intelligent file analysis.

## 🎯 What does it do?

Every Sunday at 10 AM, the script analyzes each file in your Downloads folder and uses AI to decide the best destination:

| Destination | Description |
|-------------|-------------|
| **iCloud** | Important files (cloud backup) |
| **Documents** | General frequently-used docs |
| **Images** | Photos, screenshots, graphics |
| **PDFs** | PDF documents |
| **Code** | Scripts, projects, code files |
| **Videos** | Video files |
| **Audio** | Music and audio files |
| **Installers** | .dmg, .pkg, apps |
| **Archive** | Old files for archiving |
| **Trash** | Temporary files, garbage |

## 🚀 Quick Install

```bash
# 1. Make sure you have Claude Code installed
npm install -g @anthropic-ai/claude-code

# 2. Run the installer
cd downloads-organizer
chmod +x install.sh
./install.sh
```

## 📋 Prerequisites

- macOS (uses LaunchAgent for scheduling)
- Claude Code CLI installed and authenticated
- Node.js (for Claude Code)

## 🔧 Manual Usage

### Standard Version (Sequential Processing)
```bash
# Run now
organize-downloads

# Test without moving files (dry-run)
organize-downloads-dry

# Or directly
~/.downloads-organizer/organize-downloads.sh --dry-run --verbose
```

### 🚀 Ultra-Fast Version (Recommended)
**10-50x faster!** Analyzes all files in a single Claude API call.

```bash
# Run ultra-fast version
./organize-downloads-ultra.sh

# Dry-run test
./organize-downloads-ultra.sh --dry-run --verbose

# Requirements: jq (install with: brew install jq)
```

### Performance Comparison

| Version | Speed | API Calls | Best For |
|---------|-------|-----------|----------|
| **Standard** | 1x | 1 per file | Small batches (<10 files) |
| **Ultra** | 10-50x | 1 total | Any size (recommended!) |

**Example:** 50 files takes ~5 minutes with standard, ~10 seconds with ultra!

## ⚙️ Configuration

Edit `~/.downloads-organizer/config.yaml` to customize:

```yaml
# Change destination directories
directories:
  icloud: ~/Library/Mobile Documents/com~apple~CloudDocs/Organized

# Add automatic rules
auto_rules:
  trash:
    extensions: [".tmp", ".log"]

# Exclude specific files
exclusions:
  files:
    - "important-file.pdf"
```

## 📅 Change Schedule Time

Edit `~/Library/LaunchAgents/com.user.downloads-organizer.plist`:

```xml
<key>StartCalendarInterval</key>
<dict>
    <key>Weekday</key>
    <integer>0</integer>  <!-- 0=Sun, 1=Mon, ..., 6=Sat -->
    <key>Hour</key>
    <integer>10</integer> <!-- Hour (0-23) -->
    <key>Minute</key>
    <integer>0</integer>  <!-- Minute (0-59) -->
</dict>
```

Then reload:

```bash
launchctl unload ~/Library/LaunchAgents/com.user.downloads-organizer.plist
launchctl load ~/Library/LaunchAgents/com.user.downloads-organizer.plist
```

### Schedule Examples

```xml
<!-- Every day at 9:00 AM -->
<key>StartCalendarInterval</key>
<dict>
    <key>Hour</key>
    <integer>9</integer>
    <key>Minute</key>
    <integer>0</integer>
</dict>

<!-- Monday and Friday at 6:00 PM -->
<key>StartCalendarInterval</key>
<array>
    <dict>
        <key>Weekday</key>
        <integer>1</integer>
        <key>Hour</key>
        <integer>18</integer>
    </dict>
    <dict>
        <key>Weekday</key>
        <integer>5</integer>
        <key>Hour</key>
        <integer>18</integer>
    </dict>
</array>
```

## 📊 Logs

```bash
# View execution logs
tail -f ~/.downloads-organizer/organize.log

# View LaunchAgent logs
tail -f ~/.downloads-organizer/launchd.log
```

## 🔍 How Does the AI Decide?

Claude Code analyzes each file considering:

1. **File name** - Indicates purpose
2. **Extension** - File type
3. **Size** - Large files may be more important
4. **Age** - Old files may be archived
5. **Context** - Screenshots, installers, etc.

Example analysis:

```
File: Q4-2025-Report.pdf
Extension: pdf
Size: 2.3MB
Age: 5 days

DECISION: ICLOUD | REASON: Important financial report, should have cloud backup
```

## 🗑️ Uninstall

```bash
./uninstall.sh
```

Or manually:

```bash
launchctl unload ~/Library/LaunchAgents/com.user.downloads-organizer.plist
rm ~/Library/LaunchAgents/com.user.downloads-organizer.plist
rm -rf ~/.downloads-organizer
```

## 🐛 Troubleshooting

### "Claude Code CLI not found"

```bash
npm install -g @anthropic-ai/claude-code
# Make sure you're authenticated
claude auth
```

### Script doesn't run on Sunday

```bash
# Check if loaded
launchctl list | grep downloads-organizer

# Force execution for testing
launchctl start com.user.downloads-organizer
```

### Check errors

```bash
cat ~/.downloads-organizer/stderr.log
```

## 📁 File Structure

```
~/.downloads-organizer/
├── organize-downloads.sh  # Main script
├── config.yaml            # Configuration
├── organize.log           # Execution log
├── processed.txt          # Already processed files
├── stdout.log             # Standard output
└── stderr.log             # Errors

~/Library/LaunchAgents/
└── com.user.downloads-organizer.plist  # Scheduling
```

## 💡 Tips

1. **Run a dry-run first** to see what would be moved
2. **Customize rules** in config.yaml for your workflow
3. **Check logs** after the first executions
4. **Add exclusions** for files that should stay in Downloads

---

Created with ❤️ using Claude Code
