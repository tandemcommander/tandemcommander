# Closing report - 301-subst-target-whole
Backlog item: a-subst-drive-whose-target-is-long-or-outside-the-code-page - A subst drive whose target is long or outside the code page resolves to a cut or code-page path
Outcome: closed

## What changed

- `src/common/salsubst.h` (new, header-only): `SalSubstTargetToPathU8` - the device text
  `\??\X:...` / `\??\UNC\...` -> the subst path as UTF-8, the size measured first, refused (never
  cut) when the caller's buffer is too small; `SAL_SUBST_TEXT_U8_MAX` (3 * MAX_PATH + 1).
- `src/salamdr2.cpp`: `QueryDosDeviceWholeW` (MAX_PATH stack buffer, then a growing heap buffer);
  `MyQueryDosDevice` without the code-page `QueryDosDevice` fallback; `GetSubstInformation(..,
  BOOL* tooLong)`; `ResolveSubsts` returns FALSE with the path unchanged on a refused target (plug-in
  ABI unchanged); new `GetSubstPathVolume` - the volume of a path on a subst drive from the whole
  wide target + the rest, only for a path `ResolveSubsts` cannot resolve.
- `src/salamdr1.cpp` (`HasTheSameRootPathAndVolume`, `PathsAreOnTheSameVolume`) and
  `src/salamdr7.cpp` (`GetResolvedPathMountPointAndGUID`, not after a walk that ended on a share):
  `GetSubstPathVolume` as the fallback when their volume walk fails.
- `src/dialogs3.cpp` Drive Information, `src/drivelst.cpp` remote-drive menu text,
  `src/fileswn9.cpp` Copy UNC Path: buffers for every `subst.exe` target / the real buffer size; a
  refused target shows nothing or reports "too long".
- `src/consts.h`: declarations; `src/saltests/saltests.cpp`: `TestSubstTarget301`.

## Measurements (before / after, commands)

- Lengths (scratch PowerShell): `subst.exe` takes an 80-CJK-letter folder (138 units, 298 bytes),
  refuses 359 units; `DefineDosDeviceW` takes both; `QueryDosDeviceW(260)` fails for 359 units.
- Probe `probe/subst_probe.ps1` on the hidden desktop
  (`powershell -File tools\run_on_hidden_desktop.ps1 -Log ... -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\301-subst-target-whole\probe\subst_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after-review2"`):
  - before (HEAD 0f7bd140 build, first 9 rows): 7 / 2 - CJK DEL "delete directory J", CJK INFO empty;
  - installed 0.1.10 (all 18 rows): 14 / 4 - CJK DEL, CJK INFO, LONG VOL, LONG MOVE;
  - negative control (`GetSubstPathVolume` disabled): 14 / 4 - CJK / LONG VOL and MOVE;
  - after: **18 / 0**, registry restored identical, no subst left, fixture removed.
- `probe/review2_unc_probe.ps1` (a short subst holding a symbolic link to a share): branch before
  the review-2 fix SUBST FAIL (the local C: volume); after 4 / 0.
- Imports (`dumpbin /imports`): installed 0.1.10 `QueryDosDeviceA` + `QueryDosDeviceW`; now only
  `QueryDosDeviceW`.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED` (no UI strings, resources or plug-in lists changed: `full` not
  needed).
- `saltests.exe` -> `saltests: 26559 checks, 0 failed`; rule negative control (the fit test
  replaced by "accept what was converted") -> 4 failed; restored.
- Probes: as above, 18 / 0 and 4 / 0.

## Reviews (findings and what was done)

- Review 1: MUST M1 (the refusal made the volume checks fail open - Undelete's same-partition
  warning, moves as copy + delete, Drive Information's volume) -> fixed with `GetSubstPathVolume`;
  SHOULD S1 (no volume rows) -> VOL and MOVE rows; SHOULD S2 (a long subst-to-UNC target: FALSE)
  -> documented; NOTEs (heap per query, a saltests comment, probe header numbers) -> fixed.
- Review 2 (with the previous findings): no MUST; SHOULD S1 (the fallback also after a link to a
  share and for resolvable paths - Drive Information showed the local volume) -> gated; NOTE N1
  covered by the same gate; NOTE N2 (doubled backslash) -> fixed.
- Details: `fix-log.md`, section *Review*.

## Owed to a person (with the new person-step items)

- `check-copy-full-path-as-unc-on-a-subst-drive-with-a-long-non` - Check Copy UNC Path on a subst
  drive with a long non-ASCII target (the clipboard; `quickstart.md` step 5).

## New Inbox items (slug - title)

- `undelete-skips-its-same-partition-warning-when-the-target` - Undelete skips its same-partition
  warning when the target volume cannot be told (bug, 5, data-safety, measure:301).
- `check-copy-full-path-as-unc-on-a-subst-drive-with-a-long-non` - Check Copy UNC Path on a subst
  drive with a long non-ASCII target (person-step, 3, long-paths, leftover:301).
