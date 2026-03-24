#!/bin/bash
# nexus uninstall — removes statusLine from ~/.claude/settings.json

SETTINGS="$HOME/.claude/settings.json"

if [ ! -f "$SETTINGS" ]; then
  echo "ERROR: Claude settings not found at: $SETTINGS"
  exit 1
fi

python3 - "$SETTINGS" <<'EOF'
import json, sys

settings_path = sys.argv[1]

with open(settings_path) as f:
    settings = json.load(f)

if 'statusLine' in settings:
    del settings['statusLine']
    with open(settings_path, 'w') as f:
        json.dump(settings, f, indent=2)
        f.write('\n')
    print('OK: nexus status bar removed.')
    print('   Restart Claude Code to apply.')
else:
    print('INFO: No statusLine config found -- nothing to remove.')
EOF
