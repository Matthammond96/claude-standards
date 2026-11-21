#!/bin/bash
# Install the coding standards and their hooks into the user settings of coding agents,
# each described by a recipe in recipes/ and named by its file (recipes/codex.json is
# --codex). Safe to run again: it replaces what it installed before and leaves everything
# else in the agent's instructions and hook config as it was.
#   ./install.sh --claude-code --codex        install or update for these agents
#   ./install.sh --codex --uninstall          remove it from these agents
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
lizard_version="1.26.0"
begin="<!-- claude-standards:begin -->"
end="<!-- claude-standards:end -->"

# Which hook runs at each moment a recipe can name, in the order they are registered.
# turn_end goes before the agent's other turn-end hooks, so its request to keep going is
# not lost behind theirs.
roles='{
  "before_shell": {"command": "on-shell.sh before", "timeout": 10},
  "after_edit": {"command": "on-save.sh", "timeout": 60, "status": "Formatting and checking..."},
  "after_shell": {"command": "on-shell.sh after", "timeout": 60},
  "turn_end": {"command": "on-stop.sh", "timeout": 120, "status": "Checking code quality...", "first": true},
  "subagent_end": {"command": "on-stop.sh", "timeout": 120, "status": "Checking code quality..."}
}'

need() { command -v "$1" >/dev/null 2>&1 || { echo "install: $1 is required" >&2; exit 1; }; }

usage() {
  local agents; agents=$(cd "$here/recipes" && ls -- *.json | sed 's/^/--/; s/\.json$//' | tr '\n' ' ')
  echo "usage: install.sh [--uninstall] <agent>...    agents: $agents" >&2
  exit 1
}

# Stops the installer, saying why, when recipe $1 does not match recipe.schema.json.
check_recipe() {
  local problems; problems=$(recipe_problems "$here/recipes/$1.json")
  [ -z "$problems" ] && return 0
  printf 'install: recipes/%s.json does not match recipe.schema.json:\n%s\n' "$1" "$problems" >&2
  exit 1
}

# What is wrong with recipe file $1, one problem a line. Reads the parts of JSON Schema
# that recipe.schema.json uses: object, string and boolean types, required, unknown fields
# and $ref.
recipe_problems() {
  jq -r --slurpfile schema "$here/recipe.schema.json" '
    def problems($s; $at):
      . as $value
      | if $s["$ref"] then problems($schema[0] | getpath($s["$ref"] | ltrimstr("#/") | split("/")); $at)
        elif $s.type == "string" then (if type == "string" then empty else "\($at) must be a string" end)
        elif $s.type == "boolean" then (if type == "boolean" then empty else "\($at) must be a boolean" end)
        elif type != "object" then "\($at) must be an object"
        elif $s.properties | not then empty
        else
          ($s.required[]? | select(in($value) | not) | "\($at).\(.) is missing"),
          (keys[] | select(in($s.properties) | not) | "\($at).\(.) is not a known field"),
          (to_entries[] | select(.key | in($s.properties))
            | . as {key: $key, value: $field} | $field | problems($s.properties[$key]; "\($at).\($key)"))
        end;
    problems($schema[0]; "")' "$1"
}

# Reads recipe $1 into recipe (its file), target (the agent's directory), instructions and
# hook_config.
load_recipe() {
  recipe="$here/recipes/$1.json"
  local variable default
  variable=$(jq -r '.home.variable // empty' "$recipe")
  default=$(jq -r .home.default "$recipe")
  target="${default/#\~/$HOME}"
  [ -n "$variable" ] && [ -n "${!variable:-}" ] && target="${!variable}"
  instructions="$target/$(jq -r .instructions "$recipe")"
  hook_config="$target/$(jq -r .hook_config "$recipe")"
}

install_into() {
  install_hooks
  write_standards with
  write_hook_config with
  echo "installed for $(jq -r .name "$recipe") in $target. $(jq -r '.after_install // ""' "$recipe")"
}

