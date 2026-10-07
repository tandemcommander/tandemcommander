# Privacy Statement

## Summary

Tandem Commander is a file manager that runs entirely on your computer. It has
no user accounts, no telemetry, no analytics and no advertising, and it sends
nothing to the project or to its author. With one exception it uses the
network only as a result of something you do — for example connecting to an
FTP or SFTP server, loading the images of a Markdown document, or clicking a
web link. The exception is the check for a new version: unless you turn it
off, the program asks GitHub about once a day, when it starts, which version
of Tandem Commander is the latest (see *Checking for a new version*). What it
stores — settings, history and, if you choose, saved passwords — stays in
your Windows user profile.

This statement covers the program and its installer as distributed by the
Tandem Commander project, including the plugins that come with it. It does not
cover the website tandemcommander.org, the GitHub repository, the Windows
Package Manager catalogue, or plugins obtained from anywhere else.

The locations below can be opened by typing them into the address bar of
Windows File Explorer (for example `%LOCALAPPDATA%\Tandem Commander`); the
registry key can be opened with the Registry Editor (`regedit`).

## What the program stores on your computer

### Settings and history

Settings are stored in the Windows registry under
`HKEY_CURRENT_USER\Software\Tandem Commander`. They include the window layout,
the folders open in the panels and in their tabs (which can be locations
inside archives or on FTP and SFTP servers, including the server name and your
user name there), your hot paths and user menu, the programs you configured as
viewers, editors and archivers, and the settings of each plugin. They are
saved when you close the program (*Save configuration on exit*, on by default)
or when you save the configuration yourself.

Recently used values are kept as history in the same place — for example file
masks and text you searched for, copy and move targets, folders you changed
to, commands typed on the command line, and in plugins recently compared
files, recently viewed pictures and FTP server addresses. History is saved by
default. You can control it under **Options → Configuration → History**:
*Save history*, *Save List of Working Directories* (off by default), the two
*Command line history* options, and *Clear History*, which removes the saved
entries the next time the configuration is saved.

Some recently used values are kept even when history is turned off and are
not removed by *Clear History* — for example the last text you searched for in
the built-in viewer and the last locations used by the Registry Editor and
PictView plugins. Deleting the registry key (see *Removing your data*) removes
them. The last folder you used on each drive is also kept when history is
off, but *Clear History* removes it.

If you use **Options → Export Configuration**, everything above — including
saved passwords in their stored form, see below — is written to a file at the
location you choose.

Windows keeps your hot paths in the program's taskbar jump list. Using
**Commands → Open Folder → Active Folder** (Shift+F3) in a Registry Editor
plugin panel sets the key at which the Windows Registry Editor opens.

To show the folders of OneDrive, Dropbox and Google Drive, the program reads
the settings those programs keep on your computer. Nothing is sent anywhere.

### New version check

For the check for a new version (see *Checking for a new version*) the
program keeps, in the same registry key under `0.1\Update Check`: whether the
check at start-up is on, when it last tried and whether the server answered,
when it last succeeded, the number and release date of the latest version it
learned of, and a version you chose to skip. These values are written when
they change, not with the rest of the settings, and *Clear History* does not
remove them. Nothing from the server's answer is stored except that version
number and date. An exported configuration contains these values too.
Importing a configuration, or removing a damaged one, replaces or removes
them; if the option is not part of what is imported, the check at start-up is
on again.

### Saved connections

FTP and SFTP bookmarks store the server address, port, user name, starting
folder and similar connection details. SFTP bookmarks also store the location
of your private key file — never the key itself — and SFTP remembers the key
fingerprints of servers you chose to trust. The FTP plugin keeps the e-mail
address it sends when you log in anonymously (by default the placeholder
`anonymous@example.com`, an address at a domain reserved for examples) as
plain text. Connection logs are kept in memory only
and disappear when the program closes, unless you save or copy a log
yourself.

### Crash reports

