# Fix log - 391-regedt-link-loop

Backlog item `registry-editor-copy-or-find-through-a-link-to-an-ancestor` - Registry Editor: Copy or
Find through a link to an ancestor walks in a loop.

## Measurement before (HEAD fbccd821, Debug x64)

Probe `probe/loop391_probe.ps1` (written for this feature; style of 297's `link297_probe.ps1` and 257's
Find probe), run on the hidden desktop:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log ... -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <probe> -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Expect before"
```

Result `probe/loop391_before.txt` (Copy rows) and `probe/loop391_before_find.txt` (Find rows):

- COPYSELF (`Self\<K>` holding `L -> Self\<K>`, F5 into `Cil\`): 55 keys written below `Cil\<K>`, a chain
  27 levels deep (`Cil\<K>\L\L\...`); ended with "Unable to open a registry key. (87)" naming
  `...\Self\<K>\L` x27 `\Mark`. The item expected the name-length limit; measured, Windows stops
  following links in one open after ~27-28 steps with ERROR_INVALID_PARAMETER. Same defect.
- COPYCANCEL: the same.
- COPYANC (`Anc\<K>\D\L -> Anc`): 38 keys, 28 deep, error 87.
- COPYCYCLE (`Cyc\<K>\L1 -> Cyc2`, `Cyc2\L2 -> Cyc\<K>`): 43 keys, 28 deep, error 87.
- COPYELSE (control, `Mov\<K>\L -> Jinde`): PASS (copied as a plain key, no box).
- The source was unchanged in every row; registry of the product restored, SHA-256 identical.
- FINDSELF / FINDANC / FINDCYCLE: "Mark" listed 28 / 10 / 15 times (expected 1) and each search ended
  with "Error Searching Windows Registry - Unable to open a registry key. (87)".
- FINDELSE (control): "Sub" found once (the path column was not read yet - fixed in the probe).

Probe-method finding: 257's way to open Find (plug-in hot key Ctrl+Shift+G) gives NOT DRIVEN now -
257's own probe too (run 2026-11-02: 8 NOT DRIVEN). Feature 312 made Ctrl+Shift+G the program's
*Go to Shortcut* when the opt-in browser-like tab shortcuts are on, and the restored maintainer
configuration has them on; the program key runs first (by 312's design). This probe uses Ctrl+Shift+J
(no program key). Not a product defect.

Reachability: F5 on a key in the Registry Editor panel -> `CopyOrMoveFromFS` -> `CopyOrMoveKey` ->
`CopyOrMoveKeyRec` (fs5.cpp) opens each subkey by name (`SafeOpenKey`, follows links); the plug-in's
Find (menu *Search in Windows Registry*) -> `CFindThread::Body` -> `ScanKey` -> `ScanKeyAux`
(finddlg.cpp), the same. Links are makeable without elevation under HKCU.

## Design

- Each walk keeps the chain of identities (292's internal key name, `AddOpenedRegKeyId`) of the keys it
  is inside: the starting key with all its identities (`GetRegKeyIds`: root ids, both HKCR halves;
  best effort) plus the opened handle's own identity, then one identity per opened subkey.
- A subkey whose opened identity is one of the chain or holds one of them (`SalRegKeyIdWithin`) leads
  back: pure rule `SalRegKeyIdLeadsBack` in `src/common/salregkeyid.h` (saltests). By induction only a
  key reached through a link can match (a plain child's identity is longer than every chain entry).
- Copy: checked right after the source key is opened, before the target is checked or created; refused
  with 296's "Can't copy a key to itself." box naming the source key (OK skips, Cancel stops).
- Find: the key is not searched (no box).
- An identity that cannot be read below the start: the existing open-error box (fails closed).

## Analyze

Run 1: no CRITICAL / HIGH. MEDIUM I1 (FR-006 "Move unchanged" vs the check running in the shared
recursion for Move too) - fixed in the spec's edge cases (297 refuses a link source first, so Move
never reaches the new check through a link). LOW C1 (no task checks "no new UI text") - added to T011.
LOW U1 (negative-control method open) - accepted; recorded below. Run 2: nothing left above LOW.

## Implementation

- `src/common/salregkeyid.h`: `SalRegKeyIdLeadsBack(chain, count, id)`.
- `src/saltests/saltests.cpp`: `TestRegKeyIdLeadsBack391` (self, parent, above the start, root, case
  outside ASCII, plain subkey, sibling, prefix of a name, longer name, other hive, a cycle, count limit,
  NULL / empty entries and identity).
- `src/plugins/regedt/regedt.h`: `CRegWalkChain` (malloc'd identities - not `TIndirectArray`, which
  frees with scalar `delete`), `CRegWalkLevel` (RAII: the chain back to its length on every return),
  `RegWalkEnterTop`, `RegWalkEnter`.
- `src/plugins/regedt/fs5.cpp`: `GetOpenedRegKeyId` split out of `AddOpenedRegKeyId` (no 15 KB set per
  key); the chain functions; `CRegCopyTop` carries the chain; `CopyOrMoveKeyRec` enters each opened
  source key before 296's target check; 296's refusal box moved into `RefuseCopyIntoItself` (same text,
  same buttons).
- `src/plugins/regedt/finddlg.h/.cpp`: `ScanKey` makes a chain per starting key, `ScanKeyAux` skips a
  key that leads back (returns TRUE, nothing searched, no box).
- Trap met again: a Bash here-document collapsed the doubled backslashes of the new saltests strings
  (C4129 warnings) and a `'\'` of the probe (`Contains('')` matched everything) - both repaired with the
  editor / a script written to a file.
- No UI string, dialog or resource changed: `git diff main -- src/plugins/regedt/lang src/plugins/regedt/regedt.rh2` is empty - no translation refresh.

## Checks

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd`: BUILD SUCCEEDED.
- saltests: 30,755 -> 30,777 checks, 0 failed.
- Probe after (`probe/loop391_after.txt`): PASS 19, FAIL 0, NOT DRIVEN 0 (English); `loop391_after_czech.txt`:
  19 / 0. Copy rows: one "Can't copy a key to itself." box naming the link key, 2-3 keys written
  instead of 38-55; Find rows: 1 result each, no box.
- Negative control (U1): `RegWalkEnter`'s leads-back test forced off in the working tree (`FALSE &&`),
  rebuilt, probe run, reverted and rebuilt: `probe/loop391_negctl.txt` PASS 8, FAIL 11 - every looping
  row (BOX + STATE of four Copy rows, three Find rows) fails, the controls and END rows pass.
- Regression probes on this build (`probe/*_on391.txt`): 292 `alias292_probe` 33 / 0; 294 `above294_probe`
  24 / 0; 296 `link296_probe` first run 44 PASS / 1 FAIL - LINKDANGLE ERROR "Copy / Move opened no dialog"
  (the operation never ran; the flake 294 recorded), full re-run `link296_probe_on391_rerun.txt` 47 / 0;
  297 `link297_probe` 40 / 0; 390 `hkcr390_probe` 10 / 0. The product's registry restored identical
  after every probe.
