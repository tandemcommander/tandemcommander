# Fix log: 305 - the core never follows a shortcut to a cut target path

Backlog item `a-shortcut-whose-target-path-has-260-or-more-characters-is` (source measure:304).

## Measurement before (main at 31239f48)

1. `probe/measure_core.cpp` - built with `cl /nologo /EHsc /std:c++latest /utf-8 /I src\common`
   (vcvars64; minimal stand-ins for the core's UTF-8 conversions, whose `.cpp` files need the
   core's `precomp.h`), run with a base folder: plain `.lnk` files and a folder shortcut whose item
   list (built folder by folder, `SetIDList`) names targets of 250 / 259 / 260 / 261 / 300 / 400
   units.
   - `D:\Build\tcm_core305` and `E:\...\build\tcm_m305` (no 8.3 names): 250 / 259 whole; 260+
     `SalShellLinkGetPathU8(SLGP_UNCPRIORITY)` = NOERROR with 259 units `\\?\D:\Build\...` cut
     mid-name, does not exist; `SLGP_RAWPATH` the same cut answer; `SalFolderShortcutTargetU8` =
     NOERROR with the cut path.
   - `%TEMP%` (C:, 8.3 names): 260+ answered in the 8.3 form (87-109 units), exists - not cut.
2. GUI probe `probe/lnk305_probe.ps1` (hidden desktop, links written by `probe/mklnk305.cpp`;
   fixture `build\tc305` on E:, no 8.3 names) on the unchanged build -
   `probe/result_before.txt`:
   - ENTER-250 PASS (control).
   - ENTER-300 FAIL: "The path or file name "E:\...\zzz(28)" is invalid." - the panel stays.
   - FOCUS-300 FAIL: "Cannot obtain shortcut target or target path is not accessible."
   - ENTER-SEP / FOCUS-SEP FAIL: a 300-unit target whose parent has 259 units - the panel
     **silently opens the parent folder** (another folder, no message).
   - Registry restored, identical (SHA-256 D8DA635D...E56F).
   Found while probing: after `IShellLink::Resolve` (both callers resolve first) the cut answer
   is 259 units in the PLAIN form (`E:\...`), before Resolve `\\?\` + 255 units. The rule compares
   plain forms, so both are covered; the SEP rows use a 259-unit parent so that the cut after
   Resolve is exactly the parent.

**Defect confirmed** (`BL verify` at 31239f48).

Note: the item's *Evidence* names `fileswn0.cpp` "Enter" and `fileswn2.cpp` "Go to Shortcut
Target"; it is the other way round (`fileswn0.cpp` = `FocusShortcutTarget`, 838;
`fileswn2.cpp` = `Execute`, Enter). No call site changes - the fix is in the reader.

## Decisions

- The rule of feature 304, in the core: an answer of MAX_PATH - 1 = 259 units or more is
  followed only when the link's item-list name (`SHGetNameFromIDList(SIGDN_FILESYSPATH)`) equals it
  or extends it (plain forms, ordinal, case ignored) - then the whole item-list name, plain.
  Otherwise `HRESULT_FROM_WIN32(ERROR_FILENAME_EXCED_RANGE)`.
- `SLGP_RAWPATH` with an answer of 259+ units: refused without the item list (environment
  strings - not comparable; item *Approach*).
- `SalFolderShortcutTargetU8` passes the refusal on as its existing "too long" result (feature
  286) - Browse refuses instead of silently picking the shortcut folder.
- A core twin of the plug-ins' rule (`SalShellLinkWholeTargetW` next to
  `SplFileDlgDetail::WholeFolderShortcutTargetW`), as `SalIsFolderShortcutIni` /
  `IsFolderShortcutIni` - the plug-ins are not touched (research R2).
- Probe fixture in the build folder, not `%TEMP%`: the defect exists only on a volume without 8.3
  names (research R6); every path the probe types starts with the fixture root.

## Analyze

`speckit-analyze`: 0 CRITICAL, 0 HIGH. MEDIUM C1 (the probe fixture outside `%TEMP%`) accepted
and recorded above; LOW U1 (drop / Browse not driven) - T013.

## Implementation

`src/common/salshelllink.h`:
- `SalPlainPathAllocW` - the plain form (`\\?\UNC\x` -> `\\x`, `\\?\x` -> `x`).
- `SalShellLinkWholeTargetW(answer, listName)` - the pure rule (data-model.md), the core's twin of
  `SplFileDlgDetail::WholeFolderShortcutTargetW`.
- `SalShellLinkGetPathU8` - an answer of 259+ units: `SLGP_RAWPATH` -> refused
  (`HRESULT_FROM_WIN32(ERROR_FILENAME_EXCED_RANGE)`); otherwise `GetIDList` +
  `SHGetNameFromIDList(SIGDN_FILESYSPATH)` -> the rule -> the whole name (plain) or refused. Shorter
  answers: unchanged, the item list is not read. "Does not fit the caller's buffer" stays `E_FAIL`.
- `SalFolderShortcutTargetU8` - the reader's `ERROR_FILENAME_EXCED_RANGE` is its own "too long"
  result (Browse refuses; before a reader failure was `S_FALSE` = the shortcut folder itself).

No call site changed (`fileswn0.cpp`, `fileswn2.cpp`, `shellsup.cpp`, `shellib.cpp`); no UI text;
the plug-ins untouched.

`src/saltests/saltests.cpp` `TestShellLinkWholeTarget305`:
- the plain form (6 rows + NULL); the pure rule - every row of data-model.md incl. both measured
  cut forms (`\\?\E:\` before Resolve, `E:\` after it), the cut on a backslash, case, UNC; the two
  twins (core / plug-in) agree on a 7 x 7 table;
- `SalShellLinkGetPathU8` with the fake link `CFakeLink304`: 259+ without item list / item list
  naming another folder / not-a-prefix -> refused, ""; `SLGP_RAWPATH` 259+ -> refused without
  reading the item list; short answers and 258 units -> as before, item list not read; "" / S_FALSE
  / E_FAIL passed on;
- end to end in `%TEMP%` (C:, 8.3) and next to `saltests.exe` (E:, no 8.3): plain `.lnk` and folder
  shortcuts whose item list names 250 / 259 / 260 / 300 (a Czech letter) / 400 units and 300 with a
  259-unit parent; read without and with `Resolve(SLR_NO_UI | SLR_ANY_MATCH)`: the target folder by
  identity, plain, whole on E:; raw path whole under 259, refused from 259; folder shortcut with
  `MAX_PATH` NOERROR (250 / 259) or too long (E: 260+), with `SAL_MAX_PATH_UTF8` whole. Negative
  control inside: the raw `GetPath` answer is another folder - printed count.

## Checks

| Check | Command | Result |
|---|---|---|
| encoding guard | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |
| build | `.\build.cmd` (PowerShell) | `BUILD SUCCEEDED` |
| saltests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | `saltests: 27037 checks, 0 failed`; `saltests 305: 1 volume(s) without 8.3 names tested, GetPath's cut reproduced 8 time(s)` (4 targets x without / with Resolve) |
| negative control 1 | `SalShellLinkWholeTargetW` returning every answer as it is (`if (TRUE \|\| answerLen < MAX_PATH - 1)`), rebuilt | `27037 checks, 84 failed` (fake-link refusals, end-to-end "another folder / \\?\ form / not whole", folder shortcut not too long); restored |
| negative control 2 | the raw-path refusal removed (`if (TRUE \|\| (flags & SLGP_RAWPATH) == 0)`), rebuilt | `27037 checks, 13 failed` (the raw-path rows); restored, rebuilt, 0 failed |
| existing checks (T009) | `TestShellLink128` (`FAILED` for no fit, `!= NOERROR` for no path), 181, 194, 286 (`tooLong`, `S_FALSE`, the 259-byte limit) | unchanged, pass |

## Measurement after

- `probe/measure_core.cpp` rebuilt against the changed header:
  - `D:\Build\tcm_core305a` (no 8.3 names): UNCPRIORITY 250 / 259 / 260 / 261 / 300 / 400 **whole,
    exists** (before: 259 units cut for 260+); RAWPATH 250 whole, 259+ refused `0x800700CE`;
    `SalFolderShortcutTargetU8` (32 KB buffer) whole for all.
  - `%TEMP%` (C:, 8.3): 250 / 259 whole; 260+ the 8.3 form as before; RAWPATH 259 refused (fail
    closed - a raw answer of exactly 259 units is not proven), 8.3 answers as before.
- GUI probe `probe/result_after.txt`: **PASS 10, FAIL 0** - ENTER-250, ENTER-300, ENTER-SEP,
  FOCUS-300, FOCUS-SEP end in the whole 300-unit target (before: an error message, or silently the
  parent folder); END rows clean; registry restored, identical (D8DA635D...E56F).
- Fixture folders removed (`tcm_core305*` on C: and D:, `build\tc305` by the probe; saltests
  removes its own).

Behaviour change to note: `SLGP_RAWPATH` answers of exactly 259 units (whole) are now refused too.
The two callers ask the raw path only to recognise a link to a server (`\\server`), never 259
units long; the Enter / Go to route falls back to the item list's own name as before.

## Review

### Review 1 (independent agent, refute-first)

No MUST. Re-ran build, saltests (27037 / 0), `measure_core.cpp` against main's and the branch's
header on D: (main: 260-400 cut, not existing; branch: whole, existing; RAWPATH 259+ refused) and
the GUI probe (PASS 10, registry identical). Own cases: a UNC base `\\localhost\D$\...` (answer
`\\?\UNC\...` cut at 259, item list whole - whole after the fix), a surrogate pair across the cut
(a lone high surrogate at unit 259 - caught, whole), a hand-made `.lnk` with LinkInfo only (Windows
11 answers S_FALSE - nothing that worked before is refused). Callers enumerated: `fileswn0.cpp`,
`fileswn2.cpp`, `shellsup.cpp` (`DropPath[SAL_MAX_PATH_UTF8]`), `shellib.cpp` via
`SalFolderShortcutTargetU8` - each takes its existing "cannot read" route on a refusal.

- SHOULD 1: the refusal pass-through in `SalFolderShortcutTargetU8` (FR-004) was untested - its
  negative control (`FALSE && got == ...`) left saltests at 0 failed (real links always prove the
  name, so "too long" came from the buffer check). **Fixed**: the loaded-link part moved into
  `SalFolderShortcutLinkTargetU8(IShellLinkW*, char*, int)` (as 304 moved `LinkTargetWholeW`);
  saltests drives it with `CFakeLink304`: a 259-unit answer without item list / with an item list
  naming another folder -> too long (also with room for it); a short answer followed; longer than
  the buffer -> too long; "" / E_FAIL -> S_FALSE; NULL arguments. Negative control 3 repeated
  (`else if (FALSE && got == HRESULT_FROM_WIN32(ERROR_FILENAME_EXCED_RANGE))`) -> `27046 checks, 3
  failed` (the three refusal rows); restored -> 0 failed.
- SHOULD 2: a whole UNC answer of exactly 259 units (mapped drive, UNC preferred) can never match
  the item list's drive form and is now refused - it was followed before. **Accepted** (fail
  closed): a 259-unit answer cannot be told from a cut one; every longer UNC answer was cut before;
  recorded in the spec's edge cases. Not reproduced (needs a `net use` mapping on the maintainer's
  machine).
