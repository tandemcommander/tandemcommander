# Implementation Plan: a name is not cut at a byte position

**Branch**: `137-names-cut-at-byte` | **Date**: 2026-10-13 | **Spec**: [spec.md](spec.md)

## Summary

1. **Measure**: two rows added to the SFTP probe of 133 (`sftp133_probe.ps1`): QRLONG (Quick
   Rename, command 754, a name of 100 CJK letters - 304 bytes) and QR250 (a name of 250 ASCII
   letters, the row 131 / 133 owed); one row to the FTP probe of 134 (AUTOREN: the plug-in's
   "If Cannot Create File" set to automatic rename in the registry for the run, a download into
   a local folder whose path leaves room for part of the accented name). Run on 0.1.9.
2. **Core** (`src/fileswn5.cpp`, the plug-in branch of Quick Rename): a chosen name of
   `MAX_PATH` bytes or more is refused with `IDS_TOOLONGNAME` and the dialog opens again with
   the typed text - instead of `lstrcpyn(newName, ..., MAX_PATH)` cutting it.
3. **Shared** (`src/plugins/shared/splunicode.h`): `SplU8WholePrefixLen(s, bytes)` - the number
   of bytes, at most `bytes`, that end at a character boundary; checks in `saltests`.
4. **FTP** (`src/plugins/ftp/operats5.cpp`, `DoCreateDir` and the file twin): the three byte
   cuts of the automatic rename use it.

## Technical Context

- The plug-in interface gives `QuickRename` a `newName` buffer of `MAX_PATH` bytes (feature
  027); longer names cannot be passed - hence refusal, not a bigger buffer.
- Test servers: container `tandem-sftp` (133), `ftp134_server.py` (134).
- No new strings (the core has `IDS_TOOLONGNAME`); `PRIVACY.md` untouched.

## Constitution Check

Backward compatibility and the plug-in ABI untouched; "a path or name is never cut - refuse"
(standing rule) applied to the last place found in the core's plug-in path.

## Structure

1. Spec, plan, tasks. 2. Probe rows; "before" on 0.1.9. 3. Fixes + unit checks; build.
4. Rows again; regressions; review; records; local commit.
