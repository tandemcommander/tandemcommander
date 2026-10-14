# Fix log: 147 - plug-in windows close cleanly while a worker box could appear

Backlog: `specs/NEXT-WORK.md` A.3 (queue 104 entry 6; 118 R7).

## Measured first (`probe/result_pre147.txt`, `Debug_x64` at `0f0a8d90`)

Probe `probe/plugin_close_box_probe.ps1` (built from the 143 probe and the 118 helpers):
**PASS 7 / FAIL 0** on the build before -

- K1: the File Comparator with "The files are identical. Do you wish to close?" open, normal exit:
  clean in 1.3 s (`WM_CLOSE` -> `CM_EXIT`; while a box is open it closes the owned dialogs and
  repeats after 100 ms).
- K2: Checksum Calculate with its "Read error" box open (the probe holds a byte-range lock on the
  file's first MB), normal exit: clean in 1.3 s (`WM_CLOSE` closes the owned dialogs, the worker's
  too, and repeats).
- K3: the same, an installer's close: declined in 0.0 s (the box is an undeclared window).

So the recorded symptom is not reachable with a box open. Left, by reading:

- Checksum `CSFVMD5Dialog` `WM_DESTROY`: `ThreadQueue.WaitForExit(hThread, INFINITE)` - no message
  handling. A worker that meets a read / open error after the close began calls `DialogError` with
  this window as the owner; `DialogBoxParam` disables the owner with `EnableWindow` - a send to the
  waiting thread: both threads blocked (until a forced release terminates the worker).
- File Comparator `Release`: `CRemoteComparator::Terminate` first; when the windows then do not
  close in time `Release` returns FALSE and the plug-in stays loaded without its fcremote receiver
  (fcremote comparisons stop until the next start).

## Work

- `misc.cpp/.h`: `SafeReadFile`, `SafeOpenCreateFile` take `const BOOL* terminate` (default NULL);
  once set, no box - the call fails as cancelled. The worker calls (Calculate, Verify) pass
  `Terminate`.
- `dialogs.cpp` `WM_DESTROY`: the wait loops on `WaitForExit(hThread, 0)` +
  `MsgWaitForMultipleObjects(..., QS_SENDMESSAGE)` + `PeekMessage(PM_NOREMOVE | PM_QS_SENDMESSAGE)`
  (sent messages only), and closes an owned enabled dialog of the worker's thread on every pass
  (review LOW-1: a box that slipped past the flag check).
- `filecomp.cpp` `Release`: `if (!ret && !force) CRemoteComparator::CreateRemoteComparator();`

## Review (refute-first agent, 2026-10-14)

No critical or medium finding; the deadlock claim checked against the core's `DialogError`
(`CFileErrorDlg::Execute` -> `DialogBoxParam` with the Checksum dialog as owner). Taken over: LOW-1
(above). Recorded:

- LOW-2: the comparator's hex-view half - its `WM_DESTROY` pump (`PM_REMOVE`) could dispatch a
  pending `WM_USER_HANDLEFILEERROR` and show a stray box; no crash path; reachability low (posted
  messages come before paint; the window is hidden first). `CFileMapping::Destroy` does not reset
  `FileSize` (a later paint would post "handle is invalid") - a trap for later work.
- LOW-3: the restarted receiver may start a comparison while the core's "force?" question is open;
  Yes then terminates it - the force semantics.
- NIT: the thread handle is no longer locked across the whole wait (a reused handle within 50 ms
  - very unlikely); a receiver restarted while fcremote holds its start mutex stays "created"
  without a thread (as at plug-in start).

## After (final build)

- `saltests` 21,829 / 0; `check_encoding.py` TOTAL 0.
- `probe/result.txt`: K1-K3 **7 / 0**.
- `probe/result_118_regress.txt`: the whole 118 probe **58 / 0** (as in 118).
