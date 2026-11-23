# dotfiles

Meu ambiente de desenvolvimento macOS, recriável em qualquer Mac: **Apple Silicon (arm64)** ou **Intel (x86_64)**.

## Máquina nova

```bash
# 1. Clonar (repositório PRIVADO)
git clone git@github.com:<seu-usuario>/dotfiles.git ~/dotfiles   # ou copie a pasta via AirDrop/pendrive
cd ~/dotfiles

# 2. Instalar tudo
./install.sh

# ou só algumas etapas
./install.sh brew node vscode
```

Etapas, na ordem: `clt` → `brew` → `shell` → `git` → `node` → `vscode` → `python` → `ruby`.
O script é idempotente e faz backup do que substituir em `~/.dotfiles-backup/<data>/`.

## Manter atualizado (na máquina "principal")

```bash
cd ~/dotfiles && ./export.sh && git diff && git commit -am "snapshot $(date +%F)" && git push
```

## O que fica guardado

| Arquivo | Conteúdo | Gerado por |
|---|---|---|
| `Brewfile` | formulae, casks e taps do Homebrew | `export.sh` |
| `vscode/extensions.txt` | extensões do VS Code | `export.sh` |
| `vscode/settings.json`, `keybindings.json`, `snippets/` | configurações do VS Code | `export.sh` |
| `node/versions.txt` | última versão de cada major do Node (nvm) | `export.sh` |
| `node/default.txt` | versão padrão do nvm | `export.sh` |
| `node/globals.txt` | pacotes `npm -g` | `export.sh` |
| `ruby/versions.txt`, `default.txt` | rubies do rvm | `export.sh` |
| `python/requirements-user.txt` | `pip --user` | `export.sh` |
| `git/gitconfig*` | `.gitconfig` e includes | `export.sh` |
| `macos/applications.txt` | apps em /Applications (checklist do que não vem do brew) | `export.sh` |
| `shell/zshrc`, `shell/zprofile` | shell **portátil** | escrito à mão |

## Como a portabilidade arm64 ↔ Intel é garantida

- **Nenhum caminho fixo.** O Homebrew fica em `/opt/homebrew` (arm64) ou `/usr/local` (Intel). O `zprofile` escolhe pelo `uname -m` e todo o resto usa `$HOMEBREW_PREFIX`.
- **Nada compilado é copiado.** Não levamos `node_modules`, `~/.nvm` ou binários. Guardamos só *listas* (Brewfile, versões, nomes de pacotes) e cada máquina baixa/compila o binário da própria arquitetura.
- **Projetos:** `node_modules` nunca vai de uma máquina para outra. Em cada projeto, rode `npm ci` (ou `yarn install --frozen-lockfile`); o lockfile garante as mesmas versões.
- **Específico da máquina** (tokens, paths locais) vai em `~/.zshrc.local`, que não é versionado.

## VS Code + Settings Sync

Se o Settings Sync estiver ligado (engrenagem → *Backup and Sync Settings*, com **Extensions** marcado), entrar com a mesma conta já sincroniza extensões e settings. Este repositório é a **segunda via**: funciona sem login, fica versionado e não depende da nuvem da Microsoft.

## Fica de fora de propósito (copiar manualmente / com segurança)

- Chaves SSH/GPG (`~/.ssh`, `~/.gnupg`): gere novas ou transfira com cuidado.
- `.env` de projetos e `vscode/mcp.json` (contêm segredos).
- Apps fora do Homebrew (Docker Desktop, etc.): veja `macos/applications.txt`.

## Observações para o Mac Intel

- O macOS 26 (Tahoe) é a última versão com suporte a Intel; o Homebrew ainda funciona, mas algumas fórmulas podem compilar do código-fonte (demora mais).
- `openssl@1.1` foi desativado no Homebrew e deve falhar numa instalação nova. Ele só é necessário para Ruby 2.7; prefira Ruby 3.x.
- Node 14/16/17/19 estão fora de suporte. Apague de `node/versions.txt` o que não usar mais.
