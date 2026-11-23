#!/usr/bin/env bash
# =============================================================================
# install.sh — recria o ambiente numa máquina macOS nova (Apple Silicon ou Intel).
#
#   ./install.sh                 # tudo
#   ./install.sh brew vscode     # só as etapas escolhidas
#
# Etapas: clt brew shell git node vscode python ruby
# É idempotente: pode rodar várias vezes sem estragar nada.
# =============================================================================
set -uo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
ARCH="$(uname -m)"
if [ "$ARCH" = "arm64" ]; then BREW_PREFIX="/opt/homebrew"; else BREW_PREFIX="/usr/local"; fi
CODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
VSCODE_USER="$HOME/Library/Application Support/Code/User"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
FAILED=()

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m  ! %s\033[0m\n' "$*"; FAILED+=("$*"); }

# Cria symlink ~/.arquivo → dotfiles/arquivo, guardando backup do que existia.
link() {
  local src="$DOTFILES/$1" dst="$2"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mkdir -p "$BACKUP_DIR" && mv "$dst" "$BACKUP_DIR/"
    echo "  backup: $dst → $BACKUP_DIR/"
  fi
  ln -sfn "$src" "$dst" && echo "  $dst → $src"
}

step_clt() {
  log "Xcode Command Line Tools"
  if ! xcode-select -p >/dev/null 2>&1; then
    xcode-select --install
    echo "Conclua a instalação na janela do sistema e rode ./install.sh de novo."
    exit 1
  fi
  echo "  ok"
}

step_brew() {
  log "Homebrew ($ARCH → $BREW_PREFIX)"
  if [ ! -x "$BREW_PREFIX/bin/brew" ]; then
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  eval "$("$BREW_PREFIX/bin/brew" shellenv)"
  log "brew bundle (Brewfile)"
  brew bundle --file="$DOTFILES/Brewfile" || warn "brew bundle: alguns itens falharam (veja acima)"
  # VS Code é necessário para a etapa 'vscode'.
  [ -d "/Applications/Visual Studio Code.app" ] || brew install --cask visual-studio-code
}

step_shell() {
  log "Shell (zsh)"
  link shell/zprofile "$HOME/.zprofile"
  link shell/zshrc    "$HOME/.zshrc"
  [ -f "$HOME/.zshrc.local" ] || cp "$DOTFILES/shell/zshrc.local.example" "$HOME/.zshrc.local"
}

step_git() {
  log "Git"
  link git/gitconfig "$HOME/.gitconfig"
  for f in "$DOTFILES"/git/gitconfig-*; do
    [ -f "$f" ] && link "git/$(basename "$f")" "$HOME/.$(basename "$f")"
  done
}

step_node() {
  log "Node (nvm)"
  [ -x "$BREW_PREFIX/bin/brew" ] && eval "$("$BREW_PREFIX/bin/brew" shellenv)"
  export NVM_DIR="$HOME/.nvm"; mkdir -p "$NVM_DIR"
  local nvm_sh=""
  for c in "$NVM_DIR/nvm.sh" "$BREW_PREFIX/opt/nvm/nvm.sh"; do [ -s "$c" ] && nvm_sh="$c" && break; done
  if [ -z "$nvm_sh" ]; then warn "nvm não encontrado (rode a etapa brew antes)"; return; fi
  # shellcheck disable=SC1090
  . "$nvm_sh"
  # O nvm compila/baixa o binário certo para a arquitetura desta máquina.
  while read -r v; do
    [ -z "$v" ] && continue
    nvm install "$v" >/dev/null && echo "  node v$v" || warn "node v$v falhou"
  done < "$DOTFILES/node/versions.txt"
  local def; def="$(cat "$DOTFILES/node/default.txt")"
  nvm install "$def" >/dev/null; nvm alias default "$def"; nvm use default >/dev/null
  if [ -s "$DOTFILES/node/globals.txt" ]; then
    xargs npm install -g < "$DOTFILES/node/globals.txt" || warn "npm globals falharam"
  fi
}

step_vscode() {
  log "VS Code"
  if [ ! -x "$CODE_BIN" ]; then warn "VS Code não instalado"; return; fi
  mkdir -p "$VSCODE_USER/snippets"
  for f in settings.json keybindings.json; do
    if [ -f "$DOTFILES/vscode/$f" ]; then
      [ -f "$VSCODE_USER/$f" ] && mkdir -p "$BACKUP_DIR" && cp "$VSCODE_USER/$f" "$BACKUP_DIR/vscode-$f"
      cp "$DOTFILES/vscode/$f" "$VSCODE_USER/$f"
    fi
  done
  rsync -a "$DOTFILES/vscode/snippets/" "$VSCODE_USER/snippets/"
  local installed; installed="$("$CODE_BIN" --list-extensions | tr 'A-Z' 'a-z')"
  while read -r ext; do
    [ -z "$ext" ] && continue
    if echo "$installed" | grep -qx "$(echo "$ext" | tr 'A-Z' 'a-z')"; then continue; fi
    "$CODE_BIN" --install-extension "$ext" >/dev/null 2>&1 && echo "  + $ext" || warn "extensão $ext falhou"
  done < "$DOTFILES/vscode/extensions.txt"
}

step_python() {
  log "Python (pip --user)"
  if [ -s "$DOTFILES/python/requirements-user.txt" ]; then
    python3 -m pip install --user -r "$DOTFILES/python/requirements-user.txt" || warn "pip falhou"
  else
    echo "  nada a instalar"
  fi
}

step_ruby() {
  log "Ruby (rvm)"
  [ -s "$DOTFILES/ruby/versions.txt" ] || { echo "  nada a instalar"; return; }
  if [ ! -s "$HOME/.rvm/scripts/rvm" ]; then
    curl -sSL https://get.rvm.io | bash -s stable --ignore-dotfiles || { warn "rvm falhou"; return; }
  fi
  # shellcheck disable=SC1091
  . "$HOME/.rvm/scripts/rvm"
  while read -r v; do
    [ -z "$v" ] && continue
    # Ruby 2.x precisa de OpenSSL 1.1 (desativado no Homebrew; use se existir).
    local ssl=()
    [[ "$v" == 2.* && -d "$BREW_PREFIX/opt/openssl@1.1" ]] && ssl=(--with-openssl-dir="$BREW_PREFIX/opt/openssl@1.1")
    rvm install "$v" "${ssl[@]}" || warn "ruby $v falhou"
  done < "$DOTFILES/ruby/versions.txt"
  [ -s "$DOTFILES/ruby/default.txt" ] && rvm alias create default "ruby-$(cat "$DOTFILES/ruby/default.txt")"
}

ALL=(clt brew shell git node vscode python ruby)
STEPS=("$@"); [ ${#STEPS[@]} -eq 0 ] && STEPS=("${ALL[@]}")
echo "macOS $(sw_vers -productVersion) · $ARCH · Homebrew em $BREW_PREFIX"
for s in "${STEPS[@]}"; do "step_$s"; done

log "Concluído"
if [ ${#FAILED[@]} -gt 0 ]; then
  printf '\033[1;33mPendências:\033[0m\n'; printf '  - %s\n' "${FAILED[@]}"
fi
echo "Abra um novo terminal (ou: exec zsh) para carregar o shell novo."
