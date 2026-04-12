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

# -- Remove nexus hooks from settings.json ------------------------------------
python3 - "$SETTINGS" <<'HOOKEOF'
import json, sys

settings_path = sys.argv[1]

with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})
for event_name in list(hooks.keys()):
    for group in hooks[event_name]:
        group['hooks'] = [h for h in group.get('hooks', []) if 'nexus' not in h.get('command', '')]
    # Remove empty matcher groups
    hooks[event_name] = [g for g in hooks[event_name] if g.get('hooks')]
    # Remove empty events
    if not hooks[event_name]:
        del hooks[event_name]

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print('OK: Nexus hooks removed')
HOOKEOF

if [ -d "$PLUGIN_CACHE" ]; then
  rm -rf "$PLUGIN_CACHE"
  echo "OK: Plugin cache cleaned."
fi

# -- Clean up cache files ------------------------------------------------------
rm -f /tmp/nexus-token-cache.json /tmp/nexus-session-start /tmp/nexus-git-cache
echo "OK: Cache files cleaned"
