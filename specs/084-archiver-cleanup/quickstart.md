# Quickstart / Validation Guide: Working Archivers Only (feature 084)

These scenarios prove the spec's success criteria. Contracts and the data model
are referenced, not repeated. Steps that need a person, or software this
machine does not have, are marked **(person)** and are recorded as owed in
`fix-log.md` if not done.

## 0. Prerequisites

- VS 2022, Python 3.13+, `OPENSAL_BUILD_DIR` (optional).
- 7-Zip installed (`C:\Program Files\7-Zip\7z.exe`; present on the development
  machine, 22.01).
- **(person)** WinRAR 7.x for the RAR packer scenarios (§4). It is not
  installed on the development machine.
- Fixtures in `specs/084-archiver-cleanup/probe/fixtures/`:
  - the libarchive RAR test set (RAR4, RAR5, encrypted data and headers,
    Unicode names, multi-volume);
  - ARJ and LZH samples from libarchive's test suite (7-Zip cannot create
    them);
  - a 7-Zip-created archive with Czech, Chinese and emoji names. 7-Zip can
    create a `.zip` or `.7z`; renamed to an extension mapped to 7-Zip, it
    exercises the console path.
- The feature that upgrades the vendored 7-Zip to 25.x must be merged before
  §3 (RAR) can pass. Every other section is independent of it.

## 1. Build and unit tests

```bat
build.cmd full
build.cmd full release
```

Expected:
- Both builds succeed, `check_encoding.py` strict `TOTAL: 0`, and
  `check_runtime_deps.py` passes.
- `salspawn` no longer appears in the solution, the generated filter or any
  output tree (`rg -n -i salspawn src build.cmd setup` → only history
  comments, if any).
- `saltests.exe` passes. It is above its 1527 baseline, with new groups for
  the `-slt` parser ([contracts/7z-slt-listing.md](contracts/7z-slt-listing.md)
  P4) and the migration decisions
  ([contracts/config-migration-106.md](contracts/config-migration-106.md)
  M1–M3, including idempotence).

## 2. External launch and cancel (SC-001, FR-005, FR-006)

Use a configuration with 7-Zip found by Autoconfiguration.

| Step | Expected |
|---|---|
| Enter on `fixtures\sample.arj` | listing appears; names, sizes and dates equal `7z l -slt` |
| F5 one file and a selection out of it, to a path with spaces and `ř` | files extracted; byte-identical to a reference extraction |
| F3 on a file inside | the viewer opens the correct file |
| Same on `sample.lzh` and on the Unicode-name archive | names intact, including Chinese and emoji |
| Rename `7z.exe` temporarily, then press Enter on the archive | the archive is treated as an ordinary file (entry hidden, FR-017); no error mentions a helper |
| Restore `7z.exe`, re-run Autoconfiguration | archive opens again with no other step |
| Unpack a large archive (≥ 1 GB, created with 7-Zip) and press **Cancel** | the wait window closes, `7z.exe` is gone (Task Manager / `tasklist`), nothing is left in the target (temporary folder removed), no error box |
| Probe `probe/gui_probe.ps1` (launch scenarios; a separate `launch_probe.ps1` was not written) | asserts no `salspawn` process ever appears, the archiver is a child of `tandemcommander.exe`, and Cancel leaves no orphan |

## 3. RAR out of the box (SC-004) — after the 7-Zip upgrade feature

On a clean Windows 11 VM or Windows Sandbox with **no** WinRAR or 7-Zip
installed **(person or Sandbox script)**:

| Fixture | Expected |
|---|---|
| RAR4, RAR5 | listing and extraction OK, content identical |
| Encrypted data, RAR4 and RAR5 | password prompt (Unicode password accepted); wrong password reported plainly; nothing presented as extracted |
| Encrypted headers | password asked before the listing |
| Multi-volume RAR5 (8 parts), RAR4 (4 parts) | opened from the first part; all files extracted |
| Unicode names | intact |
| Damaged archive | error in plain terms; no partial result presented as complete |
| Alt+F5 on that machine | **no** RAR packer offered (FR-017, US1 scenario 3) |

## 4. RAR packing with WinRAR **(person)**

With WinRAR 7.x installed and Autoconfiguration run:

- Alt+F5 offers "RAR (WinRAR)".
- Run pack, pack-and-move, F5 into an open `.rar`, and delete inside a `.rar`,
  with Unicode names. The results open in WinRAR with correct names.
- Wrong-password and read-error exit codes show their messages.

## 5. Upgrade migration (SC-005, US4)

`probe/gui_probe.ps1` (scenario `migration`; a separate `migration_probe.ps1` was not written) follows the 078/079 registry backup and restore
recipe, key by key:

1. Load three 0.1.8-shaped configurations from `probe/fixtures/*.reg`:
   - (a) untouched defaults;
   - (b) an edited ARJ default entry plus an edited RAR "1.44MB volumes"
     entry;
   - (c) a custom entry calling `C:\Tools\myarc.exe` with DOS variables, and
     one using `$(Rar32bitExecutable)` with its own arguments.
2. Start the Debug build, exit normally, export the key.

Expected:
- (a) and (b): every entry referring to a removed archiver is gone, and so is
  the RAR volume preset.
- (c): both entries are byte-identical.
- Associations follow the M2 table, and the 7-Zip records follow M3.
- Diff outside `Packers & Unpackers` = only the M5 allow-list.
- A second start changes nothing (idempotence).
- A fresh registry starts with the new defaults and no migration.

## 6. No obsolete texts (SC-002, FR-012, FR-013)

```bat
rg -n -i "MS-DOS|External DOS|External Win32|1\.44 ?MB|salspawn" translations src\lang help\src
```

- Expected: no hits, apart from documented history comments.
- Visual pass **(person)** in English and Czech: Pack and Unpack dialogs, the
  Packers, Unpackers, External Archivers and Associations configuration pages,
  Archivers Autoconfiguration.
- The translation dry run reports 0 gaps beyond the newly added strings in
  every enabled language (079 procedure, research R10).

## 7. Inventory (SC-006, FR-014)

- `inventory.md` lists every extension that 0.1.8 or 084 knows. For each it
  gives the handler, the status (kept / removed / new) and the reason.
- A script cross-checks it against the compiled defaults and the plug-in
  registrations: `probe/inventory_check.py`, 0 differences.

## 8. Regression (FR-010, FR-011)

- ZIP, 7z, TAR family, CAB and ISO: open, extract, pack (where supported) as in
  0.1.8.
- Plug-in interface version unchanged (106), and
  `git diff --stat v0.1.8 -- src/plugins/shared` is empty, apart from the 7zip
  plug-in's own files.
