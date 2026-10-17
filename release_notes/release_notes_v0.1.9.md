# Tandem Commander 0.1.9

**Released 7 October 2026 · build 193 · Windows 11 or newer, 64-bit · feature release**

## New

- **Check for a new version.** Shortly after start-up the program tells you when a newer version has been published and offers *Download*, *Remind Me Later* and *Skip This Version*. Also available as *Help ▸ Check for New Version* and in the About box.
  - On by default, about once a day. It sends one request to GitHub with nothing about you or your computer, and downloads nothing by itself.
  - Turn it off in *Configuration ▸ General ▸ Check for a new version of Tandem Commander at start-up*.
- **RAR archives without installing anything.** RAR 1.5–4 and RAR5 archives open in the panel like a folder and can be viewed, copied from and unpacked — including encrypted and split archives. RAR archives are read-only.
- **Current 7-Zip engine.** The 7zip plugin moved from 7-Zip 16.04 (2016) to 26.03, with all security fixes made in between.
- **External archivers work.** They never started in any earlier release. 7-Zip (if installed) opens and unpacks ARJ and LZH/LHA archives; WinRAR (if installed) creates RAR archives.
- **Cancel for external archivers** — a *Cancel* button and Esc stop a running archiver.
- *Archivers Autoconfiguration* finds 7-Zip and WinRAR without scanning the disks.
- **PictView saves pictures again.** *Save As* writes BMP, PNG, JPEG, GIF and TIFF; *Set as Wallpaper* works.
- `$(ListUnicodeFullName)` for custom packers: a file list in Unicode.

## Changed

- **Updates go through with viewer windows open.** An installer or `winget upgrade` no longer fails because a Code Viewer, Markdown Viewer, PictView, Database Viewer, File Comparator, Disk Map or Checksum Verify window was left open. Windows holding unsaved work still keep the program running.
- **Only archivers that are installed are offered** in Pack and Unpack.
- **Packing an archive into itself is refused** as a whole, with the archive's name — leave the archive out of the selection.
- **Names are compared the way Windows compares them.** `Článek.txt` and `článek.txt` are one name; unrelated names are no longer confused. ZIP archives follow the same rule, so `č.txt` copied onto `Č.txt` now asks to overwrite.
- **Checksum lists saved as MD5 / SHA** can now be checked by GNU `sha256sum` and 7-Zip.
- **The viewer engine's crash reports stay on your computer** — they are no longer sent to Microsoft.
- Links stored in 7z and RAR archives are not unpacked; you are told how many were left out.
- **Plugin interface 107** for plugin authors. Plugins built for earlier versions keep working.

## Fixed

**Data loss**

- An edited file with an accented name is packed back into its archive — before, the edit was lost without a word.
- Edits from an archive are no longer lost or mixed up when two files, or two archives, have similar names, or when both panels show the same archive.
- Adding a file to a ZIP archive replaces only the file of that name, and a file that cannot be read no longer costs the archive's own copy.
- Moving a folder into an archive or to an FTP server no longer deletes the files behind a junction or symbolic link.
- Packing from a very deep folder no longer leaves sub-folders out silently.
- Renaming or moving a file no longer deletes it when the server sees the new name as the same file (for example on a macOS share).
- A folder is never copied or moved onto another path of itself.
- Packing never writes the archive over a file that is being packed; a failed multi-volume ZIP leaves no stray volumes.
- PictView's *Save As* no longer deletes the file it was asked to replace.
- 7zip plugin: *Unpack and delete* keeps an archive that did not unpack completely; Cancel no longer deletes the wrong file; a file not packed during a Move is not deleted.

**Names and text in any language**

- Find Files, Configuration and the command line keep text outside the system code page (Cyrillic, Chinese, emoji on a Czech Windows) instead of turning it into `?`.
- Window titles, the tray icon and the taskbar show such names correctly.
- Plugins use the exact file you name. Batch Rename, File Comparator, Database Viewer, PictView, FTP, CAB and Undelete could silently use a look-alike file (`voila` instead of `voilà`).
- `fcremote.exe` (File Comparator from other programs) works with accented names.
- Checksum lists are read in the encoding they were written in (code page, UTF-8, UTF-16).
- Undelete restores files under their own names, also on FAT disks.

**Passwords**

- 7z and RAR: a password with a non-English letter works. Archives made by earlier versions still open.
- ZIP: a password outside the system code page really protects the archive, and archives encrypted on Linux or macOS open.
- FTP: passwords in any script, up to 100 characters; a saved password is no longer damaged by moving through its field.
- SFTP: very long passwords and passphrases are sent correctly.

**Long paths**

- Archives in deep or accented folders open (paths over 259 bytes), and viewing, unpacking, editing and adding work there.
- A path is never silently cut — where a limit remains, the program says "path too long".
- No crash in folders about 7,500 characters deep; Find searches the folder you are in, however deep.
- Several buffer overruns with long paths removed (PictView, Database Viewer, Undelete, ISO, 7zip, Change Directory).

**Privacy and security**

- A password typed as part of an address (`ftp://user:password@server`) is no longer saved in any history.
- A Markdown document can no longer open a web page by itself; remote images send no cookies and never sign in with your Windows account.
- Unpacking a 7z archive can no longer write outside the target folder.
- Encrypted ZIP and 7z archives and saved passwords use Windows' cryptographic random generator.
- An anonymous FTP login no longer sends an address at somebody else's domain.

**Other**

- PictView: the pipette and histogram show the real colors; the shown picture can be renamed, deleted and saved over; a rotation is kept.
- The *Word size* chosen for 7z packing is used.
- A wrong password for a 7z archive is reported instead of producing nothing.
- Message boxes break lines between words; copying to the clipboard says when it fails.
- Menu shortcuts on accented letters (Alt+letter) work.

## Removed

- The MS-DOS and discontinued archivers (ARJ, LHA, UC2, JAR, ACE, PKZIP, RAR 2.50) and the *1.44MB volumes* presets — none of them could run. Their entries are removed from your configuration once.
- `7zwrapper.dll`, an unused helper of the 7zip plugin.

---

Install over the previous version — settings are preserved · Free software under the GNU GPL v2 or later · <https://tandemcommander.org> · full detail in `CHANGELOG.md`
