#!/bin/sh
# PostToolUse hook: appends one JSON line per successful Write or Edit call to
# tool-usage.log, next to this script. Claude Code only fires PostToolUse after
# a tool succeeds, so failed calls never reach this script.
#
# Written in plain POSIX sh so it needs no Node, Python or jq. It logs metadata
# only, never file contents, and always exits 0 so logging can't disturb a session.

log_file="$(dirname "$0")/tool-usage.log"
input=$(cat)

# Prints the first string value for a JSON key, still JSON-escaped. A key inside
# a string value has an escaped closing quote (\"key\"), so it can't match here.
# Keeping the value escaped lets it go straight into the JSON log line below.
json_string() {
  printf '%s' "$input" \
    | LC_ALL=C grep -aoE '"'"$1"'"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' \
    | head -n 1 \
    | sed -E 's/^"[^"]*"[[:space:]]*:[[:space:]]*"//; s/"$//'
}

tool=$(json_string tool_name)
file=$(json_string file_path)

if [ -n "$tool" ]; then
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  { printf '{"ts":"%s","tool":"%s","file":"%s"}\n' "$timestamp" "$tool" "$file" >> "$log_file"; } 2>/dev/null
fi

exit 0
