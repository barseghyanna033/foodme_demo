#!/bin/sh
# PostToolUse hook: after a successful Write or Edit of a file under
# apps/{web,admin,backend}/src/, runs or recommends a scoped validation command
# and reports the result to Claude through additionalContext.
#
#   web      .ts/.tsx   runs   npm run lint -- <file>
#   admin    .js/.jsx   runs   npm run lint   (the script is `eslint .`, so it
#                              always lints the whole app)
#   backend  .java      only recommends a Gradle command; Gradle is never run
#                       here because the build needs a JDK 17 toolchain
#
# It never installs anything, and never runs a full test suite, E2E tests or a
# build. Those are listed as manual follow-ups. Written in plain POSIX sh, like
# log-file-changes.sh. Always exits 0: the edit has already happened, so a
# failed check is reported rather than treated as a hook error.

lint_timeout_seconds=170
max_output_lines=40
max_output_bytes=4000

input=$(cat)

# Same parsing approach as log-file-changes.sh: prints the first string value
# for a JSON key, still JSON-escaped.
json_string() {
  printf '%s' "$input" \
    | LC_ALL=C grep -aoE '"'"$1"'"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' \
    | head -n 1 \
    | sed -E 's/^"[^"]*"[[:space:]]*:[[:space:]]*"//; s/"$//'
}

is_windows() {
  case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}

# Forward slashes, single separators, no trailing slash, and on Windows a
# C:/ style drive so C:\x, C:\\x and /c/x all compare equal.
normalize_path() {
  normalized=$(printf '%s' "$1" | tr '\\' '/' | tr -s '/' | sed 's#/$##')
  if is_windows; then
    normalized=$(printf '%s' "$normalized" | sed -E 's#^/([a-zA-Z])/#\1:/#')
  fi
  printf '%s' "$normalized"
}

# Windows paths are case-insensitive, so drive and folder case may differ
# between the tool input and CLAUDE_PROJECT_DIR.
comparable_path() {
  if is_windows; then
    printf '%s' "$1" | LC_ALL=C tr 'A-Z' 'a-z'
  else
    printf '%s' "$1"
  fi
}

# Prints the hook's JSON result. additionalContext is what reaches Claude.
emit_report() {
  escaped=$(printf '%s' "$1" \
    | LC_ALL=C sed "s/$(printf '\033')\[[0-9;]*[A-Za-z]//g" \
    | LC_ALL=C tr '\t' ' ' \
    | LC_ALL=C tr -d '\000-\010\013-\037' \
    | LC_ALL=C sed 's/\\/\\\\/g; s/"/\\"/g' \
    | LC_ALL=C awk 'NR > 1 { printf "\\n" } { printf "%s", $0 }')
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$escaped"
}

# Runs the arguments with a time limit, so a slow check is reported instead of
# the hook being killed silently. Windows has its own unrelated timeout.exe, so
# only GNU timeout is used.
run_limited() {
  if timeout --version 2>/dev/null | grep -q coreutils; then
    timeout "$lint_timeout_seconds" "$@"
  else
    "$@"
  fi
}

# --- Decide whether this event applies ------------------------------------

case "$(json_string tool_name)" in
  Write | Edit) ;;
  *) exit 0 ;;
esac

raw_file=$(json_string file_path)
[ -n "$raw_file" ] || exit 0

if [ -n "$CLAUDE_PROJECT_DIR" ]; then
  raw_project=$CLAUDE_PROJECT_DIR
else
  raw_project=$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd)
fi
[ -n "$raw_project" ] || exit 0

file=$(normalize_path "$raw_file")
project=$(normalize_path "$raw_project")

