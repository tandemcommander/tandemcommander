---
title: FTP: a path whose escaped form does not fit MAX_PATH is left half-escaped
type: decision
status: new
severity: 2
area: ftp
source: manual
who: person
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: [ftp-long-name-and-path-leftovers]
depends-on: []
reason: -
---

# FTP: a path whose escaped form does not fit MAX_PATH is left half-escaped

## Problem

Part of `ftp-long-name-and-path-leftovers` (split at 4c6fd132). The core asks the FTP plug-in for the external (URL) form of a path - for the address shown and stored (history, panel tabs, Copy Full Path, the "path error" text) - with `ConvertPathToExternal`: a buffer of MAX_PATH bytes and **no return value**. The FTP plug-in turns each `%` that starts a hex sequence into `%25` (`FTPAddHexEscapeSequences`); when the result does not fit, the function stops in the middle and returns FALSE, and the caller ignores it - the path stays **half-escaped**. Read back (`ConvertPathToInternal`), the sequences not escaped are decoded: `/a%41b` becomes `/aAb` - another folder. Reachable only with a server path of roughly 250-259 bytes (the core refuses longer typed paths, feature 233) that holds literal `%XX` text.

## Evidence

By reading at 4c6fd132: `src/plugins/ftp/fs1.cpp:741` (`FTPAddHexEscapeSequences(fsUserPart, MAX_PATH);` result ignored); `src/plugins/ftp/ftputils.cpp:1385` `FTPAddHexEscapeSequences` (returns FALSE "small buffer" after escaping the first sequences). The contract: `src/plugins/shared/spl_fs.h:895-897` ("buffer 'fsUserPart' (size MAX_PATH characters)", `void`). Core callers: `src/fileswn1.cpp:203`, `fileswn3.cpp:2138`, `fileswn8.cpp:175` (`PluginFSConvertPathToExternal`, used for history / targets / `paneltabs.cpp:516` tabs), `fileswn9.cpp:2170` (Copy Full Path, buffer 2 * MAX_PATH). Origin: the audit of feature 215 (`specs/215-ftp-long-name-command/fix-log.md`, *Review*, last paragraph).

## Expected

A path whose escaped form does not fit is never stored or shown half-escaped; how that is achieved is the maintainer's choice below.

## Question

The plug-in cannot refuse inside `ConvertPathToExternal` (void, MAX_PATH by contract). Should the plug-in interface get a way to refuse or a larger buffer, or is the half-escaped path accepted as a limit?

## Options

- **A - accept it as a limit.** No change; recorded in the FTP section of the project reference. Users with ~250+ byte FTP paths containing literal `%XX` may reopen another folder from history or a tab. No interface change.
- **B - append an interface method** (ABI append-only): e.g. a size-aware `ConvertPathToExternalEx(..., int bufSize)` returning BOOL; the core passes its real buffer and refuses (not stores) the path when FALSE; old plug-ins keep the old call. Interface 108 is still unreleased in the tree (245), so it can go there. Costs: a contract in `specs/NNN-*/contracts/`, core changes at four callers.
- **C - plug-in only, all-or-nothing**: escape nothing when the whole does not fit. No interface change, but the unescaped path still decodes to another folder - it only makes the damage uniform; not a fix.

## Recommendation

B while interface 108 is unreleased (it removes the defect for every FS plug-in that escapes); otherwise A - the case is rare and C does not remove it.

## Log

- 2026-10-20 — created (source manual)
