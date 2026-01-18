#!/bin/bash
#
# Smart Downloads Organizer - Fast Batch Version
# Analyzes files in Downloads folder and uses AI to decide destination
# OPTIMIZED: Processes all files in a single Claude API call
#
# Usage: ./organize-downloads-fast.sh [--dry-run] [--verbose]
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
TEMP_DIR="$HOME/.downloads-organizer/temp"

# Flags
DRY_RUN=false
VERBOSE=false
BATCH_SIZE=50  # Process up to 50 files per batch

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
    mkdir -p "$TEMP_DIR"
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

    # Return JSON format for easier parsing
    cat << EOF
{"filename": "$filename", "extension": "$extension", "size": "$size_human", "age_days": $age_days, "modified": "$modified"}
EOF
}

# ============================================================================
# BATCH CLAUDE CODE ANALYSIS
# ============================================================================

analyze_batch_with_claude() {
    local files_json="$1"
    local temp_file="$TEMP_DIR/batch_analysis.json"

    # Create prompt for batch analysis
    local prompt="You are a file organization assistant. Analyze these files and decide the best destination for each.

FILES TO ANALYZE:
$files_json

AVAILABLE DESTINATIONS:
- ICLOUD: Important files needing cloud backup (documents, personal photos, work files)
- DOCUMENTS: General frequently-used documents
- IMAGES: Photos, screenshots, graphics
- PDFS: PDF documents
- CODE: Code files, scripts, projects, archives with code
- VIDEOS: Video files
- AUDIO: Music and audio files
- INSTALLERS: .dmg, .pkg, app installers
- ARCHIVE: Old files (>30 days) for archiving
- TRASH: Temporary files, duplicates, garbage (.tmp, .part, etc)
- KEEP: Recent files potentially in use (<3 days)

RULES:
- Old .dmg/.pkg (>7 days) → TRASH or INSTALLERS
- Old screenshots (>30 days) → ARCHIVE or TRASH
- Important work/study documents → ICLOUD
- Very recent files (<3 days) → Consider KEEP
- Project .zip/.tar files → CODE
- .part, .crdownload, .tmp → Always TRASH

RESPOND ONLY with valid JSON array in this EXACT format:
[
  {\"filename\": \"example.pdf\", \"destination\": \"PDFS\", \"reason\": \"PDF document for reference\"},
  {\"filename\": \"old-installer.dmg\", \"destination\": \"TRASH\", \"reason\": \"Old installer, already used\"}
]

IMPORTANT: Return ONLY the JSON array, no other text."

    # Call Claude Code CLI and save to temp file
    echo "$prompt" | claude --print 2>/dev/null > "$temp_file" || {
        log "ERROR: Failed to analyze batch with Claude"
        echo "[]"
        return 1
    }

    # Extract just the JSON array (in case Claude adds extra text)
    # Look for content between [ and ]
    local json_content=$(cat "$temp_file" | grep -o '\[.*\]' | head -1)

    if [ -z "$json_content" ]; then
        log "ERROR: Invalid JSON response from Claude"
        echo "[]"
        return 1
    fi

    echo "$json_content"
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
            verbose_log "  → Keeping in Downloads: $filename"
            return 0
            ;;
        *)
            log "  → Unknown destination '$destination', keeping in Downloads"
            return 0
            ;;
    esac

    # Check if destination exists
    if [ ! -d "$target_dir" ]; then
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
        verbose_log "  → Moved to: $target_path"
    fi
}

# ============================================================================
# MAIN PROCESSING - BATCH VERSION
# ============================================================================

process_downloads() {
    log "=========================================="
    log "Starting Downloads organization (FAST BATCH MODE)"
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

    # Collect all files to process
    local files_to_process=()
    local file_paths=()

    log "Scanning Downloads folder..."

    while IFS= read -r file; do
        local filename=$(basename "$file")

        # Skip hidden files
        [[ "$filename" == .* ]] && continue

        # Skip files being downloaded
        [[ "$filename" == *.part ]] || [[ "$filename" == *.crdownload ]] || [[ "$filename" == *.download ]] && continue

        # Skip already processed
        is_processed "$file" && continue

        files_to_process+=("$file")
    done < <(find "$DOWNLOADS_DIR" -maxdepth 1 -type f)

    local total_files=${#files_to_process[@]}

    if [ "$total_files" -eq 0 ]; then
        log "No files to process. Finishing."
        return 0
    fi

    log "Found $total_files files to analyze"
    log ""

    # Process in batches
    local processed=0
    local batch_num=0

    for ((i=0; i<$total_files; i+=$BATCH_SIZE)); do
        ((batch_num++))
        local batch_end=$((i + BATCH_SIZE))
        [ $batch_end -gt $total_files ] && batch_end=$total_files

        local batch_size=$((batch_end - i))
        log "Processing batch $batch_num ($batch_size files)..."

        # Build JSON array of file info
        local files_json="["
        local first=true

        for ((j=i; j<batch_end; j++)); do
            local file="${files_to_process[$j]}"
            local file_info=$(get_file_info "$file")

            if [ "$first" = true ]; then
                first=false
            else
                files_json+=","
            fi
            files_json+="$file_info"
        done
        files_json+="]"

        verbose_log "Sending batch to Claude..."

        # Analyze entire batch with Claude
        local decisions=$(analyze_batch_with_claude "$files_json")

        if [ "$decisions" = "[]" ]; then
            log "WARNING: No decisions received for batch $batch_num, skipping"
            continue
        fi

        # Process each decision
        # Extract decisions using basic JSON parsing (works for simple cases)
        local decision_count=0

        for ((j=i; j<batch_end; j++)); do
            local file="${files_to_process[$j]}"
            local filename=$(basename "$file")

            # Extract decision for this file from JSON
            # This is a simple approach - for production, consider using jq
            local file_decision=$(echo "$decisions" | grep -o "\"filename\": *\"$filename\"[^}]*}" | head -1)

            if [ -z "$file_decision" ]; then
                log "  ⚠️  No decision for: $filename (keeping in Downloads)"
                continue
            fi

            local destination=$(echo "$file_decision" | grep -o '"destination": *"[^"]*"' | cut -d'"' -f4)
            local reason=$(echo "$file_decision" | grep -o '"reason": *"[^"]*"' | cut -d'"' -f4)

            log "  📄 $filename"
            log "     → $destination: $reason"

            move_file "$file" "$destination"

            # Mark as processed
            if [ "$DRY_RUN" = false ]; then
                mark_processed "$file"
            fi

            ((processed++))
            ((decision_count++))
        done

        log "  ✓ Batch $batch_num complete ($decision_count files processed)"
        log ""
    done

    log "=========================================="
    log "Organization complete!"
    log "Total processed: $processed files"
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
        --batch-size)
            BATCH_SIZE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Smart Downloads Organizer (Fast Batch Mode) - Powered by Claude Code"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --dry-run           Simulate execution without moving files"
            echo "  --verbose           Show detailed information"
            echo "  --batch-size N      Process N files per batch (default: 50)"
            echo "  --help              Show this help"
            echo ""
            echo "This version processes multiple files in a single Claude API call,"
            echo "making it MUCH faster than the standard version."
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

# Cleanup temp files
rm -rf "$TEMP_DIR"
