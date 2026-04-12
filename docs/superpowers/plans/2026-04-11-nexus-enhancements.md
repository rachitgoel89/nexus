# Nexus Status Bar Enhancements

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve token count accuracy via hooks, add adaptive token formatting, fix PowerShell cursor parity, and add session duration display.

**Architecture:** A `Stop` hook script parses the transcript JSONL to extract real token counts and writes them to a cache file. A `SessionStart` hook writes a timestamp file. The statusline scripts read both cache files to display accurate context data and session duration. All hook scripts are bash (macOS/Linux) with PowerShell equivalents.

**Tech Stack:** Bash, PowerShell, jq, Python (for JSON parsing in hooks)

---

## File Structure

```
scripts/
  statusline.sh          # MODIFY - adaptive formatting, read token cache, session duration
  statusline.ps1         # MODIFY - cursor fix, adaptive formatting, read token cache, session duration
  hooks/
    stop.sh              # CREATE - parses transcript for real token counts, writes cache
    session-start.sh     # CREATE - writes session start timestamp
  setup.sh               # MODIFY - register Stop and SessionStart hooks
  uninstall.sh           # MODIFY - clean up hook entries and cache files
commands/
  setup.md               # No change needed (delegates to setup.sh)
```

---

### Task 1: Create the Stop Hook Script

**Files:**
- Create: `scripts/hooks/stop.sh`

This hook fires after every Claude response. It reads the transcript JSONL, finds the last assistant message, extracts token counts, and writes to `/tmp/nexus-token-cache.json`.

- [ ] **Step 1: Create `scripts/hooks/stop.sh`**

```bash
#!/bin/bash
# nexus Stop hook — extracts real token counts from transcript JSONL
# Writes to /tmp/nexus-token-cache.json for the statusline to read.
# Runs after every Claude response. Must exit 0 always. No stdout.

set -e

CACHE="/tmp/nexus-token-cache.json"
input=$(cat)

transcript=$(echo "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)

if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then
  exit 0
fi

# Find the last assistant message with usage data (search from end)
usage_json=$(tail -200 "$transcript" \
  | grep '"type":"assistant"' \
  | tail -1 \
  | jq -r '.message.usage // empty' 2>/dev/null)

if [ -z "$usage_json" ] || [ "$usage_json" = "null" ]; then
  exit 0
fi

# Extract token fields
input_tokens=$(echo "$usage_json" | jq -r '.input_tokens // 0')
cache_creation=$(echo "$usage_json" | jq -r '.cache_creation_input_tokens // 0')
cache_read=$(echo "$usage_json" | jq -r '.cache_read_input_tokens // 0')
output_tokens=$(echo "$usage_json" | jq -r '.output_tokens // 0')

# Total input = all input token types (this is the actual context window fill)
total_input=$(( input_tokens + cache_creation + cache_read ))

# Write cache atomically
tmp_cache="${CACHE}.tmp.$$"
cat > "$tmp_cache" <<EOF
{"total_input":${total_input},"output_tokens":${output_tokens},"input_tokens":${input_tokens},"cache_creation":${cache_creation},"cache_read":${cache_read},"session_id":"${session_id}","timestamp":$(date +%s)}
EOF
mv "$tmp_cache" "$CACHE"
chmod 600 "$CACHE" 2>/dev/null

exit 0
```

- [ ] **Step 2: Make executable**

Run: `chmod +x scripts/hooks/stop.sh`

- [ ] **Step 3: Test manually**

Run:
```bash
echo '{"transcript_path":"/Users/raygoel/.claude/projects/-Users-raygoel/dc030a99-5ccb-491f-8b3e-e5f15224023c.jsonl","session_id":"test123"}' | bash scripts/hooks/stop.sh && cat /tmp/nexus-token-cache.json | jq .
```
Expected: JSON with `total_input`, `output_tokens`, `timestamp` fields populated with real numbers.

- [ ] **Step 4: Commit**

```bash
git add scripts/hooks/stop.sh
git commit -m "feat: add Stop hook to capture real token counts from transcript"
```

---

### Task 2: Create the SessionStart Hook Script

**Files:**
- Create: `scripts/hooks/session-start.sh`

Writes a timestamp file when a session begins. The statusline reads it to compute elapsed duration.

- [ ] **Step 1: Create `scripts/hooks/session-start.sh`**

```bash
#!/bin/bash
# nexus SessionStart hook — records session start time
# Writes to /tmp/nexus-session-start for the statusline to read.
# No stdout. Always exits 0.

TIMESTAMP_FILE="/tmp/nexus-session-start"

echo "$(date +%s)" > "$TIMESTAMP_FILE"
chmod 600 "$TIMESTAMP_FILE" 2>/dev/null

exit 0
```

