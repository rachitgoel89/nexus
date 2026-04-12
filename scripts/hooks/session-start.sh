#!/bin/bash
# nexus SessionStart hook — records session start time per session
# Writes /tmp/nexus-session-start-{session_id} for the statusline to read.
# Also writes /tmp/nexus-sid-{cwd_hash} as a per-workspace session pointer.
# No stdout. Always exits 0.

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)
cwd=$(echo "$input" | jq -r '.cwd // empty' 2>/dev/null)

if [ -z "$session_id" ]; then
  exit 0
fi

# Write session start timestamp
TIMESTAMP_FILE="/tmp/nexus-session-start-${session_id}"
tmp="${TIMESTAMP_FILE}.tmp.$$"
date +%s > "$tmp"
mv "$tmp" "$TIMESTAMP_FILE"
chmod 600 "$TIMESTAMP_FILE" 2>/dev/null

# Write per-cwd session pointer
if [ -n "$cwd" ]; then
  cwd_hash=$(python3 -c "import hashlib, sys; print(hashlib.md5(sys.argv[1].encode()).hexdigest()[:8])" "$cwd" 2>/dev/null)
  if [ -n "$cwd_hash" ]; then
    echo "$session_id" > "/tmp/nexus-sid-${cwd_hash}"
    chmod 600 "/tmp/nexus-sid-${cwd_hash}" 2>/dev/null
  fi
fi

exit 0
