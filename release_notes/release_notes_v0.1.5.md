# Tandem Commander 0.1.5

**Released 25 August 2026 · build 189 · Windows 11 or newer, 64-bit · bug-fix release**

This release comes out of a product-wide review of how Tandem Commander handles names and text that are not plain English: accented Czech, Slovak, Hungarian, Polish or German file names, Cyrillic and Asian names, accented Windows account names and installation folders. Roughly forty places that garbled such text, silently refused to act on it — or, in one case, terminated the application — are fixed. Markdown files now also open instantly.

## New

- **Markdown files (F3) open instantly after the first view in a session.** The viewer's rendering engine used to shut down whenever the last viewer window closed, so nearly every open showed an empty window for a moment before the document appeared. The engine is now kept ready until you exit the application. Sessions in which you never view a Markdown file are unaffected — nothing is started ahead of time — and the behavior can be switched back in Plugins Manager → Markdown Viewer → Configure if you prefer the lower memory use.

## Fixed

- **A crash when putting a long or non-Latin file name on the command line.** Ctrl+Enter and Ctrl+Space / Ctrl+[ / Ctrl+] terminated the application on the spot for a name of about 87 Chinese or Japanese characters, 130 accented ones, or any long path — losing the panel state and selection.
- **The command line inserts the name you see.** Inserting an accented file name or panel path used to fill the command line with unreadable characters, so pressing Enter ran the command against a file that does not exist.
- **Compare Directories works in folders with accented names** — no more "cannot read directory" for every accented subfolder, and no error for every accented file when comparing by content.
- **Cloud folders open from the drive bar and the Change Drive menu.** OneDrive (personal and Business), Dropbox and Google Drive entries used to land in a parent folder — or look as if clicking them did nothing at all.
- **The external archivers handle accented names.** Packing into a RAR, ARJ, LHA, UC2 or ACE archive no longer fails with the archiver reporting it cannot find the file, and unpacking into an accented folder no longer fails with "cannot create the file list" and leaves a temporary folder behind.
- **Files dragged from Windows Explorer** onto the command line, the status bar, the toolbar or an open viewer window are accepted instead of silently refused.
- **Shortcuts with an accent in the path or in the target** open the folder they point to when you press Enter, instead of being treated as a plain file.
- **Editing a file inside an archive and then using *Copy To…* really copies it.** Before, nothing was copied and nothing was said, and the edit was left behind in a temporary file.
- Creating a self-extracting archive, creating a link, listing a typed file mask and running a user-menu item "through a batch file" or with a `$(DOSFullName)`/`$(DOSPath)` variable all act on the right files.
- **The application finds its own files when your account name or the installation folder contains accents.** F1 opens the help instead of reporting it cannot be found; a `config.reg` next to the program or in `%APPDATA%\Tandem Commander` is imported again; `$(SalDir)`/`$(SalPath)` in the user menu launch; `-C <path>` accepts an accented configuration path; and the "My Documents" entry in the drive bar works.
- **Environment variables such as `%USERPROFILE%` expand correctly on an accented account name** — typing `%USERPROFILE%\Desktop` into Change Directory or the command line no longer reports that the path does not exist.
- **The Windows taskbar jump list works.** Right-clicking the taskbar icon showed hot paths with accented names as garbled text, and clicking one did nothing at all.
- **A remembered directory with accented characters survives a restart** instead of silently falling back to a parent folder.
- **Leftover `SAL*.tmp` temporary folders are cleaned up again** on profiles whose name or TEMP path contains accented characters — they used to accumulate forever.
- **Rubber-band selection matches what is drawn.** Dragging a selection rectangle over files with accented names selected more files than the rectangle covered.
- **Drive Information (Ctrl+F1) is readable.** The file system, label and flags are reported for volumes mounted into an accented folder and for UNC shares with accented names; the share or link target of a network drive or junction is shown correctly; a drive label using characters outside your Windows code page shows instead of question marks; a shared folder with an accented share name gets its marker; and deleting a junction or symlink on a `subst` drive is confirmed as a link, not as a plain folder.
- **Byte counts no longer show a stray "Â" before every group of digits** in languages whose word for bytes carries accents — Czech `967Â 709Â 523Â 968 bajtů` is now `967 709 523 968 bajtů`. This affected Drive Information, the directory- and archive-size results, the "not enough space" message and the viewer's file-offset tooltip.
- **The internal viewer keeps its default character set.** Choosing a Central-European conversion (Kameničtí, KOI-8 ČS2) as the default no longer loses it on the next start, and the viewer's window title shows accented file names correctly.
- **Files whose name contains a broken character can be worked with at last.** Windows permits file names that are not valid Unicode text — they typically arrive from other tools or extracted archives, and the panel shows such a character as a placeholder glyph. Every operation on them used to fail with "file not found"; they can now be deleted, copied, moved, renamed and viewed, and the name is reproduced exactly.
- **Readable text in the remaining dialogs and lists**: the "Reading path…" wait window, the Location column and the *Keyboard Shortcuts* list in Plugins Manager, the *Save Configuration* overwrite prompt, the directory-line tooltip for very long paths, the archiver names in the Pack/Unpack dialog and the ZIP overwrite prompt.
- **The "Show in Change Drive menu" label in Plugins Manager is readable again** in Czech, Slovak, Hungarian, German and Spanish — a regression introduced in 0.1.2.
- **User-menu icons.** An item whose icon comes from a program stored under an accented path shows that icon instead of the default one.
- **File Comparator** shows its window title in binary comparisons and no longer comes up with an empty path bar.
- **The Markdown viewer keeps its instant view after being reloaded** in Plugins Manager — unloading and reloading the plugin used to disable the fast start permanently.

## Known limitations

- A name containing characters your Windows code page cannot represent (Cyrillic on a Central-European system, for example) is inserted into the command line with `?` in their place — wrong, but visibly wrong instead of silently wrong. Making those work requires the command line itself to become a Unicode control, which is a separate change.
- How the *contents* of an archive are displayed is unchanged: names with accents inside an archive listing may still be shown incorrectly. That half has to move as a whole and is still to come.
- Unchanged from earlier releases: the HTML help has not been rebranded yet; the **unrar** plugin needs `unrar.dll` and the **FTP** plugin needs OpenSSL, neither of which is shipped; ed25519 SSH keys are not supported by the SFTP plugin.

## Upgrading

- Install over the previous version — settings are preserved, plugins built for 0.1.0–0.1.4 keep working (plugin interface unchanged at 106).

---

Free software under the GNU GPL v2 or later · <https://tandemcommander.org> · full technical detail in `CHANGELOG.md`
