# Changelog

All notable changes to Tandem Commander are recorded here, newest first.

Tandem Commander is derived from Open Salamander, which was open-sourced under
GPLv2 in 2023; this file starts at the first Tandem Commander release and does
not restate Open Salamander's own history. Versions follow
`MAJOR.MINORA.MINORB` (see `src/plugins/shared/spl_vers.h`), and each release
also carries an internal build number shared by the application and every
plugin.

## [Unreleased]

Working external archivers (feature 084). **External archivers never worked
in any Tandem Commander release:** every archive operation that used an
external program ended with "Unable to execute new process
...\utils\salspawn.exe", because a helper program that no build ever shipped
started the archiver. The list of external archivers dated from the 1990s, and
most of its entries were MS-DOS programs that 64-bit Windows cannot run at all.
Archivers are now started directly. Of the old list only RAR (WinRAR) is kept,
for creating RAR archives; 7-Zip is added for opening and unpacking ARJ and
LZH/LHA archives. RAR archives are opened and unpacked by the 7zip plugin
(feature 087, below).

RAR without installing anything, and a current 7-Zip engine (feature 087).
The 7zip plugin's engine is updated from 7-Zip 16.04 (2016) to 26.03, which
fixes the security defects found in it since, and with it the plugin opens
and unpacks RAR archives itself. The engine now contains only the 7z and RAR
formats, the only ones the plugin uses.

Privacy fixes (feature 085): privacy defects found while writing the privacy
statement of 0.1.8 are fixed, and `PRIVACY.md` now describes the program
without them.

Updates with viewer windows open, and plugin interface 107 (feature 088).

Follow-ups in the 7zip plugin and in the plugin text converters (feature 089).

File names that differ only in the case of an accented letter (feature 092).
The program decided whether two names are the same name with a table for one
code page, applied byte by byte to UTF-8 text. So `Článek.txt` and
`článek.txt` were two different names for it although they are one file for
Windows, and on a Central European system some unrelated names - `ĥ.txt` and
`Ĺ.txt` - were taken for the same name. The program now uses the rule of the
Windows file systems wherever it finds a file by name, decides about
overwriting, deleting or renaming, compares paths, or keeps a list of names.

Text outside the system code page in Find, Configuration and the command
line, and passwords in the 7zip plugin (feature 093). On a Czech Windows a
character such as `Ж` or `日` typed into Find Files, into a Configuration
page or into the command line became `?`, and the 7zip plugin handed every
password with a non-English letter to the archive engine garbled.

### Fixed