If the program crashes, it writes a text report to
`%LOCALAPPDATA%\Tandem Commander` and tells you where it is. **The program
never sends reports anywhere.** A report can contain the names of folders and
files that were open in the panels, the full command line the program was
started with, the names and locations of loaded program files, details about
Windows and your hardware, small excerpts of the program's memory (which can
include fragments of text it was handling), and for each drive its name,
serial number, size, free space and — for network or substituted drives — the
server, share or folder behind it. Your Windows user name usually appears as
part of folder paths. Please read a report before attaching it to a public
issue. The program never deletes crash reports; you can delete them at any
time.

### Viewer engine data

The Markdown Viewer and the Code Viewer display documents with Microsoft Edge
WebView2. WebView2 keeps its working data — caches, which can include
documents and images you viewed, and similar internal databases — in
`%LOCALAPPDATA%\Tandem Commander\WebView2`. Your file names are not part of
the addresses the viewers use internally. The program does not clear this
folder.

### Desktop wallpaper

PictView's **File → Set as Wallpaper → Center**, **Tile** and **Stretch** save
the picture you are viewing as
`%LOCALAPPDATA%\Tandem Commander\PictView_Wallpaper.bmp` and tell Windows to
use that file as your desktop background (Windows records it in its own
settings); for the chosen layout PictView sets the values `WallpaperStyle`
and `TileWallpaper` in `HKEY_CURRENT_USER\Control Panel\Desktop`. The
background you had before is remembered there too (the values
`PrevWallpaper`, `PrevWallpaperStyle` and `PrevTileWallpaper`; *Set as
Wallpaper* and **None** never remember a PictView picture there):
**Restore Previous** switches to the remembered background and remembers the
one it replaced, so using it again switches back (it does nothing when no
background is remembered); **None** removes the background. The file is replaced each time
you set a new picture; it is not deleted by the program.

### Temporary files

When you open a file from an archive or from an FTP or SFTP server, or run
some operations, working copies are placed in your temporary folder
(`%TEMP%`). They are removed when they are no longer needed or when the
program closes. If the program crashes, leftovers can remain; for its working
folders, the program offers to delete them the next time it starts.

PictView's *Save As* first writes the image into a temporary file in the
folder you save to (named `pv`, four characters and `.tmp`), which takes the
chosen name only when it is complete; the wallpaper picture is written the
same way in `%LOCALAPPDATA%\Tandem Commander`. If the program crashes during the save,
that file can remain there.

## Saved passwords

A password is saved only if you ask for it: *Save password* in an FTP or SFTP
bookmark, *Save passphrase* for an SFTP key, and *Save password* for an FTP
proxy server. How it is protected depends on the Master Password
(**Options → Configuration → Security → Use Master Password**):

- **With a Master Password**, saved passwords are encrypted with AES-256 using
  a key derived from your Master Password. The Master Password itself is
  never stored; after you enter it, it is kept in memory until the program
  closes. If you forget it, the passwords it protects cannot be recovered.
- **Without a Master Password**, saved passwords are only scrambled, not
  encrypted. The scrambling method is published with the program's source
  code, so anyone who can read your registry settings or an exported
  configuration can unscramble them. If you save passwords, please set a
  Master Password.

Passwords typed as part of an address (`ftp://user:password@server`) — in
FTP Quick Connect, in Change Directory, as a copy or move target, in Find's
*Look in* field or on the command line — are used for that operation but are
not kept in history: the history entry reads `ftp://user@server`. Version
0.1.8 and older saved them there as plain text; such entries are cleaned the
next time the configuration is saved — for the FTP Quick Connect history, the
next time it is saved after the FTP plugin has been used — or remove them
with *Clear History*. A password that contains `/` — or, on the command line,
a space, a quote, `<` or `>`, unless the address is enclosed in quotes — is
not recognised as part of the address and stays in the entry; use the
password field instead.

If you cancel the Master Password prompt while saving a new FTP, FTP proxy or
SFTP password or an SFTP key passphrase, it is not saved at all (*Save
password* is turned off); the connection still uses it.

Passwords for network drives are entered in a Windows dialog and are saved
only if you choose so there, by Windows.

## When the program uses the network

Apart from the check for a new version, the program does not contact the
internet on its own: there is no telemetry and there are no crash-report
uploads.

### Checking for a new version

