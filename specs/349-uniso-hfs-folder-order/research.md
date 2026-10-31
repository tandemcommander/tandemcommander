# Research - 349-uniso-hfs-folder-order

## R1 - Why a folder's contents can precede it

- Decision: treat it as normal HFS+, not damage.
- Rationale: TN1150 - catalog keys are (parentID, name), records sorted by key; a catalog node ID is
  given at creation and kept on a move. A folder made before its new parent has a lower ID; the records
  keyed by its ID come before the record keyed by the new parent's ID. Measured with crafted images
  (`probe/img349.py` on an xorriso seed: IDs 16 .. 31 rising in name order).
- Alternatives: none - the order is the format's.

## R2 - How to put every entry in its own folder

- Decision: take the not-yet-taken folders above a record first ("pending ancestors", outermost
  first), using the unchanged per-record code; a first pass only collects folder ID, parent ID and
  record index.
- Rationale: keeps 329's left-out handling (`CSalLeftOutIds::Under` needs the parent decided before
  the child), 332's record classes, the listing rule and the error paths exactly as they are; the
  loop's behaviour for in-order catalogs is identical (nothing is ever pending there).
- Alternatives considered: (a) build every folder's path in a first pass and list in catalog order -
  duplicates the listing rule / left-out logic in a second place; (b) sort the records by depth -
  changes where a "type not handled" record ends the listing and the order in which reports are made.

## R3 - Loops

- Decision: a walk up the parent chain stamps each folder; meeting a stamped folder = a loop. Every
  folder of that walk is left out (its ID into `CSalLeftOutIds`), the listing marked incomplete, no
  message.
- Rationale: none of them reaches the root - any place would be a guess; 332 handles damaged records
  the same silent way (a whole unpack fails, the image is kept). The walk is iterative (no recursion
  limit) and stops at a taken folder, so each folder is walked at most once before it is taken.
- Alternatives: list them at the root (as before - a guess, and the image was deleted).

## R4 - Unchanged cases

- The root folder used as the volume label (`bSkipRootParent`), TN1150's metadata folders and damaged
  records are not in the table: their children have no pending folders and go to the HFS+ root as
  before (332's Inbox items own those). Duplicate folder IDs: the first record is the one found, as the
  old `pFolders` search did.
