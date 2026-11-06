#!/bin/sh
# PreToolUse hook for Bash and PowerShell: checks staged test files before a
# git commit.
#
#   *Test.java under src/test/java     gradle test --tests <class>
#   other files under apps/backend/src/test   gradle compileTestJava
#   src/test/resources/data.sql        asks the user, runs nothing
#   apps/web/e2e, apps/admin/e2e       asks the user, runs nothing (see below)
#
# Gradle runs on a temporary export of the staged backend files, outside the
# repository. So it tests exactly what would be committed, writes nothing under
# apps/, and avoids Gradle's delete failures inside OneDrive folders.
#
# E2E checks are deliberately not implemented yet. They need Node.js 22 on PATH,
# so a staged E2E file only asks the user. Running E2E tests needs the backend and
# writes real accounts and orders, so a hook never runs them.
#
# Only a run that proves success allows the commit. Test and compile failures are
# denied. Anything else, including interrupted runs, delete errors and a missing
# JDK, asks the user and never counts as a pass.
#
# It never runs a full test suite, and only covers commits made through Claude.
#
# Known gaps: git aliases, other ways to create commits (merge, cherry-pick, revert,
# rebase, am, commit-tree), script files, commands piped into a shell, encoded
# commands, and a cd whose failure is handled by the command itself.

gate_timeout_seconds=570
max_detail_lines=20
max_detail_bytes=2000

input=$(cat)

# Same parsing approach as log-file-changes.sh: prints the first string value for
# a JSON key, still JSON-escaped.
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

# Forward slashes, single separators, no trailing slash, and C:/ style drives.
normalize_path() {
  normalized=$(printf '%s' "$1" | tr '\\' '/' | tr -s '/' | sed 's#/$##')
  if is_windows; then
    normalized=$(printf '%s' "$normalized" | sed -E 's#^/([a-zA-Z])/#\1:/#' | LC_ALL=C tr 'A-Z' 'a-z')
  fi
  printf '%s' "$normalized"
}

json_escape() {
  printf '%s' "$1" \
    | LC_ALL=C tr '\t' ' ' \
    | LC_ALL=C tr -d '\000-\010\013-\037' \
    | LC_ALL=C sed 's/\\/\\\\/g; s/"/\\"/g' \
    | LC_ALL=C awk 'NR > 1 { printf "\\n" } { printf "%s", $0 }'
}

decided=0
export_dir=""

# Prints a permission decision: deny or ask. It never prints allow, which would
# skip the user's normal permission prompts.
decide() {
  decided=1
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' \
    "$1" "$(json_escape "gate-test-commit.sh: $2")"
  exit 0
}

# Lets the commit continue through the normal flow, and tells Claude what passed.
report_pass() {
  decided=1
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' \
    "$(json_escape "gate-test-commit.sh: $1")"
  exit 0
}

cleanup() {
  # A failed cleanup leaves a temporary folder behind and changes no result.
  [ -z "$export_dir" ] || rm -rf -- "$export_dir" 2>/dev/null
}

on_exit() {
  status=$?
  cleanup
  # Reaching here undecided, after the checks began, means the script itself
  # stopped early. That must not let the commit through unnoticed.
  if [ "$decided" -eq 0 ] && [ "${checks_started:-0}" -eq 1 ]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"gate-test-commit.sh: the check stopped unexpectedly (exit %s), so staged tests were not validated."}}\n' "$status"
    # Claude Code reads this decision only when the hook exits 0.
    exit 0
  fi
}
trap on_exit EXIT
trap 'decided=1; printf "gate-test-commit.sh: interrupted, so staged tests were not validated.\n" >&2; exit 2' HUP INT TERM

# --- Is this a git commit? -------------------------------------------------
#
# The command is read the way a shell reads it. Only a word in command position
# can be a command, so grep "git commit" notes.txt mentions a commit without
# making one. Wrappers such as sudo, env and bash -c are unwrapped, and the
# working directory is followed through cd.

case "$(json_string tool_name)" in
  Bash | PowerShell) ;;
  *) exit 0 ;;
esac

raw_command=$(json_string command)
case "$(printf '%s' "$raw_command" | LC_ALL=C tr -d "'\"\\\\")" in
  *commit*) ;;
  *) exit 0 ;;
