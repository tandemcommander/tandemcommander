# Fix log: 176 - Pack with "Overwrite" keeps the old archive until the new one exists

Backlog: NEXT-WORK item 5i (found by 175's review).

## Measured (before)

Probe `probe/overwrite_probe.ps1` (built on 119's `packleft_probe.ps1`: its helpers kept, its cases
replaced), the build at 175: `probe/result_before.txt` (7 / 3).

- The core's Pack (850) into the existing `out\k.zip` (holding `old.bin`), "already exists - Add
  or Overwrite?" -> Overwrite, one source held open so that the packer cannot read it, the error
  answered Cancel: **`out\` was empty - the old archive was gone** (O-fail-zip, O-fail-7z,
  O-fail-move with Move). The core deleted the archive before it started the packer.
- O-ok-zip and O-ok-multi (multi-volume, the last volume renamed to `k.zip`, 119's K-exist-over):
  replaced as asked - must stay.

## Work

`src/fileswn7.cpp`: "Overwrite" moves the existing archive aside - a temporary name reserved in
its folder (`SalGetTempFileName`, `arcXXXX.tmp`) and `MoveFileEx(REPLACE_EXISTING)` onto it - instead
of deleting it. After the packer, what is at the archive's name decides: success with an archive -
the aside file is deleted; a failed **Move** that left an archive - both stay (the new one may
already hold moved sources) and `IDS_PACKERR_UNABLETOREN` names both; otherwise (no archive, or a
failed copy - no source touched) - what the failed pack left is deleted and the old archive moved
back (`IDS_PACKERR_UNABLETOREN` names both if that fails). A failure to move it aside is reported as
the delete's failure was (`IDS_ERROROVERWRITINGFILE`) and the Pack dialog comes back.

No string, interface or registry change. Build: BUILD SUCCEEDED; `check_encoding.py` TOTAL 0.

## Measured (after)

The same probe: 12 / 0 (`probe/result_after.txt`; the build at 168: 8 / 4) - the fail rows keep
`k.zip` / `k.7z` with `old.bin` and leave nothing else in `out\`; O-move-late-7z keeps the new
archive with the moved file and the old one as `arc*.tmp`; Overwrite that succeeds replaces it (also
multi-volume); registry identical. 119's pack probe as a regression: 104 / 0 (8 not driven, as its
own record), its A and K rows again on the final build 28 / 0.

## Review

Independent refute-first review (read-only):
- **CRITICAL, taken:** the first version deleted whatever was at the archive's name after a failed
  pack and put the old archive back - but a Move can fail AFTER the new archive holds the moved
  sources (the 7-Zip plug-in: a source that cannot be deleted, then Cancel; RAR's `m` with exit
  code 1 on a warning; ZIP's `CleanUpSource` on low memory) - those sources would have been gone.
  Now a failed Move never deletes an archive it left; both archives stay and are named. Probe row
  O-move-late-7z added (z9.bin readable but not deletable): PASS.
- SHOULD-FIX, taken: a pack that "succeeds" without an archive (ZIP: nothing to pack, a fatal read
  error cancelled) deleted the old archive too; now the old one is put back when no archive exists.
- Accepted / recorded: a folder of about 249 bytes or more cannot reserve `arcXXXX.tmp`
  (`SalGetTempFileName` limit) - Overwrite is refused there with the error, the dialog comes back
  (nothing at risk); a crash inside the packer leaves the old archive as `arc*.tmp`; a failed copy
  pack that left a usable partial archive now returns to the old archive; a multi-volume pack to
  removable media may end on another disk (the restore then fails and is reported).
