# 076 — Avast false-positive review

**Written**: 2026-09-17 · **Baseline**: `main` at `0f615ad` (0.1.7, build 191,
plus the feature-075 hardening commits) · **Trigger**: a user reported that
Avast "blocked and removed" Tandem Commander and that they "also had a problem
with the installation". No detection name, no Avast version, no file name.

This is an analysis record, not a feature. Nothing in the product was changed.
The two side effects of the session are listed in §7.

---

## 1. Verdict in one paragraph

The most probable cause is **reputation-based blocking of an unknown file**
(Avast *CyberCapture* / *FileRepMalware* / *IDP.Generic*), not a signature
match: every shipped binary is a few weeks old, is signed by a certificate
issued on **2026-08-03** with no accumulated reputation, and is wrapped by an
Inno Setup 7 loader that was itself only released on **2026-07-13**. Two things
in the product make a heuristic verdict *more* likely and are worth fixing:
the main executable **patches kernel32 in memory at every start** (a textbook
inline-hook pattern, §3.2), and the installer **ships no Visual C++ runtime**
although all 25 PE modules need it (§3.3) — the latter is the best explanation
of "a problem with the installation" that has nothing to do with Avast at all.
Everything else that antivirus engines weigh (packing, unsigned files, network
activity at start, autostart, shell extensions, raw disk access at start,
script payloads in resources) was checked and is **not** present (§4).

The reporter's Avast version matters less than it seems (§5): a current Avast
would block the file *because* it is unknown; an old one would rely more on
the heuristics in §3.2. Without the detection name both remain possible.

---

## 2. What was examined

| Item | How | Result |
|---|---|---|
| The exact published artifact | `setup/output/tandemcommander-0.1.7-x64-setup.exe`; SHA-256 `6731E146…F64DD` matches `tools/winget/manifests/0.1.7/…installer.yaml` **and** the GitHub asset re-downloaded today | verified identical |
| Its signature chain | `Get-AuthenticodeSignature`, X509Chain | Valid; *CN=Open Source Developer Pavel Stupka* → *Certum Code Signing 2021 CA* → *Certum Trusted Network CA 2*; SHA-256 RSA-4096; Certum timestamp; policy OID `2.23.140.1.4.1` (CA/B Forum *non-EV* code signing); valid 2026-08-03 → 2027-08-03 |
| A fresh full Release build from HEAD | `build.cmd full release` (40 s incremental, BUILD SUCCEEDED, 20 plugins, 189 language modules) | tree of 357 files / 28 MB |
| A fresh **signed** installer | `setup\build_setup.cmd sign` | 216/216 PE files signed and verified, installer + uninstaller signed (`rebuilt-0.1.7-signed-2026-09-17.exe`, kept in the session scratchpad, SHA-256 `6CBEC836…20B46`) |
| Inno Setup engine of the shipped installers | `Inno Setup Setup Data (7.0.0.3)` string in 0.1.1 … 0.1.7 | all seven releases use the 7.0.0.x engine; the loader is a 32-bit PE32 stub (Delphi linker 2.25, DEP + ASLR, no CFG) |
| Static properties of every shipped PE | `dumpbin /headers /imports /dependents`, section entropy, version resources | §3, §4 |
| Source-level behaviour census | ripgrep over `src/` (vendored deps separated) for 60 APIs antivirus heuristics score | §3.2, §4 |
| Installer script | `setup/tandemcommander.iss` | §3.3, §4 |
| Local Microsoft Defender verdict | `MpCmdRun -Scan -ScanType 3` (engine 1.1.26080.3, signatures 1.459.255.0, age 0 d) on the published installer, the rebuilt installer and the whole Release tree | **no threats** |
| Public evidence | Avast documentation, Inno Setup revision history, upstream Salamander forum, Certum programme | §5, §6 |