esac

checks_started=1

working_dir=$(json_string cwd | tr '\\' '/' | tr -s '/')
[ -n "$working_dir" ] || working_dir=${CLAUDE_PROJECT_DIR:-.}
project=${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd)}

set -f
newline='
'
unit_separator=$(printf '\037')
record_marker=$(printf '\036')
line_break_marker=$(printf '\002')
literal_quote_marker=$(printf '\003')
word_separators=$(printf ' \t.')
word_separators=${word_separators%.}

# Undoes the JSON escaping. Continued lines are joined, and a quote escaped inside
# a quoted string is marked so that it does not end that string. Backslashes become
# forward slashes, which keeps Windows paths usable.
unescape_json() {
  printf '%s' "$1" \
    | LC_ALL=C sed -E \
      -e 's/\\\\(\\r)?\\n/ /g' \
      -e 's/`(\\r)?\\n/ /g' \
      -e 's/\\\\\\"/'"$literal_quote_marker"'/g' \
      -e 's/\\\\`/ /g' \
      -e 's/\\\\\$/S/g' \
      -e 's/\\\\/\//g' \
      -e 's/\\"/"/g' \
      -e 's/\\\//\//g' \
      -e 's/\\n/'"$line_break_marker"'/g' \
      -e 's/\\r//g' \
      -e 's/\\t/ /g' \
      -e 's/\\u00[0-9a-fA-F]{2}/ /g' \
    | LC_ALL=C tr "$line_break_marker" '\n'
}

# Restores text that was stored inside a single word, such as the bash -c payload.
decode_payload() {
  printf '%s' "$1" \
    | LC_ALL=C tr "$line_break_marker" '\n' \
    | LC_ALL=C tr "$literal_quote_marker" '"'
}

