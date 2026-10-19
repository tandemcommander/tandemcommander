# Research - 250-damaged-highlight-entry

## R1 - skip the damaged entry or end the list

- **Decision**: skip it - the loop advances to the next number.
- **Rationale**: the item allows both; skipping keeps the user's entries after the damaged one (they are
  otherwise dropped by the save on exit, which rewrites the list from what was loaded).
- **Alternatives**: end the list at the damaged entry (as the settings import of feature 245 does for
  its source, `src/cfgimport.cpp`) - loses every following entry on the next save. The import's
  behaviour is left as it is (out of scope); the mismatch is recorded as an Inbox item.

## R2 - which failures count as "damaged"

- **Decision**: every failure of `GetValue(... Masks ..., REG_SZ, masks, MAX_PATH)` (missing value,
  wrong type, read error such as `ERROR_MORE_DATA`) and a failure to create the item (`new` or
  `item->Set`).
- **Rationale**: each of them made the loop re-open the same key; all measured by the probe except
  low memory (not drivable).
- **Alternatives**: read longer masks with a `MAX_GROUPMASK` buffer - a new behaviour (the dialog
  cannot produce or show such a mask), not asked by the item.

## R3 - the messages

- **Decision**: keep `GetValue`'s existing message (non-quiet) - shown once per damaged entry now.
- **Rationale**: no new string (a new string needs the `.slt` refresh a run cannot do); the user learns
  that the configuration was damaged.
- **Alternatives**: a quiet read - silences the only hint that an entry was dropped.

## R4 - a pure rule for `saltests`

- **Decision**: none. The change is the control flow around registry calls; there is no decision that
  can be tested apart from the registry. The probe drives the real loader end to end.
