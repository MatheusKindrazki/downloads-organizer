#!/bin/bash
#
# Downloads Organizer - Script de Instalação
# Configura o agendamento automático no macOS
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.downloads-organizer"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       Downloads Organizer - Instalação                       ║"
echo "║       Powered by Claude Code                                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Verifica se é macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "❌ Este script é apenas para macOS."
    echo "   Para Linux, use cron manualmente."
    exit 1
fi

# Verifica se Claude Code está instalado
echo "🔍 Verificando dependências..."

if ! command -v claude &> /dev/null; then
    echo ""
    echo "⚠️  Claude Code CLI não encontrado!"
    echo ""
    echo "Instale o Claude Code primeiro:"
    echo "  npm install -g @anthropic-ai/claude-code"
    echo ""
    echo "Após instalar, execute este script novamente."
    exit 1
fi

echo "✅ Claude Code CLI encontrado: $(which claude)"

# Cria diretório de configuração
echo ""
echo "📁 Criando diretório de configuração..."
mkdir -p "$CONFIG_DIR"
mkdir -p "$LAUNCH_AGENTS_DIR"

# Copia o script principal
echo "📋 Copiando scripts..."
cp "$SCRIPT_DIR/organize-downloads.sh" "$CONFIG_DIR/"
chmod +x "$CONFIG_DIR/organize-downloads.sh"

# Copia configuração se não existir
if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
    cp "$SCRIPT_DIR/config.yaml" "$CONFIG_DIR/"
    echo "✅ Arquivo de configuração criado em: $CONFIG_DIR/config.yaml"
else
    echo "ℹ️  Arquivo de configuração já existe, mantendo o atual"
fi

# Processa o plist substituindo $HOME
echo ""
echo "⏰ Configurando agendamento para todo Domingo às 10:00..."

PLIST_FILE="$LAUNCH_AGENTS_DIR/com.user.downloads-organizer.plist"

# Substitui $HOME pelo caminho real
sed "s|\$HOME|$HOME|g" "$SCRIPT_DIR/com.user.downloads-organizer.plist" > "$PLIST_FILE"

# Descarrega se já estiver carregado
launchctl unload "$PLIST_FILE" 2>/dev/null || true

# Carrega o novo LaunchAgent
launchctl load "$PLIST_FILE"

echo "✅ LaunchAgent instalado e carregado"

# Cria diretórios de destino
echo ""
echo "📂 Criando diretórios de destino..."

mkdir -p "$HOME/Documents/Imagens"
mkdir -p "$HOME/Documents/PDFs"
mkdir -p "$HOME/Documents/Código"
mkdir -p "$HOME/Documents/Vídeos"
mkdir -p "$HOME/Documents/Áudio"
mkdir -p "$HOME/Documents/Instaladores"
mkdir -p "$HOME/Documents/_Arquivo"

echo "✅ Diretórios criados"

# Cria alias para fácil acesso
echo ""
echo "🔗 Criando atalhos..."

# Detecta qual shell está sendo usado
SHELL_RC=""
if [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
elif [ -f "$HOME/.bash_profile" ]; then
    SHELL_RC="$HOME/.bash_profile"
fi

if [ -n "$SHELL_RC" ]; then
    # Verifica se o alias já existe
    if ! grep -q "alias organize-downloads" "$SHELL_RC" 2>/dev/null; then
        echo "" >> "$SHELL_RC"
        echo "# Downloads Organizer" >> "$SHELL_RC"
        echo "alias organize-downloads='$CONFIG_DIR/organize-downloads.sh'" >> "$SHELL_RC"
        echo "alias organize-downloads-dry='$CONFIG_DIR/organize-downloads.sh --dry-run --verbose'" >> "$SHELL_RC"
        echo "✅ Aliases adicionados ao $SHELL_RC"
        echo "   Execute 'source $SHELL_RC' ou abra um novo terminal para usar"
    else
        echo "ℹ️  Aliases já existem"
    fi
fi

# Resumo
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ Instalação Concluída!                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📍 Localização dos arquivos:"
echo "   Script:    $CONFIG_DIR/organize-downloads.sh"
echo "   Config:    $CONFIG_DIR/config.yaml"
echo "   Logs:      $CONFIG_DIR/organize.log"
echo "   LaunchAgent: $PLIST_FILE"
echo ""
echo "📅 Agendamento:"
echo "   O script será executado automaticamente todo DOMINGO às 10:00"
echo ""
echo "🚀 Comandos úteis:"
echo "   organize-downloads          # Executar agora"
echo "   organize-downloads-dry      # Testar sem mover arquivos"
echo ""
echo "🔧 Para modificar o horário:"
echo "   1. Edite: $PLIST_FILE"
echo "   2. Mude Weekday (0=Dom, 1=Seg...) e Hour (0-23)"
echo "   3. Execute: launchctl unload $PLIST_FILE"
echo "   4. Execute: launchctl load $PLIST_FILE"
echo ""
echo "❓ Para desinstalar:"
echo "   launchctl unload $PLIST_FILE"
echo "   rm -rf $CONFIG_DIR"
echo "   rm $PLIST_FILE"
echo ""

# Pergunta se quer executar um teste
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -p "🧪 Deseja executar um teste agora (dry-run)? [s/N] " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo ""
    echo "Executando teste..."
    echo ""
    "$CONFIG_DIR/organize-downloads.sh" --dry-run --verbose
fi
