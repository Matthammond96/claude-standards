# Coding standards and practices

These apply to every project unless the project's own instructions say otherwise.

## How to work

- **Think before coding.** State your assumptions. If a request has more than one
  reasonable reading or a real trade-off, say so before building.
- **Simplicity first.** Write the least code that solves the problem correctly. No
  speculative features, options or abstractions nobody asked for. Simplicity never
  excuses a weaker answer: the right option wins even when it needs more.
- **Recommend on merit.** When offering options, recommend the one that is best for
  correctness, security and the people who use it. Never recommend one because it is
  already built, quicker or easier, and never offer that as a reason; say what is
  built apart from what is recommended. A brief to another agent never limits what a
  right answer may need ("don't add machinery", "keep it small"), and a delegated
  agent's recommendation is judged on its merits before it is passed on.
- **Surgical changes.** Change only what the task needs and match the existing style.
  Mention unrelated problems you notice; do not fix them unasked.
- **Goal-driven.** Turn the task into something checkable (a failing test, a measured
  number) and keep going until the check passes.
- **Read before writing.** Read the code around a change first, and search for a function,
  type or pattern that already does the job before writing a new one.
- **Review your own diff.** Before finishing, read the whole diff as a reviewer who has
  never seen the task, and fix what they would question.

## Code

Hooks installed with these standards format every file you edit and check its length, and
when you finish a turn they measure the functions in the files you touched. They judge how
the code is built, not whether it is correct: correctness is the job of the project's own
tests, type checker and linter, which you still run. Fix what the hooks report; do not work
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
- **No file over 400 lines.** This covers source, scripts, hand-written fixtures and ports
  of other libraries. Tests, generated data and vendored code are exempt: a test file
  follows the size of the code it tests, so keep the code well split instead. Before
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

## Structure

Decide where code belongs before writing it. An existing project's layout and its
language's conventions come first; these rules shape new projects, new areas and code that
has no layout yet. Scale them to the project: a three-file tool needs no folders.

- **One responsibility per file, named after it.** A file holds one main concept and its
  name is that concept (`parseConfig.ts` exports `parseConfig`), with the private helpers
  and types only it uses alongside. If you cannot describe a file without "and", it is two
  files. No grab-bag files: `utils`, `helpers`, `common`, `misc`, `shared`.
- **Folders group by responsibility, not by kind.** Group what changes together by feature
  or domain (`billing/`, `auth/`), not by what it is (`controllers/`, `types/`,
  `services/`). A recursive listing should read as a table of contents. Split a directory
  into named subdirectories once it mixes two concerns or passes about ten source files;
  do not create a folder for one file.
- **Dependencies point one way.** Entry points (CLI, HTTP handlers, UI) call domain logic;
  domain logic never imports them. Databases, network, filesystem and clock sit behind
  interfaces at the edges and are passed in. No import cycles.
- **Small public surface.** Export only what another module needs; everything else stays
  private. One area uses another through its public entry point, not its internals. Inside
  an area, import from the file that defines the thing: no barrel files that only
  re-export. A simple interface matters more than a simple implementation: a module that
  only passes calls through hides nothing.
- **Separate deciding from doing.** Keep the code that computes a result apart from the
  code that reads and writes. The deciding part is then pure and tested without mocks.
- **Validate at the boundary.** Parse outside input (requests, files, environment, API
  responses) into typed values where it enters; inside, trust the types. Never swallow an
  error: handle it where something can be done about it, or pass it up with context.
- **Tests mirror the code.** Each module's tests sit where the language's convention puts
  them and are named after the module, so either is found from the other.

## Readability

Code is read far more often than it is written, and it is too complex when a reader cannot
understand it quickly.

- **Obvious over clever.** Write the version a newcomer follows on the first read. If a
  piece is complex where its purpose is simple, look again for the simpler way.
- **Names carry the meaning.** Long enough to say what the thing is or does, one word for
  one thing across the codebase, unique enough to grep. No `data`, `info`, `manager`,
  `handle` or abbreviations that need explaining.
- **Comments explain why.** Never what the code does: if that needs saying, rename or
  restructure. Say why it is this way, what it must not break, and what a public function
  promises. Nothing about the change, story, ticket or bug that prompted it ("added",
  "fixed for the login bug"): that belongs in the commit message.
