# claude-standards

Coding standards for every coding-agent session on a machine (Claude Code, Codex), and the
hooks that hold the agent to them.

- **[standards.md](standards.md)**: the rules, installed into the agent's instructions
  (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`) so every session reads them.
- **[recipes/](recipes/)**: one recipe per agent, saying where it keeps its instructions
  and hooks and what its hooks are called, checked against
  [recipe.schema.json](recipe.schema.json). To support another agent, add a recipe.
- **[hooks/on-save.sh](hooks/on-save.sh)**: after each file the agent edits, formats it with
  the project's own formatter (Prettier, Biome, Ruff, Black, rustfmt, gofmt; only when the
  project has it configured) and reports a code file over 400 lines (tests and
  Markdown are exempt).
- **[hooks/on-shell.sh](hooks/on-shell.sh)**: around each shell command Claude runs, finds
  the files the command changed (with `sed`, a script, a heredoc) and treats them as
  edited too.
- **[hooks/on-stop.sh](hooks/on-stop.sh)**: when a turn ends, measures the functions in the
  files edited during it and reports any over 60 lines, 5 parameters or the complexity
  limit of its language.

The hooks judge how code is built, not whether it is correct, and report each problem once
per session. Nothing is added to any project.

## What counts

- **Only what the session made worse.** The first time a session touches a file, the hooks
  keep it as committed (`HEAD`). A function or file that was already over a limit, and is
  no further over it, is not reported; one that grew is, with what it was. A file with no
  committed version is all the session's.
- **Complexity is per language**: 10, and 15 in Go, where every `if err != nil` is a
  branch. To add or change one, edit `complexity_limit` in
  [hooks/lib.sh](hooks/lib.sh).
- **Test files** (`_test.go`, `.test.*`, `.spec.*`, `test_*.py`, `tests/`, `__tests__/`)
  are measured for neither their functions nor their length: a test file follows the
  size of the code it tests, so keep that code well split instead.
- **File length** is checked for JavaScript, TypeScript, Python, Rust, Go and shell;
  functions are measured for all of those but shell.
- **Shell edits** are seen in the repository the session runs in. A file changed in
  another repository, or committed by the same command that changed it, is not.

To support another language, give its extensions a kind in `classify`
([hooks/lib.sh](hooks/lib.sh)), add its formatter to `format_file`, and add the kind to
`measured` if [lizard reads it](https://github.com/terryyin/lizard#languages).

## Install

Needs `jq` and `python3` (with `venv`).

```sh
git clone git@github.com:Matthammond96/claude-standards.git
claude-standards/install.sh --claude-code --codex
```

Name one or more agents; each is a recipe in [recipes/](recipes/), and `./install.sh` alone
lists them. For each agent, in its directory (`~/.claude`, `~/.codex`), the installer:

1. copies the hooks, and the agent's recipe, to `hooks/`;
2. installs the analyser ([lizard](https://github.com/terryyin/lizard), pinned) into a
   private virtualenv at `hooks/.venv`;
3. writes the standards into the agent's instructions (`CLAUDE.md`, `AGENTS.md`) between
   `<!-- claude-standards:begin -->` and `<!-- claude-standards:end -->`, keeping whatever
   else the file holds;
4. registers the hooks in the agent's hook config (`settings.json`, `hooks.json`), keeping
   every other setting and hook.

Restart running sessions afterwards. Codex runs only hooks you have trusted: review them
with `/hooks`. The agent's own variable (`CLAUDE_CONFIG_DIR`, `CODEX_HOME`) installs
somewhere else.

## Update

Edit the standards, hooks or recipes here, never the installed copies, then on each
machine:

```sh
git pull && ./install.sh --claude-code --codex
```

Running the installer again replaces what it installed before.

## Uninstall

```sh
./install.sh --claude-code --codex --uninstall
```

## Switches

Environment variables, read by the hooks:

| Variable | Effect | Default |
|---|---|---|
| `CLAUDE_ONSAVE=0` | turns both hooks off | on |
| `CLAUDE_QUALITY=0` | turns the end-of-turn function check off | on |
| `CLAUDE_ONSAVE_MAX_LINES` | file length limit | 400 |
| `CLAUDE_QUALITY_FUNCTION_LINES` | function length limit | 60 |
| `CLAUDE_QUALITY_COMPLEXITY` | one complexity limit for every language | 10, Go 15 |
| `CLAUDE_QUALITY_PARAMS` | parameter limit | 5 |
