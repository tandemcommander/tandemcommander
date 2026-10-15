# Fix log: 194 - dropping onto a shortcut follows a target of any length

Backlog: NEXT-WORK D, "A shell calls that return paths" (128): "The drop-target code for
shortcuts (`shellsup.cpp`, `shellib.cpp`) still limits a target to `MAX_PATH` bytes (refused,
not cut) - it could use `SalShellLinkGetPathU8`".

## Read (before)

`src/shellsup.cpp` `GetCurrentDir` (the panel's drop target, asked on every drag-over), for a
`.lnk` under the mouse:
- the shortcut's own name was widened into `OLECHAR[MAX_PATH]`; a UTF-8 name of MAX_PATH units
  or more failed that and went to the code-page fallback (`MultiByteToWideChar(CP_ACP)` into the
  same buffer, terminated at MAX_PATH - 1): the shell was asked to load a cut, code-page-decoded
  name - the shortcut was not read, the drop went into the folder holding it;
- its target was read into `WCHAR[MAX_PATH]` and `char[MAX_PATH]`: a target of MAX_PATH bytes or
  more (a deep folder, or about 130 Czech letters) was not followed (refused, not cut).

The `shellib.cpp` part of the backlog line (`ResolveNetHoodPath`, a folder shortcut's
`target.lnk`): its only input is the Browse for Folder result, which `GetTargetDirectoryAux`
takes into `MAX_PATH` bytes (`SalSHGetPathFromIDListU8(res, path, MAX_PATH)`) - nothing longer
reaches it - but its `GetPath` into `MAX_PATH` units could hand back a cut target, another
folder: it takes `SalShellLinkGetPathU8` too (review), refusing more than `MAX_PATH` bytes.

Not drivable on the hidden desktop: an OLE drag follows the real mouse. The two helpers the
code takes now are checked by saltests against real shortcuts (`SalShellLinkGetPathU8`, 128;
`SalShellLinkLoadNameAlloc`, 181) and used by Enter on a shortcut and *Go to Shortcut Target*.

## Work

`src/shellsup.cpp`: `SalShellLinkLoadNameAlloc` (the whole name, `\\?\` from MAX_PATH characters
on) and `SalShellLinkGetPathU8` (the whole target or refused) into a heap buffer of
`SAL_MAX_PATH_UTF8` bytes, taken only for a `.lnk` (`fullName` already holds 96 KB of the
stack); `DropPath` and the drop target's `CurDir` have the same size. The code-page fallback is
gone (the helper keeps it only for a name that is not UTF-8). `src/shellib.cpp`
`ResolveNetHoodPath`: `SalShellLinkGetPathU8` as well (above).

Build: BUILD SUCCEEDED; `check_encoding.py` TOTAL 0.

Owed to a person: drag a file onto a shortcut whose target folder's path is longer than 260
bytes (or has 130+ Czech letters) - the drop goes into the target folder.

## Review

Refute-first review: sound. Every copy into `DropPath` in bounds; low memory leaves the item a
plain file; the `S_FALSE` result (a shortcut with no path) differs from before only for an
archive mask matching `*.lnk`; `SLGP_UNCPRIORITY` kept; downstream (`CImpDropTarget::CurDir`,
`GetShellFolder`, `DoCopyMove`) is long-path already; the shell extension's hand-off refuses.
Taken: NIT - the buffer only for a `.lnk`; NIT - the comment's wording; the pre-existing point
in `ResolveNetHoodPath` (above). Not taken: the Network plug-in's `cache.cpp` copy of it (the
plug-in is not built).
