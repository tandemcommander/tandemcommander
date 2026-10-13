# Brief for the work of feature 131 (defects found by feature 130)

Repository `E:\Projects\tandemcommander` (Tandem Commander, WinAPI C++, derived from Open
Salamander). Branch `131-plugin-defect-batch`. Read `CLAUDE.md` first - its *Standing rules* and
*Working method* bind this work.

Feature 130 read every plug-in and wrote down defects it saw but did not fix (the sections
"Other defects seen" of `specs/130-plugin-mixed-templates/triage/<plugin>.md`, and the list in
`specs/NEXT-WORK.md`, section D, under "feature 130"). They were **seen by reading, not
measured** - several are marked "suspected". You get a named set of them.

## For every item, in this order

1. **Measure first.** Read the code until you know: is the defect real? Is it reachable - by
   what user action and input (give the action, the input, and what the user sees or loses)?
   Where reading is not enough, prove it with a small test program of your own (compile and run
   it under your own temporary directory **outside the repository**; `cl` is available through
   a Visual Studio developer prompt - `vswhere` finds it). An item that turns out not to be a
   defect, or not reachable, is a finding: record it and change nothing.
2. **Fix it minimally**, in the plug-in's own directory, matching the surrounding code.
3. **Record it** (below).

## Rules of the fix

- **A path or name is never cut.** A path that does not fit is refused with a message (an
  existing string of that plug-in or of the core; look for "too long" texts) or kept in a heap
  buffer / a buffer of the right size (`SAL_MAX_PATH_UTF8`-like constants: look at what the
  plug-in already uses; plug-ins have `U8_MAX_PATH` or similar in places). Text that is only
  *shown* may be shortened at a whole character (`SplU8TrimTornTail`, `SplU8CopyTrunc` in
  `src/plugins/shared/splunicode.h`).
- A "refusal" must fail closed: the operation does not run on a shortened path, nothing is
  created, deleted or overwritten under a wrong name.
- Paths and names are UTF-8 (WTF-8); never pass them to an `A` API or convert them with
  `CP_ACP`. Wide file calls: `SplU8ToWExtAlloc` etc.
- **No new resource strings** (a new string breaks the build of all translations) - reuse an
  existing one; if none fits, say so in the record and pick the nearest existing text. No change
  of the plug-in interface. No change outside the directories given to you (and none in
  `src/plugins/shared/`, `src/common/`, the core) - if a fix needs one, describe it in the
  record and stop there for that item.
- An unbounded `sprintf` / `vsprintf` / `strcpy` into a fixed buffer becomes a bounded call; when
  the text is UTF-8 and may be cut, trim the tail **only when it was cut**.
- Pure decisions (a rule that can be stated without windows or files) are best written as a
  small `inline` function so that a unit check can be added later - say in the record which
  ones you made and what cases a check should cover.
- New comments in English, short, `feature 131` where the reason is not obvious. Sources are
  UTF-8 (some with BOM), LF or CRLF as each file already is - keep both; edit with the Edit
  tool, exact replacements; never rewrite a whole file; do not use Bash here-documents to write
  files (doubled backslashes collapse).

## Hard limits

- **Do not build the repository, do not run the program, no GUI, no registry, no git command
  that changes anything.** Other agents work in other directories of the same tree at the same
  time.

## The record

One file per plug-in: `specs/131-plugin-defect-batch/items/<plugin>.md`, one section per item:

- what the note of 130 said, and what you found (real / not a defect / unreachable), with
  file:line evidence;
- how a user reaches it: action, input, visible effect before the fix;
- the fix (files, what the code does now), or why nothing was changed;
- how to test it: a GUI probe row a person could automate (action, input, expected text or
  state), and, where it applies, the unit cases;
- what you are not sure about.

Your final message: per item one line - verdict (FIXED / NOT A DEFECT / UNREACHABLE / NEEDS A
CHANGE OUTSIDE MY DIRECTORIES / LEFT, why), the easiest items to probe, and the uncertainties
with file:line. Do not claim more than you read or ran.
