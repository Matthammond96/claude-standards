# Coding standards and practices

These apply to every project unless the project's own instructions say otherwise.

## How to work

- **Think before coding.** State your assumptions. If a request has more than one
  reasonable reading or a real trade-off, say so before building.
- **Simplicity first.** Write the least code that solves the problem. No speculative
  features, options or abstractions nobody asked for.
- **Surgical changes.** Change only what the task needs and match the existing style.
  Mention unrelated problems you notice; do not fix them unasked.
- **Goal-driven.** Turn the task into something checkable (a failing test, a measured
  number) and keep going until the check passes.

## Code

Hooks in `~/.claude/hooks/` format every file you edit and check its length, and when you
finish a turn they measure the functions in the files you touched. They judge how the code
is built, not whether it is correct: correctness is the job of the project's own tests,
type checker and linter, which you still run. Fix what the hooks report; do not work
around them. They report only what you made worse in the session, so what they report is
yours to fix.

- **Small, simple functions.** At most 60 lines, 5 parameters and a complexity (branches)
  of 10, or 15 in Go, where every error check is a branch. Over that, extract named
  helpers, flatten nesting or group parameters. A helper has to earn its name: do not
  split a function that reads well top to bottom only to get under a number. Functions in
  test files are not measured: a table of cases or a scenario is long by nature.
- **Leave old debt for its own change.** A function or file that was over a limit before
  you touched it stays as it is, unless the task is to fix it: do not make it worse, say
  that it is over, and offer to fix it separately. A refactor mixed into another change
  makes both harder to review.
- **No file over 400 lines.** This covers source, tests, scripts, hand-written fixtures and
  ports of other libraries; only generated data and vendored code are exempt. Before
  finishing any task, run `wc -l` on every file you created or edited and split any that is
  over, by responsibility into named modules (never `part1`/`part2`). The hooks check
  code and shell scripts; fixtures and other files are yours to check. Do not add a
  standards-checking script to the project for these limits: the hooks enforce them.
- **No loose scripts.** Tooling, build steps and test harnesses are written in the
  project's main typed language and designed like product code: typed data, shared
  modules, type-checked and linted by the same gates. In a TypeScript project that means
  `.ts`, never `.mjs`, `.cjs` or untyped `.js`.
- **One place for each rule.** Logic lives once. If two parts need the same rule, one
  owns it and the other calls it or is generated from it.
- **Generic over special-cased.** Solve the general problem. Do not pile up heuristics for
  individual edge cases; if a fix only helps one input, look for the underlying rule.
- **Keep the core neutral.** Language-, platform-, vendor- and tool-specific knowledge
  belongs at the edges (adapters, descriptors, config), passed in as data, not hard-coded
  in shared code.
- **Tools enforce the standards.** Formatter and linter configured in the repo and run in
  CI for every language in it. No warnings left on. The size limits above are the
  exception: the hooks hold you to them, so they are not added to the project's linter.
- **No dead code, stale comments or TODOs** in finished work.

## Evidence

- **Measure before and after.** For a change meant to improve something, record the
  baseline first, then show the result against it.
- **Prefer real projects to synthetic tests** as evidence, and say which is which.
- **Report plainly** what was verified, what failed and what was not run.

## Repositories

- **Nothing leaks.** No names, data, paths or identifying details from other projects,
  private repositories or the local machine in code, tests, fixtures, docs or recordings.
  Use neutral, invented examples.
- **READMEs stay current.** Every top-level directory has one that says what the
  directory is for and matches reality, and extension points have a "how to add one"
  guide. Do not list the files: a list goes stale with the next rename.
- **Ready for strangers.** Structure, naming and docs should make sense to someone who has
  never seen the project.
