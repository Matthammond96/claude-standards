# claude-standards

Coding standards for every Claude Code session on a machine, and the hooks that hold Claude
to them.

- **[standards.md](standards.md)**: the rules, installed into `~/.claude/CLAUDE.md` so every
  session reads them.
- **[hooks/on-save.sh](hooks/on-save.sh)**: after each file Claude edits, formats it with
  the project's own formatter (Prettier, Biome, Ruff, Black, rustfmt, gofmt; only when the
  project has it configured) and reports a file over 400 lines.
- **[hooks/on-stop.sh](hooks/on-stop.sh)**: when a turn ends, measures the functions in the
  files edited during it and reports any over 60 lines, a complexity of 10 or 5 parameters.

The hooks judge how code is built, not whether it is correct, and report each problem once
per session. Nothing is added to any project.

## Install

Needs `jq` and `python3` (with `venv`).

```sh
git clone git@github.com:Matthammond96/claude-standards.git
claude-standards/install.sh
```

The installer:

1. copies the hooks to `~/.claude/hooks/`;
2. installs the analyser ([lizard](https://github.com/terryyin/lizard), pinned) into a
   private virtualenv at `~/.claude/hooks/.venv`;
3. writes the standards into `~/.claude/CLAUDE.md` between
   `<!-- claude-standards:begin -->` and `<!-- claude-standards:end -->`, keeping whatever
   else the file holds;
4. registers the hooks in `~/.claude/settings.json`, keeping every other setting and hook.

Restart running Claude Code sessions afterwards. Set `CLAUDE_CONFIG_DIR` to install
somewhere other than `~/.claude`.

## Update

Edit the standards or hooks here, never the installed copies, then on each machine:

```sh
git pull && ./install.sh
```

Running the installer again replaces what it installed before.

## Uninstall

```sh
./install.sh --uninstall
```

## Switches

Environment variables, read by the hooks:

| Variable | Effect | Default |
|---|---|---|
| `CLAUDE_ONSAVE=0` | turns both hooks off | on |
| `CLAUDE_QUALITY=0` | turns the end-of-turn function check off | on |
| `CLAUDE_ONSAVE_MAX_LINES` | file length limit | 400 |
| `CLAUDE_QUALITY_FUNCTION_LINES` | function length limit | 60 |
| `CLAUDE_QUALITY_COMPLEXITY` | complexity limit | 10 |
| `CLAUDE_QUALITY_PARAMS` | parameter limit | 5 |
