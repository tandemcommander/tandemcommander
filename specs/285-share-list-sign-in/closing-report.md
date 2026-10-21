# Closing report - 285-share-list-sign-in
Backlog item: share-list-offers-sign-in - A server's share list that needs a password shows only the Windows error
Outcome: closed

## What changed

- `src/fileswnb.cpp` `CFilesWindow::PickServerShare`: the share list of 125 is read in at most two
  rounds. A refusal of the logon-failure class gets Windows' sign-in dialog between them; then the
  list once more. Cancel ends like Esc in the list. A failed sign-in shows its message. The dialog
  is never offered a second time.
- `src/drivelst.cpp` `SignInToUncServerW` (new): `WNetAddConnection3W(parent, {RESOURCETYPE_ANY,
  \\server\IPC$}, NULL, NULL, CONNECT_INTERACTIVE | CONNECT_PROMPT)` on the UI thread, wide, not
  remembered. Its messages are those of `RestoreNetworkConnection` for an unmapped path (1219,
  the provider's text, `GetErrorText`). A Debug-only seam answers the sign-in for the probe.
- `src/common/saluncserver.h`: `SalUncShareListStep`, `SalUncSignInTarget` (pure; refuse, never
  cut). `src/consts.h`: declarations. `src/saltests/saltests.cpp`: `TestUncShareListSignIn285`.
- `specs/125-unc-server-shares/contracts/probe-seam.md`: the new seam variables listed.
- No new string. `PRIVACY.md` unchanged (claims checked true, research R4), with a decision for
  the maintainer.

## Measurements (before / after, commands)

`run_on_hidden_desktop.ps1` + `probe/signin_probe.ps1` (Debug, seams, `\\localhost`):
- before at eb173f7f (`probe/result_before.txt`): A1, A2, C1, F1, W1 and K1 each showed the box
  "Path: \\localhost\ Error: (5) Access denied" with 0 sign-ins; N1 showed (53); R1 showed the list.
- after (`probe/result_after.txt`, `-Expect fixed`): **PASS 20, FAIL 0**:
  - A1, A2 and L1: 1 sign-in to `\\localhost\IPC$`, then the list and `\\localhost\D$`.
  - C1 and U1 (a CJK server, whose target was logged whole): no box; Change Directory opens again.
  - F1: one "Network Error (1326)". W1: one "Multiple connections". K1: one sign-in, then "(5)".
  - N1 and R1: unchanged, 0 sign-ins.
  - The registry was restored identical.
- negative control (`probe/result_negative.txt`, wrong expected target): A1 FAIL, exit 1.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- `.\build.cmd`: `BUILD SUCCEEDED`. `.\build.cmd release`: `BUILD SUCCEEDED`; the Release exe holds
  no `TC_PROBE_UNC_SIGNIN` / `TC_PROBE_UNC_ERROR` string.
- `saltests`: 25122 checks, 0 failed (25091 before, +31).
- Probe: 20 / 0 (above).

## Reviews (findings and what was done)

One independent refute-first review found no MUST. It re-ran every check and added its own CJK,
non-class-error and negative-control rows.
- SHOULD 1: without `CONNECT_PROMPT`, `IPC$` could connect silently with the current identity, and
  no dialog would appear. Fixed: `CONNECT_PROMPT` added, then rebuilt and re-probed (20 PASS).
- SHOULD 2: `PRIVACY.md` is not updated. It is maintainer-owned, so it became the decision item
  below.
- NOTEs: the person rows became a new item. Probe rows L1 (1326) and U1 (CJK) were added. Three
  NOTEs were accepted as the full share path's behaviour (fix-log *Review*).

## Owed to a person (with the new person-step items)

- `share-list-sign-in-285-by-hand-the-real-windows-dialog-on-a`: Windows' real dialog on a server
  that refuses the list. The steps: sign in; the Backspace route; Cancel / Esc; a wrong password;
  *Remember my credentials*; an account that may connect but not list (one dialog, then "(5)"); a
  credential conflict; the keyboard in the list after the dialog.
- `should-privacy-md-name-the-sign-in-of-the-share-list-285`: decide whether `PRIVACY.md` names the
  sign-in (recommendation A: one sentence).

## New Inbox items (slug - title)

- share-list-sign-in-285-by-hand-the-real-windows-dialog-on-a - Share list sign-in (285) by hand:
  the real Windows dialog on a server that refuses the list
- should-privacy-md-name-the-sign-in-of-the-share-list-285 - Should PRIVACY.md name the sign-in of
  the share list (285)?
