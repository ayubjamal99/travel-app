#!/usr/bin/env bash
# Runs once when the devcontainer is created (and again on rebuild).
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

step "Fixing ownership of persisted volumes"
for d in "$HOME/.claude" "$HOME/.config/gh" "$HOME/.m2"; do
  sudo mkdir -p "$d"
  sudo chown -R "$(id -u):$(id -g)" "$d"
done

step "OS packages: tmux, jq, shellcheck, curl"
sudo apt-get update -qq
sudo apt-get install -y -qq tmux jq shellcheck curl ca-certificates unzip >/dev/null

step "gitleaks (latest release)"
if ! command -v gitleaks >/dev/null; then
  case "$(uname -m)" in
    x86_64|amd64) GL_ARCH=x64 ;;
    aarch64|arm64) GL_ARCH=arm64 ;;
    *) echo "unsupported arch $(uname -m)"; exit 1 ;;
  esac
  GL_URL=$(curl -fsSL https://api.github.com/repos/gitleaks/gitleaks/releases/latest \
    | jq -r --arg a "linux_${GL_ARCH}.tar.gz" '.assets[] | select(.name | endswith($a)) | .browser_download_url' | head -1)
  tmp=$(mktemp -d)
  curl -fsSL "$GL_URL" -o "$tmp/gl.tgz"
  tar -xzf "$tmp/gl.tgz" -C "$tmp" gitleaks
  sudo install -m 0755 "$tmp/gitleaks" /usr/local/bin/gitleaks
  rm -rf "$tmp"
fi
gitleaks version

step "Claude Code"
if ! command -v claude >/dev/null; then
  curl -fsSL https://claude.ai/install.sh | bash || npm install -g @anthropic-ai/claude-code
fi
# The native installer puts claude in ~/.local/bin
grep -q '.local/bin' "$HOME/.bashrc" 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
export PATH="$HOME/.local/bin:$PATH"
claude --version || true

step "Angular CLI"
npm install -g @angular/cli >/dev/null 2>&1
ng version --skip-confirmation >/dev/null 2>&1 || true

step "Playwright system dependencies (Chromium)"
npx -y playwright install --with-deps chromium >/dev/null 2>&1 || echo "  (playwright deps install skipped; QA can run it later)"

step "Repo wiring"
git config core.hooksPath .githooks
chmod +x scripts/agentctl scripts/*.sh scripts/hooks/*.sh .githooks/* 2>/dev/null || true
mkdir -p ops/.runtime ops/handoff
[ -f ops/STATE ] || echo STOPPED > ops/STATE
[ -f ops/handoff/CURRENT.md ] || cp ops/handoff/TEMPLATE.md ops/handoff/CURRENT.md
[ -f .env ] || cp .env.example .env
# agentctl on PATH
sudo ln -sf "$ROOT/scripts/agentctl" /usr/local/bin/agentctl

step "Done. Versions:"
java -version 2>&1 | head -1
mvn -v 2>/dev/null | head -1
node -v
gh --version | head -1
docker --version 2>/dev/null || true
cat <<'EOF'

Next (one time, in this terminal):
  1. claude            -> log in with your Claude Pro account, then /config:
                          turn ON "Continue automatically at usage limit". Exit.
  2. gh auth login     -> then: gh auth refresh -s project
  3. edit .env         -> paste SLACK_WEBHOOK_URL
  4. agentctl doctor
See SETUP.md for the rest.
EOF
