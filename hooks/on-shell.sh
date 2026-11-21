#!/bin/bash
# Around each shell command Claude runs: find the files the command changed, so an edit
# made with sed, a script or a heredoc is formatted and measured like one made with the
# edit tools. Run as `on-shell.sh before` when the command starts and `on-shell.sh after`
# when it ends: a file counts when git shows it changed or new in the repository the
# command ran in, and it was written since the command started.
# What it can't see: files changed in another repository than the one the session is in,
# and files committed by the same command that changed them.
# Switches: CLAUDE_ONSAVE=0 turns it off.
. "$(dirname "$0")/lib.sh"
phase="$1"
[ "${CLAUDE_ONSAVE:-1}" = "0" ] && { reply "${phase}_shell"; exit 0; }
input=$(cat)
session=$(session_id "$input")
mark=$(session_file "$session" mark)
if [ "$phase" = "before" ]; then
  mkdir -p "$(dirname "$mark")" && touch "$mark"
  reply before_shell
  exit 0
fi
[ -f "$mark" ] || { reply after_shell; exit 0; }
cwd=$(printf '%s' "$input" | jq -r '.cwd // .workspacePaths[0] // "."' 2>/dev/null)
top=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || { reply after_shell; exit 0; }
list=$(edited_list "$session")

{ git -C "$top" diff --name-only -z HEAD 2>/dev/null; git -C "$top" ls-files -z --others --exclude-standard; } |
  while IFS= read -r -d '' path; do
    file="$top/$path"
    [ "$file" -nt "$mark" ] || continue
    # In a subshell: classify moves to the file's own project.
    (classify && remember "$list" && format_file)
  done
reply after_shell
exit 0