uninstall_from() {
  write_standards without
  write_hook_config without
  rm -rf "$target/hooks/.venv" "$target"/hooks/{lib,on-save,on-shell,on-stop}.sh "$target/hooks/recipe.json"
  echo "removed from $(jq -r .name "$recipe") in $target"
}

# The hooks, and the recipe they read to find the files an edit changed.
install_hooks() {
  mkdir -p "$target/hooks"
  cp "$here"/hooks/*.sh "$target/hooks/"
  cp "$recipe" "$target/hooks/recipe.json"
  chmod +x "$target"/hooks/on-*.sh
  local venv="$target/hooks/.venv"
  if [ "$("$venv/bin/lizard" --version 2>/dev/null)" != "$lizard_version" ]; then
    python3 -m venv "$venv"
    "$venv/bin/pip" install --quiet "lizard==$lizard_version"
  fi
}

# The instructions file without the section between the markers.
without_section() {
  [ -f "$instructions" ] || return 0
  awk -v b="$begin" -v e="$end" '$0 == b { skip = 1 } !skip { print } $0 == e { skip = 0 }' \
    "$instructions"
}

write_standards() {
  local rest; rest=$(without_section)
  {
    [ -n "$rest" ] && printf '%s\n\n' "$rest"
    [ "$1" = "with" ] && { echo "$begin"; cat "$here/standards.md"; echo "$end"; }
    true
  } > "$instructions.new"
  mv "$instructions.new" "$instructions"
}

# The hook config with our hooks removed and, for "with", registered again at each moment
# the recipe names.
write_hook_config() {
  mkdir -p "$(dirname "$hook_config")"
  [ -f "$hook_config" ] || echo '{}' > "$hook_config"
  jq --arg mode "$1" --arg dir "$target/hooks" --argjson roles "$roles" --slurpfile recipe "$recipe" '
    def is_ours: (.command // "") | test("/hooks/on-(save|stop|shell)\\.sh( |$)");
    def ours: is_ours or any(.hooks[]?; is_ours);
    def handler($role):
      {type: "command", command: ($dir + "/" + $role.command), timeout: $role.timeout}
      + (if $role.status and ($recipe[0].status_message != false) then {statusMessage: $role.status} else {} end);
    def entry($role; $at):
      if $at.flat then handler($role)
      else ($at | if .matcher then {matcher} else {} end) + {hooks: [handler($role)]} end;
    def register($section; $role; $at):
      if $role.first then .[$section][$at.event] = [entry($role; $at)] + (.[$section][$at.event] // [])
      else .[$section][$at.event] += [entry($role; $at)] end;
    ($recipe[0].hook_section // "hooks") as $section
    | ($recipe[0].events) as $events
    | .[$section] = ((.[$section] // {}) | map_values(if type == "array" then map(select(ours | not)) else . end))
    | if $mode == "with" then
        reduce ($roles | to_entries[] | select(.key | in($events))) as $r
          (.; register($section; $r.value; $events[$r.key]))
      else . end
    | .[$section] |= with_entries(select((.value | type) != "array" or (.value | length) > 0))
    | if (.[$section] | to_entries | all((.value | type) != "array")) then del(.[$section]) else . end
  ' "$hook_config" > "$hook_config.new"
  mv "$hook_config.new" "$hook_config"
}

need jq
mode=with
agents=()
for arg in "$@"; do
  case "$arg" in
    --uninstall) mode=without ;;
    --*) [ -f "$here/recipes/${arg#--}.json" ] || usage; agents+=("${arg#--}") ;;
    *) usage ;;
  esac
done
[ "${#agents[@]}" -gt 0 ] || usage
[ "$mode" = "without" ] || need python3
for agent in "${agents[@]}"; do check_recipe "$agent"; done
for agent in "${agents[@]}"; do
  load_recipe "$agent"
  mkdir -p "$target"
  if [ "$mode" = "with" ]; then install_into; else uninstall_from; fi
done
