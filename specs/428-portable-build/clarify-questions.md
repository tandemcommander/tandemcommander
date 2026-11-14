# Feature 428 — questions for the interactive clarify session

The maintainer asked (2026-11-14) that every ambiguity of the portable build goes to an
interactive `/speckit-clarify` session and that the questions are prepared in detail. This is the
catalogue. Each question has the context (facts measured in
[state-inventory.md](state-inventory.md)), the options, and a **recommendation**; `spec.md` uses
the recommendation as its provisional answer and cites the question as **(Q-nn)**.

Suggested order for the session: block A first (it decides the shape of the whole feature), then
B, C, D, E. The questions marked **★** change the scope or the effort most; the rest can take the
recommendation if time is short. `/speckit-clarify` asks at most five questions per pass by
default — run it in several passes or ask it to go through this catalogue in order.

## Status

| Pass | Date | Answered (recorded in `spec.md` → *Clarifications*) |
|------|------|------------------------------------------------------|
| 1 | 2026-11-14 | Q-07 A (separate exe fixed at build time) · Q-01 / Q-02 / Q-03 (WebView2 part) A with the folder named `settings` (lower-case), WebView2 data in `%TEMP%`, deleted at exit — measured: caches only · Q-13 / Q-14 A (check as installed, link only, ZIP asset required) · Q-21 / Q-22 B (badge icon, separate taskbar group) · Q-05 A (never registered, a message instead) |

