#!/bin/bash
# When Claude finishes a turn: measure the files it edited during the turn and send back
# what is over the limits, so it simplifies before stopping. This is about how the code is
# built, not whether it is correct: correctness belongs to the project's own tests, type
# checker and linter. Only what the session made worse counts: a function or file that was
# already over a limit, and is no further over it, is left alone. It asks once: if
# problems remain after that, the turn ends and the user is told. A problem is reported
# once per session.
# Limits (environment variables): CLAUDE_QUALITY_COMPLEXITY (branches per function: 10,
# and 15 in Go; see complexity_limit), CLAUDE_QUALITY_FUNCTION_LINES (60),
# CLAUDE_QUALITY_PARAMS (5), CLAUDE_ONSAVE_MAX_LINES (400, lines per file).
# Switches: CLAUDE_ONSAVE=0 or CLAUDE_QUALITY=0 turns it off.
[ "${CLAUDE_ONSAVE:-1}" = "0" ] || [ "${CLAUDE_QUALITY:-1}" = "0" ] && exit 0
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
lizard="$here/.venv/bin/lizard"
input=$(cat)
list=$(edited_list "$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)")
[ -s "$list" ] || exit 0
again=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
len="${CLAUDE_QUALITY_FUNCTION_LINES:-60}"; par="${CLAUDE_QUALITY_PARAMS:-5}"

# The functions of file $1 over a limit, with complexity limit $2, one a line:
# <name> TAB <complexity> TAB <lines> TAB <parameters> TAB <file>:<line>
# lizard prints: <file>:<line>: warning: <name> has N NLOC, N CCN, N token, N PARAM, ...
over_limits() {
  limited "$lizard" -w -C "$2" -L "$len" -a "$par" "$1" 2>/dev/null | awk '
    match($0, /: warning: /) {
      where = substr($0, 1, RSTART - 1); rest = substr($0, RSTART + RLENGTH)
      name = rest; sub(/ has .*/, "", name)
      c = rest; sub(/.* NLOC, /, "", c); sub(/ CCN.*/, "", c)
      p = rest; sub(/.* token, /, "", p); sub(/ PARAM.*/, "", p)
      # Lines are the code of the function itself (NLOC), so a block that only holds other
      # functions, such as a describe() of many tests, is not long because they are.
      l = rest; sub(/ NLOC.*/, "", l); sub(/.* has /, "", l)
      printf "%s\t%d\t%d\t%d\t%s\n", name, c, l, p, where
    }'
}

# The functions of $file the session put over a limit, or further over it than they were.
worse_functions() {
  local ccn base; ccn=$(complexity_limit); base=$(baseline "$list")
  {
    [ -f "$base" ] && over_limits "$base" "$ccn" | sed 's/^/was\t/'
    over_limits "$file" "$ccn" | sed 's/^/now\t/'
  } | awk -F'\t' -v ccn="$ccn" -v len="$len" -v par="$par" '
    function exceeded(what, now, limit, was) {
      if (now <= limit || now <= was) return ""
      return sprintf(what " (limit %d%s)", now, limit, was > limit ? ", was " was : "")
    }
    $1 == "was" { if ($3 > c[$2]) c[$2] = $3; if ($4 > l[$2]) l[$2] = $4; if ($5 > p[$2]) p[$2] = $5; next }
    {
      why = ""
      n = split(exceeded("complexity %d", $3, ccn, c[$2]) "|" exceeded("%d lines", $4, len, l[$2]) "|" exceeded("%d parameters", $5, par, p[$2]), parts, "|")
      for (i = 1; i <= n; i++) if (parts[i] != "") why = why (why ? ", " : "") parts[i]
      if (why) printf "%s  %s: %s\n", $6, $2, why
    }'
}

problems=$(
  sort -u "$list" | while IFS= read -r file; do
    classify || continue
    too_long "$list"
    [ -x "$lizard" ] && measured && ! is_test && worse_functions
  done | unseen "$list" | head -40
)

if [ -z "$problems" ]; then rm -f "$list"; exit 0; fi
if [ "$again" = "true" ]; then
  rm -f "$list"
  jq -n '{systemMessage: "Code quality limits are still exceeded in files edited this turn."}'
  exit 0
fi
jq -n --arg reason "Code quality: you put these over the limits, or further over them, in this session.
$problems
Fix them: extract named helpers, flatten nesting, group parameters, split files by responsibility. Do not change behaviour." \
  '{decision: "block", reason: $reason}'
