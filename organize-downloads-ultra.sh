#!/bin/bash
#
# Smart Downloads Organizer - Ultra-Fast Version with jq
# Analyzes ALL files in a single Claude API call
# FASTEST: Uses jq for robust JSON parsing
#
# Usage: ./organize-downloads-ultra.sh [--dry-run] [--verbose]
#

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

DOWNLOADS_DIR="$HOME/Downloads"
DOCUMENTS_DIR="$HOME/Documents"
ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
ARCHIVE_DIR="$HOME/Documents/_Archive"
TRASH_DIR="$HOME/.Trash"

# Category folders
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
    mkdir -p "$CONFIG_DIR" "$TEMP_DIR" "$ARCHIVE_DIR" "$IMAGES_DIR" "$PDFS_DIR" \
             "$CODE_DIR" "$VIDEOS_DIR" "$AUDIO_DIR" "$INSTALLERS_DIR"
    touch "$STATE_FILE" "$LOG_FILE"
}

is_processed() {
    local file_hash=$(echo "$1" | md5 -q 2>/dev/null || md5sum <<< "$1" | cut -d' ' -f1)
    grep -q "^$file_hash$" "$STATE_FILE" 2>/dev/null
}

mark_processed() {
    local file_hash=$(echo "$1" | md5 -q 2>/dev/null || md5sum <<< "$1" | cut -d' ' -f1)
    echo "$file_hash" >> "$STATE_FILE"
}

# ============================================================================
# FILE ANALYSIS
# ============================================================================

collect_files_info() {
    local files_json="["
    local first=true
    local count=0

    while IFS= read -r file; do
        local filename=$(basename "$file")

        # Skip hidden files and downloads in progress
        [[ "$filename" == .* ]] && continue
        [[ "$filename" == *.part || "$filename" == *.crdownload || "$filename" == *.download ]] && continue

        # Skip already processed
        is_processed "$file" && continue

        # Get file metadata
        local extension="${filename##*.}"
        local size=$(stat -f%z "$file" 2>/dev/null || stat --format=%s "$file" 2>/dev/null)
        local size_human=$(ls -lh "$file" | awk '{print $5}')
        local age_days=$(( ($(date +%s) - $(stat -f %m "$file" 2>/dev/null || stat --format=%Y "$file" 2>/dev/null)) / 86400 ))

        # Escape filename for JSON
        local safe_filename=$(echo "$filename" | sed 's/"/\\"/g')

        if [ "$first" = true ]; then
            first=false
        else
            files_json+=","
        fi

        files_json+=$(cat <<EOF
{"filename":"$safe_filename","extension":"$extension","size":"$size_human","age":$age_days}
EOF
)
        ((count++))
    done < <(find "$DOWNLOADS_DIR" -maxdepth 1 -type f)

    files_json+="]"

    echo "$files_json"
    return $count
}

