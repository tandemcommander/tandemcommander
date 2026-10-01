# Fix log: feature 092 — name identity (encoding cluster B-2)

Branch `092-name-identity-unicode`, based on `091-workflow-actions-node`.
Decisions by the author (maintainer away): `spec.md` *Clarifications*.

## T001 — baseline

- saltests before the feature: 2055 / 0. Strict guard `TOTAL: 0`.
- Timing (`probe/timing_probe.ps1`, Release build of the branch base, a
  folder of 100,000 files, half with accented names; medians of 5, two full
  runs; the machine was not idle — another build was running — so ±13 %
  between runs):

  | Measure | run 1 | run 2 |
  |---|---|---|
  | refresh | 1106.5 ms (1093.9–1121.6) | 962.2 ms (955.4–968.7) |
  | refresh with all 100,000 selected | 1415.6 ms (1333.4–1466.9) | 1268.2 ms (1249.6–1278.1) |

  Method: `SendMessageTimeout(WM_COMMAND, CM_LEFTREFRESH 724)` returns when
  the handler returns; the refresh is synchronous (`mainwnd3.cpp` →
  `WM_USER_REFRESH_DIR` → `RefreshDirectory`). Posting the command and
  waiting with `WM_NULL` does not work (a sent message overtakes posted ones).

## S1 — helpers (commit `92c66e89`, revised in the S2 commit)

`SalNameCompareOrdinalCI`, `SalNameEqualOrdinalCI`, `SalPathEqualOrdinalCI`,
`SalPathHasPrefixOrdinalCI` in `src/common/salunicode.{h,cpp}`;
`TestNameIdentity092`.

Measured by the tests on the build machine:

- **The file system agrees**: for 16 name pairs created on real NTFS in the
  temp folder (case pairs, the CP1250 collision pair, `straße`/`strasse`,
  NFC/NFD, Greek and Cyrillic pairs, final sigma, Kelvin sign, full-width A,
  dotted and dotless i, long s, the DŽ digraphs) the helper's answer equals
  "does opening the second name find the first file" in every case.
- **No character outside ASCII equals an ASCII letter** for the operating
  system's table (0 found below U+2000; the reviewer found 0 in the whole
  BMP). So `ı`/`I`, `ſ`/`S` and Kelvin/`k` are *different* names — the
  research's examples of length-changing folds were wrong.
