# Tandem Commander 0.1.10

**Released 17 October 2026 · build 194 · Windows 11 or newer, 64-bit · fixes for the reports made after 0.1.9**

## New

- **A server name is enough to get to its shared folders** (#5). Change Directory to `\\server\` now lists the server's shared folders under the path line — visible ones first, hidden `$` shares after them. Esc cancels the wait; a server that cannot be read is reported with Windows' own reason.
- **PictView: *Update Thumbnail* works.** The command did nothing in any earlier release. It refreshes the thumbnail stored inside a JPEG file, and replaces the file only when the new one differs from it in the thumbnail alone — the picture, XMP data, colour profile and anything stored behind the picture are compared byte for byte first.
- **SFTP: `sftp://user@host/path`** is accepted in Change Directory.
- **Archive Update warns when another program changed the edited member** — a file opened for editing from an archive is marked when its member was changed or removed in the archive meanwhile.

## Changed

- **The exported configuration is a Unicode registry file** and keeps every letter; files exported by older versions keep importing. A failed export no longer deletes the file it was meant to replace.
- **Clearer refusals**: a folder copied onto itself, a folder moved into its own subfolder and an archive packed into itself each say so.
- Every program file built by the project uses Control Flow Guard.

## Fixed

**Data loss**

- **Deleting a link in a very deep folder no longer empties the folder it points to.** With the Recycle Bin off, deleting a junction in a path longer than about 780 characters deleted its target's files. Cleaning up temporary folders, Change Attributes, Change Case and Convert with subfolders, and Disk Map's menu likewise act only on the link now.
- **Another file's short name never overwrites that file.** Renaming, moving, copying, unpacking or downloading (FTP, SFTP) to a name such as `LONGFI~1.TXT` — the short name of another file — could replace that file; the Renamer even deleted it. Each now gets a file or folder of its own, or an error.
- **Archives through a drive letter that was pointed elsewhere** (SUBST or a network drive): viewing, editing, deleting or copying a member could act on the other archive, and an edit could be packed into it. Such an operation is refused now and the panel is reopened.
- **Case-sensitive folders (WSL)**: "a.txt" and "A.txt" are kept apart by rename, copy, the Renamer, PictView, Restore Selection and drag & drop into an archive (which also deleted "A.txt" on Move).
- **A replaced file is never lost halfway**: the viewer's Copy to File, Files > Convert and packing over an existing archive keep the old file until the new one is complete.
- **External archivers never get another file's name** when a long name did not fit their list of files; such a name is refused.

**Names and messages in every language**

- **Translated messages show file names and error texts readably** (#7). In Czech, German, Slovak and other languages with accented letters, a message made of a translated sentence and a file name or a Windows error showed one half as garbage: Find Files, about twenty message boxes, the View With / Edit With menu, the external archivers.
- **The same in the plug-ins**: 7-Zip, ZIP, TAR, CAB, ISO, Checksum, Batch Rename, PictView, PE Viewer, Database Viewer, Disk Map, Portables, SFTP and the FTP client (messages, the operation window, bookmarks, the information line). The FTP log, also its encrypted-connection lines, is readable; a saved log is UTF-8 now.
- **Registry Editor** (#3): the word for a key, the "selected" text and values with accented letters are readable; questions and errors name the key instead of showing an empty box.
- **A shortcut opens its target** whatever letters the path has (#8), also in deep folders, onto which files are dropped, and with a `\\?\` target.
- **Menus**: accented shortcut letters work in drop-down menus, and names with letters outside English are no longer garbled by an added shortcut.
- **Change Case, the Renamer and the viewer** work with accented names (they failed with "The file name is incorrect" or garbled the name); text typed while the program catches up keeps its characters.
- **User Menu**: commands run through the command shell get accented names and names with %, ^, ! or & unchanged, run in each file's folder from the Find window, and never in a shortened folder.
- **FTP: files with accented names work on UTF-8 servers.**
- **The program starts when installed in a folder with letters of another script**, and a folder named with `%...%` opens as it is.
- **The Markdown Viewer's settings are translated.**

**Long paths and names**

- **Long names in Chinese, Japanese or Korean** (from about 240 letters) can be copied, moved and renamed — they failed with "the file name is incorrect"; a typed name longer than Windows allows was shortened silently and is refused now. A name that does not fit is never cut: Quick Rename on a server, FTP automatic rename, the Copy, Move and Unpack dialogs, the FTP panel.
- **Archives with long names**: ZIP and other archives with names over 255 bytes open, ISO keeps long Rock Ridge names, files dropped into an archive with a long name are taken, and packing or dragging a folder with a too long name says so instead of "succeeding".
- Checksum verifies lists with very long paths; Focus from plug-ins, messages and the Plug-ins dialog reaches long folders; a file with a very long name no longer stays selected after a dialog; a too long server or share name says "too long".

**Crashes and lost settings**

- **FTP: an address with `%` in the host name** (`ftp://a%sb/`) crashed the program.
- **ZIP: a self-extractor favourite with a long name** was lost, with all its options, at the next save of the configuration.
- **The program starts on Windows 7 SP1 / 8.0 again** (#6) — it ended without a window. Windows 11 stays the only supported system.
- **Disk Map**: closing the program with a map's context menu open crashed it; Checksum and File Comparator windows close reliably.
- No crash with very long paths in several messages, on a broken shortcut with a long name, or in the Registry Editor's Find with long input; buffer overruns with long font names and long paths in File Comparator, Disk Map and 7-Zip are fixed.
- A crash report stays complete after a stuck background task was stopped.

**SFTP**

- **No more occasional "Unable to exchange encryption keys"** — about one connection in 256 failed with a valid server.
- **A directory that could not be read whole is an error.** When reading a remote directory failed in the middle, a copy "succeeded" with part of the files and the panel showed a partial list.
- **No operation on a shortened path.** A remote or local path that did not fit was cut and the download, upload, delete or rename went on with the cut one.
- **Messages say why**: "Permission denied" instead of nothing (also for F3 on a file you may not read); a long path no longer pushes the reason out of the message.
- Deleting a tree with one item that cannot be deleted shows one message instead of one per folder level.
- **Nothing is replaced without a question.** An upload replaced a file on the server silently, and Quick Rename to an existing name replaced that other file. An upload asks now, and a replaced file — on the server or on your disk — keeps its old content until the new one has arrived whole.
- **Move works for directories, in both directions, and removes only what arrived.** A directory moved from a server stayed there; a move to a server deleted the local tree afterwards even when the server had refused part of it.
- **A lost connection stops the operation** instead of going on with answers that belong to earlier requests.
- Devices and FIFOs on a server are not downloaded (a link to `/dev/zero` filled the disk); OneDrive folders are uploaded (they were skipped silently); Change Attributes says when the server refused.

**Other**

- **ZIP**: archives with 65,535 files or more record their number correctly, and deleting many files from a large archive takes well under a second instead of about 20 seconds.
- **Registry Editor's Find** works with regular expressions and in hex again, takes "0x" numbers, and shows text values to their end.
- **Compare Directories** treats names that differ only in case as the same file again.
- **Undelete** never gives two restored files one name.
- PictView: *Update Thumbnail* keeps the camera maker's own data of real camera files and works for file names in any script on any disk; the print preview shows the picture, and printing matches it.
- PictView: *Update Thumbnail* opens files in folders with accented letters and is no longer asked "this file does not contain EXIF data" for files that have it.
- Renamer: search and replace never changes another letter; "Include subdirectories" after a rename shows the renamed folder's files; long names no longer crash it.
- Error messages show the Windows text for more errors; Dropbox and Google Drive folders are recognised under any account name.
- PE Viewer, Undelete, Batch Rename, Registry Editor: names with accented letters and unrelated Windows error texts in several messages.
- Spanish: 7-Zip said "El archivo '…' es Aceptar."; the "SFTP error" sentence was wrong in seven languages.

---

Install over the previous version — settings are preserved · Free software under the GNU GPL v2 or later · <https://tandemcommander.org> · full detail in `CHANGELOG.md`
