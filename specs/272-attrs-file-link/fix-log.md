# Fix log: 272 - Change Attributes on a file symbolic link changes the link, not its target file

Backlog item `change-attributes-on-a-file-symbolic-link-compresses-re` (left by 253's review,
SHOULD 1): a file symbolic link's own Change Attributes entry reaches the TARGET file for
compression, times and (by reading) encryption.

## Measured (before, 8b08f1da)

1. **OS behaviour** (PowerShell P/Invoke outside the program; a file symbolic link `in\f.txt` ->
   `out\T.TXT` under %TEMP% made with `SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE` - Developer
   Mode is on):
   - `FSCTL_SET_COMPRESSION` through a handle opened with `FILE_FLAG_BACKUP_SEMANTICS` (the
     worker's flags): `T.TXT` compressed, the link not;
   - with `FILE_FLAG_OPEN_REPARSE_POINT` (with or without `FILE_FLAG_BACKUP_SEMANTICS`): the link
     compressed / uncompressed, `T.TXT` untouched (error 0 both ways);
   - `SetFileTime` through a handle opened with flags 0 (the worker's): `T.TXT` set to 2001, the
     link keeps 2026; with `FILE_FLAG_OPEN_REPARSE_POINT`: the link 2005, `T.TXT` stays 2001;
   - `SetFileAttributesW` on the link (read-only, hidden): the link's own bits - nothing to fix;
   - a dangling file link: compression with `FILE_FLAG_OPEN_REPARSE_POINT` succeeds, with the
     worker's flags error 2.
   - a file with a third-party reparse tag `0x00000123` (REPARSE_GUID_DATA_BUFFER, not a name
     surrogate; settable without privilege): the worker's open fails with 1920, an
     `FILE_FLAG_OPEN_REPARSE_POINT` open would compress the file's own entry - such a file must
     keep the old way (the item's note: not a link).
2. **The product** - new probe `probe/attrs_flink272_probe.ps1` (Change Attributes, command 748,
   on a focused file link; hidden desktop; Debug x64 build of 8b08f1da), `probe/result_before.txt`
   PASS 7 (6 END + PLAIN), FAIL 5, NOT DRIVEN 1:
   - **COMP**: the link not compressed, **T.TXT compressed**;
   - **UNCOMP** (link and T.TXT compressed beforehand): the link still compressed, **T.TXT
     uncompressed**;
   - **TIME** (Modified 2001-02-03; T.TXT set to 2010 beforehand): the link keeps 2026, **T.TXT
     gets 2001**;
   - **SUBC** (folder `sel` with `OWN.TXT` and the link, Compressed + Include subdirectories): sel
     and OWN.TXT compressed, the link not, **T.TXT compressed**;
   - **PLAIN** (plain file, Compressed + date): PASS;
   - **NONLINK**: FAIL only in the probe - it looked for the title "Error Compressing"; the box is
     "Error Changing Compression" ((1920), R.TXT not compressed). Probe fixed and the row re-run:
     `probe/result_before_nonlink.txt` PASS - the existing behaviour to keep;
   - **ENC**: NOT DRIVEN (no EFS certificate may be created on the build machine).
3. **Encryption by reading**: `MyEncryptFile` / `MyDecryptFile` call `SalEncryptFile` /
   `SalDecryptFile` with the link's path - they follow the link (as 253 recorded for directory
   links).

Reachability: Change Attributes (dialog, or Compress / Uncompress / Encrypt / Decrypt) ->
`CFilesWindow::ChangeAttr` -> `BuildScriptMain(atChangeAttrs)` -> `BuildScriptFile` (`fileswn6.cpp`,
`case atChangeAttrs`: `op.Attr = sourceFileAttr`, the listed attributes with
`FILE_ATTRIBUTE_REPARSE_POINT`) -> worker `ocChangeAttrs` -> `DoChangeAttrs(..., op->Attr, ...)`.
With Include subdirectories the walk lists the folder's files the same way.

## Analyze

`speckit-analyze`: no CRITICAL / HIGH. MEDIUM C1 (no task for the CHANGELOG entry the constitution
requires) - fixed by T013. LOW F1 (naming consistent) - nothing to do.

## Decisions

- Compression and times of a file link: through `FILE_FLAG_OPEN_REPARSE_POINT` (the link's own
  entry) - measured to work; the compression helpers keep `FILE_FLAG_BACKUP_SEMANTICS` too
  (measured: no difference on a file).
- Encryption of a file link (only when its state would change): refused exactly as 253 refuses a
  directory link's - `ERROR_NOT_SUPPORTED` under `IDS_ERRORENCRYPTING`. No new UI string.
- The link rule: `DeleteAsDirLink` (197 / 213 / 253, fail closed), now asked for every entry listed
  with the reparse bit, files included. A readable tag that is not a name surrogate (cloud
  placeholder, dedup, third-party tag) is not a link - row NONLINK keeps its old error.

## Work

- `src/common/salreparse.h` (feature 253 section, widened): `SalAttrsEntryIsDirLink` ->
  `SalAttrsEntryIsLink` (reparse bit + rule, the directory bit no longer required);
  `SalAttrsOpenFlags(isDir, isLink)` = `FILE_FLAG_BACKUP_SEMANTICS` for a folder |
  `FILE_FLAG_OPEN_REPARSE_POINT` for a link (a file link was 0); `SalAttrsLinkRefusesEncryption`
  parameter renamed. `src/saltests/saltests.cpp`: `TestAttrsLink253` - the two checks that pinned
  "a file link unchanged" removed (the rule changed), the rest kept; new `TestAttrsFileLink272`
  (21 checks: file link, non-surrogate tags 0x123 / cloud / dedup / WOF, symlink and WSL symlink tags, unreadable tag,
  open flags, encryption refusal).
- `src/worker.cpp` `DoChangeAttrs`: `isLink = SalAttrsEntryIsLink(fileAttr, (fileAttr &
  FILE_ATTRIBUTE_REPARSE_POINT) && DeleteAsDirLink(name))` replaces `isDirLink`; passed to
  `UncompressFile` / `CompressFile`, both encryption refusals and the time handle. Comments of the
  compression helpers name file links.
- T007 diff reading: for a plain file (`isLink` FALSE: time flags 0, compression
  `FILE_FLAG_BACKUP_SEMANTICS`), a plain folder and a directory link the flags and calls are
  identical to before. The Copy / Move callers (`worker.cpp` ~6901 - 6962 created folders, ~7603 -
  7626 the temporary target file) call the helpers with the default `ownEntry = FALSE` - unchanged.
  The only new file-system query: `DeleteAsDirLink` for a file listed with the reparse bit.
- Trap met: a Python rewrite of `worker.cpp` in text mode wrote LF line endings; converted back to
  CRLF before the build (the diff shows only the 11 changed lines).

## Checks (after)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- clang-format (VS 2022 LLVM) on the changed lines: the new test lines aligned; no other diff in
  the changed lines (pre-existing differences elsewhere in the files left alone).
- `.\build.cmd` -> `BUILD SUCCEEDED` (warnings C4018 in `salamdr2.cpp` 1058 / 1066 are
  pre-existing).
- `saltests.exe` -> `saltests: 24833 checks, 0 failed` (24835 after the review changes).
- Probe `probe/result_after.txt`: PASS 12, FAIL 0, NOT DRIVEN 1 - COMP the link compressed, T.TXT
  not; UNCOMP the link uncompressed, T.TXT still compressed; TIME the link 2001, T.TXT 2010; SUBC
  sel, OWN.TXT and the link compressed, T.TXT not; PLAIN as before; NONLINK as before ((1920),
  not compressed); registry restored and identical. Negative control: `probe/result_before.txt`
  (build of 8b08f1da) FAIL 4 (+ the NONLINK title fault of the probe, re-run in
  `result_before_nonlink.txt`: PASS).
- Regressions: 253's probe `probe/regress_253.txt` PASS 10 / FAIL 0 / NOT DRIVEN 1; 213's probe
  `probe/regress_213.txt` 8 / 0.
- `CHANGELOG.md`: entry under 0.1.11 — unreleased; 253's limitation sentence about file links
  updated (fixed here).

## Owed to a person

- **ENC** (NOT DRIVEN): on a machine with an EFS certificate: Change Attributes -> Encrypted on a
  file symbolic link -> "Error Changing Encryption" for the link ("The request is not
  supported."), Skip; the target file stays unencrypted; a plain file selected with it is
  encrypted. And Decrypt on an encrypted file link -> the same refusal, the target stays
  encrypted.

## Review

Refute-first review (one agent): **no MUST, no SHOULD**. It re-ran the build (BUILD SUCCEEDED),
saltests (24833 / 0), the encoding guard (TOTAL: 0), this probe on the hidden desktop (PASS 12 /
FAIL 0 / NOT DRIVEN 1, registry identical), 253's probe (10 / 0 / 1) and 213's (8 / 0); negative
controls: `result_before.txt` (8b08f1da) FAIL 4, the NONLINK row fails a naive "reparse bit is
enough" rule, the new unit checks fail on the old header. Outside the program it compressed,
re-timed and uncompressed absolute, relative and dangling file links - the link still resolves,
the target unchanged. Callers enumerated: Copy / Move keep `ownEntry = FALSE`; `SalAttrsOpenFlags`
only in `worker.cpp`; `DoChangeAttrs` only from `ocChangeAttrs`; the four command routes
(dialog, Compress, Uncompress, Encrypt / Decrypt) all through `BuildScriptMain(atChangeAttrs)`.

- NOTE 1 - `DeleteAsDirLink` ran for every reparse file even when only Read-only / Hidden /
  Archive change (extra opens and a `TRACE_E` per OneDrive placeholder with Include
  subdirectories). **Done**: asked only when compression, encryption or times change
  (`useLinkRule`); `isLink` is used for nothing else.
- NOTE 2 - the test comment named 0x9000001A `IO_REPARSE_TAG_CLOUD_A` (it is `IO_REPARSE_TAG_CLOUD`);
  suggested WOF 0x80000017 and the WSL symlink 0xA000001D. **Done** (2 checks added).
- NOTE 3 - Convert through a file link (`worker.cpp` ~7850 `SalReplaceWithTempW` on the link's
  name), outside the item. **Measured** outside the program: `ReplaceFileW(link, temp)` fails with
  1464 (`ERROR_SYMLINK_NOT_SUPPORTED`), link and target intact; `SalReplaceFailureNext` maps 1464
  to "keep the target" - Convert reports an error and loses nothing. Not a data-loss defect; not
  added to the Inbox (Convert on a file link fails with an error - recorded here).
- NOTE 4 - the encryption refusal is not driven (no EFS certificate) - owed to a person (below).

After the changes for NOTE 1 / 2: encoding guard TOTAL: 0; `.\build.cmd` BUILD SUCCEEDED; saltests
24835 / 0; probe `probe/result_after.txt` PASS 12 / FAIL 0 / NOT DRIVEN 1 (registry identical);
`probe/regress_253.txt` 10 / 0 / 1; `probe/regress_213.txt` 8 / 0. The fix is a guard on a
query whose result was otherwise unused, so a second review was not needed (no MUST).