- [ ] **Step 2: Make executable**

Run: `chmod +x scripts/hooks/session-start.sh`

- [ ] **Step 3: Test manually**

Run:
```bash
echo '{}' | bash scripts/hooks/session-start.sh && cat /tmp/nexus-session-start
```
Expected: A unix timestamp like `1718300000`.

- [ ] **Step 4: Commit**

```bash
git add scripts/hooks/session-start.sh
git commit -m "feat: add SessionStart hook to record session start time"
```

---

### Task 3: Update statusline.sh — Adaptive Token Formatting + Token Cache + Session Duration

**Files:**
- Modify: `scripts/statusline.sh`

Three changes:
1. Replace the fixed `%.1fk` formatting with an adaptive `format_tokens` function
2. Read `/tmp/nexus-token-cache.json` and use `total_input` for accurate context fill when available
3. Read `/tmp/nexus-session-start` and display elapsed duration

- [ ] **Step 1: Add the `format_tokens` helper function**

Insert after the `RESET` / `SEP` definitions (after line 28), before the model section:

```bash
# -- Adaptive token formatter --------------------------------------------------
# <1000 → raw (e.g. "800"), 1k-99.9k → one decimal (e.g. "36.0k"),
# 100k+ → no decimal (e.g. "150k")
format_tokens() {
  local n="$1"
  if [ "$n" -lt 1000 ] 2>/dev/null; then
    echo "$n"
  elif [ "$n" -lt 100000 ] 2>/dev/null; then
    awk "BEGIN {printf \"%.1fk\", $n/1000}"
  else
    awk "BEGIN {printf \"%.0fk\", $n/1000}"
  fi
}
```

- [ ] **Step 2: Add session duration segment**

Insert after the wall clock time section (after line 145), before the final output section:

```bash
# -- Session duration -----------------------------------------------------------
session_duration=""
SESSION_START_FILE="/tmp/nexus-session-start"
if [ -f "$SESSION_START_FILE" ]; then
  session_start=$(cat "$SESSION_START_FILE" 2>/dev/null)
  if [ -n "$session_start" ]; then
    now=$(date +%s)
    elapsed=$(( now - session_start ))
    if [ "$elapsed" -ge 3600 ]; then
      hours=$(( elapsed / 3600 ))
      mins=$(( (elapsed % 3600) / 60 ))
      session_duration=$(printf "${TN_COMMENT}%dh%02dm${RESET}" "$hours" "$mins")
    elif [ "$elapsed" -ge 60 ]; then
      mins=$(( elapsed / 60 ))
      session_duration=$(printf "${TN_COMMENT}%dm${RESET}" "$mins")
    else
      session_duration=$(printf "${TN_COMMENT}<1m${RESET}" )
    fi
  fi
fi
```

- [ ] **Step 3: Replace context window section with token-cache-aware version**

Replace the entire context window section (lines 104-142) with:

```bash
# -- Context window with visual bar ------------------------------------------
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_window_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')

ctx_display="${TN_COMMENT}n/a${RESET}"

if [ -n "$used_pct" ]; then
  # Try to use hook-sourced accurate token data
  TOKEN_CACHE="/tmp/nexus-token-cache.json"
  hook_tokens=""
  if [ -f "$TOKEN_CACHE" ]; then
    cache_age=$(( $(date +%s) - $(stat -c %Y "$TOKEN_CACHE" 2>/dev/null || stat -f %m "$TOKEN_CACHE" 2>/dev/null || echo 0) ))
    if [ "$cache_age" -lt 60 ]; then
      hook_tokens=$(jq -r '.total_input // empty' "$TOKEN_CACHE" 2>/dev/null)
    fi
  fi

  if [ -n "$hook_tokens" ] && [ "$hook_tokens" != "null" ] && [ "$hook_tokens" -gt 0 ] 2>/dev/null; then
    display_tokens="$hook_tokens"
    used_int=$(awk "BEGIN {printf \"%.0f\", $hook_tokens * 100 / $ctx_window_size}")
  else
    used_int=$(printf "%.0f" "$used_pct")
    display_tokens=$(awk "BEGIN {printf \"%.0f\", $used_pct * $ctx_window_size / 100}")
  fi

  # Clamp percentage to 0-100
  [ "$used_int" -gt 100 ] 2>/dev/null && used_int=100
  [ "$used_int" -lt 0 ] 2>/dev/null && used_int=0

  if [ "$used_int" -ge 75 ]; then
    ctx_color="$TN_ROSE"
  elif [ "$used_int" -ge 50 ]; then
    ctx_color="$TN_GOLD"
  else
    ctx_color="$TN_BLUE"
  fi

  bar_filled=$(( used_int / 10 ))
  bar_empty=$(( 10 - bar_filled ))
  bar=""
  for (( i=0; i<bar_filled; i++ )); do bar="${bar}▓"; done
  if [ "$bar_filled" -lt 10 ]; then
    bar="${bar}▶"
    bar_empty=$(( bar_empty - 1 ))
  fi
  for (( i=0; i<bar_empty; i++ )); do bar="${bar}░"; done

  if [ -n "$display_tokens" ] && [ "$display_tokens" != "0" ]; then
    used_fmt=$(format_tokens "$display_tokens")
    limit_fmt=$(format_tokens "$ctx_window_size")
    ctx_display=$(printf "${ctx_color}[${bar}] ${TN_FG}%s${TN_SLATE}/${TN_FG}%s ${ctx_color}(%d%%)${RESET}" "$used_fmt" "$limit_fmt" "$used_int")
  else
    ctx_display=$(printf "${ctx_color}[${bar}] (%d%%)${RESET}" "$used_int")
  fi
fi
```

