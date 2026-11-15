#!/bin/bash
# Around each shell command Claude runs: find the files the command changed, so an edit
# made with sed, a script or a heredoc is formatted and measured like one made with the
# edit tools. Run as `on-shell.sh before` when the command starts and `on-shell.sh after`
# when it ends: a file counts when git shows it changed or new in the repository the
# command ran in, and it was written since the command started.
# What it can't see: files changed in another repository than the one the session is in,
# and files committed by the same command that changed them.
# Switches: CLAUDE_ONSAVE=0 turns it off.
[ "${CLAUDE_ONSAVE:-1}" = "0" ] && exit 0
. "$(dirname "$0")/lib.sh"
input=$(cat)
session=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
mark=$(session_file "$session" mark)
if [ "$1" = "before" ]; then
  mkdir -p "$(dirname "$mark")" && touch "$mark"
  exit 0
fi
[ -f "$mark" ] || exit 0
top=$(git -C "$(printf '%s' "$input" | jq -r '.cwd // "."' 2>/dev/null)" rev-parse --show-toplevel 2>/dev/null) || exit 0
list=$(edited_list "$session")

{ git -C "$top" diff --name-only -z HEAD 2>/dev/null; git -C "$top" ls-files -z --others --exclude-standard; } |
  while IFS= read -r -d '' path; do
    file="$top/$path"
    [ "$file" -nt "$mark" ] || continue
    # In a subshell: classify moves to the file's own project.
    (classify && remember "$list" && format_file)
  done
exit 0
