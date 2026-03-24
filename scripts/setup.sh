#!/bin/bash
# nexus setup — configures statusLine in ~/.claude/settings.json

set -e

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
SETTINGS="$HOME/.claude/settings.json"
SCRIPT="$PLUGIN_ROOT/scripts/statusline.sh"

echo "Setting up nexus status bar..."
echo ""

# -- Dependency check ---------------------------------------------------------
missing=()
for dep in jq bc; do
  if ! command -v "$dep" &>/dev/null; then
    missing+=("$dep")
  fi
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

echo "OK: Dependencies found (jq, bc)"

# -- Validate settings.json exists --------------------------------------------
if [ ! -f "$SETTINGS" ]; then
  echo "ERROR: Claude settings not found at: $SETTINGS"
  echo "   Make sure Claude Code is installed and has been run at least once."
  exit 1
fi

# -- Write statusLine into settings.json using Python -------------------------
python3 - "$SETTINGS" "$SCRIPT" <<'EOF'
import json, sys

settings_path, script_path = sys.argv[1], sys.argv[2]

with open(settings_path) as f:
    settings = json.load(f)

settings['statusLine'] = {
    'type': 'command',
    'command': f'bash {script_path}'
}

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print(f'OK: statusLine configured in {settings_path}')
EOF

# -- Register marketplace in settings.json ------------------------------------
python3 - "$SETTINGS" <<'EOF'
import json, sys

settings_path = sys.argv[1]

with open(settings_path) as f:
    settings = json.load(f)

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

print('Marketplace registered: rachitgoel89/nexus on GitHub')
EOF

echo ""
echo "Restart Claude Code (or start a new session) to activate nexus."
