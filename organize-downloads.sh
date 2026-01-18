#!/bin/bash
#
# Smart Downloads Organizer - Powered by Claude Code
# Analyzes files in Downloads folder and uses AI to decide destination
#
# Usage: ./organize-downloads.sh [--dry-run] [--verbose]
#

set -euo pipefail

# ============================================================================
# CONFIGURATION - Adjust these paths as needed
# ============================================================================

DOWNLOADS_DIR="$HOME/Downloads"
DOCUMENTS_DIR="$HOME/Documents"
ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
ARCHIVE_DIR="$HOME/Documents/_Archive"
TRASH_DIR="$HOME/.Trash"

# Category folders (inside Documents)
IMAGES_DIR="$DOCUMENTS_DIR/Images"
PDFS_DIR="$DOCUMENTS_DIR/PDFs"
CODE_DIR="$DOCUMENTS_DIR/Code"
VIDEOS_DIR="$DOCUMENTS_DIR/Videos"
AUDIO_DIR="$DOCUMENTS_DIR/Audio"
INSTALLERS_DIR="$DOCUMENTS_DIR/Installers"

# Script configuration
LOG_FILE="$HOME/.downloads-organizer/organize.log"
STATE_FILE="$HOME/.downloads-organizer/processed.txt"
CONFIG_DIR="$HOME/.downloads-organizer"

# Flags
DRY_RUN=false
VERBOSE=false

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

verbose_log() {
    if [ "$VERBOSE" = true ]; then
        log "[VERBOSE] $1"
    fi
}

ensure_dirs() {
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$ARCHIVE_DIR"
    mkdir -p "$IMAGES_DIR"
    mkdir -p "$PDFS_DIR"
    mkdir -p "$CODE_DIR"
    mkdir -p "$VIDEOS_DIR"
    mkdir -p "$AUDIO_DIR"
    mkdir -p "$INSTALLERS_DIR"
    touch "$STATE_FILE"
    touch "$LOG_FILE"
}

is_processed() {
    local file_hash=$(echo "$1" | md5 -q 2>/dev/null || md5sum <<< "$1" | cut -d' ' -f1)
    grep -q "^$file_hash$" "$STATE_FILE" 2>/dev/null
}

mark_processed() {
    local file_hash=$(echo "$1" | md5 -q 2>/dev/null || md5sum <<< "$1" | cut -d' ' -f1)
    echo "$file_hash" >> "$STATE_FILE"
}

get_file_info() {
    local file="$1"
    local filename=$(basename "$file")
    local extension="${filename##*.}"
    local size=$(stat -f%z "$file" 2>/dev/null || stat --format=%s "$file" 2>/dev/null)
    local size_human=$(ls -lh "$file" | awk '{print $5}')
    local modified=$(stat -f "%Sm" -t "%Y-%m-%d" "$file" 2>/dev/null || date -r "$file" "+%Y-%m-%d" 2>/dev/null)
    local age_days=$(( ($(date +%s) - $(stat -f %m "$file" 2>/dev/null || stat --format=%Y "$file" 2>/dev/null)) / 86400 ))

    cat << EOF
File: $filename
Extension: $extension
Size: $size_human
Last modified: $modified
Age: $age_days days
EOF
}

# ============================================================================
# CLAUDE CODE ANALYSIS
# ============================================================================

