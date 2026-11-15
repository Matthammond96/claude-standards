#!/bin/bash
# When Claude finishes a turn: measure the quality of the files it edited during the turn
# and send back what is over the limits, so it simplifies before stopping. This is about
# how the code is built, not whether it is correct: correctness belongs to the project's
# own tests, type checker and linter. It asks once: if problems remain after that, the
# turn ends and the user is told. A function is reported once per session.
# Limits (environment variables): CLAUDE_QUALITY_COMPLEXITY (10, branches per function),
# CLAUDE_QUALITY_FUNCTION_LINES (60), CLAUDE_QUALITY_PARAMS (5).
# Switches: CLAUDE_ONSAVE=0 or CLAUDE_QUALITY=0 turns it off.
[ "${CLAUDE_ONSAVE:-1}" = "0" ] || [ "${CLAUDE_QUALITY:-1}" = "0" ] && exit 0
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
lizard="$here/.venv/bin/lizard"
[ -x "$lizard" ] || exit 0
input=$(cat)
list=$(edited_list "$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)")
[ -s "$list" ] || exit 0
again=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
ccn="${CLAUDE_QUALITY_COMPLEXITY:-10}"; len="${CLAUDE_QUALITY_FUNCTION_LINES:-60}"; par="${CLAUDE_QUALITY_PARAMS:-5}"

files=()
while IFS= read -r file; do
  classify && [ "$kind" != "text" ] && files+=("$file")
done < <(sort -u "$list")
[ "${#files[@]}" -eq 0 ] && { rm -f "$list"; exit 0; }

# lizard prints: <file>:<line>: warning: <name> has N NLOC, N CCN, N token, N PARAM, N length, ...
problems=$(limited "$lizard" -w -C "$ccn" -L "$len" -a "$par" "${files[@]}" 2>/dev/null |
  awk -v ccn="$ccn" -v len="$len" -v par="$par" '
    match($0, /: warning: /) {
      where = substr($0, 1, RSTART - 1); rest = substr($0, RSTART + RLENGTH)
      name = rest; sub(/ has .*/, "", name)
      c = rest; sub(/.* NLOC, /, "", c); sub(/ CCN.*/, "", c)
      p = rest; sub(/.* token, /, "", p); sub(/ PARAM.*/, "", p)
      # Lines are the code of the function itself (NLOC), so a block that only holds other
      # functions, such as a describe() of many tests, is not long because they are.
      l = rest; sub(/ NLOC.*/, "", l); sub(/.* has /, "", l)
      why = ""
      if (c + 0 > ccn) why = why sprintf("complexity %d (limit %d)", c, ccn)
      if (l + 0 > len) why = why (why ? ", " : "") sprintf("%d lines (limit %d)", l, len)
      if (p + 0 > par) why = why (why ? ", " : "") sprintf("%d parameters (limit %d)", p, par)
      if (why) printf "%s  %s: %s\n", where, name, why
    }' | unseen "$list" | head -40)

if [ -z "$problems" ]; then rm -f "$list"; exit 0; fi
if [ "$again" = "true" ]; then
  rm -f "$list"
  jq -n '{systemMessage: "Code quality limits are still exceeded in files edited this turn."}'
  exit 0
fi
jq -n --arg reason "Code quality: these functions in files you edited this turn are over the limits.
$problems
Simplify the ones you wrote or changed: extract named helpers, flatten nesting, group parameters. Do not change behaviour. For functions that were already like this before your edit, leave them and tell the user." \
  '{decision: "block", reason: $reason}'