- [ ] **Step 4: Update the final output section to include session duration**

Replace the segments assembly (lines 147-164) with:

```bash
# -- Final output -------------------------------------------------------------
segments=()
segments+=("$(printf "${TN_COMMENT}%s${RESET}" "$current_time")")
[ -n "$session_duration" ] && segments+=("$session_duration")
segments+=("$(printf "${TN_LAVENDER}${BOLD}%s${RESET}" "$model")")
segments+=("$ctx_display")
[ -n "$cost_display" ]   && segments+=("$cost_display")
segments+=("$branch_display")
[ -n "$stash_display" ]  && segments+=("$stash_display")

result=""
for seg in "${segments[@]}"; do
  if [ -n "$result" ]; then
    result="${result}${SEP}${seg}"
  else
    result="$seg"
  fi
done
printf "%s\n" "$result"
```

- [ ] **Step 5: Test statusline.sh with mock data**

Run:
```bash
# Write a fake token cache
echo '{"total_input":87500,"output_tokens":1200,"timestamp":'$(date +%s)'}' > /tmp/nexus-token-cache.json
# Write a fake session start 47 minutes ago
echo $(( $(date +%s) - 2820 )) > /tmp/nexus-session-start
# Run with mock status line input
echo '{"model":{"model_id":"claude-opus-4-6"},"workspace":{"current_dir":"/tmp"},"context_window":{"used_percentage":40,"context_window_size":200000},"cost":{"total_cost_usd":1.23}}' | bash scripts/statusline.sh
```
Expected output should show: time | 47m | Opus 4.6 | [▓▓▓▓▶░░░░░] 87.5k/200k (44%) | cost | branch
Note: the percentage should be 44% (from hook: 87500/200000) not 40% (from used_percentage).

- [ ] **Step 6: Test adaptive formatting edge cases**

Run:
```bash
# Test low token count (<1k)
echo '{"total_input":800,"output_tokens":50,"timestamp":'$(date +%s)'}' > /tmp/nexus-token-cache.json
echo '{"model":{"model_id":"claude-sonnet-4-6"},"workspace":{"current_dir":"/tmp"},"context_window":{"used_percentage":1,"context_window_size":200000},"cost":{"total_cost_usd":0.01}}' | bash scripts/statusline.sh
# Should show "800/200k"

# Test high token count (100k+)
echo '{"total_input":156000,"output_tokens":3000,"timestamp":'$(date +%s)'}' > /tmp/nexus-token-cache.json
echo '{"model":{"model_id":"claude-opus-4-6"},"workspace":{"current_dir":"/tmp"},"context_window":{"used_percentage":78,"context_window_size":200000},"cost":{"total_cost_usd":5.50}}' | bash scripts/statusline.sh
# Should show "156k/200k"
```

- [ ] **Step 7: Commit**

```bash
git add scripts/statusline.sh
git commit -m "feat(statusline.sh): adaptive token formatting, hook-accurate context, session duration"
```

---

### Task 4: Update statusline.ps1 — Cursor Fix + Adaptive Formatting + Token Cache + Session Duration

**Files:**
- Modify: `scripts/statusline.ps1`

Four changes:
1. Fix the progress bar to include the `▶` crawling cursor (parity with bash)
2. Add adaptive `Format-Tokens` function
3. Read token cache for accurate context data
4. Add session duration display

- [ ] **Step 1: Add `Format-Tokens` helper function**

