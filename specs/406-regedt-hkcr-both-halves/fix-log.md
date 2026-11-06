# Fix log - 406 Registry Editor: Move of an HKCR key held by both halves leaves its machine half

Backlog item `registry-editor-hkcr-move-both-halves-leaves-machine-half` (source leftover:390, review
NOTE 2 of 390).

## Measurement before (main at 8bb3c295, not elevated)

### Direct measurement (script `%TEMP%\tcmeasure\hkcr_view.ps1`, only HKCU written and removed)

A user's half was created for the machine-only key `HKCR\.386` (machine: `(default) = vxdfile`,
`PerceivedType = system`, subkey `PersistentHandler` with a `(default)`): user's `PerceivedType =
tcprobe-user`, `TcProbeUserOnly = u`, an empty `PersistentHandler`.

- `reg query HKCR\.386 /s`: `(Default) = vxdfile`, `PerceivedType = tcprobe-user`,
  `TcProbeUserOnly = u`; `PersistentHandler (Default) = {098f...}` - values merged per name, the
  user's wins; the machine's `system` hidden.
- `RegDeleteKeyW(HKEY_CLASSES_ROOT, ".386\PersistentHandler")` = 0, then `(".386")` = 0: only the
  user's half gone each time; the machine's half intact; HKCR shows the machine's key again.

Consequence for the design: a machine value hidden by a user's value of the same name is not in the
copy - deleting the machine's half blindly (elevated) would lose it.

### Probe (new, `probe/hkcr406_probe.ps1`, build Debug x64 of 8bb3c295, `.\build.cmd` BUILD SUCCEEDED)

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log %TEMP%\tcmeasure\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File %TEMP%\tcmeasure\probe\hkcrboth_probe.ps1 -Exe ...\tandemcommander.exe -RepoRoot E:\Projects\tandemcommander -OutFile %TEMP%\tcmeasure\probe\hkcrboth_before.txt"
```

(the probe was run from a scratch copy before the branch existed; copied unchanged into
`probe/hkcr406_probe.ps1`, output `probe/hkcr406_before.txt`, log `probe/result_before.txt`.)

