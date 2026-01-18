# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Automated Downloads organization system that uses Claude Code CLI for intelligent file analysis. Runs automatically via LaunchAgent on macOS (Sundays at 10 AM) or can be executed manually.

## Architecture

This is a **shell script** project (not Node.js/TypeScript), consisting of:

1. **organize-downloads.sh** - Main script that:
   - Scans Downloads folder
   - Collects metadata for each file (name, extension, size, age)
   - Calls Claude Code CLI (`claude --print`) with structured prompt
   - Parses AI response (format: `DECISION: [DESTINATION] | REASON: [text]`)
   - Moves files to categorized destinations
   - Maintains history of processed files via MD5 hash

2. **config.yaml** - Configuration (currently documentation only, not read by script)

3. **install.sh** - Installer that:
   - Copies scripts to `~/.downloads-organizer/`
   - Configures LaunchAgent
   - Creates aliases in shell rc file

4. **com.user.downloads-organizer.plist** - macOS LaunchAgent for scheduling

## AI Decision Flow

The script sends Claude Code a prompt with:
- File information (name, extension, size, age)
- List of 11 possible destinations (ICLOUD, DOCUMENTS, IMAGES, PDFS, CODE, VIDEOS, AUDIO, INSTALLERS, ARCHIVE, TRASH, KEEP)
- Contextual rules (e.g., old .dmg → TRASH, important docs → ICLOUD)

The AI responds in a structured format that is parsed via grep.

## Essential Commands

### Manual Execution
```bash
# Run now (after installation)
organize-downloads

# Dry-run mode (test without moving)
organize-downloads-dry

# Or directly
~/.downloads-organizer/organize-downloads.sh --dry-run --verbose
```

### Installation/Uninstallation
```bash
# Install
./install.sh

# Uninstall
./uninstall.sh
```

### LaunchAgent
```bash
# Check status
launchctl list | grep downloads-organizer

# Force execution
launchctl start com.user.downloads-organizer

# Reload after editing plist
launchctl unload ~/Library/LaunchAgents/com.user.downloads-organizer.plist
launchctl load ~/Library/LaunchAgents/com.user.downloads-organizer.plist
```

### Logs
```bash
# Execution log
tail -f ~/.downloads-organizer/organize.log

# LaunchAgent log
tail -f ~/.downloads-organizer/launchd.log

# Errors
cat ~/.downloads-organizer/stderr.log
```

## Directories

**Source:**
- `~/Downloads` - Scanned folder

**Destinations:**
- `~/Library/Mobile Documents/com~apple~CloudDocs` - ICLOUD
- `~/Documents` - DOCUMENTS
- `~/Documents/Images` - IMAGES
- `~/Documents/PDFs` - PDFS
- `~/Documents/Code` - CODE
- `~/Documents/Videos` - VIDEOS
- `~/Documents/Audio` - AUDIO
- `~/Documents/Installers` - INSTALLERS
- `~/Documents/_Archive` - ARCHIVE
- `~/.Trash` - TRASH

**Config/State:**
- `~/.downloads-organizer/organize-downloads.sh` - Installed script
- `~/.downloads-organizer/config.yaml` - Configuration (not currently used)
- `~/.downloads-organizer/processed.txt` - MD5 hashes of processed files
- `~/.downloads-organizer/organize.log` - Execution logs

## Dependencies

- **Claude Code CLI** - Installed via `npm install -g @anthropic-ai/claude-code`
- **macOS** - For LaunchAgent (Linux can use cron)
- **Bash 3.2+** - macOS default shell

## Known Limitations

1. **config.yaml is not read** - File exists as documentation, but script uses hardcoded variables at the top of `organize-downloads.sh`
2. **No auto-rules implementation** - The `auto_rules` in config.yaml are not applied
3. **Simple parser** - Uses grep to extract decision, may fail if Claude responds outside expected format
4. **No rollback** - Moved files have no automatic undo (only via processed.txt history)

## Common Modifications

### Change destinations
Edit variables at the top of `organize-downloads.sh`:
```bash
DOWNLOADS_DIR="$HOME/Downloads"
ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
# etc...
```

### Change execution schedule
Edit `~/Library/LaunchAgents/com.user.downloads-organizer.plist`:
```xml
<key>Weekday</key>
<integer>0</integer>  <!-- 0=Sun, 1=Mon, ..., 6=Sat -->
<key>Hour</key>
<integer>10</integer> <!-- 0-23 -->
```

### Modify AI prompt
Function `analyze_with_claude()` in `organize-downloads.sh` lines 98-138.

### Add new destination
1. Create directory variable at top of script
2. Add case to switch in `move_file()` lines 150-189
3. Update prompt in `analyze_with_claude()`
4. Add `mkdir -p` in `ensure_dirs()` lines 53-64

## Security

- **No permanent file deletion** - TRASH moves to ~/.Trash
- **Dry-run available** - Test before executing
- **Processing history** - processed.txt prevents reprocessing
- **Complete logs** - Audit trail of all movements
