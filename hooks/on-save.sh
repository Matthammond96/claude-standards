#!/bin/bash
# After Claude edits a file: format it with the project's own formatter, check its length,
# and remember it so on-stop.sh can measure it when the turn ends. Measuring waits until
# then because code is often incomplete between edits.
# Switches: CLAUDE_ONSAVE=0 turns it off; CLAUDE_ONSAVE_MAX_LINES sets the limit (400).
[ "${CLAUDE_ONSAVE:-1}" = "0" ] && exit 0
. "$(dirname "$0")/lib.sh"
input=$(cat)
file=$(printf '%s' "$input" | jq -r '.tool_response.filePath // .tool_input.file_path // empty' 2>/dev/null)
classify || exit 0

list=$(edited_list "$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)")
remember "$list"
format_file

reason=$(too_long "$list" | unseen "$list") # said once a session
[ -n "$reason" ] || exit 0
jq -n --arg reason "$reason" '{decision: "block", reason: $reason}'
