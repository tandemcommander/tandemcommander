# Fix log: 253 - Change Attributes on a junction changes the junction, not its target folder

Backlog item `change-attrs-on-link-reaches-target` (left by 213's review): the link's own Change
Attributes entry reaches the TARGET folder for compression, times and (by the source "probably")
encryption.

## Measured (before, d5f67ace)

1. **OS behaviour** (PowerShell P/Invoke on a junction `j` -> `tgt` under %TEMP%, outside the
   program): `FSCTL_SET_COMPRESSION` through a handle opened with `FILE_FLAG_BACKUP_SEMANTICS` only
   compressed / uncompressed `tgt`; with `FILE_FLAG_OPEN_REPARSE_POINT` added it compressed /
   uncompressed `j` itself (error 0 both ways, `tgt` untouched). `SetFileTime` without the flag set
   `tgt`'s times (2000), with it `j`'s (2001).
2. **The product** - new probe `probe/attrs_link253_probe.ps1` (Change Attributes, command 748, on a
   focused junction; hidden desktop; Debug x64 build of d5f67ace), `probe/result_before.txt`
   PASS 6 (5 END rows + PLAIN), FAIL 4, NOT DRIVEN 1:
   - **COMP** (Compressed set): the junction not compressed, **the target folder compressed**;
   - **UNCOMP** (junction and target compressed beforehand, Compressed cleared): the junction still
     compressed, **the target uncompressed**;
   - **TIME** (Modified date 2001-02-03; the target's times set to 2010): the junction keeps 2026,
     **the target gets 2001**;
   - **SUBC** (a folder `sel` holding `OWN.TXT` and the junction, Compressed + Include
     subdirectories): `sel`, `OWN.TXT` compressed, the junction not, **the target folder
     compressed** (its file not - 213's walk fix holds);
   - **PLAIN** (positive control: a plain folder, Compressed + date): PASS;
   - **ENC**: NOT DRIVEN - the user has no EFS certificate (`Cert:\CurrentUser\My`, EKU
     1.3.6.1.4.1.311.10.3.4: 0) and encrypting would create one in the user's store.
3. **Encryption by reading**: `MyEncryptFile` / `MyDecryptFile` call `SalEncryptFile` /
   `SalDecryptFile` (`EncryptFileW` / `DecryptFileW`) with the link's path - no flag keeps them on
   the link; their `preserveDate` handles are opened without `FILE_FLAG_OPEN_REPARSE_POINT` too.

Reachability: Change Attributes (dialog, or the Compress / Uncompress / Encrypt / Decrypt commands)
-> `CFilesWindow::ChangeAttr` (`fileswn5.cpp`) -> `BuildScriptMain(atChangeAttrs)` ->
`BuildScriptDir` adds `ocChangeAttrs` for the junction (`op.Attr` = its listed attributes, with
`FILE_ATTRIBUTE_REPARSE_POINT`) -> worker `DoChangeAttrs(..., op->Attr, ...)`.

Consumers of the four helpers (Grep, all in `src/worker.cpp`): `DoChangeAttrs`; the Copy / Move
directory creation (`UncompressFile` / `MyEncryptFile` / `MyDecryptFile` / `CompressFile` on the
created target folder, ~6898 - 6959); the file copy (~7600 - 7623, the temporary target file). No
declaration in a header.

## Decisions

- Compression and times of a directory link: through `FILE_FLAG_OPEN_REPARSE_POINT` (the link's
  own entry) - measured to work.
- Encryption of a directory link (only when its state would change): refused with
  `ERROR_NOT_SUPPORTED` under `IDS_ERRORENCRYPTING` - the ordinary Retry / Skip / Skip all / Cancel
  error; not `ERROR_INVALID_FUNCTION`, which would switch encryption off for the rest of the
  operation. No new UI string.
- The link rule: `DeleteAsDirLink` (197 / 213, fail closed), asked only for an entry listed with
  the directory and the reparse bit.
- File symbolic links: not named by the item - unchanged; recorded as a backlog item.

## Work

- `src/common/salreparse.h` (feature 253 section): `SalAttrsEntryIsDirLink`, `SalAttrsOpenFlags`,
  `SalAttrsLinkRefusesEncryption`; `src/saltests/saltests.cpp` `TestAttrsLink253` (16 checks).
- `src/worker.cpp`: `CompressFile` / `UncompressFile` take `ownEntry` (default FALSE - the Copy /
  Move callers unchanged; `SalAttrsOpenFlags(TRUE, FALSE)` = `FILE_FLAG_BACKUP_SEMANTICS`, the old
  value). `DoChangeAttrs` decides `isDirLink` once (asks `DeleteAsDirLink` only for an entry listed
  with the directory and the reparse bit), passes it to the compression helpers and to the time
  handle (`SalAttrsOpenFlags(isDir, isDirLink)` - for a non-link the old `isDir ?
  FILE_FLAG_BACKUP_SEMANTICS : 0`); a directory link's encryption change sets
  `ERROR_NOT_SUPPORTED` (title `IDS_ERRORENCRYPTING`, the ordinary Retry / Skip / Skip all / Cancel
  error) instead of calling `MyDecryptFile` / `MyEncryptFile`.
- T008 diff reading: for every entry that is not a directory link the flags and calls are
  identical to before; no new UI string, resource, plug-in interface or stored data (FR-006).
- Not measured: a junction whose name ends with '.' or ' ' (the helpers append '\' for such names)
  - `mklink` refuses to create one even with the `\\?\` form.
- Probe fix during the run: `$PSScriptRoot` is empty in a parameter default under Windows
  PowerShell 5.1 - the library path is now computed in the body.

## Checks (after)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- clang-format (VS 2022 LLVM) on the changed lines of the three sources.
- `.\build.cmd` -> `BUILD SUCCEEDED` (warnings C4018 in `salamdr2.cpp` 1058 / 1066 are
  pre-existing; the file recompiled because it includes `salreparse.h`).
- `saltests.exe` -> `saltests: 24391 checks, 0 failed`.
- Probe `probe/result_after.txt`: PASS 10, FAIL 0, NOT DRIVEN 1 - COMP the junction compressed,
  target not; UNCOMP the junction uncompressed, target still compressed; TIME the junction 2001,
  target 2010; SUBC sel, OWN.TXT and the junction compressed, target and T.TXT not; PLAIN as before;
  registry restored and identical. Negative control: `probe/result_before.txt` (the build of
  d5f67ace) FAIL 4.
- Regression: 213's probe `probe/regress_213.txt` 8 / 0.

## Owed to a person

- **ENC** (NOT DRIVEN): on a machine with an EFS certificate (or one where creating it is fine):
  Change Attributes -> Encrypted on a junction -> "Error Changing Encryption" for the junction ("The request
  is not supported."), Skip; the target folder stays unencrypted; a plain folder selected with it is
  encrypted. And Decrypt on an encrypted junction (e.g. made inside an encrypted folder) -> the same
  refusal, the target stays encrypted.

## Review

Refute-first review (one agent): **no MUST**. It re-ran build (BUILD SUCCEEDED), saltests (24391 /
0), the encoding guard (TOTAL: 0), this probe on the hidden desktop (PASS 10 / FAIL 0 / NOT DRIVEN
1, registry identical) and 213's probe (8 / 0); negative control `result_before.txt` was made on
d5f67ace = the merge-base (FAIL 4). Callers enumerated: `CompressFile` / `UncompressFile` at the
Copy / Move sites keep the default (same flags as before); `MyEncryptFile` / `MyDecryptFile`
unchanged; `DoChangeAttrs` only from `ocChangeAttrs`. No new write except compression and times of
the link's own entry.

- SHOULD 1 - file symbolic links still change their target (compression with the old flags, times
  with flags 0); reachable with Include subdirectories. Outside the item (it names junctions /
  directory symbolic links) -> new Inbox item `leftover:253`.
- SHOULD 2 - the encryption refusal never ran (ENC NOT DRIVEN); read as correct (not the
  `ERROR_INVALID_FUNCTION` branch; no refusal when the state matches - COMP / SUBC go through that
  path). -> person-step item at closing.
- NOTE - a junction named with a trailing '.': the reviewer made one with `CreateDirectoryW` +
  `FSCTL_SET_REPARSE_POINT`; opening it with the appended '\' and `FILE_FLAG_OPEN_REPARSE_POINT`
  compressed the link itself (OS side fine; the program not driven with such a name).
- NOTE - directory symbolic links and SMB paths: measured outside the program, the link's own entry
  is reached; the probe drives junctions only.
- NOTE - Skip all on the refusal also skips later Change Attributes errors of the operation
  (existing behaviour of `SkipAllChangeAttrs`).
- NOTE - "decided when it runs" was only half true (the reparse bit comes from the listing):
  the spec's clarification corrected.
- NOTE - SUBC sets "Include subdirectories" by `BM_SETCHECK` (no `BN_CLICKED`), so the dialog does
  not grey the untouched boxes; the compression assertions hold. The unit checks prove the rule,
  the probe the wiring.
- NOTE - volume mount points are now changed on their own entry too (as Delete); a mount point to
  a FAT volume no longer switches compression off for the rest of the operation.