When the program starts, it asks GitHub — which hosts the project's releases —
which version of Tandem Commander is the latest, and tells you if it is newer
than yours. This is on by default. It happens at most once in 24 hours; if the
server could not be reached at all, the program tries again at a later start,
at most once an hour. The same question is asked when you choose
**Help → Check for New Version** or *Check now* in the About box.

The request goes to `api.github.com` over an encrypted connection. GitHub
receives what any web request reveals — your IP address and the time — and the
fixed identification `TandemCommander-updatecheck`, together with two fixed
lines saying which form of answer is expected. Nothing else is sent: not the
version you have installed, no identifier of you, your computer or the
installation, and nothing about your files or settings. No cookies are stored
or sent, and the program never signs in to a server or a proxy with your
Windows credentials. The request uses the proxy settings of Windows: if a
proxy server is set up — or Windows finds one automatically on your network —
the request goes through it. The request goes to GitHub, not to the project or its
author; GitHub's privacy statement describes what GitHub does with it.

From the answer the program uses only the version number and the release
date. It downloads and installs nothing itself. *Download* — in the
notification window and in the About box — hands the address of the new
version's installer on github.com to your web browser, which downloads the
file (GitHub serves it from its download servers); *Release notes* opens the
page of that release on github.com. Both happen only when you choose them.

To turn the check off, clear **Options → Configuration → General → Check for
a new version of Tandem Commander at start-up**, or the same option in the
notification window. The program then asks only when you choose the command
yourself.

### Other network use

Everything else happens only in these situations, each started by something
you do:

- **FTP** — the program connects to the server you entered, or to a proxy you
  configured. FTP is not encrypted: your user name, password and files travel
  as readable text. Secure FTP (FTPS) is not available in this version; for
  anything sensitive use SFTP. An anonymous login sends `anonymous` and the
  configured e-mail address (the placeholder above unless you set your own).
- **SFTP** — the program connects to the server you entered over an encrypted
  SSH connection. It tells the server the name and version of its connection
  software (`SSH-2.0-libssh2_1.11.1_DEV` — no personal information). The first
  time you connect to a server, and whenever its key changes, you are asked
  whether to trust it.
- **Opening a Markdown document** — images from the internet are not loaded
  unless you choose **View → Load Remote Images**, and that choice applies to
  the open window only and is not remembered. The server hosting an image
  (and a proxy or redirect target on the way) then receives an ordinary web
  request: your IP address, the time, the image's address, and the
  identification `TandemCommander-mdview`. No cookies are stored or sent, and
  the viewer never signs in to a server with your Windows credentials. Nothing
  else from the document is sent. The viewer is designed to block anything
  else a document tries to load from the internet. Web and e-mail links in a
  document open in your browser or e-mail program only when you click them
  (or activate them with the keyboard), and lead wherever the document's
  author pointed them; the viewer is designed so that a document cannot open
  them without a click or key press of yours.
- **Network drives and shared folders** — when you open a network location,
  Windows connects to it.
- **Links in the program** — links in, for example, the About box, the Help
  menu, the Plugins Manager and the new-version notification open in your web
  browser or e-mail program when you click them. They point to
  tandemcommander.org or the project's GitHub pages, except the PictView
  plugin's home page and support address, which belong to a third party,
  pictview.com.
- **E-mail** — **Files → Email** passes the selected files to your e-mail
  program; nothing is sent until you send the message there.

When you open a phone or camera in the program, the Portables plugin
identifies itself to the device as "Windows Portable Devices for Tandem
Commander" with the plugin's version number.

## Components governed by others

- **Windows** handles network drives and their credentials, the jump list,
  and crashes the program cannot handle itself (Windows Error Reporting,
  according to your Windows settings).
- **Shell extensions installed by other software** — context-menu entries,
  icon overlays such as cloud-storage status icons, thumbnails — run inside
  Tandem Commander when it shows your files, and behave as their vendors
  designed them.
