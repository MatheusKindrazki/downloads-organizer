#!/bin/bash
#
# Downloads Organizer - Powered by Claude Code
# Analisa arquivos na pasta Downloads e usa IA para decidir o destino
#
# Uso: ./organize-downloads.sh [--dry-run] [--verbose]
#

set -euo pipefail

# ============================================================================
# CONFIGURAÇÃO - Ajuste esses caminhos conforme sua necessidade
# ============================================================================

DOWNLOADS_DIR="$HOME/Downloads"
DOCUMENTS_DIR="$HOME/Documents"
ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
ARCHIVE_DIR="$HOME/Documents/_Arquivo"
TRASH_DIR="$HOME/.Trash"

# Pastas por categoria (dentro de Documents)
IMAGES_DIR="$DOCUMENTS_DIR/Imagens"
PDFS_DIR="$DOCUMENTS_DIR/PDFs"
CODE_DIR="$DOCUMENTS_DIR/Código"
VIDEOS_DIR="$DOCUMENTS_DIR/Vídeos"
AUDIO_DIR="$DOCUMENTS_DIR/Áudio"
INSTALLERS_DIR="$DOCUMENTS_DIR/Instaladores"

# Configuração do script
LOG_FILE="$HOME/.downloads-organizer/organize.log"
STATE_FILE="$HOME/.downloads-organizer/processed.txt"
CONFIG_DIR="$HOME/.downloads-organizer"

# Flags
DRY_RUN=false
VERBOSE=false

# ============================================================================
# FUNÇÕES AUXILIARES
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
Arquivo: $filename
Extensão: $extension
Tamanho: $size_human
Última modificação: $modified
Idade: $age_days dias
EOF
}

# ============================================================================
# ANÁLISE COM CLAUDE CODE
# ============================================================================

analyze_with_claude() {
    local file="$1"
    local file_info="$2"

    # Prompt para o Claude Code analisar o arquivo
    local prompt="Você é um assistente de organização de arquivos. Analise este arquivo e decida o melhor destino.

ARQUIVO PARA ANÁLISE:
$file_info

DESTINOS DISPONÍVEIS:
1. ICLOUD - Para arquivos importantes que devem ter backup na nuvem (documentos importantes, fotos pessoais, trabalhos)
2. DOCUMENTS - Para documentos gerais que você usa frequentemente
3. IMAGES - Para imagens, fotos, screenshots
4. PDFS - Para documentos PDF
5. CODE - Para arquivos de código, scripts, projetos
6. VIDEOS - Para vídeos
7. AUDIO - Para músicas e áudios
8. INSTALLERS - Para .dmg, .pkg, instaladores
9. ARCHIVE - Para arquivos antigos (mais de 30 dias) que podem ser arquivados
10. TRASH - Para arquivos temporários, downloads duplicados, lixo óbvio (.tmp, .part, etc)
11. KEEP - Manter no Downloads (se for algo recente e potencialmente em uso)

REGRAS:
- Arquivos .dmg e .pkg antigos (>7 dias) geralmente vão para TRASH ou INSTALLERS
- Screenshots antigos podem ir para ARCHIVE ou TRASH
- Documentos de trabalho/estudo importantes vão para ICLOUD
- Arquivos muito recentes (<3 dias) considere KEEP
- Arquivos .zip/.tar de projetos vão para CODE
- Arquivos .part, .crdownload, .tmp sempre vão para TRASH

RESPONDA APENAS com uma linha no formato:
DECISÃO: [DESTINO] | MOTIVO: [breve explicação]

Exemplo: DECISÃO: PDFS | MOTIVO: Documento PDF de relatório, útil para referência"

    # Chama o Claude Code CLI
    local response=$(echo "$prompt" | claude --print 2>/dev/null || echo "DECISÃO: KEEP | MOTIVO: Erro ao analisar, mantendo no Downloads")

    echo "$response"
}

