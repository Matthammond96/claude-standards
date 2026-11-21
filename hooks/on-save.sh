#!/bin/bash
# After the agent edits files: format each with the project's own formatter, check its
# length, and remember it so on-stop.sh can measure it when the turn ends. Measuring waits
# until then because code is often incomplete between edits.
# Switches: CLAUDE_ONSAVE=0 turns it off; CLAUDE_ONSAVE_MAX_LINES sets the limit (400).
. "$(dirname "$0")/lib.sh"
[ "${CLAUDE_ONSAVE:-1}" = "0" ] && { reply after_edit; exit 0; }
input=$(cat)
list=$(edited_list "$(session_id "$input")")
decision=$(recipe_get '.output.edit_block // "block"')

reason=$(
  edited_files "$input" | while IFS= read -r file; do
    # In a subshell: classify moves to the file's own project.
    (classify || exit 0; remember "$list"; format_file; [ -n "$decision" ] && too_long "$list")
  done | unseen "$list" # said once a session
)
if [ -n "$reason" ]; then
  jq -n --arg decision "$decision" --arg reason "$reason" '{decision: $decision, reason: $reason}'
else
  reply after_edit
fi
