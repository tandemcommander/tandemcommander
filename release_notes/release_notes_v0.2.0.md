# Tandem Commander 0.2.0

**Released 25 October 2026 · build 195 · Windows 11 or newer, 64-bit · feature release**

## New

- **Quick search finds text anywhere in a name and shows only the matches.** Typing "chat" finds "2024_chatbot"; the panel shows only the matching items, lightly tinted, with "Search: chat (3 of 120)" in its directory line, and commands act only on what is shown. Accents are ignored both ways — "zlut" finds "žluťoučký", "strasse" finds "Straße". The previous behaviour is one option in *Configuration ▸ Panels*.
- **Import settings from Altap Salamander and Open Salamander.** *Options ▸ Import Settings from Salamander* (also offered once at the first start) brings hot paths, FTP connections and their passwords, the user menu, viewers and editors, histories, options, colours and plug-in settings after a preview. The old program's settings are only read, nothing you already have is changed without your tick, and a backup of your settings is saved first.
- **Panel tabs: a Tabs page in Configuration**, optional **browser-like shortcuts** (Ctrl+T, Ctrl+W, Ctrl+Page Down / Up) and **Reopen Closed Tab** for the last ten tabs closed in a panel.
- **Markdown Viewer: *View ▸ Page Width*** — *Normal*, *Wide*, *Wider* or *Full Window*, remembered; wide tables and code no longer scroll inside a narrow column.
- **Code Viewer: DOS, ISO-8859-2, KOI-8 and the other conversion tables** in *View ▸ Encoding*, as in the built-in viewer; a chosen table is remembered.
- **PictView turns photos taken upright and shows their Exif information** — both had been switched off by mistake.
- **Network drives show the names given in Explorer** ("Archiv" with its path) and the disconnected icon when Windows cannot reconnect them; such a drive reconnects whatever letters its path holds.
- **The way up from a network share.** `..`, Backspace and *Go to root* in the root of `\\server\share` list the server's shares; a server that lists them only to a signed-in user brings Windows' sign-in dialog.
- **Linux CD images show their real names** — images made by xorriso are listed and extracted under their real, long, lower-case names instead of short upper-case ones.

## Changed

- **Settings live under a key that no longer changes with the version.** At the first start of 0.2.0 they are copied from `HKEY_CURRENT_USER\Software\Tandem Commander\0.1` to `…\Settings`, checked value by value and used only when the copy is complete; the old key stays as a backup. Going back to 0.1.x afterwards is not supported.
- **Versions follow Semantic Versioning**: a release with new features raises the middle number, a fixes-only release the last one — hence 0.2.0 after 0.1.10.
- **Unpacking a TAR, cpio or rpm archive that holds symbolic links ends as failed.** The links cannot be created; they are named in a message, everything else is extracted and the archive is kept.
- **A configuration file imported at start-up may change only Tandem Commander's own settings**; a file that names any other key is refused as a whole.
- **Plugin interface 108** for plugin authors: a plugin can import its own settings from the old program. Plugins built for earlier versions keep working.

## Fixed

**Data loss**

- **Unpack with "Delete archive after unpacking" keeps a disc image that was not extracted whole** — a damaged folder or session, an unreadable HFS+ part, audio or Video CD stream tracks, a skipped file, a Mac file stored compressed. Before, the image was deleted with the only copy of what was missed.
- **TAR, cpio and rpm archives give every file**: hard-linked files arrive with their content, and archives made by Python, GNU tar in POSIX format or Windows `tar.exe` list long and non-ASCII names whole. Before, files were left out, empty or put into a wrong folder, and the archive could be deleted after unpacking.
- **Registry Editor: a Move or Delete no longer deletes keys or values you did not choose** — a key moved onto itself under another root name or into the key above its parent, a copy through a registry link, a key holding a link. A lost class name is warned about.
- **FTP: an upload asks before it replaces a file** renamed in the panel meanwhile, `b.txt` on a server that ignores case, a file with an unusual name, or a file changed through another name of the same server.
- **ZIP**: adding to or deleting from an archive that another program holds open can no longer lose it; names that differ only in case (`a.txt`, `A.txt`) are deleted, copied and replaced one by one.
- **Links**: copying out of an archive no longer moves your files from behind a link; *Change Attributes* on a junction or a file link changes the link, not what it points to.
- **Pack and Unpack never use another name**: an archive name with a colon, a trailing dot or space, or a leading space, and a long target path or mask, are kept whole or refused.
- **A damaged configuration entry** no longer erases the viewers, editors or User Menu items after it, or keeps the program from starting.
- **Undelete warns** before restoring onto the disk being recovered also through a mount folder with accented letters.
- A file left under a temporary `salNNN` name after a copy, a new folder or an unpack is named in a message.

**Names and text in any language**

- **The Desktop view's column headers read correctly on a non-English Windows** (#13).
- Drive labels, CD and USB drive names, folder type names and subst drives in any script are shown and used exactly; Drive Information writes accented labels correctly.
- Popup menus run the item whose hot key was typed in any alphabet; TortoiseSVN gets its typed hot keys.
- Masks with accented extensions (`*.čtx`) match both cases; the Batch Renamer's regular expressions and the Registry Editor's Find work on whole letters.
- FTP learns each server's encoding: an older code-page server gets new names in its code page, and one server no longer decides how names go to another.
- Disc images: Chinese and Japanese Joliet names stay whole, and names Windows cannot take are made safe, as in other archives.

**Long paths and names**

- **Typed text is refused, never cut** — Select and Find masks, filters, Find's *Containing* text, the Recycle Bin masks, Unpack targets, User Menu and viewer commands. Before, a shortened text could select, search or delete other files.
- View and Edit of archive files with long names, Create Directory, Paste into the same folder and Edit New File work with long names; the information line describes a long-named file without an error box.
- A shortcut or network location whose target has 260 or more characters opens the target itself, never its parent; Browse For Folder refuses a path it cannot return whole.
- Disc images and TAR archives with trees deeper than the panel can show list everything else and name what was left out.
- FTP refuses a server path that does not fit instead of downloading another folder; User Menu commands never run on a parent folder.

**SFTP**

- **Uploads into upload-only ("drop") folders work** — files are sent, existing ones are never touched, also for a folder uploaded again.
- The next upload offers to delete temporary files left by a lost connection; the overwrite question says what a replacement cannot keep.

**Crashes**

- Opening a damaged or crafted Nero image, or a TAR archive with a name of 300 Chinese letters, no longer crashes the program.
- A single very long file mask in the settings no longer crashes the program at every start; running out of memory no longer crashes the path line, the information line or a dialog's status text.

**Other**

- Copying from a TAR folder opened by a path typed in another case extracts its files.
- In case-sensitive folders, Compare Directories, the viewer's next file, the User Menu and Ctrl+X take the file of exactly the same name.
- Closing the File Comparator during a binary comparison no longer shows a stray error box.

## Removed

- The standalone settings migration script of 0.1.3 — the import replaces it and never overwrites what you set without asking.

---

Install over the previous version — settings are preserved · Free software under the GNU GPL v2 or later · <https://tandemcommander.org> · full detail in `CHANGELOG.md`