- **7 case pairs differ in UTF-8 length** (2 bytes vs 3: U+023A/2C65,
  023E/2C66, 026B/2C62, 027D/2C64, 0251/2C6D, 0271/2C6E, 0250/2C6F), out of
  973 case pairs in the BMP (reviewer's brute force). Hence: no byte-length
  guard in front of the helper, and the prefix helper counts on the path.

Two revisions after it was first committed:

1. *Performance* (review of S2): the first version scanned both strings
   fully before comparing — 5–25× slower than `StrICmp` per call, which a
   quadratic loop (Cut of 30,000 items with both panels on one path) turns
   into tens of seconds. Now: one pass over the common ASCII prefix, and
   the yes/no helper rejects on the first byte before measuring the strings.
2. *Total order* (analysis of S5): "either string is not WTF-8 → legacy
   fold" is intransitive over a list holding valid and invalid names
   together (names pasted from the clipboard can be legacy text). The
   comparison is now lexicographic over the leading ASCII characters and
   the tail; valid tails sort before invalid ones (contract I1). saltests
   check antisymmetry and transitivity over a set mixing ASCII, valid and
   invalid names, and that every element of the sorted set is found again by
   binary search.

saltests: **12,828 / 0**.

## S0 — the guard

`tools/check_encoding.py`: a byte table indexed by a drive letter (`X[0]` on
an identifier that names a path, root, directory or drive; a variable named
`…drive…`) is no longer reported: `acp-byte-table-on-name` went from 33 hits
to 5 real ones, which are annotated (`masks.cpp` ×3 — the byte matchers run
only for ASCII pairs or non-UTF-8 text; `pack3.cpp` — a hash bucket whose
two sides fold alike; `fileswn6.cpp`, `fileswn3.cpp`, `salamdr5.cpp` — drive
letters the shape does not recognise). The rule is **strict** now
(`RULES`, `PROMOTED_FROM_DRAFT`). Proven to fire: a planted
`LowerCase[f->Name[0]] == LowerCase[name[0]]` in a scratch source makes
`--strict` exit 1 with that line; removed, exit 0. (The first shape accepted
any `ident[0]`, which would have let exactly that line through — review of
S2.)

T006 (a rule flagging the old comparison on names in converted files) is
**not done**: converted files still hold legitimate uses of `StrICmp` on
text that is not a name, and deferred sites; a per-file rule would need an
annotation on each. Recorded as a follow-up with the remaining clusters.

## S2 — finding one item by name (FR-004)

Converted to `SalNameEqualOrdinalCI` (16 comparisons + 1):

| Site | Function | What |
|---|---|---|
| `fileswn1.cpp` ×2 | `CommonRefresh` | item vs suggested focus name |
| `fileswn0.cpp` ×3 | `RefreshDirectory` | item vs `NextFocusName`; new listing vs old focus |
| `fileswn2.cpp` ×3 | `ChangeAndListPathOnFS`, `ChangePathToPluginFS` | item vs the name to focus |
| `fileswnb.cpp` ×3 | `WM_USER_DONEXTFOCUS`, `WM_USER_ENUMFILENAMES` | item vs name |
| `fileswn6.cpp` | `ExecuteFromArchive` | duplicate names before editing from an archive |
| `shellsup.cpp` ×2 | `ShellAction` (cut) | item in one panel vs the other |
| `mainwnd3.cpp` | user-menu compare set-up | item vs item |
| `finddlg1.cpp` ×2 | Find's file enumeration | full name vs last name |
| `fileswn1.cpp` | `SelectUnselectByFocusedItem` | same name / same extension as the focused item |

Four byte-length guards in front of the comparison were removed
(`fileswn0.cpp`, `fileswn2.cpp`, `fileswn6.cpp`, `mainwnd3.cpp`).

**Independent review — ACCEPT**, four SHOULD-FIX, all done: the length
guards; the performance of the helper; the guard's too-wide `[0]` shape;
the rule made strict. Its measurements: ASCII parity over 54.5 million
pairs (equality identical to `StrICmpEx`; the sign identical to
`CompareStringOrdinal`); the legacy tier identical to `StrICmpEx` over 2.7
million pairs; `SalPathEqualOrdinalCI` identical to `IsTheSamePath` over
15.3 million ASCII pairs with backslashes in every position. Confirmed: the
duplicate check before editing from an archive has no partner that must
move with it (the disk-cache key takes the name unfolded and compares with
`strcmp`).

**GUI probe** `probe/focus_probe.ps1` (old = Release build of the branch
base, new = Debug build of this stage; focus observed through the viewer
title / the title after Enter; run twice, 20 / 20 lines each):

| Scenario | Old build | New build |
|---|---|---|
| focus on `Ĺ-dir`, refresh, Enter | enters **`ĥ-dir`** | enters `Ĺ-dir` |
| `Č.txt` focused, renamed outside to `č.txt`, refresh | focus jumps to **another file** | stays on `č.txt` |
| focus on `Ĺ.txt`, refresh | F3 shows **`ĥ.txt`** | F3 shows `Ĺ.txt` |
| go up from `Ĺ-dir`; Quick Rename `Článek.txt` → `článek.txt`; start in `…\č` when the disk has `Č` | correct (an exact match is preferred) | correct |
| the ASCII controls | correct | identical |

The collision is measured on this machine (code page 1250):
`CharLowerA(0xA5)` = `CharLowerA(0xB9)` = 0xB9, the second UTF-8 bytes of
`ĥ` and `Ĺ`. Not driven: `WM_USER_DONEXTFOCUS` in isolation. The registry
key was backed up and restored (identical hash).

Recorded for the backlog: `UnselectItemWithName` (`fileswn0.cpp`) uses the
linguistic comparison plus a length guard for an identity look-up.

## S3 — overwrite, delete, rename (FR-005)

Converted to `SalNameEqualOrdinalCI` (20 comparisons): the sites that decide
between "the same file under another spelling" and "another file" before an
overwrite, a delete or a rename.

| Site | Function | Decision |
|---|---|---|
| `fileswn5.cpp` x3 | `RenameFileInternal` | Quick Rename: only a change of case / only the 8.3 name collides / overwrite |
| `worker.cpp` x2 | `SalCreateFileEx` | the target exists only as an 8.3 name |
| `worker.cpp` | `CorrectCaseOfTgtName` | take the spelling the disk has (the capacity test stays, bytes are copied within the old string) |
| `worker.cpp` | `DoCopyFile` | "overwrite older": same file found under the target name |
| `worker.cpp` x4 | `DoMoveFile` | change of case vs. overwrite; 8.3 collision |
| `worker.cpp` x2 | `SalCreateDirectoryEx` | 8.3 collision |
| `fileswn6.cpp` x4 | `BuildScriptDir`, `BuildScriptFile` | a change of case is one rename; copy onto itself is refused |
| `safefile.cpp` x2 | `SafeFileCreate` | 8.3 collision |
| `pack2.cpp` | temporary name | generated ASCII name, no behaviour change |
| `cache.cpp` x2, `cache.h` | `ContainTmpName`, `TmpNameEqual` | a temporary name is taken |
| `salamdr5.cpp` | `SalSplitGeneralPath` | F6 on a directory typed in another case is a rename |

`SalSplitGeneralPath` is also reachable from plug-ins. FR-008 protects the
comparison *primitives* a plug-in calls with its own text; a file service's
internal decision follows FR-001 (spec clarified). Only the name half is
converted; the path half (`IsTheSamePath` or the plug-in's callback) stays.

**Probe** `probe/case_only_probe.cpp` (`build_and_run.cmd`, exit 0): for 15
name pairs the new rule agrees with NTFS (create one name, open the other);
the old rule (the x64 `StrICmp` of `str.cpp` over the `CharLowerA` table)
gives 4 false "different" and 1 false "same". 8 rows for the in-place
spelling correction, including pairs of different UTF-8 length.

**Independent review - ACCEPT**, no blocker. Its measurements:

- The whole BMP on real NTFS with the product's `salunicode.cpp`: 62,472
  names created, 973 collisions, **0 false "same", 0 false "different"**.
- A case-sensitive directory (`fsutil file setCaseSensitiveInfo`) holding
  both `Článek.txt` and `článek.txt`: the move fails with "already exists"
  and the new code shows the error without an overwrite prompt - exactly what
  `a.txt`/`A.txt` always did there. At every site the new behaviour for
  accented pairs equals the old behaviour for ASCII pairs.
- `ĥ.txt` moved onto an existing `Ĺ.txt`: the old code took them for one file
  and showed a bare error; the new code asks to overwrite.
- 8.3 tests: both operands come from `WIN32_FIND_DATAW`, always valid WTF-8;
  the logic `equal to the short name AND not to the long name` is unchanged.

Done after the review: four comments stated as fact what was not measured
(NTFS renames a case-only pair without complaint; the "would delete the
source" path needs a file system that answers "already exists") - reworded.
FR-009 and contract I6 now say that the second guard rule is deferred.

Recorded, not changed (all exist before this feature, none made worse):

1. **Delete-then-retry trusts a name rule alone** (`worker.cpp DoMoveFile`,
   `fileswn5.cpp RenameFileInternal`): on a share whose server folds *more*
   than Windows (NFC/NFD on a macOS server), a rename onto another spelling of
   the same file answers "already exists", the names compare different, and
   the overwrite branch deletes the target - which is the source. The fix is
   a file-identity test (volume serial + file index) before the delete.
   Backlog.
2. `CCacheDirData::DetachTmpFile` (`cache.cpp`) keeps the byte fold; it has
   no caller in the tree.
3. The helper reads an allocation failure (tails over 519 bytes) as "not
   WTF-8", i.e. "different".
4. The probe does not cover the 8.3 predicate, legacy text, or paths over
   520 units; the reviewer's whole-BMP run and saltests cover the helper.
