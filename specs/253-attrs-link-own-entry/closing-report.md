# Closing report - 253-attrs-link-own-entry
Backlog item: change-attrs-on-link-reaches-target - Change Attributes on a junction compresses / re-times the target folder
Outcome: closed

## What changed

- `src/worker.cpp` `DoChangeAttrs`: a directory link (`DeleteAsDirLink`, fail closed, asked only
  for an entry listed with the directory and reparse bits) gets its own compression and times - the
  handles are opened with `FILE_FLAG_OPEN_REPARSE_POINT`; an encryption change of such a link
  (only when its state differs from the request) is refused with `ERROR_NOT_SUPPORTED` under the
  existing "Error Changing Encryption" dialog (Retry / Skip / Skip all / Cancel), never through the
  "not supported on the volume" branch. `CompressFile` / `UncompressFile` take `ownEntry` (default
  FALSE - the Copy / Move callers unchanged).
- `src/common/salreparse.h`: `SalAttrsEntryIsDirLink`, `SalAttrsOpenFlags`,
  `SalAttrsLinkRefusesEncryption`; `src/saltests/saltests.cpp` `TestAttrsLink253` (16 checks).
- No UI string, resource, plug-in interface or stored data changed.

## Measurements (before / after, commands)

- OS (PowerShell P/Invoke on a junction under %TEMP%): compression and `SetFileTime` without the
  flag landed on the target, with it on the junction.
- Probe `probe/attrs_link253_probe.ps1` on the hidden desktop
  (`tools\run_on_hidden_desktop.ps1 ... -Label before|after`):
  - before (d5f67ace): COMP, UNCOMP, TIME, SUBC FAIL (the target folder compressed / uncompressed /
    re-timed, the junction not), PLAIN PASS, ENC NOT DRIVEN - `probe/result_before.txt`;
  - after: PASS 10, FAIL 0, NOT DRIVEN 1 - `probe/result_after.txt`; registry restored, identical.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED`.
- `saltests.exe` -> `saltests: 24391 checks, 0 failed`.
- Probe 253: 4 FAIL -> 10 / 0 (1 NOT DRIVEN); regression 213's probe 8 / 0 (`probe/regress_213.txt`).

## Reviews (findings and what was done)

One refute-first review: no MUST. SHOULD 1 (file symbolic links still reach their target) - out
of the item's scope -> Inbox item. SHOULD 2 (encryption refusal not driven) -> person-step item.
NOTEs: the spec's "decided when it runs" clarification corrected (the reparse bit comes from the
listing); others recorded in `fix-log.md` *Review*.

## Owed to a person (with the new person-step items)

- `check-that-change-attributes-refuses-to-encrypt-or-decrypt-a` - run the encryption refusal on a
  machine with an EFS certificate (row ENC NOT DRIVEN).

## New Inbox items (slug - title)

- `change-attributes-on-a-file-symbolic-link-compresses-re` - Change Attributes on a file symbolic
  link compresses / re-times the target file
- `check-that-change-attributes-refuses-to-encrypt-or-decrypt-a` - Check that Change Attributes
  refuses to encrypt or decrypt a junction (253)