Not possible in this session: a VirusTotal lookup of the published hash (the
site needs a browser; the Chrome extension was not connected), a run under
Avast itself, and unpacking the published installer with `innoextract` 1.9
(it does not understand the Inno Setup 7 loader — "Unexpected setup loader
revision: 2"). The rebuilt tree was analysed instead; the source delta since
`v0.1.7` is the eight files of feature 075 (202 insertions), none of which
touches any site discussed here.

---

## 3. Findings, ranked by likelihood of being the reporter's cause

### 3.1 Reputation: everything about the product is new (most likely cause)

Avast's reputation layer blocks files it has "not previously encountered",
quarantines them and uploads them for analysis (CyberCapture — Avast's own
description; the user sees *"Hang on, this file may contain something bad"*
and the file disappears, which matches "blocked and removed"). The
related labels are *FileRepMalware* ("rarely seen on Windows systems") and
*IDP.Generic*. All of the following make Tandem Commander maximally unknown:

- **First public release 0.1.0 in August 2026, seven releases in four weeks**
  (0.1.1 and 0.1.2 on 2026-08-07, 0.1.3 on 08-18, 0.1.4 on 08-19, 0.1.5 on
  08-25, 0.1.6 and 0.1.7 on 08-29). Every release changes the hash of all 216
  PE files and of the installer, so file-level reputation restarts each time.
- **Certificate issued 2026-08-03**, individual non-EV code-signing
  certificate from Certum's Open Source programme. Reputation systems
  (SmartScreen, Avast, AVG) attach reputation to the certificate over time;
  a six-week-old certificate has none. Certum's own material says the
  certificate "supports building SmartScreen reputation" — i.e. it starts
  without it. Non-EV means no immediate SmartScreen pass.
- **Inno Setup 7.0.0.3 loader.** Inno Setup 7.0.2 (the first stable 7.x) was
  released on 2026-07-13, the 7.0.0 beta on 2026-05-18; the installers were
  compiled two to six weeks later. The stub is a brand-new PE that antivirus
  whitelists of "known installer stubs" had barely seen when 0.1.x shipped.
  Inno Setup has a documented history of exactly this: 6.2.1 builds were
  flagged by Defender in May 2022 while 6.2.0 builds were not (innosetup
  group thread); 6.0.3 triggered "Trojan.Dropper"; Avast users reported
  "Win32:Malware-Gen" on Inno installers in 2015–2016.
- **A 8.0 MB executable with entropy 7.96** (solid LZMA compression of
  27 MB of payload). Compressed installers are normal, but for a heuristic
  engine that has never seen the stub or the signer it is one more point.
- **The installer launches the application at the end** (`[Run] … postinstall`)
  and the application immediately starts a second process
  (`utils\salmon.exe`, `HIGH_PRIORITY_CLASS`, inheriting a
  `PROCESS_VM_READ` handle to its parent). Legitimate, but it is exactly the
  moment a behaviour shield is watching a freshly installed unknown binary.

Why this also explains "a problem with the installation": CyberCapture and
the File Shield intercept the Inno Setup temp files (`%TEMP%\is-XXXXXXXXXX.tmp\`)
and the freshly written files under `Program Files`; an install that is
interrupted mid-copy reports an Inno error or leaves a partial tree. The
electron-builder project documented the same symptom class ("various errors
during installation… Avast CyberCapture in the window title") for an
**EV-signed** installer — signing alone does not exempt a file.

### 3.2 A real behavioural trigger in the product: the in-process kernel32 patch

`src/callstk.cpp:76-127` (`PreventSetUnhandledExceptionFilterAux`) does, at
**every** start of `tandemcommander.exe`, in the main thread, unconditionally
(called from the first `CCallStack` constructor, `callstk.cpp:283`):

1. `GetProcAddress(kernel32, "SetUnhandledExceptionFilter")`
2. `VirtualProtect(…, 13, PAGE_EXECUTE_READWRITE, …)` on kernel32's code page
3. `WriteProcessMemory(GetCurrentProcess(), …)` of a 13-byte
   `MOV R11, imm64; JMP R11` trampoline over the function's entry
4. restore protection.

This is an **inline API hook on a system DLL** — the same mechanics EDR and
malware use to detour functions, and the pattern behaviour-based engines
(Avast *Behavior Shield*, Symantec *SONAR*, Defender *ML*) are built to catch.
The technique of manipulating `SetUnhandledExceptionFilter` is catalogued
under *anti-debugging* on unprotect.it. Static scanners see the same thing
in the import table of the release executable: `WriteProcessMemory`,
`VirtualProtect`, `OpenProcess`, `CreateToolhelp32Snapshot`,
`IsDebuggerPresent`, `SetWindowsHookExA`, `GetAsyncKeyState`,
`AdjustTokenPrivileges`, `DeviceIoControl`, `CreateProcessA/W` in one
non-Microsoft, low-prevalence binary. Each has an innocent use here (see §4),
but generic ML verdicts (*Win64:Evo-gen*, *Win64:Malware-gen*, *IDP.Generic*)
score the combination.

Precedent from the same code base: Symantec Endpoint Protection's SONAR
flagged `salamand.exe` as `SONAR.AM.C!g10` ("heuristic detection … based on
suspicious behaviors") on the Altap forum (thread 34225); ALTAP answered
"a problem with your antivirus" and changed nothing.

The comment above the call explains the original motive (2005–2012): a plugin
or shell extension built with a different CRT re-installs its own unhandled
exception filter and MSVC 2005 sanity checks call `UnhandledExceptionFilter`
directly, so crashes bypassed the bug reporter. Today the product ships no
shell extension, all plugins share the same CRT, and the crash reporter has
no upload path. **Recommendation: remove the patch** (keep
`SetUnhandledExceptionFilter(TopLevelExceptionFilter)`; if catching
foreign-filter crashes still matters, `AddVectoredExceptionHandler` is the
supported way). Cost: one function and one call; benefit: the single most
suspicious runtime behaviour disappears, and `WriteProcessMemory` /
`VirtualProtect` leave the import table.

### 3.3 The installer ships no Visual C++ runtime (a real install failure, unrelated to Avast)

Every one of the 25 shipped PE modules links the CRT dynamically
(`RuntimeLibrary = MultiThreadedDLL` in `sal_release.props` and
`plugin_release.props`): `tandemcommander.exe` imports **VCRUNTIME140.dll,
VCRUNTIME140_1.dll, CONCRT140.dll** and nine `api-ms-win-crt-*` forwarders;
`7zip.spl`, `codeview.spl`, `filecomp.spl`, `mdview.spl` additionally need
**MSVCP140.dll**; all 20 plugins, `salmon.exe`, `7za.dll`, `sqlite.dll`,
`exif.dll`, `7zwrapper.dll` need VCRUNTIME140.

The Release tree contains **none** of these DLLs, `build.cmd full` never
copies them (its runtime-layout step copies conversion tables, toolbars,
automation samples and the zip2sfx samples only), `tandemcommander.iss`
neither packages `vc_redist.x64.exe` nor runs it, and the release notes,
website and manual do not mention the requirement. Upstream Open Salamander
handled this with `src/vcxproj/!populate_build_dir.cmd`, which copies
`concrt140.dll msvcp140.dll vcruntime140.dll` plus the UCRT into the output
tree (documented in `architecture/03-build-pipeline.md` §"Populate Build
Directory"); Tandem's own build pipeline dropped that step.

On a machine without the *Microsoft Visual C++ 2015–2022 Redistributable
(x64)* the installer finishes normally and the post-install launch fails with
*"The code execution cannot proceed because VCRUNTIME140.dll was not
found"* (or CONCRT140.dll) — from the user's point of view "the installation
had a problem". Windows 11 does **not** ship this runtime; most machines have
it from other software, which is why it went unnoticed. This developer
machine has 14.51.36247 installed, so no local test could ever show it.

Fix options, cheapest first:

1. **App-local CRT**: copy `vcruntime140.dll`, `vcruntime140_1.dll`,
   `msvcp140.dll`, `concrt140.dll` from
   `VC\Redist\MSVC\<ver>\x64\Microsoft.VC143.CRT\` into the Release tree in
   `build.cmd full release` (the UCRT `api-ms-win-crt-*` set is part of
   Windows 10+ and needs nothing). Microsoft-signed files, licensed for
   redistribution, no installer logic, no elevation issue. The signing sweep
   must **skip** them (they carry a valid Microsoft signature; re-signing
   would replace it — `Test-SignedByCurrent` currently re-signs anything not
   signed by our certificate, so an exclusion by signer is needed).
2. Bundle `vc_redist.x64.exe` and run it from `[Run]` with
   `/install /quiet /norestart`, guarded by a `[Code]` check of
   `HKLM\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64\Installed`
   (adds ~25 MB and a second installer to trust).
3. Static CRT (`/MT`) — rejected: the application and 20 plugin DLLs exchange
   CRT objects across module boundaries.

### 3.4 Smaller static-reputation items (cosmetic, each cheap)

| Site | Observation | Why engines care |
|---|---|---|
| `plugins\7zip\7zwrapper.dll`, `utils\sqlite.dll` | **no version resource at all** (empty CompanyName / ProductName / FileVersion) | file-reputation systems treat versionless DLLs as more suspicious; both are also the only files whose provenance a reviewer cannot read from the file |
| `tandemcommander.exe`, `salmon.exe` | non-standard PE sections `.i_cst`, `.i_alc`, `.i_str` (from `#pragma section` in `callstk.cpp`, `allochan.cpp`, `handles.cpp`) | unusual section names are a classic feature in static classifiers; harmless, but cheap to rename or merge (`/MERGE`) |
| all binaries | no Control Flow Guard (`DLL characteristics 0x8160`; DEP, ASLR, high-entropy VA are on) | not an antivirus trigger, but part of the "hardening score" some vendors publish; `/guard:cf` is a one-line change |
| `tandemcommander.exe` | imports `IsDebuggerPresent` (only used under `_DEBUG`, but the import stays because `bugreprt.cpp:576` is unconditional) and carries the string `ZwQueryInformationProcess` (dead pre-Vista path in `salamdr6.cpp:2493-2560`) | both are anti-debug indicators in static scoring; removable |
| `salmoncl.cpp:148-215` | `salmon.exe` is started with `HIGH_PRIORITY_CLASS`, handle inheritance on, and a `PROCESS_VM_READ` handle to the parent | needed for the minidump; the priority class is not — dropping it removes one oddity |
| `src/tasklist.cpp:168` | `OpenProcess(PROCESS_TERMINATE)` + `TerminateProcess` on another Tandem Commander instance (Task List → Terminate) | legitimate user action; noted because "terminates other processes" is scored |

---

## 4. What was checked and is *not* a problem

- **Packing / obfuscation**: none. Section entropies are those of ordinary
  MSVC code (`.text` 6.4, `.rdata` 4.6–5.7, `.data` 0.9–5.2). The 9.3 MB
  `.rsrc` of `codeview.spl` (entropy 5.4) is the highlighting data; it was
  grepped for the tokens script scanners key on (`Invoke-Expression`,
  `EncodedCommand`, `FromBase64String`, `DownloadString`, `WScript.Shell`,
  `ActiveXObject`, `CreateRemoteThread`, `VirtualAlloc` …): **none** present;
  only grammar keywords such as `Start-Process` (7), `HKEY_` (7), `Bypass` (5),
  `schtasks`/`vssadmin`/`bcdedit`/`certutil`/`bitsadmin` (1 each).
- **Signing**: every shipped PE (216 incl. all `.slg`) carries a valid
  SHA-256 Authenticode signature with a Certum RFC 3161 timestamp; the
  installer and uninstaller are signed; `build_setup.cmd sign` refuses to
  package an unsigned tree.
- **Hardening**: DEP, ASLR and high-entropy 64-bit ASLR on every module;
  `requestedExecutionLevel asInvoker`; Common-Controls 6 manifest; no
  `uiAccess`.
- **Network at start**: none. Crash-report upload is permanently disabled
  (`src/salmon/upload.cpp:7`); the `checkver` plugin (WinINet update check)
  is **off** in `plugins.cfg`; `mdview`'s WinHTTP fetch runs only for a
  remote image the user explicitly consented to; FTP/SFTP open sockets only
  on user action.
- **Persistence**: no writes to `HKLM`, `HKCR`, `Run`/`RunOnce`, services,
  scheduled tasks. All `HKEY_LOCAL_MACHINE`/`HKEY_CLASSES_ROOT` sites in the
  core are reads (icon associations, overlay handlers, policies, CPU info
  for the bug report). The `RunOnce` hits are in the ZIP self-extractor
  *stub* source, which is **not shipped** (no `*.sfx` in the tree; only
  `zip2sfx\readme.txt` + two `.set` samples).
- **Shell extension**: not built, not shipped, not registered by the
  installer (no `regserver`); the `DllRegisterServer` hit is inside 7-Zip's
  NSIS parser.
- **Hooks**: all four `SetWindowsHookEx` sites are thread-local
  (`WH_CALLWNDPROC`/`WH_GETMESSAGE` with `GetCurrentThreadId()`), never
  global; `GetAsyncKeyState` is used for `VK_ESCAPE` (45×) and modifier
  keys (7×) — no keylogging pattern.
- **Raw disk access**: `\\.\` device opens exist only in `undelete.spl`
  (on user action inside the plugin), `drivelst.cpp`/`salamdr*.cpp` (volume
  queries) and 7-Zip's NTFS handler; nothing at start.
- **Privileges**: `AdjustTokenPrivileges` for `SE_MANAGE_VOLUME_NAME`
  (undelete), `SE_SHUTDOWN_NAME` (comment only), and 7-Zip's
  `SeLockMemory`/`SeRestore`/`SeBackup`/`SeCreateSymbolicLink` (archive
  extraction); no `SeDebugPrivilege` in shipped code (the two hits are the
  upstream setup remover and the trace server, neither shipped).
- **`CreateRemoteThread`**: only the name in the HANDLES debug-tracking
  wrapper tables (`handles.cpp`, `mhandles.cpp`); no call site.
- **Version resources**: consistent `Tandem Commander Project` /
  `Tandem Commander` / `0.1.7 (x64)` on all first-party files; `7za.dll`
  keeps Igor Pavlov's resource with "Modified for use by Tandem Commander".
- **Microsoft Defender** (current engine and signatures): no threats on the
  published installer, the rebuilt installer and the full tree.

---

## 5. How old could the reporter's Avast be, and does it matter?

Facts: Avast versions 9, 10 and 11 stopped receiving virus definitions in
summer 2023 (Avast blog, 2023-06-21); Windows 7 without the Convenience
Rollup is frozen at program version 21.2 but keeps receiving definitions;
every supported version self-updates its program and definitions several
times a day. A user on Windows 11 (the product's stated requirement) is
therefore almost certainly on a **current** Avast (25.x / Avast One) or on
an unsupported, no-longer-updating one — there is little in between.

Consequences for the cause:

| Avast state | Most likely mechanism | What the user saw |
|---|---|---|
| Current, default settings | CyberCapture / File reputation ("unknown file", low prevalence, young certificate) → file quarantined and uploaded | "Hang on, this file may contain something bad" / *FileRepMalware* / *IDP.Generic* — the file "disappears" |
| Current, *Hardened Mode* or *Behavior Shield* on default | §3.2 pattern on first launch | *IDP.Generic*, *Win64:Evo-gen [Susp]* on `tandemcommander.exe` after install |
| Old (no definition updates) | static heuristics only; the §3.2 import combination and an unknown Inno 7 stub | *Win64:Malware-gen*, *Win32:Evo-gen* on the installer |

So the version changes the *label*, not the fact. The four things to ask the
reporter for, in order of value: the **detection name** (Avast shows it in
*Menu → Protection → Virus Chest* and in *Menu → Settings → General → …
Protection log*), the **Avast program version** (*Menu → About*), **which
file** (installer, `tandemcommander.exe`, `salmon.exe`, a plugin), and
whether the install error mentioned **VCRUNTIME140.dll / CONCRT140.dll**
(§3.3) — that one would be a different bug entirely.

### 5.1 Update: "probably an old Avast on an old Windows 10" (2026-09-17)

The maintainer's follow-up narrows the scenario. What it changes:

- **"Old Avast" is a choice, not a consequence of the OS.** Avast Free
  Antivirus / Avast One 26.x still list "Windows 10 except Mobile and IoT
  Edition" with no minimum build, and even Windows 7 SP1 / 8.1. So an old
  Avast on Windows 10 means program updates are switched off, broken, or
  the machine is rarely online — and in that case its *definitions* may be
  stale too. Definitions still flow to every version from 12 upward (only
  9–11 were cut off in summer 2023); Behavior Shield and CyberCapture both
  exist since Avast 2017 (v17). Any Avast from 2017 on therefore has the same
  two mechanisms as a current one, only with older engines and ML models:
  more weight on static features (the unknown Inno Setup 7 stub, the §3.2
  import combination), generic labels such as *Win64:Malware-gen* /
  *Win32:Evo-gen [Susp]*, and — if *Hardened Mode* is on — an outright block
  of any executable not on Avast's allow-list.
- **A whitelisting submission cannot reach a machine whose definitions no
  longer update.** On such a machine only the product-side changes help:
  removing the kernel32 patch (§3.2) and shipping the CRT (§3.3). Priority
  of those two goes up; the submissions (§6 item 3) stay worthwhile for
  everyone else.
- **Certificate chain trust is the new amplifier.** The chain ends in
  *Certum Trusted Network CA 2*. That root is not part of the small inline
  root set Windows ships with; it is delivered by *Automatic Root
  Certificates Update* from Windows Update the first time a chain needs it
  (on this developer machine it sits in the `AuthRoot` store, which is
  exactly the CTL-download store). A Windows 10 that has not reached
  Windows Update for a long time, or has the "Turn off Automatic Root
  Certificates Update" policy, or sits behind a blocked network, validates
  the signature as *"terminated in a root certificate which is not
  trusted"*. For Avast and SmartScreen the file is then effectively
  **unsigned** and every reputation weight the signature would carry is
  gone. Cheap check for the reporter: installer → *Properties → Digital
  Signatures → Details* must say "This digital signature is OK"; if it says
  the root is not trusted, running Windows Update (or
  `certutil -generateSSTFromWU`) fixes the machine, and no change on our
  side can. Switching CAs would not help either — DigiCert/Sectigo roots
  are delivered the same way, they are merely more likely to be cached
  already.
- **Nothing in the product needs a newer Windows 10 build.** All 25 shipped
  PE modules were checked for static imports newer than Windows 7: only
  `DwmSetWindowAttribute` and `InitializeCriticalSectionEx` (both Vista)
  appear; the cloud-files API (`cldapi.dll`) is loaded dynamically; Inno
  Setup 7 states support for "every Windows release since 2006". So there
  is no "entry point not found" failure on any Windows 10 build. The WebView2
  runtime may be missing on an old Windows 10 — that only degrades the Code
  Viewer / Markdown viewer to the built-in viewer, it does not affect
  installation. What an old, rarely updated Windows 10 *does* make more
  likely is a **missing Visual C++ 2015–2022 x64 runtime** (§3.3): on such
  a machine the installer finishes and the program then refuses to start —
  the single most plausible reading of "a problem with the installation".

Immediate advice for the reporter, independent of any fix on our side:
update Avast (or at least its definitions) and run Windows Update, then
retry; if `tandemcommander.exe` still does not start, install the Visual
C++ 2015–2022 x64 redistributable. And send the detection name.

---

## 6. Recommended actions

Ordered by effect on users per unit of work.

1. **Ship the Visual C++ runtime** (§3.3, option 1). Independent of Avast; a
   machine without the redistributable cannot run 0.1.0–0.1.7 at all.
   Add a release-gate check that the tree contains the four CRT DLLs.
2. **Remove the kernel32 in-memory patch** (§3.2). One function; re-run the
   crash-reporter scenario afterwards (force a crash from a plugin, confirm
   `salmon.exe` still produces the minidump).
3. **Register with Avast's Whitelisting Program**
   (`https://www.avast.com/en-us/whitelist-program-registration` → FTP
   credentials → upload every release's installer; ask for
   *digital-signature whitelisting* once a track record exists) and file the
   0.1.7 installer through the false-positive form
   (`https://www.avast.com/en-us/submit-a-sample`, *False positive → File*,
   ZIP without password, ≤ 500 MB, include the detection name the reporter
   provides). AVG shares the engine and the programme. Do the equivalent at
   Microsoft (Security Intelligence submission), ESET and Kaspersky
   proactively — each release restarts file reputation.
4. **Add a pre-release scan step** to the ship gate: Defender scan of the
   signed tree (already trivially available: `MpCmdRun -Scan -ScanType 3
   -File <tree>`), then a VirusTotal upload of the signed installer *after*
   the GitHub asset is public (uploading before publication would leak the
   binary to third parties earlier than intended). Publish the SHA-256 and
   the VirusTotal permalink in the release notes and on the website; the
   website currently shows no hash and no signing information.
5. **Keep the certificate stable.** Reputation accrues to the signer;
   renew the Certum certificate on 2027-08-03 with the identical subject and
   the same key type, do not switch CAs casually, and never ship an unsigned
   or partially signed build again (already enforced by `build_setup.cmd
   sign`).
6. **Cosmetics from §3.4**: give `7zwrapper.dll` and `sqlite.dll` a version
   resource; drop `HIGH_PRIORITY_CLASS` for `salmon.exe`; compile with
   `/guard:cf`; drop the dead `ZwQueryInformationProcess` path and the
   release-mode `IsDebuggerPresent` import; optionally merge the `.i_*`
   sections.
7. **Write an "Antivirus warning?" page** for the website/FAQ: what the
   product does at start (spawns `utils\salmon.exe`, reads no network, writes
   only `HKCU\Software\Tandem Commander`), how to verify the signature
   (Properties → Digital Signatures → *Open Source Developer Pavel Stupka*,
   Certum), the SHA-256 of the current installer, and how to report a false
   positive to Avast. Most reporters never come back with the detection name
   unless told where to find it.

Not recommended: switching installer technology (NSIS/MSI have the same
history), an EV certificate (Certum does not offer it for the open-source
programme, and CyberCapture ignores EV anyway per the electron-builder
report), or reverting to Inno Setup 6 (the 7.x stub gains reputation with
every Inno-built product that ships, which is thousands).

---

## 7. Side effects of this session (please read)

1. **`setup/output/tandemcommander-0.1.7-x64-setup.exe` was overwritten and
   restored.** `build_setup.cmd sign` writes the output name from
   `MyAppVersion`, which is still 0.1.7, so the rebuild replaced the
   archived published installer. The published file was re-downloaded from
   the GitHub release, hash-verified against the winget manifest
   (`6731E146…F64DD`) and put back; the rebuilt signed installer
   (`6CBEC836…20B46`) lives in the session scratchpad as
   `rebuilt-0.1.7-signed-2026-09-17.exe`. Lesson: bump the version (or rename
   the archived file) before rebuilding an already-published version.
2. **The Release tree in `build\tandemcommander\Release_x64` is now signed**
   (216 files, timestamps of 2026-09-17). A later `build.cmd full release`
   re-links and unsigns whatever it rebuilds; nothing else depends on it.
3. **Microsoft Defender logged three detections at 18:32 caused by this
   analysis, not by the product**: two Bash command lines and one PowerShell
   command that *contained the list of script tokens searched for in
   `codeview.spl`* (`Invoke-Mimikatz`, `EncodedCommand`, …) were blocked by
   Defender's command-line/AMSI scanning as `Trojan:PowerShell/Mimikatz.A`,
   `Trojan:PowerShell/PSAttackTool.A` and `Trojan:Win32/PowhidSubExec.B`
   (visible in *Windows Security → Protection history*). No file was
   quarantined; the search was re-run with the tokens read from a file. It
   is, incidentally, a live demonstration of how little it takes to trip a
   content heuristic.
4. `innoextract` 1.9 was downloaded into the session scratchpad to unpack
   the published installer; it cannot read Inno Setup 7 archives and was not
   used further. Nothing was installed on the machine (the `winget install`
   attempt did not complete and was abandoned).

---

## 8. Evidence pointers

- Certificate: thumbprint `A3D05CCF5CA13EAFF49CC7F64D1832F0E6EF6733`, key on
  *SimplySign CSP* (Certum cloud), `tools/codesign/codesign.cfg`.
- Published hashes: `tools/winget/manifests/0.1.6` and `0.1.7`
  (`InstallerSha256`); all seven archived installers in `setup/output` verify
  as *Valid* with the same signer.
- Kernel32 patch: `src/callstk.cpp:76-127`, call at `:283`, enclosing
  condition `if (FirstCallstack)` at `:232`.
- CRT linkage: `src/vcxproj/sal_release.props:16`,
  `src/plugins/shared/vcxproj/plugin_release.props:14`; upstream copy step
  `src/vcxproj/!populate_build_dir.cmd:40-41`; Tandem layout step
  `build.cmd:390-428`.
- Crash reporter launch: `src/salmoncl.cpp:92-215`; upload disabled
  `src/salmon/upload.cpp:7-18`.
- Inno Setup 7 dates: `https://jrsoftware.org/files/is7-whatsnew.htm`
  (7.0.0-beta 2026-05-18, 7.0.2 2026-07-13, 7.1.0 2026-08-12).
- Avast: CyberCapture FAQ
  (`https://support.avast.com/en-us/article/Antivirus-CyberCapture-FAQ`),
  whitelisting FAQ
  (`https://support.avast.com/en-us/article/threat-lab-file-whitelist/`),
  definitions EOL for v9–11
  (`https://blog.avast.com/virus-definition-updates-eol`).
- Upstream precedent: `https://forum.altap.cz/viewtopic.php?t=34225`
  (Symantec SONAR.AM.C!g10 on salamand.exe).
- Inno Setup false-positive history:
  `https://groups.google.com/g/innosetup/c/lvsb2vWhklk` (6.2.1, 2022),
  `https://community.avast.com/t/problem-with-inno-setup/710534` (2015–16).
- Session logs (scratchpad): `build_release.log`, `build_setup_sign2.log`,
  `api_hits_raw.txt`.
