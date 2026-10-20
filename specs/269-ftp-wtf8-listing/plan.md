# Implementation Plan: An FTP file name with an unpaired surrogate keeps its name on a UTF-8 server

**Branch**: `269-ftp-wtf8-listing` | **Date**: 2026-10-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/269-ftp-wtf8-listing/spec.md`

## Summary

`FTPListingFieldToU8` (`src/plugins/ftp/ftputils.cpp`) decides once per listing field (and per PWD
path, through `FTPDecodeServerReplyPathInPlace`) whether the server's bytes are kept as the UTF-8
name or read in the ANSI code page and remembered as a code-page name (feature 224). The "keep"
test is the strict `MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, ...)`, which refuses the
WTF-8 form of an unpaired surrogate (`ED A0 80` ..) - the program's own encoding of such NTFS names
(feature 066) and exactly what `FTPU8NameToServer` sends. The fix replaces that test by a pure,
length-bounded rule `SalFtpListingFieldIsU8` in a new header-only `src/common/salftplisting.h`:
TRUE when the bytes are ASCII or WTF-8 - exactly the set `SplU8ToW` of
`src/plugins/shared/splunicode.h` accepts (strict UTF-8 plus any surrogate in a 3-byte sequence),
with an embedded NUL byte valid as before. Everything else of the function (the code-page branch,
`FTPAddCodePageName`, the raw fallback) and every sender stays unchanged. `saltests` checks the rule,
also exhaustively against `SplUnicodeDetail::Wtf8ToW` for all short byte strings.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; the rule is header-only (the FTP plug-in cannot compile a `.cpp`
from `src/common`)
**Storage**: none (the process-wide code-page name set of feature 224 only receives fewer names)
**Testing**: `saltests` (`TestFtpListingField269`); hidden-desktop probe `probe/ftp269_probe.ps1`
(5 rows) against 215's `ftpmini.py` with a new byte-transparent `wtf-8` mode; feature 224's probe as
the regression of the code-page detection
**Target Platform**: Windows 11 x64
**Project Type**: desktop application, FTP plug-in (`src/plugins/ftp`)
**Performance Goals**: the listing decode stays one pass over the bytes (the strict call was one
pass, too)
**Constraints**: no UI string, no plug-in interface change, no network behaviour change (the bytes
sent are the same), no registry change
**Scale/Scope**: one condition in `ftputils.cpp`, one new header, saltests checks, one probe-server
option

## Constitution Check

| Principle | Status |
|---|---|
| I. Build Reproducibility | PASS - no new dependency; header-only rule, built by the existing projects |
| II. Backward Compatibility | PASS - ASCII, UTF-8 and legacy code-page names decode as before (probe controls DL-ACC, LEG-DL and the 224 probe); only names that strict UTF-8 refused and WTF-8 accepts change |
| III. Incremental Modernization | PASS - a pure rule in `src/common/` with unit checks, a one-line call site change |
| IV. Windows Platform Commitment | PASS - NTFS name semantics (WTF-8, feature 066) |
| V. Plugin Architecture Preservation | PASS - no interface change; plug-in metadata stays UTF-8 |
| VI. UI Consistency | PASS - no UI change |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/269-ftp-wtf8-listing/
|-- spec.md
|-- plan.md
|-- research.md
|-- data-model.md
|-- quickstart.md
|-- contracts/listing-field-rule.md
|-- fix-log.md
|-- tasks.md
`-- probe/ftp269_probe.ps1, result_*.txt
```

### Source Code (repository root)

```text
src/common/salftplisting.h            (new) SalFtpListingFieldIsU8
src/plugins/ftp/ftputils.cpp          FTPListingFieldToU8 uses the rule
src/saltests/saltests.cpp             TestFtpListingField269
specs/215-ftp-long-name-command/probe/ftpmini.py   ENC "wtf-8" (additive)
```

**Structure Decision**: the existing core / plug-in layout; the rule beside the other FTP rules
(`salftpautoren.h`, `salftpanon.h`).

## Complexity Tracking

None.
