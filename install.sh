#!/bin/bash
# =============================================================================
# nexus — one-shot installer for Mac/Linux
# https://github.com/rachitgoel89/nexus
# =============================================================================

set -e

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
VERSION=$(python3 -c "import json; print(json.load(open('$REPO_ROOT/.claude-plugin/plugin.json'))['version'])" 2>/dev/null || echo "1.0.0")
PLUGIN_CACHE="$HOME/.claude/plugins/cache/rachitgoel89/nexus/${VERSION}"
SETTINGS="$HOME/.claude/settings.json"

echo ""
echo "  nexus — Claude Code Status Bar"
echo "  ================================"
echo ""

# -- Dependency check ---------------------------------------------------------
missing=()
for dep in jq python3; do
  command -v "$dep" &>/dev/null || missing+=("$dep")
done

if [ ${#missing[@]} -gt 0 ]; then
  echo "ERROR: Missing dependencies: ${missing[*]}"
  echo ""
  if command -v brew &>/dev/null; then
    echo "  brew install ${missing[*]}"
  elif command -v apt-get &>/dev/null; then
    echo "  sudo apt-get install -y ${missing[*]}"
  elif command -v dnf &>/dev/null; then
    echo "  sudo dnf install -y ${missing[*]}"
  else
    echo "  Please install: ${missing[*]}"
  fi
  echo ""
  exit 1
fi

echo "  [OK] Dependencies: jq, python3"

# -- Validate Claude settings exist -------------------------------------------
if [ ! -f "$SETTINGS" ]; then
  echo ""
  echo "  ERROR: Claude settings not found at: $SETTINGS"
  echo "         Run Claude Code at least once before installing nexus."
  exit 1
fi

# -- Copy plugin to Claude cache ----------------------------------------------
mkdir -p "$PLUGIN_CACHE"
rsync -a --exclude='.git' --exclude='install.sh' --exclude='install.ps1' \
  "$REPO_ROOT/" "$PLUGIN_CACHE/"
chmod +x "$PLUGIN_CACHE/scripts/"*.sh

echo "  [OK] Plugin copied to: $PLUGIN_CACHE"

# -- Update settings.json -----------------------------------------------------
python3 - "$SETTINGS" "$PLUGIN_CACHE/scripts/statusline.sh" <<'EOF'
import json, sys

settings_path, script_path = sys.argv[1], sys.argv[2]

with open(settings_path) as f:
    settings = json.load(f)

# statusLine
settings['statusLine'] = {
    'type': 'command',
    'command': f'bash {script_path}'
}

# enabledPlugins — remove old docket, add nexus
plugins = settings.get('enabledPlugins', {})
plugins.pop('docket@rachitgoel89', None)
plugins['nexus@rachitgoel89'] = True
settings['enabledPlugins'] = plugins

# extraKnownMarketplaces — register GitHub source
marketplaces = settings.get('extraKnownMarketplaces', {})
marketplaces['rachitgoel89'] = {
    'source': {
        'source': 'github',
        'repo': 'rachitgoel89/nexus',
        'ref': 'main'
    }
}
settings['extraKnownMarketplaces'] = marketplaces

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print(f'  [OK] statusLine configured')
print(f'  [OK] Plugin enabled: nexus@rachitgoel89')
print(f'  [OK] Marketplace registered: rachitgoel89/nexus')
EOF

echo ""
echo "  DONE! Restart Claude Code to activate nexus."
echo ""
echo "  Then run:  /nexus:setup"
echo "  To update: claude plugin update nexus"
echo ""
