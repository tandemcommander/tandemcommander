# Research - feature 294

## R1 When does the copy write into the source?

- Decision: exactly when the target key holds the source (`source = target\R`, `R` non-empty, by
  identity) and the source holds the path `R` below itself (`source\R` exists).
- Rationale: `CopyOrMoveKey(source -> target)` writes the values of `source\P` into `target\P` for
  every subkey path `P` of the source (`P` empty = the source itself, written into the target). A
  key `target\P` lies inside the source exactly when `P` begins with `R` (whole elements). Such a
  `P` exists exactly when `source\R` exists (subkeys are enumerated by name, case ignored). The
  case "target inside the source" is 292's existing check; target equal to source is refused by the
  folder check or by 292's `SalRegKeyIdsAnyWithin` (which includes equality).
- Measured: rows ABOVEMOVE / ABOVEALIAS (`R` = `<K>`), ABOVEDEEP (`R` = `<M>\<K>`) lose x=3;
  FLATTEN (`source\R` missing) merges without loss.
- Alternatives considered: (a) refuse whenever the target holds the source - simpler, but refuses
  the lossless merge (FLATTEN) that works today (constitution II; conservative answer of the
  spec); (b) a guard inside `CopyOrMoveKey` that refuses a subkey whose target is inside the
  source - would stop half-way after the values of the upper keys were already merged into the
  target (partial change, a Cancel the user cannot judge); the check before the copy writes nothing.

## R2 Which path `R`, which source path is opened?

- Decision: `R` is the remainder of a source identity after a target identity and `\`
  (`SalRegKeyIdBelow`), for every pair of identities (HKCR paths have one per half that holds them,
  292). The check opens `<source root>\<source key>\R` (KEY_READ) - the same way the copy opens the
  source's subkeys (`SafeOpenKey`, links followed), so the check sees what the copy would enumerate.
  Under HKCR the merged view is opened: a chain in either half refuses (conservative).
- The joined path is built on the heap at its full length (never cut). `ERROR_FILE_NOT_FOUND` = no
  chain; `ERROR_SUCCESS` = refuse; any other error = the existing "Unable to open a registry key"
  box with Retry / Skip / Skip All / Cancel (Skip leaves the key alone, Cancel stops) - fails closed.
  The box names the joined path when it fits the editor's key-name limit, else the source key (the
  box's fixed buffer would shorten it).

## R3 Message

- Decision: the existing `IDS_CANTMOVETOITSELF2` / `IDS_CANTCOPYTOITSELF2` ("Name: <key> Error:
  Can't move/copy a key to itself.", OK / Cancel) - the copy would indeed move the key onto itself.
  No new string (a run cannot do the two-stage `.slt` refresh).