| Row | Result |
|---|---|
| BOTHMOVE (F6 of `HKCR\.386` into `\HKEY_CURRENT_USER\Software\TcProbeBoth\Cil\`, Cancel) | FAIL: boxes none; the copy equals the merged view; the user's half deleted; the machine's half left - a partial Move reported as success, **without elevation** |
| BOTHSKIP (the same, Skip) | FAIL: the same (no box) |
| BOTHSHADOW (user's `PersistentHandler (default)` hides the machine's) | FAIL: the same (no box) |
| BOTHSELF (F6 into `\HKEY_CURRENT_USER\Software\Classes\`) | PASS: refused by 292 "Can't move a key to itself." |

Rows: PASS 6, FAIL 7; registry restored identical (1C3349EA...B0A4); no user's half of `.386` left.

Reachable from F6 / drag and drop, default configuration (`regedt` on): `CopyOrMoveFromFS` ->
`CopyOrMoveKey` -> `CopyOrMoveKeyRec` -> `SafeDeleteKey(HKCR)`. The item said it needed elevation; it
does not - without elevation the machine's half also stays, and no box says so.

Callers (Grep): `SalRegHkcrDeleteHalf` only `CopyOrMoveKeyRec` + saltests; `SafeDeleteHkcrHalf` only
`CopyOrMoveKeyRec`; `CopyOrMoveKeyRec` <- `CopyOrMoveKey` <- `CopyOrMoveFromFS` (F5 / F6, drag and
drop) and Quick Rename (`fs3.cpp`).

## Analyze findings

- C1 (MEDIUM): the probe found Skip by its English text - BOTHSKIP would fail in Czech; fixed in the
  probe (see *The change*).
- U1 (LOW): Skip All not driven - the unchanged `RegOperationError` path; accepted.
- E1 (LOW): "no new string / no ABI change" has no own task - checked in the diff and by the review.

## The change

- `src/common/salregkeyid.h`: `SAL_HKCR_DELETE_BOTH` (appended; the old values keep their numbers);
  `SalRegHkcrDeleteHalf(TRUE, TRUE)` returns it (was `VIEW`); `SalRegValueSame` (type, size, bytes;
  a size without data is never "the same").
- `src/plugins/regedt/fs5.cpp`:
  - `HkcrMachineHalfCopied(path, copied)`: opens both halves (`KEY_QUERY_VALUE`), compares the class
    names (case ignored, as the copy's own test) and, for every machine value, the user's value of
    the same name (absent = copied; `SalRegValueSame` otherwise; a larger user value = another
    value); any error is returned (fails closed; a value changed while read = `ERROR_MORE_DATA`).
  - `SafeDeleteHkcrHalf(..., checkCopied)`: with the check, "not copied" becomes
    `ERROR_NOT_SUPPORTED` in the existing `IDS_REMOVESOURCE` box (feature 297's precedent); Retry
    checks again.
  - `CopyOrMoveKeyRec`: `SAL_HKCR_DELETE_BOTH` = the machine's half (checked), then the user's half,
    each by its real path; when the machine's half fails or is refused nothing of the key is deleted.
- No new UI string, no dialog, no plug-in ABI change: no `.slt` refresh.
- Probe: analyze C1 fixed - Skip is found by its id 173 (measured in the English box: Retry 4,
  Skip 173, Skip All 174, Cancel 2), not by its English text; row BOTHEQUAL added (control of
  BOTHSHADOW: an equal user's value is not hidden - the machine's delete is tried, (5)).
  The first edit of the probe went through a Bash here-document and lost a backslash in one line
  (the known trap, 123/294) - caught by reading it back, fixed with the editor.

## Checks after the change

| Check | Result |
|---|---|
| `.\build.cmd` | BUILD SUCCEEDED (warnings only the old C4267 of `fs2.cpp`) |
| `saltests.exe` | `saltests: 282544 checks, 0 failed` |
| saltests negative control (header mutated: both = VIEW, size not compared; restored from a copy after) | 5 failed (lines 14465, 14492, 14493, 14513, 14522) |
| probe English, first version (`hkcr406_after.txt` before BOTHEQUAL) | 13 PASS / 0 FAIL: BOTHMOVE / BOTHSKIP first box "Unable to remove the original registry key. (5) Access denied" naming `HKEY_LOCAL_MACHINE\Software\Classes\.386\PersistentHandler`; BOTHSHADOW the same with "(50) The request is not supported."; both halves unchanged, the copy equals the merged view; BOTHSELF refused |
| probe English with BOTHEQUAL | 16 PASS / 0 FAIL; registry restored identical (1C3349EA...B0A4) |

Interruption: after the English run the maintainer started the installed Tandem Commander and this
build's Debug exe on the real desktop (0:13); the probes refuse while any instance runs (they share
the registry key) and the Debug exe locks `regedt.spl` (LNK1168 during the negative control's build).
The run waited for them to close (they closed at ~0:15; never stopped by the run), then rebuilt
(`.\build.cmd` BUILD SUCCEEDED; `fs5.obj` / `regedt.spl` 0:15:34-35, after the header was restored
at 0:14:27 - the negative control's objects are gone) and ran the final series on that binary.

## Final probe series (runner `%TEMP%\tcmeasure\run_all.ps1`, hidden desktop, not elevated)

| Probe | Result |
|---|---|
| `hkcr406_probe.ps1` English (`hkcr406_after.txt`, log `result_hkcr406_en.txt`) | 16 PASS / 0 FAIL / 0 NOT DRIVEN |
| `hkcr406_probe.ps1` Czech (`hkcr406_after_czech.txt`, `result_hkcr406_cs.txt`) | 16 / 0 / 0 (Skip found by id) |
| 390 `hkcr390_probe.ps1` (`hkcr390_probe_on406.txt`) | 10 / 0 / 0 |
| 292 `alias292_probe.ps1` | 33 / 0 / 0 |
| 294 `above294_probe.ps1` | 24 / 0 / 0 |
| 296 `link296_probe.ps1` | 47 / 0 / 0 |
| 297 `link297_probe.ps1` | 40 / 0 / 0 |

Registry restored identical after every run (B90B4B77...6EC44; the hash differs from the earlier
runs because the maintainer's instances saved their settings when they closed). The superseded logs
`result_after.txt` (13-row run) and `result_after_czech.txt` (NOT RUN, the maintainer's instance
was open) were removed.

## NOT DRIVEN / owed to a person

- The elevated Move (both halves really removed; the (50) refusal of a hidden machine value at the
  top key) - the probe never runs elevated (it would delete a real machine key): a line of the
  release checklist `manual-checks-owed-before-the-next-release` (feature 406).
- A non-empty machine class name that differs from the user's - by reading (setting a machine
  class needs elevation; the user's class is set by the probe's `RegCreateKeyExW`, row BOTHCLASS).
- Quick Rename of a both-halves HKCR key - by reading (research R4).

## Review

### First review (independent agent, refute-first, on commit 475a0d00)

No MUST. Re-measured: the probe on `main`'s `fs5.cpp` / `salregkeyid.h` (built in its own copy)
7 PASS / 9 FAIL (BOTHMOVE / BOTHSKIP / BOTHSHADOW / BOTHEQUAL: no box, the user's half missing, the
machine's left); on HEAD 16 / 0; negative control `HkcrMachineHalfCopied` forced to "copied" -
BOTHSHADOW TEXT FAIL ((5) instead of (50)), BOTHEQUAL PASS; saltests 282544 / 0; clang-format clean.
Callers enumerated (`CopyOrMoveFromFS`, Quick Rename `fs3.cpp`); a Move into the key's own machine
half is refused by 292 (identity set of an HKCR path holds both halves); a skipped value keeps the
key; `RegDeleteKeyW` refuses a machine half that still has subkeys; the user's half is deleted only
after the machine's.

| Finding | Done |
|---|---|
| SHOULD 1 `fix-log.md` lines 92 / 95 held control characters (a backspace, a tab and a CR: `\b`, `\t`, `\r` of a Bash here-document fed to Python - feature 123's trap) | fixed with a script file written by the editor; `grep -P` over every changed file finds none |
| SHOULD 2 the check read values with the reported `maxData` while the copy doubles it ("Microsoft sometimes returns half the size"): a value larger than the maximum gave `ERROR_MORE_DATA`, a (234) box that Retry never clears - a wrong refusal | fixed: the buffers start at twice the maximum and grow on `ERROR_MORE_DATA` (the same value read again, at most 8 rounds, then the error - fails closed); the comment "the key changed while it was read" corrected. Not reproducible here (no key with the quirk) - by reading |
| NOTE the probe never reached the top key's own check (the subkey's box comes first) nor the class branch | fixed: rows BOTHTOP (a machine-only key without subkeys, a hidden value at the top: (50) naming the top key) and BOTHCLASS (the user's half created with a class through `RegCreateKeyExW`) |
| NOTE class names compared linguistically ignoring case: a machine class differing only in case counted as copied | fixed: exact comparison; refined - an empty machine class holds nothing and is no reason to refuse (otherwise every user's class name would refuse the Move) |
| NOTE a change of the user's half by another program between the copy and the delete is not seen (the check compares the halves, not the copy) | recorded in the function's comment; negligible race, not changed |
| NOTE when the user's half cannot be read the box names the machine's key | recorded in the comment; the key named is the one not deleted - accepted |
| NOTE the refusal (50) says no reason | feature 297's precedent, no new string - accepted |
| NOTE a non-elevated Move of a both-halves key now ends with an access-denied box | the intended change (it silently removed the user's half before) |

Checks after the review fixes (final binary): `.\build.cmd` BUILD SUCCEEDED; saltests `282544 checks,
0 failed`; probe English 23 PASS / 0 FAIL (BOTHTOP: the first box names
`HKEY_LOCAL_MACHINE\Software\Classes\.3ds` with (50); BOTHCLASS: (5), the user's class
`TcProbeClass` read back), Czech 23 / 0; 390's probe 10 / 0; registry restored identical. The probes of
292 / 294 / 296 / 297 ran on the binary before these fixes (all PASS above); the fixes change only
`HkcrMachineHalfCopied`, reached only for a key held by both halves at the delete of a Move.

