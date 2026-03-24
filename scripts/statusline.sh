#!/bin/bash

# =============================================================================
# nexus — Claude Code Status Bar
# https://github.com/raygoel/nexus
#
# Shows: Time | Model | Context Usage | Cost | Git Branch | Stash Count
#
# Color Palette: Tokyo Night (256-color ANSI)
# =============================================================================

# -- Tokyo Night 256-color palette ------------------------------------------
TN_COMMENT=$'\033[38;5;60m'     # Muted slate-blue for subdued elements
TN_SLATE=$'\033[38;5;59m'       # Dark slate for separators
TN_LAVENDER=$'\033[38;5;141m'   # Soft purple for model name
TN_BLUE=$'\033[38;5;111m'       # Calm blue for context bar (normal)
TN_GOLD=$'\033[38;5;179m'       # Warm amber for context bar (warning)
TN_ROSE=$'\033[38;5;204m'       # Soft rose for context bar (critical)
TN_GREEN=$'\033[38;5;149m'      # Sage green for branch name
TN_TEAL=$'\033[38;5;115m'       # Teal accent for branch icon
TN_FG=$'\033[38;5;146m'         # Muted foreground for token counts

BOLD=$'\033[1m'
DIM=$'\033[2m'
RESET=$'\033[0m'

# Separator: dim slate pipe
SEP="${TN_SLATE}${DIM} | ${RESET}"

input=$(cat)

# -- Model name ---------------------------------------------------------------
raw_model=$(echo "$input" | jq -r '
  .model.model_id // .model.display_name // "Unknown"
')

model=$(echo "$raw_model" \
  | sed 's|^[^/]*/||'                                          \
  | sed 's/^[Cc]laude[ -]//'                                   \
  | sed 's/ (.*$//'                                            \
  | sed 's/-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$//'     \
  | sed 's/-\([0-9]\)/ \1/g'                                   \
  | sed 's/\([0-9]\) \([0-9]\)/\1.\2/'                        \
  | awk '{print toupper(substr($0,1,1)) substr($0,2)}'
)

# -- Git branch (with 5-second cache) ----------------------------------------
cwd=$(echo "$input" | jq -r '.workspace.current_dir // "."')
git_branch="no-git"

CACHE_FILE="/tmp/nexus-git-cache"
CACHE_MAX_AGE=5

cache_is_stale() {
    [ ! -f "$CACHE_FILE" ] || \
    [ $(($(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0))) -gt $CACHE_MAX_AGE ]
}

if cd "$cwd" 2>/dev/null; then
  if cache_is_stale; then
    branch=$(git --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
      git_branch="$branch"
      echo "$git_branch" > "$CACHE_FILE"
    fi
  else
    git_branch=$(cat "$CACHE_FILE" 2>/dev/null || echo "no-git")
  fi
fi

branch_display=$(printf "${TN_TEAL}⎇ ${TN_GREEN}${BOLD}%s${RESET}" "$git_branch")

# -- Session cost -------------------------------------------------------------
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')

cost_display=""
if [ -n "$cost_usd" ] && [ "$(echo "$cost_usd > 0" | bc -l 2>/dev/null)" = "1" ]; then
  cost_int=$(echo "$cost_usd" | awk '{printf "%.0f", $1}')
  if [ "$cost_int" -ge 250 ]; then
    cost_color="$TN_ROSE"
  elif [ "$cost_int" -ge 100 ]; then
    cost_color="$TN_GOLD"
  else
    cost_color="$TN_GREEN"
  fi
  cost_display=$(printf "${cost_color}💰 \$%.2f${RESET}" "$cost_usd")
fi

# -- Stash count --------------------------------------------------------------
stash_count=0
if [ "$git_branch" != "no-git" ]; then
  stash_count=$(git --no-optional-locks stash list 2>/dev/null | wc -l | tr -d ' ')
fi

stash_display=""
if [ -n "$stash_count" ] && [ "$stash_count" -gt 0 ]; then
  stash_display=$(printf "${TN_GOLD}⎇ %s stashed${RESET}" "$stash_count")
fi

# -- Context window with visual bar ------------------------------------------
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_window_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')

ctx_display="${TN_COMMENT}n/a${RESET}"

if [ -n "$used_pct" ]; then
  used_int=$(printf "%.0f" "$used_pct")

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
  for (( i=0; i<bar_empty; i++ )); do bar="${bar}░"; done

  display_tokens=$(awk "BEGIN {printf \"%.0f\", $used_pct * $ctx_window_size / 100}")

  if [ -n "$display_tokens" ] && [ "$display_tokens" != "0" ]; then
    used_k=$(echo "$display_tokens" | awk '{printf "%.1fk", $1/1000}')
    limit_k=$(echo "$ctx_window_size" | awk '{printf "%.0fk", $1/1000}')
    ctx_display=$(printf "${ctx_color}[${bar}] ${TN_FG}%s${TN_SLATE}/${TN_FG}%s ${ctx_color}(%d%%)${RESET}" "$used_k" "$limit_k" "$used_int")
  else
    ctx_display=$(printf "${ctx_color}[${bar}] (%d%%)${RESET}" "$used_int")
  fi
fi

# -- Wall clock time ----------------------------------------------------------
current_time=$(date +"%H:%M")

# -- Final output -------------------------------------------------------------
segments=()
segments+=("$(printf "${TN_COMMENT}%s${RESET}" "$current_time")")
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