analyze_with_claude() {
    local file="$1"
    local file_info="$2"

    # Prompt for Claude Code to analyze the file
    local prompt="You are a file organization assistant. Analyze this file and decide the best destination.

FILE FOR ANALYSIS:
$file_info

AVAILABLE DESTINATIONS:
1. ICLOUD - For important files that should have cloud backup (important documents, personal photos, work)
2. DOCUMENTS - For general documents you use frequently
3. IMAGES - For images, photos, screenshots
4. PDFS - For PDF documents
5. CODE - For code files, scripts, projects
6. VIDEOS - For videos
7. AUDIO - For music and audio files
8. INSTALLERS - For .dmg, .pkg, installers
9. ARCHIVE - For old files (more than 30 days) that can be archived
10. TRASH - For temporary files, duplicate downloads, obvious garbage (.tmp, .part, etc)
11. KEEP - Keep in Downloads (if it's recent and potentially in use)

RULES:
- Old .dmg and .pkg files (>7 days) usually go to TRASH or INSTALLERS
- Old screenshots may go to ARCHIVE or TRASH
- Important work/study documents go to ICLOUD
- Very recent files (<3 days) consider KEEP
- Project .zip/.tar files go to CODE
- .part, .crdownload, .tmp files always go to TRASH

RESPOND ONLY with a line in the format:
DECISION: [DESTINATION] | REASON: [brief explanation]

Example: DECISION: PDFS | REASON: PDF report document, useful for reference"

    # Call Claude Code CLI
    local response=$(echo "$prompt" | claude --print 2>/dev/null || echo "DECISION: KEEP | REASON: Error analyzing, keeping in Downloads")

    echo "$response"
}

# ============================================================================
# FILE MOVEMENT
# ============================================================================

move_file() {
    local file="$1"
    local destination="$2"
    local filename=$(basename "$file")
    local target_dir=""

    case "$destination" in
        "ICLOUD")
            target_dir="$ICLOUD_DIR"
            ;;
        "DOCUMENTS")
            target_dir="$DOCUMENTS_DIR"
            ;;
        "IMAGES")
            target_dir="$IMAGES_DIR"
            ;;
        "PDFS")
            target_dir="$PDFS_DIR"
            ;;
        "CODE")
            target_dir="$CODE_DIR"
            ;;
        "VIDEOS")
            target_dir="$VIDEOS_DIR"
            ;;
        "AUDIO")
            target_dir="$AUDIO_DIR"
            ;;
        "INSTALLERS")
            target_dir="$INSTALLERS_DIR"
            ;;
        "ARCHIVE")
            target_dir="$ARCHIVE_DIR"
            ;;
        "TRASH")
            target_dir="$TRASH_DIR"
            ;;
        "KEEP")
            log "  → Keeping in Downloads: $filename"
            return 0
            ;;
        *)
            log "  → Unknown destination '$destination', keeping in Downloads"
            return 0
            ;;
    esac

    # Check if destination exists
    if [ ! -d "$target_dir" ]; then
        log "  → Creating directory: $target_dir"
        mkdir -p "$target_dir"
    fi

    # Move file (or simulate in dry-run)
    local target_path="$target_dir/$filename"

    # If file with same name exists, add timestamp
    if [ -e "$target_path" ]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local name="${filename%.*}"
        local ext="${filename##*.}"
        if [ "$name" = "$ext" ]; then
            target_path="$target_dir/${filename}_${timestamp}"
        else
            target_path="$target_dir/${name}_${timestamp}.${ext}"
        fi
    fi

    if [ "$DRY_RUN" = true ]; then
        log "  → [DRY-RUN] Would move to: $target_path"
    else
        mv "$file" "$target_path"
        log "  → Moved to: $target_path"
    fi
}

# ============================================================================
# MAIN PROCESSING
# ============================================================================

process_downloads() {
    log "=========================================="
    log "Starting Downloads organization"
    log "=========================================="

    if [ "$DRY_RUN" = true ]; then
        log "[DRY-RUN MODE ACTIVE - No files will be moved]"
    fi

    # Check if Claude Code is installed
    if ! command -v claude &> /dev/null; then
        log "ERROR: Claude Code CLI not found!"
        log "Install with: npm install -g @anthropic-ai/claude-code"
        exit 1
    fi

    # Count files
    local file_count=$(find "$DOWNLOADS_DIR" -maxdepth 1 -type f | wc -l | tr -d ' ')
    log "Found $file_count files in Downloads"

    if [ "$file_count" -eq 0 ]; then
        log "No files to process. Finishing."
        return 0
    fi

    local processed=0
    local skipped=0
    local errors=0

    # Process each file
    find "$DOWNLOADS_DIR" -maxdepth 1 -type f | while read -r file; do
        local filename=$(basename "$file")

        # Ignore hidden files
        if [[ "$filename" == .* ]]; then
            verbose_log "Ignoring hidden file: $filename"
            continue
        fi

        # Ignore files being downloaded (.part, .crdownload, .download)
        if [[ "$filename" == *.part ]] || [[ "$filename" == *.crdownload ]] || [[ "$filename" == *.download ]]; then
            verbose_log "Ignoring download in progress: $filename"
            continue
        fi

        # Check if already processed
        if is_processed "$file"; then
            verbose_log "File already processed: $filename"
            ((skipped++)) || true
            continue
        fi

        log ""
        log "Analyzing: $filename"

        # Get file information
        local file_info=$(get_file_info "$file")
        verbose_log "$file_info"

        # Analyze with Claude Code
        log "  Consulting AI..."
        local analysis=$(analyze_with_claude "$file" "$file_info")

        # Extract decision and reason
        local decision=$(echo "$analysis" | grep -o 'DECISION: [A-Z]*' | cut -d' ' -f2 || echo "KEEP")
        local reason=$(echo "$analysis" | grep -o 'REASON: .*' | cut -d':' -f2- || echo "No reason specified")

        log "  Decision: $decision"
        log "  Reason:$reason"

        # Move file
        move_file "$file" "$decision"

        # Mark as processed
        if [ "$DRY_RUN" = false ]; then
            mark_processed "$file"
        fi

        ((processed++)) || true
    done

    log ""
    log "=========================================="
    log "Organization complete!"
    log "Processed: $processed | Skipped: $skipped | Errors: $errors"
    log "=========================================="
}

# ============================================================================
# MAIN
# ============================================================================

# Process arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Smart Downloads Organizer - Powered by Claude Code"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --dry-run    Simulate execution without moving files"
            echo "  --verbose    Show detailed information"
            echo "  --help       Show this help"
            echo ""
            echo "Configuration:"
            echo "  Edit variables at the top of the script to adjust paths."
            echo "  Logs are saved in: $LOG_FILE"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help to see available options"
            exit 1
            ;;
    esac
done

# Ensure directories exist
ensure_dirs

# Execute processing
process_downloads
