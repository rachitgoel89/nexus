import json
path = '/Users/raygoel/.claude/settings.json'
s = json.load(open(path))
s.pop('statusLine', None)
s.get('enabledPlugins', {}).pop('nexus@rachitgoel89', None)
open(path, 'w').write(json.dumps(s, indent=2) + '\n')
print('cleaned')