- **PictView renames, deletes and saves over the picture it shows.** Since the
  built-in image engine of 0.1.0, the picture shown in a PictView window could
  not be renamed ("The process cannot access the file because it is being used
  by another process") or deleted (Windows' "File in use"), and a second
  PictView window showing the same picture made Save As, Rename and Delete fail
  in the first one. Every PictView window showing the picture now lets go of it
  for the operation and takes it back afterwards: it keeps the picture, its zoom,
  mirror and rotation when the file did not change (renamed, or the operation
  failed), shows the saved picture after a Save As over it, and shows the
  picture as `<Deleted>` after Delete. A failed Save As over the shown picture no
  longer resets the zoom and the mirror. Save As now starts from what the
  picture really is: an opaque PNG, TIFF or icon no longer asks about losing an
  alpha channel; a black-and-white picture is offered "2 colors" and the CCITT
  G3/G4 TIFF compressions; gray and 16-color pictures start at 256 gray levels
  and 16 colors; the window title and Image Information show the picture's own
  colors and bit depth (they said 16777216 colors / TrueColor 24Bit for every
  picture). The *Set as Wallpaper* commands work: *Center*, *Tile* and
  *Stretch* always failed with "Unable to save the image" and then still made
  Windows re-apply the desktop wallpaper without a file; now the picture is
  saved as `%LOCALAPPDATA%\Tandem Commander\PictView_Wallpaper.bmp` and becomes
  the desktop background, *Restore Previous* switches to the remembered
  previous background (also one whose path has accented letters - it was
  garbled; nothing happens when none is remembered) and
  *None* removes the background; nothing changes when the picture cannot be
  saved or Windows refuses it. A TIFF
  comment with letters outside ASCII is now also stored as an XMP description,
  which programs read without guessing the encoding, and a JPEG comment no
  longer ends with a NUL byte (feature 111).
- **Adding a file to a ZIP archive replaces only the file of that name.**
  The ZIP plugin compared names in a way that took names differing in
  letters a Central European code page treats as one - `ĥ.txt` and `Ĺ.txt`,
  `Ítem.txt` and `Ýtem.txt`, `ž.txt` and `ż.txt`, many Cyrillic and Chinese
  pairs - for the same name. Copying `ĥ.txt` into an archive holding
  `Ĺ.txt` asked to overwrite `Ĺ.txt` and, on *Yes*, replaced it; packing
  back an edit of one such file deleted the other one from the archive; and
  answering *Skip* to such a mismatched question while edits were packed
  back could delete the edited file itself and store the other one twice.
  In an archive made on Unix the copied file was even renamed to the other
  file's name and then not found. The plugin now uses the rule of the
  Windows file systems: names are the same only when Windows would see one
  file. The other way round, `č.txt` copied into an archive holding `Č.txt`
  now asks to overwrite it, as `a.txt` and `A.txt` always did (Windows
  cannot hold both in one folder). For the same reason, on a Czech, Slovak,
  Hungarian or Croatian system `cHata.txt` and `chata.txt` were two names
  (the old comparison read "ch" as one letter) and are one now. And when an
  archive held several files of one name in different letter case
  (`ax.txt`, `Ax.txt`), answering *Yes* for one and *Skip* for another
  deleted the first one without storing the new file; now *Skip* keeps only
  that file and the new one is stored. Also: deleting the last file of a
  folder in an archive made on Unix that has another folder differing only
  in letter case (`Dir` and `DIR`) made the emptied folder disappear
  (feature 110).
- **A file viewed or edited from an archive is the file of that archive.**
  Two archives whose names differ only in letters that a Central European
  code page treats as one - `ĥ.zip` and `Ĺ.zip`, `Ítem.zip` and `Ýtem.zip` -
  shared their temporary copies: with both open (one in each panel), viewing
  (F3) a file of the second showed the file of the first, and editing (F4) a
  file of the second opened the first archive's copy; leaving the archives
  then packed that one copy into BOTH archives, so the second archive's file
  was replaced by the first's without any warning. Also: leaving an archive
  discarded the temporary copies of every archive whose name merely starts
  with its name (`p.zip` and `p.zip.zip`), and editing such a file again
  afterwards silently replaced the copy - with the changes not yet packed
  back - by the file from the archive. And one archive opened in both panels
  through two paths of the same folder (a SUBST drive letter,
  `\\localhost\C$\...`) gave one file two temporary copies, so the second
  update replaced the first edit; the two panels now share one copy, as they
  already did for one path. Finally, with both panels showing one archive,
  an update of that archive by another program was not noticed by the
  viewer: F3 went on showing the old content until both panels had left
  the archive (feature 109).
- **Every file edited from an archive is packed back as itself.** Editing
  two files of one archive whose names differ only in letters that a
  Central European code page treats as one - `ĥ.txt` and `Ĺ.txt`,
  `Ítem.txt` and `Ýtem.txt`, `ž.txt` and `ż.txt`, and many Cyrillic and
  Chinese pairs - lost the second edit: its temporary copy was deleted while
  the editor had it open, and leaving the archive did not offer it for the
  update. In a ZIP archive the second file then disappeared from the
  archive entirely when the first one was packed back. Both edits are now
  packed back, each into its own file - in a 7z archive by this change, in
  a ZIP archive in every case together with the ZIP plugin's own fix
  (feature 110, above; before it, only when the two temporary copies ended
  up in one temporary folder). Also: a file opened once through a
  folder typed in another letter case (Change Directory to `archive.zip\DIR`
  for the folder `Dir`) and once through the folder itself got two
  temporary copies, and the second update replaced the first edit; both
  routes now open the same copy, and the update goes into the folder as the
  archive stores it (feature 108).
- **A folder is never copied or moved onto another path of itself.** Moving
  a folder "into the place where it already is" through another path of
  that place - `\\localhost\C$\...`, `\\127.0.0.1\C$\...`, a mapped network
  drive, a SUBST drive letter, a junction, the short (8.3) name of a folder
  above it, a second name of a WebDAV server - deleted the folder's empty
  subfolders, after a string of "Cannot move a file to itself." and "The
  directory is not empty" messages. Moving a folder into itself or into one
  of its own subfolders through such a path moved its whole content one
  level down (`F\a.txt` became `F\F\a.txt`) and deleted the originals, and
  a junction moved onto itself that way was deleted. No file was lost, but
  the folder you had was rearranged. These are now
  refused before anything is touched: "Cannot move a directory to itself."
  (a copy onto itself: "Cannot copy a file to itself."). Copying a folder
  into one of its own subfolders still makes a copy there, as it always did.
  Also: copying (or moving to another drive letter or server name) a file
  that has several hard links onto the very same file through such a path
  asked "Overwrite?" with two identical lines and then failed with a
  sharing error; it is now refused as "Cannot copy a file to itself." -
  overwriting *another* hard link of the file works as before (feature 107).
- **Packing never writes the archive over a file that is being packed.**
  When a multi-volume ZIP archive was created from a folder that held a
  file named like one of its volumes (packing into `a.zip` with `a.z01` or
  `a.z04` among the selected files), the ZIP plugin asked "Overwrite?" and
  on *Yes* overwrote that file with the archive - the file was lost even on
  a copy, and with "delete files after packing" the archive itself was
  broken and the other packed files deleted too. In the Pack dialog,
  choosing *Overwrite* when the archive name was one of the selected files
  deleted that file before anything was packed, with every packer. Both are
  now refused before anything is touched - also when the same file is
  reached under another spelling (an 8.3 name, `\\localhost\C$\...`, another
  letter case, a hard link): the ZIP plugin says "This file is one of the
  files being packed", the Pack dialog "Cannot copy a file to itself." and
  comes back. Also fixed: answering *Cancel* to the ZIP plugin's "Overwrite?"
  question for the second or a later volume deleted the existing file you
  had just declined to overwrite (feature 106).
- **PictView's *Save As* saves again, and never loses the file it replaces.**
  Since 0.1.0 Save As (Ctrl+S) could not save anything: every format ended
  with "Unable to save the image". Worse, when the name chosen was an
  existing file, PictView first asked "Do you want to replace it?" and on
  *Yes* **deleted that file** - and then failed to save, so the file was
  simply gone. Now the image is written into a temporary file next to the target first,
  and only a complete file takes the target's place; if anything goes wrong -
  no permission to write in the folder, the file opened by another program, a
  full disk, Esc during the save - the existing file stays exactly as it was
  and the message says why. Save As writes BMP, PNG, JPEG, GIF and TIFF with
  the built-in Windows encoders, with the dialog's color depths, compressions,
  JPEG quality and subsampling, rotation and flip, and a comment (stored as
  UTF-8 text); formats Windows cannot write (PCX, Targa, CEL, IFF, PNM, SGI,
  Sun Raster, RLE, SKA, WBMP) are no longer offered, and the GIF *Interlaced*
  and TIFF *strip* options are disabled (Windows always writes non-interlaced
  GIF89a and its own TIFF strips). Saving over the image shown in the window
  works and the window then shows the saved image. *File > Save As...* is
  back in the viewer's menu (feature 105).
- **The plugins use the file and folder names you give them.** With a
  name containing letters outside the system code page (a Russian or
  Chinese name on a Czech Windows, an emoji) several plugins failed, showed
  the name garbled, or - worse - replaced letters with look-alikes
  (`voilà` became `voila`, fullwidth `ＡＢ` became `AB`) and **used another
  existing file or folder without a word**. The Batch Rename plugin renamed
  a file to `voila.txt` when told `voilà.txt` (and offered to overwrite the
  existing `voila.txt`); a mask such as `Ж*.txt` became `?*.txt` and selected
  other files for renaming; its manual list and history showed accented
  names garbled. The Database Viewer's *Open* opened `voila.csv` instead of
  `voilà.csv`; PictView's *Copy To* copied into the look-alike folder and
  its *Save As* asked to replace the look-alike file; the FTP plugin's save
  dialogs (logs, listings, server types) could overwrite a look-alike file
  and failed for every name with an accented letter; the CAB plugin took the
  next volume from a look-alike folder; Undelete opened a look-alike disk
  image; the ZIP plugin's password and overwrite dialogs showed names
  garbled. All of these now use the exact name. A name too long for a
  plugin's field is now refused with Windows' "The filename or extension is
  too long." instead of being changed; nothing is saved and the dialog stays
  open. In the FTP plugin this also applies to a password or user name of
  more than 100 bytes (about 50 accented letters): Connect and Close refuse
  it and the saved password stays as it was - before, such a password was
  saved and sent in the system code page. A long password saved by an
  earlier version keeps working as long as it is not retyped; to change it,
  enter one of at most 100 bytes (feature 104).
- **Renaming or moving a file no longer deletes it when the server sees the
  new name as the same file.** Some servers treat two spellings of a name as
  one file even though Windows treats them as two, for example `café.txt`
  with the accent stored as a separate character, as on a macOS server, and
  `café.txt` typed on the keyboard. Renaming a file to such a spelling of its
  own name made the program ask whether to overwrite "the existing file"
  (both lines identical), and on Yes it deleted the file it was renaming.
  With *Confirm file overwrite* turned off it deleted it without asking. The
  program now asks Windows whether the existing file is the file itself, and
  renames it through a temporary name instead. Copying a file onto another
  path of itself - a SUBST drive, `\\localhost\C$`, a junction, or a WebDAV
  server reached under two names - is now refused with "Cannot copy a file to
  itself.", and so is moving it to another drive letter or server name of
  itself ("Cannot move a file to itself."); a move within one drive through a
  junction was always harmless (Windows leaves the file where it is). Before,
  the program asked to overwrite the file with itself. Through WebDAV a move
  then deleted the only copy; elsewhere a sharing error stopped it. Renaming
  or moving a symbolic link onto the file it points at deleted that file and
  left a link to itself; it is now refused. The Renamer plugin and PictView's
  Rename follow the same rules (feature 103).
- **The File Comparator compares the files you name.** With a name
  containing characters outside the system code page (a Cyrillic or Chinese
  name on a Czech Windows, an emoji) the comparison failed, and the name was
  saved into the history as `?`. Worse, when files were dropped onto its
  dialog or passed by another program through `fcremote.exe`, some letters
  were replaced by look-alikes - `voilà.txt` became `voila.txt` - and **if
  such a file existed, it was compared instead without a word**. Since the
  first release, `fcremote.exe` (used by version-control and other programs
  to show differences) failed for every name with a letter outside plain
  English, even `Petrů.txt`; and the history list showed every such name
  garbled. All of this is fixed: names of any script and length reach the
  comparison exactly; very long paths no longer freeze the window; a folder
  name ending with a dot or a space is no longer confused with the one
  without. Also fixed: "Insert line" in the list of differences named the
  wrong file; a folder dropped as the second item was taken for a file. An
  old `fcremote.exe` copied elsewhere now reports that it does not match
  instead of waiting forever with `-w` (feature 102).
- **Smaller fixes** (feature 101):
  - The tip of the notification-area icon shows folder names with accented
    and other non-English letters correctly (they were garbled).
  - Pasting a path from the clipboard as a panel path (Ctrl+Shift+V) works
    for paths of any length.
  - *Copy UNC name* says "The path specified is too long." instead of
    failing silently, also in the Find window.
  - Shared folders: a share on `C:\foo` was taken for the share of
    `C:\foobar\...` as well, and deep paths under a share were cut.
  - Dragging part of a very long path from the directory line no longer
    builds a drag image hundreds of thousands of pixels wide.
  - When *Move* into an archive is refused because a folder cannot be read
    or is nested too deeply, the message now says that (it used to speak of
    a link), and long folder names in these messages are shortened visibly
    with "...". New texts in all languages.
- **Window titles show names in any script.** The title of a viewer window
  (Code Viewer, internal viewer, Markdown Viewer, PictView, Database Viewer,
  File Comparator, DiskMap) and of the main window showed `?` for every
  character outside the system code page - a Cyrillic or Chinese file name on
  a Czech Windows, an emoji anywhere - on the taskbar and in Alt+Tab too, and
  two such files in one folder got the same title. The file itself was always
  the right one. The titles are exact now, and the main window no longer
  re-sets its title on every refresh (feature 100).
- **Moving into an archive or to an FTP server no longer deletes files
  outside the selection.** Moving (F6, drag and drop with Move, cut and
  paste) a folder that contained a junction or a symbolic link to another
  folder - or the link itself - into a ZIP, 7z or other archive packed the
  files *behind* the link and then deleted them, without any warning; moving
  such a folder to an FTP server did the same. Those files are not part of
  what you moved. Moving into an archive now shows the existing warning about
  links and does nothing; use Copy (F5) if you want the content. Moving to an
  FTP server moves the link itself and leaves what it points to alone. Every
  release so far was affected (feature 099).
- **Packing from a long folder packs everything.** When a selection with
  sub-folders was packed (Alt+F5, or copied into an archive) from a folder
  whose path was 260 bytes or longer - about 130 accented characters - the
  contents of the sub-folders were left out of the archive **without any
  message**; with *Move* they then stayed on disk. Every file is packed now;
  a folder that cannot be read or is nested absurdly deep is reported. A
  *Move* into an archive whose selection contains such a folder now keeps
  all source files (the warning shown is the one for links) (feature 098).
- **No crash in very deep folders.** Entering a folder whose path was about
  7,500 characters long crashed the program (the directory line); paths up
  to the Windows limit work now, and clicking a part of the path goes there.
- **Change Directory to a long file path** (typing the full path of a file
  of 260 bytes or more) no longer overruns a buffer; the panel goes to the
  folder and selects the file.
- **Pasting a path that is too long** (Ctrl+Shift+V) shows "The path
  specified is too long." instead of going to a cut path, and a path copied
  from a Unicode program keeps characters outside the system code page.
- **Copying the UNC name** of a file (on a SUBST drive or a share) no longer
  overruns buffers with long paths.
- **7zip plugin**: two error messages are built with a bound.
- **Archives in deep or accented folders open.** An archive whose full path
  was longer than 259 bytes could not be opened in a panel - with accented
  folder names that is a path of only about 130 characters. The path was cut
  without a word: Enter did nothing, or an error named a path you never
  typed, or - if a file happened to exist at the cut path - **a different
  archive was opened**. ZIP, 7z, TAR and the other archives handled by
  plugins now open at any path length the program can reach, and viewing,
  unpacking, editing with update, adding and deleting work there. A path is
  never cut any more: where a limit remains, the message "The path specified
  is too long." is shown and nothing else happens. Limits that remain:
  archives handled by an external archiver program and by plugins built for
  an earlier version of the program (259 bytes); a folder *inside* an archive
  deeper than 259 bytes; copying to the clipboard or dragging from an archive
  whose name is longer than 259 bytes (feature 097).
- **Paths are refused instead of being cut** in a few more places where a cut
  path could lead somewhere else: the `-L`, `-R` and `-A` command-line
  parameters (the program now says the path is too long instead of starting
  in another folder), assigning a hot path, inserting a panel's path into a
  dialog field, and dropping a path on the directory line or the command
  line.
- **Unpack (Alt+F9) and Pack (Alt+F5) in long folders** no longer overrun a
  buffer: Alt+F9 on an archive in a folder of about 360 bytes or more, and
  the default archive name from a folder name of 260 bytes or more.
- **ISO plugin**: opening an image that cannot be read at a path of 240 bytes
  or more could crash the plugin while it built the error message.
- **An edited file with an accented name is packed back into its archive.**
  When you edited a file inside an archive (F4, or Enter and the program it
  opens) and its name contained any character outside plain English letters
  - `článek.txt`, a Cyrillic name - the program did not offer to update the
  archive when you left it or closed the program, and said nothing: **the
  edit was lost**. This affected every release so far, for ZIP, 7z and every
  other archive type. The archive is now updated as for any other file. A
  temporary copy that cannot be examined for another reason is offered for
  the update too, instead of being forgotten (feature 096).
- **Opening or editing a file deep inside an archive works.** When the path
  of the archive, the folder inside it and the file's name together came to
  about 520 bytes or more (for example 200 + 200 + 130), Enter and F4 on the
  file ended with "File not found" - the program asked the archiver for the
  folder instead of the file. F3 was not affected. The right file is opened
  now (feature 095).
- **A ZIP password with characters outside the system code page protects the
  archive.** The ZIP plugin replaced every character the system code page
  does not contain with `?` before using the password - without saying so. On
  a Czech Windows an archive encrypted with a six-letter Cyrillic word was
  really encrypted with `??????`: any other six-letter Cyrillic word opened
  it, and other programs refused the word you had typed. Such a password is
  now used as typed. Passwords made of characters of the system code page
  (for example Czech letters on a Czech Windows) are used exactly as before,
  so 7-Zip and earlier versions keep opening new archives. **Archives you
  made earlier with such a password still open with it** - but they stay as
  weak as they were; to protect the content with the real password, unpack
  the archive and pack it again. Self-extracting archives are not changed:
  their password prompt is a separate small program that still reads the
  password the old way. With AES encryption a password that needs more than
  128 bytes is refused (65 or more Cyrillic letters, for example); until now
  it was accepted and replaced by question marks.
- **ZIP archives encrypted on other systems open.** An archive whose key was
  made from the password's UTF-8 form (usual on Linux and macOS) never
  opened, and an AES-encrypted archive made by a console tool that used the
  DOS code page did not open either. The typed password is now tried in each
  of these forms, file by file.
- **A ZIP password of 255 characters is used whole**; the last character was
  dropped.
- **Less damage from a wrong ZIP password.** The classic ZIP encryption lets
  a wrong password through its quick check about once in 256 tries; the file
  was then unpacked as garbage over an existing file and deleted after the
  checksum failed. Where the plugin now tries several forms of a password, it
  checks the content before it touches the target file.
- **The ZIP plugin no longer writes the password into the text of a crash
  report**, and removes passwords from memory when it is done with them.
- **A very long SFTP password or key passphrase is sent as typed.** From 512
  bytes on (256 accented letters, for example) it was sent garbled. The
  password fields now take up to 511 characters, all of them sent correctly.
- **7z and RAR archives with a non-English letter in the password open, and
  the 7zip plugin encrypts with the password you type.** Since the first
  release the plugin garbled every password containing a character outside
  ASCII (for example `ř`) before using it. An archive encrypted in another
  program with such a password could not be opened; an archive created by
  the plugin was encrypted with the garbled password, so other programs
  could not open it with the password you had typed - and neither could the
  plugin on a computer with another system code page. The password is now
  used exactly as typed, with any characters. **Archives made by earlier
  versions still open with the password you remember**: when the typed
  password is refused, the plugin tries the form the earlier version used,
  file by file, without asking again. Files you add to such an archive keep
  the archive's existing password form, so it stays openable as a whole;
  to get an archive every program opens with the password as typed, unpack
  it and pack it again. (This replaces the note under *Added* that passwords
  could contain only code-page characters - they did not work correctly
  either.)
- **A wrong password for a 7z archive is reported.** With a wrong password
  for an archive whose file names are not encrypted, unpacking produced
  nothing and showed no message. It now says that the data could not be
  unpacked and that the password may be wrong, once per operation, and goes
  on with the files that can be unpacked.
- **Find Files accepts any text.** Characters outside the system code page
  typed into *Named*, *Look in* or *Containing* became `?`, and *Look in*
  showed `?` even for a folder it was opened from - so a search in a folder
  named, say, in Cyrillic on a Czech Windows found nothing. The fields now
  keep what you type and the search uses it.
- **Configuration keeps such text when typed**: hot paths, User Menu
  commands, arguments and directories, viewer and editor commands, and the
  items edited in place in the lists.
- **The command line keeps such text**: typed, pasted, dropped, or inserted
  with Ctrl+Enter - a file named `日本.txt` was inserted as `??.txt`. The
  command runs with the real name and the history stores it.
- **Alt+letter with an accented letter in the main window** no longer does
  the wrong thing: the letter was compared as a different character (`ř` as
  `Y`), and menu shortcuts on accented letters never worked.
- Text too long for a field's storage is cut at a whole character instead of
  being stored with `?` in place of the characters outside the code page.

- **The cursor stays on a file whose name differs only in the case of an
  accented letter.** After a refresh, after returning from a subfolder, or
  when another program renamed `Č.txt` to `č.txt`, the cursor jumped to
  another file. And in a folder holding names that the old comparison
  confused (`ĥ` and `Ĺ` on a Central European system) the cursor could land on
  the wrong one of them - Enter then opened the other folder, F3 showed the
  other file.
- **Renaming a file or folder only in the case of an accented letter** is
  treated as a rename of that one item - as it always was for `a.txt` to
  `A.txt` - in Quick Rename, in the Rename and Move dialogs, and in a move or
  copy onto the same folder. Two different files whose names the old
  comparison confused now get the usual overwrite question instead of a bare
  error.
- **Paths are recognised as the same place regardless of the case of accented
  letters**: a folder typed as `c:\článek` is the folder `C:\Článek` for the
  directory history (one entry, not two), for the remembered cursor position
  when you return to the parent folder, for the refresh after another program
  changed the folder, for stepping to the next file in a viewer, and for an
  archive open in both panels.
- **Selections and hidden names survive a refresh for such names too.** The
  lists the program keeps of selected, hidden or dragged names were ordered
  and searched by the old comparison.

- **PictView and the Database Viewer no longer write past a buffer in a deep
  folder.** When the full path of the next or previous file was 260 bytes or
  longer, stepping to it (Space, Backspace) - or just the viewer refreshing
  its toolbar - wrote the name into a buffer of 260 bytes. Depending on what
  lay behind it the viewer misbehaved or the program crashed. Both viewers
  now take names of any length.
- **An anonymous FTP login no longer sends an address at somebody's
  domain.** When you connect anonymously and never set an e-mail address in
  the FTP plugin's configuration, the plugin sends a placeholder as the
  password, as anonymous servers expect. It was `name@someserver.com` - an
  ordinary domain that belongs to somebody else. It is now `anonymous@example.com`; `example.com`
  is reserved for examples and belongs to nobody. A stored old placeholder is
  replaced; an address you entered yourself is kept (feature 090).
- **File names with an unpaired surrogate work in plugins.** A file name may
  contain half of a UTF-16 surrogate pair (NTFS allows it, some tools produce
  it). The program itself has handled such names since 0.1.5; the helpers
  plugins use to convert names did not, so a plugin could fail to open such a
  file, and the 7zip plugin replaced the character in 7z archives. Names now
  pass through plugins unchanged in both directions.
- **Moving files into a 7z archive no longer deletes a file that was not
  packed.** When a file met a folder of the same name in the archive, it was
  left out of the archive but deleted from the disk as if it had been moved.
- **Adding a folder that already exists in a 7z archive keeps its entry.**
  The folder's own entry (its time and attributes; for an empty folder the
  folder itself) was dropped from the archive.
