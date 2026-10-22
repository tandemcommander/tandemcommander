# Research - feature 296

## R1 What does the copy do at a registry link? (measured)

- Scratch script (`HKCU\Software\TcLinkExp296`, removed; recorded in `fix-log.md`):
  `RegCreateKeyExW` at a link to an existing key opens that key (disposition 2, `NtQueryKey` reports
  the target's name); at a dangling link it **creates** the link's target (disposition 1); a key
  below a link is created below the link's target. `RegOpenKeyExW` with `REG_OPTION_OPEN_LINK` opens
  the link key itself, and `RegQueryValueExW(L"SymbolicLinkValue")` gives type `REG_LINK` (6); a
  normal key gives `ERROR_FILE_NOT_FOUND` for that value; a missing name gives `ERROR_FILE_NOT_FOUND`
  at the open. Only the last element is opened as a link; earlier elements are followed.
- Consequence: the copy (`CopyOrMoveKey`) is redirected at every link it meets in the target tree.

## R2 Where to decide

- Decision: in the recursion, before `SafeCreateKey(target)` of each level (the top call included).
- Rationale: the target tree is only known while walking the source (each `target\P` is named from a
  source subkey). The parents of `target\P` were decided at their own levels, so the path up to the
  last element is either real or a link already judged harmless; a link's identity read with links
  followed is exactly where `RegCreateKeyExW` would write.
- Alternatives considered: a pre-pass over the whole source tree before writing (would double the
  walk, still race with changes, and give a refusal the user cannot locate); refusing every link in
  the target tree (simpler, but changes the result of copies through links elsewhere - not named by
  the item; conservative answer of the spec).

## R3 When does a link reach the source?

- Decision: with `S` = the identities of the operation's source (the selected key; read and, for a
  Move, deleted) and `L` = the identities of the link's target: refuse when some `L` lies in or is
  some `S` (`SalRegKeyIdsAnyWithin(L, S)`); when some `S` lies strictly inside some `L`, refuse when
  the key being copied at this level holds the remainder `R = SalRegKeyIdBelow(S, L)`
  (`SafeRegKeyHoldsPath`) - the 294 rule: the copy writes `L\P` for each subkey path `P` of that key,
  inside the source exactly when `P` begins with `R`. Otherwise follow.
- Below a followed link the recursion continues at `L\P` for paths `P` not beginning with `R`; those
  never reach the source, and any further link is judged at its own level.
- The 294 loop in `CopyOrMoveFromFS` and the new check are the same decision: one helper
  `SafeRegKeyIdsReachSource` serves both.
- `S` is read lazily (the first link met), from a heap copy of the top source path (the recursion
  appends to its buffer); a read error = the existing open-error box (fails closed).

## R4 Dangling link

- Decision: refused through the existing open-error box (`IDS_OPEN`, "Unable to open a registry
  key.") with the system's text of `ERROR_CANT_RESOLVE_FILENAME` ("The name of the file cannot be
  resolved by the system."), naming the target key; Retry re-checks, Skip / Skip All skip the key,
  Cancel stops.
- Rationale: creating through it creates a key at the link's target; whether that lies in the source
  cannot be shown without creating it (the link value is a path that may itself pass through links).
  Measured harm: LINKDANGLE created a key inside the source; LINKTOP a self-recursive chain.
- Alternative considered: compare the link value text with `S` - misses links inside that path;
  refuse-rather-than-guess.

## R5 Message for a link reaching the source

- Decision: the existing `IDS_CANTMOVETOITSELF2` / `IDS_CANTCOPYTOITSELF2` ("Name: <key> Error:
  Can't move/copy a key to itself.", OK / Cancel) with the full name of the source key of that level
  (`HKEY_...\path`), composed whole (`FormatWideU8`, heap). OK = skip (a Move keeps its source,
  someFileSkipped), Cancel = stop. No new string.

## R6 Other errors

- The open as a link or the value query failing with another error, or the link's identity not
  readable: the existing open-error box (`RegOperationError(err, IDS_OPEN, ...)`) - fails closed.
- Previously such a target failed later in `SafeCreateKey` with the create-error box; the outcome
  (key not copied) is the same.
