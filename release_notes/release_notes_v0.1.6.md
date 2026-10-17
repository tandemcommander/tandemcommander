# Tandem Commander 0.1.6

**Released 29 August 2026 · build 190 · Windows 11 or newer, 64-bit · feature release**

Two additions you can see the moment you use them. Pressing F3 on a source or configuration file now opens a **Code Viewer** with syntax highlighting, line numbers and a choice of twelve colour schemes, covering over two hundred languages and formats. And the **Command Shell** command (`Num /`) is no longer tied to the Command Prompt — pick Windows PowerShell, PowerShell 7, Windows Terminal, Git Bash, or name your own program. This is also the first release published to the Windows Package Manager catalogue, so Tandem Commander can be installed and updated with `winget`. If you change neither setting, everything behaves exactly as in 0.1.5.

## New

- **Code Viewer: F3 shows code the way an editor does.** A new viewer plugin takes over F3 for source, markup and configuration files — `.cpp`, `.c`, `.h`, `.cs`, `.java`, `.js`, `.ts`, `.py`, `.php`, `.rb`, `.go`, `.rs`, `.sql`, `.xml`, `.json`, `.yaml`, `.toml`, `.ini`, `.sh`, `.ps1`, `Dockerfile`, `Makefile` and some two hundred more. Comments, strings, keywords and numbers are coloured, lines are numbered, and the recognised format is named in the title bar. `.txt` and `.log` files open in it too, as plain text with line numbers. The window is strictly read-only — the file on disk is never touched.
- **Twelve colour schemes.** Five light (GitHub Light, Light Plus, One Light, Solarized Light, Catppuccin Latte) and seven dark (GitHub Dark, Dark Plus, One Dark Pro, Solarized Dark, Catppuccin Mocha, Gruvbox Dark Medium, Nord), plus a "follow the application theme" option that gives you a dark view when the application is dark. Switching schemes recolours the open file immediately, without reloading it and without losing your place.
- **The Code Viewer opens instantly.** It renders through the Windows WebView2 engine and shares the warm engine introduced for the Markdown viewer in 0.1.5, so at most the first view of a session pays the start-up wait. Ctrl+PgDn and Ctrl+PgUp step to the next and previous file of the panel without leaving the window, and Find, word wrap, whitespace display and font size are on the menu.
- **Viewing untrusted files is safe.** Nothing in a viewed file is ever executed, no network request is made, and no window, download or external program can be launched from its content — however the file is crafted.
- **The Command Shell command opens the program you choose.** A new **Command Shell** page in the Configuration dialog (right after *Hot Paths*) offers Command Prompt — the default, and exactly what 0.1.5 did — plus Windows PowerShell, PowerShell 7, Windows Terminal and Git Bash, each found automatically wherever it happens to be installed. A preset you do not have is marked in the list, so you never get a silent failure. *Custom* lets you name any program and arguments, with `$(FullPath)` for the panel's directory and `$[NAME]` for environment variables. All the ways of invoking the command — the menu, `Num /`, `Ctrl+/` and the toolbar button — follow the setting. The command line box at the bottom of the window is unaffected.
- **Installation and updates through winget.** Tandem Commander is published in the Windows Package Manager catalogue as `PavelStupka.TandemCommander`:

  ```
  winget install tandemcommander
  winget upgrade tandemcommander
  ```

  It installs for all users, into `Program Files`, and asks for administrator rights exactly as the installer does on its own. Availability depends on Microsoft accepting the submission, which can take a few days after this release; the downloads here and on the website are unchanged and remain the primary channel.

## Changed

- **Source and configuration files no longer open in the built-in text viewer** on F3 — the Code Viewer claims them. The built-in viewer is always one key away on **Alt+F3**, and the Code Viewer hands very large or binary files over to it rather than trying. Which types each viewer takes can be changed in Plugins Manager, as for any viewer plugin.
- **The download and the installed program are noticeably larger** than 0.1.5: the Code Viewer carries the highlighting definitions for all those formats with it, so it needs no internet access and works offline.
- The Configuration dialog remembers which page you used last; because the new page is inserted after *Hot Paths*, that memory is off by one the first time after upgrading, and correct from then on.

## Fixed

- **Environment variables in user-menu arguments expand correctly when the value contains accented characters.** On an account named, for example, *Jiří Novák*, `$[USERPROFILE]` expanded to a path that does not exist and the command failed.

## Known limitations

- **The Code Viewer reads UTF-8, UTF-16 and your Windows code page.** Its F8 encoding menu offers a fixed list of five encodings, not the full conversion table the built-in viewer has. A file in ISO-8859-2, CP852 or a similar single-byte encoding that is not your system's may therefore show wrong accents — open it with Alt+F3 in the built-in viewer, which handles those. This is the largest remaining gap and is the next thing planned for the viewer.
- A file name containing characters your Windows code page cannot represent (Cyrillic on a Central-European system, for example) is still inserted into the command line with `?` in their place — wrong, but visibly wrong instead of silently wrong. Fixing it requires the command line itself to become a Unicode control, which is a separate change.
- How the *contents* of an archive are displayed is unchanged: names with accents inside an archive listing may still be shown incorrectly.
- Unchanged from earlier releases: the HTML help has not been rebranded yet; the **unrar** plugin needs `unrar.dll` and the **FTP** plugin needs OpenSSL, neither of which is shipped; ed25519 SSH keys are not supported by the SFTP plugin.

## Upgrading

- Install over the previous version — settings are preserved, and nothing needs to be reconfigured. Both new features are opt-in in the sense that matters: the Command Shell keeps opening the Command Prompt until you change it, and the Code Viewer simply makes F3 nicer.
- Plugins built for 0.1.0–0.1.5 keep working: the plugin interface is unchanged at 106.
- If you would rather manage the upgrade with `winget`, uninstall this version first and then `winget install tandemcommander`, so that winget owns the installation from the start.

---

Free software under the GNU GPL v2 or later · <https://tandemcommander.org> · full technical detail in `CHANGELOG.md`
