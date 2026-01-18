#!/bin/bash
#
# Downloads Organizer - Script de Desinstalação
#

set -e

CONFIG_DIR="$HOME/.downloads-organizer"
PLIST_FILE="$HOME/Library/LaunchAgents/com.user.downloads-organizer.plist"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       Downloads Organizer - Desinstalação                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

read -p "⚠️  Tem certeza que deseja desinstalar? [s/N] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "Cancelado."
    exit 0
fi

echo ""
echo "🗑️  Removendo LaunchAgent..."
launchctl unload "$PLIST_FILE" 2>/dev/null || true
rm -f "$PLIST_FILE"

echo "🗑️  Removendo arquivos de configuração..."
rm -rf "$CONFIG_DIR"

echo "🗑️  Removendo aliases do shell..."
for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
    if [ -f "$rc" ]; then
        # Remove as linhas relacionadas ao Downloads Organizer
        sed -i '' '/# Downloads Organizer/d' "$rc" 2>/dev/null || true
        sed -i '' '/alias organize-downloads/d' "$rc" 2>/dev/null || true
    fi
done

echo ""
echo "✅ Downloads Organizer desinstalado com sucesso!"
echo ""
echo "Nota: Os diretórios de destino (Imagens, PDFs, etc.) NÃO foram removidos."
echo "      Os arquivos que foram organizados permanecem em seus novos locais."
