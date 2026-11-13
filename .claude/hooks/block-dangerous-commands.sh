#!/bin/sh
# PreToolUse hook for Bash and PowerShell: blocks pushes to main, forced or broad
# pushes, recursive forced deletes, and git commands that discard work.
#
# It only reads the command text and never runs it. The only commands it runs
# itself are read-only git lookups of the current branch. Exit 2 blocks the tool
# call and sends the reason to Claude. Any other non-zero exit would let the call
# through, so unreadable input is blocked deliberately.
#
# This is a guardrail, not a security boundary: variables, eval and encoded
# commands can get past text matching. Branch protection on GitHub is what
# actually protects main. Harmless text that contains a blocked command, such as
# grep "rm -rf", is blocked too, because that is the safer way to be wrong.

input=$(cat)

# Same parsing approach as log-file-changes.sh: prints the first string value for
# a JSON key, still JSON-escaped.
json_string() {
  printf '%s' "$input" \
    | LC_ALL=C grep -aoE '"'"$1"'"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' \
    | head -n 1 \
    | sed -E 's/^"[^"]*"[[:space:]]*:[[:space:]]*"//; s/"$//'
}

block() {
  printf 'Blocked by block-dangerous-commands.sh: %s\nDo not retry this another way. If it is really needed, ask the user to run it themselves.\n' "$1" >&2
  exit 2
}

lowercase() {
  printf '%s' "$1" | tr 'A-Z' 'a-z'
}

tool=$(json_string tool_name)
case "$tool" in
  Bash | PowerShell) ;;
  "") block "the hook input could not be read" ;;
  *) exit 0 ;;
esac

raw_command=$(json_string command)
[ -n "$raw_command" ] || block "the command could not be read"

working_dir=$(json_string cwd | tr '\\' '/' | tr -s '/')
[ -n "$working_dir" ] || working_dir=${CLAUDE_PROJECT_DIR:-.}

# Set when an earlier part of the command changes directory or branch, because
# the current branch can then no longer be trusted for a plain `git push`.
context_changed=0

check_current_branch() {
  [ "$context_changed" -eq 0 ] \
    || block "a git push with no explicit branch follows a directory or branch change, so the target cannot be confirmed"

  branch_dir=${1:-$working_dir}
  branch=$(git -C "$branch_dir" symbolic-ref --short -q HEAD 2>/dev/null)
  [ -n "$branch" ] || block "a git push with no explicit branch, and the current branch could not be determined"
  [ "$(lowercase "$branch")" != main ] || block "a git push from the main branch"

  # Read from config because @{u} fails when no remote-tracking ref exists yet.
  upstream=$(git -C "$branch_dir" config --get "branch.$branch.merge" 2>/dev/null)
  case "$(lowercase "$upstream")" in
    main | refs/heads/main) block "a git push whose upstream is main" ;;
  esac
}

check_remote() {
  case "$1" in
    *'$'* | *'*'* | *%*) block "a git push whose target cannot be confirmed from the command text" ;;
  esac
  [ "$(lowercase "$1")" != main ] || block "a git push to main"
}

check_refspec() {
  refspec=$(lowercase "$1")
  case "$refspec" in
    +*) block "a forced git push" ;;
    :) block "a git push of all matching branches" ;;
    *'$'* | *'*'* | *%*) block "a git push whose target cannot be confirmed from the command text" ;;
  esac

  destination=${refspec##*:}
  case "$destination" in
    main | heads/main | refs/heads/main) block "a git push to main" ;;
    head | @ | "") check_current_branch "$2" ;;
  esac
}

check_push() {
  push_dir=$1
  shift
  positional=0
  skip_next=0

  for argument in "$@"; do
    if [ "$skip_next" -eq 1 ]; then
      skip_next=0
      continue
    fi

    case "$argument" in
      [0-9]'>'* | '>'* | '<'*) continue ;;
    esac
    argument=${argument%%[<>]*}
    [ -n "$argument" ] || continue

    case "$argument" in
      --) ;;
      --all | --branches | --mirror) block "a git push of every branch" ;;
      --force | --force=* | --force-with-lease | --force-with-lease=* | --force-if-includes) block "a forced git push" ;;
      -o | --push-option | --receive-pack | --exec | --repo) skip_next=1 ;;
      --*) ;;
      -*f*) block "a forced git push" ;;
      -*) ;;
      *)
        positional=$((positional + 1))
        if [ "$positional" -eq 1 ]; then
          check_remote "$argument"
        else
          check_refspec "$argument" "$push_dir"
        fi
        ;;
    esac
  done

  # With no refspec, git pushes the current branch.
  if [ "$positional" -lt 2 ]; then
    check_current_branch "$push_dir"
  fi
}

