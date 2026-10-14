# Feature Specification: can a typed FTP path be cut at FTP_MAX_PATH? (measured: no)

**Feature Branch**: `162-ftp-long-typed-path`
**Created**: 2026-10-14
**Status**: Closed by measurement - no code change, see fix-log.md
**Input**: `specs/NEXT-WORK.md` item 13 (116, 121): "a typed server path is still cut at
`FTP_MAX_PATH` when stored; `ChangePath` with an open connection was not examined for the
cut-user case; a custom proxy-script line over 1,000 bytes is cut without CRLF. Find: a *Look
in* path near the program's maximum stops with a trace only."

## User Scenarios & Testing *(mandatory)*

### User Story 1 (Priority: P1)

A user types `ftp://server/<a long path>` (Change Directory, the command line, a hot path, the
F5 target). If the plug-in kept only the first 300 bytes (`FTP_MAX_PATH`), the panel would go
into the folder those bytes name - another folder. The panel must either reach the whole path or
refuse it; it must never go into a cut one.

**Independent Test**: `probe/ftp_long_path_probe.ps1` (134's FTP server; what the server
received decides): the whole path at the boundary, a refusal one byte over it and at 299 / 400
bytes, both with the first connect and with a connection open.

## Requirements *(mandatory)*

- **FR-001**: No typed path reaches the server cut (no CWD / LIST of a strict prefix of it).
- **FR-002**: If a route that cuts is reachable, it refuses with `IDS_TOOLONGPATH` (no new
  string, no interface change); if none is reachable, nothing is changed (a negative finding is
  recorded with its evidence).

## Outcome

Measured: the core hands a plug-in at most 259 bytes of user part (`ChangePathToPluginFS`,
`ChangeAndListPathOnFS`; the F5 target field, measured by 121), the plug-in keeps 300 bytes of
path and 609 of user part - the cut is not reachable. The Find and proxy-script parts are not
defects either (fix-log.md). No code change.