- **Microsoft Edge WebView2**, used by the Markdown Viewer and the Code
  Viewer, is provided by Microsoft. Its diagnostic data and its updates are
  governed by Microsoft's privacy statement and your Windows diagnostic-data
  settings (see Microsoft's
  [Data and privacy in WebView2](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/data-privacy)).
  The program turns off some of its background features (background
  networking, sync, component updates and SmartScreen checks) and tells it not
  to send its crash reports to Microsoft, so they stay on your computer, but
  does not change Microsoft's other diagnostic-data collection.
- **External archivers** (7-Zip and WinRAR's console programs) run only when
  you work with an archive format handled by an external program installed on
  your computer; they are separate programs with their own behaviour. To find
  them, *Archivers Autoconfiguration* reads where they are installed (their
  registry entries and the Program Files folders); nothing is sent anywhere.
- **Plugins from other sources** are not covered by this statement.

## Optional components

Some plugins exist in the project's source code but are not part of the
distributed program — among them an old update-checker plugin that would
contact the website of the original Open Salamander (it has nothing to do
with the check for a new version described above). They are not installed,
and loading such a plugin yourself is outside this statement.

## Installing and uninstalling

The installer downloads nothing. It copies the program files, creates
shortcuts and registers the program with Windows so that it can be
uninstalled. When it updates an existing installation, it also deletes
program files that earlier versions installed and this version no longer
uses; it does not touch your settings or other data.

Uninstalling removes the program files and the uninstall entry. It leaves in
place:

- your settings, history and saved passwords
  (`HKEY_CURRENT_USER\Software\Tandem Commander`);
- crash reports, viewer engine data and a PictView wallpaper picture
  (`%LOCALAPPDATA%\Tandem Commander`);
- the three `Prev...` values PictView writes in
  `HKEY_CURRENT_USER\Control Panel\Desktop` (see *Desktop wallpaper*);
- the folder `%APPDATA%\Tandem Commander`, which the program uses as the
  default place for exported configurations;
- any temporary files left behind by a crash.

## Removing your data

1. To remove history only, use **Options → Configuration → History → Clear
   History**, then save the configuration (or close the program). Values that
   are kept even with history off are not removed this way.
2. To remove everything, uninstall the program, then:
   - delete the registry key `HKEY_CURRENT_USER\Software\Tandem Commander`
     with the Registry Editor;
   - delete the folders `%LOCALAPPDATA%\Tandem Commander` and
     `%APPDATA%\Tandem Commander` (if a PictView picture is your desktop
     background, choose another background first);
   - delete the values `PrevWallpaper`, `PrevWallpaperStyle` and
     `PrevTileWallpaper` under `HKEY_CURRENT_USER\Control Panel\Desktop`, if
     they are there;
   - delete any configuration files you exported and any crash reports you
     copied elsewhere;
   - in your temporary folder (`%TEMP%`), delete leftover files and folders
     whose names start with `SAL`, `PACK` or `MFL` and end with `.tmp`, if
     there are any.

The taskbar jump list is kept by Windows and is not removed by these steps.

## Older versions

Versions 0.1.0 to 0.1.7 included a separate crash-reporting helper. Its upload
function was switched off in every release, and it saved reports on your
computer only. It was removed in version 0.1.8.

## Contact

Questions about privacy can be asked in the project's issue tracker:
<https://github.com/tandemcommander/tandemcommander/issues>. Issues there are
public, so please do not include passwords or other personal information.

Changes to this statement can be followed in the history of this file in the
project's repository.

---

This statement describes Tandem Commander 0.1.9 (`CHANGELOG.md`). In 0.1.8,
the version before it: there is no check for a
new version, so the program never contacts the internet on its own and keeps
no `Update Check` values; a password typed as part
of an address is saved in history as plain text; a Markdown document can open
a link without a click; remote images identify as `OpenSalamander-mdview`, and
the viewer may answer a server's request for Windows sign-in with your Windows
account; cancelling the Master Password prompt saves an SFTP password or
passphrase scrambled; the viewer engine's crash reports follow your
Windows diagnostic-data settings; and the placeholder sent on an anonymous
FTP login is `name@someserver.com`; a crash that happens while the ZIP
plugin is using a password can write that password into the crash report; and
PictView's wallpaper commands wrote no picture file (*Restore Previous* and
*None* did write the three `Prev...` values).
Last updated 2026-10-07.
