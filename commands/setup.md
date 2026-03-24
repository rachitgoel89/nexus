---
name: setup
description: Configure the nexus status bar in Claude Code settings
allowed-tools: Bash
---

Run the nexus setup script to install the status bar:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh"
```

Show the user the full output. If dependencies are missing, clearly display the install command for their OS. If setup succeeds, confirm the status bar will appear after restarting Claude Code.
