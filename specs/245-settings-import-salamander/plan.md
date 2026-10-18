# Implementation Plan: Import settings from Altap Salamander and Open Salamander

**Branch**: `245-settings-import-salamander` | **Date**: 2026-10-18 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/245-settings-import-salamander/spec.md`;
evidence in [analysis.md](analysis.md), decisions in [research.md](research.md).

## Summary

An *Options → Import Settings from Salamander…* wizard (plus a one-time offer
at the first start of a fresh configuration) imports settings from Altap
Salamander 2.5–4.0 or Open Salamander 5.0 into the running Tandem Commander.
The source key is read once, read-only, into an in-memory snapshot; pure
rules (header `src/common/salcfgimport.h`, checked by `saltests`) turn it into
an import plan per group (hot paths, user menu, FTP connections, plugin
command shortcuts, viewers/editors, search criteria, histories, option groups,
colours, view templates, default directories, other plugins' settings). The
preview lists every change; overwriting choices are off by default and need
explicit consent (FR-010c). Apply: backup (configuration export) → in-memory
changes per group, all-or-nothing → the Configuration dialog's refresh →
`SaveConfig()`. FTP connections are merged by the FTP plugin itself through
plugin interface 108 (append-only). The 057 script is retired; constitution,
privacy statement and identity notes are updated.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143 (VS2022)
**Primary Dependencies**: WinAPI only; existing core services (registry export,
password manager, task list, plugin manager); no new third-party code
**Storage**: Windows registry — source roots read-only (`HKCU\Software\Altap\…`,
`HKCU\Software\Open Salamander\5.0`); destination `HKCU\Software\Tandem Commander\0.1`
(through the program's own `SaveConfig`, plus the plugin-settings subtree
replacement of R8); backup `.reg` under `%APPDATA%\Tandem Commander\Settings backups`
**Testing**: `saltests` (pure rules, fixtures in memory); `_DEBUG` automation
seam + PowerShell probes on the hidden desktop with fixture source roots
(`TC_CFGIMPORT_TEST_ROOT`), registry backup/restore of the product key,
byte-exact before/after exports; a UI probe for the wizard pages; independent
refute-first review agents
**Target Platform**: Windows 11+, x64
**Project Type**: desktop application (core `salamand.vcxproj`) + plugin (FTP)
**Performance Goals**: snapshot + plan of a real Altap 4.0 configuration < 1 s;
the whole wizard flow < 3 minutes for a user (SC-001)
**Constraints**: source never written (SC-002); no modal box while reading;
plugin ABI append-only (104–107 plugins keep loading); UTF-8/WTF-8 rule
(wide registry reads, no `A` API, no `CP_ACP`) except the master password,
which is code-page bytes in both programs (documented exception); house
dialog style (Constitution VI)
**Scale/Scope**: sources with tens to a few hundred items per group; 15 group
kinds; ~5 new dialogs; ~60 new UI strings

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Note |
|---|---|---|
| I. Build reproducibility | PASS | new sources join `salamand.vcxproj`, FTP project, `saltests`; no manual steps |
| II. Backward compatibility | **AMEND** (justified) | Principle II forbids reading predecessor configuration. The feature adds a narrow, explicit exception (read-only, user-started, plus the first-start existence check) — amendment 3.2.0 → 4.0.0 in the same change (FR-031). No identity is reintroduced; nothing changes unless the user starts the wizard and confirms (opt-in satisfied). Plugin ABI: append-only 107 → 108 |
| III. Incremental modernization | PASS | new code in new files; touched legacy code limited to: the refresh block of `WM_USER_CONFIGURATION` (factored into a method, behaviour unchanged), menu template, start-up hook, plugin entry object, password-manager static helpers |
| IV. Windows commitment | PASS | WinAPI only |
| V. Plugin architecture | PASS | interface documented first (`contracts/plugin-api-v108.md`, `architecture/06`) |
| VI. UI consistency | PASS | `DIALOGEX` + `DS_SHELLFONT` + `MS Shell Dlg 8`, `CCommonDialog`, themed controls, dark theme |

Post-design re-check: PASS (the amendment is a tracked deliverable, T-docs).

## Project Structure

### Documentation (this feature)

```text
specs/245-settings-import-salamander/
├── spec.md, analysis.md, research.md, plan.md, data-model.md, quickstart.md
├── contracts/
│   ├── plugin-api-v108.md        # interface 108 (append-only)
│   ├── salcfgimport-rules.md     # pure rules + saltests obligations
│   ├── wizard-flow.md            # pages, controls, states, texts
│   └── options-table.md          # the allow-list of option values
├── checklists/requirements.md
├── fix-log.md, tasks.md (next), probe/, closing-report.md (end)
```

### Source Code

```text
src/common/salcfgimport.h          # NEW pure rules: source table, snapshot tree, parsers, planners
src/cfgimport.h / cfgimport.cpp    # NEW engine: discovery, snapshot reader, plan, apply, backup, report, seam
src/cfgimpdlg.cpp                  # NEW wizard pages
src/mainwnd*.cpp, menu4.cpp        # menu item, command, refresh method, first-start offer message
src/salamdr1.cpp                   # freshConfig detection, offer posting
src/pwdmngr.cpp/.h                 # static verify/decrypt helpers for a foreign verifier/password
src/plugins.h, plugins1.cpp        # entry append, handler pointer on CPluginData, context object
src/plugins/shared/spl_base.h      # interface 108 classes + entry method
src/plugins/shared/spl_vers.h      # LAST_VERSION_OF_SALAMANDER 108 + history
src/plugins/ftp/ftpimport.cpp      # NEW FTP handler (Plan/Apply) + registration in the entry
src/lang/lang.rc, texts.rc2, *.rh  # dialogs and strings
src/saltests/saltests.cpp          # TestCfgImport245
src/vcxproj/*.vcxproj              # new files
help/src/hh/salamand/              # new help page + menu reference
utils/                             # 057 script retired
```

**Structure Decision**: core feature (it needs the running program's
in-memory configuration), with FTP's private format kept inside the FTP
plugin behind interface 108.

## Phases (implementation order, each closed by build + tests before the next)

1. **Foundation** — pure header + `saltests`; snapshot reader; discovery;
   plan/report skeleton; backup; instance check; menu command; wizard pages
   with the hot-path group end to end (MVP of US1 without FTP).
2. **Core list groups** — user menu, viewers/editors, plugin shortcuts,
   search criteria, histories.
3. **Interface 108 + FTP** — contract, headers, core context, FTP handler,
   passwords page.
4. **Option groups** — allow-list table, colours/highlighting, view
   templates, default directories, plugin settings (R8).
5. **First-start offer, automation seam, probes** — fixtures, e2e runs,
   UI probe, Release build.
6. **Documents, translations, retirement of the 057 script, reviews** —
   constitution, privacy, identity notes, changelog, help, `.slt` refresh,
   independent refute-first reviews, fixes, closing report.

## Complexity Tracking

| Deviation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Constitution II amendment | the feature is by definition reading a predecessor's configuration | an external tool (057) proved hard to find, untranslated, replace-only — and it overwrote TC settings |
| Plugin interface 108 | FTP merge must stay inside the FTP plugin (Q3) | core knowledge of FTP's layout = layering break |
| Master password read as code-page bytes | the old program derived its key from code-page bytes | UTF-8 would make every non-ASCII master password fail |
