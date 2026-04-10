#!/bin/bash
# Docker entrypoint: bootstrap config files into the mounted volume, then run hermes.
set -e

HERMES_HOME="/opt/data"
INSTALL_DIR="/opt/hermes"

# Create essential directory structure.  Cache and platform directories
# (cache/images, cache/audio, platforms/whatsapp, etc.) are created on
# demand by the application — don't pre-create them here so new installs
# get the consolidated layout from get_hermes_dir().
mkdir -p "$HERMES_HOME"/{cron,sessions,logs,hooks,memories,skills}

# .env
if [ ! -f "$HERMES_HOME/.env" ]; then
    cp "$INSTALL_DIR/.env.example" "$HERMES_HOME/.env"
fi

# config.yaml
if [ ! -f "$HERMES_HOME/config.yaml" ]; then
    cp "$INSTALL_DIR/cli-config.yaml.example" "$HERMES_HOME/config.yaml"
fi

# SOUL.md
if [ ! -f "$HERMES_HOME/SOUL.md" ]; then
    cp "$INSTALL_DIR/docker/SOUL.md" "$HERMES_HOME/SOUL.md"
fi

# auth.json — restore from env var if not present in volume
if [ ! -f "$HERMES_HOME/auth.json" ] && [ -n "$HERMES_AUTH_JSON" ]; then
    echo "$HERMES_AUTH_JSON" > "$HERMES_HOME/auth.json"
    chmod 600 "$HERMES_HOME/auth.json"
fi

# Telegram credentials from env vars → .env
if [ -n "$TELEGRAM_TOKEN" ]; then
    sed -i "s|^# TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=$TELEGRAM_TOKEN|" "$HERMES_HOME/.env"
fi
if [ -n "$TELEGRAM_ALLOWED_USERS" ]; then
    sed -i "s|^# TELEGRAM_ALLOWED_USERS=.*|TELEGRAM_ALLOWED_USERS=$TELEGRAM_ALLOWED_USERS|" "$HERMES_HOME/.env"
fi
if [ -n "$TELEGRAM_HOME_CHANNEL" ]; then
    sed -i "s|^# TELEGRAM_HOME_CHANNEL=.*|TELEGRAM_HOME_CHANNEL=$TELEGRAM_HOME_CHANNEL|" "$HERMES_HOME/.env"
fi

# .hermes dir for config (some versions expect it here)
mkdir -p "$HERMES_HOME/.hermes"
if [ ! -f "$HERMES_HOME/.hermes/config.yaml" ] && [ -f "$HERMES_HOME/config.yaml" ]; then
    cp "$HERMES_HOME/config.yaml" "$HERMES_HOME/.hermes/config.yaml"
fi

# Sync bundled skills (manifest-based so user edits are preserved)
if [ -d "$INSTALL_DIR/skills" ]; then
    python3 "$INSTALL_DIR/tools/skills_sync.py"
fi

exec hermes "$@"
