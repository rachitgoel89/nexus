#!/bin/bash
# nexus Stop hook — extracts real token counts from transcript JSONL
# Writes to /tmp/nexus-token-{session_id}.json for the statusline to read.
# Also writes /tmp/nexus-sid-{cwd_hash} as a per-workspace session pointer.
# Runs after every Claude response. Must exit 0 always. No stdout.

input=$(cat)

transcript=$(echo "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)
cwd=$(echo "$input" | jq -r '.cwd // empty' 2>/dev/null)

cwd_hash=""
if [ -n "$cwd" ]; then
  cwd_hash=$(python3 -c "import hashlib, sys; print(hashlib.md5(sys.argv[1].encode()).hexdigest()[:8])" "$cwd" 2>/dev/null)
fi

if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then
  exit 0
fi

CACHE="/tmp/nexus-token-${session_id}.json"

# Find the last assistant message with usage data (search from end)
usage_json=$(tail -200 "$transcript" \
  | jq -c 'select(.type == "assistant") | .message.usage // empty' 2>/dev/null \
  | tail -1)

if [ -z "$usage_json" ]; then
  exit 0
fi

# Extract token fields
input_tokens=$(echo "$usage_json" | jq -r '(.input_tokens // 0) | floor')
cache_creation=$(echo "$usage_json" | jq -r '(.cache_creation_input_tokens // 0) | floor')
cache_read=$(echo "$usage_json" | jq -r '(.cache_read_input_tokens // 0) | floor')
output_tokens=$(echo "$usage_json" | jq -r '(.output_tokens // 0) | floor')

# Total input = all input token types (this is the actual context window fill)
total_input=$(( input_tokens + cache_creation + cache_read ))

# Write cache atomically
tmp_cache="${CACHE}.tmp.$$"
jq -n \
  --argjson ti "$total_input" \
  --argjson ot "$output_tokens" \
  --argjson it "$input_tokens" \
  --argjson cc "$cache_creation" \
  --argjson cr "$cache_read" \
  --arg sid "$session_id" \
  --argjson ts "$(date +%s)" \
  '{total_input:$ti, output_tokens:$ot, input_tokens:$it, cache_creation:$cc, cache_read:$cr, session_id:$sid, timestamp:$ts}' \
  > "$tmp_cache"

# Write per-cwd session pointer so statusline can find the right cache
if [ -n "$cwd_hash" ]; then
  echo "$session_id" > "/tmp/nexus-sid-${cwd_hash}"
  chmod 600 "/tmp/nexus-sid-${cwd_hash}" 2>/dev/null
fi

mv "$tmp_cache" "$CACHE"
chmod 600 "$CACHE" 2>/dev/null

exit 0
