# Changelog

All notable changes to Tandem Commander are recorded here, newest first.

Tandem Commander is derived from Open Salamander, which was open-sourced under
GPLv2 in 2023; this file starts at the first Tandem Commander release and does
not restate Open Salamander's own history. Versions follow
`MAJOR.MINORA.MINORB` (see `src/plugins/shared/spl_vers.h`), and each release
also carries an internal build number shared by the application and every
plugin.

## [0.1.11] — unreleased

- **Opening a damaged or crafted Nero image (NRG) of several sessions could crash the program** (feature 340).
  - **Before:** each session of an NRG image says how many tracks it holds, and the ISO plug-in believed it. When the sessions counted more tracks than the image has (or a count of 2^31 or more, read as a negative number), listing the image as "Session 01", "Session 02", ... read past the end of the plug-in's track table - in the Debug build a range-check message, in the release build a crash or a read of unrelated memory; with one such count a session's files were silently left out.
  - **Now:** each session gets at most the tracks the image really has, in order; those are listed in its folder as before. A session count that does not fit marks the listing incomplete, so a whole Unpack (Alt+F9) extracts everything there is and keeps the image, also with "Delete archive after unpacking". Images whose counts fit list and unpack exactly as before.
  - **Limitation:** no message says why the image was kept. The image information shown by View (F3) still reads the session counts unchecked when they add up to fewer tracks than the image holds (recorded for a later fix). Not tried with a damaged image made by Nero itself.
- **Unpack with "Delete archive after unpacking" deleted a Mac disc image after writing its compressed files empty** (feature 339).
  - **Before:** on the HFS+ part of a disc image made on a Mac, a file that macOS keeps compressed (HFS+ compression) or whose content is only in its resource fork (for example a custom folder icon) was extracted as an empty file, without a word, and counted as extracted. A whole Unpack (Alt+F9) with "Delete archive after unpacking" then deleted the image with the file's only content; Copy (F5) also produced the empty file.
  - **Now:** such a file is not written. A box names it and says why (compressed, or stored only in its resource fork) with Skip, Skip all and Cancel; a whole unpack then fails, so the image is kept, and everything else is extracted. Ordinary files extract as before.
  - **Limitation:** the content of such files cannot be extracted (no decompression). A file that has data and also a resource fork extracts its data only, and the image is still deleted (recorded as a decision). The listed size of such a file stays the size of its (often empty) data fork. Not yet tried with an image made on a real Mac.
