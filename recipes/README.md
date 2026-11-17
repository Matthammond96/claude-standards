# recipes

One recipe per coding agent the standards install into. A recipe says where the agent
keeps its instructions and hooks and what its hooks are called; the installer and the
hooks hold everything that is the same for every agent. The file's name is the
installer's flag: `codex.json` is `./install.sh --codex`.

Every recipe must match [recipe.schema.json](../recipe.schema.json), which describes each
field. The installer checks it before installing anything and says what is wrong.

## How to add one

The agent needs hooks that take JSON on stdin and register in a JSON file shaped like
Claude Code's (`{"hooks": {<event>: [{"matcher", "hooks": [{"type": "command", ...}]}]}}`),
and that accept `{"decision": "block", "reason": ...}` back.

1. Copy the recipe of the agent closest to yours to `recipes/<agent>.json`.
2. Set `home` to the agent's configuration directory and the environment variable that
   moves it, `instructions` to the file it reads into every session, and `hook_config` to
   the file that registers its hooks.
3. Under `events`, give the agent's event name, and tool matcher where it has one, for
   each moment it supports. A moment left out is not hooked; `after_edit` and `turn_end`
   are required.
4. Write `edited_files`: a jq filter that turns the agent's after-edit hook input into
   absolute paths of the files changed, one per output. Test it on a real input:
   `jq -r '<filter>' < input.json`.
5. Put anything the user must do by hand afterwards, such as trusting the hooks, in
   `after_install`.
6. Run `./install.sh --<agent>`, edit a file through the agent and check it is formatted
   and that a file over 400 lines is reported.
