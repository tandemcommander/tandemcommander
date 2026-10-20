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
