# nexus

Tokyo Night themed status bar for Claude Code — time, model, context window, cost, git branch, and stash count at a glance.

![nexus preview](assets/preview.png)

## Installation

### Via Claude Code plugin system

```
claude plugin marketplace add rachitgoel89/nexus
claude plugin install nexus@rachitgoel89
```

### Manual

```bash
bash scripts/setup.sh
```

Restart Claude Code (or start a new session) after installing.

## Updating

Once installed, you can update nexus to the latest version with:

```
claude plugin update nexus
```

The installer registers the `rachitgoel89/nexus` GitHub marketplace so Claude Code knows where to fetch updates from.

## Uninstalling

```
claude plugin uninstall nexus
```

Or manually:

```bash
bash scripts/uninstall.sh
```
