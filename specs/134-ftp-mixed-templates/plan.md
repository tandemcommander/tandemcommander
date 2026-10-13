# Implementation Plan: FTP client - mixed texts

**Branch**: `134-ftp-mixed-templates` | **Date**: 2026-10-13 | **Spec**: [spec.md](spec.md)

## Summary

The map is the triage of feature 130 (`specs/130-plugin-mixed-templates/triage/ftp.md`: about
104 defective sites in four parts A-D, with the encodings of every source and sink, a list of
what must not be touched and an eight-step proposal). This feature measures first (a probe
with its own FTP server), then carries the steps out:

- **Shared pieces, by the session, first** (so that the four work packages share one contract):
  `LoadStrU8` for the plug-in (`ftp.h`, `ftp.cpp`); `FTPTextToU8` / `FTPGetErrorTextU8` in
  `ftputils.h` (a text of unknown encoding as UTF-8 - a reply, a `FormatMessage` text); the
  core's `GetCommonFSOperSourceDescr` as UTF-8 (`src/zip.cpp`).
- **Four work packages in parallel**, by file group, each with the brief `agent-brief.md` and
  its part of the triage: A `ctrlcon*.cpp`, `sockets.cpp`, `ssl.cpp`, `datacon*.cpp` (incl.
  the connect error state machine, `GetProxyError`, the wait windows, **the log sink** and the
  Logs window); B `fs*.cpp`, `ftp*.cpp`, `parser*.cpp` (incl. `GetTypeNameForUser`); C
  `dialogs*.cpp`; D `operats*.cpp`. No build, no GUI, no git in the packages.
- **Contracts across packages** (fixed in the brief): after this feature `GetProxyError`,
  `GetFatalErrorTxt`, `GetTypeNameForUser` and every composed log message give UTF-8;
  `FTPGetErrorText` and `FTPListingFieldToU8` are unchanged; the log sink normalises every
  message; commands and their log copies are untouched.
- Then one build, the probe before / after, independent reviews (one per package pair),
  fixes, final builds and runs, records.

## Technical Context

- `src/plugins/ftp/` (C++, about 60 files; `/J` - `char` is unsigned); `src/zip.cpp` (core);
  `src/plugins/undelete/dialogs.cpp` (the other user of the core's subject text - checked).
- Shared helpers: `src/plugins/shared/splloadstru8.h` (130), `splunicode.h`.
- Test server: `probe/ftp134_server.py` (standard library; lists a tree with accented names,
  answers chosen commands with a reply of a chosen text and encoding, logs every received
  line as hex). Probe: `probe/ftp134_probe.ps1` on the hidden desktop, library of 098.
- Control build: the build of this branch before the code changes (0.1.10 prepared) and 0.1.9.
- No new strings; `PRIVACY.md` untouched (the same data in the same places - the address
  history gets the typed text instead of a garbled one; a saved log is a file the user writes).

## Constitution Check

- Backward compatibility: stored configuration and histories still load (values of unknown
  encoding go through "valid UTF-8, else code page"); the plug-in interface is untouched; the
  core's subject text changes its encoding - both users are checked (FTP, Undelete).
- Never lose the user's data: nothing sent to a server changes (SC-002 compares the bytes).
- UI consistency: existing dialogs; wide sinks where a control was code-page only.
- Incremental modernization: one more plug-in on the rule of 127 / 130.

## Structure

1. Spec, plan, research, tasks, brief. Shared pieces.
2. In parallel: the four packages (edits + a record each); the session writes the server and
   the probe and measures "before".
3. Build, compile fixes, `saltests`, encoding check; probe "after"; the server's byte log
   compared.
4. Reviews (refute-first), fixes, Release build, regressions, records, local commit.
