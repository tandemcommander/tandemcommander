# Research: Privacy Statement for the winget Catalogue

Phase 0 of [plan.md](plan.md). Two parts: the decisions that shape the
deliverables (R1–R10), and the evidence-backed **data-surface inventory** that
every sentence of `PRIVACY.md` must trace to (contract C1).

**Method.** Four independent read-only researchers inventoried, in parallel:
(A) the main application, shell extension and installer; (B) the FTP and SFTP
plugins with the core password manager; (C) the WebView2 viewers (mdview,
codeview, `src/common/webhost`); (D) the other 16 enabled plugins plus the
disabled ones. One claim class was re-verified independently by the
coordinator: the import tables of every shipped module of the 0.1.8 Release
tree (`build\tandemcommander\Release_x64`, FileVersion 0.1.8, 2026-09-20),
read with `dumpbin /imports`, filtered for network/crypto DLLs:

| Module | Network-capable imports |
|---|---|
| `tandemcommander.exe` | `mpr.dll` (WNet* — network drives), `netapi32.dll` (NetShareEnum/NetShareDel — local shares), `wsock32.dll` **ordinal 10 only = `inet_addr`** (string parser, `drivelst.cpp:370`) |
| `plugins\ftp\ftp.spl` | `wsock32.dll`, `crypt32.dll` |
| `plugins\sftp\sftp.spl` | `ws2_32.dll`, `bcrypt.dll`, `crypt32.dll` |
| `plugins\mdview\mdview.spl` | `winhttp.dll` |
| the other 22 modules (16 plugins, codeview, helpers) | none |

Shipped plugin folders: 7zip, codeview, dbviewer, diskmap, filecomp, folders,
ftp, checksum, mdview, peviewer, pictview, portables, regedt, renamer, sftp,
tar, uncab, undelete, uniso, zip (20) — no checkver.

---

## Decisions

### R1 — Catalogue field

- **Decision**: add `PrivacyUrl` to the defaultLocale template, after
  `PublisherSupportUrl`.
