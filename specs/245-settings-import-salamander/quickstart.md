# Quickstart — validating feature 245

Prerequisites: `build.cmd` (Debug x64) and `build.cmd full release` succeed;
`saltests` passes. GUI runs only on the hidden desktop
(`tools/run_on_hidden_desktop.ps1`); every probe exports
`HKCU\Software\Tandem Commander` first and restores + verifies it at the end
(never touches the real `HKCU\Software\Altap` / `Open Salamander` keys — the
fixtures live under `HKCU\Software\Tandem Commander Test 245\…` and reach the
program through `TC_CFGIMPORT_TEST_ROOT`).

## V1 — unit rules

`build\…\saltests.exe` → `TestCfgImport245` all checks pass (rules of
`contracts/salcfgimport-rules.md`, negative controls included).

## V2 — e2e matrix (automation seam, Debug)

`specs/245-*/probe/ci245_e2e.ps1 -Exe <debug exe>`: for each scenario it
creates the fixture source(s) and a fixture TC configuration, runs the
program with `TC_CFGIMPORT_AUTORUN=<script>`, waits for its exit, exports
the TC key and the source key, compares:

| Scenario | Expectation |
|---|---|
| S1 defaults (hot paths, user menu, FTP, plugin keys, find sets — Add; viewers unticked) | items added as in US1; **0 existing TC values changed** (SC-010): every TC value present before is byte-identical after, except the lists that grew |
| S1v viewers ticked | without consent not applied (rows before `*.*` are changes); with consent added before the catch-all |
| S2 every group, Replace / take over, consent | groups equal the source's; TC-owned values (FR-016) unchanged; plugin registration unchanged |
| S3 run S1 twice | second run adds nothing (SC-005) |
| S4 source byte-identity | the source key's export before = after, every scenario (SC-002) |
| S5 cancel / no consent | nothing changed |
| S6 source version 103, 104, 105, 46 (< 47 → `$` doubled, < 44 → lower-case masks), 38 (refused), 107 (refused) | as research R2/R3 |
| S7 passwords: scrambled, AES with right / wrong / no source master password, TC with / without master password, weaker-storage consent on/off | research R10; TC master password unchanged (SC-009) |
| S8 plugin viewer rows (mapped / unmapped plugin), plugin keys conflicting with TC keys | R5/R7 |
| S9 another instance running | refused, nothing changed |
| S10 backup | file exists; importing it (`-C`) restores the pre-import export exactly (SC-008) |
| S11 non-ASCII names in hot paths, menu, FTP | unchanged text (FR-007) |
| S12 first start with a fixture source | offer shown once (UI probe), answered ⇒ never again |

## V3 — wizard UI probe

`probe/ci245_ui.ps1`: opens the wizard from the menu, walks the five pages
by control IDs, checks enabling rules (Next disabled with nothing ticked,
Import disabled until consent), cancels on each page (nothing changed),
completes one Add run, captures each page (also in the Dark theme).

## V4 — Release

The e2e matrix's S1/S2/S4 against the Release build through the UI probe
(the seam is Debug-only).

## Manual (owed to a person)

Run the wizard against a real Altap Salamander 4.0 configuration with
master-password-protected FTP passwords; log in to one imported server.
