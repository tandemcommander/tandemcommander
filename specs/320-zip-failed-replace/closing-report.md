# Closing report - 320-zip-failed-replace
Backlog item: zip-says-the-archive-was-not-changed-after-a-failed-replace - ZIP says the archive was not changed after a failed replace, yet it changed and a temp file stays
Outcome: closed

## What changed

- `src/plugins/zip/add.cpp`, `add_del.h`: new `CZipPack::ReplaceArchiveWithTemp()` - the closed
  temporary working file takes the closed archive's place through `SalReplaceWithTempW`
  (`src/common/salsafereplace.h`, feature 105): one ReplaceFileW step, the archive never deleted
  first. Kept -> the temporary file deleted, "Archive was not changed." (now true); the archive
  vanished -> the temporary file kept and named (`IDS_ERRCREATE`); both gone -> `IDS_ERRACCESS`;
  done -> attributes as before and the "newest file time" applied again (ReplaceFileW moves the time
  when it copies the archive's named streams).
- `CZipPack::PackNormal` (`add.cpp`) and `CZipPack::DeleteFromArchive` (`add_del.cpp`) call it instead
  of `ClearReadOnlyAttr` + `DeleteFileU8` + `MoveFileU8`.
- `src/saltests/saltests.cpp`: `TestSafeReplace320` (18 checks + one printed observation).
- No new UI string, no plug-in interface change, no registry change.

## Measurements (before / after, commands)

- Before (4252bcb6, `probe/result_before.txt`): `powershell -File tools\run_on_hidden_desktop.ps1 ...
  zipreplace_probe.ps1 ... -Label before` - add-locked and del-locked FAIL: the replace message, the
  archive unchanged, a new `Sal623.tmp` / `Sal272.tmp`; controls PASS. (That run also had a
  del-stream row: Change Directory refuses `report:zip.zip` with error 123 - the stream route is not
  reachable; the row was removed.)
- Old algorithm on a stream (PowerShell P/Invoke): delete True, rename 123 -> the stream archive gone,
  temporary file left (319's shape). Review 2: the same shape on an ordinary file when the temporary
  file is held without delete sharing.
- After (`probe/result_after.txt`, `-Label after`): **12 PASS / 0 FAIL**; add-locked / del-locked: the
  message, nothing new, nothing changed; registry restored, identical.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- `.\build.cmd`: BUILD SUCCEEDED (last after review 2's NOTE 4).
- `saltests: 27558 checks, 0 failed` (27540 + 18).
- Probe: before 2 FAIL / 10 PASS (+ the removed del-stream row), after 12 / 0.
- clang-format: the changed lines clean.

## Reviews (findings and what was done)

- Review 1: killed twice without a report; not counted. Its control probe on the pre-feature build
  reproduced the stray `Sal*.tmp`; its killed probe left the registry changed (below).
- Review 2 (refute-first, no GUI probes, no source changes): no MUST. SHOULD 1 (an archive behind a
  file symbolic link fails safe, 1464) -> spec edge case + Inbox item. SHOULD 2 (the "only copy" case
  is not described as such; needs a new string) -> Inbox item. NOTE 1 (shape (b) reproducible on an
  ordinary file) and NOTE 2 (a held temporary file may remain) -> spec and fix-log. NOTE 3 (saltests
  test the shared rule, the probe guards the plug-in) accepted. NOTE 4 (a check pinned an OS
  behaviour) fixed. NOTE 5 (ACL / streams / creation time kept) as decided in the spec.

## Owed to a person (with the new person-step items)

- `restore-registry-after-killed-probe-320`: the killed review probe left the panel paths / focus and
  `Plugins.ver Version (x64)` changed in `HKCU\Software\Tandem Commander`; the installed program was
  running on the key, so the run did not restore it. Backup `%TEMP%\tc320_backup.reg` (SHA-256
  CF69145A...).

## New Inbox items (slug - title)

- zip-cannot-update-an-archive-reached-through-a-symbolic-link - ZIP cannot update an archive reached through a symbolic link
- zip-does-not-say-the-temporary-file-is-the-only-copy - ZIP does not say the temporary file is the only copy when the archive vanished
- restore-registry-after-killed-probe-320 - Restore the product registry key changed by a killed probe of feature 320
