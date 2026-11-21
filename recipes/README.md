# recipes

One recipe per coding agent the standards install into. A recipe says where the agent
keeps its instructions and hooks and what its hooks are called; the installer and the
hooks hold everything that is the same for every agent. The file's name is the
installer's flag: `codex.json` is `./install.sh --codex`.

Every recipe must match [recipe.schema.json](../recipe.schema.json), which describes each
field. The installer checks it before installing anything and says what is wrong.

## How to add one

The agent needs hooks that take JSON on stdin, return JSON on stdout, and register in a
JSON config file. Defaults match Claude Code's format (`{"hooks": {<event>: [{"matcher",
"hooks": [{"type": "command", ...}]}]}}`, `.session_id`, `.stop_hook_active`,
`{"decision": "block", "reason": ...}`); agents that differ (like Antigravity) override
those fields in `hook_section`, `status_message`, `events.<moment>.flat`, `input` and
`output`.

1. Copy the recipe of the agent closest to yours to `recipes/<agent>.json`.
2. Set `home` to the agent's configuration directory (and the environment variable that
   moves it, if it has one), `instructions` to the file it reads into every session, and
   `hook_config` to the file that registers its hooks.
3. Under `events`, give the agent's event name, and tool matcher where it has one, for
   each moment it supports. A moment left out is not hooked; `after_edit` and `turn_end`
   are required. Set `"flat": true` on events whose handlers sit directly in the event
   array without a `{"hooks": [...]}` wrapper.
4. Write `edited_files`: a jq filter that turns the agent's after-edit hook input into
   absolute paths of the files changed, one per output. Test it on a real input:
   `jq -r '<filter>' < input.json`.
5. If the agent uses different stdin field names or stdout responses, set `input` and
   `output` (see [recipe.schema.json](../recipe.schema.json)). If `after_edit` cannot
   return messages, set `"edit_block": ""` so file-length warnings wait for `turn_end`.
6. Put anything the user must do by hand afterwards, such as trusting the hooks, in
   `after_install`.
7. Run `./install.sh --<agent>`, edit a file through the agent and check it is formatted
   and that a file over 400 lines is reported.
