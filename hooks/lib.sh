# Shared by the hooks. Given $file, classify sets kind, dir and root, or returns 1 for a
# file the hooks leave alone.
classify() {
  [ -n "$file" ] && [ -f "$file" ] || return 1
  case "$file" in
    */node_modules/*|*/vendor/*|*/dist/*|*/build/*|*/target/*|*/.git/*|*/.venv/*|*/recordings/*|*.min.*|*.lock|*-lock.json|*.snap) return 1 ;;
  esac
  case "${file##*.}" in
    ts|tsx|mts|cts|js|jsx|mjs|cjs) kind=js ;;
    py) kind=py ;;
    rs) kind=rs ;;
    go) kind=go ;;
    sh|bash|zsh) kind=sh ;;
    json|css|scss|yaml|yml|html) kind=text ;;
    *) return 1 ;;
  esac
  # The project root: the nearest directory above the file that holds a repository.
  dir=$(cd "$(dirname "$file")" && pwd)
  root="$dir"
  while [ "$root" != "/" ] && [ ! -e "$root/.git" ]; do root=$(dirname "$root"); done
  [ "$root" = "/" ] && root="$dir"
  cd "$root"
}

# Whether the functions of a file of this kind can be measured (lizard reads it).
measured() { case "$kind" in js|py|rs|go) return 0 ;; esac; return 1; }

# A test file: neither its functions nor its length are measured. A table of cases or a
# scenario walked through step by step is long and branchy by nature, and a test file
# follows the size of the code it tests.
is_test() {
  case "$file" in
    *_test.go|*.test.*|*.spec.*|*/test_*.py|*_test.py|*/tests/*|*/test/*|*/__tests__/*) return 0 ;;
  esac
  return 1
}

# The complexity limit for a file of this kind. Go's is higher: every `if err != nil`
# is a branch, so a function that only does six fallible things in a row is already at 7.
# CLAUDE_QUALITY_COMPLEXITY sets one limit for every language.
complexity_limit() {
  if [ -n "${CLAUDE_QUALITY_COMPLEXITY:-}" ]; then echo "$CLAUDE_QUALITY_COMPLEXITY"; return; fi
  case "$kind" in
    go) echo 15 ;;
    *) echo 10 ;;
  esac
}

# The nearest file of one of these names between the edited file and the root.
nearest() {
  local d="$dir" name
  while :; do
    for name in "$@"; do [ -e "$d/$name" ] && { echo "$d/$name"; return 0; }; done
    [ "$d" = "$root" ] || [ "$d" = "/" ] && return 1
    d=$(dirname "$d")
  done
}

# A project-local program, else one on the PATH.
tool() {
  local p; p=$(nearest "node_modules/.bin/$1" ".venv/bin/$1") && { echo "$p"; return 0; }
  command -v "$1" 2>/dev/null
}

limited() { if command -v timeout >/dev/null 2>&1; then timeout 20 "$@"; else "$@"; fi; }
configured() { grep -qs "$1" "$root/pyproject.toml" "$dir/pyproject.toml" 2>/dev/null; }
uses_ruff() { nearest ruff.toml .ruff.toml >/dev/null || configured '^\[tool\.ruff'; }
uses_biome() { nearest biome.json biome.jsonc >/dev/null; }

# Formats $file with the project's own formatter. Nothing is installed or guessed: a tool
# runs only when the project has it configured.
format_file() {
  local p manifest edition
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
  return 0
}

# What a session keeps until it ends, by name: the files edited (list), what it has been
# told (seen), when its shell command started (mark) and the files as they were (base).
session_file() { echo "${TMPDIR:-/tmp}/claude-on-save/${1:-unknown}.$2"; }
edited_list() { session_file "$1" list; }

# Where $file is kept as it was before the session touched it.
baseline() { echo "${1%.list}.base/$(printf '%s' "$file" | cksum | cut -d' ' -f1).${file##*.}"; }

# Records $file (classified) as edited in the session whose list is $1. The first time, it
# keeps the file as committed, so the checks can tell what the session made worse from
# what was already there. A file with no committed version is all the session's.
remember() {
  local list="$1" base
  mkdir -p "$(dirname "$list")" && echo "$file" >> "$list"
  base=$(baseline "$list")
  { [ -e "$base" ] || [ -e "$base.none" ]; } && return 0
  mkdir -p "$(dirname "$base")"
  git -C "$root" show "HEAD:${file#"$root"/}" > "$base" 2>/dev/null || { rm -f "$base"; : > "$base.none"; }
}

# Says so, as one "<file>  length: ..." line, when $file is over the length limit and
# longer than it was before the session whose list is $1.
too_long() {
  local max="${CLAUDE_ONSAVE_MAX_LINES:-400}" lines was=0 base
  [ "$kind" = "text" ] && return 0
  is_test && return 0
  lines=$(wc -l < "$file" | tr -d ' ')
  [ "$lines" -gt "$max" ] || return 0
  base=$(baseline "$1")
  [ -f "$base" ] && was=$(wc -l < "$base" | tr -d ' ')
  [ "$lines" -gt "$was" ] || return 0
  if [ "$was" -gt "$max" ]; then
    echo "$file  length: $lines lines; the limit is $max and it was already $was. Do not make it longer: move what you added into a named module, and tell the user the file needs splitting."
  else
    echo "$file  length: $lines lines; the limit is $max. Split it by responsibility into named modules."
  fi
}

# Report each thing once per session: prints only the lines of stdin whose key (the line
# without its ":<line number>") this session has not been told about yet.
unseen() {
  local seen="${1%.list}.seen" line key
  touch "$seen"
  while IFS= read -r line; do
    key=$(printf '%s' "$line" | sed -E 's/:[0-9]+  /  /; s/: .*//')
    grep -qxF -- "$key" "$seen" || { echo "$key" >> "$seen"; printf '%s\n' "$line"; }
  done
}