- **Unpack with "Delete archive after unpacking" deleted a disc image after a file of it was skipped** (feature 338).
  - **Before:** a whole Unpack (Alt+F9) of a disc image counted as successful whenever it was not cancelled. A file that could not be read (a damaged sector) and was answered Skip or Skip all, a file that could not be created in the target folder, a file whose overwrite question was answered Skip, a folder that could not be created - after each the other files were extracted, the unpack reported success and "Delete archive after unpacking" deleted the image with the only copy of what was skipped. After Skip all (or after an overwrite question answered All) later read errors showed no box at all, and the file was simply missing. A damaged or crafted image listing two files of one name had the second written over the first, and the image was deleted too.
  - **Now:** a whole unpack in which any file or folder was not extracted whole fails, so the image is kept; everything that could be extracted stays extracted. A file written over a file the same unpack had written (told by the file system's identity, not by the names) fails it too. Unpacking an intact image, and replacing your own files in the target on your answer, work and delete the image as before. The boxes and their buttons are unchanged.
  - **Limitation:** no message says why the image was kept (each skipped file had its own box). Copy (F5) out of an opened image is unchanged. Where the target's file system gives no file identities (some network shares), a target file met again after anything was written keeps the image.
- **Unpack with "Delete archive after unpacking" deleted a disc image whose Video CD-like stream track a file covered only in part** (feature 337).
  - **Before:** since feature 336, a CD-ROM XA Mode 2 Form 2 stream track (a Video CD / SVCD video stream) of a disc image (NRG, CCD/IMG) counted as extracted as soon as any listed file started in it, however little of the track the file held. With a damaged or crafted directory whose `AVSEQ01.DAT` entry is shorter than its stream, Unpack (Alt+F9) with "Delete archive after unpacking" extracted that part, reported success and deleted the image with the rest of the stream.
  - **Now:** the stream counts as extracted only when every part of it that no listed file extracts whole is an empty gap (as the 2-second gaps around the video files of a real Video CD); otherwise Unpack extracts everything listed and keeps the image. Video CD and SVCD images made by vcdimager (NRG and CCD/IMG) are unpacked and deleted as before; a truncated image, or one whose track table gives the stream too few sectors, is kept.
  - **Limitation:** no message says why the image was kept. An image whose gaps are not empty (made by other software) is kept too. Video CD / SVCD video files still extract cut to 2048 bytes of each 2324-byte sector, and such an image is still deleted after a whole unpack; a file skipped after a read error still lets the unpack succeed (recorded for a later fix).
- **Unpack with "Delete archive after unpacking" deleted a disc image with a Video CD-like stream track that no file of the image refers to** (feature 336).
  - **Before:** since feature 335, a data track of a disc image (NRG, CCD/IMG) in CD-ROM XA Mode 2 Form 2 sectors - a Video CD / SVCD video stream - was taken as safe whether or not any listed file covered it. A Video CD extracts its streams through the `AVSEQnn.DAT` / `AVSEQnn.MPG` files of its first track, but a stream that no file refers to (in a session of its own, or on a Video CD whose directory lost those entries) listed nothing: Unpack (Alt+F9) with "Delete archive after unpacking" reported success and deleted the image with the stream.
  - **Now:** such a stream track counts as left out unless a listed file starts in it: Unpack extracts everything listed and keeps the image even with "Delete archive after unpacking". Video CD and SVCD images whose files cover their streams (made by vcdimager, as NRG and CCD/IMG) are unpacked and deleted as before.
  - **Limitation:** no message says why the image was kept. A file that merely starts in a stream track covered it, however little of the track it held (kept since feature 337); a Video CD whose directory does not refer to one of its streams keeps its image after a whole unpack. Video CD / SVCD video files still extract cut to 2048 bytes of each 2324-byte sector (measured on real images; recorded for a later fix), and such an image is still deleted after a whole unpack with "Delete archive after unpacking".
- **Unpack with "Delete archive after unpacking" deleted a disc image one of whose data sessions had lost its file system** (feature 335).
  - **Before:** in a disc image with a track table (NRG, CCD/IMG), a data track in which the ISO plug-in found no file system it knows (its volume descriptors destroyed, but the track within the image) was taken as raw data that lists nothing, like the video tracks of a Video CD. Unpack (Alt+F9) with "Delete archive after unpacking" then extracted the other sessions, reported success and deleted the image: the files of the damaged session were lost.
  - **Now:** such a track counts as left out unless it is a Video CD / SVCD stream (its sectors from 16 on are CD-ROM XA Mode 2 Form 2, which never holds a file system): Unpack extracts everything listed and keeps the image even with "Delete archive after unpacking". Video CD and SVCD images (made by vcdimager, as NRG and CCD/IMG) and images whose tracks all have a file system are unpacked and deleted as before.
  - **Limitation:** no message says why the image was kept. A Video CD stream track with a zero-filled sector near its start keeps the image too; a Form 2 track that no listed file covers was still deleted with the image (kept since feature 336), and Video CD video files may extract cut to 2048 bytes a sector - recorded for a later fix.
- **Unpack with "Delete archive after unpacking" deleted a disc image with a track the ISO plug-in could not read, or with audio tracks** (feature 334).
  - **Before:** in a disc image with a track table (NRG, CCD/IMG), the ISO plug-in skipped a track it could not open - a session whose file system does not open (the "Some error(s) occured while reading multisession image" box), a track whose data lies past the end of the file, a track of a type it does not know, a track no session covers, the last data track of a single session - and listed the rest. It never extracts audio tracks, and in a single-session listing it does not even show them or the other data tracks. Unpack (Alt+F9) with "Delete archive after unpacking" then extracted what was listed, reported success and deleted the image: the files of the skipped tracks and all audio were lost.
  - **Now:** such a listing counts as incomplete: Unpack extracts everything listed and keeps the image even with "Delete archive after unpacking". This includes audio CDs, CD-Extra and mixed-mode (data + audio) images. Images whose data tracks all open and that hold no audio are unpacked and deleted as before, also Video CD images with raw video tracks. The box and the listing in the panel are unchanged.
  - **Limitation:** no message says why the image was kept. A data track inside the image whose file system is destroyed was still taken as raw data that lists nothing (kept since feature 335).
- **Unpack with "Delete archive after unpacking" deleted a hybrid disc image whose HFS+ part could not be read** (feature 333).
  - **Before:** a hybrid CD/DVD image (ISO 9660 or UDF plus an HFS+ part for Macs) is listed with one folder per part. When the ISO plug-in could not read the HFS+ part at all - its volume header of an unknown version, its catalog damaged, empty or past the end of the file, or an entry of the image's Apple partition map damaged - it left the part out without a word. Unpack (Alt+F9) with "Delete archive after unpacking" then extracted the other parts, reported success and deleted the image: files that exist only in the HFS+ part were lost.
  - **Now:** when the image holds an HFS+ volume (its own signature is there) that cannot be read, the listing counts as incomplete: Unpack extracts everything listed and keeps the image even with "Delete archive after unpacking". Undamaged hybrids, and Linux install images whose Apple partition map holds only their EFI boot image, are unpacked and deleted as before.
  - **Limitation:** no message says why the image was kept. An HFS+ part whose signature itself is destroyed, and APFS, original HFS and HFSX parts (which the plug-in never lists), still let Unpack delete the image - the last three wait for a decision.
- **Unpack with "Delete archive after unpacking" deleted a disc image whose HFS+ part held a damaged entry** (feature 332).
  - **Before:** when the ISO plug-in met a damaged record in the HFS+ part of a disc image (a Mac or hybrid CD/DVD image) - a file or folder entry whose data does not fit, whose name is too long or broken, or of a kind the plug-in does not know - it skipped the entry (or stopped listing the HFS+ part) without a word. Unpack (Alt+F9) with "Delete archive after unpacking" then extracted what was listed, reported success and deleted the image: the skipped files were lost.
  - **Now:** such a listing counts as incomplete: Unpack extracts everything listed and keeps the image even with "Delete archive after unpacking". Undamaged images, including the internal records every HFS+ volume holds, are unpacked and deleted as before. A UDF file whose entry cannot be read already kept the image since feature 330.
  - **Limitation:** no message says why the image was kept. An HFS+ part whose catalog cannot be read at all, a name with a null character inside, and hard-linked files (extracted empty, their data under internal `iNode` names) are recorded for later fixes.
- **Opening a damaged or crafted Nero image (NRG) could crash the program or corrupt its memory** (feature 331).
  - **Before:** an audio track whose CD-Text title was longer than 256 bytes overran a fixed buffer of the ISO plug-in while the image was listed; a CD-Text block whose size did not match the image, or a track table naming tracks the image does not have, made the plug-in read or write outside its memory - in the Debug build a run-time check or heap-corruption message, in the release build a crash or silent memory corruption.
  - **Now:** the track's name is kept whole, whatever its length: it is listed, or - when longer than the panel can show - left out and named in the usual message about entries that could not be listed. The CD-Text block is used only when it lies within the image, and track information is applied only to tracks the image has. Undamaged images list exactly as before.
  - **Limitation:** a CD-Text block that claims to reach past the end of the file makes the image open as an unknown format, as other truncated Nero images do. Two other unchecked values of the Nero format (the cue-sheet size and the session track counts), and audio track names that are not converted to Unicode or made safe, are recorded for later fixes.
- **Unpack with "Delete archive after unpacking" deleted a damaged disc image although some of its folders could not be read** (feature 330).
  - **Before:** when the ISO plug-in could not read a folder of an image (its data past the end of the file, a damaged record), it showed "Error reading directory structure ... Incomplete content of ISO image" and listed no folder after it. Unpack (Alt+F9) with "Delete archive after unpacking" then extracted what was listed, reported success and deleted the image: the files of the unreadable folder and of every later folder were lost. The same happened in ISO 9660, UDF and Xbox images, when a UDF folder's entry could not be read (no message at all), and when the UDF part of a UDF + ISO 9660 image could not be read at all.
  - **Now:** a listing that met such a damaged folder or file-system part counts as incomplete: Unpack extracts everything listed and keeps the image even with "Delete archive after unpacking". The messages are the same as before; undamaged images are unpacked and deleted as before.
  - **Limitation:** folders after the damaged one are still not listed (recorded for a later fix); a damaged HFS+ part of an image, and a session of a multi-session image that cannot be opened, still let Unpack delete it (both recorded for a later fix). When nothing was shown while listing (a UDF folder whose entry cannot be read), the image is kept without a message.
- **A disc image whose UDF, Xbox or HFS+ file system holds a folder tree deeper than the panel can show opened with "Error" or "too long path" and later folders missing, and "Delete archive after unpacking" could delete it after a partial unpack** (feature 329).
  - **Before:** feature 328 fixed this for ISO 9660 volumes only. In the UDF part of an image (or a UDF image) and in an Xbox image, an entry deeper than the panel listing takes (a folder path of more than 255 bytes) showed "Error" and no folder after it was listed; in an HFS+ part the message was "This disk image contains a too long path" and the rest of the HFS+ volume was missing; an audio track whose CD-Text name was too long (an NRG image) emptied the listing. Unpack with "Delete archive after unpacking" then extracted what was listed and deleted the image.
  - **Now:** such an entry is left out alone - a folder with its contents - and everything else is listed; the same message as for ISO 9660 names the left-out entries with their whole paths in the image (for example `UDF (label)\...`). Unpack of such an image extracts everything listed and keeps the image even with "Delete archive after unpacking".
  - **Limitation:** an HFS+ folder whose catalog number is lower than its parent's (moved into a newer folder on a Mac) still has its contents listed at the HFS+ root; entries skipped because the HFS+ data is damaged still let Unpack delete the image (both recorded for a later fix; damaged UDF data keeps the image since feature 330).
- **A disc image with a folder tree deeper than the panel can show opened with a bare "Error" and most of its folders missing, and "Delete archive after unpacking" could delete it after a partial unpack** (feature 328).
  - **Before:** when an entry of an ISO image lay deeper than the panel listing takes (a folder path of more than 255 bytes - five nested folders of 60 letters are enough), the ISO plug-in showed "Error", threw away everything it had listed so far and listed no folder after it: the image opened with the deep tree and later folders missing, with nothing naming them. This hit images made by genisoimage (Rock Ridge or Joliet); images made by xorriso were listed whole but under their upper-case, shortened ISO 9660 names. Unpack (Alt+F9) with "Delete archive after unpacking" then extracted what was left and deleted the image.
  - **Now:** an entry the panel cannot show is left out alone; everything else is listed, and one message names the left-out entries with their whole paths in the image. Unpack of such an image extracts everything listed and keeps the image even with "Delete archive after unpacking". A Rock Ridge image keeps its real names wherever they fit; only the deep folders that must be shorter for their contents to be shown get their ISO 9660 names, so the deep files stay reachable. A file keeps its real name also when its path in the image is very long. A crafted image whose folders point back to themselves opens at once instead of keeping the program busy.
  - **Limitation:** a Joliet image has no second name to fall back on, so its too-deep entries stay out of the listing (named in the message). A file deeper than 259 bytes in the image cannot be copied by selecting a folder from the image's root - the usual "Name ... with full path is too long" question appears; Unpack, or a copy from a folder nearer to it, extracts it. UDF, Xbox and HFS+ volumes are handled the same way since feature 329; an image with an unreadable folder is kept by Unpack with "Delete archive after unpacking" since feature 330.

- **A disc image with crafted file names could put files outside the folder they were extracted to, or hide their data in an NTFS stream** (feature 327).
  - **Before:** the ISO plug-in took the names an image stores as they were - also from Joliet, plain ISO 9660, UDF, HFS+ and Xbox images, and the volume label a hybrid image is listed under. An image can hold names Windows must not take: `12:30.txt` became a file `12` with the data in a hidden stream, `con.txt` a device name, `name.` a file Windows tools cannot open, a name with `/` or `..\` was lost with an error, and a volume label `v\..\..\w` made every file of the image be written next to the target folder instead of into it. Only Rock Ridge names were made safe (feature 326).
  - **Now:** every name the plug-in lists, from any of its file systems, and every volume label folder is made safe the way archive names are: `\`, `/`, `:` and the other characters Windows forbids become `_`, a trailing dot becomes `_`, a device name gets a `_` prefix (`_con.txt`); names are never shortened or dropped, and ordinary names stay exactly as they were. Extraction makes the name safe once more before it writes.
  - **Limitation:** two names that differ only in such characters (`a:b` and `a_b`) end up with the same name, and the usual overwrite question appears.

- **CD images made on Linux with xorriso showed and extracted files under upper-case, shortened names** (feature 326).
  - **Before:** Rock Ridge stores a file's real name in an image (lower case, up to 255 letters). The ISO plug-in read it only when an image marked each file with an old Rock Ridge entry that current tools no longer write: in an image made by xorriso, the tool most Linux distributions build their images with, `top.txt` was listed and extracted as `TOP.TXT`, a folder `folder` as `FOLDER`, a file of a 200-letter name under 31 upper-case letters, and two files could end up under the same name. A Rock Ridge name containing `;` was cut at it (`a;b.txt` came out as `a`).
  - **Now:** the plug-in recognises Rock Ridge by the marker every such image carries at its root, and lists and extracts files and folders under their real names, whole and with their case, also with a `;` in them. A Rock Ridge name Windows cannot take as it is is renamed safely, as in other archives: `..\x.txt` becomes `.._x.txt` and stays in the target folder, `12:30.txt` becomes `12_30.txt`, `con.txt` becomes `_con.txt`, a trailing dot becomes `_`. Names that differ only in case (`a.txt` and `A.txt`, folders `D` and `d`) stay two items, as in TAR and 7-Zip archives. Images made by genisoimage keep their Rock Ridge names, now made safe in the same way; images without Rock Ridge and Windows images (Joliet) keep their names as before.
  - **Limitation:** an image that has both Rock Ridge and Joliet is still listed through Joliet, as before; an image whose Rock Ridge folders are nested deeper than the panel can show is listed with its upper-case ISO 9660 names, as before; a CD-XA image whose Rock Ridge marker does not lie at the start keeps the upper-case names.

- **Copying the files shown in a folder of a TAR archive left out the second names of hard-linked files without a word** (feature 325).
  - **Before:** GNU tar and Python store a file that has several names (hard links) once, and its other names as links to the first. The TAR plug-in did not show those names in the panel, so a user who opened a folder of the archive and copied the files shown there (Select All, Copy) got only the files stored with data - the other names were missing, with no message. A link could not be copied or viewed on its own either.
  - **Now:** a hard link is listed as a file with the size of the file it names, and copying it - also alone, also without the file it names, also from a compressed `.tar.gz` - writes that file's content under the link's name; F3 shows it. When that content was already passed, the archive is read a second time for it. For an archive updated with `tar -u` (a name stored twice) the link gets the version stored last before it, as tar extracts it. A link to a file the archive does not hold is named in a message and the operation ends as failed, so "Delete archive after unpacking" keeps the archive.
  - **Limitation:** symbolic links are still not listed (they cannot be created); FIFO and device members are still skipped without a message (recorded for a later fix); a link to a member whose path is too deep for the panel is listed with size 0.

- **Undelete could restore files onto the very disk they were being recovered from without its warning** (feature 324).
  - **Before:** before restoring, Undelete warns when the target folder is on the disk the deleted files come from, because writing there can overwrite files not yet recovered. When the target was reached through a folder the disk is mounted at and that folder's name had a letter outside the English alphabet (for example `C:\mnt\Zálohy`), or through a junction that names the disk by its volume ID, the program could not tell the target's disk, took it for another one and restored without the warning. Viewing a deleted file could likewise put its temporary copy on that disk without asking for another folder.
  - **Now:** when the disk of the target cannot be told by name, Undelete compares the disks the two folders are actually on (their volume serial numbers, through any mount folder or junction); when even that cannot be read, it shows the warning (or asks for another temporary folder). Targets on another disk are restored without a warning, as before.
  - **Limitation:** a target whose disk reports no serial number (some network or RAM drives), a network folder that does not answer, or a source disk whose root cannot be opened now shows the warning - press OK to continue; "Don't show this again" still turns the warning off.

- **An FTP upload could replace a file that had just been renamed in the FTP panel, without asking** (feature 323).
  - **Before:** while an upload to an FTP server was still in progress (for example waiting on an overwrite question), a file renamed in the FTP panel (Quick Rename) to `b.txt`, followed by an upload of a local `b.txt` into the same folder, was stored over the renamed file without the "Target File Already Exists" question. A folder created with Create Directory (F7) by typing a path outside the panel's folder was unknown to that upload: it tried to create the folder again and stopped with "Error Creating Target Directory". The panel reported these changes to the upload with the server's host and user name in each other's places, so they never arrived.
  - **Now:** Create Directory and Quick Rename in the FTP panel update what a running upload knows about the server: the overwrite question appears for the renamed file, and a folder made with F7 is joined. After a Quick Rename or a command sent with Send FTP Command, the upload lists the server's folders again before it decides whether a name exists. A folder created with a path (`.cfg/new`) never makes the upload believe that the folders on the way are new and empty - a folder the listing does not show (a hidden dot folder, or `Docs` typed as `docs` on a server that ignores case) is listed again, so its files are not overwritten without the question.
  - **Limitation:** an upload to the same server under another name (`localhost` and `127.0.0.1`) still does not learn of the panel's changes; Send FTP Command updates it only with "Command can make changes on working path" ticked (the default).

- **A CD image with Chinese or Japanese file names (Joliet) extracted files under shortened names, and a damaged Mac disk image (HFS+) could be read outside its catalog** (feature 322).
  - **Before:** in an ISO image made on Windows (Joliet), a file whose name is mostly Chinese, Japanese or Korean letters lost the end of its name in the listing and when extracted - a file of 12 such letters and `.txt` came out without `.txt`, a longer name broke inside a letter and came out as unreadable characters. In the HFS+ part of a Mac disk image, the ISO plug-in followed the node numbers, links and record positions of the catalog without checking them, so a damaged image could make it read memory outside the catalog or loop without end.
  - **Now:** Joliet file names are kept whole. Every node, link and record of an HFS+ catalog is checked against the catalog it was read from; a damaged catalog is refused with the message "The Catalog file of the HFS Plus partition is damaged." (in an image that also holds ISO 9660 or UDF, those parts open as before), and a single record that does not fit is left out of the listing. Valid images list and extract as before.
  - **Limitation:** Rock Ridge names in images made by xorriso (most Linux distribution images) are still shown as their short ISO 9660 names, and such an ISO + HFS+ image still shows "Cannot read sector #00000020." when it opens - both as in 0.1.10.

- **Opening a TAR archive whose member has a name of 300 Chinese or Japanese letters closed the program with a bug report** (feature 321).
  - **Before:** a GNU-format TAR member at the top of the archive whose name has a part longer than any file system takes (measured: 300 CJK letters) was handed to the panel whole, and the panel's fixed name buffers overflowed as soon as the archive was shown - "A problem has occurred, forcing Tandem Commander to close". A GNU-format member deeper than a panel listing holds (for example 12 folders of 200 letters), or a folder of 255 CJK letters with files in it, made the whole archive refuse to open with "Internal error: file data structure corrupted.".
  - **Now:** GNU-format long names are treated exactly like extended-header paths (features 306, 308): a member whose name no file system takes is left out with the message "The filename or extension is too long." and its path - never shortened; Unpack extracts everything else and then ends as failed, so "Delete archive after unpacking" keeps the archive. A member deeper than a panel listing holds is not shown in the panel (the same message on opening), but Unpack and copying its folder extract it. A top-level folder whose name is long but valid (up to 255 characters) is listed and extracted as in 0.1.10 - also from an extended header; as in 0.1.10, such a folder of more than 85 Chinese or Japanese letters cannot be opened in the panel ("The path specified is too long."), but Copy and Unpack extract it with its contents. The panel itself also refuses an entry whose name is longer than its name buffers (780 bytes), whatever plug-in lists it (an archive's top level, FTP, SFTP, the registry editor and other file-system plug-ins), and the icon code with *Simple icons in archives* no longer overflows on a name just under that bound; every name these plug-ins list today keeps working.
  - **Limitation:** only the first member left out is named in the message. Such a name in a cpio or rpm archive (opened by the same TAR plug-in) no longer crashes but makes the whole archive refuse to open with "Internal error: file data structure corrupted."; from another plug-in it makes that plug-in report its own "could not add" error (some leave just that entry out, some stop the listing) - no such names occur on real Linux or Windows file systems.

- **Adding files to a ZIP archive, or deleting from it, while another program held it open left a stray "Sal....tmp" file - and in rarer cases lost the archive while saying "Archive was not changed"** (feature 320).
  - **Before:** the ZIP plug-in deleted the archive and renamed its temporary working file to the archive's name. When another program (an indexer, a viewer, another archiver) held the archive open, the message "Cannot replace original archive with temporary working file. Archive was not changed." was true, but a "Sal....tmp" file was left next to the archive every time. When instead the new temporary file was held (an antivirus scanning it), the archive was deleted, the rename failed, and the archive was gone - under the same "not changed" message.
  - **Now:** the new archive takes the old one's place in a single step. If that cannot be done, the archive stays exactly as it was, the temporary file is removed, and the message is true. A changed archive keeps its own attributes, permissions and the "downloaded from the internet" mark; "Set zip file time to the newest file time" still applies.
  - **Limitation:** an archive reached through a symbolic link can no longer be changed this way - the message is shown and nothing changes (before, the link was replaced by a plain file). A temporary file held by another program cannot be deleted and may remain. If the archive vanished during the operation, its new content is kept in the temporary file, which the message names but does not describe as the only copy.

- **Pack hid the archive in a hidden part of a file when its name held a colon - no archive could be found** (feature 319).
  - **Before:** an archive name typed in the Pack dialog (Alt+F5) with a colon in it ("report:zip", "rep:x.zip") created an empty file "report" (or "rep") and wrote the archive into a hidden part of it (an NTFS "alternate data stream"), which Explorer and the panel do not show. With a file "report" already there, the archive was attached to it in the same hidden way; adding to such a hidden archive failed with "Archive was not changed." yet changed it and left a temporary file behind.
  - **Now:** a name with a colon in its last part is refused with "The path specified is invalid." and the dialog opens again; nothing is created or changed, also when the file or the hidden part already exists, and also with "Use the other panel for packing". A drive letter ("C:\archives\report.zip", "C:report.zip") and the full-width colon "：" work as before.
  - **Limitation:** the message does not say that the colon is the problem. A colon in a folder part of the name ("sub:x\a.zip") is left to the packer, which refuses it (nothing is created).

- **Pack created an archive whose name ended in a dot or a space - a file other programs could not open or delete** (feature 318).
  - **Before:** an archive name typed in the Pack dialog (Alt+F5) that ended in a dot or a space ("report.", "report.zip ") was created exactly so; Explorer and most programs could not open, rename or delete such a file. A name like a Windows device ("CON.zip", "con", "NUL .zip", "COM1.zip") was created too.
  - **Now:** such a name is refused with "The path specified is invalid." and the dialog opens again; nothing is written. An archive that already exists under such a name can still be added to or overwritten. Names with dots or spaces inside or at the start ("report.v1.zip", " report.zip") and names that only begin like a device ("CONSOLE.zip", "COM10.zip") work as before.
  - **Limitation:** the message does not say which part of the name is the problem. A colon in the name still put the archive into a hidden part of a file - fixed by feature 319 above.

- **Pack dropped a leading space of the archive name - the items went into a differently named archive** (feature 317).
  - **Before:** packing (Alt+F5) a file or folder whose name starts with a space (" report") offered the archive " report.zip", but OK packed into "report.zip" - another archive; when "report.zip" already existed, the "add or overwrite?" question was about it, and Add or Overwrite changed it. A typed archive name starting with a space lost the space the same way.
  - **Now:** the archive name keeps its leading spaces: " report.zip" is created, or - when it exists - the question names it and Add or Overwrite work on it; an existing "report.zip" is not touched. A name made only of spaces and dots (" ..", " .") is refused with "The path specified is invalid." and the dialog opens again. Names without a leading space work as before.
  - **Limitation:** an entry of spaces only gets the extension and keeps its spaces ("   .zip"). A name ending in a dot or a space was still created as typed - fixed by feature 318 above.

- **Unpack into a subfolder named after the archive dropped a leading space - the files went into a differently named folder** (feature 316).
  - **Before:** with "Use the archive name as a subfolder", an archive whose name starts with a space (" report.zip") was offered the subfolder " report", but OK unpacked into "report" - another folder, merged with it when it already existed (overwrite questions were still asked), even when " report" itself existed. A typed target starting with a space lost the space the same way.
  - **Now:** the target keeps its leading spaces: an existing folder of that name receives the files; a new one is refused with "Error Creating Directory" and the dialog opens again - as for the same folder given with its full path. Targets without a leading space work as before.
  - **Limitation:** the program does not create a folder whose name starts with a space, so the offered subfolder of such an archive has to be edited (or the folder created first). The Pack dialog had the same defect - fixed by feature 317 above.

- **Unpack offered the other panel's long folder path shortened - one Enter unpacked into another, newly created folder** (feature 315).
  - **Before:** when the other panel showed a folder whose path is longer than 259 bytes (about 260 characters, or 87 Chinese or Japanese letters), the Unpack dialog (Alt+F9) offered that path cut short - with Chinese or Japanese letters sometimes as unreadable text. The cut path was accepted, so with "Use the other panel for unpacking" a single Enter unpacked the files into a new folder named after the cut path, nothing asked. With "Use the archive name as a subfolder" a path that had no room for the subfolder was offered without it, and the files went straight into the other panel's folder. An empty target in such a long folder unpacked into a cut folder too.
  - **Now:** a path that does not fit is not offered (the dialog offers what it offers when the other panel is not a folder on a disk); with the subfolder setting the archive's name alone is offered - a subfolder next to the archive. An empty target in a folder that is too long - or, with the subfolder setting, an archive name that is too long for a folder name - is refused with "The path specified is too long." and the dialog opens again. Paths that fit are offered as before.
  - **Limitation:** with "Use the other panel for unpacking" and a long other panel, Enter now unpacks next to the archive (overwrite questions are still asked); to unpack elsewhere, type a path that fits. A plug-in's own unpack mask that is too long is replaced by `*.*`.

- **The Markdown Viewer kept the text in a narrow column - a wider window only added empty margins, and wide tables and code scrolled inside the column** (feature 314).
  - **Before:** a document was always shown in a centred column of a fixed width (46rem, about 736 pixels at 100 %, 80-90 characters a line), whatever the window size; zoom made the text and the column larger together, so it did not help.
  - **Now:** View > Page Width chooses the column: *Normal* (as before, the default), *Wide* (64rem), *Wider* (90rem) or *Full Window* (no limit, the margins stay). The choice applies at once to the open document - also in View Source - and is remembered for the next documents and after a restart. Tables, code blocks and images use the chosen width, so in *Full Window* a wide table needs no scroll bar when the window is wide enough. A user who changes nothing sees the same page as before.
  - **Limitation:** like a color-scheme change, choosing a width shows the document again from the top. A width chosen in one viewer window does not change other open viewer windows.

- **Quick search did not find names with accents when the text was typed without them - "zlut" did not find "žluťoučký"** (feature 313).
  - **Before:** the new quick search (feature 244 below) ignored case but not accents: typing "zlut" showed "zlutý" but not the folder "žluťoučký", "cesky" never reached "Český", and typing "žlut" did not find "zlutý". The quick way of typing, without accents, and every keyboard without the language's letters found nothing.
  - **Now:** accents are ignored in both directions - "zlut" and "žlut" find both names, "cesky" finds "Český", "ubersicht" finds "Übersicht", also in names stored with separate accent marks. "ł", "ø", "đ", "ß", "æ", "œ" and "ı" are found by "l", "o", "d", "ss", "ae", "oe" and "i" ("lodz" finds "Łódź", "strasse" finds "Straße"). Folded letters can be typed one by one ("stras" already finds "Straße"); the cursor, Left, Right and Backspace work on whole letters of the name, and typing is as fast as before.
  - **Limitation:** only the accents of Latin, Greek and Cyrillic letters are ignored; marks that tell letters apart in other scripts (the Japanese voiced mark, Hebrew points, Indic signs) still count. Other letters ("ð", "þ", "ħ") are not folded. With *Quick search finds text anywhere in names* switched off, quick search keeps the earlier rule, which does not ignore accents.

- **Panel tabs: a Tabs page in Configuration, optional browser-like tab shortcuts, and Reopen Closed Tab** (feature 312).
  - **Before:** the tabs used Chrome's keys with Shift added (Ctrl+Shift+T new, Ctrl+Shift+W close, Ctrl+Shift+Page Down / Up next / previous), because the plain Ctrl+T, Ctrl+W and Ctrl+Page Down / Up keep their classic meanings; a tab closed by mistake was lost; *Show tabs in panels* was one checkbox on the Appearance page.
  - **Now:** Configuration has a **Tabs** page (after Appearance) with *Show tabs in panels*, the new option **Browser-like tab shortcuts** (off by default) and a list of the tab shortcuts that follows the option at once. With the option on and tabs on, Ctrl+T opens a tab, Ctrl+W closes it, Ctrl+Page Down / Up switch tabs, Ctrl+Shift+T reopens the tab closed last, Ctrl+Shift+W restores the selection and Ctrl+Shift+G goes to a shortcut's target - in the panel and in the command line; Ctrl+Shift+Page Down / Up and Ctrl+Tab stay. With the option off every key does what it did. **Reopen Closed Tab** (the *Tabs* submenus and a tab's context menu) brings back the last closed tabs of a panel one by one - up to 10, each with its folder, view, sort, filter, cursor, selection and history, at its old position; the list is kept in memory only and emptied by Clear History. *Tabs* is also under Options > Show and in the toolbars' context menu. Menu labels and tooltips show the keys of the chosen mode, and *Go to Shortcut or Link Target* is in the Commands menu at every skill level. A configuration from an earlier version opens the Configuration page it remembered.
  - **Limitation:** with the option on, Ctrl+Page Up / Down no longer go to the parent / into a folder (Backspace and Enter do). Ctrl+Shift+G can no longer be given to a plugin command; a plugin command that already has it keeps it, but the browser-like option takes it over. The real keyboard and the new page in the eight languages have not yet been checked by a person.

- **Find searched for a shortened "Containing" text and found files that do not contain the typed text; the internal viewer's Find did the same** (feature 311).
  - **Before:** the Containing field takes 200 characters, but the program keeps the text in 200 bytes. A longer text in bytes - 67 or more Chinese or Japanese letters, 101 or more accented letters - was shortened without a word, and Find searched for the shorter text in every mode (plain, regular expression, hex), listing files that do not hold what was typed. The shortened text was then written back into the field and its history, also by Options > Add Current, Manage and Ignore and when a stored option without a Containing text was chosen. The internal viewer's Find shortened its text the same way, and viewing a found file put the shortened Containing text into the viewer's Find.
  - **Now:** such a text is refused with "The path specified is too long." before anything is searched - in Find (also Find Duplicates and the refine commands), in Options > Add Current, Manage and Ignore, and in the viewer's Find - and the field keeps the whole text. A stored option without a Containing text keeps the field as typed. Viewing a found file leaves the viewer's Find text as it was when the Containing text is too long. Shorter texts work exactly as before.
  - **Limitation:** the message speaks of a path. Typing with a real keyboard has not yet been checked by a person. When the viewer's Find is opened over a selection of non-ASCII text, the selection is still shown in the wrong code page, and a long one is now refused; hex mode still turns quoted letters outside the system code page into `?` - both recorded for later.

- **Unpacking a cpio archive or an rpm package gave hard-linked files empty and left symbolic links out without a word - with "Delete archive after unpacking" the archive was deleted** (feature 310).
  - **Before:** cpio (and the payload of every rpm) stores a file with several names as one entry per name, with the data under only one of them - usually the last; the TAR plug-in wrote the other names as empty files. A symbolic link was skipped silently. Either way the unpack ended as successful, so "Delete archive after unpacking" deleted the archive with the content of those names.
  - **Now:** every name of a hard-linked file arrives with its content (as a copy, with the usual overwrite question) - in Unpack, in copying from the opened archive, also when only a name stored without the data is copied or viewed. A symbolic link is named in a message with its target, the rest is extracted, and the operation ends as failed, so the archive is kept - the rule feature 309 brought for tar.
  - **Limitation:** symbolic links are never created, so unpacking an rpm or cpio that holds them now ends as failed (the files are extracted the same). When the data is stored with an earlier name and only a later name is copied or viewed, that name is reported instead of shown. The panel still shows such names with size 0.

- **Unpacking a TAR archive left out files stored as hard links without a word - with "Delete archive after unpacking" the archive was deleted and those files were lost** (feature 309).
  - **Before:** GNU tar and Python store a second name of the same file (a hard link in the source tree - common in backups and package trees) as a link to the first one. The TAR plug-in skipped every link member, hard or symbolic, and the unpack still ended as successful, so the file arrived under its first name only, and "Delete archive after unpacking" deleted the archive with its other names.
  - **Now:** a hard link is extracted as a copy of the file it names when that file was extracted in the same operation (Unpack, or copying a folder out of the opened archive) - with the usual overwrite question; long and non-ASCII link names (GNU and PAX formats) are understood. A link that cannot be reproduced - a symbolic link, or a hard link to a file not extracted (outside the mask or selection, skipped, not in the archive) - is named in a message with the name it points to, the rest is extracted, and the operation ends as failed, so "Delete archive after unpacking" keeps the archive.
  - **Limitation:** symbolic links are never created, so a whole Unpack of an archive that holds them (most Linux tarballs and `.deb` packages) now shows one message and ends as failed where it used to look successful - the files are extracted the same. Link members are still not shown in the panel, so copying the files shown inside an archive folder leaves hard-linked names out (recorded for later); cpio and rpm archives: see feature 310 above.

- **TAR archives made by Python, by GNU tar in POSIX format or by Windows `tar.exe` showed long or non-ASCII names cut or as question marks - files were extracted into a wrong folder or not at all** (features 306, 308).
  - **Before:** such tools store a member's real path, size and time in an extended (PAX) header and leave only a substitute in the classic header: the name cut after 100 bytes, letters outside ASCII as `?`. The TAR plug-in skipped the extended headers, so it listed and extracted the substitute: a long path ended in a cut folder, a Chinese or Czech name failed with "invalid name", two members with the same substitute collided, a large member's size of 0 made the rest of the archive unreadable, and times were wrong.
  - **Now:** the plug-in reads the extended headers - a member's own and the global ones - and lists, views and extracts members under their real names, with their real size and time (to 100 ns). A member whose path no file system takes (a name over 255 characters) is left out with the message "The filename or extension is too long." and its path - never shortened; the rest is extracted, and the unpack then ends as failed, so "Delete archive after unpacking" keeps the archive. A member deeper than a panel listing holds (a folder path over 255 bytes - a deep source tree, `node_modules`) is not shown in the panel, with the same message on opening, but Unpack and copying its folder extract it. A damaged extended header refuses the archive with the plug-in's header error instead of listing wrong names.
  - **Limitation:** only the first member left out is named in the message. GNU sparse files keep their old handling (links: see feature 309 above); an archive cut off right after an extended header no longer opens. A GNU-format long name with a component over 255 characters still crashed the program on opening - fixed by feature 321.

- **A shortcut to a folder whose path has 260 or more characters opened its parent folder or failed - a file dropped onto it could land in the parent folder** (feature 305).
  - **Before:** for a shortcut (`.lnk`) pointing at a folder or file whose path has 260 or more characters on a drive without 8.3 short names, Windows answers the target cut after 259 characters, and the program used that path. Enter on the shortcut and Go to Shortcut Target showed "is invalid" / "Cannot obtain shortcut target" - or, when the cut fell on a backslash, silently opened the target's parent folder. A file dropped onto such a shortcut went to that other folder, and Browse on such a network location took the cut path.
  - **Now:** the program checks such an answer against the shortcut's own record of its target and uses the whole path, so Enter, Go to Shortcut Target and a drop reach the target itself; when the whole path cannot be proven, the shortcut is treated as one whose target cannot be read (Browse says "The path specified is too long.") - never a shortened path. Shorter targets work exactly as before.
  - **Limitation:** a shortcut on a mapped network drive whose target path has exactly 259 characters in its network form is now refused as well. A drop and Browse with such a shortcut have not yet been checked by a person; the Network plug-in (not shipped by default) still reads such targets cut - recorded for later.

- **PictView, UnCAB and Undelete: picking a network location whose target folder path has 260 or more characters could give a shortened path - another folder** (feature 304).
  - **Before:** the folder picker of these plug-ins follows a picked network location (a folder shortcut) to the folder it points at. On a drive without 8.3 short names, Windows answers such a long target cut after 259 characters, usually in the middle of a folder name, and the picker took that path - a folder that does not exist, or a parent folder of the target.
  - **Now:** the picker checks such an answer against the shortcut's own record of its target: it takes the whole path when that proves it, and otherwise refuses the pick with "The filename or extension is too long." - never a shortened path. Shorter targets work exactly as before. A whole path still has to fit the plug-in's own limit (PictView and Undelete refuse paths over 259 bytes, UnCAB's unpack over 256).
  - **Limitation:** checked with real shortcuts by the program's tests; picking one in the real dialog has not yet been checked by a person. The same cut in the main program (Enter or a drop on such a shortcut) is fixed by feature 305.

- **FTP: an upload of `B.txt` replaced the server's `b.txt` without asking, on servers that show Unix-style paths but ignore case** (feature 303).
  - **Before:** many FTP servers list their folders like a Unix server but store the files on a file system that ignores case - FileZilla Server and other servers running on Windows. Uploading `B.txt` (or `čaj.txt`) into a folder holding `b.txt` (or `Čaj.txt`) was sent without the "Target File Already Exists" question, because the names differ in case, and the server wrote the upload over its `b.txt`.
  - **Now:** a file or link in the target folder whose name differs from the uploaded file's name only in case counts as existing: the question appears (or the answer configured for existing files is applied), and nothing is sent until it is answered. Overwrite uploads the file as before; folders whose names differ only in case do not stop a file upload.
  - **Limitation:** the program cannot tell whether such a server ignores case, so on a server that does not (a real Unix server) the same question also appears for `B.txt` beside `b.txt`, and a configured automatic answer (skip, auto-rename, resume) is applied there too. Checks on real servers are recorded for a person.

- **A subst drive mapped to a folder with a long name in another script was handled through a path full of question marks - Delete did not recognise a junction on it** (feature 301).
  - **Before:** for a subst drive (`subst Z: <folder>`) whose folder path took more than 259 bytes as UTF-8 - for example a folder named by 80 Chinese or Japanese letters - the program asked Windows for the folder in the system code page, so every letter outside it became `?`, and used that wrong path. F8 on a junction of such a drive asked to delete a "directory" instead of the junction, Drive Information showed no drive type and no subst folder, and Copy UNC Path, the Change Drive menu and the bug report used the `?` text.
  - **Now:** the subst folder is read exactly, at any length. F8 names the junction, Drive Information shows "local drive (subst: <the whole folder>)" with its mount point and volume, and moves inside the drive are still renames on one volume. Where a folder does not fit (Copy UNC Path past 520 bytes, a line that cannot hold it) the program says the path is too long or shows no folder - never a shortened or `?` path.
  - **Limitation:** Copy UNC Path on such a drive has not yet been checked by a person (it needs the clipboard) - recorded for later.

- **Drive Information wrote a new volume label with accented letters garbled** (feature 300).
  - **Before:** a label typed in Drive Information was handed to Windows in the system code page, although the program held it as UTF-8: every letter outside ASCII arrived as two or three wrong letters - `Zálohy` became `ZĂˇlohy` on the drive.
  - **Now:** the label (and the drive's path) reach Windows exactly as typed. An unchanged label is still not written, a failed write still shows "Unable to change drive label." and keeps the dialog open.
  - **Limitation:** the label field still cannot hold letters outside the system code page - a label in another script is shown, and written back after an edit, with question marks - recorded for later.

- **Unpack (Alt+F9) shortened a long target path or file mask and unpacked into another folder or other files - with "Delete archive after unpacking" the archive could go with files never unpacked** (feature 299).
  - **Before:** in the Unpack dialog a target path or an "Unpack files" mask whose text was longer than 259 bytes (as UTF-8; a CJK letter takes three) was shortened silently and used. A long path unpacked the archive into another folder - a shorter path, possibly an existing folder of yours. A shortened mask unpacked other files than the ones named; when "Delete archive after unpacking" was checked, the archive was then deleted although the files the mask named had never been unpacked.
  - **Now:** OK refuses such a text with "The path specified is too long."; the dialog stays open with the whole text in the field, and nothing is created, unpacked or deleted. Text that fits works as before.
  - **Limitation:** when the other panel shows a path longer than 259 bytes, the dialog still offers that path shortened as a choice of the target field - recorded for later.

- **A single file mask longer than 259 bytes could crash the program, even at every start** (feature 298).
  - **Before:** a mask list (masks separated by `;`) holding one mask longer than 259 bytes overran the program's memory while it was being prepared. Such a mask cannot be typed into the usual fields, but it can come from the settings - a hand edit of the registry, a settings import, a plug-in's thumbnail masks, a tab's filter, saved search criteria - or from a plug-in. With a plug-in's thumbnail masks the program crashed at every start ("A problem has occurred") until the value was removed by hand.
  - **Now:** a mask of any length is prepared whole - never shortened, so it selects exactly the files it describes. Mask lists that worked before give exactly the same result.
  - **Limitation:** a mask list stored in the program is still limited to 1000 bytes in all, as before.

- **Registry Editor: deleting or moving a key that holds a registry link deleted the key the link points at** (feature 297).
  - **Before:** a registry link is a key made as a symbolic link, which any user can create in their own part of the registry. Deleting (F8) a key that held such a link, or the link itself, deleted the key the link pointed at - a key the user never selected, possibly anywhere in their registry - and left the link, so the selected key then could not be removed ("Unable to delete a registry key"). Moving it (F6, also drag and drop) or renaming the link (Quick Rename) first copied the linked key into the target as an ordinary key and then deleted it.
  - **Now:** Delete removes a link as the link itself, never what it points at; a link to a key that does not exist is removed too. A Move or Quick Rename refuses a link, before anything of it is copied, with "Unable to remove the original registry key. The request is not supported." (*Retry*, *Skip*, *Skip All*, *Cancel*); *Skip* leaves the link, and the key holding it, where they were. Keys that are no links are deleted and moved as before, and Copy (F5) still copies what a link points at as an ordinary key.
  - **Limitation:** the message does not say that the key is a link. A Move goes key by key, so what was moved before a refused link stays moved. A selected link that points at a missing key cannot be deleted by itself, only together with the key above it. Copy and Find through a link that points back into the copied tree repeat it until names get too long - recorded for later.

- **Registry Editor: moving a key into a key that holds a registry link to it could delete values without any question** (feature 296).
  - **Before:** when the target of a Copy or Move (F5 / F6, also drag and drop and Quick Rename) held, somewhere below it, a registry link - a key made as a symbolic link, which any user can create in their own part of the registry - pointing into the key being moved (or into the key above it, with the moved key holding the path back), the copy wrote through the link into the moved key itself and the Move then deleted it: those values were gone, with no box and no other copy. Copy wrote into the key it was copying from. A link pointing at a key that did not exist made the copy create keys inside the moved key - in the worst case dozens of copies of it inside itself.
  - **Now:** each key the copy is about to write is checked first. Through a link that leads into the moved key the key is refused, before anything of it is written, with "Name: <key> Error: Can't move a key to itself." (*OK* skips the key and a Move then keeps the original, *Cancel* stops). A link pointing at a key that does not exist is refused with "Unable to open a registry key." (*Retry*, *Skip*, *Skip All*, *Cancel*). A link to any other key is followed as before; keys that are not links behave as before.
  - **Limitation:** what was copied before the refused key stays in the target. The message is the existing "to itself" one and does not name the link. A link to a missing key elsewhere, which used to be created through, is now refused too. Deleting or moving a key that itself holds a registry link still deletes the key the link points at (fixed by feature 297).

- **A dialog's status text or the size field of a panel's path line could crash the program when memory ran out** (feature 295).
  - **Before:** when a text in a dialog - for example the file name or status in the progress dialog of a copy, move, delete or pack - had to show a text longer than any it had shown before and memory ran out half-way through making room for it, the text gave back memory it was still using; the next repaint, the next text or closing the dialog could crash the program or damage its memory. The free-space field of a panel's path line wrote into memory it had not got when memory ran out.
  - **Now:** the dialog text keeps showing its previous text and stays usable; the next longer text, once memory is available, is shown normally. Without memory the free-space field shows nothing and tries again at the next update. Nothing changes when memory is available.
  - **Limitation:** the low-memory case cannot be produced in the running program; it is checked by unit rules that make each step fail.

- **Registry Editor: moving a key into the key above its parent could delete a value without any question** (feature 294).
  - **Before:** when a key held a subkey of its own name - for example `A\K` holding `K`, which holds another `K` with a value - and that middle `K` was moved (F6) into `A\` (so into `A\K`, the key it came from), the copy wrote the innermost key onto the moved key itself and then deleted it: the innermost key's values were gone, with no box and no other copy. The same happened with the target written under another root name (`\HKEY_USERS\<your SID>\...`) and with a longer repeated chain (`A\K\M\K` holding `M\K`, moved into `A\`). Copy (F5) wrote into the key it was copying from.
  - **Now:** such a Copy or Move is refused for that key, before anything is written, with "Name: <key> Error: Can't move a key to itself." (*OK* skips the key, *Cancel* stops). Moving a key into the key above its parent when it does not hold that repeated chain still merges it as before.
  - **Limitation:** the message is the existing "to itself" one. A registry link inside the target pointing into the source is still followed by the copy (rare; fixed by feature 296).

- **The panel's path line or information line could crash the program when memory ran out** (feature 293).
  - **Before:** when the line above a panel (the path) or below it (the information line) had to show a text longer than any it had shown before and memory ran out half-way through making room for it, the line kept using memory it had already given back; the next repaint, the next text or closing the panel could crash the program or damage its memory.
  - **Now:** the line keeps showing its previous text and stays usable; the next longer text, once memory is available, is shown normally. Nothing changes when memory is available.
  - **Limitation:** the low-memory case cannot be produced in the running program; it is checked by unit rules that make each step fail. A dialog's status text and the size field of the path line have similar low-memory defects - recorded for later.

- **Registry Editor: moving a key onto itself under another root name deleted it** (feature 292).
  - **Before:** a key or value moved (F6) into the key that already holds it, written with another root name - `HKEY_CURRENT_USER\Software\X\Key` into `\HKEY_USERS\<your SID>\Software\X\`, or `HKEY_CURRENT_USER\Software\Classes\...` into the same key under `\HKEY_CLASSES_ROOT\` - was not recognised as a move onto itself. The overwrite question named two different paths, and after *All* (or *Yes*) the key with all its subkeys, or the value, was **deleted** - there was no other copy. Copy asked to overwrite instead of refusing, and a Move into one of the key's own subkeys under another root name filled it with copies of itself many levels deep.
  - **Now:** the Registry Editor compares what the registry itself says each key is, so every name of one key (`HKEY_USERS\<SID>` and `HKEY_CURRENT_USER`, `HKEY_CLASSES_ROOT` and its user and machine halves, `HKEY_CURRENT_CONFIG`, registry links) is the same key: such a Copy or Move is refused with the same message as under one root name ("Can't move key or value to itself." / "Can't move a key to itself."), and nothing is deleted. Other copies and moves behave as before.
  - **Limitation:** with `HKEY_CLASSES_ROOT` and one of its halves (or a key held by both halves) as source and target, values are refused even when they would reach the other half, and each key is decided on its own. The run-as-administrator case (moving into `HKEY_LOCAL_MACHINE\Software\Classes`) was checked without administrator rights only - recorded for a person.

- **A long Recycle Bin mask list, Find mask, viewer or compare mask was shortened silently; a long view name too** (feature 291).
  - **Before:** in Configuration > System, "Move following files to the Recycle Bin, delete others permanently", a mask list longer than the program holds (259 bytes - about 86 Chinese or Japanese letters) was cut and stored shorter; a mask dropped from the end no longer matched, so the files it named would have been **deleted permanently** instead of going to the Recycle Bin. In Find, such a "Named" mask was cut and the search found other files (`M*Q` searched as `M*`); Options > Add Current, Manage or Ignore, or choosing a stored option, also left the cut mask in the field. The viewer's text / hex mode masks and the Compare Directories ignore masks were stored cut, and renaming a view in Configuration > Views kept only the first 29 bytes of the name.
  - **Now:** each of these refuses the text with "The path specified is too long." and leaves it whole in the field; nothing shorter is searched for or stored. A view name that does not fit is refused and the view keeps its name. Text that fits behaves as before.
  - **Limitation:** a refused view name is not kept - press F2 and type a shorter one. A refused compare mask can sit in a field that is switched off (check its box to edit it). The Find dialog's "Containing" text, the target path and mask of Unpack with an external unpacker, the User Menu's names to compare and the Change Icon file name are still shortened; they are recorded for later.

- **Adding a file into a ZIP that holds names differing only in case could replace the other one** (feature 290).
  - **Before:** in a ZIP that holds, for example, `A.txt` and `a.txt`, or folders `D` and `d` (made in a case-sensitive folder, by WSL, or on Unix), copying or moving a file into it matched the existing files ignoring case. Copying `x.txt` into folder `d` asked to overwrite `D\x.txt` - a file in the other folder, not shown where you were - and *Yes* deleted it; adding `a.txt` asked twice and, after *Yes* to both, only the new `a.txt` was left, `A.txt` was gone. In a ZIP made on Unix the new file could replace `A.txt` instead of `a.txt`.
  - **Now:** in such an archive a file you add replaces only the file of exactly its name, after the usual question; the other one keeps its content. Archives without such names behave as before.
  - **Limitation:** in such an archive a name that differs from an existing one only in case (`B.txt` beside `b.txt`) is added as a second file without a question. An archive holding two names that Windows treats as different but the older comparison took for one (e.g. `ĥ.txt` and `Ĺ.txt`) is treated the same way.

- **A CD or USB drive named in another script showed as question marks in the Change Drive menu** (feature 289).
  - **Before:** the label of a CD / DVD and the name of a removable drive were asked of Windows in the system's code page, which turns every letter outside it into `?` before the program sees it - a disc labelled `Диск` on a Czech or English system showed as `????` in Alt+F1 / Alt+F2 and the drive bar tooltip. The same held for the type name of folders in the *Type* column ("File folder") when the Windows display language is outside the code page. The program's own words in the drive list ("Local Drive", "Network", "As Other Panel", the free space, …) and the type of the `..` entry were also code-page text where everything else is Unicode.
  - **Now:** these names and words come from Windows and the language file as Unicode and are shown exactly; a long name is never cut. Where they showed correctly before, they look the same.
  - **Limitation:** checked on fixed drives in English and Czech (the stored texts are Unicode, the display unchanged); a real CD, a USB stick and a display language outside the code page were not available - recorded for a person.

- **FTP: a new name reached an old (code-page) server garbled, and a name seen on one server was sent wrongly to another** (feature 288).
  - **Before:** on an older FTP server whose names are in the system's code page (not UTF-8), a folder you created, the new name of a rename or an uploaded file with letters outside ASCII (`nový`, `čaj.txt`) arrived as UTF-8 and the server stored a garbled name (`novĂ˝`). And a name the program had once seen in the code page on one server was sent in the code page to every server: after browsing an old server, deleting, renaming or downloading a file of the same name on a UTF-8 server failed with "550 No such file".
  - **Now:** the program learns each server's encoding (by its address, port and user name) from the names its listings show: a server whose listings show only code-page names gets new names in the code page; a UTF-8 server gets UTF-8; what one server showed no longer decides another. Names of UTF-8 servers and names taken from a listing go as before.
  - **Limitation:** until a listing shows a name with letters outside ASCII, a server is unknown and gets UTF-8 (a folder created or a path typed right after connecting to an old server still arrives garbled there; it stays reachable under that name later). One file with a code-page name on a UTF-8 server whose other names are plain ASCII makes the program take that server for an old one. The program does not ask the server (the FTP command `FEAT`) - that would be a new command sent to every server. A name the code page cannot hold exactly (e.g. Chinese, or `señor` in the Central European code page) still goes in UTF-8 - never as a look-alike such as `senor`, which would be another file. What was learned lasts until the program ends.

- **Registry Editor: copying or moving a key onto a key of the same name never warned that the class name would be lost** (feature 287).
  - **Before:** when the target already held a key of the same name with another *class name* (a rarely used attribute of a registry key), F5 / F6 merged the contents into it without a word - the target kept its own class name and, with Move, the source key was deleted. The warning "Class name of the key cannot be copied to the target key" was written for this case but compared the source key with itself, so it never appeared (in Open Salamander as well).
  - **Now:** the warning appears before that key's contents are copied, naming the key - for the copied key itself or for any subkey that meets such a key in the target: *Cancel* stops the operation, *Yes* continues as before, *All* stops asking for the rest of the operation. A Move stopped this way loses nothing: the key in question and the keys above it stay at the source (a key is deleted there only after it was moved whole). Copying into a key that has no key of that name, or one with the same class name, is unchanged.
  - **Limitation:** when the warning comes for a subkey, what was already copied above it stays in the target after *Cancel*. Windows cannot change the class name of an existing key, so the target keeps its own after *Yes*.

- **A folder picked in Browse For Folder could come back as another folder, and a long network location as itself** (feature 286).
  - **Before:** in the Browse For Folder dialog (Change Drive > Network, the browse of a Copy / Move target, Find, the User Menu, Configuration > Drives, plug-ins), a folder whose path is long in letters outside ASCII (more than 259 bytes in UTF-8, e.g. about 85 Chinese letters) came back in the system's code page - letters turned into `?` or look-alikes, another folder - and was taken without a word. A network location (a folder shortcut) whose target is that long was not followed: the location's own folder came back instead.
  - **Now:** both are refused with "The path specified is too long." and nothing is picked - the field or panel keeps what it had. Folders and network locations that fit come back whole, as before.
  - **Limitation:** such folders still cannot be picked there (the callers, plug-ins included, hold the result in 260 bytes); a folder of 260 or more characters cannot be selected in the dialog at all (Windows). The network-location case was checked by unit tests against real folder shortcuts; the dialog with a real network location is recorded for a person.

- **A server that wants a name and password before it lists its shares showed only "Access is denied"** (feature 285).
  - **Before:** `\\server\` in Change Directory (and, since feature 284, Backspace or *Go to root* in the root of a share) showed "Error: (5) Access is denied." when the server lists its shared folders only to a signed-in user, and stopped there - while a full path `\\server\share` in the same case offers Windows' sign-in dialog.
  - **Now:** the same Windows sign-in dialog appears; after you sign in, the server's shares are listed and you pick one. Cancel in the dialog leaves everything as it was; a failed sign-in shows the same message as for a full share path. The dialog is offered once: if the server still refuses the list after a sign-in, its error is shown. The program sees no name or password - Windows asks for them and keeps them only if you choose so in its dialog.
  - **Limitation:** checked with a test switch of the development build in place of Windows' dialog and of a refusing server (also with a server name in Chinese letters); Windows' real dialog on a real file server is recorded for a person.

- **Backspace and Go to root did nothing in the root of a network share** (feature 284).
  - **Before:** in `\\server\share` the panel listed no `..` entry, Backspace and the *Parent directory* command did nothing, and *Go to root* opened the same share root again - the way to another share of the same server was typing `\\server\` into Change Directory (feature 125).
  - **Now:** the root of a share lists `..`; it, Backspace, *Parent directory*, *Go to root* and *Open in other panel* on `..` show the server's shares under the directory line, as Change Directory does with `\\server\`: pick one to open it, Esc to stay. A server that refuses the list shows its error and the panel stays. Dropping files onto that `..` is refused, as nothing can be stored at `\\server\`. With a Network plug-in installed, its `net:` panel still opens instead.
  - **Limitation:** holding Backspace now ends at the share list instead of stopping at the share's root; a server that lists no folder share answers "A share name is missing in the path specified". Checked against this computer's own shares (`\\localhost`) with the list given by a test switch of the development build; a real file server, Esc in the wait window and dropping onto `..` are recorded for a person.

- **A file mask like `*.čtx` missed `A.ČTX`, and `*.ĥ` converted or selected `x.Ĺ`** (feature 283).
  - **Before:** a mask made of `*.` and an extension with accented letters compared the extension byte by byte through the system's code page. It missed the other case of an accented letter (`*.čtx` did not find `A.ČTX`, nor a name written with a separate accent mark), an exclusion like `|*.čtx` excluded nothing, and on some systems two different letters counted as one - with a Czech system locale `*.ĥ` matched `x.Ĺ`, and Convert rewrote that file. The same masks are used by Select / Unselect, the panel filter, Find, Copy / Move masks and the Recycle Bin masks (a file the mask missed was deleted permanently instead of being recycled).
  - **Now:** such a mask matches whole letters without regard to case, as every other mask with accented letters already did; masks made only of ASCII letters work exactly as before.
  - **Limitation:** a mask with an accented extension is matched a little more slowly than an ASCII one (noticeable only with long lists of such masks). Archive associations by extension still use the code page for accented extensions (the shipped ones are ASCII).

- **A file could be left renamed to "salNNN" without a word after a copy, a new folder or an unpack** (feature 281).
  - **Before:** when a new file or folder had a name that is only the short (8.3) name of another one - for example `LONGFI~1.TXT` next to `longfilename.txt` - the program moved the other one aside to a temporary name like `sal3F0`, created the new one and moved the other one back. When another program (a virus scanner, an indexer) held it at that moment, it stayed under the temporary name: copying a file or a folder (F5), Create Directory (F7), Edit New File and unpacking from an archive showed only the copy's own error, and nothing said where the other file was. PictView's and the Renamer's rename gave up on the first failed attempt to move it back.
  - **Now:** the move back is retried for about a second on every route, and when it still fails an "Error Renaming File" message shows the whole path of the `salNNN` entry and the reason - also after you cancel the copy, and for plug-ins that create files through the program (FTP, SFTP, the Renamer). Quick Rename's and F6's message shows a long path whole now too.
  - **Limitation:** the message names the temporary entry, not the file it was (open it to see); it is not shown while the program is closing (a shutdown, "Cancel all operations"). The failure itself needs another program to hold the file for that moment, so it was tested with a test switch of the development build; PictView's rename and FTP / SFTP were checked by reading.

- **A User Menu command could run on the parent of a panel's folder, or run for some selected files before refusing a long name** (feature 280).
  - **Before:** with a panel in a folder whose path has 260 or more bytes (in UTF-8; about 87 Chinese letters already), a User Menu command using `$(FullPathLeft)`, `$(FullPathRight)` or `$(FullPathInactive)` could get the folder's parent - another folder - or said that the variable is "not defined". A command run without a shell over several selected files ran for the files before the first one with a too long name, then refused it. `$(ListOfSelectedFullNames)` refused a list that fits as "too long", and a too long name to compare opened the compare dialog with an empty field and no reason.
  - **Now:** every value the User Menu inserts is whole, or the command is refused with "Cannot finish operation because of too long name." before anything runs; the list of selected full names holds long names whole. A command started without a shell that fails to start keeps the panel's selection, as before.
  - **Limitation:** files and folders whose full name has 260 or more bytes still cannot be used with the User Menu (refused). A command run without a shell now starts nothing when any selected file is refused while preparing (also on Cancel at a missing environment variable), as a command run through a shell always did. A list command is refused when the first selected file's full name is too long. The Find window's route was checked by reading (recorded for a person).

- **A folder uploaded again into an upload-only SFTP folder failed with "Cannot create directory"** (feature 279).
  - **Before:** in a server folder that accepts uploads but does not show its content (an "upload" right without "list", hosted drop boxes), a local folder that had been uploaded there before failed as a whole: "Cannot create directory ...: SFTP error 4: Failure", and none of its files were sent.
  - **Now:** its files are sent, each only if no file of that name is there (as for files uploaded alone into such a folder). When the server confirms nothing of the folder - an empty folder, a file of that name in the way, a folder that cannot be entered - one box names the folder and says that the server does not show whether it is there (or that it is not there), and a Move keeps the local folder; a Move removes a local folder only when something of it was confirmed to arrive.
  - **Limitation:** a file of the folder that the server refuses for want of a right still shows its own box (an upload-only service answers so for a file that is already there); checked against a test server modelling such a folder and against OpenSSH, not against a real upload-only service (recorded for a person).

- **The Registry Editor's Find with a regular expression could miss text at the end of a name or value with accented letters** (feature 278).
  - **Before:** on Windows set to use UTF-8 for the system (the "Beta: Use Unicode UTF-8" option) or to a Chinese, Japanese or Korean system locale, a regular expression searched only part of a key name, value name or text value that contained letters taking more than one byte - for example, `bar` did not find `čččč bar` - or searched leftover bytes of an earlier text in its place. Other system locales (such as Czech or Western European) were not affected.
  - **Now:** the whole text is searched; a text that cannot be converted for the search is skipped instead of being searched as leftover bytes.
  - **Limitation:** checked by tests with each code page; the Find window itself was tried only with a Czech system locale (a check with the UTF-8 option is recorded for a person). Viewing (F3) such a text value can still show it cut on those systems (recorded for a later fix).

- **Copying an FTP folder whose server path is very long could download another folder's files under its name** (feature 277).
  - **Before:** when the server reported a folder's path longer than 300 bytes - in the form German AIX servers use (`257 '/path' ist das aktuelle Verzeichnis.`), or from an older server with accented folder names whose path grows longer in UTF-8 - the FTP plug-in cut the path and took the cut one, an ancestor folder, as the folder it was in. Such a path appears, for example, for a link to a deeply nested folder. After a reconnect, copying the folder downloaded the ancestor's files under the deep folder's name. A path of exactly 300 bytes in the usual form was refused, although it fits.
  - **Now:** a path that does not fit is refused with "Error Getting Working Path On Server", as the usual form already was, and nothing is read from or written to another folder; a path of exactly 300 bytes is accepted. Also: the Create Directory report to the upload's folder cache, AS/400 member names used as download names and the upload's size estimate of a linked file no longer work on a cut name or path, and the lock that keeps two operations off one server file now compares file names by the Windows rule (`Č.txt` and `č.txt` are one file on a case-insensitive server).
  - **Limitation:** server paths longer than 300 bytes are still not supported (refused). The AS/400, OS/2 and VMS parts were checked by reading only. Folder names on case-insensitive servers are still compared by the code-page rule (recorded for a later fix).

- **Moving the cursor onto a file with a very long name showed "Expanded string is too large."** (feature 276).
  - **Before:** when the cursor landed on an archive file with a long name - for example 200 Chinese letters - an error box "Expanded string is too large." appeared (sometimes twice), and the information line below the panel kept describing the previous file. The same happened on disks that do not keep short (8.3) names. The information line names the file twice by default (its name and its short name, which is the name itself when there is no short one), and the text did not fit.
  - **Now:** no box appears; the information line describes the file - its name, size, date, time and attributes - whatever the length of its name. A malformed Information Line content (Configuration) still reports its error once.
  - **Limitation:** an Information Line content with very large widths (such as many `$(FileSize:9999)`) can still be too large and reports it as before. A plug-in that fills the information line itself keeps its own limit.

- **Viewing or editing an archive file whose path inside the archive is long still said "resulting filename is too long"** (feature 275).
  - **Before:** F3 (View) and F4 (Edit) refused a file whose folders and name inside the archive took 520 bytes or more - for example a name of about 172 or more Chinese letters at the top of the archive, or a shorter one inside folders with long names - although its temporary copy would fit. F5 (Copy) extracted such files.
  - **Now:** F3 and F4 open such files with ZIP, 7-Zip and TAR archives (and the other archive types the program ships), and an edited file goes back under its whole path, which the Archive Update list shows whole. The only length limit left is the temporary copy's: a name too long for the temporary folder is refused as before. The CAB plug-in refuses a path that does not fit its buffer with a message instead of cutting it (no real cabinet holds such a path).
  - **Limitation:** *Copy Selected To...* in the Archive Update dialog refuses an edited file whose target path would be longer than 259 characters (Update All works). Editing was tried with ZIP and 7-Zip archives; ISO images and CAB archives were checked by reading only.

- **Create Directory (F7) refused a new folder's name in a deep folder with "The path specified is too long."** (feature 274).
  - **Before:** a name typed without a path was refused whenever the folder's path and the name together reached 260 bytes - in a deep folder, or for a long name in letters that take three bytes each (for example a Chinese name of 87 or more letters, even in a short folder). Typing the full path worked. A name longer than any file system takes got the same message, which blamed the path.
  - **Now:** the folder is created from a typed name up to the program's path limit (as Edit New File, feature 259); a name longer than 255 characters is refused with "Cannot finish operation because of too long name." before anything is created, and a path over the program's limit with "The path specified is too long."; the dialog comes back with the text.
  - **Limitation:** a new folder whose name is 260 bytes or longer is created but not selected afterwards.

- **Copying from a TAR folder opened by a path typed in another case copied nothing** (feature 273).
  - **Before:** a folder inside an archive can be opened by typing its path - on the command line, in Change Directory (Shift+F7) or from a hot path - also in another case than the archive spells it, for example `archive.tar\DOCS` for the folder "Docs". The panel listed the folder but kept the typed spelling, and in a TAR archive (also .tgz, .tbz and the other formats of the TAR plug-in) Copy (F5) of its files then extracted nothing: the target stayed empty and no error was shown. 7z archives copied the files.
  - **Now:** the panel enters the folder under the archive's own spelling (the directory line shows `archive.tar\Docs`), and copying its files extracts them in every archive format. Archives that hold names differing only in case, and folders entered by Enter, behave as before.
  - **Limitation:** in an archive that holds names differing only in case in some other folder, a path typed in another case still opens the archive's root instead of the folder; copying files from disk into an archive by typing the target as `archive.7z\DOCS` may still create a second folder "DOCS" beside "Docs" (suspected, not yet measured). Both are recorded for a later fix.

- **Changing the attributes of a file symbolic link compressed or re-dated the file it points to** (feature 272).
  - **Before:** *Change Attributes* on a file symbolic link (also through a selected folder with "Include subdirectories" holding such a link, and the Compress / Uncompress commands) set the compression and the dates of the file the link points to - also a file outside the selection - not of the link. The link kept its own state. Encrypt / Decrypt would have encrypted or decrypted that file too. Feature 253 had fixed this for junctions and directory links only.
  - **Now:** compression and dates change on the link itself; the file it points to keeps its own. Encrypting or decrypting a file link is refused with "Error Changing Encryption" (Skip goes on with the other items), as for a junction. Plain files, cloud placeholder files (OneDrive and similar) and other special files that are not links work as before.
  - **Limitation:** the refusal of encryption has not yet been tried on a real machine with file encryption set up.

- **In a ZIP archive holding names that differ only in case, deleting or copying one of them could also take the other** (feature 271).
  - **Before:** a ZIP made on Windows from a case-sensitive folder (for example by WSL or a .NET program) can hold both "a.txt" and "A.txt", or folders "D" and "d". The program showed "D" and "d" as one folder, so copying or deleting it took both; Hide Selected Names on one twin hid both, and Store / Restore Selection of one twin selected both. In a ZIP made on Linux or macOS, which already showed the two folders apart, copying only folder "d" also extracted the files of "D", and **deleting only folder "d" also deleted the files of "D"** from the archive.
  - **Now:** a ZIP that holds such names shows them apart, like a ZIP made on Linux: each twin is selected, hidden, copied and deleted alone, and folders "D" and "d" stay two folders, each copied or deleted with only its own files - also in ZIPs made on Linux or macOS. A ZIP without such names behaves as before (for example, a folder can still be opened by typing its name in another case).
  - **Limitation:** adding a file into such a ZIP still takes the twins for one name: adding "a.txt" asks whether to overwrite "A.txt" too, and adding into folder "d" asks to overwrite a file of the same name in "D" - answering Yes replaces that other file (recorded for a later fix). Pasting a twin from such a ZIP through the clipboard has been checked by reading only; a person has not yet tried it.

- **A long Select, Unselect or Convert mask, a long filter, volume label or hot path name typed in place was shortened silently and used** (feature 270).
  - **Before:** these fields hold up to 259 characters, but the program keeps their text in a buffer of 260 bytes, and letters such as Chinese take three bytes each. Text that fitted the field but not the buffer was cut at a whole letter without a word: a Select or Unselect mask of 87 or more Chinese letters selected other files (which a following Delete or Move then acted on); Convert converted files the typed mask does not match; Change Filter stored a shorter filter, also with "Don't use filter"; Drive Information tried to write a shorter volume label; renaming a hot path in place (F2 in Configuration > Hot Paths) stored a shorter name, and a second F2 on the row started from the shortened text.
  - **Now:** each of these refuses such text with "The path specified is too long." and keeps the dialog open with the whole text in the field; nothing is selected, converted, stored or written. A hot path renamed in place keeps the whole name until OK, which then refuses it with the hot path selected and its name shown whole (as for a name typed into the Name field). Text that fits behaves as before.
  - **Limitation:** other mask fields still shorten such text - the Recycle Bin masks of Configuration > System, the Find dialog's "Named" field, the viewer's text and hex masks and the compare ignore masks (recorded for a later fix; the Recycle Bin case can delete such files permanently instead of moving them to the Recycle Bin). A volume label with letters outside the system's code page is still written in the code page (recorded for a later fix).

- **The FTP client showed and downloaded a file name with an unpaired surrogate under another name, and uploading such a file again overwrote the server's copy without asking** (feature 269).
  - **Before:** Windows allows a file name with an unpaired UTF-16 surrogate (made by some programs; such names cannot be typed). Uploaded to an FTP server that keeps names in UTF-8 byte for byte (a typical Linux server), the name arrived intact, but the next listing read it in the system's code page: the panel showed another name ("a" + 3 other letters + ".txt" on a Czech Windows), a download created a local file of that other name, and uploading the same file again did not see the server's file - with the default "ask" setting there was no "Target File Already Exists" question and the server's file was overwritten.
  - **Now:** such a name is listed as it is: the panel shows it, a download creates the file under the same name (also for a folder), and an upload or download over a file of the same name asks first. Names in UTF-8 and names of older servers in the code page are read as before.
  - **Limitation:** on an older server that sends names in the code page, a name whose bytes happen to look like such a surrogate (in the Czech code page "í" followed by a no-break space and "€", for example; very rare) is now listed as a surrogate name, and uploading a local file of its real name creates a second file next to it instead of asking (nothing is overwritten).

- **A damaged entry in the viewers, editors or User Menu configuration erased every entry after it** (feature 268).
  - **Before:** at start-up the program read the lists of viewers, alternative viewers, editors and User Menu items only up to the first damaged entry - one with a required value missing or of the wrong type, for example after a hand edit of the registry or an imported .reg file. The entries after it were not offered, and when the program was closed it saved the lists as it had read them, so those entries were gone for good - without a word (a value of the wrong type showed one "Error Loading Configuration" box). A damaged first entry cost the whole list.
  - **Now:** the damaged entry is left out and every entry after it is loaded and saved. In the User Menu, a damaged item that began a submenu is left out together with that submenu's end, so the items inside move one level up; a damaged submenu end is replaced by a plain one, so the submenu still closes where it did. Lists without damage load exactly as before.
  - **Limitation:** the damaged entry itself is not kept. Each value of the wrong type still shows its own "Error Loading Configuration" box at start-up. A gap in the numbering of the entries still ends a list there. The settings import (Import Settings from Salamander) still stops at a damaged entry of these lists in the source configuration (recorded for a later change).

- **PictView never turned photos taken with the camera held upright, and its Exif information command never opened** (feature 267).
  - **Before:** a phone or camera photo taken upright is stored sideways with an orientation tag in its Exif block. PictView showed every such photo lying on its side, although its setting "Autorotate EXIF JPEG images (digital camera pictures)" (on by default) promised to turn it. File > Exif information (also in the viewer's right-click menu) stayed unavailable for every picture. Both had been switched off by mistake since the viewer got its built-in image engine.
  - **Now:** with that setting on, a JPEG photo is shown the way its orientation tag says - turned by a quarter or half, or mirrored, for all eight values of the tag, also when its name has letters outside the system's code page. File > Exif information is available for a JPEG with an Exif block and lists its tags (camera, date, exposure, orientation...); for a picture without Exif it stays unavailable. A photo is now turned by its tag even when the picture size recorded in the tag differs from the picture (PictView used to make an exception there, which showed many correctly tagged photos wrong). Update Thumbnail behaves as before.
  - **Limitation:** only JPEG files: TIFF and camera raw files are still shown as stored and get no Exif command (recorded for a later change). Whether the menu item looks enabled or grayed has been checked through the command only; a person has not yet looked at the menu.

- **Closing the File Comparator while it was still comparing two binary files could show a stray "cannot access the file" box** (feature 266).
  - **Before:** when the comparator's window was closed while a comparison in the hex view was still running, a file error the view had just reported (and not yet shown) could appear as an error box with Retry / Cancel over the closing window, and Cancel then asked whether to close the comparison - although the window was already going away. The timing was narrow.
  - **Now:** once the window has begun to close, such a pending error shows no box and the window closes. Errors reported while the window stays open show their box as before.
  - **Limitation:** the narrow timing could not be reproduced on purpose; the fix was checked by reading the code and by an independent review. Exiting the program while a Disk Map shell command runs, and answering "force it to unload?" Yes, still ends the map's work at once, as in every release (no crash; a Delete confirmation still waiting keeps the file, but a confirmed Delete or Paste already in progress is cut off; recorded for a later decision).

- **A remembered network drive whose path has letters outside the system's code page, or a long path, could not be reconnected** (feature 264).
  - **Before:** a remembered (persistent) network drive that Windows did not reconnect at sign-in is shown disconnected in the Change Drive menu and on the drive bars. Picking it, or opening a folder on it, reconnected it with its remembered path converted to the system's code page and cut at 259 bytes. A path with Cyrillic or Chinese letters on a Czech or English Windows (every such letter became "?"), or a path longer than 259 bytes on a double-byte code page, was handed to Windows wrong: the drive stayed disconnected and the program said "The path or file name "Z:\" is invalid." Since 0.1.11 shows such a path exactly in the menu, the failure was easy to run into.
  - **Now:** the drive is reconnected to exactly the path Windows remembers, whatever letters it holds and up to the longest path Windows accepts for a connection (259 characters). The saved user name and network provider are used as before, the "trying to reconnect, press Esc" window still lets a slow reconnection be cancelled, refused credentials still bring Windows' password dialog, and an unreachable server still reports Windows' own error (for example "The network path was not found"). Drives with ordinary paths reconnect as before.
  - **Limitation:** the password dialog, Esc and a saved user name of another account have been checked by reading only; a person has not yet tried them with a password-protected share. Logging in to a UNC path (\\server\share without a drive letter) whose share name has non-ASCII letters still goes through the code page (recorded for a later fix).

- **A configuration file imported at start-up could write and delete registry keys of other programs** (feature 263).
  - **Before:** at every start the program imports config.reg from its folder or from %APPDATA%\Tandem Commander, or the file given with `-C`. It wrote every key the file named - also keys of other programs or of HKEY_CLASSES_ROOT - and a line such as `[-HKEY_CURRENT_USER\Software\<other program>]` deleted another program's settings. When the file also held Tandem Commander's settings this happened without any message; a file without them was imported after the question "Do you want to import it anyway?".
  - **Now:** only Tandem Commander's own key (HKEY_CURRENT_USER\Software\Tandem Commander\0.1) may be written or deleted. A file that names any other key, or holds no Tandem Commander settings at all, is refused as a whole with "Unable to import the specified file. It is not a configuration file." before anything is written, and the question is no longer asked. Files exported by the program, and the settings backups of the settings import, import as before.
  - **Limitation:** the message does not say which line of the file caused the refusal (recorded for a later change), and a refused file is refused again at every start until it is corrected or removed. A configuration file that also sets something outside the program's key (for example file associations) is no longer applied at all.

- **The Code Viewer showed a DOS (CP852), ISO-8859-2 or other single-byte text in another code page with wrong letters, and offered no way to fix it** (feature 262).
  - **Before:** the Code Viewer (the default F3 viewer for source and text files) read a file without a byte order mark that is not UTF-8 or UTF-16 only in Windows' code page. A batch file written in DOS code page 852 on a Central European Windows showed "Pý˘lię §luśouźkě…" instead of "Příliš žluťoučký…". Its Encoding menu (F8) offered only UTF-8, UTF-8 with BOM, UTF-16 LE / BE and the system code page; the only way to read such a file was the built-in viewer.
  - **Now:** View > Encoding also lists every conversion table of the built-in viewer's Convert menu (ISO-8859-2, CP852, MAC CE, Kameničtí, KOI-8 and the others, in the same order). Choosing one shows the open file through it, as the built-in viewer does, and the status bar names the table. F8 / Shift+F8 step through the whole list. A table chosen from the menu is remembered, also after a restart, and used for the next file that is not UTF-8 or UTF-16; choosing *System code page* forgets it. Stepping with F8 changes only the open file. Until a table is chosen, files are read exactly as before.
  - **Limitation:** the Code Viewer does not recognize the code page by itself (the built-in viewer's *Auto-Select*) and has no separate *Set as default* command (recorded for a later change). A remembered table applies to every later single-byte file, including files in Windows' code page, until *System code page* is chosen again. On a Windows set to use UTF-8 for non-Unicode programs, the tables do not give readable text (the built-in viewer is limited the same way). The letters on screen have been checked by tests only; a person has not yet read them in the program.

- **In a folder that tells a.txt and A.txt apart, Compare Directories paired the wrong file, and the viewer's next / previous file, the User Menu's compare names and Ctrl+X could pick the other one** (feature 261).
  - **Before:** a case-sensitive folder (WSL, or one made case-sensitive with `fsutil`) can hold two files whose names differ only in case. Compare Directories paired a.txt on one side with A.txt on the other: both files of the pair could be marked although an identical A.txt existed, an identical file could be marked different, and two sub-folders holding other names (aB.txt / Ab.txt against ab.txt / AB.txt) were reported identical. After another program added a file to the folder, the viewer's next / previous file could start from the other twin (showing A.txt again, or skipping a.txt). The User Menu's second compare name and the ghosted "cut" mark in the other panel took the first name equal ignoring case.
  - **Now:** each of these takes the file with exactly the same name. Compare Directories pairs a.txt with a.txt; where a folder holds such twins, a name differing only in case is paired only when neither side has a twin of it. Without twins nothing changes: "Readme.txt" and "README.txt" are still one name.
  - **Limitation:** in ordinary folders, a pair differing only in case can still be missed when the folder also holds the same name with a soft hyphen or in a decomposed Unicode form (as before; recorded for a later fix). The Find window's next / previous file still takes the first name equal ignoring case. Ctrl+X and the User Menu have been checked by unit tests only; a person has not yet tried them in the program.

- **Viewing or editing an archive file with a long name said "resulting filename is too long", and a .gz file with a long stored name was extracted under a cut name** (feature 260).
  - **Before:** F3 (View) and F4 (Edit) of a file inside an archive whose name has about 70 or more Chinese or Japanese letters (or about 105 Cyrillic letters, with the usual Windows temporary folder) - a name Windows accepts - failed with "Unable to unpack file from archive to temporary directory because resulting filename is too long." The program limited its temporary copy to 259 bytes instead of what Windows allows. A .gz file stores the original file name; the program kept only its first 259 bytes, so such a file was listed and extracted under a shorter name, and a name cut inside a letter came out garbled.
  - **Now:** F3 and F4 work for such names (feature 275 removed the remaining limit of about 170 Chinese letters) and the edited file goes back into the archive under its whole name. The temporary copy's path may be as long as Windows allows (259 characters; an emoji counts as two). A .gz file's stored name is read whole; when it is longer than any file name Windows allows (255 characters), the file is refused with the system's "The filename or extension is too long." and nothing is extracted. Short names work as before.
  - **Limitation:** a name too long for the temporary folder is still refused with the same "too long" message (a path inside the archive of 520 bytes or more no longer is - feature 275). Plugins that ask the program for a temporary copy of their own files keep the old 259-byte limit. Folders with long names inside archives are still not listed (each archive type says so when it opens). Editing was tried with ZIP archives only.

- **Pasting a file with a long name into its own folder said "Cannot copy a file to itself.", and Edit New File refused paths of 260 bytes or more** (feature 259).
  - **Before:** when Paste (Ctrl+V) put a copy of a file or folder into the folder it came from and the copy's name ("name - Copy.txt") reached 260 bytes, the program dropped the name and reported "Cannot copy a file to itself." - also for names Windows accepts, such as 84 Chinese letters + ".txt". Edit New File (Shift+F4) refused with "The path specified is too long." every file whose full path was 260 bytes or longer: a short name in a deep folder, a typed long path, or a name of 100 Chinese letters. Pasting or dropping files into an archive or a plugin's file system could, on low memory, fall back to a name in the system's code page, and a source folder too long for the program was reported as a Unicode problem.
  - **Now:** the copy name is built whole. When it would be longer than Windows allows for a name (255 characters; an emoji counts as two), the "name is too long" question appears (Skip / Skip all / Focus / Cancel), and nothing is copied over its source. Edit New File creates files in folders of any length the program supports. A name longer than Windows allows gets "Cannot finish operation because of too long name." and the dialog returns with the text. Paste or drop into an archive or plugin file system never uses a code-page name: it does nothing when a name cannot be converted, and says "The path specified is too long." for a source folder that is too long.
  - **Limitation:** a name with a zero-padded number, such as "x (001).txt", is refused as too long at its first too-long copy name, even when a later numbered one would fit. A new file whose name is 260 bytes or longer is not selected in the panel after Edit New File. Pasting a long name has been checked by unit tests only; a person has not yet tried it in the program.

- **SFTP: uploading into an upload-only ("drop") folder always failed with "Permission denied"** (feature 258).
  - **Before:** on a server that lets an account create files in a folder but not look at them (an upload-only folder on SFTPGo or a hosted drop box), every Copy or Move into that folder failed with "Permission denied" before anything was sent: the program could not find out whether a file of that name was already there. The question before replacing a server file did not say what a replacement cannot keep. A temporary file `.tcpart-…` left when the connection was lost during an upload stayed on the server; nothing offered to remove it.
  - **Now:** a file is uploaded into such a folder when no file of that name is there; an existing file is never touched (the upload fails and says why). Where the server will not report the size of the uploaded file, its confirmation of every byte counts instead. A failed upload there removes its partial file where the server allows it, or says that one may remain. The overwrite question says that other hard links to the file keep the old content and that its ACL and extended attributes are not carried over. The next upload over the same connection offers to delete temporary files left by a lost connection. Uploads into ordinary folders work as before; a write-only folder on OpenSSH already worked.
  - **Limitation:** in such a folder an existing file is protected only by the server's "create only if new" rule; a server that ignores that rule lets the upload replace the file (its old content is lost; the new file is complete). A folder uploaded into such a folder a second time still fails with "Cannot create directory" (the server does not show that it is already there). Temporary files left before the program was closed, or by another computer, are not looked for. Hard links and ACLs are only stated, not kept (SFTP version 3 cannot report or set them). The drop folder was tried with a test server that behaves like one, not yet with SFTPGo or a hosted service.

- **The Registry Editor's Find could miss a whole word on the second line of a list, and searched other bytes for an accented letter in quotes of a HEX pattern** (feature 257).
  - **Before:** with "Regular expression" and "Whole words" checked, a word on the second or a later line of a multi-string value was judged by the letters of the first line: "foo bar" on the second line was not found for `bar`, while "xxbar" was. An empty regular expression with "Whole words" found nothing. In HEX mode, a letter inside `'...'` that takes more than one byte in the system's code page (every accented or non-Latin letter when Windows uses UTF-8 for non-Unicode programs, Japanese or Chinese letters on such systems) was searched as a zero byte.
  - **Now:** whole words are judged on their own line, an empty regular expression finds everything as an empty text does, and a quoted letter is searched as all its bytes in the code page - the same bytes a plain-text search uses. A pattern that becomes too long is refused as before. Searches without these options work as before.
  - **Limitation:** on systems that use UTF-8 or an East Asian code page for non-Unicode programs, a regular expression can still miss the end of a text with accented letters (recorded for a later fix). "Whole words" still counts only spaces, not punctuation, as word boundaries. The UTF-8 case has not yet been tried in the program by a person.

- **In a popup menu, typing the hot key of an item named in another alphabet could run another item, or nothing** (feature 256).
  - **Before:** a context menu, the User Menu or a plugin's menu took the typed key in the keyboard layout's code page. A hot key outside it (a Cyrillic letter on a Czech Windows, a Japanese letter typed through the IME) never matched, and a letter the code page could not hold ran the item whose hot key is "?". Shell extensions that draw their own menu items (TortoiseSVN) were never told which key was typed, so their hot keys did nothing. In the Find window, Alt + the hot key of a hidden option only opened the Options part when that hot key was an English letter or a digit.
  - **Now:** popup menus compare whole letters, so the item whose hot key was typed is chosen. Shell extensions get the typed letter and can select or run their item. The Find window also opens Options for an accented or non-Latin hot key. English hot keys and every other key work as before.
  - **Limitation:** a letter typed with the menu bar active before any menu opens (after F10) still goes through the code page. In the panel's background menu, in the New submenu and in the Find window's result menu, shell extensions still cannot answer a typed key (recorded for a later fix). Real keyboards, input methods and TortoiseSVN have not yet been tried by a person.

- **The Batch Renamer's regular expressions could refuse a rename, or replace the wrong letter, in names with accents or non-Latin letters** (feature 254).
  - **Before:** with "Regular expression" checked, `.`, a bracket class such as `[ž]` or `[^l]`, `\w`, `[[:alpha:]]` or an empty match could take only part of a letter. The rename was then refused with "(123) The filename, directory name, or volume label syntax is incorrect". `а\b` on "Жаба.txt" replaced the first "а" instead of the last ("ЖAба.txt"). `ž+` repeated only part of the letter, a look-behind stepped into the middle of one, and the escape `\xC5\xBD` did not match "Ž" when case-insensitive. The plain "Whole words" search treated an accent written as a separate character as the end of a word, so "Cafe" → "Tea" turned "Café" into "Teá". A case-insensitive search did not match the final sigma "ς" with "Σ".
  - **Now:** expressions work on whole letters: classes, `.`, `\w`, `\d`, `\s`, POSIX classes, `\b`, quantifiers, look-behind and empty matches. Accents written as separate characters and letters outside the Basic Multilingual Plane (rarer CJK characters, for example) count as parts of a word. Escapes such as `\xC5\xBD` or `\ž` give one whole letter, and a range such as `[à-ž]` covers the letters between. "ς" and "σ" are one letter when case-insensitive. The Search / Replace / New name histories no longer merge two entries that differ in a letter. Expressions and names made only of plain English letters work as before.
  - **Limitation:** a case-insensitive range compares the lower-case letters, so `[Ж-ж]` can match fewer letters than the same range case-sensitive. A letter whose upper and lower case differ in length (e.g. "İ") still matches only in its own case. An escape for half a letter (`\xC5` alone) never matches part of a letter. The look-behind `(?<=ab|ž)` is now refused as "not fixed width".

- **Changing the attributes of a junction compressed or re-dated the folder it points to** (feature 253).
  - **Before:** *Change Attributes* on a junction or a directory symbolic link (also through a selected folder with "Include subdirectories", and the Compress / Uncompress commands) set the compression and the dates of the folder the link points to, not of the link. The link kept its own state. Encrypt / Decrypt would have encrypted or decrypted that folder too.
  - **Now:** compression and dates change on the link itself; the folder it points to keeps its own. Encrypting or decrypting a link is refused with "Error Changing Encryption" (Skip goes on with the other items), because a link cannot be encrypted on its own. Plain folders and files work as before.
  - **Limitation:** the refusal of encryption has not yet been tried on a real machine with file encryption set up. (A file symbolic link passed compression and dates to its target file too - fixed by feature 272.)
- **In a 7z, RAR or TAR archive holding names that differ only in case, the other file could be copied** (feature 252).
  - **Before:** such archives (made on Linux, or from a case-sensitive Windows folder) were treated as if "a.txt" and "A.txt" were one name. Pasting a.txt could extract A.txt. Store / Restore Selection and Reselect selected both, and Hide Selected Names hid both. Folders "D" and "d" were shown as one folder, and copying it out of a TAR archive extracted only one of them, silently leaving the other's files behind. SFTP folders were treated the same way.
  - **Now:** an archive that holds such names tells them apart. Each twin is selected, hidden, copied and pasted on its own, and folders "D" and "d" are two folders whose files are all extracted. SFTP folders always tell them apart, as FTP folders do. Archives without such names work as before, including a path typed in another case.
  - **Limitation:** in such an archive, paths must be typed in their exact case. A ZIP made on Windows that holds such names is still treated the old way (recorded for a later fix).
- **A long name or command typed into a dialog could be shortened without a word, and the shorter one used** (feature 251).
  - **Before:** text that fitted the field but was too long for the program in UTF-8 (for example Chinese or Japanese letters, which take three bytes each) was cut at a whole letter. *Make File List* wrote its list into another file (the name cut, the extension lost) and dropped the end of a long line format. A command, its arguments or its initial folder in the *User Menu*, *Viewers* or *Editors* configuration was stored shorter, so another program or folder would be used. A hot path's path or name was stored as "?" characters, the *Drives* page's "If path is inaccessible go to" path was stored shorter, *Edit New*'s "Save as default" kept a shorter name, and the browse buttons beside these fields started from a shortened path.
  - **Now:** such text is refused with "The path specified is too long." The dialog stays open with the item and the field shown, and nothing is written, stored or browsed. Text that fits works as before, also when it fits exactly.
  - **Limitation:** the Select / Unselect and Convert masks, the filter, the volume label and the in-place rename of a hot path in its list still shorten such text (recorded for a later fix).
- **A damaged entry in the file highlighting list stopped the program from starting** (feature 250).
  - **Before:** if an entry of the panel item highlighting list (*Options → Configuration → Panels → Colors*) had no readable masks in the configuration (an edited registry, an imported `.reg` file), the start-up never ended: the program ran at full processor load without showing its window, or showed the same "Error Loading Configuration" message again and again.
  - **Now:** the damaged entry is left out and the program starts; the entries before and after it keep working. For a value of the wrong type or one too long, the message is shown once.
  - **Limitation:** the left-out entry is not kept: it is gone from the configuration after the program is closed.
- **Copying out of an archive could move your files from behind a link** (feature 249).
  - **Before:** when an archive was browsed through an external archiver (*Archive associations* → 7-Zip) and the archiver unpacked a folder of the archive as a junction or a directory symbolic link pointing elsewhere, copying files out of that folder (F5, drag & drop) silently moved the files of the folder the link pointed to into the target. The 7-Zip version tested (22.01) does not create such links itself, so it needed an archiver that does.
  - **Now:** the copy stops with an error before anything is moved, and the temporary folder is removed (the link itself only). Archives without such a link unpack as before.
  - **Limitation:** the error shows the system message ("System error: …: The object manager encountered a reparse point…") and the temporary path, not the folder in the archive.
- **The Desktop view's column headers were garbled on a non-English Windows** (feature 248, GitHub issue #13).
  - **Before:** in the Desktop view (the Folders plugin), the column names that come from Windows showed their accented letters as mojibake, e.g. "Typ poloĹľky" and "Datum zmÄ›ny" on a Czech Windows. The program's own headers and the texts in the rows were right.
  - **Now:** the headers read as Windows names them ("Typ položky", "Datum změny").
  - **Limitation:** column headers can show only the characters of the Windows code page. A letter it does not have (e.g. a Czech display language with a Western code page) shows as "?", not as a different letter; a name too long for the header is shortened at a whole character.
- **Quick search finds text anywhere in a name and shows only the matches**
  (feature 244).
  - **Finding:** typing in a panel found only names that start with the typed text. A folder such as "2024_chatbot" could not be found by typing "chat", unless one knew to type a leading "/". Now a name that contains the text anywhere matches. A name that starts with it still gets the cursor first, as before.
  - **Hiding:** while you type, the panel shows only the matching items. The arrows move among them, Enter opens one, and Esc (or deleting the whole text) shows everything again with the cursor where it was.
  - **Indication:** the searching panel is lightly tinted in its colour scheme (also in the Dark theme), and its directory line shows the text and the number of matches, for example "Search: chat (3 of 120)".
  - **Commands:** copy, move, delete, pack, select all and the other commands work only on the items that are shown. An item hidden by the search is never touched, and if it was selected it stays selected.
  - **When it ends:** the search now lasts until Esc, until the folder, tab or active panel changes, or until an operation creates or renames an item that does not match. Before, almost any command ended it.
  - **Previous behaviour:** to get it back, clear *Options → Configuration → Panels → Quick search finds text anywhere in names and shows only the matches*.
  - **Limitation:** where the match starts is not highlighted in the name; the cursor stands after its end.
- **Import settings from Altap Salamander and Open Salamander** (feature 245).
  - **Where:** *Options → Import Settings from Salamander*. At the first start of a new Tandem Commander configuration the program also offers it once, if it finds settings of Altap Salamander 2.5–4.0 or Open Salamander 5.0.
  - **What:** hot paths, FTP connections (bookmarks, proxy servers, server types, saved passwords), the user menu, shortcuts you gave to plugin commands, viewer and editor associations, saved searches and the search ignore list, histories, confirmations, panel, keyboard and general options, internal viewer settings, colours and highlighting, view templates, default directories of drives and the settings of the plugins Tandem Commander ships.
  - **Safe by default:** the old program's settings are only read, never changed. The wizard shows a preview before anything changes; with its defaults it only adds what is new and changes nothing you already have. Replacing a group, taking over options or adding viewer associations (they take files over from your row for all files) is off until you tick it, and every value it would change is listed (for a plugin's own settings the first 60 and a count) and must be allowed. A backup of your current settings is saved first, and the result says how to restore it.
  - **Never imported:** archiver settings (use *Archivers Autoconfiguration*), the plugin installation, the language, the theme, panel tabs, toolbar layouts and window positions — Tandem Commander's own plugins (SFTP, Markdown and code viewers) and file associations stay as they are. Plugins Tandem Commander does not include are named in the result.
  - **Passwords:** passwords the old program protected with a Master Password come over only if you type that Master Password; they are then protected like Tandem Commander's own, never with weaker protection unless you agree.
  - **Keyboard shortcuts:** shortcuts of Tandem Commander's own commands cannot be changed, so only the shortcuts you gave to plugin commands are imported.
  - **Removed:** the standalone script `utils/migrate-altap-settings.cmd` (0.1.3), which the wizard replaces; it replaced whole groups and could overwrite settings you had already made in Tandem Commander.
  - **For plugin authors:** plugin interface 108 adds `SetPluginSettingsImport`, through which a plugin merges its own settings from the old program; plugins built for 104–107 keep working.
- **Network drives show their Windows names, and their icon shows when they are disconnected** (feature 246; the same in Altap Salamander).
  - **Names:** a mapped network drive that you (or your administrator's policy) named in Explorer, e.g. "Archiv", was shown only by its path in the Change Drive menu (Alt+F1 / Alt+F2) and the drive bar tooltip. Both now show the name with the path: "Archiv (\\server\share\Storage)". A drive without a name looks exactly as before. Names and paths in any script are shown exactly, and a long one is no longer cut.
  - **Disconnected icon:** the drive bars kept the icon they had when they were built, so a remembered network drive that Windows could not reconnect (a red cross in Explorer) still looked connected there, and a reconnected one still looked disconnected. The drive bars now catch up when you return to the window, open the Change Drive menu or refresh; a drive whose connection Windows reports as unavailable or disconnected gets the disconnected icon also while its letter is still listed.
  - **Reconnecting:** picking a disconnected drive reconnects it with its path as Windows records it. A share whose name contains "&" could not be reconnected that way before.
  - **Limitation:** Windows does not report when a server stops answering, so a drive that loses its server while you keep working in Tandem Commander shows the change at the next of those moments; a state where Windows still lists the drive as connected while its server is off is shown as Windows reports it.

## [0.1.10] — 2026-10-17

**Build 194.** Fixes for the problems reported on GitHub after 0.1.9, and
for what checking those fixes found. Several ways of losing files are
closed: deleting a link in a very deep folder emptied the folder it points
to, a name that is another file's short name could overwrite that file, and
an archive opened through a drive letter that was pointed elsewhere could
be changed in place of another. Shortcuts open their targets, a server name
lists its shared folders, the program starts again on older Windows, and
messages, menus and the plug-ins show names in any language readably. Long
names are kept whole or refused, never cut; SFTP no longer fails about one
connection in 256.

- **Packing a folder that contains a folder with a very long name**
  (feature 241). Copying or moving it into an archive "succeeded" without
  packing anything and without a message. It now says the name is too
  long, and nothing is packed or moved.

- **Dragging a folder with a very long name into an archive** (feature 240)
  ended without a word; it now says the name is too long.

- **A folder whose name contains %...% opens as it is** (feature 238). A
  folder named, for example, "p%OS%q", given on the command line or typed
  into Change Directory, opened "pWindows_NTq" instead (the text between
  the percent signs was read as an environment variable). An existing
  folder now wins; a path that does not exist as typed is still expanded.

- **Menus: accented shortcut letters work in drop-down menus** (feature
  237). In menus such as the plug-in menus, a shortcut letter outside
  English (Č, Ř, ...) could not be typed, and a typed letter could select
  an item with another shortcut.

- **Menus: item names with letters outside English stay readable**
  (feature 236). An automatically added keyboard shortcut could be put
  inside such a letter in some menus (plug-ins, histories), which garbled
  the name. A name such as "R&D" no longer loses its shortcut.

- **Find window: the list of selected names from several folders**
  (feature 235). A User Menu command using the list of selected names, run
  on Find results from several folders, got bare names that pointed into
  the first folder. Such a list now holds full names.

- **User Menu from the Find window runs in each file's folder** (feature
  234). A User Menu command with a relative file name, started from Find
  results, ran in an unrelated folder (or, for files from several
  folders, all in the first one) - it could act on another file of the
  same name. Each command now runs in its file's folder.

- **Compare Directories: names that differ only in case are the same file
  again** (feature 232). "Readme.txt" on one side and "README.txt" on the
  other were both marked as different (since 0.1.0). A selection also
  survives again when another program changes only the case of a selected
  file's name.

- **Restoring a selection in a case-sensitive folder** (feature 231). In a
  folder that tells "a.txt" and "A.txt" apart (a WSL folder), Reselect,
  Restore Selection and Hide Selected Names also took the other file of
  the pair - the next command could act on a file nobody selected.

- **Dragging or pasting into an archive takes only the selected files**
  (feature 230). In a folder that tells "a.txt" and "A.txt" apart (a WSL
  folder), dragging or pasting "a.txt" into an archive also packed
  "A.txt" - with Move it was deleted - and could crash the program.

- **User Menu: names with %, ^, ! or & reach commands run through the
  command shell unchanged** (feature 229). A file named "50%off.txt",
  "a%OS%b.txt" or "a^b.txt" reached such a command under another name - it
  could act on another file; a name like "x&calc" inserted without quotes
  ran another command; a list of names split "Smith,John.txt" in two. The
  names now pass unchanged; a name that cannot (holding ^, or & | < >
  outside quotes) is refused with a message and nothing runs. The list
  variables now put names with , ; = & | < > ( ) ^ in quotes, and the
  command shell starts with delayed expansion off.

- **Dragging or pasting files into an archive from a deep folder**
  (feature 228). From a folder whose path is longer than about 260
  characters the program looked at a shortened path - an error, or another
  folder whose name starts the same, whose items' details were used for the
  dragged ones. It now reads the whole path.

- **User Menu: commands run through the command shell work with accented
  names** (feature 226). An item set to run through the command shell got
  file and folder names with letters outside English garbled, so it did
  not find the file (or found another one); a command with a relative name
  did not run in a panel folder with such letters; and when the item's
  initial folder did not exist, the command ran in the panel's folder
  instead. The names now reach the command unchanged (also Chinese or
  Japanese ones), the command runs in the panel's folder, and a missing
  initial folder stops it.

- **User Menu: a command is not run in a shortened folder** (feature 225).
  A User Menu command on the ".." item or in an empty panel whose folder
  path is very long ran in a shortened path - another folder. It is now
  refused with "name too long", as for other items.

- **FTP: files with accented names work on UTF-8 servers** (feature 224).
  Deleting, renaming or downloading a file such as "café.txt" on a server
  that uses UTF-8 failed ("No such file"): the name was sent in the
  Windows code page. Names now go in UTF-8 unless the server itself listed
  them in its old code page.

- **ISO images: long Rock Ridge names are kept, damaged images are safer**
  (feature 223). A file with a long Rock Ridge name (about 150 letters or
  more) was listed and extracted under a shortened name; it is now read
  whole. The ISO plug-in also checks the lengths an image declares
  before using them.

- **Archives with long file names open** (feature 222). A ZIP (or another
  archive) containing a file whose name has more than 255 bytes - for
  example about 86 Chinese or 128 Cyrillic letters, still a valid
  Windows name - could not be opened at all ("Cannot add file to the
  list."). Such files are now listed and can be extracted; an item that
  really is too long is skipped and the rest of the archive is shown.

- **A file briefly renamed to "salXXX" is renamed back reliably**
  (feature 221). When a rename or move collided with another file's short
  (8.3) name, that file was moved aside and back; if another program held
  it at that moment it silently stayed named "salXXX". The move back is
  now retried, and if it still fails you are told where the file is.

- **SFTP: viewing a file you may not read says so** (feature 220). F3 on
  a server file without read permission showed nothing at all; it now
  says "Permission denied". A connection whose server stopped answering
  is also released completely when it is closed.

- **Go to Shortcut Target works for a folder link stored with a "\\?\"
  target** (feature 219). A symbolic link whose target was written in the
  long form (`\\?\C:\...`) could not be followed ("The path specified is
  invalid"). Deleting deep folder links and deleting by Recycle Bin masks
  were checked and remove only the link.

- **A crash report stays complete after a stuck background task was
  stopped** (feature 218). When the program had to stop an unresponsive
  background thread (an icon reader or a path check), a crash report
  written later could lose its call stacks; the stopped thread is now
  removed from the report's list first.

- **SFTP: no more occasional "Unable to exchange encryption keys"**
  (feature 217). About one connection in 256 failed its key exchange
  with a valid server (a leading zero in the shared secret was encoded
  wrongly by the bundled SSH library), and a failed key exchange left
  memory behind. Both are fixed.

- **FTP: the encrypted connection's log lines are readable** (feature 216).
  The FTPS lines of the FTP log (the certificate, its issuer, the cipher,
  errors) lost their letters when the program's language differs from
  Windows' language; an OpenSSL error text also had a buffer smaller
  than OpenSSL requires.

- **FTP: long file names are no longer shortened** (feature 215). A name
  longer than 255 bytes (for example about 86 Chinese or 128 Cyrillic
  letters) was cut in the FTP panel: deleting or renaming it sent the
  shortened name to the server - another file, or none - and two long
  names starting alike looked like one. Such names are now kept whole;
  a download or upload of a name too long for the local side is refused
  with an error instead of being written under a shortened name.

- **Change Attributes, Change Case and Convert stay inside the selection**
  (feature 213). With "Include subdirectories", a junction or folder
  symbolic link inside the selected folder was followed: the files of
  the folder it points to got the new attributes, had their names'
  case changed, or were converted. Now only the link itself is changed.

- **The Copy, Move and Unpack dialogs never shorten what you typed**
  (feature 214). A target that did not fit was silently cut - with
  letters such as Chinese or Japanese ones a typed folder could be cut to
  its parent, and the files went there. Such a target is now refused with
  "The path specified is too long."

- **Cleaning up a temporary folder never deletes through a link** (feature
  212). When a temporary folder of the program (an archive unpacked for
  viewing, an external archiver's work folder, a plug-in's temporary
  folder) contained a junction or a folder symbolic link, the cleanup
  went through it and deleted the files of the folder it points to. Now
  only the link itself is removed.

- **Disk Map: the menu of a file never acts on its folder** (feature 211).
  For a file with a long name deep in the folder tree (its full path over
  about 780 characters), the map's context menu worked on the FOLDER the
  file is in - "Delete" offered to delete that whole folder permanently.
  Such an item has no menu now.

- **Renamer: search and replace never changes another letter** (feature
  210). With "Case sensitive" off, searching for "Ě" also replaced "Ċ" (and
  similar pairs of other letters) - the file got a wrong name; "Ž" did not
  find "ž"; "Whole words" missed words ending in a letter with an accent,
  and a cut such as $(OriginalName:0,1) split such a letter. They work on
  letters now.

- **Renamer: "Include subdirectories" after a rename shows the renamed
  folder's files** (feature 209). After renaming a folder to a full path
  or into a subfolder, ticking "Include subdirectories" failed with
  "Unable to read directory" - it looked for the folder in the wrong
  place, where another folder of that name could have been listed.

- **Renamer: changing the case of names with accents works** (feature 208).
  Lower, upper and mixed case and "remove diacritics" failed with "The file
  name is incorrect" (or changed only the plain letters) for names with
  letters such as "Č" or Chinese ones, and changing only the case of such a
  name asked to overwrite the file itself.

- **Renamer: long names and folders no longer crash it or reach other
  files** (feature 207). Undo, or "Remove source path", of a file whose
  full path has 260 or more bytes (for example a name of 90 Chinese
  letters) crashed the Renamer; in a folder with such a path it worked on
  names in the root of the drive instead. Both work or are refused now.

- **Renamer: a new name's folder is never another folder by its short name**
  (feature 206). With relative paths, a new name "LONGDI~1\x.txt" next to a
  folder "longdirname" (whose short 8.3 name is LONGDI~1) went into
  longdirname and offered to overwrite a file there - Yes replaced it; a
  folder with a very long name typed by its short name crashed the
  Renamer. The new name gets a folder of its own now.

- **FTP and SFTP downloads never write into another file by its short
  name** (feature 205). Downloading "LONGFI~1.TXT" over SFTP next to
  "longfilename.txt" (whose short 8.3 name it is) asked to overwrite and
  replaced that other file; a folder "LONGDI~1" went into "longdirname".
  The download is a file or folder of its own now, or - when the other one
  is open in another program - an error with the reason. The same for FTP.

- **An archive's folder is never unpacked into another folder by its short
  name** (feature 204). A member "LONGDI~1/a.txt" unpacked next to a folder
  "longdirname" (whose short 8.3 name is LONGDI~1) went into longdirname,
  and a member of the same name as a file there replaced it after one
  question. It gets a folder of its own now (ZIP, TAR, 7-Zip and the other
  archive plug-ins). An old archive that stored such short names unpacks
  beside the original folder instead of into it; a target typed with a
  short name still goes where it points.

- **Copying or unpacking to another file's short name never overwrites it**
  (feature 203). Copying "LONGFI~1.TXT" - the short (8.3) name of another
  file - into a folder where that file was open in another program asked
  to overwrite it, and unpacking such a member from an archive then
  replaced the other file's content; a copied folder "LONGDI~1" was merged
  into the other folder "longdirname". The error is reported now.

- **PictView's Rename to another file's short name never replaces it**
  (feature 202). Renaming the shown image to "LONGFI~1.PNG" - the short
  (8.3) name of another image - offered to overwrite that image and Yes
  replaced it; the shown image is renamed now and the other one kept.

- **Rename and Move to another file's short name never overwrite it**
  (feature 201). Renaming or moving a file to "LONGFI~1.TXT" - the short
  (8.3) name of another file - while that file was open in another program
  asked to overwrite the other file; it now reports the error instead.

- **PictView's Rename in a case-sensitive folder** (feature 200). Renaming
  the shown "a.png" to "A.png" while "A.png" is another file failed with
  "already exists"; PictView asks to overwrite it now.

- **Renamer no longer deletes a file whose short name is the new name**
  (feature 199). Renaming a file to "LONGFI~1.TXT" - the short (8.3) name of
  another file - offered to overwrite it and then deleted that other file;
  it is now kept (with a new short name), as in the main window's rename.

- **Changing only the case of a name never deletes the file on drives of
  other file systems** (feature 198). On a drive provided by a file system
  driver such as WinFsp or Dokan, which can give "a.txt" and "A.txt" of the
  same file two different file numbers, Quick Rename or Move from "a.txt" to
  "A.txt" could take the file for another one and delete it as the
  overwritten target. Another file is now recognised only when it is still
  there after the renamed file was moved aside under a temporary name.

- **Deleting a link in a very deep folder no longer deletes its target's
  files** (feature 197). With the Recycle Bin off, deleting a junction (or a
  folder containing one) whose path was longer than about 780 characters
  emptied the folder the junction points to. Only the link is removed now;
  *Go to Shortcut Target* also works for such links.

- **Renamer in a case-sensitive folder** (feature 196). Renaming "a.txt" to
  "A.txt" while "A.txt" is another file failed with "already exists"; the
  Renamer asks to overwrite it now.

- **Copying within a case-sensitive folder** (feature 195). In a folder that
  tells names apart by case, copying "a.txt" as "A.txt" (or a folder "d" as
  "D") was refused as a copy onto itself; it is copied now, and an existing
  "A.txt" that is another file is offered for overwriting.

- **Dropping files onto a shortcut works for long paths** (feature 194).
  A shortcut in a very deep folder, or one pointing to a folder with a long
  path, was not followed when files were dragged onto it.

- **Leaving the program while a server's share list is still being read
  frees what it held** (feature 193). After giving up waiting for a server
  that does not answer, the program left that request's memory behind at exit
  (a test build reported a memory leak).

- **Registry Editor's Find takes "0x" numbers** (feature 192). "0xff" now
  finds the value 255, as the help says; a hexadecimal number too big for 64
  bits no longer finds a smaller one, and an empty number value is no longer
  found by chance.

- **No crash in the Registry Editor's Find with long input** (feature 191).
  A long text in a time field, or a long quoted hex pattern, overran the
  stack; they are refused with a message now.

- **Registry Editor finds with regular expressions and in hex again**
  (feature 190). Such a search used an unset value; a test build stopped it
  with an error box.

- **Registry Editor shows text values to their end, and only to it**
  (feature 189). A multi-string value stored with one closing character showed
  a trailing space; in the Find window such a value, or a text with an odd
  length, was followed by stray characters, and a regular-expression search
  missed its last letter.

- **Dropbox and Google Drive folders are recognised under any account name**
  (feature 188). With an account name containing accented letters, the folder
  icons of Dropbox and Google Drive were not shown.

- **A too long server or share name says "too long"** (feature 187).
  Change Directory to a network path whose server or share name is longer
  than Windows allows said "A share name is missing" (or "A server name is
  missing") and offered the share list; it now says "The path specified is
  too long."

- **External archivers: messages show the whole command line and the
  right letters** (feature 186). "Command line too long" cut the command
  line, and from two routes overran a buffer; "Path to file too long"
  showed the path with wrong letters.

- **Messages cut to fit end at a whole letter** (feature 185). Nine
  messages (the Find log, a drive label, file associations, a temporary
  file) could end in a broken character when their text was too long. A
  link in a plug-in's message box is copied to the clipboard whole, and a
  User Menu environment variable with a name of 260 letters or more is no
  longer looked up under a shortened name - another variable.

- **External archivers never get another file's name** (feature 184). When
  unpacking or deleting through an external archiver, a file name longer
  than about 260 bytes was cut in the list of files handed to the archiver,
  which then worked on another file; the conversion for archivers that
  expect DOS letters could overrun a buffer. Such a name is now refused
  with "Path to file too long", and so is a drag & drop unpack target that
  does not fit.

- **No crash with very long paths in several messages** (feature 183). Copying
  from an archive into a very deep folder, and a few error messages that name
  a long path, could overrun a buffer.

- **No crash on a broken shortcut with a long name** (feature 182). *Go to
  Shortcut Target* on a damaged shortcut whose name was long (for example in
  Chinese) crashed the program.

- **Shortcuts in deep folders open** (feature 181). A shortcut in a folder with
  a long path (for example many accented letters) was refused as "too long" or
  "not a valid shortcut".

- **Error messages show the Windows text for more errors** (feature 180). Some
  errors (for example a file that is not a valid program) were reported as
  "System error 193, text description is not available." instead of their
  description.

- **PictView prints what its print preview shows** (feature 179). With *Scale
  to fit* a picture could be printed mirrored after a negative size had been
  typed, and a large print scale of a big picture printed a wrong size.

- **FTP: uploading a file with a long name shows its name whole** (feature
  178). The operation window's caption cut a local name of about 130
  accented letters or more, possibly inside a letter.

- **Packing over an existing archive keeps it when the packing fails**
  (feature 176). Choosing *Overwrite* deleted the existing archive before
  packing started; when packing then failed or was cancelled, the old archive
  was lost. It now stays until the new archive is complete.

- **Files > Convert keeps what the converted files had** (feature 175). The
  conversion deleted each file and put a new one in its place, so a file lost
  its permissions and additional data streams, and could be lost if the last
  step failed. It is now replaced in one step; Quick Rename onto an existing
  file likewise.

- **The exported configuration keeps every letter** (feature 174). Options >
  Export Configuration wrote letters outside the system's code page (Cyrillic
  folders, history, commands) as question marks, and a key or value with such
  a name made the export fail. The export is now a Unicode registry file, and
  importing it restores everything; files exported by older versions keep
  importing. A failed export no longer deletes the file it was meant to
  replace.

- **The viewer's Copy to File replaces a file safely** (feature 173). Copying
  onto an existing file deleted it first and then moved the new content in; if
  that move failed, the original was gone. The new content now takes the
  file's place in one step, and the file keeps its attributes.

- **Saving and opening files with accented names from the viewer** (feature
  172). The viewer's *Copy to File* refused every name with an accented letter
  ("The file name is incorrect") and suggested a garbled name; its *Open File*
  could not open such a file. Exporting the configuration under a name or into
  a folder with letters outside the system's code page (for example Cyrillic on
  a Czech Windows) failed, and the *Browse...* buttons of the configuration
  garbled such paths.

- **The program starts when installed in a folder with letters of another
  script** (feature 170). Installed under a folder whose name has a character
  outside the system's code page (for example a per-user install for a user
  named in Cyrillic or Chinese on a Czech or English Windows), the program did
  not start at all; its plug-ins would not have loaded either. The Add
  plug-in dialog takes such folders too. From such a folder the toolbar now
  shows its current icons instead of the old ones, the viewer and Convert find
  their conversion tables, and the Google Drive folder is found for the icon
  overlays (feature 171).

- **Change Case renames files with accented letters correctly** (feature 169).
  Changing the case of a name with letters outside English (Czech, Greek,
  Cyrillic, ...) failed with "The file name is incorrect" or renamed the file
  to a different, garbled name ("žluťoučký kůň.txt" became
  "żLUťOUďKý Kůň.TXT"). The panel's name format option showed such names
  garbled too.

- **Hardening of the shipped files** (feature 167): every program file built
  by the project uses Control Flow Guard, and `sqlite.dll` carries a version
  resource naming its origin.

- **The Markdown Viewer's settings are translated** (feature 166). Its
  configuration dialog was in English in every language.

- **ZIP archives with 65,535 files or more record their number correctly**
  (feature 165). Packing 70,000 files wrote "4,464" as the archive's count
  of files, and adding to or deleting from such an archive counted wrongly
  too; a program that trusts that number showed only part of the archive.
  The data itself was intact. Large archives now carry the count in their
  zip64 record, and an archive with a wrong count from an earlier version
  gets the right one the next time it is changed.

- **Deleting many files from a large ZIP archive is fast** (feature 164).
  Deleting 15,000 of 30,000 files took about 20 seconds and grew with the
  square of the archive's size; it now takes well under a second (100,000
  files: about one second).

- **A file with a very long name no longer stays selected after a dialog**
  (feature 163). With nothing selected, Quick Rename, Change Attributes,
  Change Case, Pack, Email or Convert select the file under the cursor for
  their time; a file whose name is longer than 259 bytes (about 130 letters
  with accents) stayed selected afterwards - the next Delete with the cursor
  on another file offered to delete that file. Find's ignore list now treats
  an entry like "Účty" as the same folder as "účty".

- **Portables: "selected devices" in the right plural** (feature 161) - it
  always read "N selected device" (in every language the English form).

- **Dropping files into an archive with a very long name** (feature 160): an
  archive whose full name is longer than 259 bytes refused files dropped or
  pasted into it; ZIP, 7z and TAR take them now.

- **Portables: the information line reads correctly in every language**
  (feature 159) - "selected devices" and "no devices" lost their accented
  letters.

- **Case-sensitive folders: renaming onto a name that differs only in case**
  (feature 158). Where `a.txt` and `A.txt` are two files (a WSL or
  case-sensitive folder), renaming `a.txt` to `A.txt` now asks whether to
  overwrite `A.txt` instead of failing with "already exists".

- **FTP: the information line about selected files reads correctly**
  (feature 157). With a size-in-bytes column it showed "bajt? v 3 vybran?ch
  souborech" in Czech (and the same in other languages with accents).

- **Texts about several selected files read correctly in every language**
  (feature 156). Dragging several files showed "vybran? 2 soubory" (a
  question mark for each accented letter); the Copy from archive, Delete from
  archive and Pack dialogs for several files showed their sentence garbled.

- **Clearer refusals** (feature 155). A folder copied onto itself says so
  (it said "Cannot copy a file to itself."), a folder moved into one of its
  own subfolders says that, packing an archive into itself tells to leave it
  out of the selection, and the Batch Renamer says "Cannot move a file to
  itself." instead of "already exists". An empty folder copied onto itself is
  refused too.

- **Text typed while the program catches up keeps its characters**
  (feature 154). Characters outside the keyboard layout's code page (another
  script, emoji) typed into the command line right when the program came back
  to the foreground or while an operation was running arrived as `?`.

- **Archive Update warns when another program changed the edited member**
  (feature 153). A file opened for editing from an archive (F4) whose member
  was changed or removed in the archive by another program meanwhile is now
  marked in the Archive Update dialog - updating it overwrites that change.
  The dialog's list also scrolls sideways now.

- **PictView: the print preview shows the picture** (feature 152). The
  preview in the Print dialog stayed an empty page in every release since
  the image engine was replaced; it now shows the picture as it will be
  printed - mirrored or turned as in the viewer, only the selection when
  printing the selected area.

- **Plug-ins dialog: Focus works in a long or non-English install folder**
  (feature 151). Focus built the plug-in's path in the system code page into
  a fixed buffer - an install folder with characters outside it was named
  wrongly, and one near 260 bytes long overran the buffer.

- **Focus from a plug-in or a message reaches files in long folders**
  (feature 150). Focus from Checksum, PictView, the "name is too long"
  messages and the Shares dialog cut a folder path longer than about 460
  (PictView: 260) bytes - the panel reported an error or went to another
  folder.

- **Checksum: a list with a very long path is verified** (feature 149). A line
  whose path was longer than about 780 bytes stopped the whole check with
  "Cannot finish operation because of too long name." - also for every other
  file of the list. Such a name is shown with its end visible.

- **Undelete: restoring deleted files of one name never overwrites another
  restored file** (feature 148). Two deleted `a.txt` and a deleted `a (1).txt`
  were all named `a (1).txt` at least twice, and the restore asked to
  overwrite one with the other. The numbers now skip the names the list
  already has; in FAT folders below a folder with a single item the deleted
  files of one name are numbered too.

- **Checksum and File Comparator windows close reliably** (feature 147). A
  read error met just while a Checksum window was closing could block it for
  good; after a declined close the File Comparator stopped taking comparisons
  from other programs (fcremote).

- **Deleting, copying or viewing in an archive through a drive letter that
  was pointed elsewhere no longer acts on the other archive** (feature 146).
  F8 deleted the members of the same names from the archive the letter led
  to now; F4 could put the other archive's member back into this one. Such an
  operation is refused with the note that the archive has changed, and the
  panel is reopened.

- **An edited archive member is never packed into another archive** (feature
  145). When the drive letter an archive was opened through (SUBST or a
  network drive) was pointed elsewhere while a member was being edited,
  leaving the archive packed the edit into the archive the letter led to now.
  The update is now refused ("Packing ... has failed": point the letter back
  and try again, or copy the edited file to a folder), and a refresh reopens
  such an archive. An archive updated in place by an archiver still takes the
  edit.

- **Archives through a re-pointed drive letter keep their own members**
  (feature 144). With both panels on the same SUBST or network drive name of
  an archive, the letter pointed to another folder in between and both
  archives of the same size and time, viewing or editing a member in the
  second panel worked on the FIRST archive's member - and the edit was packed
  into the second archive, replacing its own member.

- **Disk Map: closing the program with a map's context menu open no longer
  crashes** (feature 143). The same was true while Windows' own confirmation of
  a command chosen from that menu (Delete) was open, and when an installer
  closed the program for an update while the menu was open. A map closes now
  when its menu or box has ended; the confirmation of a shell command is left
  for you to answer, and the map closes after it.

- **FTP client: messages, the operation window and the log show names
  readably in every language** (feature 134; the last part of GitHub #7).
  In languages whose texts have accented letters, a message made of a
  translated sentence and a file, directory or bookmark name, a Windows error
  or the server's reply showed one half as garbage: creating a directory,
  changing a path, renaming, downloading, the Copy / Move / Delete questions,
  the descriptions, states and title of the operation window, bookmark
  questions. Fixed in about 120 places.
  - **The log is readable.** One directory with an accented name made the
    whole log of a connection show through the wrong encoding - in English
    too. Every line is right now; a saved log is UTF-8 (with a byte-order
    mark) and *Copy* puts Unicode text on the clipboard. **The bytes of a
    saved log therefore differ** from earlier versions.
  - A server reply in the system code page no longer spoils an English
    message either.
  - Places that could only show text of the system code page - the
    "Connecting to ... as ..." line of the password prompt, the list of logs,
    the lists of server types and proxy servers, the certificate error text -
    show any name. The Quick Connect address is stored in the address history
    as it was typed (an accented address was stored garbled).
  - Nothing sent to a server changes.
  - Undelete: the "restore ... to" label names the file readably.
  - For plug-in authors: `GetCommonFSOperSourceDescr` returns its whole text
    as UTF-8 (it was a code-page word around a UTF-8 name).

- **PictView: Update Thumbnail works for every file name** (feature 142). A
  photo whose name or folder has letters outside the system code page -
  Japanese, Greek, an emoji on a Czech system - could not get its thumbnail
  updated on a volume that keeps no short names (the default for every disk
  but the system one): each file showed "Unable to create a file with the new
  thumbnail. Disk full?" with OK only. The Exif library now takes any name
  and long paths; the Exif information window likewise.
  - A failure offers Skip / Skip all / Cancel like the command's other
    errors, with the Windows reason where one is known; "Skip all" was never
    honoured and is now (separately for each kind of error).
  - A read-only picture updated with your consent is read-only again
    afterwards.

- **Long names in other scripts are copied, moved and renamed whole**
  (feature 141; so in 0.1.9 too). A file or folder whose name is long in
  Chinese, Japanese or Korean letters (from about 240 letters; Windows allows
  255) could not be copied or moved at all - "the file name ... syntax is
  incorrect" - because the name was cut inside a letter on the way. Quick
  Rename to such a name failed the same way, and a typed name longer than
  Windows allows was **shortened silently** (256 letters became 173). Now the
  whole name is used, and a name that is too long is refused with a message.
  The same for a new name typed into Copy / Move, and for Edit New File.
  - A mask with `?` or fixed letters works on whole letters: `?.*` on
    `été.txt` gives `é.txt` (it produced a broken name). Results for plain
    ASCII names and masks are unchanged. For plug-in authors: the `MaskName`
    service follows the same rule.
  - **FTP: an automatically renamed upload is shortened at a whole letter**
    (the download direction was repaired in 137), and a rename on an OpenVMS
    server no longer crashes for a name like `a_123;1` that was already
    renamed once.

- **SFTP: a lost connection stops the operation** (feature 140; so in 0.1.9
  too). When a request timed out, a copy, move, delete or attribute change
  went on with the next item - and the next answer read from the server could
  be the late answer to the earlier request: the content of one file under
  the name of another, a "not found" for the wrong path. Now the operation
  ends there with one message, nothing more is sent on that connection and
  nothing is removed on either side after it; the next operation offers to
  reconnect as before.
  - **Devices, FIFOs and sockets are not downloaded** (also behind a link and
    with F3): a link to `/dev/zero` filled the disk without end, a FIFO froze
    the program. They are reported as "not a regular file" and left in place.
  - **Change Attributes and Change Owner say when the server refused**: one
    message with the first refused item, its reason and the number of others.
    Refusals went to the log only.

- **SFTP: nothing is replaced without a question, and never before its
  replacement is whole** (feature 139; all of this was so in 0.1.9 too).
  - **An upload asks before it replaces a file on the server** (Yes / No /
    Cancel = skip the rest). It replaced it without a word.
  - **A replaced file keeps its old content until the new one has arrived
    whole.** An upload goes to a temporary name in the same directory
    (`.tcpart-…`), the size the server reports is compared with the local
    file, and only then does it take the place of the old file, with the old
    file's owner and permissions. A download over an existing local file goes
    through a temporary file likewise. A failed or stopped transfer leaves the
    old file as it was and no partial file under its name. Where the server
    does not allow this (the target is a link, the account may not create or
    rename files there, the file belongs to another account) the file is
    written in place as before - after the question - and the log says so.
  - **Quick Rename to a name that already exists is refused.** It replaced
    the other file silently.
  - **Move to the server removes a local file only after its own upload is
    confirmed**, and a folder when everything in it was moved. Before, the
    local tree was deleted by listing it again after the upload - including a
    folder the server had refused to create.
  - A folder that is a link (junction, symbolic link) is skipped and you are
    told once; cloud folders (OneDrive) are uploaded - they were skipped
    silently and the upload reported success. A very deep local tree no longer
    exhausts the stack.

- **SFTP: Move from the server moves directories** (feature 138). A moved
  directory was copied and stayed on the server whole, without a word. Now
  each file is removed from the server once its local copy is confirmed (the
  same size as the file on the server), and a directory once everything in it
  was moved. What could not be moved stays, with the directories above it,
  and is reported. Two files on the server whose names are one name on
  Windows (`A.txt` and `a.txt`) are not merged: the second stays on the
  server.

- **Quick Rename on a server refuses a name that is too long** (feature
  137). A typed name longer than about 85 Chinese or 130 accented letters was
  cut - possibly inside a letter - and the server was asked to rename the
  file to the cut name; the in-place rename line could even send the name
  through the system code page (a row of question marks). The program says
  the name is too long and nothing is renamed. Renaming a file on a disk to
  such a long name in the in-place line works now.
- **FTP: automatic rename of a download** shortens a name at a whole letter.
  With an accented or Asian name the cut could fall inside a letter and the
  file was not downloaded at all ("the file name is incorrect").

- **Registry Editor: texts in the information line are readable in every
  language** (GitHub #3, feature 124). In Czech, German and Slovak the word
  for a key (`KLÍČ`) came out as replacement characters; so did the
  "selected" text in five languages, the name of the `(Default)` value in
  four, and the data of any text value with accented letters in every
  language, English included. A long text value is now shortened after a
  whole character. *Copy Name*, *Copy Full Name* and *Copy Path* put names
  with accented letters on the clipboard correctly. The Size column and the
  plug-in's Find window were right and stay right.

- **SFTP: a directory that could not be read whole is an error** (feature
  133). When reading a remote directory failed in the middle, the part read
  so far was taken for the whole directory: a copy "succeeded" with part of
  the files and the panel showed a partial list. Now the copy or move fails
  with "Cannot list directory ...: reason", and the panel returns to the
  parent directory. Deleting a tree no longer asks the server to remove a
  directory whose items could not all be deleted (one message instead of one
  per level). Error messages with a long path keep their reason at the end.
  An address typed as `sftp://user@host/path` is accepted. The SFTP fixes of
  feature 131 were checked against a real server.

- **PictView: *Update Thumbnail* works again - and cannot damage a picture**
  (feature 132). The command has done nothing in any release so far ("Unable
  to save the image"). It makes the thumbnail now, and a file is replaced only
  when the new one differs from it in the thumbnail alone: the picture, the
  XMP data, colour profile and whatever follows the picture (motion photo) are
  compared byte for byte first. The old Exif code would have dropped the XMP
  data of every file and written a truncated file for some; such a file is
  left untouched and reported. A file with Exif is no longer asked "this file
  does not contain EXIF data". The Exif data themselves are not rewritten:
  only the thumbnail picture is swapped and every other byte of the block
  stays where it is, so the camera maker's own data survive (feature 135 -
  the old Exif code changed or shortened them in 30 of 82 real camera files
  tested). The old thumbnail does not stay readable in the file.

- **Plug-ins: a batch of defects found while reading them** (feature 131).
  - **FTP: an address with `%` in the host name crashed the program**
    (`ftp://a%sb/`) - the name was used as a format of the error text.
  - **ZIP: a self-extractor favourite with a long name was lost.** A name of
    about 25 accented letters (17 CJK) did not load, and the favourite with
    all its options was deleted at the next save. Favourite names with
    accented letters are also shown right after a restart now.
  - **SFTP never works on a shortened path**: a remote or local path that did
    not fit was cut and the download, upload, delete or rename went on with
    the cut one; it is refused ("path too long") and a move deletes nothing.
    A failed operation shows the server's reason ("Permission denied")
    instead of nothing or the reason of an earlier failure.
  - **PictView: *Update Thumbnail* works for files with accented letters in
    the path** (none of them could be opened).
  - PE Viewer: a version-resource name with a letter such as `č` no longer
    loses the rest of its line. Undelete: the names of its virtual folders are
    right in every language. Renamer: "Duplicate name." is no longer followed
    by an unrelated Windows error; long search and command histories load.
    Registry Editor: a broken regular expression in Find shows its own error
    only. File Comparator, DiskMap, 7-Zip: buffer overruns with long font
    names, long paths and a wrong plural. FTP: Quick Rename with a mask
    refuses a name that is too long instead of renaming to a cut one.
  - Spanish: 7-Zip said "El archivo '...' es Aceptar."; the "SFTP error"
    sentence was wrong in seven languages.

- **Plug-ins: messages with a file name are readable in every language**
  (feature 130, the follow-up of GitHub #7). In a translated version a
  plug-in's question or error that named a file showed the name as wrong
  letters (`PĹ™Ă­liĹˇ` for `Příliš`) whenever the sentence itself had an
  accented letter - Checksum's "file already exists, overwrite?", the
  result of *Test Archive* in ZIP and 7-Zip (Slovak, Hungarian, ...), the
  window titles of PictView, Database Viewer and PE Viewer, the errors of
  SFTP, TAR, UnISO and Renamer with the reason Windows gives. Thirteen
  plug-ins are corrected. The title of the progress window of an archive
  operation shows an accented archive name right now too (it was wrong in
  English as well). The FTP client follows separately.

- **Registry Editor: questions and errors name the key** (feature 129).
  Copying or moving a key to a target that does not exist asked whether to
  create it in a box with *Yes* and *No* and **no text** when the target's
  name held a letter such as `č`, `ř`, or any letter outside Western
  European; "can't copy a key to itself" was empty the same way, and
  "unable to open registry key" stopped in the middle of the name. Viewing
  (F3) a value of such a key used one temporary file for the same-named
  values of different keys. All four are right now, in every language.

- **A server name is enough to get to its shared folders** (GitHub #5,
  feature 125). Change Directory with `\\server\` (or `\\server`) answered
  *A share name is missing in the path specified*. The program now asks the
  server for its shared folders and offers them in a list under the path
  line - visible folders first, the hidden `$` shares after them; pick one
  and the panel opens it. A server that cannot be read is reported with the
  reason Windows gives, and the wait can be cancelled with Esc. Nothing
  changes where a Network plug-in is present. `PRIVACY.md` describes the new
  request.

- **The program no longer needs Windows 8 functions to start** (GitHub #6,
  feature 126). Two functions used to look up command shells installed as
  Store packages were bound when the program is loaded; on Windows 7 SP1,
  Server 2008 R2 and Windows 8.0 that ended the start without any window or
  message. They are now looked up when needed, and where they do not exist a
  packaged shell is simply not found. Windows 11 remains the only supported
  system; nothing changes there. (The Code Viewer and Markdown Viewer
  plug-ins still need a newer Windows.)

- **Translated messages show names and error texts readably** (GitHub #7,
  feature 127). In languages whose texts have accented letters, a message
  composed from a translated sentence and a file name, a path or the reason
  Windows gives showed one half as garbage: the Find Files status line and
  log, the Find window's title with an accented mask, about twenty message
  boxes (a folder that cannot be read, a name that is too long, a viewer or
  editor that cannot be started, ...), the View With / Edit With menu, five
  Registry Editor messages, the viewer's *Cannot find the string*, the
  message about a broken regular expression, and every message of the
  external archivers. Ctrl+C in a message box copies its text readably. The name the program generates for a copy pasted
  into the same folder is spelled correctly in Slovak and Hungarian. English
  is unchanged. The progress window's title no longer overruns its buffer
  with a very long file name.

- **Shortcuts open their targets** (GitHub #8, feature 128). Enter or a
  double-click on a shortcut (`.lnk`) to a folder answered *(123) The
  filename, directory name, or volume label syntax is incorrect* whenever the
  target path held a letter outside plain ASCII - any accented letter, any
  other script. The same for *Go to Shortcut Target*. Both read the target
  as Unicode now, like Windows Explorer.

## [0.1.9] — 2026-10-07

**Build 193.** Feature release. The program now tells you when a newer
version has been published: on by default, one request to GitHub about once a
day, nothing about you or your computer is sent, and one option turns it off.
RAR archives open and unpack without installing anything, on a 7-Zip engine
updated from 16.04 to 26.03. External archivers, which never started in any
earlier release, work; the MS-DOS archivers are gone. A long series of fixes
ends silent data loss around archives and file operations, makes file names,
passwords and typed text in any script work in the program and its plugins,
opens archives and folders at very long paths, and makes PictView's Save As
save again. The privacy defects found while writing the privacy statement are
fixed. Plugin interface 107; plugins built for earlier versions keep working.

New version check (feature 123). Tandem Commander tells you when a newer
version has been published. **It is on by default and is the first thing the
program does on the internet without being asked:** once a day, when it
starts, it asks GitHub which release is the latest. It sends nothing about you
or your computer and downloads nothing; `PRIVACY.md` describes it, and one
option turns it off. Because this version is the first that can look, you will
first be told about the version that follows it.

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

### Added

- **Check for a new version.** When a newer version of Tandem Commander has
  been published, a window says so shortly after the program starts: it shows
  the version you have, the new version and its release date, and offers
  *Download* (the installer opens in your web browser — the program downloads
  and installs nothing itself), *Remind Me Later* and *Skip This Version*; a
  link opens the release notes. The check runs about once a day (when the
  server could not be reached, it is tried again at a later start, at most
  once an hour) and never delays the start: without a connection, or when the
  server does not answer, nothing is shown. **Help → Check for New Version** asks at any time and
  always answers — a newer version, "the latest version", or why the check
  could not be made. The **About** box shows what is known next to your
  version, with a link to the download. To turn the automatic check off, clear
  **Options → Configuration → General → Check for a new version of Tandem
  Commander at start-up**, or the same option in the window itself. What is
  sent: one request to `api.github.com` with the fixed identification
  `TandemCommander-updatecheck` — not your version, no identifier, no cookies
  (see `PRIVACY.md`). Only published releases with an installer are offered,
  never pre-releases. If the program was installed with the Windows Package
  Manager, `winget upgrade` may offer the new version a little later than
  this window does; the download works in either case.

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
  scanned, captured), and while a window of another plugin that may hold
  unsaved work is open (Batch Renamer and others; File Comparator, Disk Map
  and Checksum Verify windows, the Registry Editor's Find window and FTP's
  log and message windows no longer stop an update - see *Fixed*, features
  118 and 121).
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

### Fixed

- **Find searches the folder you are in, however deep it is.** The *Look in*
  field held 259 bytes - about 130 accented characters: opened from a deeper
  folder it took the path cut there (inside a character too), so Find searched
  another folder or none, and a longer typed path was cut the same way. The
  field now takes any path the program can open.
- **Message boxes break lines between words.** When a message contained a long
  path, every line of it was cut at the box's edge, inside words. Now only the
  path itself is split, preferably after a backslash.
- **Copying a name, a path or text to the clipboard says when it fails.**
  While another program held the clipboard open, *Copy Full Name*, *Copy Name*,
  *Copy Full Path*, *Copy UNC Name*, the copy commands of the Find window, the
  directory line, the viewer and the message boxes did nothing, silently; they
  now show the system's reason.
- **Checksum: a list that cannot be written completely is reported.** A full
  disk (or a file locked by another program) left a truncated checksum list
  without a word; the plugin now shows "Error creating file" with the reason.
- **Disk Map's log shows file names correctly** - names with letters outside
  English were garbled there.
- **The plugins' folder pickers follow network shortcuts** (folders in
  *Network shortcuts* / NetHood) to the folder they point at, as the program's
  own picker always did, and no longer accept a selection that is not a
  folder on disk.
- **FTP: a user name, server name or password typed into a path that is too
  long is refused** ("too long path") instead of being cut - a cut user or
  server name was another account or server, and the password went there.
  The login command that carried the password is now wiped from memory after
  the connection, like the transfer workers' copy.
- **Closing the program right after the File Comparator's `fcremote` started
  it no longer asks "plugin has rejected to unload. Force?"**
- **An update goes through while the Registry Editor's Find window (not
  searching) or FTP's Logs or server-message window is open.**
- Smaller: the "name already used" error of a copy or move shows its
  translation exactly also when the system's code page lacks some of its
  letters; the Romanian ZIP message about multi-volume archives begins with a
  capital letter.

- **PictView's pipette and histogram show the picture's real colors.** Since
  the built-in image engine of 0.1.0 the pipette showed, for three of every
  four pixels, the color of another pixel with its channels mixed up, and the
  histogram was wrong for every picture - the engine's rows were read in the
  wrong format. Both now read every pixel correctly (checked against an
  independent decoder on 24-bit, 32-bit, transparent, palette, gray and
  black-and-white pictures). On a mirrored picture the pipette also showed the
  pixel opposite the cursor, and on a very large picture zoomed in it could
  show another pixel; it now always shows the one under the cursor.
- **PictView renames a picture onto a file that another PictView window
  shows.** Choosing *Rename* onto an existing file that a second PictView
  window had open failed with "Access is denied" (nothing was lost).
  After "Yes" to the overwrite question the rename now goes through, and the
  second window shows what that name holds now; a window that is printing or
  saving keeps its file and the rename is refused as before.
- **A rotated picture stays rotated when PictView changes its background
  color.** With a different background color for full screen, switching to
  full screen (or changing the colors in the configuration) undid a rotation
  made in the viewer - also the automatic one from a photo's orientation -
  and the picture was drawn squeezed and saved unrotated.
- **A failed multi-volume ZIP archive leaves nothing behind, and a set never
  ends with a misnamed last volume.** When packing a multi-volume archive
  stopped part-way - a file that could not be read, Cancel, a declined
  "Overwrite?" question - the volumes already written stayed in the folder, a
  set that no program can open. They are now deleted; files the operation did
  not create are never touched (a volume name whose overwrite you confirmed
  goes with the set; when the disk cannot tell whether a volume is still the
  file that was written, it is kept). On removable disks only the volume
  still being written is deleted; cancelling "insert the next disk" no longer
  deletes the file of that name on the newly inserted disk. Packing a multi-volume archive into a name that already
  exists (answering "Add") used to end with the last volume named `.z0N`
  instead of `.zip`, silently - and with "Delete files after packing" the
  files were deleted. The ZIP plugin now refuses this before it starts ("The
  multi-volume archives can be created only like a new archive"); choose
  "Overwrite" or another name.
- **Packing an archive into itself is refused, with its name.** Packing
  (Alt+F5, F5 / F6 into an archive in the other panel, drag and drop, paste)
  into an archive that is itself one of the selected files - or lies inside a
  selected folder - made the ZIP plugin report a sharing violation, and the
  7zip plugin packed the old archive into the new one (with "Delete files
  after packing" then failing with "Delete Error"). It is now refused before
  anything happens, and the message names the archive. **Changed behaviour:**
  the pack is refused as a whole (before, ZIP added the other files after you
  skipped the archive) - leave the archive out of the selection. The Pack
  dialog no longer asks "Add or Overwrite?" in that case (feature 119).
- **An update no longer fails because a finished comparison, disk map or
  checksum verification was left open.** When an installer or a package
  manager (winget) updates Tandem Commander while it is running, it asks the
  program to close; since 0.1.8 the program declines while a window it cannot
  close without asking is open - and so far that was every window of the File
  Comparator, Disk Map, Checksum and Batch Renamer plugins. A File Comparator
  window, a Disk Map window (with its Log window) and a Checksum Verify window
  only show what they read, so the program now closes them and lets the update
  go on - also while the comparison, scan or verification is still running
  (it is cancelled, as Esc does). Windows that hold something that would be
  lost still keep the program running, without showing anything: a Checksum
  Calculate window with checksums that were not saved - each checksum type
  it calculated must have been saved, as one save writes one type - or that
  are still being calculated, a Batch Renamer window (its masks and its Undo of the renames
  already done), and any dialog or message box of these plugins. Also fixed:
  closing a File Comparator window while it was comparing was lost when the
  comparison ended at that moment - the result's message box appeared instead
  (or the window stayed open); and Disk Map could write into freed memory when
  the program could not unload it at once, or when a scan was stopped just as
  it finished (feature 118).
- **Checksum lists are read in the encoding they were written in.** Verifying
  a .md5, .sha1, .sha256, .sha512 or .sfv list reported files with accented
  names as missing when the list was written in the Windows code page (Open
  Salamander, older tools, PowerShell Set-Content), and refused a list saved
  as UTF-8 with a byte order mark (Total Commander when a name needs Unicode,
  PowerShell Out-File -Encoding utf8) or as UTF-16 (PowerShell 5.1 ">") as
  "not a checksum file". The encoding is now recognised for the whole list;
  a name that cannot be read exactly is reported missing and never matched to
  a similar-looking file. Lines such as "./folder/file" or
  "folder/../file" (lists made with find) were always reported missing and
  now work; a name with "?" or "*" (what a code-page tool writes for a
  character it cannot store) is reported missing instead of being taken as
  a wildcard that found some other file and then ended in an error; a
  folder named in a list is reported missing instead of an error; a name
  with a full path is checked only when it lies on the list's own drive or
  network share - any other, in particular a network path such as
  \\server\share\file, is reported missing without contacting that server;
  lines that GNU sha256sum escapes (names with a backslash) are read. Lists
  saved by Calculate in the MD5 and SHA formats now end lines with LF and
  have no comment line, so GNU sha256sum (also in Git for Windows) and 7-Zip
  can check them - neither could before; SFV lists are unchanged (feature
  117).
- **FTP passwords are the text you type, in any script and up to 100
  characters.** A character outside the Windows code page typed into the
  password field of the FTP Connect dialog or of a proxy server - Cyrillic,
  Chinese or Japanese, an emoji, or accented letters such as "à" on a Czech
  Windows - was turned into "?" or into a look-alike ("a") before it was saved
  or sent, so the login failed; "Show password" showed and copied the same "?".
  Worse, a correctly saved password with such characters (typed as part of the
  address, ftp://user:password@server) was saved back as question marks when
  you merely moved through the password field. Passwords now reach the server
  as typed (as UTF-8, as before for every other character), and "Show password"
  shows and copies them exactly. A password, account or proxy password of up
  to 100 characters is now always sent as typed: version 0.1.8 sent one of
  more than 50 accented letters (or 34 Chinese characters) in another form -
  bytes of the Windows code page, "?" for every other character. A password
  that 0.1.8 saved in that form keeps working unchanged, also with "Retry"
  after a failed login. Saved passwords keep their format; a password longer
  than 100 bytes (more than 50 accented letters, or 34 Chinese characters)
  saved by this version is cut to its first 100 bytes if you go back to
  version 0.1.8 or older; an anonymous-login password (e-mail address) of
  more than 100 bytes is not read by 0.1.8 at all - it uses its default and
  saves that default over it. A SOCKS 5 proxy accepts at most 255 bytes of
  user name and of password (its protocol's limit): a longer one is refused
  when you enter it, and never sent cut. User names, server addresses and
  start folders keep their limits (about 50 accented letters for a user
  name) and are refused, not cut, when longer. A proxy server entry with a
  refused field is no longer saved with that field empty (feature 116).
- **Undelete's "Restore Encrypted Files from Backup" no longer crashes in
  deep folders.** Restoring a folder whose contents lie deeper than about
  260 characters of path (fewer with accented letters), or a folder holding a
  junction or symbolic link back to itself, made the program crash. A source
  panel in such a deep folder restored nothing and left empty folders behind.
  Folders of any depth are now restored; a link back into the folders being
  restored, or the target folder lying inside them, is reported and skipped.
  Also in Undelete: the virtual folder {All Deleted Files} of a FAT disk
  showed a file twice when its deleted folder was found twice, and could
  leave out a different small file (up to 20 bytes) that had the same name as
  another; deleted files whose names differ only in the case of an accented
  letter (for example "Č.txt" and "č.txt", one name for Windows) are now
  numbered like "A.txt" and "a.txt" always were, instead of the second
  asking to overwrite the first; and a failed restore of an encrypted file into its backup form
  could delete a file of the same name without the ".bak" in the target
  folder (feature 115).
- **Undelete restores deleted files under their own names, and from the
  volume chosen.** A file whose name begins with one of 4,096 Chinese and
  Japanese characters (U+5000 to U+5FFF) was listed with a "$" and two
  garbled characters, and restoring it asked for "the first letter of the
  damaged name" and wrote the file under a name that was not its own - on
  every file system (NTFS, exFAT, FAT). A rule that belongs only to the old
  8.3 short names of FAT disks had been applied to all names; it now applies
  only there. On FAT disks (USB sticks, memory cards) also: short names with
  accented letters are read correctly, a deleted file whose long name starts
  with an accented letter, or with a letter Windows leaves out of the 8.3
  name, keeps its long name (it was shown under its 8.3 name), the
  lower-case markers of 8.3 names are honoured, and the
  "All" button of the damaged-name question also remembers an accented
  letter. A disk mounted into a folder whose name contains a character
  outside plain English letters was shown with a wrong name, and choosing it
  could open the disk the folder lies on instead of the mounted one. Also
  fixed: an alternate data stream with a very long name could be mixed into
  the file's main content when restoring from NTFS, error messages showed
  file names garbled in translated user interfaces, and several overruns on
  long names, including a crash when restoring two deleted files of the same
  very long name (feature 114).
- **A file that cannot be read while it is added into an archive no longer
  costs the archive's own copy of it.** Adding files into a ZIP archive (F5,
  F6, or an edited file packed back) that already holds a file of the same
  name, answered *Yes* to "overwrite?", removed the old file from the archive
  before the new one was read; when the new one then could not be opened
  (another program had it open, it had vanished) or could not be read to the
  end (a read error), and the answer was *Skip* or *Skip all*, the archive
  lost the old file too. With the ZIP option "Use temporary copy of archive
  for its modifications" turned off it was lost also on *Cancel* and when the
  progress was cancelled. Now the old file stays in the archive exactly as it
  was whenever the new one is not stored, in both modes. In the same place:
  a file added with AES encryption that could not be read to the end was
  stored incomplete after *Skip* (it could not be extracted, and a Move
  deleted the original), and *Cancel* did not stop the operation - now such a
  file is not stored and *Cancel* ends the operation. The 7zip plugin had the
  same loss: a file replacing one in a 7z archive is now offered *Retry* and
  *Cancel* only when it cannot be opened (*Cancel* leaves the archive as it
  was), and a file skipped during a Move is no longer deleted although it was
  not packed (feature 113).
- **An edit of a file from an archive is no longer lost when the other panel
  updates the same archive.** With both panels showing one archive, a file
  opened for editing (F4) in one panel and saved, but not yet packed back,
  was thrown away when the other panel updated the archive (its own edits
  packed on leaving it) or reopened it after another program had changed it:
  viewing (F3) or editing that file again in the first panel extracted it
  from the archive over the edit, and leaving the archive then offered
  nothing - the edit was gone without a word. This happened whenever the
  first panel did not refresh in between (automatic refresh off for the
  drive, a network share that does not report changes, Ctrl+R in the other
  panel). The edited file is now kept until its panel has packed it back. In
  the same place: a file opened for editing whose copy already existed (viewed
  first, or opened in the other panel) could be taken as unchanged when the
  editor saved very quickly, and when memory ran out the copy was deleted
  under the editor just opened; now such a file is not opened for editing and
  "Insufficient memory." is shown. One consequence to know: a file opened
  for editing is kept even when it was not changed, so if another program
  changes that file in the archive meanwhile, the panel that opened it goes on
  showing (and editing) the copy it opened until it is refreshed (Ctrl+R) or
  the archive is left - and packing an edit of it back replaces the other
  program's change, as it already did when the panel was refreshed first
  (feature 112).
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
  comes back (with feature 119, above, before its "Add or Overwrite?"
  question and naming the archive). Also fixed: answering *Cancel* to the
  ZIP plugin's "Overwrite?" question for the second or a later volume
  deleted the existing file you had just declined to overwrite (feature
  106).
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
  open. In the FTP plugin this also applies to a user name of more than 100
  bytes (about 50 accented letters): Connect and Close refuse it - before,
  such a name was saved and sent in the system code page; FTP passwords are
  no longer limited this way (see *FTP passwords are the text you type*,
  above) (feature 104).
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
- **Pasting a long path** (Ctrl+Shift+V) no longer goes to a cut path -
  paths of any length are accepted (with feature 101, above) - and a path
  copied from a Unicode program keeps characters outside the system code
  page.
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
  an archive with links that were left out (see *RAR archives* under *Added*).
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
