#!/bin/bash
# Install the coding standards and their hooks into Claude Code's user settings
# (~/.claude, or $CLAUDE_CONFIG_DIR). Safe to run again: it replaces what it installed
# before and leaves everything else in CLAUDE.md and settings.json as it was.
#   ./install.sh             install or update
#   ./install.sh --uninstall remove it
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
target="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
lizard_version="1.26.0"
begin="<!-- claude-standards:begin -->"
end="<!-- claude-standards:end -->"

need() { command -v "$1" >/dev/null 2>&1 || { echo "install: $1 is required" >&2; exit 1; }; }

# CLAUDE.md without the section between the markers.
without_section() {
  [ -f "$target/CLAUDE.md" ] || return 0
  awk -v b="$begin" -v e="$end" '$0 == b { skip = 1 } !skip { print } $0 == e { skip = 0 }' \
    "$target/CLAUDE.md"
}

write_standards() {
  local rest; rest=$(without_section)
  {
    [ -n "$rest" ] && printf '%s\n\n' "$rest"
    [ "$1" = "with" ] && { echo "$begin"; cat "$here/standards.md"; echo "$end"; }
    true
  } > "$target/CLAUDE.md.new"
  mv "$target/CLAUDE.md.new" "$target/CLAUDE.md"
}

install_hooks() {
  mkdir -p "$target/hooks"
  cp "$here"/hooks/*.sh "$target/hooks/"
  chmod +x "$target/hooks/on-save.sh" "$target/hooks/on-stop.sh"
  local venv="$target/hooks/.venv"
  if [ "$("$venv/bin/lizard" --version 2>/dev/null)" != "$lizard_version" ]; then
    python3 -m venv "$venv"
    "$venv/bin/pip" install --quiet "lizard==$lizard_version"
  fi
}

# settings.json with our hook entries removed and, for "with", added again.
write_settings() {
  local settings="$target/settings.json"
  [ -f "$settings" ] || echo '{}' > "$settings"
  jq --arg mode "$1" --arg dir "$target/hooks" '
    def ours: any(.hooks[]?; (.command // "") | test("/hooks/on-(save|stop)\\.sh$"));
    def entry(name; seconds; status):
      {hooks: [{type: "command", command: ($dir + "/" + name), timeout: seconds, statusMessage: status}]};
    def without(event): (.hooks[event] // []) | map(select(ours | not));
    .hooks = (.hooks // {})
    | .hooks.PostToolUse = without("PostToolUse")
    | .hooks.Stop = without("Stop")
    | .hooks.SubagentStop = without("SubagentStop")
    | if $mode == "with" then
        .hooks.PostToolUse += [{matcher: "Edit|Write|MultiEdit"} + entry("on-save.sh"; 60; "Formatting and checking...")]
        | .hooks.Stop = [entry("on-stop.sh"; 120; "Checking code quality...")] + .hooks.Stop
        | .hooks.SubagentStop += [entry("on-stop.sh"; 120; "Checking code quality...")]
      else . end
    | .hooks |= with_entries(select(.value | length > 0))
    | if .hooks == {} then del(.hooks) else . end
  ' "$settings" > "$settings.new"
  mv "$settings.new" "$settings"
}

need jq
mkdir -p "$target"
if [ "${1:-}" = "--uninstall" ]; then
  write_standards without
  write_settings without
  rm -rf "$target/hooks/.venv" "$target"/hooks/{lib,on-save,on-stop}.sh
  echo "removed from $target"
else
  need python3
  install_hooks
  write_standards with
  write_settings with
  echo "installed in $target (restart Claude Code sessions to pick it up)"
fi
