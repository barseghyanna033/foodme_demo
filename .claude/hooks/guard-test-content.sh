#!/bin/sh
# PreToolUse hook for Write and Edit: rejects test code that hides failures or is
# known to be flaky, before it reaches the file. It covers apps/web and apps/admin
# *.spec.ts files under e2e/, and Java files under apps/backend/src/test/java.
#
# Existing tests already use some of these patterns, such as @Order in
# OrderControllerTest.java and waitForTimeout in flake-dish-modal.spec.ts, so it
# rejects only a change that adds more of a pattern than it removes. It reads text
# only and does not run tests. Exit 2 blocks the tool call and sends the reason to
# Claude.

input=$(cat)

# Same parsing approach as log-file-changes.sh: prints the first string value for
# a JSON key, still JSON-escaped.
json_string() {
  printf '%s' "$input" \
    | LC_ALL=C grep -aoE '"'"$1"'"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' \
    | head -n 1 \
    | sed -E 's/^"[^"]*"[[:space:]]*:[[:space:]]*"//; s/"$//'
}

has_string_key() {
  printf '%s' "$input" | LC_ALL=C grep -aqE '"'"$1"'"[[:space:]]*:[[:space:]]*"'
}

block() {
  printf 'Blocked by guard-test-content.sh: %s\nFix the test instead of working around this check.\n' "$1" >&2
  exit 2
}

# Forward slashes, single separators, no trailing slash, and C:/ style drives.
normalize_path() {
  printf '%s' "$1" | tr '\\' '/' | tr -s '/' | sed -E 's#/$##; s#^/([a-zA-Z])/#\1:/#'
}

# Drive and folder case can differ between the tool input and the project path.
comparable_path() {
  printf '%s' "$1" | LC_ALL=C tr 'A-Z' 'a-z'
}

# Replaces escaped line breaks and tabs, so that a pattern right after one still
# has a word boundary in front of it.
flatten_escapes() {
  printf '%s' "$1" | LC_ALL=C sed -E 's/\\[nrt]/ /g'
}

count_matches() {
  printf '%s\n' "$1" | LC_ALL=C grep -oE -e "$2" | wc -l | tr -d ' '
}

tool=$(json_string tool_name)
case "$tool" in
  Write | Edit) ;;
  *) exit 0 ;;
esac

raw_file=$(json_string file_path)
[ -n "$raw_file" ] || exit 0

file=$(normalize_path "$raw_file")
project=$(normalize_path "${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd)}")
[ -n "$project" ] || exit 0

case "$(comparable_path "$file")" in
  "$(comparable_path "$project")"/*) ;;
  *) exit 0 ;;
esac
project_bytes=$(printf '%s' "$project" | LC_ALL=C wc -c | tr -d ' ')
rel=$(printf '%s' "$file" | LC_ALL=C cut -c"$((project_bytes + 2))"-)

boundary='(^|[^A-Za-z0-9_])'
case "$rel" in
  */../*) exit 0 ;;
  apps/web/e2e/*.spec.ts | apps/admin/e2e/*.spec.ts)
    kind=spec
    patterns="${boundary}test\\.only
${boundary}test\\.skip
${boundary}test\\.fixme
${boundary}describe\\.only
${boundary}describe\\.skip
${boundary}describe\\.fixme
${boundary}waitForTimeout
${boundary}expect\\(true\\)\\.toBe\\(true\\)"
    ;;
  apps/backend/src/test/java/*.java)
    kind=java
    patterns="@Disabled([^A-Za-z]|\$)
${boundary}Thread\\.sleep
@Order\\(
${boundary}assertTrue\\(true\\)"
    ;;
  *) exit 0 ;;
esac

# Work out the text before and after this change.
if [ "$tool" = Write ]; then
  has_string_key content || block "the new file content could not be read"
  after=$(flatten_escapes "$(json_string content)")
  if [ -f "$file" ]; then
    is_new_file=0
    before=$(cat "$file")
  else
    is_new_file=1
    before=""
  fi
else
  has_string_key old_string && has_string_key new_string || block "the edit could not be read"
  is_new_file=0
  before=$(flatten_escapes "$(json_string old_string)")
  after=$(flatten_escapes "$(json_string new_string)")
fi

set -f
old_ifs=$IFS
IFS='
'
for pattern in $patterns; do
  added=$(count_matches "$after" "$pattern")
  existing=$(count_matches "$before" "$pattern")
  if [ "$added" -gt "$existing" ]; then
    label=${pattern#"$boundary"}
    label=$(printf '%s' "$label" | sed -E 's/\\//g; s/\(\[\^A-Za-z\]\|\$\)$//')
    block "this change adds $label to $rel. It can hide a failure or make the test flaky."
  fi
done
IFS=$old_ifs

if [ "$is_new_file" -eq 1 ]; then
  name=${rel##*/}
  if [ "$kind" = spec ]; then
    case "$name" in
      flake-*) block "new test files must not use the flake- prefix: $rel" ;;
    esac
    [ "$(count_matches "$after" 'expect\(')" -gt 0 ] || block "the new test file has no assertion: $rel"
  else
    case "$name" in
      *Test.java)
        [ "$(count_matches "$after" 'assert|andExpect|verify\(')" -gt 0 ] || block "the new test class has no assertion: $rel"
        ;;
    esac
  fi
fi

exit 0
