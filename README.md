# 📁 Downloads Organizer

Sistema automatizado de organização de Downloads usando **Claude Code CLI** para análise inteligente de arquivos.

## 🎯 O que faz?

Todo domingo às 10h, o script analisa cada arquivo na sua pasta Downloads e usa IA para decidir o melhor destino:

| Destino | Descrição |
|---------|-----------|
| **iCloud** | Arquivos importantes (backup na nuvem) |
| **Documentos** | Docs gerais de uso frequente |
| **Imagens** | Fotos, screenshots, gráficos |
| **PDFs** | Documentos PDF |
| **Código** | Scripts, projetos, arquivos de código |
| **Vídeos** | Arquivos de vídeo |
| **Áudio** | Músicas e arquivos de áudio |
| **Instaladores** | .dmg, .pkg, apps |
| **Arquivo** | Arquivos antigos para arquivamento |
| **Lixeira** | Arquivos temporários, lixo |

## 🚀 Instalação Rápida

```bash
# 1. Certifique-se de ter o Claude Code instalado
npm install -g @anthropic-ai/claude-code

# 2. Execute o instalador
cd downloads-organizer
chmod +x install.sh
./install.sh
```

## 📋 Pré-requisitos

- macOS (usa LaunchAgent para agendamento)
- Claude Code CLI instalado e autenticado
- Node.js (para o Claude Code)

## 🔧 Uso Manual

```bash
# Executar agora
organize-downloads

# Testar sem mover arquivos (dry-run)
organize-downloads-dry

# Ou diretamente
~/.downloads-organizer/organize-downloads.sh --dry-run --verbose
```

## ⚙️ Configuração

Edite `~/.downloads-organizer/config.yaml` para personalizar:

```yaml
# Alterar diretórios de destino
directories:
  icloud: ~/Library/Mobile Documents/com~apple~CloudDocs/Organizados

# Adicionar regras automáticas
auto_rules:
  trash:
    extensions: [".tmp", ".log"]

# Excluir arquivos específicos
exclusions:
  files:
    - "arquivo-importante.pdf"
```

## 📅 Alterar Horário do Agendamento

Edite `~/Library/LaunchAgents/com.user.downloads-organizer.plist`:

```xml
<key>StartCalendarInterval</key>
<dict>
    <key>Weekday</key>
    <integer>0</integer>  <!-- 0=Dom, 1=Seg, ..., 6=Sáb -->
    <key>Hour</key>
    <integer>10</integer> <!-- Hora (0-23) -->
    <key>Minute</key>
    <integer>0</integer>  <!-- Minuto (0-59) -->
</dict>
```

Depois recarregue:

```bash
launchctl unload ~/Library/LaunchAgents/com.user.downloads-organizer.plist
launchctl load ~/Library/LaunchAgents/com.user.downloads-organizer.plist
```

### Exemplos de Horários

```xml
<!-- Todo dia às 9:00 -->
<key>StartCalendarInterval</key>
<dict>
    <key>Hour</key>
    <integer>9</integer>
    <key>Minute</key>
    <integer>0</integer>
</dict>

<!-- Segunda e Sexta às 18:00 -->
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
# Ver logs de execução
tail -f ~/.downloads-organizer/organize.log

# Ver logs do LaunchAgent
tail -f ~/.downloads-organizer/launchd.log
```

## 🔍 Como a IA Decide?

O Claude Code analisa cada arquivo considerando:

1. **Nome do arquivo** - Indica o propósito
2. **Extensão** - Tipo de arquivo
3. **Tamanho** - Arquivos grandes podem ser mais importantes
4. **Idade** - Arquivos antigos podem ser arquivados
5. **Contexto** - Screenshots, instaladores, etc.

Exemplo de análise:

```
Arquivo: Relatorio-Q4-2025.pdf
Extensão: pdf
Tamanho: 2.3MB
Idade: 5 dias

DECISÃO: ICLOUD | MOTIVO: Relatório financeiro importante, deve ter backup
```

## 🗑️ Desinstalar

```bash
./uninstall.sh
```

Ou manualmente:

```bash
launchctl unload ~/Library/LaunchAgents/com.user.downloads-organizer.plist
rm ~/Library/LaunchAgents/com.user.downloads-organizer.plist
rm -rf ~/.downloads-organizer
```

## 🐛 Solução de Problemas

### "Claude Code CLI não encontrado"

```bash
npm install -g @anthropic-ai/claude-code
# Certifique-se que está autenticado
claude auth
```

### Script não executa no domingo

```bash
# Verificar se está carregado
launchctl list | grep downloads-organizer

# Forçar execução para teste
launchctl start com.user.downloads-organizer
```

### Verificar erros

```bash
cat ~/.downloads-organizer/stderr.log
```

## 📁 Estrutura de Arquivos

```
~/.downloads-organizer/
├── organize-downloads.sh  # Script principal
├── config.yaml            # Configurações
├── organize.log           # Log de execuções
├── processed.txt          # Arquivos já processados
├── stdout.log             # Saída padrão
└── stderr.log             # Erros

~/Library/LaunchAgents/
└── com.user.downloads-organizer.plist  # Agendamento
```

## 💡 Dicas

1. **Execute um dry-run primeiro** para ver o que seria movido
2. **Personalize as regras** no config.yaml para seu fluxo de trabalho
3. **Verifique os logs** após as primeiras execuções
4. **Adicione exclusões** para arquivos que devem ficar no Downloads

---

Criado com ❤️ usando Claude Code
