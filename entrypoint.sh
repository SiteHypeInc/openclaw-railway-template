#!/bin/bash
set -e

# Ensure /data and OpenClaw state paths are writable by openclaw
mkdir -p /data/.openclaw/identity /data/workspace
chown -R openclaw:openclaw /data 2>/dev/null || true
chown -R root:root /data/.openclaw/extensions 2>/dev/null || true
chmod 700 /data 2>/dev/null || true
chmod 700 /data/.openclaw 2>/dev/null || true
chmod 700 /data/.openclaw/identity 2>/dev/null || true

# Persist Homebrew to Railway volume so it survives container rebuilds
BREW_VOLUME="/data/.linuxbrew"
BREW_SYSTEM="/home/openclaw/.linuxbrew"

if [ -d "$BREW_VOLUME" ]; then
  # Volume already has Homebrew — symlink back to expected location
  if [ ! -L "$BREW_SYSTEM" ]; then
    rm -rf "$BREW_SYSTEM"
    ln -sf "$BREW_VOLUME" "$BREW_SYSTEM"
    echo "[entrypoint] Restored Homebrew from volume symlink"
  fi
else
  # First boot — move Homebrew install to volume for persistence
  if [ -d "$BREW_SYSTEM" ] && [ ! -L "$BREW_SYSTEM" ]; then
    mv "$BREW_SYSTEM" "$BREW_VOLUME"
    ln -sf "$BREW_VOLUME" "$BREW_SYSTEM"
    echo "[entrypoint] Persisted Homebrew to volume on first boot"
  fi
fi

# Clear stale Chromium singleton locks on startup
find /data -name "SingletonLock" -delete 2>/dev/null || true
find /data -name "SingletonSocket" -delete 2>/dev/null || true

# Add OpenRouter auth profile
mkdir -p /data/.openclaw/agents/main/agent
python3 -c "
import json, os
path = '/data/.openclaw/agents/main/agent/auth-profiles.json'
try:
    with open(path, 'r') as f:
        c = json.load(f)
except:
    c = {'version': 1, 'profiles': {}, 'usageStats': {}}
c['profiles']['openrouter:default'] = {
    'type': 'api_key',
    'provider': 'openrouter',
    'baseUrl': 'https://openrouter.ai/api/v1',
    'key': os.environ.get('OPENROUTER_API_KEY', '')
}
with open(path, 'w') as f:
    json.dump(c, f, indent=2)
" 2>/dev/null || true

exec gosu openclaw node src/server.js
exec gosu openclaw node src/server.js
