# Research - 390 Registry Editor Move from HKCR into the user's Classes key

## R1 What the delete through HKCR reaches (measured)

- Decision: the defect is real at 129136b4. Probe `hkcr390_probe.ps1` (not elevated), row MACHUSER:
  F6 of machine-only `HKEY_CLASSES_ROOT\.386` (values `(default)`, `PerceivedType`, subkey
  `PersistentHandler`) into `\HKEY_CURRENT_USER\Software\Classes\`: no box, the user's half of `.386`
  missing afterwards, the machine's half unchanged. MACHUSERU (`\HKEY_USERS\<SID>_Classes\`) the same.
  `RegDeleteKeyW(HKEY_CLASSES_ROOT, path)` deletes the user's half when it exists - which the copy
  just created.
- Rationale: matches the review note of 292 (NOTE 4) and 292's measured merged-view behaviour.

## R2 Delete the copied half, or refuse

- Decision: delete, per key level, the half that held the key before the copy of that level wrote
  anything, by its real path, when exactly one half held it.
- Rationale: makes the elevated Move a real Move; without elevation the delete of the machine's key
  fails visibly with the existing "Unable to remove the original registry key." box (access denied)
  - the honest outcome of every Move whose source cannot be deleted. No new string.
- Alternatives: (a) refuse before copying when the target is the user's half of the source - needs a
  new message or reuses a misleading one, and also refuses the elevated case that can work;
  (b) delete through HKCR and check afterwards whether the key is still there - the copy is already
  gone by then.

## R3 Why "before this level's copy"

- Decision: the halves are read at the start of each recursion level, before `SafeCreateKey` of
  that level. A subkey's user half is only created at its own level, so the reading of a child is
  not disturbed by the parent's copy.
- Rationale: if the top key is held only by the machine's half, the user's half has no such key and
  so none of its subkeys - every level is machine-only; a top key held by both halves cannot be
  moved onto the user's half (feature 292 refuses it as "onto itself").

## R4 Keys held by both halves

- Decision: unchanged (delete through HKCR). Not named by the item; rule §1 step 4.

## R5 Errors and length

- An open error other than "not found" while reading the halves -> the existing open-error box
  (Retry / Skip / Skip All / Cancel) before anything of that key is written (fails closed).
- `Software\Classes\` + the path is joined into a buffer of `MAX_KEYNAME + 32` units (as
  `GetRegKeyIds` of 292 does); a path that does not fit is refused (`ERROR_FILENAME_EXCED_RANGE` in
  the open-error box), never cut. The delete box names the real key when it is shorter than
  `MAX_KEYNAME`, else the HKCR source (the box's own buffer would shorten it - 294's precedent).

## R6 Creating a new key through HKCR

- Measured: F6 of a user-only HKCR key into `\HKEY_CLASSES_ROOT\TcProbe390\Cil\` (parent only in the
  user's half) fails with "Unable to create a registry key. (5)" - Windows creates the new subkey in
  the machine's half. Existing behaviour, not this item; the probe's control uses
  `\HKEY_CURRENT_USER\Software\Classes\TcProbe390\Cil\` instead.
