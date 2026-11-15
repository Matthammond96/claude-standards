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
around them.

- **Small, simple functions.** At most 60 lines, a complexity of 10 (branches) and 5
  parameters. Over that, extract named helpers, flatten nesting or group parameters.
- **No file over 400 lines.** This covers source, tests, scripts, hand-written fixtures and
  ports of other libraries; only generated data and vendored code are exempt. Before
  finishing any task, run `wc -l` on every file you created or edited and split any that is
  over, by responsibility into named modules (never `part1`/`part2`). If a file you were
  asked to edit is already over the limit, say so and offer to split it; do not make it
  longer. Do not add a standards-checking script to the project for these limits: the hooks
  enforce them.
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
  CI for every language in it. No warnings left on.
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
- **READMEs stay current.** Every top-level directory has one that matches reality, and
  extension points have a "how to add one" guide.
- **Ready for strangers.** Structure, naming and docs should make sense to someone who has
  never seen the project.