# ============================================================================
# MOVIMENTAÇÃO DE ARQUIVOS
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
            log "  → Mantendo em Downloads: $filename"
            return 0
            ;;
        *)
            log "  → Destino desconhecido '$destination', mantendo em Downloads"
            return 0
            ;;
    esac

    # Verifica se o destino existe
    if [ ! -d "$target_dir" ]; then
        log "  → Criando diretório: $target_dir"
        mkdir -p "$target_dir"
    fi

    # Move o arquivo (ou simula no dry-run)
    local target_path="$target_dir/$filename"

    # Se já existe um arquivo com mesmo nome, adiciona timestamp
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
        log "  → [DRY-RUN] Moveria para: $target_path"
    else
        mv "$file" "$target_path"
        log "  → Movido para: $target_path"
    fi
}

# ============================================================================
# PROCESSAMENTO PRINCIPAL
# ============================================================================

process_downloads() {
    log "=========================================="
    log "Iniciando organização de Downloads"
    log "=========================================="

    if [ "$DRY_RUN" = true ]; then
        log "[MODO DRY-RUN ATIVADO - Nenhum arquivo será movido]"
    fi

    # Verifica se o Claude Code está instalado
    if ! command -v claude &> /dev/null; then
        log "ERRO: Claude Code CLI não encontrado!"
        log "Instale com: npm install -g @anthropic-ai/claude-code"
        exit 1
    fi

    # Conta arquivos
    local file_count=$(find "$DOWNLOADS_DIR" -maxdepth 1 -type f | wc -l | tr -d ' ')
    log "Encontrados $file_count arquivos em Downloads"

    if [ "$file_count" -eq 0 ]; then
        log "Nenhum arquivo para processar. Finalizando."
        return 0
    fi

    local processed=0
    local skipped=0
    local errors=0

    # Processa cada arquivo
    find "$DOWNLOADS_DIR" -maxdepth 1 -type f | while read -r file; do
        local filename=$(basename "$file")

        # Ignora arquivos ocultos
        if [[ "$filename" == .* ]]; then
            verbose_log "Ignorando arquivo oculto: $filename"
            continue
        fi

        # Ignora arquivos em download (.part, .crdownload, .download)
        if [[ "$filename" == *.part ]] || [[ "$filename" == *.crdownload ]] || [[ "$filename" == *.download ]]; then
            verbose_log "Ignorando download em andamento: $filename"
            continue
        fi

        # Verifica se já foi processado
        if is_processed "$file"; then
            verbose_log "Arquivo já processado anteriormente: $filename"
            ((skipped++)) || true
            continue
        fi

        log ""
        log "Analisando: $filename"

        # Obtém informações do arquivo
        local file_info=$(get_file_info "$file")
        verbose_log "$file_info"

        # Analisa com Claude Code
        log "  Consultando IA..."
        local analysis=$(analyze_with_claude "$file" "$file_info")

        # Extrai decisão e motivo
        local decision=$(echo "$analysis" | grep -o 'DECISÃO: [A-Z]*' | cut -d' ' -f2 || echo "KEEP")
        local reason=$(echo "$analysis" | grep -o 'MOTIVO: .*' | cut -d':' -f2- || echo "Sem motivo especificado")

        log "  Decisão: $decision"
        log "  Motivo:$reason"

        # Move o arquivo
        move_file "$file" "$decision"

        # Marca como processado
        if [ "$DRY_RUN" = false ]; then
            mark_processed "$file"
        fi

        ((processed++)) || true
    done

    log ""
    log "=========================================="
    log "Organização concluída!"
    log "Processados: $processed | Ignorados: $skipped | Erros: $errors"
    log "=========================================="
}

# ============================================================================
# MAIN
# ============================================================================

# Processa argumentos
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
            echo "Downloads Organizer - Powered by Claude Code"
            echo ""
            echo "Uso: $0 [opções]"
            echo ""
            echo "Opções:"
            echo "  --dry-run    Simula a execução sem mover arquivos"
            echo "  --verbose    Mostra informações detalhadas"
            echo "  --help       Mostra esta ajuda"
            echo ""
            echo "Configuração:"
            echo "  Edite as variáveis no início do script para ajustar os caminhos."
            echo "  Logs são salvos em: $LOG_FILE"
            exit 0
            ;;
        *)
            echo "Opção desconhecida: $1"
            echo "Use --help para ver as opções disponíveis"
            exit 1
            ;;
    esac
done

# Garante que os diretórios existem
ensure_dirs

# Executa o processamento
process_downloads