# Prints one line per simple command, with its words separated by unit separators.
# A ( or ) gets a line of its own. Code inside $(...) or backticks is printed as a
# separate record. Quoted text stays in one word. Comments, heredoc bodies,
# here-strings and redirect targets are dropped, because they are not commands.
tokenize() {
  LC_ALL=C awk '
    function flush_token() {
      if (has) {
        if (skip_word) {
          skip_word = 0
        } else {
          gsub(/\n/, "\002", tok)
          line = (count++ ? line "\037" : "") tok
        }
        tok = ""
        has = 0
      }
    }
    function flush_line(k, p) {
      flush_token()
      if (count) print line
      line = ""
      count = 0
      skip_word = 0
      for (k = 1; k <= nsub; k++) {
        p = subs[k]
        gsub(/\n/, "\002", p)
        print "\036SUB\037" p
      }
      nsub = 0
    }
    function read_substitution(i, depth, start, ch) {
      depth = 1
      start = i
      while (i <= n) {
        ch = substr(s, i, 1)
        if (ch == "(") {
          depth++
        } else if (ch == ")") {
          depth--
          if (depth == 0) break
        }
        i++
      }
      subs[++nsub] = substr(s, start, i - start)
      return i + 1
    }
    function skip_heredocs(h, j, text) {
      for (h = 1; h <= nhd; h++) {
        while (i <= n) {
          j = index(substr(s, i), "\n")
          text = j ? substr(s, i, j - 1) : substr(s, i)
          i = j ? i + j : n + 1
          if (hd_dash[h]) sub(/^\t+/, "", text)
          if (text == hd[h]) break
        }
      }
      nhd = 0
    }
    { s = s (NR > 1 ? "\n" : "") $0 }
    END {
      n = length(s)
      i = 1
      while (i <= n) {
        c = substr(s, i, 1)
        next_c = substr(s, i + 1, 1)
        if (c == "\n") {
          flush_line()
          i++
          if (nhd) skip_heredocs()
        } else if (c == " " || c == "\t") {
          flush_token()
          i++
        } else if (c == "#" && !has) {
          j = index(substr(s, i), "\n")
          if (!j) break
          i += j - 1
        } else if (c == "@" && !has && (next_c == "\047" || next_c == "\"") && substr(s, i + 2, 1) == "\n") {
          rest = substr(s, i + 3)
          j = index(rest, "\n" next_c "@")
          tok = j ? substr(rest, 1, j - 1) : rest
          has = 1
          i = j ? i + 3 + j + 2 : n + 1
        } else if (c == "\047") {
          rest = substr(s, i + 1)
          j = index(rest, "\047")
          tok = tok (j ? substr(rest, 1, j - 1) : rest)
          has = 1
          i = j ? i + j + 1 : n + 1
        } else if (c == "\"") {
          has = 1
          i++
          while (i <= n) {
            d = substr(s, i, 1)
            if (d == "\"") {
              i++
              break
            } else if (d == "$" && substr(s, i + 1, 1) == "(") {
              i = read_substitution(i + 2)
              tok = tok "$()"
            } else if (d == "`") {
              rest = substr(s, i + 1)
              j = index(rest, "`")
              subs[++nsub] = j ? substr(rest, 1, j - 1) : rest
              tok = tok "$()"
              i = j ? i + j + 1 : n + 1
            } else {
              tok = tok d
              i++
            }
          }
        } else if (c == "$" && next_c == "{") {
          j = index(substr(s, i), "}")
          if (!j) j = n - i + 1
          tok = tok substr(s, i, j)
          has = 1
          i += j
        } else if (c == "$" && next_c == "(") {
          i = read_substitution(i + 2)
          tok = tok "$()"
          has = 1
        } else if (c == ";" || c == "|" || c == "`") {
          flush_line()
          i++
        } else if (c == "&" && next_c != ">") {
          flush_line()
          i++
        } else if (c == "(" || c == ")") {
          flush_line()
          print c
          i++
        } else if ((c == "{" || c == "}") && !has) {
          flush_line()
          i++
        } else if (c == ">" || c == "<" || c == "&") {
          if (has && tok ~ /^[0-9]+$/) {
            tok = ""
            has = 0
          } else {
            flush_token()
          }
          if (substr(s, i, 3) == "<<<") {
            i += 3
            skip_word = 1
          } else if (substr(s, i, 2) == "<<") {
            i += 2
            dash = 0
            if (substr(s, i, 1) == "-") {
              dash = 1
              i++
            }
            while (substr(s, i, 1) == " ") i++
            q = substr(s, i, 1)
            delimiter = ""
            if (q == "\047" || q == "\"") {
              rest = substr(s, i + 1)
              j = index(rest, q)
              delimiter = j ? substr(rest, 1, j - 1) : rest
              i = j ? i + j + 1 : n + 1
            } else {
              while (i <= n && substr(s, i, 1) !~ /[ \t\n;&|<>()`]/) {
                delimiter = delimiter substr(s, i, 1)
                i++
              }
            }
            hd[++nhd] = delimiter
            hd_dash[nhd] = dash
          } else {
            while (substr(s, i, 1) ~ /[<>&]/) i++
            skip_word = 1
          }
        } else {
          tok = tok c
          has = 1
          i++
        }
      }
      flush_line()
    }
  '
}

commit_args_issue=""
this_dry_run=0

# Sets commit_args_issue if this commit could include files that are not staged,
# and this_dry_run if it would not commit at all.
check_commit_arguments() {
  commit_args_issue=""
  this_dry_run=0
  value_next=0
  for argument in "$@"; do
    if [ "$value_next" -eq 1 ]; then
      value_next=0
      continue
    fi
    case "$argument" in
      --dry-run) this_dry_run=1 ;;
      --all | --include | --only | --interactive | --patch | --pathspec-from-file | --pathspec-from-file=*)
        commit_args_issue="this commit can include files that are not staged, so the staged check would miss them. Stage files by name with git add, then run a plain git commit."
        ;;
      --) commit_args_issue="this commit names files directly, so the staged check would miss them. Stage files by name with git add, then run a plain git commit." ;;
      --message | --file | --author | --date | --template | --reuse-message | --reedit-message | --fixup | --squash | --trailer | --cleanup)
        value_next=1
        ;;
      --*) ;;
      # These two carry their value in the same word, so its letters are not flags.
      -u* | -S*) ;;
      -*)
        # Letters before an option that takes a value are flags, as in -am.
        flags=${argument%%[mFcCt]*}
        case "$flags" in
          *a* | *i* | *o* | *p*)
            commit_args_issue="this commit can include files that are not staged, so the staged check would miss them. Stage files by name with git add, then run a plain git commit."
            ;;
        esac
        value_letters=${argument#"$flags"}
        case "$value_letters" in
          [mFcCt]) value_next=1 ;;
        esac
        ;;
      *)
        commit_args_issue="this commit names files directly, so the staged check would miss them. Stage files by name with git add, then run a plain git commit."
        ;;
    esac
  done
}

effective_dir=$working_dir
scoped_dir=""
stage_seen=0
overrides_git=0
relevant_commit=0
unknown_repo=0
top_level=""
depth=0
frame=0

# Works out the directory a cd or -C leads to. Empty means it cannot be known from
# the command text.
resolve_dir() { # base directory, target
  target=$(printf '%s' "$2" | tr '\\' '/')
  case "$target" in
    - | *'$'* | *%* | *'*'* | *'?'*) return 0 ;;
    '~') printf '%s' "$HOME"; return 0 ;;
    '~/'*) printf '%s/%s' "$HOME" "${target#'~/'}"; return 0 ;;
    '~'*) return 0 ;;
    /* | [A-Za-z]:*) printf '%s' "$target"; return 0 ;;
  esac
  [ -z "$1" ] || printf '%s/%s' "$1" "$target"
}

record_commit() { # directory, then the arguments of git commit
  commit_directory=$1
  shift
  check_commit_arguments "$@"
  [ "$this_dry_run" -eq 0 ] || return 0

  if [ -z "$commit_directory" ] || [ "$overrides_git" -eq 1 ]; then
    unknown_repo=1
    return 0
  fi

  commit_top=$(git -C "$commit_directory" rev-parse --show-toplevel 2>/dev/null)
  if [ -z "$commit_top" ]; then
    unknown_repo=1
    return 0
  fi

  # A commit in some other repository is none of this hook's business.
  [ "$(normalize_path "$commit_top")" = "$(normalize_path "$project")" ] || return 0

  [ -z "$commit_args_issue" ] || decide deny "$commit_args_issue"
  if [ "$stage_seen" -eq 1 ]; then
    decide deny "this command stages files and commits together, so the staged files cannot be checked first. Run git add as a separate command, then git commit."
  fi
  relevant_commit=1
  top_level=$commit_top
}

handle_git() {
  git_directory=${scoped_dir:-$effective_dir}
  while [ $# -gt 0 ]; do
    case "$1" in
      -C)
        git_directory=$(resolve_dir "$git_directory" "${2:-}")
        [ $# -ge 2 ] && shift 2 || shift
        ;;
      --git-dir | --work-tree)
        overrides_git=1
        [ $# -ge 2 ] && shift 2 || shift
        ;;
      --git-dir=* | --work-tree=*)
        overrides_git=1
        shift
        ;;
      -c | --namespace | --exec-path | --super-prefix | --config-env)
        [ $# -ge 2 ] && shift 2 || shift
        ;;
      -*) shift ;;
      *) break ;;
    esac
  done
  [ $# -gt 0 ] || return 0
  git_subcommand=$1
  shift
  case "$git_subcommand" in
    add | stage | rm | mv) stage_seen=1 ;;
    commit) record_commit "$git_directory" "$@" ;;
  esac
}

# Sets skipped to the number of leading options, given the options that take a value.
count_options() { # value options, then the arguments
  value_options=" $1 "
  shift
  skipped=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --)
        skipped=$((skipped + 1))
        return 0
        ;;
      -?*)
        if option_takes_next_word "$1"; then
          skipped=$((skipped + 2))
          [ $# -ge 2 ] && shift 2 || shift
        else
          skipped=$((skipped + 1))
          shift
        fi
        ;;
      *) return 0 ;;
    esac
  done
}

# True if the next word is this option's value. Handles clusters such as -iu root,
# where the last letter takes the value, and attached values such as -uroot.
option_takes_next_word() {
  case "$value_options" in
    *" $1 "*) return 0 ;;
  esac
  case "$1" in
    --*) return 1 ;;
  esac
  remaining_letters=${1#-}
  while [ -n "$remaining_letters" ]; do
    after_letter=${remaining_letters#?}
    letter=${remaining_letters%"$after_letter"}
    case "$value_options" in
      *" -$letter "*)
        [ -z "$after_letter" ]
        return
        ;;
    esac
    remaining_letters=$after_letter
  done
  return 1
}

shift_options() { # prints how many arguments can really be shifted
  [ "$skipped" -le "$1" ] && printf '%s' "$skipped" || printf '%s' "$1"
}

join_words() {
  (IFS=' '; printf '%s' "$*")
}

# Follows one simple command through keywords and wrappers to what it really runs.
run_command() {
  while [ $# -gt 0 ]; do
    word=$1
    case "$word" in
      [A-Za-z_]*=*)
        case "$word" in
          GIT_DIR=* | GIT_INDEX_FILE=* | GIT_WORK_TREE=* | GIT_OBJECT_DIRECTORY=*) overrides_git=1 ;;
        esac
        shift
        continue
        ;;
    esac

    name=$(printf '%s' "${word##*/}" | LC_ALL=C tr 'A-Z' 'a-z')
    name=${name%.exe}
    shift

    case "$name" in
      if | then | elif | else | while | until | do | '!') ;;
      git) handle_git "$@"; return 0 ;;

      cd | chdir | pushd | sl | set-location | push-location)
        count_options "" "$@"
        shift "$(shift_options $#)"
        case "${1:-}" in
          /[Dd]) shift ;;
        esac
        if [ $# -eq 0 ]; then
          effective_dir=$HOME
        else
          effective_dir=$(resolve_dir "$effective_dir" "$1")
        fi
        return 0
        ;;
      popd | pop-location)
        effective_dir=""
        return 0
        ;;

      sudo | doas)
        count_options "-u -g -h -p -C -D -R -T -r -t -U --user --group --host --prompt --chdir --chroot --role --type --other-user --command-timeout" "$@"
        shift "$(shift_options $#)"
        ;;
      env)
        while [ $# -gt 0 ]; do
          case "$1" in
            -C | --chdir)
              scoped_dir=$(resolve_dir "$effective_dir" "${2:-}")
              [ -n "$scoped_dir" ] || overrides_git=1
              [ $# -ge 2 ] && shift 2 || shift
              ;;
            --chdir=*)
              scoped_dir=$(resolve_dir "$effective_dir" "${1#--chdir=}")
              [ -n "$scoped_dir" ] || overrides_git=1
              shift
              ;;
            -u | --unset | -[!-]*u)
              [ $# -ge 2 ] && shift 2 || shift
              ;;
            -S | --split-string)
              [ $# -lt 2 ] || analyze "$(decode_payload "$2")"
              return 0
              ;;
            --)
              shift
              break
              ;;
            -?*) shift ;;
            *) break ;;
          esac
        done
        ;;
      command | builtin)
        case "${1:-}" in
          -v | -V) return 0 ;;
        esac
        count_options "" "$@"
        shift "$(shift_options $#)"
        ;;
      exec)
        count_options "-a" "$@"
        shift "$(shift_options $#)"
        ;;
      nohup | setsid | winpty | call | unbuffer | busybox)
        count_options "" "$@"
        shift "$(shift_options $#)"
        ;;
      time)
        count_options "-f -o" "$@"
        shift "$(shift_options $#)"
        ;;
      nice | ionice)
        count_options "-n -c -p --adjustment" "$@"
        shift "$(shift_options $#)"
        ;;
      stdbuf)
        count_options "-i -o -e" "$@"
        shift "$(shift_options $#)"
        ;;
      timeout)
        count_options "-k -s --kill-after --signal" "$@"
        shift "$(shift_options $#)"
        [ $# -eq 0 ] || shift
        ;;
      watch)
        count_options "-n -d" "$@"
        shift "$(shift_options $#)"
        ;;
      xargs)
        count_options "-I -n -P -L -d -E -s -a --max-args --replace" "$@"
        shift "$(shift_options $#)"
        ;;
      find)
        while [ $# -gt 0 ]; do
          case "$1" in
            -exec | -execdir | -ok | -okdir)
              shift
              break
              ;;
          esac
          shift
        done
        ;;

      bash | sh | zsh | dash | ksh | ash | fish)
        # Options can come before or after -c, so the command is the first word that
        # is not an option or an option's value, as in bash -eo pipefail -c "...".
        shell_has_c=0
        while [ $# -gt 0 ]; do
          case "$1" in
            --)
              shift
              break
              ;;
            --rcfile | --init-file)
              [ $# -ge 2 ] && shift 2 || shift
              ;;
            --*) shift ;;
            [-+]?*)
              case "$1" in
                -*c*) shell_has_c=1 ;;
              esac
              case "$1" in
                *[oO])
                  [ $# -ge 2 ] && shift 2 || shift
                  ;;
                *) shift ;;
              esac
              ;;
            *) break ;;
          esac
        done
        # Without -c, the next word is a script file. It is not read, which is a
        # known limitation.
        if [ "$shell_has_c" -eq 1 ] && [ $# -gt 0 ]; then
          analyze "$(decode_payload "$1")"
        fi
        return 0
        ;;
      cmd)
        while [ $# -gt 0 ]; do
          case "$1" in
            /[CcKk])
              shift
              analyze "$(decode_payload "$(join_words "$@")")"
              return 0
              ;;
          esac
          shift
        done
        return 0
        ;;
      powershell | pwsh)
        while [ $# -gt 0 ]; do
          lowered=$(printf '%s' "$1" | LC_ALL=C tr 'A-Z' 'a-z')
          case "$lowered" in
            -c | -co* | -command)
              shift
              analyze "$(decode_payload "$(join_words "$@")")"
              return 0
              ;;
            -e | -ec | -en* | -f | -file) return 0 ;;
            -noprofile | -nop* | -noninteractive | -noni* | -nologo | -nol* | -sta | -mta) shift ;;
            -ex* | -executionpolicy | -w* | -windowstyle | -inputformat | -outputformat | -configurationname | -version)
              [ $# -ge 2 ] && shift 2 || shift
              ;;
            *)
              analyze "$(decode_payload "$(join_words "$@")")"
              return 0
              ;;
          esac
        done
        return 0
        ;;
      eval | iex | invoke-expression)
        case "${1:-}" in
          -[Cc]ommand) shift ;;
        esac
        [ $# -eq 0 ] || analyze "$(decode_payload "$(join_words "$@")")"
        return 0
        ;;

      # The program comes from a variable, so it may be git and cannot be followed.
      *'$'* | *%*)
        for argument in "$@"; do
          [ "$argument" != commit ] || unknown_repo=1
        done
        return 0
        ;;
      *) return 0 ;;
    esac
  done
}

handle_line() {
  IFS=$unit_separator
  # shellcheck disable=SC2086 # Word splitting is the point here.
  set -- $1
  [ $# -gt 0 ] || return 0
  case "$1" in
    '(')
      frame=$((frame + 1))
      eval "saved_dir_$frame=\$effective_dir"
      return 0
      ;;
    ')')
      eval "floor=\$entry_frame_$depth"
      if [ "$frame" -gt "$floor" ]; then
        eval "effective_dir=\$saved_dir_$frame"
        frame=$((frame - 1))
      fi
      return 0
      ;;
    "${record_marker}SUB")
      [ $# -lt 2 ] || analyze "$(decode_payload "$2")"
      return 0
      ;;
  esac
  scoped_dir=""
  run_command "$@"
}

# Reads a block of commands. A directory change inside it stays inside it, as it
# does for a bash -c payload or a command substitution.
analyze() {
  depth=$((depth + 1))
  if [ "$depth" -gt 8 ]; then
    unknown_repo=1
    depth=$((depth - 1))
    return 0
  fi
  frame=$((frame + 1))
  eval "entry_frame_$depth=\$frame; saved_dir_$frame=\$effective_dir"
  command_lines=$(printf '%s\n' "$1" | tokenize) || unknown_repo=1
  IFS=$newline
  for command_line in $command_lines; do
    handle_line "$command_line"
  done
  eval "frame=\$entry_frame_$depth"
  eval "effective_dir=\$saved_dir_$frame"
  frame=$((frame - 1))
  depth=$((depth - 1))
}

# The top level keeps its directory changes for later commands, so it is read
# without the scoping that analyze adds around nested blocks.
depth=1
entry_frame_1=0
top_lines=$(unescape_json "$raw_command" | tokenize) || unknown_repo=1
IFS=$newline
for command_line in $top_lines; do
  handle_line "$command_line"
done
IFS=$newline

if [ "$unknown_repo" -eq 1 ]; then
  decide ask "the repository for this commit could not be determined, so staged tests were not validated."
fi

if [ "$relevant_commit" -eq 0 ]; then
  decided=1
  exit 0
fi

staged=$(git -C "$top_level" -c core.quotepath=off diff --cached --name-status --no-renames 2>/dev/null)
staged_status=$?
if [ "$staged_status" -ne 0 ]; then
  decide ask "the staged files could not be read, so staged tests were not validated."
fi

test_classes=""
needs_compile=0
data_sql_staged=0
e2e_staged=0

while IFS='	' read -r change_status path; do
  [ -n "$path" ] || continue
  case "$path" in
    apps/backend/src/test/resources/data.sql) data_sql_staged=1 ;;
    apps/backend/src/test/java/*Test.java)
      if [ "$change_status" = D ]; then
        needs_compile=1
      else
        class_name=${path#apps/backend/src/test/java/}
        class_name=${class_name%.java}
        test_classes="$test_classes $(printf '%s' "$class_name" | tr '/' '.')"
      fi
      ;;
    apps/backend/src/test/*) needs_compile=1 ;;
    apps/web/e2e/* | apps/admin/e2e/*) e2e_staged=1 ;;
  esac
done <<EOF
$staged
EOF

e2e_note="Staged E2E files were not validated: the E2E check is disabled until Node.js 22 is on PATH, and running E2E tests needs the backend and writes real data."

if [ "$data_sql_staged" -eq 1 ]; then
  message="apps/backend/src/test/resources/data.sql is staged. All Spring tests share it, so a focused run cannot show it is safe, and this hook does not run the full suite. Nothing was run. Approve only if you accept committing without that check. Otherwise, deny and ask Claude to run the backend test suite first."
  [ "$e2e_staged" -eq 0 ] || message="$message $e2e_note"
  decide ask "$message"
fi

if [ -z "$test_classes" ] && [ "$needs_compile" -eq 0 ]; then
  if [ "$e2e_staged" -eq 1 ]; then
    decide ask "$e2e_note Approve only if you accept committing them unvalidated."
  fi
  decided=1
  exit 0
fi

# --- Run Gradle on an export of the staged files ---------------------------

if ! command -v java >/dev/null 2>&1; then
  decide ask "java was not found, so Gradle could not run and staged backend tests were not validated. The build needs a JDK 17 toolchain."
fi

temp_base=${TEMP:-${TMPDIR:-/tmp}}
export_dir=$(mktemp -d "$temp_base/foodme-gate.XXXXXX" 2>/dev/null)
if [ -z "$export_dir" ]; then
  decide ask "a temporary folder could not be created, so staged backend tests were not validated."
fi

if ! git -C "$top_level" ls-files -z -- apps/backend \
  | git -C "$top_level" checkout-index -z --stdin --prefix="$export_dir/" 2>/dev/null; then
  decide ask "the staged backend files could not be exported, so staged tests were not validated."
fi

backend_dir="$export_dir/apps/backend"
if is_windows; then
  gradle_program=./gradlew.bat
else
  gradle_program=./gradlew
fi
if [ ! -f "$backend_dir/$gradle_program" ]; then
  decide ask "$gradle_program is not in the staged files, so staged backend tests were not validated."
fi

IFS=$word_separators
set --
if [ -n "$test_classes" ]; then
  set -- test
  for class_name in $test_classes; do
    set -- "$@" --tests "$class_name"
  done
  command_text="gradlew test --tests$(printf '%s' "$test_classes" | sed 's/ / --tests /2g')"
else
  set -- compileTestJava
  command_text="gradlew compileTestJava"
fi

run_limited() {
  # Windows has its own unrelated timeout.exe, so only GNU timeout is used.
  if timeout --version 2>/dev/null | grep -q coreutils; then
    timeout "$gate_timeout_seconds" "$@"
  else
    "$@"
  fi
}

# Output goes to a file because a pipe would stay open after a timeout for as long
# as any Gradle child process lives, which could outlast this hook's own time limit.
output_file="$export_dir/gradle-output.txt"
(cd "$backend_dir" && run_limited "$gradle_program" --no-daemon --console=plain "$@") >"$output_file" 2>&1
gradle_status=$?
output=$(LC_ALL=C tr -d '\r' <"$output_file")

# Only these lines leave the hook, so full test output and anything in it stays
# out of the conversation.
details() {
  printf '%s\n' "$output" \
    | LC_ALL=C grep -E "$1" \
    | head -n "$max_detail_lines" \
    | head -c "$max_detail_bytes"
}

has_output() {
  printf '%s\n' "$output" | LC_ALL=C grep -qE "$1"
}

failure_lines=' FAILED$|^> Task .* FAILED|BUILD FAILED|error:|There were failing tests|No tests found|Compilation failed'
manual_command="Run this in apps/backend to see the full output: $command_text"

# An interrupted or killed run proves nothing, whatever it printed first.
case "$gradle_status" in
  124 | 137 | 143)
    decide ask "Gradle was stopped before it finished (exit $gradle_status), so staged tests were NOT validated. This is not a pass. $manual_command"
    ;;
esac

if [ "$gradle_status" -eq 0 ]; then
  if ! has_output '^BUILD SUCCESSFUL' || has_output 'BUILD FAILED'; then
    decide ask "Gradle exited 0 without reporting BUILD SUCCESSFUL, so staged tests were NOT validated. $manual_command"
  fi
  # Every staged class needs its own passing result. Gradle succeeds if any filter
  # matches, so a class with no test methods can sit beside one that passes.
  classes_without_result=""
  for class_name in $test_classes; do
    simple_name=${class_name##*.}
    if ! has_output "^$simple_name( >|\\\$).* PASSED\$"; then
      classes_without_result="$classes_without_result $simple_name"
    fi
  done
  if [ -n "$classes_without_result" ]; then
    decide ask "Gradle reported success, but no passing test was seen for:$classes_without_result. Each may be an abstract base class or have no test methods, so these classes were NOT validated. Approve only if that is expected. $manual_command"
  fi
  if [ "$e2e_staged" -eq 1 ]; then
    decide ask "$command_text passed. $e2e_note Approve only if you accept committing them unvalidated."
  fi
  report_pass "$command_text passed on the staged files."
fi

# A real test or compile failure comes first: other messages may just be side
# effects of it.
if has_output 'There were failing tests| > .* FAILED$|Compilation failed'; then
  decide deny "$command_text failed on the staged files (exit $gradle_status). Fix the test or the code before committing.
$(details "$failure_lines")
$manual_command"
fi

if has_output 'No tests found'; then
  decide ask "Gradle found no tests in the staged classes (exit $gradle_status). Each may be an abstract base class or have no test methods, so they were NOT validated. Approve only if that is expected.
$(details 'No tests found')
$manual_command"
fi

if has_output '[Uu]nable to delete|[Cc]ould not delete|[Ff]ailed to delete|being used by another process|AccessDeniedException|Access is denied'; then
  decide ask "Gradle hit a file deletion or access error (exit $gradle_status), so staged tests were NOT validated. This is not a test failure or a pass. Repositories inside OneDrive are known to cause this, though this check runs outside the repository.
$(details '[Uu]nable to delete|[Cc]ould not delete|[Ff]ailed to delete|being used by another process|AccessDeniedException|Access is denied')
$manual_command"
fi

if has_output 'No matching toolchains|Cannot find a Java installation|toolchain'; then
  decide ask "Gradle could not find the JDK 17 toolchain (exit $gradle_status), so staged tests were NOT validated. $manual_command"
fi

if has_output 'Could not resolve|Could not download|Could not GET|Unable to download|Connection (refused|timed out)|UnknownHostException'; then
  decide ask "Gradle could not download what it needs (exit $gradle_status), so staged tests were NOT validated. $manual_command"
fi

decide ask "Gradle failed for an unrecognized reason (exit $gradle_status), so staged tests were NOT validated. This is not a pass.
$(details 'BUILD FAILED|What went wrong')
$manual_command"