check_git() {
  git_dir=""
  while [ $# -gt 0 ]; do
    case "$1" in
      -C)
        git_dir=${2:-}
        [ $# -ge 2 ] && shift 2 || shift
        ;;
      -c | --git-dir | --work-tree | --namespace | --exec-path | --super-prefix | --config-env)
        [ $# -ge 2 ] && shift 2 || shift
        ;;
      -*) shift ;;
      *) break ;;
    esac
  done
  [ $# -gt 0 ] || return 0

  subcommand=$1
  shift
  case "$subcommand" in
    push) check_push "$git_dir" "$@" ;;
    checkout | switch) context_changed=1 ;;
    reset)
      for argument in "$@"; do
        [ "$argument" != --hard ] || block "git reset --hard, which discards work"
      done
      ;;
    clean)
      for argument in "$@"; do
        case "$argument" in
          --force | --force=*) block "a forced git clean, which deletes files" ;;
          --*) ;;
          -*f*) block "a forced git clean, which deletes files" ;;
        esac
      done
      ;;
  esac
}

check_delete() {
  recursive=0
  force=0
  for argument in "$@"; do
    case "$argument" in
      /[Ss]) block "a recursive delete" ;;
      -*)
        option=$(lowercase "$argument")
        case "$option" in
          --recursive | -rec*) recursive=1 ;;
          --force | -fo*) force=1 ;;
          --*) ;;
          # Clusters such as -rf. The length limit leaves out PowerShell
          # parameters that happen to contain both letters, such as -Confirm.
          -[a-z] | -[a-z][a-z] | -[a-z][a-z][a-z] | -[a-z][a-z][a-z][a-z])
            case "$option" in *r*) recursive=1 ;; esac
            case "$option" in *f*) force=1 ;; esac
            ;;
        esac
        ;;
    esac
  done
  if [ "$recursive" -eq 1 ] && [ "$force" -eq 1 ]; then
    block "a recursive forced delete"
  fi
}

word_separators=$(printf ' \t.')
word_separators=${word_separators%.}

scan_segment() {
  IFS=$word_separators
  # shellcheck disable=SC2086 # Word splitting is the point here.
  set -- $1
  while [ $# -gt 0 ]; do
    word=$1
    shift
    case "${word##*/}" in
      [Gg][Ii][Tt] | [Gg][Ii][Tt].[Ee][Xx][Ee]) check_git "$@" ;;
      [Rr][Mm] | [Rr][Mm].[Ee][Xx][Ee] | [Rr][Ii] | [Rr][Dd] | [Rr][Mm][Dd][Ii][Rr] | [Dd][Ee][Ll] | [Ee][Rr][Aa][Ss][Ee] | [Rr][Ee][Mm][Oo][Vv][Ee]-[Ii][Tt][Ee][Mm])
        check_delete "$@"
        ;;
      [Cc][Dd] | [Cc][Hh][Dd][Ii][Rr] | [Pp][Uu][Ss][Hh][Dd] | [Ss][Ll] | [Ss][Ee][Tt]-[Ll][Oo][Cc][Aa][Tt][Ii][Oo][Nn] | [Pp][Uu][Ss][Hh]-[Ll][Oo][Cc][Aa][Tt][Ii][Oo][Nn])
        context_changed=1
        ;;
    esac
  done
}

# Undo the JSON escaping, join continued lines so a command split over several
# lines stays whole, and remove quotes so that bash -c "git push ..." is scanned
# like the command inside it. Then split on anything that separates commands.
segments=$(printf '%s' "$raw_command" \
  | LC_ALL=C sed -E \
    -e 's/\\\\(\\r)?\\n/ /g' \
    -e 's/`(\\r)?\\n/ /g' \
    -e 's/\\\\/\//g' \
    -e 's/\\"//g' \
    -e 's/\\\//\//g' \
    -e 's/\\[nr]/;/g' \
    -e 's/\\t/ /g' \
    -e 's/\\u00[0-9a-fA-F]{2}/ /g' \
  | LC_ALL=C tr -d "'\"" \
  | LC_ALL=C tr ';|&(){}`' '\n')

set -f
newline='
'
IFS=$newline
for segment in $segments; do
  scan_segment "$segment"
done

exit 0
