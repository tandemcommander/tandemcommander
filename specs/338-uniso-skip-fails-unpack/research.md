# Research - 338 uniso skip fails unpack

## R1 Where the result is lost

- Decision: fix in the ISO plug-in - `ExtractAllItems` tallies, `UnpackWholeArchive` decides.
- Rationale: the core deletes an archive only after the plug-in's `UnpackWholeArchive` returns TRUE (that
  rule is right and shared by every plug-in); the ISO plug-in returned TRUE after skips. 7-Zip (087) maps
  any per-item error to a failed operation, TAR 308 / 309 fail after a member not extracted - the ISO
  plug-in was the odd one out.
- Alternatives: a core-side rule (e.g. the core counting the Skip answers of its boxes) - rejected: the
  read-error box is the plug-in's own and the core cannot see a silent skip.

## R2 Silent read errors

- Finding: iso9660 / rawfs / udf / xdvdfs `UnpackFile` set `ret = UNPACK_ERROR` only inside `if (silent == 0)`
  (when the box is shown); with `silent != 0` (after Skip all, or after the core's `SafeFileCreate` set any
  bit of the same mask - e.g. overwrite "All") the partial file is deleted and `UNPACK_OK` returned.
- Decision: one rule at each reader's end - `ret = SalIsoFileUnpackResult(ret, bFileComplete)`: OK with an
  incomplete file becomes ERROR; other results unchanged. Which boxes appear is unchanged.

## R3 HFS+

- Finding: `CHFS::UnpackFile` returns OK for a listed entry whose catalog record is not a file record (nothing
  written) and when the eight extents end before the file's size (`size > 0` after the loop - a cut file kept).
- Decision: the first returns ERROR with the existing "damaged B-tree" box (as the two checks just above it);
  the second makes the file incomplete (deleted, ERROR, no box - as a silent read error). No new string.

## R4 Same-name records (twins)

- Measured: the core's `CSalamanderDirectory::AddFile` keeps both records (no duplicate check); row TWINS
  extracted both, the second over the first after the overwrite question.
- Decision: remember every file the whole unpack wrote by its file-system identity (`SalGetFileIdentityW`,
  `salsamefile.h`; the 128-bit id where usable, else volume serial + 64-bit index - the `SalFileIdMatch`
  order) in hash sets. Before a file is unpacked, when its target exists, read the existing file's identity;
  if it is one this unpack wrote, a write over it (the unpack's result OK) marks the unpack. Identity, not
  names: the standing rule; also catches case twins and names made equal by cleaning (327's `a:b` / `a_b`).
- Fail closed: a written file without a usable id or that cannot be remembered (low memory) sets "lost";
  from then on any existing target counts as written by this unpack; an existing target whose identity
  cannot be read counts likewise (only while something was written).
- Cost: `GetFileAttributesW` per file (the core's `SafeFileCreate` makes the same query), one identity read per
  written file; lookups O(1).
- Alternatives: folded-name keys (rejected - names are not identity; the fold of `salunicode.cpp` is not
  available header-only); a linear list as SFTP 139 (rejected - quadratic on a re-unpack of a large image).

## R5 What counts as not extracted

- Decision: per file - any result but OK (ERROR, AUDIO_UNSUP); Cancel stops as before. Per folder - a FALSE
  `UnpackDir` (the folder could not be created). Files outside the dialog's mask are not asked for.
- Copy (F5) and one-file extraction keep their present results (spec clarification).
