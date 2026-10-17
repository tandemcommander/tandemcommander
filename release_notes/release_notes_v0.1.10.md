# Tandem Commander 0.1.10

**Released 14 October 2026 · build 194 · Windows 11 or newer, 64-bit · fixes for the reports made after 0.1.9**

## New

- **A server name is enough to get to its shared folders** (#5). Change Directory to `\\server\` now lists the server's shared folders under the path line — visible ones first, hidden `$` shares after them. Esc cancels the wait; a server that cannot be read is reported with Windows' own reason.
- **PictView: *Update Thumbnail* works.** The command did nothing in any earlier release. It refreshes the thumbnail stored inside a JPEG file, and replaces the file only when the new one differs from it in the thumbnail alone — the picture, XMP data, colour profile and anything stored behind the picture are compared byte for byte first.
- **SFTP: `sftp://user@host/path`** is accepted in Change Directory.

## Fixed

**Names and messages in every language**

- **Translated messages show file names and error texts readably** (#7). In Czech, German, Slovak and other languages with accented letters, a message made of a translated sentence and a file name or a Windows error showed one half as garbage: Find Files, about twenty message boxes, the View With / Edit With menu, the external archivers.
- **The same in the plug-ins**: 7-Zip, ZIP, TAR, CAB, ISO, Checksum, Batch Rename, PictView, PE Viewer, Database Viewer, Disk Map, SFTP and the FTP client (about 120 places: messages, the operation window, bookmarks). The FTP log is readable too; a saved log is UTF-8 now.
- **Registry Editor** (#3): the word for a key, the "selected" text and values with accented letters are readable; questions and errors name the key instead of showing an empty box.
- **A shortcut opens its target** whatever letters the path has (#8).
- **Long names in Chinese, Japanese or Korean** (from about 240 letters) can be copied, moved and renamed — they failed with "the file name is incorrect"; a typed name longer than Windows allows was shortened silently and is refused now. A name that does not fit is never cut: Quick Rename on a server, FTP automatic rename.

**Crashes and lost settings**

- **FTP: an address with `%` in the host name** (`ftp://a%sb/`) crashed the program.
- **ZIP: a self-extractor favourite with a long name** was lost, with all its options, at the next save of the configuration.
- **The program starts on Windows 7 SP1 / 8.0 again** (#6) — it ended without a window. Windows 11 stays the only supported system.
- Buffer overruns with long font names and long paths in File Comparator, Disk Map and 7-Zip.

**SFTP**

- **A directory that could not be read whole is an error.** When reading a remote directory failed in the middle, a copy "succeeded" with part of the files and the panel showed a partial list.
- **No operation on a shortened path.** A remote or local path that did not fit was cut and the download, upload, delete or rename went on with the cut one.
- **Messages say why**: "Permission denied" instead of nothing; a long path no longer pushes the reason out of the message.
- Deleting a tree with one item that cannot be deleted shows one message instead of one per folder level.
- **Nothing is replaced without a question.** An upload replaced a file on the server silently, and Quick Rename to an existing name replaced that other file. An upload asks now, and a replaced file — on the server or on your disk — keeps its old content until the new one has arrived whole.
- **Move works for directories, in both directions, and removes only what arrived.** A directory moved from a server stayed there; a move to a server deleted the local tree afterwards even when the server had refused part of it.
- **A lost connection stops the operation** instead of going on with answers that belong to earlier requests.
- Devices and FIFOs on a server are not downloaded (a link to `/dev/zero` filled the disk); OneDrive folders are uploaded (they were skipped silently); Change Attributes says when the server refused.

**Other**

- PictView: *Update Thumbnail* keeps the camera maker's own data of real camera files and works for file names in any script on any disk.
- PictView: *Update Thumbnail* opens files in folders with accented letters and is no longer asked "this file does not contain EXIF data" for files that have it.
- PE Viewer, Undelete, Batch Rename, Registry Editor: names with accented letters and unrelated Windows error texts in several messages.
- Spanish: 7-Zip said "El archivo '…' es Aceptar."; the "SFTP error" sentence was wrong in seven languages.

---

Install over the previous version — settings are preserved · Free software under the GNU GPL v2 or later · <https://tandemcommander.org> · full detail in `CHANGELOG.md`