Insert after the `$SEP` definition (after line 31), before the model section:

```powershell
# -- Adaptive token formatter --------------------------------------------------
function Format-Tokens($n) {
    if ($n -lt 1000) { return "$n" }
    if ($n -lt 100000) { return "$([math]::Round($n / 1000, 1))k" }
    return "$([math]::Round($n / 1000))k"
}
```

- [ ] **Step 2: Fix the progress bar cursor**

Replace lines 105-107 (the bar building logic):

```powershell
    $bar_filled = [math]::Floor($used_int / 10)
    $bar_empty  = 10 - $bar_filled
    $bar        = ("▓" * $bar_filled) + ("░" * $bar_empty)
```

With:

```powershell
    $bar_filled = [math]::Floor($used_int / 10)
    $bar_empty  = 10 - $bar_filled
    $bar = ("▓" * $bar_filled)
    if ($bar_filled -lt 10) {
        $bar += "▶"
        $bar_empty -= 1
    }
    $bar += ("░" * [math]::Max(0, $bar_empty))
```

- [ ] **Step 3: Replace context window section with token-cache-aware version**

Replace lines 96-117 (the entire context window section) with:

```powershell
# -- Context window with visual bar -------------------------------------------
$used_pct        = $data.context_window.used_percentage
$ctx_window_size = if ($data.context_window.context_window_size) { $data.context_window.context_window_size } else { 200000 }

$ctx_display = "${TN_COMMENT}n/a${RESET}"

if ($null -ne $used_pct) {
    # Try hook-sourced accurate token data
    $token_cache = "$env:TEMP\nexus-token-cache.json"
    $hook_tokens = $null
    if (Test-Path $token_cache) {
        $cache_age = (Get-Date) - (Get-Item $token_cache).LastWriteTime
        if ($cache_age.TotalSeconds -lt 60) {
            try {
                $tc = Get-Content $token_cache -Raw | ConvertFrom-Json
                $hook_tokens = $tc.total_input
            } catch {}
        }
    }

    if ($hook_tokens -and $hook_tokens -gt 0) {
        $display_tokens = $hook_tokens
        $used_int = [math]::Round($hook_tokens * 100 / $ctx_window_size)
    } else {
        $used_int = [math]::Round($used_pct)
        $display_tokens = [math]::Round($used_pct * $ctx_window_size / 100)
    }

    $used_int = [math]::Max(0, [math]::Min(100, $used_int))
    $ctx_color = if ($used_int -ge 75) { $TN_ROSE } elseif ($used_int -ge 50) { $TN_GOLD } else { $TN_BLUE }

    $bar_filled = [math]::Floor($used_int / 10)
    $bar_empty  = 10 - $bar_filled
    $bar = ("▓" * $bar_filled)
    if ($bar_filled -lt 10) {
        $bar += "▶"
        $bar_empty -= 1
    }
    $bar += ("░" * [math]::Max(0, $bar_empty))

    if ($display_tokens -gt 0) {
        $used_fmt  = Format-Tokens $display_tokens
        $limit_fmt = Format-Tokens $ctx_window_size
        $ctx_display = "${ctx_color}[${bar}] ${TN_FG}${used_fmt}${TN_SLATE}/${TN_FG}${limit_fmt} ${ctx_color}(${used_int}%)${RESET}"
    } else {
        $ctx_display = "${ctx_color}[${bar}] (${used_int}%)${RESET}"
    }
}
```

- [ ] **Step 4: Add session duration segment**

Insert before the final assembly section (before line 120):

```powershell
# -- Session duration -----------------------------------------------------------
$session_duration = ""
$session_start_file = "$env:TEMP\nexus-session-start.txt"
if (Test-Path $session_start_file) {
    try {
        $session_start = [int64](Get-Content $session_start_file -Raw).Trim()
        $now = [int64](Get-Date -UFormat %s)
        $elapsed = $now - $session_start
        if ($elapsed -ge 3600) {
            $hours = [math]::Floor($elapsed / 3600)
            $mins  = [math]::Floor(($elapsed % 3600) / 60)
            $session_duration = "${TN_COMMENT}${hours}h$($mins.ToString('D2'))m${RESET}"
        } elseif ($elapsed -ge 60) {
            $mins = [math]::Floor($elapsed / 60)
            $session_duration = "${TN_COMMENT}${mins}m${RESET}"
        } else {
            $session_duration = "${TN_COMMENT}<1m${RESET}"
        }
    } catch {}
}
```

- [ ] **Step 5: Update segments assembly to include session duration**

Replace line 123 (the `$segments = @(...)` line) with:

```powershell
$segments = @("${TN_COMMENT}${current_time}${RESET}")
if ($session_duration) { $segments += $session_duration }
$segments += @("${TN_LAVENDER}${BOLD}${model}${RESET}", $ctx_display)
```

- [ ] **Step 6: Commit**

```bash
git add scripts/statusline.ps1
git commit -m "feat(statusline.ps1): cursor fix, adaptive formatting, hook-accurate context, session duration"
```

---

### Task 5: Update setup.sh to Register Hooks

**Files:**
- Modify: `scripts/setup.sh`

Add a section that registers the `Stop` and `SessionStart` hooks in `~/.claude/settings.json`, appending to existing hook arrays if they exist.

- [ ] **Step 1: Add hook registration to setup.sh**

Insert after the marketplace registration block (after line 91), before the final echo:

```python
# -- Register hooks in settings.json ------------------------------------------
python3 - "$SETTINGS" "$PLUGIN_ROOT" <<'HOOKEOF'
import json, sys

settings_path, plugin_root = sys.argv[1], sys.argv[2]

with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.setdefault('hooks', {})

# Helper: append a nexus hook entry to an event, avoiding duplicates
def add_hook(event_name, command):
    event_hooks = hooks.setdefault(event_name, [])
    # Check if nexus hook already exists in any matcher group
    for group in event_hooks:
        for h in group.get('hooks', []):
            if 'nexus' in h.get('command', ''):
                return  # Already registered
    # Append to first matcher group if one exists, otherwise create one
    nexus_hook = {'type': 'command', 'command': command, 'timeout': 3000}
    if event_hooks:
        event_hooks[0]['hooks'].append(nexus_hook)
    else:
        event_hooks.append({'matcher': '', 'hooks': [nexus_hook]})

add_hook('Stop', f'bash {plugin_root}/scripts/hooks/stop.sh')
add_hook('SessionStart', f'bash {plugin_root}/scripts/hooks/session-start.sh')

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print('OK: Hooks registered (Stop, SessionStart)')
HOOKEOF
```

- [ ] **Step 2: Test setup.sh hook registration**

Run:
```bash
# Backup settings
cp ~/.claude/settings.json ~/.claude/settings.json.bak
# Run setup
bash scripts/setup.sh
# Verify hooks were added
cat ~/.claude/settings.json | jq '.hooks.Stop, .hooks.SessionStart'
# Restore backup
cp ~/.claude/settings.json.bak ~/.claude/settings.json
```

Expected: Both `Stop` and `SessionStart` arrays should contain nexus hook entries.

- [ ] **Step 3: Commit**

```bash
git add scripts/setup.sh
git commit -m "feat(setup): register Stop and SessionStart hooks for accurate token tracking"
```

---

### Task 6: Update uninstall.sh to Clean Up Hooks and Cache Files

**Files:**
- Modify: `scripts/uninstall.sh`

Remove nexus hook entries from settings.json and clean up cache files.

- [ ] **Step 1: Read current uninstall.sh**

Read `scripts/uninstall.sh` to understand its current structure before modifying.

- [ ] **Step 2: Add hook cleanup and cache file cleanup**

Add after the existing settings cleanup section:

```python
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
```

Add cache file cleanup:

```bash
# -- Clean up cache files ------------------------------------------------------
rm -f /tmp/nexus-token-cache.json /tmp/nexus-session-start /tmp/nexus-git-cache
echo "OK: Cache files cleaned"
```

- [ ] **Step 3: Commit**

```bash
git add scripts/uninstall.sh
git commit -m "feat(uninstall): clean up nexus hooks and cache files"
```

---

### Task 7: Update README.md

**Files:**
- Modify: `README.md`

Update the example output and add a brief features section.

- [ ] **Step 1: Update the example output line**

Replace the existing example:
```
22:13 | Sonnet 4.6 | [▓▶░░░░░░░░] 36.0k/200k (18%) | 💰 $0.41 | ⎇ main | ⎇ 2 stashed
```

With:
```
22:13 | 47m | Sonnet 4.6 | [▓▓▓▓▶░░░░░] 87.5k/200k (44%) | 💰 $0.41 | ⎇ main | ⎇ 2 stashed
```

- [ ] **Step 2: Add features section after the description**

Insert after line 3 (before the code block):

```markdown
**Features:**
- Accurate context tracking via hooks (parses real token counts from Claude transcripts)
- Adaptive token formatting (800 / 36.0k / 150k depending on magnitude)
- Session duration timer
- Session cost with color-coded thresholds
- Git branch and stash count
- Tokyo Night 256-color theme
- Cross-platform (bash + PowerShell)
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: update README with new features and example output"
```
