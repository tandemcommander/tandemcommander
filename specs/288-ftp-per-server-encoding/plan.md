# Implementation Plan: FTP - names go to each server in that server's own encoding

**Branch**: `288-ftp-per-server-encoding` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/288-ftp-per-server-encoding/spec.md`

## Summary

Feature 224's one process-wide set of "names a listing gave in the code page" becomes a per-server
state: each FTP server (host without ASCII case, port, user with anonymous = none) has the evidence
seen (UTF-8 names in listings, code-page names in listings or 257 replies) and its own set of
code-page names. A non-ASCII name goes to a server in the code page when it is one of that
server's code-page names (also as a component or leading part, 224) or when the server is
*legacy* (code-page evidence, no UTF-8 evidence) - if the code page can hold it; else UTF-8. The
pure decision (state from evidence, code page or UTF-8, same server) lives in a header-only rule
`src/common/salftpsrvenc.h` with saltests checks; the plug-in passes the server to the decoding
and encoding sites: an explicit parameter of `PrepareFTPCommand`, `FTPU8NameToServer` and
`FTPGetDirectoryFromReply`, and a scoped thread-local "server of the listing being parsed" around
the four listing parse loops (the parser's column functions have no server at hand).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new (WinAPI SRW lock as in 224)
**Storage**: in memory only, for the life of the plug-in (freed at its release, as 224's set)
**Testing**: saltests (the pure rule), the hidden-desktop probe `probe/ftp288_probe.ps1` (two
ftpmini servers, cp1250 and UTF-8), regression probes of 224, 269, 277 (and 215 through 224's)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application, the FTP plug-in (`src/plugins/ftp/`)
**Performance Goals**: a lookup per command / listing field - a short list of servers and a hash
of names under a shared SRW lock; no measurable cost against the network
**Constraints**: no new network traffic (no FEAT); no new stored data; plug-in ABI untouched (the
FTP plug-in's internal functions only); a name is never cut (the code-page form is used only when
it fits the buffer, as 224)
**Scale/Scope**: 224's bound kept - 200,000 remembered names in total; servers bounded at 1,000
(past it a new server is "unknown": UTF-8 for new names, no remembered names)

## Constitution Check

- **I. Build Reproducibility** - no new dependency; one new header in `src/common/`. PASS.
- **II. Backward Compatibility** - UTF-8 servers: unchanged; legacy servers: their listed names
  unchanged, new names now in the code page (the defect); unknown servers: unchanged; nothing
  stored, no setting. PASS.
- **III. Incremental Modernization** - a local change of the plug-in's encoding rule. PASS.
- **IV. Windows Platform Commitment** - WinAPI only. PASS.
- **V. Plugin Architecture Preservation** - no change of `spl_*.h` or of the interface version;
  internal functions of the FTP plug-in only. PASS.
- **VI. UI Consistency** - no UI change, no new strings. PASS.

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/288-ftp-per-server-encoding/
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/server-encoding-rule.md   # the rule of salftpsrvenc.h (plug-in internal)
├── fix-log.md, closing-report.md
├── probe/ftp288_probe.ps1, result_*.txt, regress_*.txt
└── tasks.md
```

### Source Code (repository root)

```text
src/common/salftpsrvenc.h          # new: pure rule (state, code page or UTF-8, same server)
src/saltests/saltests.cpp          # TestFtpServerEncoding288
src/plugins/ftp/ftputils.h/.cpp    # per-server state registry, listing scope, FTPListingFieldToU8,
                                   #   FTPU8NameToServer(.., srv), FTPGetDirectoryFromReply(.., srv)
src/plugins/ftp/ctrlcon.h, ctrlcon2.cpp   # PrepareFTPCommand(srv, ...); CControlConnectionSocket::GetServerEnc
src/plugins/ftp/ctrlcon1/3/4/5.cpp        # callers (the panel's connection)
src/plugins/ftp/operats.h, operats2.cpp   # CFTPOperation::GetServerEnc
src/plugins/ftp/operats4/6/7/8/a/b.cpp    # callers (workers)
src/plugins/ftp/operats9.cpp              # upload listing cache: scope around ParseListing
src/plugins/ftp/fs2.cpp                   # panel listing: scope around the parse loop
src/plugins/ftp/ftp.cpp                   # free at release (renamed function)
```

**Structure Decision**: the existing plug-in layout; the pure rule header-only in `src/common/`
(the FTP plug-in cannot compile a `.cpp` from `src/common`, CLAUDE.md).

## Complexity Tracking

None.
