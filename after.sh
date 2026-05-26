#!/usr/bin/env bash
# ============================================================
# after.sh — CachyOS COSMIC Setup (after first reboot)
# Run this AFTER restarting from before.sh
# ============================================================

set -uo pipefail
trap 'echo "[ERROR] Command failed on line $LINENO. Check the log for details."' ERR

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOGFILE="$SCRIPT_DIR/after-$(date +%Y%m%d-%H%M%S).log"
ERRORS=0

exec > >(tee -a "$LOGFILE") 2>&1

log() { echo "[$(date '+%H:%M:%S')] $*"; }
section() { echo ""; echo "============================================================"; echo "  $*"; echo "============================================================"; }
warn() { echo "[WARN] $*"; }
ok()   { echo "[OK]   $*"; }

echo "# after.sh log — $(date)"
echo "# Log file: $LOGFILE"
echo ""

# ============================================================
section "Checking groups are active"
# ============================================================
echo "Current groups: $(groups)"
echo "If 'libvirt' or 'flutter' are not listed, run: newgrp libvirt"
echo ""

# ============================================================
section "Flutter configuration"
# ============================================================
if command -v flutter &>/dev/null; then
    echo "Configuring Flutter..."

    flutter config --android-sdk "$HOME/Android/Sdk" 2>&1 && ok "Android SDK set" || warn "Could not set Android SDK path"

    flutter config --no-analytics 2>&1 && ok "Analytics disabled" || warn "Could not disable analytics"

    if [ -d "$HOME/Android/Sdk" ]; then
        flutter doctor --android-licenses 2>&1 && ok "Android licenses accepted" || warn "Android licenses could not be accepted (run manually: flutter doctor --android-licenses)"
    else
        warn "Android SDK not found at $HOME/Android/Sdk — skipping licenses"
        echo "  Install Android SDK first, then run: flutter doctor --android-licenses"
    fi

    ok "Flutter setup done"
else
    warn "flutter not found in PATH"
    echo "  Possible reasons:"
    echo "    - The flutter group hasn't taken effect yet"
    echo "    - Try: newgrp flutter"
    echo "    - Or: log out and log in again"
fi

# ============================================================
section "NVM — install latest Node.js"
# ============================================================
export NVM_DIR="$HOME/.nvm"

if [ -s "/usr/share/nvm/init-nvm.sh" ]; then
    source "/usr/share/nvm/init-nvm.sh"
    echo "NVM version: $(nvm --version 2>/dev/null)"

    echo "Installing latest Node.js..."
    nvm install node 2>&1 && ok "Latest Node.js installed" || { warn "Node.js install failed"; ERRORS=$((ERRORS + 1)); }

    nvm alias default node 2>&1 && ok "Default Node alias set" || warn "Could not set default alias"

    echo "Node version: $(node --version 2>/dev/null)"
    echo "npm version:  $(npm --version 2>/dev/null)"
else
    warn "NVM init script not found at /usr/share/nvm/init-nvm.sh"
    echo "  Make sure nvm package is installed and .zshrc is sourced."
    echo "  Try: source ~/.zshrc"
fi

# ============================================================
section "Global npm packages"
# ============================================================
if command -v npm &>/dev/null; then
    echo "Installing @openai/codex..."
    npm install -g @openai/codex 2>&1 && ok "@openai/codex installed" || warn "@openai/codex install failed"

    echo "Installing @google/gemini-cli..."
    npm install -g @google/gemini-cli 2>&1 && ok "@google/gemini-cli installed" || warn "@google/gemini-cli install failed"
else
    warn "npm not available — skipping global packages"
fi

# ============================================================
section "Ensuring syncthing user service is running"
# ============================================================
systemctl --user enable --now syncthing.service && ok "syncthing service running" || warn "Could not enable syncthing"

# ============================================================
section "Summary"
# ============================================================
echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo "  Finished with $ERRORS warning(s). Check the log for details."
else
    echo "  All steps completed successfully!"
fi
echo ""
echo "  Log saved to: $LOGFILE"
echo ""
echo "  Your CachyOS COSMIC setup is done!"
echo ""
