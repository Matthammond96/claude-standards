# Shared by on-save.sh and on-stop.sh. Given $file, sets kind, dir and root, or returns 1
# for a file the hooks leave alone.
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

# Where the files edited in a session are remembered until the turn ends.
edited_list() { echo "${TMPDIR:-/tmp}/claude-on-save/${1:-unknown}.list"; }

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
