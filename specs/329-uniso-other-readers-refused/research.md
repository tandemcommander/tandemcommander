# Research - feature 329

## R1 What the refusal does today (measured before the fix, probe/result_before.txt)

See `fix-log.md` *Measurement before the fix*: UDF and Xbox show "Error" and lose every later folder
of the walk (`zlast\z.txt`), HFS+ shows "too long path" and drops every later catalog record, audio
clears the listing; all three unpacks with "Delete archive after unpacking" delete the image.

## R2 Where the decision is made

- Decision: each reader asks the panel listing's rule (`SalListingAcceptsDirU8` /
  `SalListingAcceptsFileU8`, `sallistingname.h`) with the same folder part it passes to the core,
  before it allocates anything; a refusal is recorded with `Image->ListingLeftOut.Add(path, name)`
  (328), and the entry is skipped (a folder not descended).
- Rationale: the core's `CSalamanderDirectory::AddFile` / `AddDir` refuse by exactly this rule, so
  "the rule refused" equals "the listing refused"; asking first avoids allocating the name and the
  file position (the old path leaked the name - Debug heap boxes at exit in the U / X rows).
- Alternatives: inspecting the core's FALSE after the call - it cannot tell a refusal from out of
  memory, and 328 already chose the rule-first form.

## R3 Out of memory and the core refusing after the rule passed

- Decision: as 328 - the name allocation failing ends the directory (`ADD_FAILED`, the old
  `ERR_TERMINATE` / `ERR_CONTINUE` of each reader) and marks the listing incomplete; the core
  refusing after the rule passed shows the plug-in's "Error", frees the entry and marks the listing
  incomplete without clearing anything (`ADD_LEFT_OUT`, the walk goes on).
- Rationale: FR-005; a whole unpack must fail whenever the listing is not whole.

## R4 HFS+: the contents of a left-out folder

- Decision: remember the catalog folder IDs (`folderID`) of left-out folders in a set
  (`CSalLeftOutIds`, `salisonamefit.h`); a record whose parent ID is in the set is skipped silently
  (a folder's own ID is added too). The left-out folder itself is the one reported entry (328 names
  a left-out folder once, its subtree is not listed). Out of memory while remembering an ID: the
  listing is marked incomplete and the HFS+ listing ends (the old "return FALSE"), so no child can
  land at the root.
- Rationale: `CHFS::ListDirectory` looks the parent up in `pFolders` and falls back to the HFS+ root
  path when it is not found (that fallback serves the volume's root folder ID 2 when the root record
  is used as the label) - continuing without the set would list `deep.txt` at `HFS (...)\deep.txt`.
- Alternatives: adding left-out folders to `pFolders` with a marker - mixes two meanings in one list
  and its path text is never used.

## R5 Audio

- Decision: a refused track name (`"NN label"`, NRG CD-Text labels) is recorded and the track is not
  listed; `AddFileDir` returns TRUE for it (the listing is valid). Out of memory: the listing is
  marked incomplete, "Error" kept, no `Clear`.
- Note: `CAudio::ListDirectory` formats the name with `sprintf` into `char[MAX_PATH]` - a label of
  257+ bytes overruns it. That is a separate memory-safety defect (crafted NRG), recorded as an Inbox
  item, not fixed here (scope).

## R6 Strings

- Decision: no string added or removed; `IDS_ERR_TOO_LONG_PATH` becomes unused by the code and stays
  in the module (removing it would need the translation refresh and re-keying for nothing).
