#!/bin/bash
# nexus SessionStart hook — records session start time
# Writes to /tmp/nexus-session-start for the statusline to read.
# No stdout. Always exits 0.

cat > /dev/null  # drain stdin from Claude Code hook runner

TIMESTAMP_FILE="/tmp/nexus-session-start"

tmp="${TIMESTAMP_FILE}.tmp.$$"
date +%s > "$tmp"
mv "$tmp" "$TIMESTAMP_FILE"
chmod 600 "$TIMESTAMP_FILE" 2>/dev/null

exit 0
