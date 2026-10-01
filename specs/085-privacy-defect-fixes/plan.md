# Implementation Plan: Privacy defect fixes (085)

**Branch**: `085-privacy-defect-fixes` | **Date**: 2026-10-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/085-privacy-defect-fixes/spec.md`

## Summary

Fix the five privacy defects feature 083 recorded and left open (F1, F2, F3,
F6, F7), turn off the viewer engine's crash upload (F4, decided 2026-10-01),
correct the WebView2 contract's description of its data folder (F5), and
update `PRIVACY.md`, `CHANGELOG.md` and `NEXT-WORK.md` in the same change.
Each defect is one commit, reviewed independently before the next starts
(the 069 fix protocol). No plugin-interface change.

| Defect | Where | Fix (research) |
|---|---|---|
| F1 | core histories (5 sites + load), plugin history service, FTP Quick Connect (+ load) | shared pure rule `src/common/salurlpwd.*` applied to history copies only (R1–R3) |
| F3 | `src/common/webhost/webhost.cpp` navigation + new-window handlers | forward to the link handler only if `IsUserInitiated` (R4) |
| F2 | `src/plugins/mdview/webglue.cpp` `FetchRemote` | move to `remotefetch.*`; new user agent, cookies + auto-auth off, 2xx only (R5) |
| F7 | `src/plugins/sftp/dialogs.cpp` `ConnectReadFields` | cancelled prompt → do not save, uncheck (R7) |
| F6 | `src/pwdmngr.cpp` `FillBufferWithRandomData` | `BCryptGenRandom` (R6) |
| F4/F5 | `webhost.cpp`, `webkeeper.cpp`, new internal `webenvopts.h`, `architecture/11-…` | the keeper's duplicate options builder is deleted; the one `TcWebBuildEnvOptions()` sets the arguments **and** crash reporting for both (R8) |

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI; WinHTTP (mdview); BCrypt (new import of the
core: `bcrypt.dll`, a system DLL, not network-capable); WebView2 SDK
1.0.4078.44 (vendored)
**Storage**: registry histories (`HKCU\Software\Tandem Commander\0.1\…`)
**Testing**: `saltests` (pure rule, new `TestUrlPasswordStrip085`); a fetch
probe (`probe/fetch_probe.cmd` + a Python logging server) for F2; builds for
the rest; GUI scenarios recorded as owed (`quickstart.md`)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application + plugins
**Constraints**: plugin interface 106 unchanged; no configuration version
change (MINORB); `PRIVACY.md` updated in the same change
**Scale/Scope**: ~10 source files, one new shared module, one moved function

## Constitution Check

| Principle | Assessment |
|---|---|
| I. Build reproducibility | New files are added to the projects; no manual step. `bcrypt.lib` by `#pragma comment`. ✅ |
| II. Backward compatibility | Behaviour changes are defect fixes with documented justification (spec + changelog): history entries lose the password part, a document can no longer trigger navigation, a cancelled prompt no longer saves a weaker secret. Stored passwords stay readable (salts stored with data). No registry migration; old history entries are cleaned when next saved. ✅ (justified) |
| III. Incremental modernization | One commit per defect; only the touched functions change. `FetchRemote` is moved verbatim, then changed in the same commit with the diff limited to the three fixes. ✅ |
| IV. Windows platform | WinAPI only. ✅ |
| V. Plugin architecture | No interface change; the plugin-facing history service gains behaviour for two core-owned arrays only, documented in the contract. `src/plugins/shared/` untouched. ✅ |
| VI. UI consistency | No dialog or control change (the SFTP checkbox is only unchecked). ✅ |

## Project Structure

### Documentation (this feature)

```text
specs/085-privacy-defect-fixes/
├── spec.md
├── plan.md               # this file
├── research.md           # R1–R9: inventory and decisions
├── contracts/
│   └── history-password-strip.md
├── quickstart.md         # owed GUI steps + how to run the probes
├── tasks.md
├── fix-log.md            # written during implementation
└── probe/                # fetch probe (F2)
```

### Source Code (repository root)

```text
src/common/salurlpwd.h, salurlpwd.cpp      # NEW: the F1 rule (C1–C3)
src/saltests/saltests.cpp                  # TestUrlPasswordStrip085
src/vcxproj/salamand.vcxproj, saltests/…   # + salurlpwd.cpp/.h
src/dialogs3.cpp, src/finddlg1.cpp, src/editwnd.cpp, src/zip.cpp, src/mainwnd2.cpp
src/plugins/ftp/dialogs1.cpp, ftp.cpp, vcxproj/ftp.vcxproj
src/common/webhost/webhost.cpp, webkeeper.cpp, webenvopts.h (NEW, internal, WRL)
src/plugins/mdview/webglue.cpp, remotefetch.h, remotefetch.cpp (NEW), vcxproj/mdview.vcxproj
src/plugins/sftp/dialogs.cpp
src/pwdmngr.cpp
architecture/11-webview2-integration.md
PRIVACY.md, CHANGELOG.md, specs/NEXT-WORK.md, CLAUDE.md
```

**Structure Decision**: existing layout; the one new shared module follows the
`src/common/sal*.{h,cpp}` pure-helper pattern (070/078/079/080/084), the one
new plugin file follows mdview's per-concern files.

## Phases

1. **F1** (P1): module + tests → core sites → plugin service → load → FTP.
   Gate: `saltests` green, Debug build, independent review.
2. **F3**: webhost handlers. Gate: Debug build, review.
3. **F2**: move + fix, probe against a local server. Gate: probe green, review.
4. **F7**, **F6**: one commit each. Gate: build, review.
5. **F4/F5**: one options builder for host and keeper; contract doc. Gate: build,
   `rg -c "put_IsCustomCrashReportingEnabled" src/` == 1, review.
6. **Records**: `PRIVACY.md`, `CHANGELOG.md` *Unreleased*, `NEXT-WORK.md`
   item 7, `CLAUDE.md` *Recent Changes*, fix-log, quickstart. Full Debug and
   Release builds, `saltests`, encoding guard.

## Complexity Tracking

No constitution violations to justify.
