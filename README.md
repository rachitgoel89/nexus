# nexus

Tokyo Night themed status bar for Claude Code — time, model, context window, cost, git branch, and stash count at a glance.

**Features:**
- **Exact token counts** — displays real token usage with comma separators (e.g., `108,994/200k`) when hook data is available
- **Hook-accurate context tracking** — parses the session transcript JSONL to extract true input token counts instead of relying on API estimates
- **Session duration timer** — elapsed time since session start
- **Adaptive token formatting** — automatic fallback to estimates (800 / 36.0k / 150k) when hooks are stale
- **Session cost** with color-coded thresholds
- **Git branch and stash count**
- **Tokyo Night 256-color theme**
- **Cross-platform** (bash + PowerShell)

```
00:42 | ⏱ 1h06m | Opus 4.6 | [▓▓▓▓▓▶░░░░░] 108,994/200k (54%) | 💰 $2.15 | ⎇ main
```

![nexus preview](assets/preview.png)

## How it works

A `Stop` hook fires after every Claude response and parses the session transcript JSONL to extract real token counts (`input_tokens + cache_creation_input_tokens + cache_read_input_tokens`), writing them to `/tmp/nexus-token-cache.json`. The status bar reads this cache (refreshed within 60 seconds) and uses the exact numbers instead of the API's `used_percentage` estimate, which can lag or diverge significantly.

A `SessionStart` hook writes the session start timestamp to `/tmp/nexus-session-start`, allowing the status bar to display elapsed time between the clock and model name.

When hook data is stale or unavailable, the bar falls back to adaptive token formatting based on API estimates.

This means the context fill shown is derived from actual API usage data — the same numbers the model sees — rather than a potentially stale server-side percentage.

## What's new in v1.2.0

- **Hook-accurate token tracking** — a `Stop` hook now fires after every response, parsing the real transcript token counts. Previously, the context fill came from the API's `used_percentage` which can lag or diverge by 10–20%.
- **Exact token display** — token count shown as `108,994/200k` with full precision when hook data is available, not a rounded estimate.
- **Session duration** — `⏱ 1h06m` displayed between the clock and model name, driven by a `SessionStart` hook.
- **Adaptive fallback formatting** — when hooks are stale, estimates display as `800`, `36.0k`, or `150k` depending on magnitude.
- **PowerShell cursor fix** — the `▶` crawling cursor was missing from the Windows version. Fixed.

## Installation

### Via Claude Code plugin system

```
claude plugin marketplace add rachitgoel89/nexus
claude plugin install nexus@rachitgoel89
```

Then inside Claude Code, run:

```
/nexus:setup
```

Restart Claude Code (or start a new session) to activate the status bar.

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
