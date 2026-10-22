# Research - feature 315

## R1. Leave a default out, or grow the buffers

- Decision: leave a default that does not fit out (the entry stays empty).
- Rationale: the item's Notes ("leaving it out changes least"); the dialog, `SalGetFullName`,
  `CheckAndCreateDirectory`, `ExecuteUnpacker` and the unpackers all take 260-byte paths - a path
  that does not fit could not be used anyway (299's `Validate` refuses it at OK).
- Alternatives: grow `path` / `pathAlt` / `mask` to `SAL_MAX_PATH_UTF8` - every later step would
  still refuse or cut; a much larger change for no usable result.

## R2. What an entry left out shows

- Decision: empty - the same as when the other panel is not a disk. With "Use the archive name as a
  subfolder" the empty entry becomes the archive's name (relative), i.e. a subfolder next to the
  archive.
- Rationale: the existing behaviour for "no usable other-panel path"; no new UI.

## R3. Subfolder that does not fit

- Decision: empty the entry (not the bare path).
- Rationale: the bare path unpacks straight into the other panel's folder, ignoring the setting -
  a cut default (the subfolder cut away). Measured: row `subdir` unpacked into L.

## R4. Plug-in mask that does not fit

- Decision: `*.*`, the default when no mask is given; shown in the field before OK.
- Rationale: the item ("an empty / the other default"); an empty mask would unpack nothing or fail
  later. No plug-in of the tree passes a mask (grep `PostOpenUnpackDlgForThisPlugin`: only
  `demoplug`, commented, NULL).

## R5. Empty target after OK

- Decision: refuse with `IDS_TOOLONGPATH` when the archive panel's path does not fit; the existing
  `text` -> `SalMessageBox` -> `goto DO_AGAIN` path.
- Rationale: measured (row `src-long`): the empty entry unpacked into a new cut folder. The entries
  left out by R1 make the empty entry the default, so it must not cut either. `SalGetFullName`
  already refuses a relative name whose full form does not fit (`IDS_TOOLONGPATH`).

## R6. Where the rule lives

- Decision: new `src/common/salunpackdefault.h` (header-only, `saltests`).
- Alternatives: reuse 280's `SalUMCopyWhole` (`salumvalue.h`) - same copy, but named for the User
  Menu and without the subfolder rule; a feature-named header keeps the call sites readable.