case "$(comparable_path "$file")" in
  "$(comparable_path "$project")"/*) ;;
  *) exit 0 ;;
esac

# Cut by byte count to keep the file's original case, whatever case the
# project prefix was written in.
project_bytes=$(printf '%s' "$project" | LC_ALL=C wc -c | tr -d ' ')
rel=$(printf '%s' "$file" | LC_ALL=C cut -c"$((project_bytes + 2))"-)

case "$rel" in
  */../* | */node_modules/*) exit 0 ;;
esac

case "$rel" in
  apps/web/src/*) app=web ;;
  apps/admin/src/*) app=admin ;;
  apps/backend/src/*) app=backend ;;
  *) exit 0 ;;
esac

app_dir="$project/apps/$app"
app_rel=${rel#apps/"$app"/}
header="FoodMe validation for $rel:"

no_validator() {
  emit_report "$header
No scoped validation command applies to this file type, so nothing was run.
Manual follow-up if needed: $1"
  exit 0
}

# --- Backend: report only --------------------------------------------------

if [ "$app" = backend ]; then
  if is_windows; then gradle_cmd=gradlew.bat; else gradle_cmd=./gradlew; fi
  full_suite="$gradle_cmd test (in apps/backend)"

  case "$rel" in
    *.java) ;;
    *) no_validator "$full_suite" ;;
  esac

  if [ ! -f "$app_dir/gradlew" ] || [ ! -f "$app_dir/build.gradle" ]; then
    emit_report "$header
Nothing was run. No validation command is available: gradlew or build.gradle is missing from apps/backend."
    exit 0
  fi

  java_name=$(basename "$rel" .java)
  test_root="$app_dir/src/test/java"

  case "$rel" in
    apps/backend/src/test/java/*Test.java)
      test_file="$file"
      ;;
    apps/backend/src/test/java/*)
      test_file=""
      fallback=compileTestJava
      ;;
    *)
      test_file=$(find "$test_root" -type f -name "${java_name}Test.java" 2>/dev/null | head -n 1)
      fallback=compileJava
      ;;
  esac

  if [ -n "$test_file" ]; then
    test_class=$(normalize_path "$test_file" | sed -E 's#^.*/src/test/java/##; s#\.java$##' | tr '/' '.')
    recommended="$gradle_cmd test --tests \"$test_class\""
    note="This runs only the test class matching this file."
  else
    recommended="$gradle_cmd $fallback"
    note="No matching test class was found for this file, so only a compile check is recommended."
  fi

  emit_report "$header
Gradle was not run: this hook does not run Gradle automatically because the backend build requires a JDK 17 toolchain.
Recommended command (in apps/backend): $recommended
$note"
  exit 0
fi

# --- Frontend: run lint ----------------------------------------------------

if [ "$app" = web ]; then
  lint_tool=oxlint
  follow_up="npm run build (type-checks with tsc -b), plus npm run test:e2e for user-facing changes (needs the backend and database running)"
  case "$rel" in
    *.ts | *.tsx) ;;
    *) no_validator "$follow_up" ;;
  esac
else
  lint_tool=eslint
  follow_up="npm run build, plus npm run test:e2e for user-facing changes (needs the backend and database running)"
  case "$rel" in
    *.js | *.jsx) ;;
    *) no_validator "$follow_up" ;;
  esac
fi

missing=""
add_missing() {
  missing="$missing
- $1"
}

command -v npm >/dev/null 2>&1 || add_missing "npm is not on PATH (install Node.js)"
if ! grep -q '"lint"[[:space:]]*:' "$app_dir/package.json" 2>/dev/null; then
  add_missing "apps/$app/package.json defines no lint script"
fi
if [ ! -d "$app_dir/node_modules" ]; then
  add_missing "apps/$app/node_modules is missing (run npm ci in apps/$app)"
elif [ ! -e "$app_dir/node_modules/.bin/$lint_tool" ]; then
  add_missing "$lint_tool is not installed in apps/$app/node_modules (run npm ci in apps/$app)"
fi

if [ -n "$missing" ]; then
  emit_report "$header
Lint was not run. Missing prerequisites:$missing
Nothing was installed automatically."
  exit 0
fi

if [ ! -f "$file" ]; then
  emit_report "$header
Lint was not run: the file no longer exists."
  exit 0
fi

export NO_COLOR=1
if [ "$app" = web ]; then
  command_text="npm run lint -- $app_rel"
  output=$(cd "$app_dir" && run_limited npm run lint -- "$app_rel" 2>&1)
  status=$?
  scope="this file"
else
  command_text="npm run lint"
  output=$(cd "$app_dir" && run_limited npm run lint 2>&1)
  status=$?
  scope="all of apps/admin, so a failure may come from another file"
fi

case "$status" in
  0) result="PASSED" ;;
  124) result="TIMED OUT after ${lint_timeout_seconds}s" ;;
  *) result="FAILED (exit $status)" ;;
esac

tail_output=$(printf '%s\n' "$output" | tail -n "$max_output_lines" | tail -c "$max_output_bytes")

emit_report "$header
Command (in apps/$app): $command_text
Scope: $scope
Result: $result
Output (last $max_output_lines lines at most):
$tail_output
Not run automatically: $follow_up"
exit 0
