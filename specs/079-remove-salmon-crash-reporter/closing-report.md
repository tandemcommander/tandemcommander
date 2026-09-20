# Closing report — 079 Remove the salmon.exe Crash Reporter

**Date**: 2026-09-19 | **Branch**: `079-remove-salmon-crash-reporter` |
**Version**: unchanged, 0.1.8 / build 192 (`[Unreleased]` in `CHANGELOG.md`)

## What changed

- **Removed**: the out-of-process crash reporter — `src/salmon/` (16
  files), `src/vcxproj/salmon/` (5), `src/salmoncl.cpp/.h`, the `salmon`
  project and its 10 configuration lines in `salamand.sln`, the dialog
  `IDD_SALMON_MAIN` (+ 11 control ids), 40 `IDS_SALMON_*` string lines and
  41 defines, the `salmon` rows of both base-address tables, the checker
  exclusion, the icon-generator target and three README mentions. The
  application no longer starts, waits for or talks to a helper, never reads
  or writes `HKCU\Software\Tandem Commander\Bug Reporter`, and never scans
  the report folder at start-up. `CProcessListItem::SalmonPID` is
  `Reserved1` (same offset, always 0), so a 0.1.8 instance and this build
  share the process list; `tools/salbreak` mirrors it.
- **Added in-process**: `SalFormatBugReportName` (`src/common/salbugreport.*`,
  22 saltests checks), report path resolution with on-demand creation of
  `%LOCALAPPDATA%\Tandem Commander` (previously a report was silently lost
  when the folder did not exist), `CreateFileW` with a wide path, and the
  closing message (`IDS_BUGREPORT_SAVED` / `_NOTSAVED`, `LoadStringW`, English
  fallback) shown from the bug-report thread through a `MessageDone`
  handshake; `HandleException` gained a re-entry guard for a nested fault on
  the handling thread, a guard for a crash inside the bug-report thread, and
  the inline fallback marks its thread `DontSuspend` (see below). Exit code
  stays 1. `EnableExceptionsOn64` lives in `salamdr1.cpp` now.
- **Build**: `build.cmd` deletes a stale `utils\salmon.exe/.pdb` and the
  helper's Intermediate scaffolding from older output trees (MSBuild rebuild
  cleans only projects still in the solution; the installer packages the tree).
- **Translations**: 8 enabled languages refreshed twice (2 new strings; 52
  rows removed); de/fr/nl/es pinned to the formal register.
- **Records**: `CHANGELOG.md` `[Unreleased]` (Removed / Changed), `CLAUDE.md`
  (counts, tree, 077 note, 079 paragraph), `architecture/01`, `/02`, two
  help pages (Task List Break), `specs/NEXT-WORK.md` (077 items 2 and 3
  closed), this feature's `fix-log.md`, `quickstart.md`, contracts.

## What was verified (final gate, final sources)

| Check | Result |
|-------|--------|
| `build.cmd full` (Debug) | BUILD SUCCEEDED, 189 language modules, encoding guard strict TOTAL: 0 |
| `build.cmd full release` | BUILD SUCCEEDED, 189 language modules, VC runtime 4 files, closure OK (219 modules, 59 imports) |
| `saltests.exe` | 1427 checks, 0 failed (baseline 1405 + 22) |
| Helper files in trees | Debug 0, Release 0; `utils\` keeps sqlite (Debug also its .pdb/.lib/.exp) |
| Crash probe, Debug, app / plugin (zip.spl) | 3/3 and 3/3: report with `execution address`, message names the path, BM_CLICK dismissal, exit code 1, no helper process |
| Crash probe, Release, app | OK (report 28,163 bytes, exit code 1) |
| Report folder not writable | OK: "could not be saved" message names the intended path, exit code 1 |
| Start-up with 3 stale reports (Debug ×3, Release ×1) | OK: no dialog, one process, responding in <1 s, files untouched |
| Start-up with a fresh registry (×2) | OK: no dialog, one process; backup/restore verified key by key (389 subkeys, `Language = czech.slg`) |
| Task List Break (`tools/salbreak`) | OK: break exception → report → message → exit code 1 |
| Signing inventory (`-VerifyOnly`) | 215 candidates, none naming the helper |
| `salamand.sln`, `tandemcommander.iss` | 0 matches |
| Repository grep | only `CLAUDE.md` (record), `build.cmd` (cleanup stage), and the 3 disabled languages' retained `salamand.slt` |
| Icons | `gen_icons.py` regenerates byte-identical |
| Plugin ABI / config version | untouched (interface 106; no `THIS_CONFIG_VERSION` change) |

## Found on the way

- **Fallback defect, fixed before shipping**: with the report folder
  unusable, the first design retried inline and showed the message on the
  crashed UI thread; the box was created but never became visible because
  `CCallStack::Push` suspends a thread that enters a call-stack macro while an
  exception is active unless its stack is marked `DontSuspend` — the thread
  suspended itself inside its own modal loop. Now the bug-report thread
  (created with `DontSuspend`) shows the message in both outcomes; the
  remaining inline fallback (thread unusable) marks its thread first.
  Contract C4 records it.
- **Translation tooling** (not fixed, out of scope): `translate.merge`
  ignores `OPENSAL_BUILD_DIR` (pass `--templates`), and its identity for
  string-table rows is the *bundle ordinal*, so removing whole 16-id bundles
  displaced 46 rows per language into DeepL (human translations included);
  repaired from HEAD by script, dry run 0 gaps. Details and the 27,512-character
  cost in the fix-log. DeepL also returned the informal register for long
  de/fr/nl/es texts (pinned).
- **Debug-CRT leak box at exit** on first-run paths: dump captured — one
  88-byte zeroed block, `#File Error#(84)` — byte-identical to the block
  feature 078 recorded before this feature; pre-existing, unrelated.
- **Probe lessons** (recorded in memory and in the fix-log): PowerShell
  binds `$null` to `""` for string P/Invoke parameters; a MessageBox ignores a
  posted `WM_COMMAND/IDOK` (click its button); `reg.exe` reports success on
  stderr; the Bash tool collapses `\\` in heredocs.

## Owed to a human

- The antivirus re-test on a machine where the helper was flagged
  (Avast/others): install the next release and confirm no block. Nothing
  in this feature can prove a heuristic verdict.
- The clean-Windows start still owed from 077 (redistributable absent).
- The three disabled languages (chinesesimplified, russian, ukrainian) still
  carry the removed strings in their retained `salamand.slt`; refresh them
  when they are re-enabled (already a precondition since 056).

## Next

Ship gate: bump the version and move the `[Unreleased]` entry under it in the
same change (constitution, Release Documentation), rebuild signed, publish.

*Correction, 2026-09-20*: this report treated 0.1.8 as a published version.
It is not — 0.1.7 is the last release, and 0.1.8 / build 192 was only bumped
in the tree by feature 078. No further bump is needed for this feature: its
changelog entry was merged into the `## [0.1.8] — unreleased` section, and it
ships with 075, 077 and 078 as 0.1.8. See `specs/NEXT-WORK.md`, section R.