- **Adding a file into a 7z folder whose name had to be made safe** (see
  *Unpacking a 7z archive can no longer write outside the target folder*)
  replaces the existing file after the usual question, instead of storing a
  second copy.
- **A password typed as part of an address is no longer kept in history.**
  Typing `ftp://user:password@server` into FTP Quick Connect, Change Directory
  (Shift+F7), a Copy or Move target (also the FTP plugin's download target),
  Find's *Look in* field or the command line still uses the password for that
  operation, but the drop-down list and the saved history now hold
  `ftp://user@server`. Until now the password was saved in the registry as
  plain text, even without *Save password*, and was included in an exported
  configuration. Histories saved by 0.1.8 and older are cleaned when this
  version next saves its configuration (the FTP Quick Connect history once the
  FTP plugin has been used in that session). On the command line every address in
  the command is cleaned, so a recalled command such as
  `curl ftp://user@server/file` needs the password again. Not recognised: a
  password containing `/`, and on the command line a password containing a
  space, a quote, `<` or `>` outside a quoted address — use the password field.
- **A Markdown document can no longer open a web page or another window by
  itself.** A document could make the Markdown Viewer open the default browser
  at an address of its choosing without any click (for example with an
  automatic page refresh), or open further viewer windows and messages. Links
  now open only when you click them or activate them with the keyboard. Both
  viewers share this rule; the Code Viewer opens no links at all.
- **Remote images in the Markdown Viewer** (after *View ▸ Load Remote Images*)
  no longer identify themselves as `OpenSalamander-mdview` but as
  `TandemCommander-mdview`; they neither store nor send cookies; and the
  viewer no longer signs in automatically when a server asks for Windows
  authentication — a server on your local network could make it answer with
  your Windows account. An error page from the server is shown as a broken
  image instead of being handed to the viewer as image data. On a network
  whose proxy server requires signing in with your Windows account, remote
  images therefore no longer load.
- **Cancelling the Master Password prompt no longer saves an SFTP password or
  passphrase in the weaker scrambled form.** When a Master Password is in use
  but not yet entered, saving the bookmark asks for it; cancelling used to save the
  secret anyway, only scrambled. It is now not saved and *Save password* is
  turned off, as the FTP plugin always did; the connection still uses it.
- **Stronger protection of saved passwords.** The random values behind the
  encryption of saved passwords (with a Master Password) now come from
  Windows' cryptographic random generator instead of a generator seeded with
  the time and the process number. Passwords saved by older versions are read
  as before.

- **External archivers start.** The program runs the archiver itself instead
  of the missing `salspawn.exe` helper. If the archiver's program cannot be
  found, the message names it and points to *External Archivers Locations* or
  *Archivers Autoconfiguration*; any other launch error names the program and
  the reason instead of suggesting a step that cannot help.
- **Encrypted ZIP archives get unpredictable salts.** When the ZIP plugin
  encrypts a file with AES, the salt that, together with the password,
  determines the file's key now comes from Windows' cryptographic random
  generator; so do the random bytes of the classic ZIP 2.0 encryption header.
  Until now both came from a generator seeded with the time and the process
  number, so the salts of an archive could be reproduced by guessing when it
  was made, which helps an attacker prepare a password search in advance; two
  program runs that started with the same seed would even produce the same
  salts. Archives made by earlier versions open as before but keep the salts
  they were made with — re-create sensitive ones to get new salts. ZIP 2.0
  encryption itself remains weak by design; use AES for anything that matters
  (feature 086).
- **Unpacking a 7z archive can no longer write outside the target folder.**
  The 7zip plugin used each name stored in the archive as it was, so a
  crafted archive could place files outside the target folder (`..\`), at an
  absolute path or on another drive, or into a hidden NTFS stream of a file
  (`name:stream`). Names are now made safe before anything is written: such
  parts are removed or replaced, the same way for 7z and RAR, and the panel
  shows each item under the name it will be unpacked with. This affected all
  earlier versions.
- **7-Zip security fixes.** The new engine fixes, among others, a 7z PPMd
  decoding defect (CVE-2023-31102) and an endless loop on crafted data
  (CVE-2024-11612), and the RAR decoder defects that matter now that RAR is
  read (CVE-2018-5996, CVE-2018-10115, CVE-2025-53816).
- **Encrypted 7z archives get unpredictable random values.** The value that
  starts the encryption of each encrypted 7z archive (its initialisation
  vector, now 16 bytes instead of 8) comes from a generator seeded by Windows'
  cryptographic random source; the old engine seeded it only with the time and
  the process number, like the ZIP plugin's salts before feature 086. Archives
  made earlier open as before — re-create sensitive ones to get new values.
- **Unpack and delete keeps a 7z archive that did not unpack completely.**
  When a file could not be unpacked (a damaged file, a CRC error, or a name
  too long to unpack), the archive was deleted anyway. It is now kept; so is
  an archive with links that were left out (see *RAR archives*, below).
- **Cancelling while unpacking a 7z archive no longer deletes the wrong
  file.** After choosing *Skip* for a file that already existed and then
  pressing Cancel, the plugin could delete that existing file; in an archive
  compressed as one block it could delete the last file it had unpacked
  completely. Only the file being written at that moment is removed now.
- **A damaged file in a 7z archive is always offered for keeping or
  deleting.** This was asked only for one kind of error; after a CRC error
  the damaged file was kept without a word beyond the error message.
- **A wrong 7z password is asked for again.** After an unpacking error in an
  encrypted archive the plugin kept using the same password for the rest of
  the session; it now asks again at the next operation.
- A very long archive path could crash the 7zip plugin while it showed an
  error message.
- **The 7zip plugin removes the remembered password from memory completely**
  when the archive is closed; until now part of a long password stayed
  there.
- **The *Word size* chosen for 7z packing is used.** The setting in the 7zip
  plugin's compression options was never passed on correctly, so every 7z
  archive was made with the compression level's default instead. Archives
  made now follow the setting; they may come out somewhat smaller or larger
  than before, and every 7-Zip version reads them.

### Added

- **RAR archives** (RAR 1.5–4 and RAR5) open in the panel like a folder, can
  be viewed with F3, copied from with F5 and unpacked with Alt+F9 — no other
  program needs to be installed. Encrypted archives ask for the password,
  also before showing the file list when the list itself is encrypted. A
  split archive (`name.part1.rar`, `name.part2.rar` … or `name.rar`,
  `name.r00` …) opens from its first part; a missing part is reported.
  RAR archives cannot be changed: adding, deleting or updating files is
  refused with a message; creating RAR archives remains WinRAR's job (see
  *Only programs that work are offered*). An archive that would need more
  memory to unpack than half of the computer's memory, or more than 4 GB, is
  refused instead of exhausting the memory. *Unpack and delete* removes all
  parts of a split archive. **Links are not created**:
  symbolic and hard links stored in an archive are left out, and you are told
  how many. **Passwords** can contain any characters (see *Fixed*, feature
  093).

- **Cancel.** While an external archiver runs, the small "Executing external
  program" window has a *Cancel* button, and Esc does the same. It stops the
  archiver and anything it started. Esc also stops reading an archive's list
  of files. Unpacking from the panel, and with the built-in 7-Zip unpacker,
  writes nothing to the target folder when cancelled. A custom unpacker that
  does not use `$(TargetPath)` starts in the target folder and may leave some
  files there. After a cancelled pack or delete you are told the archive may be
  incomplete.
- **7-Zip.** With 7-Zip installed, ARJ and LZH/LHA archives open in the panel
  and can be unpacked through the 7-Zip console program (`7z.exe`). File
  names outside the system code page survive listing and unpacking.
- **Archivers Autoconfiguration finds installed programs without a disk
  scan.** It reads where 7-Zip and WinRAR are installed (their registry
  entries and the Program Files folders). The drive scan is still available
  and now looks only for `7z.exe` and `Rar.exe`.
- **`$(ListUnicodeFullName)`** for custom packers and unpackers: the list of
  files written in Unicode (UTF-16), for archivers that read such lists.

### Changed

- **An update no longer fails because a viewer window is open.** When an
  installer or `winget upgrade` asks the running program to close, windows of
  the Code Viewer, the Markdown Viewer, PictView and the Database Viewer are
  now closed without a question, like the internal viewer's. Since 0.1.8 the
  program declined in that state and the update failed. It still declines -
  at once, showing nothing - while a viewer has a dialog of its own open,
  while PictView shows an image that exists only in its window (pasted,
  scanned, captured), and while a window of another plugin is open (File
  Comparator, Batch Renamer and others).
- **Plugin interface 107** (for plugin authors): `IsUnattendedClose` and
  `SetWindowClosesUnattended`; `SAL_MAX_PATH_UTF8` and `CSalMaxPathBuffer`
  in the plugin headers; the headers now state the real size of the buffers
  that receive full paths (`GetNextFileNameForViewer`,
  `GetPreviousFileNameForViewer`, `SalSplitGeneralPath`,
  `SalSplitWindowsPath`, `CheckAndCreateDirectory`). Plugins built for
  interface 104-106 keep working; the two viewer file-name services skip
  files whose name does not fit the 260 bytes the old headers promised.
- **The viewer engine's crash reports stay on your computer.** If the engine
  that the Markdown Viewer and the Code Viewer display documents with
  (Microsoft Edge WebView2) crashes, its crash report is no longer sent to
  Microsoft. While Tandem Commander 0.1.5 to 0.1.8 is running at the same time
  and has used one of these viewers, the two cannot share that engine: in the instance that starts it
  second, the viewer reports that its display engine is unavailable and
  closes, until the other instance is closed.
- **Only programs that work are offered.** An external archiver's entries in
  *Pack* (Alt+F5) and *Unpack* (Alt+F9), and the archive types it serves, are
  offered only while its program is found. Install it and run *Archivers
  Autoconfiguration*, and they appear. *RAR (WinRAR)* is offered for creating
  RAR archives when WinRAR's console program `Rar.exe` is installed.
- **The 7zip plugin is registered for RAR** (its configuration is updated
  once). In *Archives Associations in Panels* the `rar;r##` entry shows the
  7-Zip plugin for viewing and *RAR (WinRAR)* for packing, on an updated
  installation exactly as on a new one. With WinRAR installed, copying into
  an open RAR archive is done by WinRAR.
- Symbolic links in a 7z archive made on Linux or macOS are no longer
  unpacked as small text files holding the link's target. They are left out
  like the links in RAR archives, you are told how many, and *Unpack and
  delete* keeps such an archive.
- In a 7z archive made on Linux or macOS, a backslash that is part of a
  file name is now shown as a character of that name (as in 7-Zip itself)
  instead of starting a new folder.
- The DOS (8.3) variables are no longer offered in the variable menus of the
  packer and unpacker configuration. Commands that already use them keep
  working.

### Removed

- The MS-DOS archivers (ARJ 2.60, LHA 2.55, UC2, JAR, RAR 2.50, PKZIP/PKUNZIP
  2.04g, ACE). 64-bit Windows cannot run 16-bit programs.
- JAR, ARJ, ACE and PKZIP for Windows, and the *1.44MB volumes* presets.
  These programs are discontinued, and ACE's extractor had a widely exploited
  security defect. ZIP is handled by the ZIP plugin as before. ARJ and LZH
  archives can still be opened with 7-Zip installed.
- **Your configuration is cleaned up once** (configuration version 106).
  Removed are the packer and unpacker entries that call one of the removed
  archivers, including ones you edited, the floppy-volume presets, and the
  archive associations of the removed archivers. None of them could run.
  The old default RAR packer becomes *RAR (WinRAR)*. Entries that call a
  program by its own path are kept unchanged, unless their arguments are
  exactly one of the old *1.44MB volumes* presets. The archiver settings saved by
  this version are not meant to be read by 0.1.8.
- **`7zwrapper.dll`**, a helper of the 7zip plugin that nothing used. An
  update removes it from the installation.

## [0.1.8] — 2026-09-20

**Build 192.** Feature release. Each panel can now keep several directories
open in **tabs**, the way a web browser does: a strip of tabs sits above the
panel's Directory Line, every tab remembers its own directory, view, sort
order, filter, cursor, selection and Back/Forward history, and the whole set
of tabs comes back at the next start. Tabs are on by default; one checkbox in
Configuration turns them off and restores the previous look and behaviour
exactly. The program also starts on a computer without the Microsoft Visual
C++ runtime, and two things antivirus engines objected to are gone: the
in-memory patch of a Windows function at start-up and the crash-reporting
helper process. When an update is installed while the program is open and
idle, it now closes without asking anything and is started again afterwards.

### Added

- **Panel tabs.** Above the Directory Line of each panel there is now a tab
  strip. The `+` button (or Ctrl+Shift+T) opens a new tab with the current
  directory; clicking a tab shows it; the active tab carries a close button
  (Ctrl+Shift+W closes it too, the last tab of a panel never closes). Tabs are
  titled by the directory they show — the folder name, the archive name for an
  archive, or the drive letter for a drive root. Middle-clicking a folder in the
  panel opens it in a new tab in the background (in archives and on plugin
  file systems as well), middle-clicking a tab closes it, and tabs can be
  dragged into a new order. The right-click menu of a tab offers *New Tab*,
  *Duplicate Tab*, *Close Tab*, *Close Other Tabs* and *Close Tabs to the
  Right*; the same commands, plus *Next Tab* (Ctrl+Shift+Page Down) and
  *Previous Tab* (Ctrl+Shift+Page Up), live in a new *Tabs* submenu of the
  *Left* and *Right* menus. When more tabs are open than fit into the strip,
  they shrink and a list button at the right end names them all. Clicking a
  tab of the inactive panel activates that panel and shows the tab in one
  step; the keyboard focus never leaves the file list.

  Returning to a tab reads its directory again, so what you see is always
  current; the cursor, the selection and the scroll position are put back. A
  tab whose directory has disappeared falls back to the nearest existing parent
  and keeps following the panel. Leaving a tab is the same as leaving its
  directory any other way: an archive offers to update files you edited inside
  it, a plugin file system (FTP, SFTP) applies its own rules for keeping or
  closing the connection, and cancelling such a question leaves the tab where
  it was. Two tabs on the same connection share it.

  The tabs of both panels are saved with the configuration (on exit, or with
  *Save Configuration*) and restored at the next start; an archive or plugin
  file system tab is opened only when you click it, a plugin asks for its login
  as usual, and no password is ever stored with a tab. A panel whose active
  tab was a plugin file system at exit starts in its last disk directory, as
  before.

  *Show tabs in panels* in Configuration ▸ Appearance turns the feature off:
  the strips disappear at once, each panel keeps the tab it was showing (the
  dialog says how many tabs will be closed and asks first), the *Tabs*
  submenus vanish and the four shortcuts do exactly what they did in 0.1.7.
  With the option off the program is, pixel for pixel, the previous version.

- **Manual.** A new *Tab Strip* page under Panel Components, the four
  shortcuts in the keyboard shortcuts table, and the new option on the
  Appearance page.

### Changed

- **The Markdown viewer renders on the same hardened surface as the Code
  viewer.** Both viewers now share one rendering host inside the program, so
  they apply one and the same security lockdown. For an ordinary Markdown
  document nothing changes — text, tables, code, images, colour schemes, zoom,
  search, View Source, links and the instant second open all behave exactly as
  in 0.1.7. For a document that tries something it should not, the viewer is
  stricter: a file download started by the document is refused (previously the
  browser engine's own handling applied), and the document is delivered with a
  content policy, so an element the viewer already refused to fetch — a remote
  image without your consent, an embedded frame, a web font — is now refused
  one step earlier. Scripts remain switched off and the viewer still makes no
  network connection of its own.

- **Ctrl+Shift+Page Up / Page Down switch tabs while tabs are on.** Until now
  these two combinations were undocumented duplicates of Shift+Page Up /
  Page Down (page-and-select). With tabs turned off they keep that behaviour.

- **After a crash the program itself tells you where the report is.** The
  text report is written as before (exception details, registers, call
  stacks, loaded modules — no memory dump, nothing is sent anywhere), now
  under the name `TC<version>-<date>-<time>.TXT` in
  `%LOCALAPPDATA%\Tandem Commander`, and a message names the full path so
  you can attach the file to an issue on GitHub. The folder is created when
  it is needed; previously the report was silently lost on a machine where
  that folder did not exist yet. Old reports left in the folder are never
  touched. The Task List *Break* command ends in the same report and message.

- **Starting the program no longer rewrites Windows system code in memory.**
  Since its Open Salamander days the program patched a Windows function
  (`SetUnhandledExceptionFilter`) inside its own process at every start so
  that no add-on could take over crash reporting. Behaviour-based antivirus
  engines treat exactly this pattern as suspicious, and it is one likely
  reason for false alarms such as the reported Avast detection. The patch is
  gone; crash reports are produced exactly as before, and the reporter simply
  re-registers itself periodically instead.

- **Updating while the program is open.** When an installer has to replace the
  program's files — `winget upgrade`, or Setup run by hand — Windows asks the
  running program to close. Tandem Commander now treats that request for what
  it is: nobody may be sitting at the computer. If it is idle it closes without
  asking anything — not even *Confirm on program exit* — saves the configuration
  exactly as a normal exit does (and leaves it alone when *Save configuration on
  exit* is off), and **is started again when the update is finished**, with the
  same directories, tabs and active tab; an instance started with its own title
  prefix or icon (`-t`, `-i`) comes back with them. Setup's
  `/NORESTARTAPPLICATIONS` switch keeps it closed. Nothing else restarts the
  program: not a crash, not a sign-out, not a reboot.

  If closing would need a decision or would interrupt something, the program
  **declines at once** and the update fails the way it always did (exit
  code 5, the installation is rolled back, nothing is changed): while a file
  operation or a search is running, while a dialog is open, while files edited
  from an archive wait to be packed back, while a panel shows an FTP or SFTP
  connection — and also **while a window of a plug-in is open, including a
  viewer window such as the Code Viewer's**. Close those windows before
  updating. (The program's own viewer and idle Find windows close by
  themselves.) Closing plug-in viewers automatically needs a change to the
  plug-in interface and is planned separately.

  Until now the program answered such a request with its ordinary exit and
  all of its questions. With a copy running or a plug-in viewer open, the
  installer gave up after five seconds, a question stayed on the screen, and
  when somebody answered it later the program exited on its own with no
  installer left to start it again. Signing out, shutting down and the normal
  exit are unchanged. The restart works for updates *from* this version on: a
  0.1.7 that is closed for the update to 0.1.8 stays closed.

### Fixed

- **An update no longer leaves `salmon.exe` behind.** The crash-reporting
  helper was removed from the product in this version, but Setup never deletes
  a file merely because a new version stopped shipping it, so every
  installation upgraded from 0.1.7 or older would have kept the file in its
  `utils` folder — the very file antivirus products flag. The installer now
  removes it after the new files are in place. (It was also this helper, not
  the program, that made every update over a running 0.1.7 fail: Windows
  cannot close a program that has no window, and gives up on the whole request
  when it finds one. Updating a running 0.1.7 to this version works.)

- **The program starts on a computer that has no Microsoft Visual C++
  runtime installed.** Every version from 0.1.0 to 0.1.7 depended on the
  "Microsoft Visual C++ 2015-2022 Redistributable (x64)" being present, but
  neither installed it nor said so: on a computer without it the installer
  finished normally and Tandem Commander then refused to start with
  *"The code execution cannot proceed because VCRUNTIME140.dll was not
  found"*. The runtime files now ship inside the program folder, so no
  separate installation is needed. Nothing changes on computers that already
  had the runtime.

- **The viewer's title bar is readable for files under very long paths.**
  Opening a file whose full path is longer than about 260 bytes showed the
  title — the file name, the word *Viewer* and the coding — with garbled
  accented characters. The name was being cut in the middle of a character,
  which made the whole title fall back to the legacy code page. Paths at or
  below that length were never affected.

- **Hardening, with no known way to trigger it.** Three internal copies that
  could write past their storage were bounded: the viewer's lookup of a
  conversion name, the File Comparator's file header, and the argument check of
  the conversion service offered to plugins. No shipped configuration reaches
  any of them — the longest conversion name in `convert.cfg` is 33 bytes and
  every path shown in the comparator is already length-limited — so nothing
  users have seen is being repaired here.

### Removed

- **The crash-reporting helper `salmon.exe`.** Since the first release the
  program started a second process alongside itself whose job was to capture
  a memory dump when the program crashed and upload it. Neither has been true
  for a long time: uploading was switched off in 0.1.0, and no memory dump was
  ever produced because the helper needed a debugging library the product
  does not ship. What remained was a background process that waits to read
  the program's memory — the exact pattern behaviour-based antivirus engines
  flag, and users reported their antivirus blocking Tandem Commander because
  of it. The helper, its start-up question about "older bug reports" (which
  used to hold the main window unresponsive until answered) and its registry
  key are gone; the `utils` folder keeps its other files.

## [0.1.7] — 2026-08-29

**Build 191.** Installer fix. Unattended installation — `/VERYSILENT` and
`/SILENT` — works for the first time; it had been failing outright since
version 0.1.0. Nothing in the application itself changed from 0.1.6: the source
code is identical, only the installer script and the build number differ.

### Fixed

- **Unattended installation works.** Running the installer with `/VERYSILENT`
  or `/SILENT` aborted immediately without installing anything, reporting exit
  code 1 and, in an installation log, "Failed to proceed to next wizard page".
  Every published version from 0.1.0 to 0.1.6 was affected, so scripted and
  managed deployment was impossible — the installer could only ever be run by
  hand. Cause: the AI disclaimer page keeps the *Next* button disabled until
  the checkbox is ticked, and a silent installation still walks through the
  wizard's pages even though it shows none of them, so it met a button it
  could not press. The page is now skipped in a silent installation, exactly
  as the licence page always was. Interactive installation is unchanged — the
  disclaimer still has to be accepted before *Next* becomes available.

  This is also what stopped Tandem Commander from being accepted into the
  Windows Package Manager catalogue: its validation installs every submitted
  package unattended.

## [0.1.6] — 2026-08-29

**Build 190.** Feature release. Pressing F3 on a source or configuration file
now opens a new **Code Viewer** with syntax highlighting in a choice of twelve
colour schemes, covering over 200 languages and formats. The **Command Shell**
command (`Num /`) is no longer tied to Command Prompt — it can open Windows
PowerShell, PowerShell 7, Windows Terminal, Git Bash or any program you name.
This is also the first release published to the Windows Package Manager
catalogue, so Tandem Commander can be installed and updated with `winget`.
Existing behaviour is unchanged for anyone who touches neither setting.

### Added

- **Code Viewer: F3 shows source and configuration files with syntax
  highlighting.** A new plugin takes over F3 for source code, markup and
  configuration formats — `.cpp`, `.c`, `.h`, `.cs`, `.java`, `.js`, `.ts`,
  `.py`, `.php`, `.rb`, `.go`, `.rs`, `.sql`, `.xml`, `.json`, `.yaml`,
  `.toml`, `.ini`, `.sh`, `.ps1`, `Dockerfile`, `Makefile` and some two
  hundred more, `.txt` and `.log` included (those open as plain text with line
  numbers). Comments, strings, keywords and numbers are coloured, lines are
  numbered, and the detected format is named in the title and the status bar.
  The window is read-only in the strict sense: the file on disk is never
  modified. Twelve colour schemes ship — five light (GitHub Light, Light Plus,
  One Light, Solarized Light, Catppuccin Latte) and seven dark (GitHub Dark,
  Dark Plus, One Dark Pro, Solarized Dark, Catppuccin Mocha, Gruvbox Dark
  Medium, Nord) — plus a "follow the application theme" option; switching
  recolours the open file without reloading it and keeps the scroll position.
  Ctrl+PgDn / Ctrl+PgUp move to the next and previous file of the panel, and
  the usual Find, word wrap, whitespace display and font size controls are on
  the menu. Like the Markdown viewer, the Code Viewer renders through the
  Windows WebView2 engine and shares the same warm engine, so only the first
  view of a session pays the start-up wait. Nothing from a viewed file is ever
  executed and no network request is made, whatever the file contains.

- **The Command Shell command opens the program you choose.** *Commands →
  Command Shell*, `Num /`, `Ctrl+/` and the toolbar button used to open the
  system Command Prompt with no way to change it. A new **Command Shell** page
  in the Configuration dialog (after *Hot Paths*) offers Command Prompt (the
  default, and exactly today's behaviour), Windows PowerShell, PowerShell 7,
  Windows Terminal and Git Bash — each located automatically wherever it is
  installed — or a *Custom* program with your own arguments, which may use
  `$(FullPath)` for the panel directory and `$[NAME]` for environment
  variables. A preset that is not installed is marked in the list and refused
  on OK. The command line box at the bottom of the window is unaffected and
  keeps running typed commands through the system interpreter.

- **Installation and updates through winget.** Tandem Commander is published
  in the Windows Package Manager catalogue as `PavelStupka.TandemCommander`,
  so it can be installed with `winget install tandemcommander` and updated
  with `winget upgrade`. It installs for all users, exactly as the installer
  does on its own. Availability follows Microsoft's
  acceptance of the submission; the download on the website and on GitHub is
  unchanged and stays the primary channel.

### Changed

- **Source and configuration files no longer open in the built-in text
  viewer** on F3, because the Code Viewer claims them. The built-in viewer is
  still available on **Alt+F3**, and the Code Viewer declines files it cannot
  handle (very large or binary content) and offers to open them there. Which
  file types each viewer takes can be changed in Plugins Manager as for any
  viewer plugin.

- The default build now ships **20 plugins** instead of 19; `codeview.spl`
  carries its own highlighting data, so the installed program and the
  installer download are noticeably larger than 0.1.5.

- The remembered *last used page* of the Configuration dialog shifts by one
  for pages after *Hot Paths*, once, because the new page is inserted there.

### Fixed

- **Environment variables in user-menu arguments expand correctly when their
  value falls outside the Windows code page.** `$[USERPROFILE]` and the like
  used to lose accented characters — on an account named, for example, *Jiří
  Novák* the expanded path did not exist and the command failed.

## [0.1.5] — 2026-08-25

**Build 189.** Bug-fix release built on a product-wide review of how the
application handles accented and non-Latin text: files and folders with such
names now work in Compare Directories, on the command line, with the external
archivers, in the cloud entries of the drive bar, in shortcuts and Explorer
drag-and-drop, in volume information and in the remaining dialogs and lists —
and the crash that a long or non-Latin name on the command line could cause is
gone. Files whose name contains a broken (unpaired-surrogate) character can be
deleted, copied, moved, renamed and viewed at last, byte counts no longer show
a stray `Â` in accented languages, and Markdown files open instantly after the
first view of a session. Full Debug and Release builds and the unit test suite
(1301/0) pass.

### Added

- **Markdown files open instantly after the first view in a session.** The
  Markdown viewer (F3) renders through the Windows WebView2 engine, and the
  engine used to shut down whenever the last viewer window closed — so almost
  every open paid the engine's start-up wait as a visibly empty window before
  content appeared. The engine is now kept ready in the background from the
  first Markdown view until the application exits: only the first view of a
  session (at most) shows the start-up wait; following links between documents
  and every later F3 render immediately. Sessions that never view a Markdown
  file are completely unaffected — nothing is started ahead of time. A new
  option in Plugins Manager → Markdown Viewer → Configure ("Keep the rendering
  engine ready for instant viewing", enabled by default) trades the instant
  opening back for the lower memory use of the old behavior when disabled.

### Changed

- The Markdown viewer's browser cache moved to a product-wide location
  (`%LOCALAPPDATA%\Tandem Commander\WebView2`); the old `mdview.WebView2`
  cache folder is removed automatically on first use. The cache holds no
  user data.

### Fixed

- **Files and folders with accented names work in the places that still refused
  them.** Comparing two folders by content no longer reports an error for every
  accented file, and no longer asks "cannot read directory" once per accented
  subfolder. Editing a file inside an archive and then using *Copy To…* actually
  copies it — before, nothing was copied and nothing was said, so the edit was
  left in a temporary file. Dragging a file from Explorer onto the command line,
  the status bar, the toolbar or an open viewer window is accepted instead of
  silently refused. Pressing Enter on a shortcut whose path — or whose target —
  contains an accent now follows it into the folder instead of treating it as a
  file. Creating a self-extracting archive, creating a link, listing a typed
  file mask, and running a user-menu item "through a batch file" or with a
  `$(DOSFullName)`/`$(DOSPath)` variable all act on the right files.

- **The command line inserts the name you see.** Ctrl+Enter and Ctrl+Space /
  Ctrl+[ / Ctrl+] used to fill the command line with unreadable characters for
  any accented name, so pressing Enter ran the command against a file that does
  not exist. One limitation remains: a name containing characters your Windows
  code page has no room for (Cyrillic on a Central-European system, say) is now
  inserted with `?` in their place — wrong, but visibly wrong instead of
  silently wrong. Making those work needs the command line to become a Unicode
  control, which is a separate change.

- **The program finds its own files when the account name or install folder is
  accented.** F1 opens help instead of reporting that help cannot be found; a
  `config.reg` placed next to the program or in `%APPDATA%\Tandem Commander` is
  imported again; a user-menu item using `$(SalDir)` or `$(SalPath)` launches;
  `-C <path>` accepts an accented configuration path; and the "My Documents"
  entry in the drive bar works. Starting an external archiver no longer fails
  with a message blaming the archiver for what was the program's own path.

- **Cloud folders open.** Choosing OneDrive — personal or Business — Dropbox or
  Google Drive from the drive bar or the Change Drive menu now opens that
  folder. Before, whenever the folder's path contained an accent, the panel
  silently went to a parent folder instead, so the entry looked as if clicking
  it did nothing. Google Drive was affected even without an accented account
  name.

- **External archivers handle accented names.** Packing a file whose name has
  accents into a RAR/ARJ/LHA/UC2/ACE archive used to fail with the archiver
  reporting it could not find the file; unpacking into an accented folder, or
  working with a temporary folder whose path is accented, failed with "cannot
  create the file list" or a MoveFile error and left the temporary folder
  behind. How an archive's contents are *displayed* is unchanged — that half
  needs the whole listing to move at once and is still to come.

- **Volume information, `subst` drives and shared folders.** Ctrl+F1 on a
  network drive or a junction shows the share or link target readably; a volume
  mounted into an accented folder, or a UNC share with an accented name, reports
  its file system, label and flags instead of nothing; deleting a junction or
  symlink on a `subst` drive is confirmed as a link, not as a plain folder; a
  drive labelled with characters outside your code page shows its label instead
  of question marks; and a shared folder with an accented share name gets its
  shared-folder marker.

- **The internal viewer keeps its default character set.** Choosing one of the
  Central-European conversions (Kameničtí, KOI-8 ČS2) as the default no longer
  loses it on the next start. The viewer's window title shows accented file
  names correctly — in Czech, Slovak and Hungarian it was unreadable for every
  accented name, with or without a conversion selected.

- **Readable text in the remaining dialogs and lists.** The "Reading path…"
  wait window, the Location column and the *Keyboard Shortcuts* list in the
  Plugins Manager, the *Save Configuration* overwrite prompt, the directory-line
  tooltip when the path is very long, the archiver names in the Pack/Unpack
  dialog, and the ZIP overwrite prompt (which showed a stray `Â` for every file
  of 1000 bytes or more on a Czech system) all show their text correctly.

- **User-menu icons.** An item whose icon comes from a program stored under an
  accented path shows that icon instead of the default one — the icon picker had
  been showing it correctly all along.

- **Markdown Viewer keeps "instant view" after being reloaded.** Unloading and
  reloading the plugin in the Plugins Manager left the fast-start engine
  permanently disarmed, so every later view paid the slow first-time start.

- **File Comparator: the window title and the path bar.** A binary comparison
  showed the uncorrected title, and the path bar could come up empty.

- Environment variables such as `%USERPROFILE%` expand correctly on an accented
  account name — typing `%USERPROFILE%\Desktop` into Change Directory or the
  command line no longer reports that the path does not exist, file types whose
  icon is registered under such a path show their real icon, and programs
  started from Tandem Commander inherit correctly encoded per-drive folders.

- **A crash when putting a long or non-Latin file name on the command line.**
  Ctrl+Enter (insert the focused name) and Ctrl+Space / Ctrl+[ / Ctrl+] (insert
  the panel path) copied the text into a fixed 260-byte buffer. A name of about
  87 Chinese/Japanese characters, or 130 accented ones, or any long path,
  overflowed it and Windows terminated the program on the spot — losing the
  panel state and selection. Found by review, not from a report.

- **The Windows taskbar jump list now works for hot paths with accented names.**
  Right-clicking the taskbar icon showed such entries as mojibake, and clicking
  one did nothing at all, because the entry was built with the legacy text API
  while the launched program reads its arguments as Unicode.

- **A remembered directory with accented characters survives a restart.** The
  per-drive "return to this directory" value was saved correctly but read back
  through the legacy code page, so on the next start the panel silently fell
  back to an ancestor directory.

- **Leftover temporary files are cleaned up on profiles whose name or TEMP path
  contains accented characters.** Viewing files from archives or plugins left
  `SAL*.tmp` directories behind forever, a new one was created for every cached
  file instead of reusing the existing one, and the "delete leftover temporary
  directories?" prompt at startup either deleted nothing or never appeared. The
  same repair applies to the temporary-directory cleanup offered to plugins.

- **Rubber-band selection matches what is drawn.** Dragging a selection
  rectangle over files with accented names selected too many, because the
  panel measured the name's bytes rather than its characters.

- **Plugins Manager: the "Show in Change Drive menu" label is no longer
  mojibake** in Czech, Slovak, Hungarian, German and Spanish. This was a
  regression introduced by the 0.1.2 fix that repaired the plugin *name* on the
  same screen and left the label beside it unconverted.

- **ZIP: the overwrite confirmation shows the file name correctly**, and the
  **File Comparison window no longer loses its title** in Czech, French,
  Hungarian and Slovak (it was blank whenever a compared file had an accented
  name).

- **Byte counts no longer show a stray "Â" before every digit group** in
  languages whose word for "bytes" carries accents (Czech "bajtů", Hungarian
  "bájt"). The Drive Information dialog (Ctrl+F1) showed
  `967Â 709Â 523Â 968 bajtů` instead of `967 709 523 968 bajtů`; the same
  defect affected the directory-size and archive-size results dialogs and the
  "not enough space" message. Cause: the number carries the locale's
  no-break-space digit-group separator in UTF-8 while the localized word was
  composed in the legacy codepage, and the mixed text was then drawn through
  the legacy path. The internal viewer's file-offset tooltip had the same
  separator garble in every language with a non-ASCII separator and is fixed
  too. English and other languages whose formatting is pure ASCII are
  byte-for-byte unchanged, as is everything plugins display (several plugin
  dialogs have their own, pre-existing separator garble on such locales —
  those are recorded and will be fixed separately).

- **Files whose names contain a broken (unpaired-surrogate) character can now
  be deleted, copied, moved, renamed, viewed and modified.** Windows permits
  file names that are not valid Unicode text — they typically arrive from
  other tools or extracted archives, and the panel shows the unreadable
  character as a replacement glyph (Windows Explorer draws a box). Every
  operation on such a file failed with "file not found": the name lost its
  broken character the moment the folder was read, so all later operations
  asked Windows for a name that does not exist on disk. Names now keep their
  exact on-disk identity end to end — a copy or move reproduces the name
  character for character, two files differing only in the unreadable
  character stay distinct, "copy name/path" places the true name on the
  clipboard, and such names survive in the saved configuration (for example
  as a panel path) instead of being corrupted on exit. The panel and dialogs
  now render the unreadable character the same way Explorer does.

## [0.1.4] — 2026-08-19

**Build 188.** Bug-fix release: thumbnails in large photo folders start
appearing immediately and honor EXIF rotation; DEL deletes to the Recycle Bin
in folders with non-ASCII characters in the path; clipboard copies (Make File
List, copy name/path and every related text-copy command) keep accented
characters intact; TortoiseGit/TortoiseSVN status badges are back at display
scaling other than 100%. Full Debug and Release builds and the unit test
suite (1152/0) pass.

### Fixed

- **Thumbnails view (Alt+5) starts showing previews immediately, even in huge
  photo folders.** Two causes were fixed. The panel used to query sync/status
  badges for every file in the folder before attempting the first thumbnail,
  so in a folder with thousands of photos previews arrived only after minutes;
  that whole-folder pass now runs after the thumbnails of the visible screen.
  And every preview was produced by decoding the entire photo at full
  resolution (typically around a second per photo); the generator now uses the
  photo's embedded preview when present, or decodes at reduced resolution, and
  a background pass upgrades any lower-quality previews afterwards. Scrolling
  or jumping anywhere in the folder immediately redirects generation to the
  files on screen, and changing folders no longer waits for a running decode.
- **Photos taken in portrait orientation show correctly rotated thumbnails.**
  The panel ignored the EXIF orientation ever since the built-in Windows
  imaging engine replaced the proprietary one, so rotated photos appeared
  lying on their side in Thumbnails view.
- **Make File List (Ctrl+M) no longer garbles accented names.** The generated
  list reached the clipboard through a legacy code-page conversion, so Czech
  (and any non-ASCII) file names pasted as mojibake. The clipboard now carries
  true Unicode; applications that can only take legacy text get the best
  representation the system code page allows. The same wrong conversion sat
  behind every other text-copy command — Ctrl+C copy name/path, Copy UNC path,
  copies from the Find window, the directory/status line, message boxes
  (Ctrl+C) and the internal viewer's Copy on UTF-8 files — all fixed the same
  way. ASCII-only copies are byte-identical to before.
- **Make File List works with a non-ASCII list file name and %TEMP%.** Saving
  the list to a file like `seznam-příloh.txt` created a garbled file name on
  disk, and a Windows profile whose TEMP path contains accented characters made
  Ctrl+M fail outright with "error creating temporary file".
- **Make File List `:N`/`:max` columns align for accented names.** Width
  modifiers counted bytes, not characters, so accented names misaligned the
  columns — and a numeric width could even cut a name in the middle of a
  character. Widths now count displayed characters and cuts land on character
  boundaries. The viewer destination also renders the list correctly even when
  the first ten thousand bytes are plain ASCII.
- **Hint tooltips show correct diacritics in localized UIs.** The line-syntax
  help in Make File List — and every other hint of this kind (file-mask hints,
  hot-path hints, plugin-supplied hints) — was drawn through a font-charset
  dependent legacy path and rendered Czech text as mojibake. The tooltip text
  is now converted explicitly and always drawn wide.
- **Dialog labels are no longer clipped in translated UIs.** The "File:" radio
  label in Make File List was cut short in every non-English language
  ("Soubor:" showed as "Sou…"), and the same sizing defect hid parts of other
  labels (German "Interner Dateibetrachter" among them). The automatic layout
  widener now accounts for radio/checkbox glyphs and no longer lets a
  drop-down box block the space scan, and the affected dialog got more room in
  the master template; all shipped languages were re-laid-out, translations
  untouched.
- **DEL no longer permanently deletes in folders with non-ASCII characters in the
  path.** In any folder whose path contains characters outside the system code page
  (Czech diacritics above all — OneDrive trees with localized folder names were the
  common victim), DEL showed the direct-delete confirmation and deleted permanently,
  exactly like SHIFT+DEL, instead of moving files to the Recycle Bin as configured.
  The drive-type check feeding the recycle decision still read the UTF-8 panel path
  (0.1.1) through the legacy code page, classified the folder as invalid, and
  silently disabled the Recycle Bin. The decision is also fail-safe now: when the
  location cannot be classified, deletion attempts the Recycle Bin route instead of
  silently escalating to a permanent delete. Locations that genuinely have no
  Recycle Bin (network, removable, optical) keep today's direct delete with
  confirmation.
- **OneDrive folders can be deleted on the direct route.** Cloud-synced folders are
  reparse points, and the permanent-delete path treated every reparse directory as a
  junction/symlink, then refused the unfamiliar cloud tag with a confusing "error
  deleting directory link". Genuine junctions and symlinks keep the protective
  "remove the link, not the target" behavior.
- **The "Recycle Bin only for specified files" mode handles non-ASCII names.** The
  per-file recycle route (masks mode, and SHIFT-inverted deletes in the "delete
  directly" mode) still used the ANSI shell operation on UTF-8 names; it now uses
  the wide API like the main route (same fix class as 0.1.1's Recycle Bin repair).
  Junction and symlink targets with non-ASCII names are also resolved correctly now
  (shared machinery).
- **Third-party icon overlay badges (e.g. TortoiseGit/TortoiseSVN) are back.**
  Overlay handlers that supply their badge as an `.ico` file — the Tortoise
  family above all — were silently dropped on any display scaling other than
  100%, so their badges never appeared in the panels. The cause was the icon
  extraction helper introduced when Salamander was open-sourced in 2023: it
  lost the small icon of `.ico`-file sources at DPI-scaled sizes, and the
  overlay loader then rejected the whole handler. Handlers whose badge lives in
  a DLL (OneDrive, Google Drive) were unaffected, which is why only the cloud
  badges appeared to work. The same fix also repairs panel file icons taken
  from `.ico` files and the shortcut-arrow overlay at scaled DPI. Note the
  platform limits that remain: Windows caps concurrently usable overlay
  handlers, and on machines crowded with cloud providers the Tortoise
  components themselves refuse their rarer states (Locked, Ignored, ReadOnly,
  Unversioned) system-wide — File Explorer shows those nowhere either.
- **Overlay badges now refresh on paths with non-ASCII characters.** The
  change-notification path from Windows was still read through the legacy
  code page, so it never matched the UTF-8 panel path introduced in 0.1.1 and
  asynchronous providers (Tortoise status cache) were never re-asked; badge
  changes (modify, revert, commit) now show up automatically in folders like
  `D:\Zkouška` just as they do in ASCII paths.
- **Profiles migrated from Altap Salamander no longer start with icon overlays
  silently disabled.** Missing overlay settings now mean the factory default
  (overlays enabled); an explicitly stored "disabled" choice is still
  respected.
- **The "sync in progress" badge (0.1.3) survives a full overlay table.** The
  synthetic cloud-sync-pending entry now reserves its slot before third-party
  handlers are loaded; previously it silently disabled itself on machines with
  15 or more loadable handlers — which the TortoiseGit fix above would have
  made the common case.

## [0.1.3] — 2026-08-18

**Build 187.** Feature release: a standalone utility migrates settings from an
existing Altap Salamander installation, and cloud sync-status badges now
display as in Windows Explorer — in folders with non-ASCII names and for
items whose sync is still in progress. Shipped after an independent
multi-perspective stabilization review of every change since 0.1.2 (see
`specs/060-prerelease-stabilization/review-report.md`), with the full Debug
and Release builds, the unit tests (1145/0) and the migration utility's test
harness (98/0) all passing.

### Added

- **Settings migration from Altap Salamander.** A standalone one-time utility,
  `utils/migrate-altap-settings.cmd` in the source repository (a single
  downloadable file, not part of the installer), copies selected settings from
  an existing Altap/Servant Salamander configuration into Tandem Commander:
  directory hot paths, FTP bookmarks including stored passwords, user menu,
  viewer/editor associations, colors, confirmations, view templates and the
  configurations of shipped plugins. It backs up the current Tandem Commander
  settings first and generates a double-click restore script; the Altap
  Salamander configuration is read-only to the tool and never modified.
  Archiver settings and window/session state are deliberately not carried
  over; the closing summary names everything skipped and why. See
  `utils/README.md`.

### Fixed

- **Settings migration: the restore script now works for backup paths with
  non-ASCII characters.** `utils/migrate-altap-settings.cmd`'s generated
  "undo" script wrote itself in a fixed encoding that mangled non-ASCII
  characters in the embedded backup file path (e.g. a user profile name with
  diacritics) — the restore then deleted the current Tandem Commander
  settings and failed to find the backup to bring them back, losing both the
  new and the old configuration. The restore script now verifies the backup
  file exists before deleting anything, and is written in a way that reads
  correctly regardless of the launching command prompt's codepage. The
  wizard's backup screen also now notes that the backup file carries any FTP
  passwords already saved in Tandem Commander, and should be kept private
  and deleted once no longer needed.
- **A rare freeze on window activation over an unresponsive network share is
  closed.** The sync-status badge check added for cloud-synced folders could,
  in the narrow case of a hung/unresponsive network path, block the whole
  window from responding until the underlying network call gave up. Found
  and fixed during a stability review, not from a user report.

- **The sync-in-progress badge (blue arrows) now displays as in Explorer.**
  Items that Windows Explorer marks as "sync pending" — most visibly folders
  whose contents are still uploading or downloading in OneDrive — showed no
  status badge at all, a gap present even before the Open Salamander fork:
  the sync provider reports this state only through the Windows per-item
  state property, a channel the panels never consulted, not through the icon
  overlay handlers the panels read. Panels now fall back to that property
  (exactly the source Explorer documents for its state icon) for items no
  overlay handler claims inside a cloud-synced folder, and show a
  sync-pending badge that clears when the provider finishes. The badge obeys
  the existing icon-overlay configuration (it can be disabled under the name
  `TandemCloudSyncPending`); behavior everywhere else, including Google
  Drive letter drives, is unchanged.

- **Folders with non-ASCII names misbehaved three ways** — most visibly on
  cloud drives such as Google Drive's `G:\Můj disk`, where the folder name is
  not the user's choice: cloud sync-status badges (synced / online-only /
  syncing / error) never appeared even though Windows Explorer showed them;
  files like Word documents or PDFs fell back to a generic blank icon; and
  the window flashed a busy cursor on every activation without any visible
  result, because automatic change monitoring was silently broken and the
  panel re-listed the folder on each return to the application (changes made
  by other programs also stopped appearing automatically in such folders).
  All three were one regression from the Unicode/long-path rework: three
  places still interpreted the now-UTF-8 panel path in the legacy 8-bit
  encoding, so any path with characters like "ů" was garbled before reaching
  Windows. ASCII-only paths — including typical OneDrive folders — were never
  affected, which made the defect look Google Drive-specific.

## [0.1.2] — 2026-08-07

**Build 186.** Maintenance release: the SFTP plugin's dialogs and connection
handling are reworked for reliability, plugin names render correctly in every
language, and all machine-translated UI text was re-done with context. Shipped
after an independent multi-perspective stability and security review of every
change since 0.1.1 (see `specs/056-prerelease-review/review-report.md`), with
the full build, the SFTP behavioural harness, the unit tests and the
translation checks all passing.

### Changed

- **Better wording across all 8 non-English languages.** Every UI string that
  had been machine-translated word-by-word (without knowing where in the
  program it appears) was re-translated with its context: which dialog or menu
  it lives in, what kind of control it labels, what its neighbours say, and
  what the module does. This fixes the class of errors where a correct word
  for the wrong meaning was chosen — e.g. Czech "Host:" rendered as a
  talk-show presenter instead of a server address. About 3,300 strings across
  the file manager and 18 plugins were refreshed; human-made translations were
  not touched. The SFTP plugin received the same treatment earlier.

### Fixed

- **SFTP: the plugin's settings could not be opened at all.** Pressing
  Configure in Plugins Manager left the application unresponsive, with nothing
  on screen to close — it had to be killed, and no SFTP setting could be
  changed by any means. The settings window existed but had no title bar or
  frame and was positioned outside the window it belonged to, so it was clipped
  away entirely. It is now an ordinary window with a title and OK/Cancel, like
  every other plugin's settings.
- **SFTP: connecting to a host whose first address is unreachable now works.**
  When a host name offered several addresses and the first silently dropped
  traffic, the whole connect time was spent waiting on it and the remaining
  addresses were never tried — typically `localhost` on a machine whose IPv6
  loopback is filtered, which failed after the full timeout while `127.0.0.1`
  connected instantly. Addresses are now attempted with a slight overlap and
  the first to answer wins, so such a host connects in about a second. A host
  that really is unreachable still fails within the configured timeout, never a
  multiple of it.

- **SFTP: text was cut off in the plugin's dialogs in every non-English
  language.** Controls were sized for English, so longer translations were
  truncated mid-word — in Czech the key-file label read "Soubor s" and the
  passphrase label "Heslo ke". It was not just the connect dialog: 26 controls
  across six dialogs were too narrow, worst a settings checkbox with room for
  about 60% of its text. The dialogs are now sized for the longest translation
  that ships. **No wording changed** — the translations were always correct,
  only their display was not.
- **SFTP: the password prompt could not fit its own message.** The text asking
  for a passphrase again after a wrong one, with the key file's path in it,
  needed more room than the two lines it had.
- **SFTP: two controls in the plugin's settings overlapped each other** — the
  "show octal mode" option sat on top of the permissions-column choices. It is
  now its own row.

- **Plugins Manager showed garbled plugin names in non-English UI.** With the
  UI in Czech, names of plugins that were not currently loaded rendered as
  mojibake ("HromadnĂ© pĹ™ejmenovĂˇnĂ­" instead of "Hromadné přejmenování");
  loading a plugin "healed" its row until the next start. The cause: the name
  cached in the configuration and the name obtained from a loaded plugin
  carried two different text encodings, and the list drew the raw bytes.
  Plugin metadata now has one defined encoding everywhere — the same fix
  covers every message composed with a plugin name (add/remove/test plugin
  prompts, hotkey-conflict warnings, packer/unpacker errors, the
  "show in bar" label). Existing configurations display correctly as they
  are; nothing is migrated or rewritten.
- **The display-encoding guard can no longer be skipped silently.** The build
  used to print "Encoding guard: SKIPPED" when Python was missing — the exact
  hole this defect shipped through. A missing Python now fails the build, and
  the guard knows plugin metadata by contract, so this class of defect fails
  the build instead of reaching users.

### Changed

- **SFTP: the connect dialog is sized for the language in use.** Its labels
  used to be given room for the longest translation of every shipped language
  at once, which left a wide empty band between the labels and the input fields
  in most languages. The dialog now measures the labels it is actually showing
  and sits them next to their fields; the fields keep their width and the
  window itself is narrower or wider depending on the language.
- **SFTP: Quick Connect no longer remembers anything, and can no longer store a
  password.** It exists for one-off connections, so every field starts empty
  each time you open the dialog and nothing about it is written to your
  settings. The "save password" and "save passphrase" options are unavailable
  while Quick Connect is selected, as is "Save" — those belong to bookmarks. A
  Quick Connect password saved by an earlier version is **deleted** the first
  time this version loads the plugin. Bookmarks are unaffected: they keep their
  values and their saved passwords exactly as before.
- **SFTP: a bookmark can now be created and saved empty.** Previously a server
  address was demanded the moment you created one, so you could not name an
  entry and fill in the details later. The address and port are now required
  only when you actually connect, with the same message as before.
- **The ZIP plugin is named "ZIP" in every language.** Machine translation had
  turned the name into the postal code: "PSČ" (Czech, Slovak), "Code postal"
  (French), "Código postal" (Spanish), "邮编" (Simplified Chinese), and
  Germany had "ZIP-Archiv". The name is now pinned as untranslatable, so a
  future re-translation cannot undo it.

## [0.1.1] — 2026-08-05

**Build 185.** Bug-fix release: private-key authentication in the SFTP plugin,
plugin stability, and contextual UI translations.

### Fixed

- **SFTP: connecting with a private key froze the whole application.** With a
  key in the OpenSSH format — what `ssh-keygen` has produced by default since
  OpenSSH 7.8 — the application became unresponsive and had to be killed. Three
  defects compounded: the bundled libssh2 could not stop scanning for a PEM
  header that was never there (its line reader could not report the end of the
  buffer), the Windows CNG key loader only understood classic RSA/DSA PEM while
  the plugin's format check accepted OpenSSH keys anyway, and the whole connect
  sequence ran on the user-interface thread, so the resulting spin took the
  application down with it.
- **SFTP: OpenSSH-format RSA and ECDSA keys now work**, both for authentication
  and for signing, and so do classic PEM keys protected by a passphrase — the
  passphrase used to be discarded before it reached the decryption step, so even
  a correct one failed.
- **SFTP: a key the application cannot use is now refused up front** with the
  reason and the remedy, instead of failing later with a low-level error:
  PKCS#8 keys, PuTTY `.ppk` files, and ed25519 keys (unsupported by the Windows
  CNG backend this build uses).
- **SFTP: a wrong or missing passphrase now re-prompts** instead of ending the
  attempt, and a key the *server* rejects now offers password authentication
  when the server permits it.
- **SFTP: authentication failures are reported accurately.** Failures were
  classified by matching words in the underlying library's message, which never
  matched its actual wording, so a key that could not be read was reported as
  "server rejected the key".
- **SFTP: a lost connection is noticed.** After a network drop or a server
  restart the session still looked alive, so every following operation failed
  with a raw error and the only way out was to close the panel. The session is
  now marked dead and the next operation reconnects.
- **SFTP: no operation can hang the application any more.** Connecting runs on
  a worker thread with a wait window that cancels within about a second; every
  network wait is bounded (the session timeout was silently not enforced
  before); viewing a remote file with F3 can be aborted; keepalive and
  disconnect no longer stall on a server that went silent; the connect timeout
  is now a budget for all of a host's addresses instead of per address.
- **SFTP: a memory leak on every connection.** The key exchange leaked a small
  block per session, which the Debug build reported as "Detected memory leaks!"
  on exit. This one predates the release and affected password logins too.
- **Translations: UI labels are translated for the place they appear in.**
  Short labels were machine-translated from the word alone, so the Czech SFTP
  connect dialog labelled the server address field "Moderátor" (a talk-show
  host), the key file field "Klíčový" (a dangling adjective) and the New
  bookmark button "Novinka" (a news item), and both the password and the
  passphrase field read "Heslo:". The translation pipeline now sends the
  engine a description of each string's location and role, hand-curated texts
  override it where wording still needs a human, and duplicate keyboard
  accelerators within a dialog are resolved automatically (Windows cycles
  between controls that share one instead of activating either). **Scope**: the
  SFTP plugin's texts were re-translated this way in all eight shipped
  languages; the other modules keep the translations they had and will improve
  when they are next re-translated.

### Changed

- The SFTP plugin's test harness exercises the code path the product actually
  uses, runs its scenarios under a watchdog that fails on a hang, and fails on
  a memory leak. The defect above escaped precisely because the harness tested
  a different, safe code path.

## [0.1.0] — 2026-08-05

**Build 184.** First public release: Tandem Commander's own identity, a
reproducible build, Unicode and long-path support throughout, and two new
plugins.

### Added

- **Own product identity.** Binary `tandemcommander.exe`, its own registry root
  (`HKCU\Software\Tandem Commander\0.1`), inter-process and shell-extension
  names, website and installer. Configuration is never read from or written to
  an Open Salamander installation, so the two can coexist. Icons and About/
  splash artwork are generated from hand-swappable sources in `tools/brand/`.
- **SFTP plugin** — connect to SSH servers, browse, transfer, rename, delete,
  change permissions and ownership, create symbolic links, bookmarks with
  optionally stored credentials, host-key verification on first connect,
  per-session logs. Built on a bundled libssh2 using Windows CNG for
  cryptography, so no OpenSSL is required.
- **Markdown viewer plugin (mdview)** — renders Markdown files in the viewer.
- **Visual themes, including a dark mode** across the application, its
  dialogs, toolbars and file panels, extended to plugin dialogs through six new
  plugin-interface methods (interface version 106).
- **Reproducible one-command build.** `build.cmd` drives the whole build from
  the repository root; which plugins ship is a committed policy
  (`plugins.cfg`, 18 of 28 enabled), and so is which languages ship
  (`translations/languages.cfg`).
- **Translations built from committed source.** Eight languages ship (English,
  Czech, German, French, Dutch, Hungarian, Romanian, Slovak, Spanish); the
  translation text lives in the repository and language modules are produced by
  the build. Simplified Chinese, Russian and Ukrainian are held back pending a
  menu rendering defect; their translation source is retained.
- **On-demand code signing** for release builds and the installer
  (`build.cmd full release sign setup`).

### Changed

- **UTF-8 file names and long paths throughout.** File names are handled as
  UTF-8 and paths beyond `MAX_PATH` work across browsing, file operations, the
  viewer, Find, rename, archives and the information line. This was an ABI
  break for plugins (interface version 104), so third-party plugins built for
  older versions are refused at load; a migration guide is in
  `doc/plugin-vnext-migration.md`.
- **Copyright attribution.** Work up to 2026 stays credited to the Open
  Salamander Authors; 2026 onward to Pavel Stupka. The SFTP and mdview plugins
  are solely his.
- **Eight obsolete plugins removed** (pak, unarj, unlha, unfat, wmobile,
  ieviewer, splitcbn, winscp); the PictView plugin now uses the Windows
  imaging engine and no longer needs an external converter DLL.

### Known limitations

- The HTML help is not yet rebranded.
- Two plugins have unresolved external dependencies: unrar needs `unrar.dll`,
  the FTP plugin needs OpenSSL.