| 2 | 2026-11-14 | Q-09 A (unwritable: start, warn once, never save elsewhere) · Q-11 A (each portable folder its own world) · Q-12 A (no new command; export / import only; Salamander import in the menu, no first-start offer) · Q-17 A (paths inside the folder stored as `$(SalDir)\…` automatically) · Q-26 A (`tandemcommander-<ver>-x64-portable.zip`, top folder `TandemCommander-<ver>-portable\`) |

| 3 | 2026-11-14 | Q-29 A (ZIP mandatory in every release) · Q-19 A (`[portable]` untranslated) · Q-20 B (About: edition line + `settings` link; splash unchanged) · Q-16 B (one-time password note) · Q-24 / Q-25 A (Debug + Release, `<Config>_x64_portable\`, ZIP only with `full release`) **+ the maintainer's addition: `build.cmd dist` builds and signs the whole release (installer + ZIP) in one command** |

**Still open** (low impact; the recommendations above stand unless the maintainer says otherwise):
Q-28 (README, licences in the ZIP), Q-03 (human-readable configuration?), Q-04 (jump list off,
icon-size write skipped), Q-06 (wallpaper bitmap in the Windows profile), Q-08 (export / backup
defaults in `settings`), Q-10, Q-15, Q-18, Q-23, Q-27, Q-30 (winget out of scope), Q-31, the
`config.reg` sub-question of Q-07 (ignored). Also the name `dist` for the one-command release.

---

## A. The shape of the portable mode

### Q-07 ★ How does a program know it is portable — fixed at build time, or a marker next to the exe?

The request says `build.cmd … portable` builds the portable version. That can mean two things:

| Option | What it means | Implications |
|--------|---------------|--------------|
| **A** | Build-time: the portable build compiles a different `tandemcommander.exe` (portable always, cannot be otherwise). | Two different executables per release, two sets of signatures; an installed exe can never become portable by accident; the portable exe can never use the registry. Tests run twice for the shared code. |
| **B** | Run-time marker: one executable for both; a marker file next to it (e.g. `portable.ini` or the settings folder itself) switches it to portable mode; `build.cmd portable` only packages the normal program with the marker into a ZIP. | One binary, one signature, the ZIP is a repack of the signed tree; a user could turn an installed copy portable (or the reverse) by adding / removing the marker — FR-018 then needs a rule (the installer's folder ignores the marker?). Common pattern among portable apps. |
| **C** | Both: the build stamps the edition into the exe (title, About, update behaviour), and the settings location is still found by the marker. | Most robust identification, but the most complex. |

**Recommendation: A** — it matches the request (a *build* mode), keeps the installed program
provably unchanged (FR-018, constitution II), and the program never has to guess.

Related: the upstream start-up import of `<exe>\config.reg` (inventory §4) — in the portable copy
**ignored** (recommended), or used once as the seed of a fresh portable configuration?

### Q-01 ★ One settings file, or a folder?

What lives there (FR-005): the whole configuration with every plug-in's settings, histories,
bookmarks, passwords — today a registry tree. Plus files (FR-007): the web-viewer data (WebView2,
typically tens of MB, many files), bug reports, import backups, the wallpaper image.

| Option | What it means | Implications |
|--------|---------------|--------------|
| **A** | A folder (e.g. `Settings\`) next to the exe; inside it the configuration as one file plus sub-folders for the web-viewer data, bug reports, backups. | Everything in one visible place; the web-viewer data cannot be a single file anyway. |
| **B** | One configuration file next to the exe (e.g. `tandemcommander.settings`) and the other files in a separate folder. | The configuration is one file to copy / back up; two things next to the exe. |
| **C** | One file only; the web-viewer data in `%TEMP%` (thrown away), no bug reports kept. | Strictly "one file", but the web viewers lose their state and the program writes outside its folder (temp). |

**Recommendation: A**.

### Q-02 Name of the settings location

Options: `Settings\` · `Data\` · `Config\` · `TandemCommander.data\` · your own. The name is visible
to users and appears in the About box (FR-015) and in `PRIVACY.md`.
**Recommendation: `Settings\`** (the same word as the registry root `…\Tandem Commander\Settings`).

### Q-03 Must the configuration be human-readable / editable by hand?

| Option | What it means | Implications |
|--------|---------------|--------------|
| **A** | A text file (e.g. the `.reg` format the program already reads and writes for *Export Configuration*). | Users can read, diff and fix it; saving rewrites a text file (size: the configuration is a few hundred KB of text); every plug-in's settings must pass through the program's text writer. |
| **B** | An opaque file that the program uses exactly like a registry tree (a private registry hive file of Windows, loaded only by this program, never visible in the system registry). | Plug-ins that use their registry handle directly keep working untouched (inventory §1 — FTP, nethood, automation do); not editable in Notepad (Export Configuration still gives a readable copy). |
| **C** | No requirement — the plan decides. | |

**Recommendation: C** with a note: the plan should prefer whatever keeps third-party plug-ins
working unchanged (FR-009). (This question is a *what*: does the maintainer need to edit the file
by hand?)

Also in this block: should the transient `%TEMP%` use (archive extraction cache, list files) move
into the portable folder (`Settings\Temp`)? **Recommendation: no** — it is transient, cleaned up,
and a USB stick is slow; FR-007 allows it.

### Q-05 ★ The shell extension (dragging from archives / plug-in file systems to Explorer)

The copy-hook extension is registered at every start by writing `HKCR\CLSID\…`,
`directory\shellex\CopyHookHandlers\…` (fallback `HKCU\Software\Classes`) and HKLM *Approved*
(inventory §1, §3). Without it, dragging or copying from a ZIP panel or a plug-in file system
(FTP, SFTP, …) to Explorer silently does nothing.

| Option | What it means | Implications |
|--------|---------------|--------------|
| **A** | Never registered in the portable copy; the action shows a message that it is unavailable in the portable edition (instead of silently doing nothing). | Truly no registry writes. One feature missing. |
| **B** | An opt-in in Configuration ("integrate with Explorer — writes to the registry"), off by default, removed again on exit. | The feature can be had; the "never touches the registry" promise becomes "unless you switch this on"; removal on exit fails after a crash. |
| **C** | Never registered, silently (as today when the DLL is missing). | Least work; confusing. |

**Recommendation: A**. To verify in the plan: whether the Release tree ships `utils\salext*.dll`
at all today (it was missing from the local build tree).

### Q-04 Windows' own traces and transient writes

- **Jump list** (taskbar right-click recent / tasks): Windows stores it in the profile. Keep (Windows'
  bookkeeping), or switch the program's jump list off in the portable copy?
  **Recommendation: switch it off** — it is the program's own contribution, and its entries would
  point to paths of a stick that is gone.
- **Restart Manager registration** (restart after a Windows update): held by the OS, nothing
  persistent. **Recommendation: keep.**
- **The icon-cache refresh** temporarily changes `HKCU\Control Panel\Desktop\WindowMetrics\Shell
  Icon Size` and restores it (inventory §1). **Recommendation: skip it in the portable copy** (a
  registry write, even a transient one, breaks SC-002).
- Prefetch, recent documents, Explorer view state, MOTW: out of scope (cannot be prevented).

### Q-06 PictView *Set as wallpaper*

It writes the Windows wallpaper settings by the user's explicit request, keeps a bitmap in
`%LOCALAPPDATA%` and remembers the previous wallpaper in `HKCU\Control Panel\Desktop`.

| Option | Implications |
|--------|--------------|
| **A** Allowed (it is the user's explicit request to change Windows); the bitmap and the previous-wallpaper record go into the portable folder. | Works; the wallpaper bitmap must stay where Windows can read it — if the stick is removed, Windows loses the wallpaper. |
| **B** Allowed; the bitmap goes to the Windows profile (it is Windows' wallpaper now). | Works after removing the stick; a file outside the portable folder (FR-007 exception). |
| **C** Disabled in the portable copy. | Simplest; a feature missing. |

**Recommendation: B** — the wallpaper belongs to Windows once set; document the exception.

### Q-08 Default folders for *Export Configuration* and the import backups

Today `%APPDATA%\Tandem Commander` (export default, `config.reg` fallback) and
`%APPDATA%\Tandem Commander\Settings backups` (before a 245 import).
**Recommendation: inside the portable settings location** (`Settings\Backups`, export default
`Settings\`), the user can still pick any folder.

---

## B. Behaviour in situations specific to a portable copy

### Q-09 ★ The folder cannot be written

| Option | Implications |
|--------|--------------|
| **A** Start with the saved (or default) settings, say once that changes cannot be saved, never save anywhere else. | Works from read-only media, e.g. a write-protected stick or CD. |
| **B** Refuse to start with a message. | Simplest; useless on read-only media. |
| **C** Offer to save the settings to a folder the user picks. | Flexible; more UI. |

**Recommendation: A.** Same message when a save fails later (stick removed, disk full); the last
complete settings stay intact (FR-010).

### Q-10 A portable folder on a network share used by several people or PCs at once

**Recommendation: no special support** — it works like two instances on one PC (last save wins);
documented. Alternative: a lock that makes the second user's copy read-only (option A of Q-09).

### Q-11 ★ Instances: *Only one instance*, inter-process names, update locks

Today the program finds "another instance" and shares locks by fixed names
(`Local\TandemCommanderUpdateCheck`, the configuration save mutex, the legacy-session mutex, the
single-instance check). An installed copy and a portable copy — or two portable copies on two sticks
— running at the same time:

| Option | Implications |
|--------|--------------|
| **A** Each portable folder is its own world: its instance check, save lock and the *Only one instance* option see only copies started from the same folder. | Installed and portable never interfere (SC-007); two copies of the same folder still coordinate their saves. |
| **B** Portable and installed are the same "program": *Only one instance* in one activates the other. | Starting the portable copy may just bring the installed one to front — confusing. |

**Recommendation: A.**

### Q-12 ★ Moving settings between an installed and a portable copy; the Salamander import

- At the first start of a portable copy on a PC where Tandem Commander is installed: **offer to copy
  the installed copy's settings** into the portable one (read-only on the registry), or start
  fresh?
- The reverse (portable → installed): only via *Export Configuration* + *Import* (exists), or a
  dedicated command?
- The 245 settings import from Altap / Open Salamander reads their registry keys read-only: keep it in
  the portable copy (menu and first-start offer), keep it only in the menu, or hide it?

**Recommendation:** first start of a fresh portable copy offers nothing automatically (a portable
copy is often started on a stranger's PC); the menu gets *Import Settings from the Installed Tandem
Commander* only if you want it (otherwise out of scope); the Salamander import stays in the menu, the
first-start offer is dropped in the portable copy; portable → installed via the existing export /
import.

### Q-13 ★ The new-version check in the portable copy

Today (123, 420-422): a check at start-up (on by default, about once a day, one HTTPS request to
GitHub), a notification, download and install for installed copies only — a copy without the
installer's uninstall entry is already "notify only" and says it cannot update itself.

| Option | Implications |
|--------|--------------|
| **A** Check as today (default on); the notification links to the release page (where the ZIP is); no download. | Users learn about updates; the portable copy contacts the internet without being asked (as the installed one; `PRIVACY.md`). |
| **B** Check off by default, can be switched on; otherwise as A. | A portable copy started on someone else's PC stays silent on the network; most users never learn about updates. |
| **C** No check at all in the portable copy (option, menu item and About line removed). | Simplest; no network contact at all. |
| **D** Full self-update of the portable copy (download the new ZIP, replace the files next to the exe, restart). | The best experience; a new mechanism (the ZIP must be verified as the installer is — signature of the files inside, 420's proof); replacing files of a running program on a stick; large scope. |

**Recommendation: A** now; D as a possible later backlog item. Also: the notification must then
link to the portable download — today the check offers a release only when it has the *installer*
asset; should it require the portable ZIP asset for the portable copy (Q-29)? **Recommendation:
yes, require the ZIP asset**, so a release without the ZIP is not offered to portable users.

### Q-14 Configuration > General in the portable copy

With Q-13 A the *When a new version is found* levels that install (download and offer, install
automatically) make no sense. **Recommendation:** show only the check on / off option; the level
list is hidden (or disabled with a note "the portable edition is updated by downloading a new
archive").

### Q-15 *Save configuration on exit* default

Today on by default. A portable copy on a stick that is pulled out without closing the program, or
on a PC where you do not want traces, may want it otherwise. **Recommendation: same as installed
(on)** — no difference without a reason.

### Q-16 Saved passwords on a stick that can be lost

Passwords saved by the program are protected only by the optional master password (not bound to
the machine or Windows account — that is what makes them portable). Options: **A** as today
(master password optional); **B** in the portable copy, saving a password without a master
password asks once / warns; **C** the portable copy requires a master password before saving any
password.
**Recommendation: B** (a one-time note when the first password is saved without a master password).

### Q-17 ★ Paths into the portable folder after a move (drive letter changes)

A stick is `E:` on one PC and `F:` on another. Paths stored in the settings that point into the
portable folder — plug-in DLLs, a user-menu item running a tool kept on the stick, an external
viewer / editor / archiver, hot paths, panel paths at exit, the custom icon / toolbar files —
break.

| Option | Implications |
|--------|--------------|
| **A** The program stores paths inside its own folder relative to it, automatically (and resolves them at start); paths elsewhere stay absolute. | Moves just work; a rule for what counts as "inside" (case, short names, `..`). |
| **B** Only plug-ins and the program's own files are relative; user-entered paths are as typed (the user can use the existing `$(SalDir)`-style variables where they exist). | Less magic; users must know the variables. |
| **C** Only plug-ins. | Minimal; user menu / viewers break after a move. |

**Recommendation: B**, plus: panel paths and hot paths that point to a drive that no longer exists
fall back as they do today for a missing drive. (The plan checks which variables exist.)

### Q-18 The folder moved or renamed while the program runs

**Recommendation: not supported**; the program keeps working with what it has and the save fails
with Q-09's message; the next start in the new place works.

---

## C. How the portable copy presents itself

### Q-19 The title marker

Options: `Tandem Commander 0.3.0 [portable]` · `Tandem Commander Portable 0.3.0` · `Tandem
Commander 0.3.0 (portable)` (matching the existing `(Administrator)` suffix). Translated in every
language or the same English word everywhere? Shown also in the tray tooltip and the taskbar (they
reuse the title).
**Recommendation:** `Tandem Commander 0.3.0 [portable]`, the word translated with the other UI
strings (pinned in `ui-overrides.json` so DeepL does not paraphrase), before `(Administrator)` when
both apply.

### Q-20 The About box

Options: **A** a line "Portable edition" under the version; **B** A plus the settings location as a
clickable link that opens it in the panel; **C** the version line reads "0.3.0 portable". Also the
splash screen?
**Recommendation: B**, the splash unchanged.

### Q-21 ★ A different icon?

| Option | Implications |
|--------|--------------|
| **A** Same icon. | No brand work; the title tells them apart. |
| **B** The same icon with a small badge (e.g. a USB-stick or an arrow corner) in all sizes, light and dark. | Instantly recognisable on the taskbar and in Explorer; new brand assets in every size (`tools/brand/`). |
| **C** A different colour of the same mark. | Recognisable; may look like another product. |

**Recommendation: B** if the brand work is acceptable in this feature, otherwise **A** with B as a
later backlog item. Only the program icon — toolbar / menu icons are unchanged.

### Q-22 Taskbar grouping

Windows groups windows by the application identity; an installed and a portable copy would share one
taskbar button and pinned items. **Recommendation:** a separate identity for the portable copy so
they are separate buttons (pinning the portable copy pins *that* executable).

### Q-23 Version resources

The file's properties (Explorer > Properties > Details): product name `Tandem Commander` with
file description `Tandem Commander (portable)`? Same version numbers. **Recommendation:** product
name unchanged, description marks the portable edition (only with Q-07 A; with B the exe is the same).

---

## D. Build

### Q-24 Argument combinations

- `portable` with Debug (without `release`): allowed (the maintainer tests the mode on a Debug build)
  or only Release? **Recommendation: allowed**; the ZIP is produced only with `release`.
- Does `portable` imply `full` (plug-ins, languages, runtime data are needed for a usable package)?
  **Recommendation: the ZIP requires `full`; `build.cmd portable` alone builds the portable
  binaries incrementally for development.**
- `portable setup` → error (recommended). `portable sign` → signs the portable tree and the files in
  the ZIP.
- One run builds both the normal and the portable program, or only portable? **Recommendation: only
  portable** (one `build.cmd` run = one edition).

### Q-25 Where the output goes

**Recommendation:** tree `build\tandemcommander\Release_x64_portable\` (Debug:
`Debug_x64_portable\`), the ZIP in `setup\output\` next to the installer (both are release assets).

### Q-26 ★ The ZIP: name and layout

- Name: `tandemcommander-<ver>-x64-portable.zip` (the installer is `…-x64-setup.exe`; the update
  check builds names from this pattern).
- Top-level folder inside the ZIP (`TandemCommander\…`) or files directly at the root?
  **Recommendation: a top-level folder** `TandemCommander-<ver>-portable\` — unpacking with
  "Extract here" then does not spill 100 files into Downloads.

### Q-27 Downloaded-file warnings

A ZIP from the internet carries the Mark of the Web; Windows' built-in unpacker passes it on to every
file, and SmartScreen may warn at the first start (signed binaries help). Options: document "unblock
the ZIP before unpacking" in the README; nothing; recommend a tool. **Recommendation: document it**
(signed binaries are the real remedy).

### Q-28 Extra files in the ZIP

A `README-portable.txt` (what it is, where the settings are, how to remove it, how to update)? The
licence (GPLv2 — the installer shows it, a ZIP must contain it), `PRIVACY.md`, the changelog?
Leave out the shell extension DLLs (Q-05)?
**Recommendation:** README (in English), the licence texts the installer ships, no shell extension
DLLs.

---

## E. Release and distribution

### Q-29 ★ Publishing the ZIP with a release

Part of every release from now on (an eighth *Release record*; `/tandem-release` and `release.py`
check it; the GitHub release gets two assets), or published only when the maintainer wants?
**Recommendation: every release**, the maintainer's step "build and attach the ZIP" added to
`backlog/RELEASE.md`; the website download page links it (outside this repository).

### Q-30 winget

winget supports portable ZIP packages (a second manifest / package id, e.g.
`PavelStupka.TandemCommander.Portable`). **Recommendation: out of scope** for this feature — a
backlog item after the first release with the ZIP.

### Q-31 Scope of this feature

Everything above in one feature (build, settings store, identity, update behaviour, docs), or the
icon (Q-21 B) and the installed ↔ portable settings transfer (Q-12) as later backlog items?
**Recommendation:** one feature without the badge icon and without the transfer command; both go
to the backlog's *Inbox* if wanted.
