# Fix log - 263 import foreign registry keys

Backlog item `importing-a-configuration-file-writes-every-key-of-a-foreign` (source measure:245,
analysis.md A11.1). Run of 2026-10-20, `main` at `0e36adce`.

## Measurement before (0e36adce)

Build: `.\build.cmd` (Debug x64, up to date). Probe written for this feature:
`probe/import263_probe.ps1` - starts the program with `-c <fixture>\config.reg` (UTF-16 "Windows
Registry Editor Version 5.00"), records the boxes of the start, answers Yes / OK, closes the program
and reads the registry; registry backed up / restored / verified (fix_probe_lib of 098).

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\263-import-foreign-reg-keys\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\263-import-foreign-reg-keys\probe\import263_probe.ps1 -Label before -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
```

Result `probe/result_before.txt`: PASS 7, FAIL 3, registry restored identical.

| Row | File | Before |
|---|---|---|
| OURS | only `[HKCU\Software\Tandem Commander\0.1\Probe263]` | PASS - imported, no box |
| OWNDEL | `[-...\0.1\Probe263Old]` + our key | PASS |
| MIXED | our key + `[HKCU\Software\TC263ProbeForeign]` | **FAIL - no box, the foreign key written** |
| NOROOT | only the foreign key | **FAIL - question NOTOURVER, Yes wrote it** |
| DELETE | our key + `[-HKCU\Software\TC263ProbeVictim]` | **FAIL - another key deleted, no box** |

The defect is wider than the item: a file that contains our root writes and deletes foreign keys
silently (no question at all).

## Consumers (fix protocol)

- `Parse()` (reglib, `src/reglib/src/regparse.cpp`): callers `src/salamdr2.cpp` ImportConfiguration
  (memory pass + registry pass) and `src/reglib/src/tester.cpp` (stand-alone REGLIBA tester, not in
  `salamand.sln`; unchanged thanks to the defaulted parameter).
- `ImportConfiguration()`: only `WinMainBody` (`src/salamdr1.cpp`), every start, `config.reg` next to
  the exe / in `%APPDATA%\Tandem Commander` / `-C`.
- `IDS_IMPORTCFG_NOTOURVER`: only `ImportConfiguration` - unused after the change, kept (084).
- `ExportConfiguration()`: `CopyBranch` of `HKCU\<SALAMANDER_ROOT_REG>` only, optional delete line of
  the root first - its files stay inside the rule.

## Decisions

See spec *Clarifications*: refuse the whole file (`IDS_IMPORTCFG_NOTREG`) when any key or delete
line is outside `HKCU\Software\Tandem Commander\0.1`, or when no key under the root exists; no new
string; restriction applied in both passes.

## Analyze

speckit-analyze: 0 CRITICAL, 0 HIGH. E1 (MEDIUM, HKCR case not driven) fixed by a probe row HKCR;
C1 (LOW, FR-007 without a task) named in T006/T007; D1 (LOW, principle II: non-opt-in change)
accepted - the plan's Complexity Tracking justifies it with principle II's own "never writes other
products' configuration".

## Implementation

- `src/common/salregroot.h` (new): `SalRegKeyIsInsideRoot(name, root)` - equal to the root or the
  root followed by `\`, ASCII case-insensitive, other bytes exact; empty / NULL outside.
- `src/reglib/src/regparse.h`: `RPE_KEY_OUTSIDE_ROOT` appended to `eRPE_ERROR`; `Parse(...,
  LPCTSTR onlyUnderHKCU = NULL)`.
- `src/reglib/src/regparse.cpp`: at every `[` / `[-` line, after the root key and the name are
  recognised and before `CreateKey` / `OpenKey` / `DeleteKey`: with a restriction, a root key other
  than `HKEY_CURRENT_USER` or a name outside the root -> `TRACE_E` of the line and
  `RPE_KEY_OUTSIDE_ROOT`. Also a bare `[HKEY_CURRENT_USER]` (empty name) is outside. Outside the
  core's code-page build a restriction refuses every key line (no such caller).
- `src/salamdr2.cpp` `ImportConfiguration`: both passes get `SalamanderConfigurationRoots[0]`; no key
  under our root -> `RPE_NOT_REG_FILE` (the question `IDS_IMPORTCFG_NOTOURVER` is gone, the string
  stays in `texts.rc2`, unused); `RPE_KEY_OUTSIDE_ROOT` -> `IDS_IMPORTCFG_NOTREG`; a `TRACE_E` names
  the refused file.
- `src/saltests/saltests.cpp`: `TestRegImportRoot263`, 20 checks.
- Not listed in `salamand.vcxproj(.filters)` (T004): the recent rule headers of 257 and 262 are not
  listed either; the include is tracked by the build.
- Probe: row HKCR added (analysis E1).

## Checks after

| Check | Command | Result |
|---|---|---|
| encoding guard | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |
| build | `.\build.cmd` | `BUILD SUCCEEDED` (the two C4018 warnings at `salamdr2.cpp:1058/1066` are older code) |
| unit rules | `saltests.exe` | `saltests: 24679 checks, 0 failed` |
| probe | quickstart step 3 -> `probe/result_after.txt` | PASS 12, FAIL 0, NOT DRIVEN 0; registry restored identical; no probe key left |

After (`probe/result_after.txt`): OURS and OWNDEL import as before, no box; MIXED, NOROOT, DELETE,
HKCR show "Unable to import the specified file. It is not a configuration file. File: ..." and write
nothing (foreign key absent, victim still there, class key absent in HKCU and HKLM classes, our key
of the same file not imported).

Negative controls:
- the probe rows MIXED / NOROOT / DELETE fail on the build of `0e36adce` (`probe/result_before.txt`);
  the HKCR row was added after the before run - on the old build it cannot show the refusal message
  its PASS needs (reasoned, not run);
- `salregroot.h` broken by hand (`return TRUE` instead of the `\` boundary test): `saltests: 24679
  checks, 2 failed` (the `0.10` / `0.1x` siblings); restored, `0 failed`.

## Review

### Review 1 (independent agent, refute-first) - 1 MUST, 1 SHOULD

- **MUST**: every file the program exports was refused. `CKey::Dump`
  (`src/reglib/src/reginmem.cpp`) writes a line for every key except the HKEY roots, so a real
  export / feature 245 settings backup holds `[HKEY_CURRENT_USER\Software]` and
  `[HKEY_CURRENT_USER\Software\Tandem Commander]` (no values) before the root; the rule refused
  them. Reproduced by the reviewer on the hidden desktop (copy of the probe with a row EXPORTSHAPE:
  FAIL, the refusal box) and on the newest backup's first lines. T010 had been ticked from reading
  `ExportConfiguration` only - the dump's parent lines were missed. Consequence: `config.reg` / `-C`
  of an exported file, and 245's restore advice (`IDS_CFGIMP_RESTORE`, `-C "<backup>"`), broken; no
  data lost (refused in the memory pass).
- **SHOULD**: no probe row used real program output.
- NOTES: the main defect fixed as described; rule boundary and fail-closed DBCS / non-ASCII
  behaviour hold; callers: `Parse` - `ImportConfiguration` (both passes) + the stand-alone tester;
  `ImportConfiguration` - `salamdr1.cpp`; `ExportConfiguration` - `mainwnd3.cpp`, `cfgimport.cpp`.

Fix:
- `salregroot.h`: `SalRegKeyIsParentOfRoot` (root starts with the name followed by `\`); shared
  `SalRegRootStartsWithCI`.
- `regparse.cpp`: a key line (not a delete line) of HKCU naming a parent of the root creates nothing
  and sets `inParentOfRoot`; a value line (set or delete) while it is set returns
  `RPE_KEY_OUTSIDE_ROOT`; a delete line of a parent stays refused.
- saltests: 14 checks for the parent rule (`saltests: 24693 checks, 0 failed`).
- probe: rows EXPORTSHAPE (the dump's shape), PARENTVAL (a value in the parent - refused, not
  written), PARENTDEL (`[-HKCU\Software\Tandem Commander]` - refused), EXPORTCLEAR (clear-key line +
  parents + the whole current configuration from `reg export` + our key), REALBACKUP (the newest
  real 245 backup, `before-import-20261020-051339.reg`; NOT DRIVEN when none).
- Spec FR-001, Clarifications, Edge Cases, Assumptions; contract; research R5 corrected.

After (`probe/result_after2.txt`): PASS 22, FAIL 0, NOT DRIVEN 0; registry restored identical
(SHA-256 `A46438BF...` before and after); no probe key left. Negative control of the new rows: the
reviewer's EXPORTSHAPE row FAILED on the first fixed build (`35b787cd`).

Process note: a Bash here-document turned `\0` of a probe line into a NUL byte (CLAUDE.md rule
123); found by `grep` reporting a binary file, repaired before the run.
