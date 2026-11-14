# Contract: `build.cmd` — `portable` and `dist` (FR-001, FR-001a, FR-002, FR-004)

## Arguments

Order-independent, case-insensitive, as today. New: `portable`, `dist`.

| Command | Builds | Output | ZIP |
|---------|--------|--------|-----|
| `build.cmd portable` | portable edition, Debug, incremental | `%OPENSAL_BUILD_DIR%tandemcommander\Debug_x64_portable\` | no |
| `build.cmd rebuild portable` | same, clean | same | no |
| `build.cmd full portable` | + runtime data, `plugins.ver`, language modules | same | no |
| `build.cmd release portable` | **error** — "the portable ZIP needs 'full': build.cmd full release portable" | — | — |
| `build.cmd full release portable` | portable edition, Release, complete | `…\Release_x64_portable\` | `setup\output\tandemcommander-<ver>-x64-portable.zip` |
| `build.cmd full release portable sign` | + every shipped binary signed and verified (as `sign` today; Microsoft runtime DLLs never re-signed) **before** the ZIP is made | same | signed contents |
| `build.cmd … portable setup` | **error** — "an installer packages the normal edition; 'portable' and 'setup' cannot be combined" | — | — |
| `build.cmd dist` | see below | both trees | installer + ZIP |
| `build.cmd dist <anything>` | **error** — "'dist' takes no other arguments" | — | — |

All errors are detected **before any work** (after argument parsing, before prerequisite checks
that take time), exit code 1. One run builds one edition, except `dist`.

The policy stages (`plugins.cfg`, `languages.cfg`, encoding guard, update-pin check) run for the
portable edition exactly as for the normal one, against the portable output tree.

## `dist`

1. Refuses when `tools\codesign\codesign.cfg` is missing or names no certificate (a release is never
   unsigned) — exit 1, nothing built.
2. Runs `full release rebuild sign setup` (the normal edition and the signed installer).
3. Runs `full release rebuild sign portable` (the portable edition and the signed ZIP).
4. On the first failing step: stops, exit code = that step's (non-zero), prints
   `DIST FAILED at step <n>: <name>`; any ZIP / installer of this version written by the failing step
   is deleted (nothing that looks finished stays in `setup\output\`). Files from an *earlier*
   successful step stay and are listed as "built before the failure".
5. On success prints:

   ```text
   DIST OK  Tandem Commander <ver> (build <n>)
     tandemcommander-<ver>-x64-setup.exe      <size> bytes  SHA-256 <hex>
     tandemcommander-<ver>-x64-portable.zip   <size> bytes  SHA-256 <hex>
   ```

## MSBuild

- `build.cmd` adds `/p:TcEdition=portable` for the portable edition; everything else (solution
  filter, `/m`, configuration, platform) is unchanged.
- `src/Directory.Build.props` (new): `TcOutSuffix` = `_portable` iff `'$(TcEdition)'=='portable'`.
- Every literal `tandemcommander\$(Configuration)_$(ShortPlatform)\` (19 files) becomes
  `tandemcommander\$(Configuration)_$(ShortPlatform)$(TcOutSuffix)\`; the Release IntDir rewrite in
  `src/Directory.Build.targets` uses the same token. A check (`tools/check_outdir_suffix.py`, run by
  `build.cmd`) fails the build if any `*.props` / `*.vcxproj` spells the output root without the
  suffix — the "KEEP IN SYNC" comment is not enough.
- `sal_base.props`: `TC_PORTABLE` in `ClCompile` and `ResourceCompile` `PreprocessorDefinitions`
  iff `TcEdition=portable`.

## Unchanged

- With no `portable` / `dist`, every output, file list and the installer are identical to before this
  feature (SC-010); `setup\build_setup.cmd` and `setup\tandemcommander.iss` package
  `Release_x64\` only.
- `build.cmd help` lists `portable` and `dist` with the table above (short form).
