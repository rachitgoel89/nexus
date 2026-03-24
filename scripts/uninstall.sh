#!/bin/bash
# nexus uninstall — removes nexus from ~/.claude/settings.json and plugin cache

SETTINGS="$HOME/.claude/settings.json"
PLUGIN_CACHE="$HOME/.claude/plugins/cache/rachitgoel89/nexus"

if [ ! -f "$SETTINGS" ]; then
  echo "ERROR: Claude settings not found at: $SETTINGS"
  exit 1
fi

python3 - "$SETTINGS" <<'EOF'
import json, sys

settings_path = sys.argv[1]

with open(settings_path) as f:
    settings = json.load(f)

changed = False

if 'statusLine' in settings:
    del settings['statusLine']
    changed = True
    print('OK: statusLine removed.')
else:
    print('INFO: No statusLine config found -- nothing to remove.')

plugins = settings.get('enabledPlugins', {})
if 'nexus@rachitgoel89' in plugins:
    del plugins['nexus@rachitgoel89']
    settings['enabledPlugins'] = plugins
    changed = True
    print('OK: nexus disabled in enabledPlugins.')

if changed:
    with open(settings_path, 'w') as f:
        json.dump(settings, f, indent=2)
        f.write('\n')
    print('   Restart Claude Code to apply.')
EOF

if [ -d "$PLUGIN_CACHE" ]; then
  rm -rf "$PLUGIN_CACHE"
  echo "OK: Plugin cache cleaned."
fi

rm -f /tmp/nexus-git-cache
