# Fix log - 317-pack-name-space

Backlog item `pack-with-a-relative-archive-name-that-starts-with-a-space` (source measure:316).

## Measurement at d526127f (main, before the feature)

Debug x64 build of d526127f (`.\build.cmd`, up to date). A probe written for the measurement
(316's driver + 098's library; first kept in a scratch folder, now `probe/pack317_probe.ps1`), run
on the hidden desktop:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log <scratch>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <scratch>\packspace_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -Lib ...\fix_probe_lib.ps1"
```

Result (first version of the probe, rows RUN + END counted): **7 FAIL / 11 PASS**, registry
restored and identical. The ZIP plug-in is the packer offered for .zip; its own "Create New Archive"
box shows the name it was given:

- space-dir (folder ` report`, item 0 ` report.zip`): "Create New Archive ... src\report.zip",
  `report.zip` created - FAIL
- space-dir-exists (the same + `report.zip` holding seed.txt): "The file "report.zip" already
  exists. Do you want to add 1 directory into existing archive or overwrite existing one?", Add:
  `report.zip` changed, no ` report.zip` - FAIL
- space-file (` notes.txt`, ` notes.zip`): `notes.zip` - FAIL
- space2-dir (`  two`, `  two.zip`): `two.zip` - FAIL
- typed-space (` typed.zip`) and typed-space-noext (` typed`, the dialog adds `.zip`): `typed.zip`
  - FAIL
- ctl-blank (the entry `   `): the dialog appends `.zip` -> `   .zip` -> trimmed -> `.zip` created
  (the probe expected a refusal - the row was wrong, see Decisions R2)
- ctl-plain (`plain` -> `plain.zip`), ctl-abs-space (`<src>\ abs.zip` -> ` abs.zip` - the absolute
  branch keeps the space; the ZIP plug-in writes such an archive): PASS

Reachability: Alt+F5 in a disk panel (default settings: "Use the other panel for packing" off) ->
`CFilesWindow::Pack` -> `CPackDialog` -> OK -> `SalGetFullName(fileBuf, &errTextID, GetPath(),
nextFocus)` (default `allowRelPathWithSpaces = FALSE`) -> the relative branch joins the panel path
with the name from after its leading spaces -> `FileExists` / the question / `ExecutePacker` on the
trimmed name.

## Decisions

- R1: pass `allowRelPathWithSpaces = TRUE` at the Pack call (as 316 did for Unpack, as
  `SalParsePath` does for Copy / Move); `SalGetFullName` itself unchanged. `nameBufSize` stays
  `MAX_PATH`, the size of `fileBuf`.
- R2: an entry of spaces only arrives as `   .zip` (the dialog appends the extension to a name
  without one) - after the fix it stays `   .zip` (spec Clarifications); a true empty entry stays
  refused. The probe's ctl-blank row becomes typed-spaces-only; ctl-empty added.
- R3: consumers of the name after the call enumerated (research R3): `PackArchiveIsSelectedSource`
  (identity), `FileExists` + the question, Overwrite's aside / put back, `ExecutePacker` (plug-in
  packers; external archivers get `"$(ArchiveFullName)"` quoted - read, not driven),
  `SalGetFileAttributes` after packing, `CutDirectory` + `PostChangeOnPathNotification`;
  `nextFocus` is unused in Pack.
- R4: ` ..` / ` .` - rows added (spec FR-004). Planned "nothing written"; measured otherwise and
  turned into a refusal - see *Change* step 2-3.

## speckit-analyze

No CRITICAL / HIGH. Fixed: C1 (MEDIUM) - Add / Overwrite into an existing space-named archive was
not driven; rows space-add / space-over added to T002. Accepted: C2 (LOW) "no new UI string / no
plug-in change" has no own task - the diff is one call site in `src/fileswn7.cpp`, `build.cmd`
(not `full`) suffices; U1 (LOW) the counts include END rows, as in 316.

## Probe updated to the spec (T002) and the negative control (T003)

`probe/pack317_probe.ps1` (the scratch probe moved into the feature): per-row answer to the "add to
archive?" question, expected new / changed files (SHA-256 of every file under the row), entries the
archive must / must not hold, an expected box text. Rows added: space-add / space-over (an existing
` report.zip`: the question names it; Add / Overwrite), typed-spaces-only (was ctl-blank),
typed-space-dots / typed-space-dot, ctl-empty. A message box titled "Pack" ("Empty name has no
sense here.") was first taken for the dialog shown again - the dialog is now recognized by its
combo box 210.

Negative control on the unchanged Pack code - the first version of these rows
(`probe/result_before_v1.txt`, the scratch run: 7 FAIL / 11 PASS) and the final probe
(`probe/result_before.txt`, built from `main`'s `src/fileswn7.cpp` for the run, then restored):
**11 FAIL / 17 PASS** - every leading-space row FAIL (`report.zip`, `notes.zip`, `two.zip`,
`typed.zip`, `.zip`; space-dir-exists asked about `report.zip` and Add changed it; space-add /
space-over never asked about ` report.zip` and created `report.zip`), the dots rows FAIL (no refusal:
the ZIP plug-in's "Cannot open or create file. Access denied." on the folder), the 3 controls PASS.

## Change (T004)

1. `src/fileswn7.cpp` `CFilesWindow::Pack`: `SalGetFullName(fileBuf, &errTextID, curDir,
   nextFocus, NULL, MAX_PATH, TRUE)` - `allowRelPathWithSpaces = TRUE`.
2. First after-run with only (1): **26 PASS / 2 FAIL** - every leading-space row PASS, but
   typed-space-dots / typed-space-dot created files literally named ` ..` and ` .` in the panel's
   folder (the ZIP plug-in opens the archive through `\\?\`, so Win32's trimming of trailing dots
   and spaces does not happen). Research R4 had expected the name to resolve to the folder - wrong;
   corrected in research.md.
3. Added: after `SalGetFullName`, a name whose last part is only spaces and dots is refused through
   the existing error path (`errTextID = IDS_PATHISINVALID`, "The path specified is invalid.", the
   dialog again) - no new string. Pure rule `SalPackNameIsOnlyDotsAndSpaces` in
   `src/common/salpackname.h`, 16 checks `TestPackName317` in `src/saltests/saltests.cpp`, the
   header listed in `src/vcxproj/saltests/saltests.vcxproj`. It applies to absolute names too
   (`<folder>\ ..` created the literal file before 317 as well) - strictly safer.

## Checks after the change

- `.\build.cmd` (Debug x64): BUILD SUCCEEDED, exit 0.
- Probe (`probe/result_after.txt`): **28 PASS / 0 FAIL**; registry restored, SHA-256 identical.
  ` report.zip` / ` notes.zip` / `  two.zip` / ` typed.zip` (x2) / `   .zip` created with the
  item's entries (the ZIP plug-in's "Create New Archive" box names the archive with its space);
  space-dir-exists: `report.zip` unchanged, no question; space-add: "The file " report.zip" already
  exists...", Add - seed.txt and ` report/f.txt`; space-over: Overwrite - only ` report/f.txt`, no
  aside left; ` ..` / ` .`: "The path specified is invalid.", the dialog again, nothing written;
  controls PASS.
- 316's probe (`probe/regress_316.txt`): 18 PASS / 0 FAIL. 241's probe (`probe/regress_241.txt`):
  8 PASS / 0 FAIL.
- `saltests.exe`: `saltests: 27456 checks, 0 failed` (27,440 + 16).
- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- clang-format: the new header clean; the new lines of `saltests.cpp` / `fileswn7.cpp` as the
  formatter wants (the files' other differences are pre-existing).

Not driven: external archivers (they get `"$(ArchiveFullName)"` quoted - read); typing with a real
keyboard (the probe sets the entry with WM_SETTEXT - the dialog reads the same text either way);
"Use the other panel for packing" on (the offered name is absolute - unchanged code path, already
kept the space: ctl-abs-space). No person step is owed: the change is verified on the build.

## Out of scope (Inbox)

- Pack writes an archive name that ends with a dot or a space, or a reserved device name, as a
  literal file (` ..` was measured: the ZIP plug-in uses `\\?\`); `report.` or `CON.zip` typed in
  the Pack dialog - by analogy, not driven - would produce a file ordinary Windows tools cannot
  open or delete. Recorded as an Inbox item (measure:317).
