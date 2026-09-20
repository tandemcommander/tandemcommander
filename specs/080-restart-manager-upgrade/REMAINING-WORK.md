# Remaining Work — Feature 080 (upgrading over a running instance)

**As of 2026-09-20.** The feature is implemented, reviewed and verified as far
as an autonomous session can go; nothing below blocks it. Ordered by what it
costs users.

---

## P1 — Owed to a person (cannot be run autonomously)

All five need either an elevation prompt answered, a real sign-out, or a
published newer version. Steps: `quickstart.md` §5.

1. **Machine-wide update with an elevated installer.** The installer that
   real users run is elevated; everything here was verified per-user. Install
   a build into `C:\Program Files`, start it **non-elevated**, run the
   installer elevated and silent over it. Must exit 0 and start the program
   again — and the restarted program must **not** be elevated (Task Manager →
   *Elevated*). The Restart Manager is documented to restart a program in its
   original user context; that has not been seen on this machine.
2. **A real `winget upgrade`**, once the package is in the catalogue
   (`microsoft/winget-pkgs#426090` was still open on 2026-09-20) and a version
   newer than the installed one is published.
3. **The interactive installer.** Run Setup by hand over a running program: the
   *Preparing to Install* page offers to close it. Both choices must behave —
   in particular *do not close* must end in Setup's own *file in use* handling,
   unchanged.
4. **Real sign-out, shutdown and forced shutdown**, idle and with a file
   operation running: the *Exiting* dialog, the block reason on Windows'
   shutdown screen and the configuration backup of a critical shutdown as in
   0.1.7. The change leaves those paths untouched by construction (every new
   line is inert unless the request carries the close-app flag, is not
   critical and the session is not shutting down — confirmed by the
   independent review), and an ordinary sign-out *query* was exercised with a
   probe; an actual sign-out was not.
5. **A servicing restart** (*Update and restart*) with the program open. If
   `SM_SHUTTINGDOWN` is already set when the question arrives, the old path
   runs; if it is not, the request is handled as an unattended close, which is
   synchronous and saves the configuration before returning — either way the
   configuration must be intact afterwards.

## P2 — Plug-in windows decline the update; plug-in viewers should not have to

An open plug-in window makes the program decline, **including viewer windows**
(Code Viewer, Markdown Viewer, PictView, Database Viewer), which hold nothing
that could be lost — and the Code Viewer is the default for F3, so this is an
everyday state. The user-visible consequence is stated in the changelog and
the manual: *close viewer windows before updating*.

Why it was not solved here (research R5): the four viewer plug-ins **ask**
*"viewer windows are open, close them?"* in `Release(parent, force = FALSE)`;
`force = TRUE` would be right for them but cancels transfers in FTP/SFTP, and
the core cannot tell the two kinds apart; imitating a click on every foreign
window's close button can raise a transfer window's own question on an
unattended machine — the defect this feature removed.

**The proper remedy is a plug-in-visible notion of an unattended close** — for
example a new `PLUGINEVENT_*` sent before unloading, or a
`IsUnattendedClose()` next to `IsCriticalShutdown()` — and four small changes
in the viewer plug-ins (skip the question, close the windows). That is an
addition to the plug-in interface (version 107, `src/plugins/shared/`,
documented first per the constitution), which is why it is a feature of its
own. Once it exists, decision D8 can let windows of plug-ins that declared
themselves safe pass.

The same signal closes the one **unverified** gap the review found: the FTP
plug-in asks *"cancel existing operations?"* in `Release()` whenever its
operations list is not empty. Decisions D7 (no plug-in file system in a panel,
none detached) and D8 (no plug-in window) keep that out of reach for every
state that could be checked, but whether an FTP operation can exist without a
window and without a file system in a panel was not established.

## P3 — Known limitations, accepted

- **An execute stage that outlives the requester's 30 s** is not stopped:
  the installer reports failure while the program still closes, and nothing
  starts it again. Measured closes take 1.2–1.4 s; a plug-in whose `Release()`
  hangs for half a minute would be needed.
- **A forced close** (`/FORCECLOSEAPPLICATIONS`) of a program that declined
  ends in the Restart Manager killing it after 30 s — without saving the
  configuration. That is what *force* asks for; before this feature the same
  situation additionally showed a *forced shutdown* message box.
- **The first update from 0.1.7 does not bring the program back.** The restart
  registration lives in the *old* process, and a 0.1.7 never registered.
- **One genuine `WM_CLOSE` within 35 s after an installer's instruction is
  ignored** (the Restart Manager sends one of its own, and it must not start
  the interactive exit). Exactly one message; a second Alt+F4 works.

## P4 — Restart after a reboot or sign-out

Excluded with `RESTART_NO_REBOOT` (spec *Assumptions*): it would make the
program reappear at sign-in for users who enabled *"restart apps after signing
in"*, is unrelated to updates and cannot be verified without a reboot. Removing
the flag is a one-word change and a product decision.

## Found on the way, not part of this feature

- **File Comparator writes an uninitialised byte into its stored
  configuration**: byte 77 of the 92-byte `Configuration` blob differs between
  any two runs (`02` / `01`). Harmless; it makes configuration exports differ
  for no reason. Likely padding after `unsigned char WhiteSpace` in
  `src/plugins/filecomp/dlg_com.h`.
- **The shipped product contains no help files** (`help\` is not in the Release
  tree or the package); *Help → Contents* ends in a *Help Error* box. Known in
  spirit (the help is not rebranded yet), but worth stating plainly.
- `specs/072-winget-distribution/quickstart.md` §2b used `Start-Process -Wait`,
  which since this feature would wait for the restarted program. Corrected.
