#!/usr/bin/env bash
# =============================================================================
# export.sh — tira um "snapshot" do ambiente desta máquina para este repositório.
# Rode sempre que instalar/remover algo relevante e depois faça commit.
#   ./export.sh
# Funciona igual em Apple Silicon (arm64) e Intel (x86_64).
# =============================================================================
set -uo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
CODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
VSCODE_USER="$HOME/Library/Application Support/Code/User"

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }

mkdir -p "$DOTFILES"/{vscode/snippets,node,ruby,python,git,macos}

# --- Homebrew ---------------------------------------------------------------
# O Brewfile é independente de arquitetura: o brew baixa o binário certo
# (arm64 ou x86_64) na hora de instalar.
log "Homebrew → Brewfile"
if command -v brew >/dev/null; then
  brew bundle dump --file="$DOTFILES/Brewfile" --force --no-vscode
  # Globais npm ficam na etapa node (dependem da versão ativa do nvm).
  sed -i '' '/^npm /d' "$DOTFILES/Brewfile"
  echo "  $(grep -cE '^(brew|cask|tap)' "$DOTFILES/Brewfile") itens"
else
  warn "brew não encontrado"
fi

# --- VS Code ----------------------------------------------------------------
log "VS Code → extensões, settings, keybindings, snippets"
if [ -x "$CODE_BIN" ]; then
  "$CODE_BIN" --list-extensions | sort -f > "$DOTFILES/vscode/extensions.txt"
  echo "  $(wc -l < "$DOTFILES/vscode/extensions.txt" | tr -d ' ') extensões"
else
  warn "VS Code não encontrado em /Applications"
fi
for f in settings.json keybindings.json; do
  [ -f "$VSCODE_USER/$f" ] && cp "$VSCODE_USER/$f" "$DOTFILES/vscode/$f"
done
if [ -d "$VSCODE_USER/snippets" ]; then
  rsync -a --delete "$VSCODE_USER/snippets/" "$DOTFILES/vscode/snippets/"
fi
# mcp.json fica de fora de propósito: costuma conter tokens.

# --- Node (nvm) -------------------------------------------------------------
log "Node → versões, default e pacotes globais"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
NVM_SH=""
for c in "$NVM_DIR/nvm.sh" "$(brew --prefix 2>/dev/null)/opt/nvm/nvm.sh"; do
  [ -s "$c" ] && NVM_SH="$c" && break
done
if [ -n "$NVM_SH" ]; then
  # shellcheck disable=SC1090
  . "$NVM_SH"
  # Mantém só a versão mais nova de cada major (v18.x, v20.x, v22.x...).
  # Se algum projeto exigir um patch exato, adicione a linha manualmente.
  ls "$NVM_DIR/versions/node" | sed 's/^v//' \
    | sort -t. -k1,1n -k2,2n -k3,3n \
    | awk -F. '{last[$1]=$0} END {for (k in last) print last[k]}' \
    | sort -t. -k1,1n > "$DOTFILES/node/versions.txt"
  nvm version default > "$DOTFILES/node/default.txt"
  nvm use default >/dev/null
  # Só os nomes (sem versão): na reinstalação pega a versão atual de cada CLI.
  npm ls -g --depth=0 --json \
    | node -e 'const d=JSON.parse(require("fs").readFileSync(0));for(const n of Object.keys(d.dependencies||{}))if(!["npm","corepack"].includes(n))console.log(n)' \
    > "$DOTFILES/node/globals.txt"
  echo "  versões: $(tr '\n' ' ' < "$DOTFILES/node/versions.txt")"
  echo "  default: $(cat "$DOTFILES/node/default.txt")"
  echo "  globais: $(tr '\n' ' ' < "$DOTFILES/node/globals.txt")"
else
  warn "nvm não encontrado"
fi

# --- Ruby (rvm) -------------------------------------------------------------
log "Ruby → versões do rvm"
if [ -d "$HOME/.rvm/rubies" ]; then
  ls "$HOME/.rvm/rubies" | grep -E '^ruby-' | sed 's/^ruby-//' > "$DOTFILES/ruby/versions.txt"
  basename "$(readlink "$HOME/.rvm/rubies/default" 2>/dev/null || echo '')" | sed 's/^ruby-//' > "$DOTFILES/ruby/default.txt"
  echo "  $(tr '\n' ' ' < "$DOTFILES/ruby/versions.txt")"
fi

# --- Python -----------------------------------------------------------------
log "Python → pacotes pip --user"
python3 -m pip list --user --format=freeze 2>/dev/null > "$DOTFILES/python/requirements-user.txt" || true
echo "  $(wc -l < "$DOTFILES/python/requirements-user.txt" | tr -d ' ') pacotes"

# --- Git --------------------------------------------------------------------
log "Git → .gitconfig (+ includes)"
[ -f "$HOME/.gitconfig" ] && cp "$HOME/.gitconfig" "$DOTFILES/git/gitconfig"
for inc in "$HOME"/.gitconfig-*; do
  [ -f "$inc" ] && cp "$inc" "$DOTFILES/git/$(basename "$inc" | sed 's/^\.//')"
done

# --- Apps instalados fora do Homebrew (só referência) -----------------------
log "macOS → lista de /Applications (checklist manual)"
ls /Applications | sed 's/\.app$//' > "$DOTFILES/macos/applications.txt"

log "Pronto. Revise com 'git diff' e faça commit."
