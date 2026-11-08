# Tandem Commander 0.3.0

**Released 8 November 2026 · build 196 · Windows 11 or newer, 64-bit · feature release**

## New

- **Tandem Commander updates itself.** When a new version is found, the program downloads its installer from the project's GitHub release in the background, checks it (the published checksum, the project's signature and the version) and offers *Install Now*: the program closes, the update is installed with a progress window and the program starts again. *When a new version is found* — *Notify me only*, *Download it and offer installation* (the default) or *Install it automatically as soon as it is downloaded* — can be chosen in *Configuration ▸ General* and in the window about a new version, which also offers **Download & Install**. An automatic installation waits while something could be lost (a copy or search running, a dialog open, text in the command line); nothing is ever installed when you close the program, and a cancelled installation is never started again on its own. Nothing is downloaded on its own on a metered connection; a copy not installed by the installer is only notified.
- **One modern icon style.** The toolbars, menus, drive bar, Change Drive menu, the `..` symbol and every plug-in that comes with Tandem Commander use the "Fluent 2" icons (Microsoft Fluent UI System Icons, MIT licence), with their own Dark variants. *Configuration ▸ Appearance ▸ Icon style* ▸ *Classic* gives back exactly the icons of 0.2.0, without a restart.
- **Panel tabs in the Windows 11 look**, with an icon per tab (drive, folder, archive, plug-in); a dragged tab follows the mouse and Esc puts it back, the X closes a tab only when the button is released over it, and the tab menu adds *Move to Other Panel* and *New Tab as Other Panel*.
- **WSL Linux file systems one click away.** Alt+F1 / Alt+F2 list `Linux - <distribution>` for every installed WSL distribution and the drive bar has a penguin button; `\\wsl.localhost` and `\\wsl$` list the distributions. A check box on the *Change Drive Menu and Drive Bar* page hides them.
- **Shift+F6 renames in place** — the edit box opens over the focused name, with the name without its extension selected; F2 still opens the Rename dialog.
- **Markdown Viewer: a *Copy* control on every code block** (#20) puts the code on the clipboard exactly as written.

## Changed

- **The Dark theme has the default theme's layout**: the toolbar area has its frame, lines and grips, drawn dark, the panel tabs sit at the same height, and the toolbars can be moved by their grips in the Dark theme too.
- **The panel tab strip is 8 pixels taller**; the old raised look is not kept as an option.
- **Shift+F6 is now a program key**: the Plugins Manager no longer accepts it for a plug-in command (such a binding never ran from the key).

## Fixed

**Data loss**

- **Unpack with "Delete archive after unpacking" keeps a disc image whose later sessions it did not extract** — multi-session CloneCD images (also without their `.ccd`), `.iso` and `.img` copies of multi-session CDs, raw `.bin` and `.mdf` images, UDF-only images followed by other data, and Easy CD Creator, WinOnCD, CIF, NTI and PDI images. Before, the image was deleted with the only copy of the later sessions.
- **Disc images give their files whole**: Video CD and SVCD video files keep all 2324 bytes of every sector (about 12 % of the video was lost), files of 4 GiB or more are extracted whole instead of as a fragment, Nero and CloneCD images of several sessions list every session with the right content, and a damaged session table no longer loses a session's files.
- **Damaged disc images are never deleted after a partial unpack**: a UDF folder that cannot be read, is stored in several pieces or holds a damaged name, an ISO 9660 folder shared by two records, and a damaged Xbox entry now mark the listing incomplete, and every readable folder after a damaged one is listed.
- **TAR, cpio and rpm**: a file whose data is stored under the name `.` is no longer extracted empty or skipped silently before the archive is deleted, and a member named like `sub/../a.txt` is no longer unpacked into a wrong folder over another file.
- **FTP uploads no longer replace a file without asking** when the server is reached under two names, as two users or through two ports, or when a folder name with letters outside ASCII matched another folder; a panel showing the folder under another name of the server is refreshed after the change.
- **Registry Editor**: a Move from `HKEY_CLASSES_ROOT` deletes the original where it really is (or says it cannot) instead of deleting its own copy or leaving the machine's half; Copy and Find no longer go round in circles through a registry link; a relative path that is too long is refused instead of opening another key.
- **The Batch Renamer no longer renames files inside junctions and folder links** reached by "Include subdirectories".
- **Copying or moving into an archive folder typed in another case** puts the files into that folder instead of a new one beside it, and opening such a folder no longer shows the archive's root.

**Crashes and freezes**

- **Damaged disc images no longer crash, freeze or corrupt memory**: Nero track lists and session information, CloneCD `.ccd` files, UDF allocation tables, entries and partition maps, and folders claiming gigabytes now open within bounds or are reported as damaged.
- **Disc images that did not open**: CloneCD images of data discs open every time, and UDF 2.50 images written by Windows list and unpack.
- **Switching back to the program no longer stops it** for half a second with a WSL folder in a panel, or for a moment while another program holds the clipboard open; a folder opened from quick search no longer flashes the whole parent folder first.

**Names and text in any language**

- **Long names are refused, never cut**: the Documents drive opens a long Documents folder whole instead of another folder; the User Menu's names to compare and the Change Icon file say "The path specified is too long."; a cpio or rpm archive with a too long member name opens with every other member.
- **Find and the viewer**: hex search keeps quoted letters outside the code page instead of turning them into `?`, and the viewer's Find shows a selected word of a UTF-8 file correctly and finds it.
- **The Registry Editor's View (F3) shows a whole text value** on UTF-8 and East Asian code pages; a cabinet with a name holding an unpaired surrogate opens and unpacks; an FTP file on a z/VM server with letters outside ASCII is shown and addressed under its real name.

**Other**

- **Find: a second click on a result column reverses the sort order** (#23), and the sorted column shows its arrow; the Registry Editor's Find sorts the same way.
- **The "mask hints" link is no longer cut off** in translated dialogs (#11).
- **A tab switch that asked a question no longer leaves the tab strip dragging a tab** (#22), and a tab can be dragged to the first place.
- **Adding files to or deleting files from a ZIP archive reached through a symbolic link** works; the link stays a link.
- **A refused Change Filter edit leaves the panel's filter as it was**; files of a folder moved on a Mac are unpacked in their own folder of a disc image's HFS+ part; the information about a Nero image shows its real sessions.

---

Install over the previous version — settings are preserved · Free software under the GNU GPL v2 or later · <https://tandemcommander.org> · full detail in `CHANGELOG.md`
