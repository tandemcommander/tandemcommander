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

## Review

### Review 1 (refute-first, independent agent)

Confirmed: the loops are fixed (old plug-in built in a worktree: FINDSELF 28 results + error 87); a
read-only walker applying the same rule over HKCR, HKCU, HKLM, HKU, HKCC (~1.12 million keys) refused
nothing; no data-loss path; no other walker or `CRegCopyTop` creator.

- MUST: `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Perflib\009`, `\CurrentLanguage`, `\005`
  (and their `WOW6432Node` copies) open as performance pseudo-handles (`0xFFFFFFFF80000050` / `...60`);
  `NtQueryKey` fails with STATUS_INVALID_HANDLE, so `RegWalkEnter` turned them into "Unable to open a
  registry key. (6)" - 6 new boxes in a Find over HKLM, the values left out with Skip All, the same box
  in a Copy of Perflib. The spec's "practically only too long" was wrong.
  Fixed: `SalRegIsPseudoKeyHandle` (`salregkeyid.h`, saltests) - such a handle is neither checked nor
  added (no key object: no identity, no subkey, no link). Spec edge cases corrected. Probe row FINDPERF
  (and FINDPERFNT, see below).
- SHOULD: a link in the copied tree to the target's parent (`Tgt\<K>\L -> Cil`, copy into `Cil\`)
  still looped: 29 keys 28 deep, error 87 - the walk reached the copy it writes. Inside the item's
  *Expected* ("never walk through a link back into the tree they walk"), so fixed here: the identity
  of the operation's target key (read once after it is created) is avoided by every source key below
  the top (`RegWalkEnter`'s `avoid`; refused with the same box). FR-001 extended. Probe row COPYTGT.
- NOTE probe coverage (HKCR both halves, a selected key that is itself a link, drag and drop,
  Move / Quick Rename through the check): not added - drag and drop and Quick Rename go through the same
  `CopyOrMoveKey`, Move reaches the check only after 297's link refusal, and the 292 / 294 / 296 / 297 /
  390 probes (HKCR, links, Move, Quick Rename) are re-run on this build.
- NOTE mojibake in the old open-error box's name read-back: the probe reads that box's name field
  through the code page (287's trap; the 296 box is read through id 2477) - a probe artefact, before 391.
- NOTE stack: `RegWalkEnter` / `GetOpenedRegKeyId` keep ~2.5 KB each on the stack, called from the
  recursion but not inlined into its frame across the recursion's depth (3 MB stack, 512-unit paths) -
  accepted.

The reviewer's own FINDPERFNT row failed on the OLD plug-in too (`rev391\perf_old.txt`): an
access-denied (5) box from a protected key under `CurrentVersion`, answered Cancel, ends the search
before Perflib - a pre-391 open error. The row now answers Skip All and allows only (5) boxes.

After the fixes: saltests 30,777 -> 30,789 / 0; probe `loop391_after_review1_english.txt` /
`_czech.txt` 24 / 0. Negative control of the two fixes (pseudo-handle test and target check forced off,
rebuilt, reverted, rebuilt): `loop391_negctl_review1.txt` COPYTGT BOX + STATE FAIL (29 keys, 28 deep,
error 87) and FINDPERF FAIL (the "(6)" box) - 3 FAIL, the other rows PASS.

Regression found by the re-run of 294's probe after the SHOULD fix (`above294_probe_on391_r1.txt`
22 PASS / 2 FAIL): FLATTEN and FLATCOPY - 294's allowed merge of `Plochy\K\K` into `Plochy\` (the
target `Plochy\K` HOLDS the source) - got "Can't move/copy a key to itself." for `...\K\K\Q`: every
source key lies inside such a target, so "within the target" alone refused them. Fix: a source key is
"in the copy" only when it lies within the target and NOT within the copied key's own identities
(`SalRegKeyIdIntoTarget`, `salregkeyid.h`, saltests incl. the flatten and HKCR-halves cases;
`CRegWalkChain::MarkTop` / `IntoTarget`). A link from such a source into the rest of the target is
still caught (a key of the target outside the source). Trap: a rebuild while the background regression
probes still ran failed with LNK1168 (the plug-in was loaded) - the 297 / 390 results of that batch are
from the review-1 build; everything is re-run on the final build below. saltests 30,803 / 0.
- Final build (after review 1 and the flatten fix): `loop391_after_r2_english.txt` / `_czech.txt`
  24 / 0; 294 `above294_probe_on391_r2.txt` 24 / 0; 292 33 / 0; 296 47 / 0; 297 40 / 0; 390 10 / 0;
  saltests 30,803 / 0; encoding guard TOTAL: 0; BUILD SUCCEEDED.