analyze_all_with_claude() {
    local files_json="$1"
    local temp_response="$TEMP_DIR/claude_response.txt"

    # Build comprehensive prompt
    read -r -d '' PROMPT <<'PROMPT_END' || true
You are an expert file organization assistant. Analyze these files and decide the best destination for each.

FILES TO ANALYZE:
%FILES_JSON%

DESTINATIONS:
- ICLOUD: Critical files needing cloud backup (tax documents, contracts, personal photos, important work)
- DOCUMENTS: Frequently-used general documents
- IMAGES: Photos, screenshots, graphics, design files
- PDFS: PDF documents and ebooks
- CODE: Source code, scripts, projects, development archives
- VIDEOS: Video files and recordings
- AUDIO: Music, podcasts, audio files
- INSTALLERS: Application installers (.dmg, .pkg)
- ARCHIVE: Old files (>30 days) rarely accessed
- TRASH: Temporary files, old installers (>7 days), obvious garbage
- KEEP: Very recent files (<3 days) potentially in active use

DECISION LOGIC:
1. File age matters: Recent (<3 days) = KEEP, Old (>30 days) = ARCHIVE/TRASH
2. Old installers (>7 days) = TRASH
3. Screenshots >30 days = ARCHIVE
4. Work/important docs = ICLOUD
5. Temp files (.tmp, .part, .crdownload) = TRASH
6. Code archives (.tar.gz, .zip with "src"/"project") = CODE

OUTPUT: Return ONLY a valid JSON array, one object per file:
[
  {"filename": "exact-name.pdf", "destination": "PDFS", "reason": "Brief explanation"},
  {"filename": "old-app.dmg", "destination": "TRASH", "reason": "Old installer"}
]

CRITICAL:
- Use EXACT filenames from input
- Return ONLY the JSON array
- No markdown, no explanations, just JSON
PROMPT_END

    # Replace placeholder with actual files JSON
    PROMPT="${PROMPT//%FILES_JSON%/$files_json}"

    # Call Claude and capture response
    echo "$PROMPT" | claude --print 2>/dev/null > "$temp_response" || {
        log "ERROR: Claude API call failed"
        echo "[]"
        return 1
    }

    # Extract JSON array (Claude might add markdown)
    local json_array=$(cat "$temp_response" | sed -n '/^\[/,/^\]/p' | tr -d '\n')

    # Validate JSON
    if ! echo "$json_array" | jq empty 2>/dev/null; then
        log "ERROR: Invalid JSON from Claude"
        verbose_log "Response was: $(cat "$temp_response")"
        echo "[]"
        return 1
    fi

    echo "$json_array"
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
        ICLOUD) target_dir="$ICLOUD_DIR" ;;
        DOCUMENTS) target_dir="$DOCUMENTS_DIR" ;;
        IMAGES) target_dir="$IMAGES_DIR" ;;
        PDFS) target_dir="$PDFS_DIR" ;;
        CODE) target_dir="$CODE_DIR" ;;
        VIDEOS) target_dir="$VIDEOS_DIR" ;;
        AUDIO) target_dir="$AUDIO_DIR" ;;
        INSTALLERS) target_dir="$INSTALLERS_DIR" ;;
        ARCHIVE) target_dir="$ARCHIVE_DIR" ;;
        TRASH) target_dir="$TRASH_DIR" ;;
        KEEP)
            verbose_log "  ⏸️  Keeping: $filename"
            return 0
            ;;
        *)
            log "  ⚠️  Unknown destination '$destination' for $filename, keeping"
            return 0
            ;;
    esac

    mkdir -p "$target_dir"

    # Handle filename conflicts
    local target_path="$target_dir/$filename"
    if [ -e "$target_path" ]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local name="${filename%.*}"
        local ext="${filename##*.}"
        [ "$name" = "$ext" ] && target_path="$target_dir/${filename}_${timestamp}" || \
                                 target_path="$target_dir/${name}_${timestamp}.${ext}"
    fi

    if [ "$DRY_RUN" = true ]; then
        log "  🔷 [DRY-RUN] $filename → $destination"
    else
        mv "$file" "$target_path" && verbose_log "  ✅ $filename → $destination"
    fi
}

# ============================================================================
# MAIN PROCESSING
# ============================================================================

process_downloads() {
    log "=========================================="
    log "Smart Downloads Organizer - ULTRA MODE"
    log "=========================================="

    [ "$DRY_RUN" = true ] && log "[DRY-RUN MODE - No files will be moved]"

    # Check dependencies
    if ! command -v claude &>/dev/null; then
        log "ERROR: Claude Code CLI not found!"
        log "Install: npm install -g @anthropic-ai/claude-code"
        exit 1
    fi

    if ! command -v jq &>/dev/null; then
        log "ERROR: jq not found!"
        log "Install: brew install jq"
        exit 1
    fi

    # Collect files
    log "📂 Scanning Downloads folder..."
    local files_json=$(collect_files_info)
    local file_count=$?

    if [ "$file_count" -eq 0 ]; then
        log "✨ No files to process"
        return 0
    fi

    log "📊 Found $file_count files to analyze"
    log "🤖 Sending to Claude for batch analysis..."

    # Analyze all files in one call
    local decisions=$(analyze_all_with_claude "$files_json")

    if [ "$decisions" = "[]" ]; then
        log "❌ No valid decisions received"
        return 1
    fi

    local decision_count=$(echo "$decisions" | jq 'length')
    log "✅ Received $decision_count decisions"
    log ""

    # Process each decision using jq
    local processed=0

    echo "$decisions" | jq -c '.[]' | while read -r decision; do
        local filename=$(echo "$decision" | jq -r '.filename')
        local destination=$(echo "$decision" | jq -r '.destination')
        local reason=$(echo "$decision" | jq -r '.reason')

        # Find the actual file
        local file="$DOWNLOADS_DIR/$filename"

        if [ ! -f "$file" ]; then
            log "  ⚠️  File not found: $filename"
            continue
        fi

        log "  📄 $filename"
        log "     → $destination: $reason"

        move_file "$file" "$destination"

        [ "$DRY_RUN" = false ] && mark_processed "$file"

        ((processed++))
    done

    log ""
    log "=========================================="
    log "✨ Complete! Processed $processed files"
    log "=========================================="
}

# ============================================================================
# MAIN
# ============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --verbose|-v) VERBOSE=true; shift ;;
        --help|-h)
            cat <<EOF
Smart Downloads Organizer - ULTRA FAST MODE

Analyzes ALL files in a single Claude API call using JSON.
Up to 10-50x faster than sequential processing!

Usage: $0 [options]

Options:
  --dry-run    Simulate without moving files
  --verbose    Show detailed output
  --help       Show this help

Requirements:
  - Claude Code CLI: npm install -g @anthropic-ai/claude-code
  - jq: brew install jq
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

ensure_dirs
process_downloads
rm -rf "$TEMP_DIR"
