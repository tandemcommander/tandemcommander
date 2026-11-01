# Contract - the FTP server path rule (feature 385)

Internal to the FTP plug-in (not a plug-in interface). Header-only: `src/common/salftpsrvpath.h`.

```cpp
enum ESalFtpSrvPathKind { sfspkCaseSensitive, sfspkVms, sfspkMvs, sfspkSlashes, sfspkDotted, sfspkAs400 };

// = FTPIsVMSEscapeSequence: an odd number of '^' right before 'c' (not before 'beginning')
BOOL SalFtpVmsEscaped(const char* beginning, const char* c);

// Is 'prefix' the same server path as 'path' (mustBeSame TRUE), or the same or an ancestor of it?
BOOL SalFtpServerPathIsPrefix(ESalFtpSrvPathKind kind, const char* prefix, const char* path, BOOL mustBeSame);
```

Rules:

1. `sfspkCaseSensitive`: byte-exact, `/` separated, one trailing `/` ignored (the old default).
2. Every other kind: the two paths are walked separator by separator and name by name; a name
   (the text between separators) equals the other path's name at the same place by
   `SalNameOrderEqualCI` (092); separators equal by byte, except `/` == `\` for `sfspkSlashes`.
3. Trailing-separator, root, `[000000` (VMS) and boundary rules are those of the old
   `FTPIsPrefixOfServerPath`, with positions in `path` taken from the walk.
4. For ASCII-only inputs the answer equals the old function's for every kind and both modes.
5. NULL is never passed (callers' contract, as before).

Mapping in `ftputils.cpp`: Unix / Empty / Unknown -> CaseSensitive; OpenVMS -> Vms; MVS -> Mvs;
Windows / NetWare / OS2 -> Slashes; IBMz_VM / Tandem -> Dotted; AS400 -> As400.
