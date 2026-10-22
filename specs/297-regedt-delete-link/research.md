# Research - feature 297

## R1 What do Delete and Move do at a registry link? (measured)

- 296's scratch script (`deletelink.ps1`, `fix-log.md` of 296): `RegDeleteKeyW` on a link's name
  deletes the key the link points at and leaves the link; `NtDeleteKey` on a handle opened with
  `REG_OPTION_OPEN_LINK` removes the link only.
- Probe `link297_probe.ps1 -Expect before` (`fix-log.md`): F8 / F6 / Quick Rename lose `Jinde` in 7
  rows; `RegDeleteKeyW` of a key still holding a link subkey fails with (5) access denied.
- Decision: test every key the recursions are about to work on; only that key's last element is
  opened as a link (its parents were decided at their own level, or are the panel's own path).

## R2 Delete: remove the link, or refuse it?

- Decision: remove the link itself (`REG_OPTION_OPEN_LINK` with `DELETE | KEY_QUERY_VALUE`, the value
  re-read on that handle, `NtDeleteKey`).
- Rationale: the item's Expected names it first; the link is part of the tree the user selected;
  removing it touches nothing else (a link key has no subkeys of its own - creating below it goes
  through it). Re-reading the value on the opened handle makes sure the handle that is deleted is a
  link (no race with a key replaced in between).
- Alternatives: refuse (the selected tree could then never be deleted - the measured "Unable to
  delete" stays); `RegDeleteKeyW(handle, L"")` (unclear whether it re-opens through the link - not
  used); `RegDeleteTree` (follows links).

## R3 Move: recreate, copy the target, or refuse?

- Decision: refuse the link source key with the existing box `IDS_REMOVESOURCE` ("Unable to remove
  the original registry key.") + `ERROR_NOT_SUPPORTED` (the system's "The request is not supported."),
  Retry / Skip / Skip All / Cancel, before anything of that key is written.
- Rationale: the item's Notes name refusing with the existing messages as the conservative option;
  recreating a link in the target or copying its target are design choices for the maintainer and
  would need a new message; no new string can be added in a run. A skipped key keeps its parents in
  the source (existing `someFileSkipped` logic), so nothing is deleted that was not fully moved.
- Where: at the very start of each `CopyOrMoveKeyRec` level when `move` - before `SafeOpenKey` of the
  source, 296's target check and `SafeCreateKey`.
- Alternatives: check only before `SafeDeleteKey` (too late - the target's content would already be
  copied; Expected forbids the silent copy); a pre-pass over the whole tree (would double the walk;
  296 chose per level too).

## R4 Copy, Export, Find (Notes: "also check")

- Copy (F5): reads through the link, copies its target as a plain key; source unchanged (probe
  COPYTREE before = after). Unchanged by this feature.
- Export: runs `reg.exe EXPORT` / `regedit.exe /e` (`export.cpp`), no own tree walk.
- Find (`finddlg.cpp`) and Copy walk the tree by name: a link to an ancestor of the walked key makes
  them recurse through it until the key-name length limit (read from the code, not driven) - Find only
  reads; Copy writes a deep chain into the target. Not data loss of the source; recorded as an Inbox
  item (`measure:297`), not fixed here.

## R5 Errors

- Opening as a link fails with "not found" = the key does not exist: Delete and Move go on as before
  (their own open shows the existing error); any other error = the existing open-error box (fails
  closed). `NtDeleteKey` failure = its NTSTATUS mapped by `RtlNtStatusToDosError`, shown in the
  "Unable to delete a registry key." box.