- **Rationale**: winget-pkgs schema 1.10.0 `defaultLocale.md`: *"PrivacyUrl —
  The publisher privacy page or the package privacy page … Optional Field …
  If there is a privacy web site or specific web page for the package it is
  preferred over a generic privacy page for the publisher."* Its field listing
  places it directly after `PublisherSupportUrl`. The request pattern: 072
  REMAINING-WORK § P0 item 3 (#425232, verified).
- **Alternatives**: none — the field is the catalogue's only privacy slot.

### R2 — Address

- **Decision**: `https://github.com/tandemcommander/tandemcommander/blob/main/PRIVACY.md`.
- **Rationale**: stable across releases, versioned with the code it describes
  (so C8 updates travel with the change), same pattern as the existing
  `LicenseUrl` and Changelog `DocumentUrl` in the template; the schema prefers
  a package-specific page, which this is.
- **Alternatives**: a page on tandemcommander.org — outside the repository,
  drifts independently of the code; a tag-pinned URL — changes every release
  and would describe a frozen version.

### R3 — Generator

- **Decision**: no `publish.ps1` change.
- **Rationale**: the renderer replaces `{{KEY}}` placeholders and strips
  comment lines (`publish.ps1:194-203`); a literal non-comment line passes
  through unchanged.

### R4 — Contact

- **Decision**: public issue tracker for general questions; GitHub private
  vulnerability reporting for sensitive matters (spec FR-009, maintainer's
  choice "C"), gated on the setting being enabled (contract C7).
- **Evidence**: `GET /repos/tandemcommander/tandemcommander/private-vulnerability-reporting`
  → `{"enabled": false}` on 2026-09-30.

### R5 — Scope of "the product"

- **Decision**: installer + program + the 20 enabled plugins. Disabled
  plugins get one sentence ("not distributed"), third-party/self-built plugins
  one sentence (outside the statement).
- **Rationale**: disabled plugins are not compiled and their stale outputs are
  deleted (`src/vcxproj/gen_plugins_filter.ps1:111-121`, called from
  `build.cmd:148`); the installer packages only the Release tree
  (`setup/tandemcommander.iss:110`); the shipped tree has no checkver (table
  above). A user can still load any `.spl` via Plugins Manager → Add
  (`src/dialogs5.cpp:719-803`).

### R6 — Packaging

- **Decision**: `PRIVACY.md` is not installed with the program.
- **Rationale**: the installer packages `build\…\Release_x64\*` only
  (`tandemcommander.iss:106-110`); linking the statement from the program is
  a separate feature (spec Assumptions).

### R7 — Changelog

- **Decision**: no `CHANGELOG.md` entry.
- **Rationale**: the constitution's Release Documentation rule covers changes
  a user of the program experiences; the statement changes no behaviour
  (FR-010) and the changelog feeds the winget ReleaseNotes of a version. A
  later release that changes data handling updates both (C8).

### R8 — Version described

- **Decision**: the statement describes **0.1.8** (the published version,
  tag `v0.1.8`); section "Older versions" notes only the data-handling
  difference: 0.1.0–0.1.7 shipped a separate crash-reporting helper
  (`utils\salmon.exe`) whose upload was disabled since 0.1.0; reports were
  written locally (CLAUDE.md feature 079).

### R9 — Defects found during the inventory

- **Decision**: the statement describes the product **as it is**, including
  the unflattering parts; defects are recorded as follow-ups (§ Side
  findings), not fixed in this feature (single-concern rule; FR-010).
- **Rationale**: FR-005 — a statement that describes intended rather than
  actual behaviour is false. Where a defect exposes data (F1), the statement
  tells the user how to avoid it until it is fixed; when fixed, C8 requires
  the statement to change with it.
- **Alternative rejected**: fixing F1 first and publishing afterwards — it
  couples a documentation change the catalogue is waiting for to a product
  change that needs its own review, build and release.

### R10 — Microsoft components

- **Decision**: attribute, don't characterise (C6): the WebView2 runtime's
  diagnostic data and crash dumps are governed by Microsoft and Windows
  diagnostic-data settings; say that the program does not change them.
- **Evidence**: Microsoft Learn, *Data and privacy in WebView2*
  (<https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/data-privacy>):
  runtime diagnostic data follows Windows *Diagnostics & feedback*; crash
  dumps are sent to Microsoft unless the host sets
  `IsCustomCrashReportingEnabled` — the product does not set it (no hits in
  `src/`).

---

## Data-surface inventory

`HKCU\…\0.1` = `HKCU\Software\Tandem Commander\0.1`. "Plugin key" =
`HKCU\…\0.1\Plugins Configuration\<NAME>` (`mainwnd2.cpp:607`,
`plugins1.cpp:2839`). **Uninstall removes none of the per-user surfaces below**
— `tandemcommander.iss` has no `[Registry]`, no `[UninstallDelete]`, no
uninstall `[Code]`; it removes only installed files and its own uninstall key.
Statement sections refer to contract C2.

### Stored on the user's computer

| id | Component | Data | Where / when | Protection | Evidence | § |
|---|---|---|---|---|---|---|
| cfg-main | app | all settings: window layout, panel paths, view/sort/filter, panel tab list (may include archive/FTP/SFTP locations), per-drive last dirs, hot paths, user menu commands, viewer/editor/archiver config, command shell | `HKCU\…\0.1\…`; on exit (Save On Exit default on) or Save | none | `mainwnd2.cpp:159,185-203,1215-1253,7138`; `dialogs4.cpp:273` | 2 |
| hist-main | app | histories: find masks/look-in/grep text, select masks, copy/move targets, change dir, viewer find, command line, file lists, new dir, rename, filters | `HKCU\…\0.1\Configuration\…`; only if Save History (default on); cleared when off; Clear History button | none | `mainwnd2.cpp:1946-1981`; `salamdr2.cpp:2662-2684`; `dialogs4.cpp:297-300,4222-4255` | 2, 8 |
| hist-workdirs | app | working-directory list | `Configuration\Working Directories`; only if Save Working Dirs (default **off**) | none | `mainwnd2.cpp:1983`; `dialogs4.cpp:298` | 2 |
| viewer-find | app | internal viewer's last search text | `Viewer\Find Text`; always (not tied to Save History) | none | `mainwnd2.cpp:2028` | 2 |
| pwd-verifier | app | master-password flag + 42-byte verifier (salt, encrypted random, MAC); master password itself never stored, held in memory for the session | `HKCU\…\0.1\Password Manager` | — | `mainwnd2.cpp:1397-1401`; `pwdmngr.cpp:820-860`; `pwdmngr.h:86-98` | 3 |
| cfg-export | app | full configuration incl. Password Manager and plugin keys (only `*.hidden` excluded) | .reg file where the user saves it; default folder `%APPDATA%\Tandem Commander` (created); user action | as stored | `mainwnd3.cpp:3139-3182`; `salamdr2.cpp:2893-2915`; `reglib/src/reginmem.cpp:606-630` | 2, 8 |
| cfg-import | app | reads `config.reg` beside the exe or in `%APPDATA%\Tandem Commander` | every start | — | `salamdr1.cpp:3601-3610` | 2 |
| crash-report | app | text report: exception, registers, call stacks with arguments (file paths), 28-byte memory samples at ~100 addresses, window messages, per-panel path/archive/plugin path/focused file name, loaded modules with paths, plugin list, time, uptime, exe path, **full command line**, locale, OS/CPU/memory, admin/integrity/remote-session, every drive's **volume label, serial number**, device target; no explicit user/computer name, but profile paths usually contain the user name | `%LOCALAPPDATA%\Tandem Commander\TC<ver>-YYYYMMDD-HHMMSS[-n].TXT`; only on a crash or Break; never deleted by the program; never sent (message: "Nothing is sent anywhere") | none | `callstk.cpp:673,724-760,783`; `bugreprt.cpp:810-860,1413-1565,1696-1745,2407-2540`; `common/salbugreport.cpp:46` | 2, 8 |
| temp-cache | app | `SAL<hex>.tmp` folders (archive/plugin extraction, user-menu batch files), `PACK*.tmp`, `MFL*.tmp`; files opened from archives/FTP/SFTP with F3 | `%TEMP%` (or configured root); removed when released / at exit; crash leftovers → delete prompt next start | none | `salamdr3.cpp:213-290`; `cache.cpp:90-111,1197,1476-1556`; `salamdr1.cpp:4585-4588` | 2 |
| jumplist | app | visible hot paths (name + path) as taskbar Tasks | kept by Windows; rebuilt at start | — | `jumplist.cpp:226-280,313-321`; `salamdr1.cpp:4522` | 2, 8 |
| shellext-reg | app | copy-hook shell extension COM registration — **not performed in the shipped 0.1.8**: the program registers only if `utils\salextx86.dll`/`salextx64.dll` exist (`FileExists` gate), and neither is shipped (installed `utils\` holds only `sqlite.dll`). Corrected after T010; originally recorded as "written at every start" | — | — | `salamdr1.cpp:4384-4398`; installed tree | — (not disclosed: does not occur) |
| restart-reg | app | Restart Manager registration, command line `-t`/`-i` only | at start | — | `mainwnd3.cpp:616` | 2 |
| plugin-cfg | 20 plugins | each plugin's settings; plugin histories only while Save History is on (dbviewer find, filecomp recent pairs, pictview recent files/folders + Copy To targets + last Save As dir, regedt last key + histories + external editor, renamer patterns/histories); none stores passwords except FTP/SFTP | plugin key; written with the configuration; removing a plugin in Plugins Manager deletes its key | none | D: `dbviewer.cpp:487,540-553`; `filecomp.cpp:331-397`; `pictview.cpp:691,898-974`; `regedt.cpp:359-402`; `crenamer.cpp:193-204`; `renamer.cpp:342-348`; `zip/main.cpp:397-489`; `plugins1.cpp:2830-2858` | 2 |
| plugin-temp | 7zip, peviewer, regedt, tar, uniso, zip, undelete | temp files while updating/viewing; undelete: user-chosen temp folder, viewed files copied off the scanned volume | `%TEMP%` / chosen folder | none | D: `7zclient.cpp:650,1112`; `peviewer.cpp:392-402`; `regedt dialogs.cpp:770`; `tardll.cpp:513`; `uniso.cpp:913`; `zip add.cpp:925`; `undelete fs2.cpp:1393-1410` | 2 |
| regedt-lastkey | regedt | writes regedit's own `LastKey` on "Open in Regedit" | `HKCU\…\Applets\Regedit`; user action | — | D: `fs5.cpp:1108-1119` | 2 |
| sftp-bookmarks | sftp | name, address, port, user, login method, **private-key file path** (key contents never stored), initial/local paths, compression | plugin key `Bookmarks\<n>` | none | B: `sftp.cpp:71-85,472-497`; `session.cpp:535-566,672` | 2 |
| sftp-secrets | sftp | password / key passphrase, only if "Save password/passphrase" ticked, bookmarks only | `PasswordE`/`PassphraseE` (AES, master password) else `PasswordS`/`PassphraseS` (scramble); cancelled master prompt → scramble | see pwd-* | B: `dialogs.cpp:732-738,816-818,851-856`; `sftp.cpp:481-492` | 3 |
| sftp-hostkeys | sftp | host, port, key type, public key, SHA256 fingerprint | plugin key `Known Hosts\<n>`; on "Trust"; no UI to remove | none | B: `sftp.cpp:87-91,680-698`; `hostkeys.cpp:67-175` | 2 |
| sftp-memory | sftp | password in memory for reconnects while the connection exists; log in memory only (host, user, IP, fingerprints, paths, errors; no passwords), lost on exit | memory | — | B: `fs.cpp:276-287,527-565`; `session.h:77-80`; `logs.cpp:45-266` | 4 |
| ftp-bookmarks | ftp | name, address, initial path, anonymous flag, user, proxy id, target path, port, server type, **initial FTP commands and list command (plain text)**, FTPS flags | plugin key | none | B: `ftp.cpp:126-153,1662-1734` | 2 |
| ftp-secrets | ftp | bookmark password only if "Save password"; proxy passwords | `PasswordE` (AES) else `PasswordS` (scramble) | see pwd-* | B: `ftp.cpp:155-167,803-823`; `ftp2.cpp:2495-2535` | 3 |
| ftp-anon | ftp | anonymous-login e-mail, default `name@someserver.com` | plugin key `Anonymous Password`, **plain text** | none | B: `ftp3.cpp:508`; `ftp.cpp:731-732` | 2, 4 |
| ftp-history | ftp | command, host-address, init-path histories; commands sent as "Secret" excluded; **the Address history stores the typed text verbatim — `ftp://user:password@host` puts the password there in plain text (F1)** | plugin key; only if Save History (default on); Clear History empties | **none** | B: `ftp.cpp:454-480,861-865,1021-1041`; `dialogs1.cpp:926-932`; `ftputils.cpp:530`; `dialogs8.cpp:163-168` | 2, 3 |
| ftp-logs | ftp | commands, replies, file names; passwords shown as "(hidden)"; memory only unless the user saves/copies | memory; file/clipboard on user action | — | B: `ftp3.cpp:540-544`; `ftp2.cpp:1634-1708`; `ctrlcon2.cpp:1998-2213` | 2 |
| pwd-aes | app (for ftp/sftp) | AES-256 (WinZip-AE style), PBKDF2-HMAC-SHA1 ×1000, 16-byte per-password salt (from `rand()` seeded with time^pid — weak, F6), 10-byte HMAC-SHA1 | — | — | A/B: `pwdmngr.cpp:21-47,552-566`; `fileenc.h:59`; `pwd2key.c:45-63` | 3 |
| pwd-scramble | app (for ftp/sftp) | fixed substitution table + offsets + padding — reversible by anyone with the (public) source | — | obfuscation only | `pwdmngr.cpp:57-114,568-575`; `pwdmngr.h:76-77` | 3 |
| wv2-udf | mdview, codeview | WebView2 engine profile: caches, code cache, cookie/history/storage databases (internal addresses only — `https://mdview.invalid/doc.html?v=N`, `https://codeview.invalid/…`; no file names), engine crash folder, GPU caches; autofill/password saving off | `%LOCALAPPDATA%\Tandem Commander\WebView2`; first view; never cleared; left on uninstall; pre-065 `mdview.WebView2` folder deleted by the janitor | none | C: `webhost.cpp:58-70,250-251,588-602`; `webkeeper.cpp:211-213`; `mdview webglue.cpp:266-303` | 2, 5, 8 |
| viewer-cfg | mdview, codeview | display settings, window placement, keep-ready flag; no recent files, no positions per document, no stored renderings | plugin keys `MDVIEW`, `CODEVIEW` | none | C: `mdview.cpp:36-44,147-184`; `codeview/config.cpp:42-171` | 2 |

### Transmitted over the network

| id | Component | Recipient | What they receive | Trigger | Evidence | § |
|---|---|---|---|---|---|---|
| net-none-core | app | — | the program itself opens no connection: no telemetry, update, licence or crash upload | — | A: no WinHTTP/WinINet/URLMon/BITS/sockets in core; import table (above) | 1, 4 |
| net-drives | app | the file server the user opens (via Windows) | credentials typed into the **Windows** prompt/CredUI; saving is Windows' choice; program stores nothing, wipes buffer | user opens a disconnected drive / UNC path | A: `drivelst.cpp:88-105,545-660` | 4, 5 |
| net-browser | app, plugins | tandemcommander.org, github.com/tandemcommander/…, language module web (`www.tandemcommander.org`), plugin home pages (tandemcommander.org; **pictview → pictview.com**, About also `mailto:support@pictview.com`), SFX link in created archives | whatever the user's browser sends | click only | A: `logo.cpp:497`; `mainwnd3.cpp:2854`; `dialogs2.cpp:882,1112`; `dialogs5.cpp:229-230`; D: `pictview.cpp:601`; `pictview dialogs.cpp:130-136`; `zip prevsfx.cpp:87` | 4 |
| net-mail | app | the user's mail client (MAPI, with dialog) | selected files, only if the user sends | "Email files" | A: `mapi.cpp:178-181` | 4 |
| net-ftp | ftp | the server (or the user's proxy/firewall) the user entered; DNS via system | **plain FTP: user name, password and data unencrypted**; anonymous: `anonymous` + configured e-mail; HTTP proxy password Base64 (not encryption); no client identification (`SYST` only); FTPS unavailable in this build (OpenSSL DLLs not shipped → connection stops with an error before login) | user connects | B: `sockets.cpp:745,1264-1269`; `ftputils.cpp:7`; `fs2.cpp:429-518`; `ctrlcon1.cpp:621-625,1817-1823`; `ssl.cpp:769-785`; `ctrlcon2.cpp:63` | 4 |
| net-sftp | sftp | the host the user entered; DNS via system; no proxy | SSH-encrypted session; client banner `SSH-2.0-libssh2_1.11.1_DEV`; host-key prompt on first connect/change (Trust/Once/Cancel) | user connects | B: `session.cpp:185,487-524,676-771`; `libssh2.h:51,251-253` | 4 |
| net-mdview-img | mdview | the image's host (system/auto proxy) | `GET` of the image URL, User-Agent **`OpenSalamander-mdview`**, no referrer, no added cookies; host sees IP, time, UA, URL; http allowed; refetched on re-render; ≤ 32 MB | only after *View > Load Remote Images*, per window, never persisted | C: `webglue.cpp:79-148,178-219`; `mdview/viewer.cpp:394,956`; `htmlgen.cpp:105,279-286` | 4 |
| net-mdview-links | mdview | user's browser / mail client | `http`/`https`/`mailto` links handed to the shell | link activation (see F3) | C: `mdview/viewer.cpp:725-792` | 4 |
| net-viewers-blocked | mdview, codeview | — | every other page request is 403'd; CSP `default-src 'none'`; navigation cancelled; downloads cancelled; permissions denied; codeview assets all embedded | — | C: `webhost.cpp:136-143,179-181,266-300,318-359`; `codeview/webglue.cpp:82-114` | 4 |
| net-wv2-ms | WebView2 runtime | Microsoft | runtime diagnostic data per Windows settings; engine crash dumps (not opted out); runtime updates; program sets `--disable-background-networking --disable-sync --disable-component-update`, SmartScreen off | governed by Microsoft | C: `webhost.cpp:47-48,237-261`; Microsoft Learn (R10) | 5 |
| net-portables | portables | the connected USB device (local) | program identifies itself to the device with product name + version | user browses a device | D: `device.cpp:182-186` | 4 |
| net-archivers | external archivers | per third-party program | — | only if the user configures RAR/ARJ/ACE/… | D: `packers.cpp:38-45`; `pack1.cpp:50-53` | 5 |
| net-installer | installer | — | downloads nothing; `AppPublisherURL`/`AppSupportURL`/`AppUpdatesURL` are metadata only | — | A: `tandemcommander.iss` (no [Registry], no downloads) | 7 |

---

## Side findings — out of scope, to be recorded as follow-ups

Recorded in `specs/NEXT-WORK.md` during implementation; none is fixed by
this feature (R9).

- **F1 — a password typed as part of an address is saved in plain text** —
  FTP Quick Connect Address history (`dialogs1.cpp:926-932`,
  `ftputils.cpp:530`), Change Directory history (`dialogs3.cpp:1200-1202`,
  found by T010) and the command-line history. Highest priority: the only
  path by which a password reaches the registry unprotected without the user
  choosing "save password".
- **F2 — mdview remote-image request**: User-Agent `OpenSalamander-mdview`
  (pre-rebrand); the comment at `webglue.cpp:79` says "no cookies" but
  WinHTTP's session cookie handling is not disabled; HTTP status not checked.
- **F3 — possible navigation without a click**: raw HTML passes through
  (`htmlgen.cpp:514`) and `ActivateLink` does not require a user gesture, so a
  `<meta http-equiv="refresh">` would probably open the default browser at an
  arbitrary `http(s)` address. Needs a GUI test; if confirmed, the statement's
  wording about links must change (C8).
- **F4 — WebView2 engine crash dumps go to Microsoft** by default
  (`IsCustomCrashReportingEnabled` not set) — a product choice to make
  consciously.
- **F5 — `architecture/11-webview2-integration.md:59-60`** says the user data
  folder "holds cache only"; it also holds cookie/history/storage databases.
- **F6 — password-manager salt** from `rand()` seeded with time^pid
  (`pwdmngr.cpp:37-47`).
- **F7 — SFTP**: a cancelled master-password prompt silently saves the secret
  scrambled only (`dialogs.cpp:851-856`).
- **F8 — withdrawn after T010.** The shell-extension registration is gated
  on `utils\salext*.dll` existing (`salamdr1.cpp:4384-4398`), which 0.1.8 does
  not ship — nothing is registered, so nothing is left behind. (Whether the
  copy hook's absence is intended is a separate question.)
- **F9 — the FTP anonymous e-mail default** `name@someserver.com` is sent to
  anonymous servers (harmless placeholder, but it is sent).

## Could not establish (stated in the document as such, or left out)

- What Microsoft's runtime diagnostic data contains — attributed (C6).
- Whether Windows Credential Manager saves a network-drive password — the
  user's choice in a Windows dialog; attributed to Windows.
- F3 behaviour at runtime.

(Resolved during Phase 0: the 0.1.8 installation on the maintainer's machine,
`C:\Program Files\Tandem Commander\plugins\`, holds exactly the 20 enabled
plugins — no checkver; `utils\` holds only `sqlite.dll`, no `salmon.exe`.)