- NOTE 1 (the prefix proof is not anchored to a separator): same rule as the plug-ins' twin
  (304); the shell's own `GetPath` derives from the item list - no disagreeing case could be built;
  the item-list object is what Explorer follows. Accepted.
- NOTE 2 (RAWPATH of exactly 259 units refused): already recorded above. Accepted.
- NOTE 3 (the Network plug-in reads `target.lnk` with `GetPath(MAX_PATH)`,
  `src/plugins/nethood/cache.cpp:2645`, the same cut; plug-in off by default): out of scope ->
  Inbox item `network-plug-in-follows-a-network-shortcut-to-a-cut-target` (review:305).
- NOTE 4 (quickstart said "3 times"; CHANGELOG / FEATURE-HISTORY pending): quickstart fixed;
  the records come with the closing commit.

No second review: review 1 had no MUST finding (SKILL step 7); the change after it is the
extraction of the loaded-link part into a function plus tests, checked by negative control 3.

### Checks after the review

| Check | Result |
|---|---|
| `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |
| `.\build.cmd` | `BUILD SUCCEEDED` |
| saltests | `saltests: 27046 checks, 0 failed`; `saltests 305: 1 volume(s) without 8.3 names tested, GetPath's cut reproduced 8 time(s)` |
| GUI probe | `probe/result_after.txt` re-run on the final code: PASS 10, FAIL 0; registry restored, identical |

## Not driven (owed to a person)

- A drop onto a shortcut with a long target (`GetCurrentDir`, feature 194) - needs a real mouse
  drag. The reader it calls is the one checked above; with a proven whole name `DropPath`
  (`SAL_MAX_PATH_UTF8`) takes it.
- Browse For Folder on a network location whose target has 260+ characters on a volume without 8.3
  names (`GetTargetDirectory`) - the dialog tree needs a real mouse; checked by saltests through
  `SalFolderShortcutTargetU8`: too long for `MAX_PATH` - the existing refusal of feature 286.
