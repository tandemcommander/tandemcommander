# Research - 406

## R1 How HKCR shows a key held by both halves (measured at 8bb3c295, not elevated)

Script `%TEMP%\tcmeasure\hkcr_view.ps1` (only HKCU written, removed after): user's half of `.386`
with `PerceivedType = tcprobe-user`, `TcProbeUserOnly = u`, empty subkey `PersistentHandler`.

- `reg query HKCR\.386 /s`: `(Default) = vxdfile` (machine), `PerceivedType = tcprobe-user` (user's -
  the machine's `system` is hidden), `TcProbeUserOnly = u`; `PersistentHandler (Default) = {098f...}`
  (machine). Values are merged per name; the user's wins.
- `RegDeleteKeyW(HKCR, ".386\PersistentHandler")` = 0 -> only the user's subkey gone;
  `RegDeleteKeyW(HKCR, ".386")` = 0 -> only the user's key gone; the machine's half intact.

**Decision**: delete both halves by their real paths. **Rationale**: the delete through HKCR can
never reach the machine's half while the user's exists. **Alternatives**: refuse every Move of a key
held by both halves (the item's second option) - rejected: an elevated user could never move such a
key, and without elevation the access-denied box already says why.

## R2 Hidden machine values

The copy reads the merged view, so a machine value hidden by a user's value of the same name with
other contents is not in the copy. Deleting the machine's half would destroy it (data loss for an
elevated user). **Decision**: before deleting the machine's half, enumerate its values; for each,
query the user's half by name: absent = copied; present with the same type and the same bytes =
copied; otherwise hidden -> refuse with `ERROR_NOT_SUPPORTED` in the existing box (feature 297
refuses a link the same way). The class names of the halves must also be equal (ignoring case, the
copy's own test). Any read error -> that error in the box (fails closed; Retry checks again).
**Alternatives**: copy the hidden value under another name - invents data; delete anyway - loses it.

## R3 Order of the halves

**Decision**: machine first, then user. Without elevation the machine's delete fails (access
denied) and nothing of the key is deleted, so the source's merged view is unchanged and the Move is
an honest copy with a box - the same outcome as 390's machine-only case. User first would leave the
source showing the machine's hidden values instead of the user's (a changed view after a failed
Move).

## R4 Quick Rename

Quick Rename (`fs3.cpp`) calls `CopyOrMoveKey` with the same root and parent. For an HKCR key held
by both halves it now deletes both halves too. Not driven by the probe: a key created through HKCR
under a machine parent goes to the machine's half (390 R6, access denied without elevation).
