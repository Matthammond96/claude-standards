#!/bin/bash
# After the agent edits files: format each with the project's own formatter, check its
# length, and remember it so on-stop.sh can measure it when the turn ends. Measuring waits
# until then because code is often incomplete between edits.
# Switches: CLAUDE_ONSAVE=0 turns it off; CLAUDE_ONSAVE_MAX_LINES sets the limit (400).
[ "${CLAUDE_ONSAVE:-1}" = "0" ] && exit 0
. "$(dirname "$0")/lib.sh"
input=$(cat)
list=$(edited_list "$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)")

reason=$(
  edited_files "$input" | while IFS= read -r file; do
    # In a subshell: classify moves to the file's own project.
    (classify || exit 0; remember "$list"; format_file; too_long "$list")
  done | unseen "$list" # said once a session
)
[ -n "$reason" ] || exit 0
jq -n --arg reason "$reason" '{decision: "block", reason: $reason}'
