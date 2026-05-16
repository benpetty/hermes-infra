#!/usr/bin/env bash
# Finishes the Hermes bootstrap on a box where cloud-init's runcmd died
# mid-way. Idempotent — safe to re-run.
#
# Usage (on the box, after `scp`ing this file to /tmp/):
#   bash /tmp/recover.sh

set -euo pipefail

# ----- Pre-configure apt/needrestart for non-interactive operation --------
# MUST run before anything that might apt-install (signal-cli is binary-only,
# but Hermes' installer apt-installs Playwright deps). Without this, an
# interactive needrestart "Pending kernel upgrade" dialog can lock the run.
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

if [ ! -f /etc/needrestart/conf.d/no-prompt.conf ]; then
  echo "==> Arming needrestart for non-interactive mode"
  sudo mkdir -p /etc/needrestart/conf.d
  sudo tee /etc/needrestart/conf.d/no-prompt.conf >/dev/null <<'NRCONF'
$nrconf{restart} = 'a';
$nrconf{kernelhints} = 0;
NRCONF
fi

if [ ! -f /etc/apt/apt.conf.d/99-noninteractive ]; then
  echo "==> Arming apt for non-interactive mode"
  sudo tee /etc/apt/apt.conf.d/99-noninteractive >/dev/null <<'APTCONF'
APT::Get::Assume-Yes "true";
Dpkg::Options { "--force-confdef"; "--force-confold"; };
APTCONF
fi

LOG=/tmp/hermes-recovery.log
exec > >(tee -a "$LOG") 2>&1
echo "[$(date -Is)] recovery starting (noninteractive mode armed)"

# ----- signal-cli ---------------------------------------------------------
if ! command -v signal-cli >/dev/null 2>&1; then
  echo "==> Installing signal-cli"
  SC_URL="$(curl -fsIL -o /dev/null -w '%{url_effective}' https://github.com/AsamK/signal-cli/releases/latest)"
  SC_VERSION="${SC_URL##*/v}"
  if ! echo "$SC_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "FATAL: signal-cli version unresolved (got: '$SC_VERSION')" >&2
    exit 1
  fi
  echo "    version v$SC_VERSION"

  # Asset names changed in 2026. The `-Linux-client.tar.gz` and
  # `-Linux-native.tar.gz` builds ship a single binary at the archive root
  # (not the historical `signal-cli-X.Y.Z/bin/signal-cli` layout). We use
  # the -client build because default-jre-headless is installed via the
  # cloud-init packages list. Handle both single-binary and directory cases
  # so a future format change doesn't break us silently.
  rm -f /tmp/signal-cli.tar.gz
  curl -fsSL "https://github.com/AsamK/signal-cli/releases/download/v${SC_VERSION}/signal-cli-${SC_VERSION}-Linux-client.tar.gz" -o /tmp/signal-cli.tar.gz

  SC_ARCHIVE_ROOT="$(tar -tzf /tmp/signal-cli.tar.gz | head -1 | cut -d/ -f1)"
  echo "    archive root: $SC_ARCHIVE_ROOT"

  # Clean up leftovers from any prior partial install (the broken symlink
  # at /opt/signal-cli and the orphaned binary file).
  sudo rm -f /opt/signal-cli /usr/local/bin/signal-cli
  sudo rm -rf "/opt/$SC_ARCHIVE_ROOT"
  sudo tar -xzf /tmp/signal-cli.tar.gz -C /opt/

  TARGET="/opt/$SC_ARCHIVE_ROOT"
  if [ -f "$TARGET" ]; then
    # Single-binary distribution: move into PATH directly.
    sudo mv "$TARGET" /usr/local/bin/signal-cli
    sudo chmod +x /usr/local/bin/signal-cli
    echo "    installed: /usr/local/bin/signal-cli (single binary)"
  elif [ -d "$TARGET" ]; then
    # Directory distribution: symlink launcher.
    sudo ln -sfn "$TARGET" /opt/signal-cli
    SC_BIN_PATH="$(find /opt/signal-cli/ -name signal-cli -type f -executable | head -1)"
    if [ -z "$SC_BIN_PATH" ]; then
      echo "FATAL: signal-cli binary not found inside /opt/signal-cli/" >&2
      exit 1
    fi
    sudo ln -sfn "$SC_BIN_PATH" /usr/local/bin/signal-cli
    echo "    installed: /usr/local/bin/signal-cli → $SC_BIN_PATH (launcher)"
  else
    echo "FATAL: extracted $TARGET is neither file nor directory" >&2
    exit 1
  fi
  signal-cli --version
else
  echo "==> signal-cli already installed: $(signal-cli --version)"
fi

# ----- Hermes (as the current user, expected to be 'hermes') --------------
if [ "$(id -un)" != "hermes" ]; then
  echo "FATAL: this script expects to be run as the 'hermes' user (got: $(id -un))" >&2
  exit 1
fi

# Always re-run the Hermes installer; it's idempotent on a warm cache and
# this handles the case where a previous attempt died mid-install (leaving
# ~/.hermes/ present but the install incomplete).
echo "==> Installing/refreshing Hermes Agent (installer is idempotent)"
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash

# ----- Source ~/.hermes-env from bashrc -----------------------------------
if ! grep -q 'hermes-env' "$HOME/.bashrc" 2>/dev/null; then
  echo "==> Wiring .hermes-env into bashrc"
  echo '[ -f ~/.hermes-env ] && . ~/.hermes-env' >> "$HOME/.bashrc"
else
  echo "==> bashrc already sources .hermes-env"
fi

# ----- Final cloud-init tail-end tasks ------------------------------------
sudo systemctl enable --now unattended-upgrades
sudo touch /opt/hermes-bootstrap/done

echo "[$(date -Is)] recovery complete"
echo
echo "Next: reload your shell so PATH and .hermes-env take effect."
echo "  exec bash -l    (or just open a new SSH session)"
