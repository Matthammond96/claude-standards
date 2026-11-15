#!/bin/bash
# After Claude edits a file: format it with the project's own formatter, check its length,
# and remember it so on-stop.sh can lint it when the turn ends. Linting waits until then
# because code is often incomplete between edits. Nothing is installed or guessed: a tool
# runs only when the project has it configured.
# Switches: CLAUDE_ONSAVE=0 turns it off; CLAUDE_ONSAVE_MAX_LINES sets the limit (400).
[ "${CLAUDE_ONSAVE:-1}" = "0" ] && exit 0
. "$(dirname "$0")/lib.sh"
input=$(cat)
file=$(printf '%s' "$input" | jq -r '.tool_response.filePath // .tool_input.file_path // empty' 2>/dev/null)
classify || exit 0

list=$(edited_list "$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)")
mkdir -p "$(dirname "$list")" && echo "$file" >> "$list"

case "$kind" in
  js|text)
    if nearest .prettierrc .prettierrc.json .prettierrc.js .prettierrc.cjs .prettierrc.yaml prettier.config.js prettier.config.mjs >/dev/null \
       && p=$(tool prettier); then limited "$p" --write --ignore-unknown --log-level=error "$file" >/dev/null 2>&1
    elif uses_biome && p=$(tool biome); then limited "$p" format --write "$file" >/dev/null 2>&1
    fi ;;
  py)
    if uses_ruff && p=$(tool ruff); then limited "$p" format -q "$file" >/dev/null 2>&1
    elif configured '^\[tool\.black' && p=$(tool black); then limited "$p" -q "$file" >/dev/null 2>&1
    fi ;;
  rs)
    if manifest=$(nearest Cargo.toml) && p=$(command -v rustfmt); then
      edition=$(sed -n 's/^edition *= *"\([0-9]*\)".*/\1/p' "$manifest" | head -1)
      limited "$p" --edition "${edition:-2021}" "$file" >/dev/null 2>&1
    fi ;;
  go) p=$(command -v gofmt) && limited "$p" -w "$file" >/dev/null 2>&1 ;;
esac

max="${CLAUDE_ONSAVE_MAX_LINES:-400}"
[ "$kind" = "text" ] && exit 0
lines=$(wc -l < "$file" | tr -d ' ')
[ "$lines" -gt "$max" ] || exit 0
[ -n "$(echo "$file  length" | unseen "$list")" ] || exit 0 # said once this session already
jq -n --arg reason "$file is $lines lines; the limit is $max. Split it by responsibility into named modules before finishing. If it was already over the limit before your edit, do not make it longer, and tell the user it needs splitting." \
  '{decision: "block", reason: $reason}'
