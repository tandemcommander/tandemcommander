# Implementation Plan: Portable build of Tandem Commander

**Branch**: `428-portable-build` | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/428-portable-build/spec.md` (15 clarifications in
three passes; low-impact points take the recommendations of
[clarify-questions.md](clarify-questions.md))

## Summary

A second **edition** of the program, compiled from the same sources with `TC_PORTABLE` by
`build.cmd … portable` into `build\tandemcommander\<Config>_x64_portable\`, packaged as
`tandemcommander-<ver>-x64-portable.zip`. The portable executable never writes the registry: at
start it builds a **private session hive** (`RegLoadAppKeyW`, invisible to the rest of Windows) in
`%TEMP%\TandemCommander-portable-<scope>\` from **`settings\tandemcommander.reg`** next to the
executable (the program's own export format), runs the whole program and every plug-in on that
hive through one base key, and writes the hive back to the file after every change (2 s debounce),
after each configuration save and at exit — atomically, with `$(SalDir)` for paths inside its own
folder. Web-viewer data lives in the same temporary folder and everything there is deleted at exit.
Plug-ins are unchanged binaries; three appended API methods (interface **109**) tell them the
edition, the data folders and a scope suffix for their named objects. The portable copy shows
`[portable]` in the title, a "Portable edition" line and a `settings` link in About, a badge icon;
it checks for new versions and only links to the release page (requires the ZIP asset). No shell
extension, no jump list, no update download. `build.cmd dist` builds and signs the complete release
(installer + ZIP) in one command; every release attaches the ZIP.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143 (VS 2022), pure WinAPI; batch
(`build.cmd`), Python 3 (build tools, ZIP), PowerShell (probes)
**Primary Dependencies**: none new. Win32 `RegLoadAppKeyW`, `RegNotifyChangeKeyValue`,
`GetFileInformationByHandleEx`; in-tree `reglib` (dump / parse, Unicode-clean since 174),
`salsafereplace.h` (`SalReplaceWithTempW`), `salnameorder.h` (path comparison), WebView2 host
(`src/common/webhost`)
**Storage**: portable — `settings\tandemcommander.reg` (UTF-16 `.reg` v5) persistent + session hive
in `%TEMP%` (measured 512 KB for a long-used configuration of 349 keys / 1,858 values); normal —
unchanged `HKCU\Software\Tandem Commander\Settings`
**Testing**: `saltests` (new group `TestPortable428` + update-check portable asset), a lossless
round-trip gate test of dump / parse on the real configuration, GUI / system probes on the hidden
desktop in `specs/428-portable-build/probe/` (registry + profile snapshot diff, move, read-only,
kill-during-save, side-by-side, update fixture)
**Target Platform**: Windows 11+, x64 (as the normal edition)
**Project Type**: desktop application (core exe + plug-in DLLs) and its build / release tooling
**Performance Goals**: start and save within 10 % of the installed copy (SC-009); measured hive
load + full read 66 ms, full write + flush 117 ms (PowerShell)
**Constraints**: plug-in ABI append-only (constitution V); the normal edition bit-for-bit
unchanged in behaviour (FR-018, SC-010); no registry write by the portable program (SC-002); a
path is never cut; UTF-8 / WTF-8 rules (066) for every new path; `PRIVACY.md` in the same change
**Scale/Scope**: ≈ 15 core files get the base key; ~10 core files get `TC_PORTABLE` branches
(start-up chain, title, About, update, shell extension, jump list, bug reports, export defaults,
password note); 3 plug-ins (webhost users codeview / mdview, pictview, filecomp); build: 19
project / sheet files, `build.cmd`, `build_langs.cmd`, 2 new Python tools; release:
`backlog/RELEASE.md`, `tools/release/release.py`

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Pre-research | Post-design |
|-----------|--------------|-------------|
| I. Build reproducibility | `build.cmd` stays the one entry; no new dependency (Python already required) | **Pass** — `portable` / `dist` documented; deterministic ZIP (sorted, commit time stamps); output check `check_outdir_suffix.py` |
| II. Backward compatibility (baseline 0.1.0) | the normal edition must not change | **Pass** — every difference is under `TC_PORTABLE`; `SalCfgBaseKey()` is the constant `HKEY_CURRENT_USER` in the normal build; SC-010 compares the normal tree and installer before / after |
| III. Incremental modernization | risk: a sweep over ~15 files | **Pass** — the base-key change is mechanical, one helper, a classification check script; no adjacent refactoring |
| IV. Windows platform commitment | — | **Pass** — Win32 only (app hives, change notification) |
| V. Plugin architecture preservation | plug-ins get raw `HKEY`s | **Pass** — the session hive *is* a registry, plug-ins unchanged; API 109 appended with contract ([contracts/plugin-api-109.md](contracts/plugin-api-109.md)) **before** the change, history in `spl_vers.h` |
| VI. UI consistency | new About controls, messages | **Pass** — About controls created in the dialog's font with the existing link behaviour; standard message boxes; translations through the normal pipeline; Dark / High Contrast checked |
| Standing rules (CLAUDE.md) | WebView2 binding contract, `PRIVACY.md`, translations, never lose data | **Pass** — `architecture/11` amended in the same change (still one folder / one argument function / one builder); `PRIVACY.md` portable section (FR-019); `.slt` two-stage refresh inside the feature; atomic replace + `.bak` (105-style) |

No violation — *Complexity Tracking* is empty.

## Project Structure

### Documentation (this feature)

```text
specs/428-portable-build/
├── spec.md                 # clarified specification
├── clarify-questions.md    # question catalogue + status of the three passes
├── state-inventory.md      # measured: what the program stores outside its folder today
├── plan.md                 # this file
├── research.md             # Phase 0: measurements and decisions R-01 … R-14
├── data-model.md           # Phase 1: folders, store states, start decision, names
├── quickstart.md           # Phase 1: how to validate end to end
├── contracts/
│   ├── build-cli.md            # build.cmd portable / dist, MSBuild property, output layout
│   ├── package-layout.md       # the ZIP: name, layout, contents, README
│   ├── settings-store.md       # the portable store: interface, guarantees, messages
│   ├── plugin-api-109.md       # three appended plug-in methods
│   ├── update-check-portable.md# asset rule and gating in the portable edition
│   └── ui-identity.md          # title, About, icon, shell-extension and password notes
├── checklists/requirements.md
├── probe/                  # (implementation) probes and their logs
├── fix-log.md              # (implementation) running log
└── tasks.md                # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
build.cmd                              # portable, dist, OUT_DIR suffix, ZIP step, summary
src/Directory.Build.props              # NEW: TcOutSuffix from TcEdition
src/Directory.Build.targets            # Release IntDir rewrite with the suffix
src/vcxproj/sal_base.props             # TC_PORTABLE for salamand (ClCompile + ResourceCompile); OutDir suffix
src/vcxproj/*.props, src/plugins/shared/vcxproj/*.props, 7za/fcremote/exif/chmlib/zip2sfx/
  salopen/shellext/sqlite/saltests project files      # the 19 OutDir literals + $(TcOutSuffix)
src/vcxproj/build_langs.cmd            # output path with the suffix
src/common/salportable.h               # NEW, pure: scope, names, relativize/expand, start decision
src/portstore.h / portstore.cpp        # NEW: the store (open, seed/join, notify+debounce, persist, close, stale clean-up)
src/regwork.cpp, consts.h              # SalCfgBaseKey()
src/mainwnd2.cpp, plugins1.cpp, salamdr1.cpp, salamdr2.cpp, mainwnd3.cpp, cfgimport.cpp,
  updcheck.cpp, callstk.cpp, tasklist.cpp, dialogs4.cpp  # base key at config sites; scoped names; skips
src/reglib/src/registry.cpp (+ factory)                # base key for "HKEY_CURRENT_USER\…" names
src/mainwnd1.cpp                       # title marker
src/logo.cpp                           # About: edition line + settings link
src/salamand.rc2, src/res/salamand_portable.ico, version resource   # badge icon, FileDescription
src/shellsup.cpp, salamdr1.cpp         # no shell-extension registration; IDS_PORTABLE_NOSHELLEXT
src/jumplist.cpp, mainwnd3.cpp         # jump list off; icon-size write skipped (portable)
src/pwdmngr.cpp                        # password note (FR-015a)
src/common/salupdcheck.h, updinstall.cpp, upddlg.cpp, dialogs4.cpp  # portable asset rule, gating
src/salamdr5.cpp, mainwnd3.cpp, cfgimport.cpp, callstk.cpp           # settings\ defaults, BugReports, Backups
src/plugins/shared/spl_gen.h, src/common/spl_vers.h, src/zip.cpp     # API 109 (+ core implementation)
src/common/webhost/webhost.cpp         # TcWebUserDataFolder() via GetUserDataFolderW
src/plugins/mdview/webglue.cpp, pictview/render2.cpp, filecomp/*, shared/lukas/messages.cpp  # plug-in users
src/lang/lang.rc2 (+ translations/*.slt refresh, ui-overrides.json)  # new strings
src/tests (saltests)                   # TestPortable428, update-check portable cases
tools/portable/make_portable_zip.py, README-portable.txt             # NEW
tools/check_outdir_suffix.py, tools/check_portable_regsites.py       # NEW build checks
tools/brand/gen_icons.py (+ README)    # --portable badge variant
tools/release/release.py, backlog/RELEASE.md                         # dist step, ZIP artefact check
PRIVACY.md, CHANGELOG.md (unreleased), README / help                  # public claims and docs
architecture/06-plugin-api.md, architecture/11-webview2-integration.md, architecture/12-project-reference.md
```

**Structure Decision**: no new project; the portable edition is the existing solution built with
one MSBuild property. New code is one core module (`portstore`) and one header-only rule set
(`salportable.h`, testable in `saltests`), the rest are guarded branches at existing sites.

## Implementation order (for `/speckit-tasks`)

1. **Gate**: round-trip test (reglib dump / parse on the real configuration hive) — stop and fix
   reglib if anything is lost.
2. Build plumbing (`TcEdition`, suffix, checks, `build.cmd portable` without ZIP) — the normal tree
   proven unchanged.
3. `salportable.h` + saltests; `portstore` + `SalCfgBaseKey()` sweep + start-up chain; the
   no-trace probe green.
4. Instance scoping, read-only / damaged-file handling, kill-during-save, move probes.
5. API 109 and the plug-in users (webhost, mdview, pictview, filecomp).
6. Identity (title, About, icon), shell-extension note, password note, jump list / icon-size skips.
7. Update check portable rule and gating.
8. ZIP, `dist`, release tooling, `PRIVACY.md`, docs, translations refresh.
9. Two refute-first reviews; closing report; manual-check lines for the release checklist.

## Risks

| Risk | Mitigation |
|------|------------|
| A config site still writes HKCU in the portable edition | `check_portable_regsites.py` classification in the build + the snapshot-diff probe (SC-002) |
| reglib loses a value type or a name in the round trip | gate test first (R-14); fix inside the feature |
| A crash leaves the user's configuration in `%TEMP%` of a foreign PC | accepted by the maintainer (R-01); stale clean-up at any portable start; `%TEMP%` is per-user |
| `RegNotifyChangeKeyValue` misses a change or fires during the program's own dump | dump under the store lock; notification re-armed before the dump reads; the exit persist is unconditional when anything was written since the last dump |
| Two instances of one copy persisting at once | `…_Store` mutex; dumps are of the same shared hive, so idempotent |
| Building the solution twice makes `dist` slow | accepted for a release; measured and reported |
