# Research - 300-volume-label-wide

## R1 - Which call the core makes today

- Decision: the site calls `SetVolumeLabelA`.
- Rationale: no project under `src/vcxproj` sets `CharacterSet` except `tserver`; the core has no
  `UNICODE`. Measured: `dumpbin /imports build\tandemcommander\Debug_x64\tandemcommander.exe`
  lists `5BC SetVolumeLabelA` and no `SetVolumeLabelW`. `src/` has no `SetVolumeLabel` shim
  (Grep: the only call is `dialogs3.cpp` `CDriveInfo::Validate`).
- Alternatives considered: none - a fact.

## R2 - The converter

- Decision: `SalU8ToWAlloc` for both the label and the volume path.
- Rationale: it is the core's converter for UTF-8 / WTF-8 → UTF-16 (066 contract): lossless for
  every on-disk name, strict for malformed input (NULL), so a refusal is possible instead of a
  guess. The label is read by `SalGetWindowTextU8` (wide read of the field → WTF-8), so its
  conversion cannot fail except for lack of memory; the path comes from `MyGetVolumeInformation`
  (UTF-8).
- Alternatives considered: a fixed `WCHAR[MAX_PATH]` with `SalU8ToW` - avoids the allocation but
  adds a size decision; the item names `SalU8ToWAlloc`.

## R3 - Reporting a failed conversion

- Decision: the existing message `IDS_UNABLETOCHANGEDRIVELABEL` ("Unable to change drive label.
  Error: %s") with `GetErrorText(ERROR_NO_UNICODE_TRANSLATION)`, or `ERROR_NOT_ENOUGH_MEMORY` when
  the input is convertible (the size query succeeds) but the allocation failed - as
  `mainwnd4.cpp` sets the last error after the same converter.
- Rationale: no new UI string (084); refuse rather than guess; the user sees why.
- Alternatives considered: falling back to the `A` call (the transitional "not valid UTF-8, keep
  the legacy path" pattern of display code) - rejected: it would write a garbled label, the
  defect itself.

## R4 - The checker

- Decision: add `SetVolumeLabel` to `ANSI_NAME_API`; the rule `ansi-api-on-utf8-path` stays a
  report-only draft rule (spec *Clarifications*).
- Rationale: measured with the list extended in memory - the core report goes 39 → 40 with the
  one new hit `dialogs3.cpp:1341` (`volumePathWithBackslash` matches `UTF8_IDENT`); the plug-in
  scan finds no `SetVolumeLabel`. After the fix (`SetVolumeLabelW` does not match `...A?\s*\(`)
  the report is 39 again. `--strict` is unaffected (draft rules never fail it).
- Alternatives considered: promoting the rule (39 other findings, a separate classification job;
  not this item).

## R5 - What can be driven in a run

- Decision: import table + checker prove the fix; a probe guards the unelevated error path and
  the 270 refusal; the real write is a person step.
- Rationale: the session is not elevated; the machine has only fixed drives (C, D, E, F) and no
  removable one; creating a VHD needs admin.
- Alternatives considered: `subst` - a substituted drive's label is the underlying volume's
  (still needs admin for a fixed drive).
