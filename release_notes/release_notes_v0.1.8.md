# Tandem Commander 0.1.8

**Released 20 September 2026 · build 192 · Windows 11 or newer, 64-bit · feature release**

## New

- **Panel tabs.** Each panel keeps several directories open in a tab strip above the Directory Line; every tab remembers its own directory, view, sort order, filter, cursor, selection and Back/Forward history.
- **Ctrl+Shift+T** (or `+`) opens a tab, **Ctrl+Shift+W** closes it, **Ctrl+Shift+PgDn / PgUp** switch tabs.
- Middle-click a folder to open it in a background tab, middle-click a tab to close it, drag tabs to reorder them.
- Tab context menu and a new *Tabs* submenu in the *Left* / *Right* menus: *New*, *Duplicate*, *Close*, *Close Other Tabs*, *Close Tabs to the Right*.
- Tabs work in archives and on FTP / SFTP, and are restored at the next start. No password is ever stored with a tab.
- On by default; *Show tabs in panels* in Configuration ▸ Appearance turns them off and restores the 0.1.7 behaviour exactly.

## Changed

- **Updating while the program is open**: asked to close by `winget upgrade` or Setup, an idle Tandem Commander closes without any question, saves its configuration and is started again after the update with the same directories and tabs.
- When closing would interrupt something (a file operation, a search, an open dialog, an FTP / SFTP connection, a plugin window) it declines at once and the update fails cleanly, with nothing changed.
- **Start-up no longer patches Windows code in memory** — a pattern antivirus engines flag. Crash reports work as before.
- **After a crash the program tells you where the report is**: `%LOCALAPPDATA%\Tandem Commander\TC<version>-<date>-<time>.TXT`. Nothing is sent anywhere.
- **The Markdown viewer uses the same hardened rendering surface as the Code Viewer.** Ordinary documents look the same; downloads started by a document are refused.

## Fixed

- **The program starts on a computer without the Microsoft Visual C++ runtime** — 0.1.0–0.1.7 installed fine and then failed with *"VCRUNTIME140.dll was not found"*. The runtime now ships in the program folder.
- **Updating over a running 0.1.7 works** (it used to fail with exit code 5).
- The installer removes the leftover `salmon.exe` from upgraded installations.
- The viewer's title bar no longer shows garbled accents for files under paths longer than about 260 bytes.
- Hardening: three internal buffer copies bounded; none was reachable with a shipped configuration.

## Removed

- **The crash-reporting helper `salmon.exe`** — a background process antivirus products flagged. Its upload had been off since 0.1.0 and it never produced a memory dump; its start-up question about "older bug reports" is gone with it.

## Known limitations

- An update is declined while a plugin window is open — **including a viewer such as the Code Viewer**. Close those windows before updating.
- The restart after an update works for updates *from* 0.1.8 on; a 0.1.7 closed for this update stays closed.
- Code Viewer: UTF-8, UTF-16 and your Windows code page only — use Alt+F3 for other encodings.
- Names outside your Windows code page are inserted into the command line with `?`; accented names inside archive listings may still display incorrectly.
- The HTML help is not rebranded yet; **unrar** needs `unrar.dll`, **FTP** needs OpenSSL (neither is shipped); no ed25519 keys in SFTP.

## Upgrading

- Install over the previous version — settings are preserved.
- Plugins built for 0.1.0–0.1.7 keep working: the plugin interface is unchanged at 106.
- `winget upgrade tandemcommander` will offer 0.1.8 once Microsoft has accepted the catalogue submission.

---

Free software under the GNU GPL v2 or later · <https://tandemcommander.org> · full technical detail in `CHANGELOG.md`