- **One job per function, at one level.** A function either orchestrates named steps or
  does one of them, not both. It either returns a value or changes something, and its name
  says which.
- **Top-down files.** The main thing a file exports comes first, the helpers it calls
  below, in the order they are called, so the file reads from intent to detail.
- **Types tell the truth.** Give every concept one named type and make invalid states
  impossible to build: a union of cases, not optional fields and flags that must agree. No
  `any`, untyped maps or stringly-typed values where a type fits.
- **No magic values or flag arguments.** A literal with meaning gets a named constant. A
  boolean that switches a function's behaviour becomes two functions or a named option.
- **No defensive noise.** Do not check for what the types rule out, catch what cannot be
  thrown, or add a fallback that hides a failure. Fail loudly at the point of the mistake.
- **Flat control flow.** Deal with errors and edge cases first and return; the main path
  stays unindented at the bottom. Nesting deeper than three levels becomes a named
  function.
- **Least mechanism.** Reach for a language feature, then the standard library, then a
  dependency the project already has, before adding a dependency or an abstraction.
- **Small, local state.** Immutable by default, declared where it is used and in the
  narrowest scope. No mutable module-level state; pass it in.

## Evidence

- **Measure before and after.** For a change meant to improve something, record the
  baseline first, then show the result against it.
- **Prefer real projects to synthetic tests** as evidence, and say which is which.
- **Tests must be able to fail.** A test fails when the code it covers breaks, and a bug
  fix comes with a test that failed before the fix.
- **Report plainly** what was verified, what failed and what was not run.

## Reviews

When work is split between a builder and an independent reviewer (another agent or
person), review where it finds the most for the least waiting.

- **Brief the builder with the reviewer's checklist.** The questions a reviewer will ask
  of this area (the method below, made specific) go into the builder's brief, so most of
  it is right the first time.
- **One full independent review per task**, once it is feature-complete, from a reviewer
  given the code and the promises, not the builder's conclusions.
- **A fix round that changes behaviour gets its own independent review**, scoped to the
  round's changes and the promises they touch, not the whole task again. Whoever
  coordinates first checks that each finding was addressed and its test failed first,
  but that check never stands in for the review: the coordinator holds the builder's
  framing and reads a fix as intended, and a fresh reviewer, at about the same cost,
  finds what it does. Only mechanical fixes (renames, docs, test-only changes) skip it.
- **One review of a set of related changes before it merges**, against the current main
  branch: what no single task's review can see, the changes' effects on each other and on
  what moved on main since they began.

How a reviewer finds what is wrong:

- **Start from the promises, not the diff.** List what the docs, the specification and
  the threat model promise in this area, and for each, find every path that keeps it,
  including code outside the diff that the change relies on or affects.
- **Read beyond the change.** Its callers and callees, the code it replaced, and what
  changed on the main branch since it began (formats, versions, interfaces).
- **Take each input's side.** For everything that crosses a trust boundary (network,
  files, other users, other processes, the environment), ask what a hostile or buggy
  sender can do: oversize, malformed, replayed, reordered, early, late, never.
- **Break the timeline.** A crash, restart, timeout or second client at every step: what
  is lost, held forever, done twice, or left in a state nothing recovers from.
- **Make the tests fail.** Remove each check the change adds and see which test fails;
  one that still passes proves nothing. Look for tests that hang instead of failing,
  that wait on time rather than a condition, or that pass whichever way a race goes.
- **Hold every word to what was seen.** Each message, log line and doc claim must be
  true in every case it can appear.
- **Read the builder's own notes as leads.** "Left alone", "for later", "couldn't test"
  and "already over the limit" are findings unless the reason holds.
- **Verify before reporting.** Settle doubts with a small experiment where it is cheap,
  say which findings were confirmed and which only read, and give the whole report in
  the final message.

## Repositories

- **Nothing leaks.** No names, data, paths or identifying details from other projects,
  private repositories or the local machine in code, tests, fixtures, docs or recordings.
  Use neutral, invented examples.
- **READMEs stay current.** Every top-level directory has one that says what the
  directory is for and matches reality, and extension points have a "how to add one"
  guide. Do not list the files: a list goes stale with the next rename.
- **Ready for strangers.** Structure, naming and docs should make sense to someone who has
  never seen the project.
