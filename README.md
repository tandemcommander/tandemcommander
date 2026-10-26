# Tandem Commander

Tandem Commander is a fast, keyboard-friendly two-panel file manager for Windows. It is based on [Open Salamander](https://github.com/OpenSalamander/salamander), the GPLv2 open-source release of the long-lived Altap Salamander file manager. Everything about the original project — its history, features, documentation, and community — lives in the upstream repository; this README covers what makes Tandem Commander different and how to build it.

**Current version**: 0.2.0 (released 2026-10-25) — every release is described in [CHANGELOG.md](CHANGELOG.md).

**Website**: [tandemcommander.org](https://tandemcommander.org) 

**Issues**: [github.com/tandemcommander/tandemcommander/issues](https://github.com/tandemcommander/tandemcommander/issues)

## What's Different from Open Salamander

- **Names in any language, paths of any length.** File and folder names are handled as Unicode throughout the program and its plugins — in panels, dialogs, archives, the command line, the clipboard and drag-and-drop — and long paths open everywhere. A name that does not fit is refused, never silently cut.
- **Panel tabs.** Each panel can keep several directories open in tabs, each with its own view, sort order, filter, selection and history, restored at the next start; optional browser-like shortcuts and *Reopen Closed Tab*.
- **Quick search that filters.** Typing finds the text anywhere in a name, also without its accents, and shows only the matching items.
- **New viewers and plugins.** A **Code Viewer** with syntax highlighting for over 200 languages and formats, a **Markdown Viewer**, and an **SFTP** plugin for SSH servers. RAR archives open and unpack without installing anything (7-Zip engine 26.03), and external archivers work.
- **Command Shell of your choice.** `Num /` opens Command Prompt, Windows PowerShell, PowerShell 7, Windows Terminal, Git Bash or any program you name.
- **Your Salamander settings come along.** *Options → Import Settings from Salamander* brings hot paths, FTP connections, the user menu and other settings over from Altap Salamander or Open Salamander after a preview; the old settings are only read.
- **Safer with your data.** A long series of fixes closes ways of losing files around archives, disc images, file operations, FTP, SFTP and the Registry Editor — for example, *Delete archive after unpacking* keeps an archive that was not extracted whole.
- **Modern distribution.** A signed installer and uninstaller, the Windows Package Manager (winget), unattended installation, no separate Visual C++ runtime needed, and an update check that tells you about a new version (one request to GitHub about once a day, nothing about you is sent, one option turns it off).
- **Translations.** English plus Czech, Dutch, French, German, Hungarian, Romanian, Slovak and Spanish.

## Installing

Download the signed installer from the [Releases page](https://github.com/tandemcommander/tandemcommander/releases/latest) and run it. Windows 11 or newer, 64-bit.

The application is also published in the Windows Package Manager catalogue as `PavelStupka.TandemCommander`, so it can be installed and kept up to date with:

```
winget install tandemcommander
winget upgrade tandemcommander
```

It installs for all users, into `Program Files`, and asks for administrator rights the same way the installer does.

Upgrading from 0.1.x: at the first start of 0.2.0 the settings are copied once to a key that no longer changes with the version (see the note on naming below). Going back to 0.1.x afterwards is not supported.

## Why This Project Exists — A Personal Note

Whenever I have worked on Windows, there has always been a Salamander close at hand. First Servant Salamander, later Altap Salamander — in my view one of the finest pieces of software I have ever worked with. But the last released version of Altap Salamander dates back to 2019, and it still carries a few aches inherited from the original versions: incomplete encoding support, missing long directory and file path support, and quite a few others. At the same time, many of my friends and family members use Altap Salamander every day, both at work and at home.

The moment Salamander was released as Open Salamander, I had a clear vision: I would adapt it for myself so I could simply keep using it. That vision quickly ran into hard reality — even though I am a very experienced software engineer, developer, and architect, I was missing the one factor a project of this scale demands above all else: time.

That has changed, essentially within the last few months, with the overall shift in how software can now be — not programmed, but *created* — with agentic systems. To be clear, I am emphatically not talking about "vibe coding"; I consider that a bit of a buzzword and I do not like it. The term I would choose is **Full Agentic Spec-Driven Development**: clearly defined procedures not just for producing code, but for producing the entire project — documentation and artifacts included. This project is deliberately built with the spec-driven approach on top of GitHub SpecKit, using the best agentic models available at the time, with reviews also carried out independently by models of other vendors.

Tandem Commander is, of course, not perfect. But thanks to this approach I ended up with a genuinely usable tool — one that I hope can serve others as well.

## A New Era of Development

Tandem Commander explores what happens when a mature, quarter-century-old C++ codebase meets the new era of agentic programming. Development follows Spec-Driven Development principles built on [GitHub SpecKit](https://github.com/github/spec-kit): every change begins as a written specification that is clarified, planned, and decomposed into tasks before any code is touched. The implementation itself is carried out by a combination of agentic coding frameworks using the best models available at the time. Planned work is kept in an ordered backlog, and every finished change is reviewed by an independent agent before it is accepted.

> **A note on naming**: since version 0.1.0 the application itself carries the Tandem Commander identity — the binary is `tandemcommander.exe`, the window titles, About dialog, and icons use the new name and visual style, and configuration lives under its own registry root (`HKCU\Software\Tandem Commander\Settings` since 0.2.0; versions 0.1.x used `…\Tandem Commander\0.1`, which 0.2.0 copies once and leaves untouched as a backup), fully separate from any Open Salamander installation. If you used Altap Salamander or Open Salamander before, the first start offers to import your settings, and *Options → Import Settings from Salamander* does it at any time — the old program's settings are only read, never changed, and nothing in Tandem Commander changes until you confirm the preview. Source files, internal identifiers, and the solution name (`salamand.sln`) intentionally keep their upstream names. The HTML help is not yet rebranded: apart from the pages describing new features, it still speaks of Open Salamander.

## About the Name: Tandem Commander

The original name *Servant* Salamander carried a philosophy I fully identify with: the program is there to **serve** the user, never the other way around. Still, a new name was needed — I did not want to trade on the original one, and I also wanted the project to sit more recognizably among the other two-panel file managers, the "commanders".

I read *Commander* accordingly: it is a tool through which the **user commands the files** — not a program that commands the user. And *Tandem* simply felt fitting and unique — two panels working side by side, in tandem.

## Thank You, Open Salamander Authors

None of this would exist without the people who built Servant Salamander, Altap Salamander, and finally Open Salamander. Over a quarter of a century they created and refined a program that countless people — me, my friends, my family — have trusted with their daily work, and it shows in every detail: the speed, the keyboard-first design, the plugin architecture, the sheer care in the code this repository inherited. Their decision to release it under an open-source license was an act of real generosity that gave this remarkable software a second life. Tandem Commander stands entirely on their shoulders, and I hope it honors what they built. To all the original authors and contributors, listed in [AUTHORS](AUTHORS): thank you.

## Building

### Prerequisites

- Windows 11 or newer
- [Visual Studio 2022](https://visualstudio.microsoft.com/downloads/) (any edition) with the **Desktop development with C++** workload
- Windows 10/11 SDK (the projects use the latest SDK installed with the workload)
- [Python 3](https://www.python.org/downloads/) on `PATH` — required: the build runs an encoding guard (`tools/check_encoding.py`) and fails without it. The remaining Python tools under `tools/` (machine translation, release preparation) are developer-side only and never run by the build.
- Optional: the `OPENSAL_BUILD_DIR` environment variable to choose the build output directory — the value must end with a backslash (e.g. `D:\Build\TandemCommander\`). When unset, the build defaults to `.\build\` under the repository root.
- Optional: [Git](https://git-scm.com/downloads), and [PowerShell 7.4+](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows) to run the `normalize.ps1` source formatter

### Build commands

Run `build.cmd` from the repository root:

```batch
build.cmd                :: incremental Debug x64 build
build.cmd rebuild        :: full clean + rebuild
build.cmd release        :: Release x64 build
build.cmd full           :: complete build: app + plugins + language modules,
                         ::   plus runtime data files and plugin registration
build.cmd full release   :: complete Release x64 build
```

Arguments can be combined in any order (`build.cmd help` shows the full usage). All third-party dependencies are vendored under `src/common/dep/`; the build restores no NuGet packages.

What is built and shipped is decided by two committed policy files, both validated on every run:

- [`plugins.cfg`](plugins.cfg) in the repository root — one `name=on|off` line per plugin (currently 20 of 31 on).
- [`translations/languages.cfg`](translations/languages.cfg) — an `enabled = on|off` field per language (currently 8 of 11 on; Chinese, Russian and Ukrainian are off).

Unit tests of the shared rules live in the `saltests` project, which a Debug build compiles to `<build dir>\tandemcommander\Debug_x64\saltests\saltests.exe`; run it after a change in `src/common/`. Feature-level GUI checks are kept as probes in each feature's `specs/NNN-*/probe/` directory.

## Release, Code Signing & Installer

Release builds are code-signed and packaged **strictly on demand** — a plain
`build.cmd full release` never signs anything, never contacts a timestamp
server, and behaves exactly like a development build. Signing and installer
packaging are extra arguments:

```batch
build.cmd full release sign          :: complete Release build, then sign every
                                     ::   shipped binary (exe, dll, spl, slg)
build.cmd full release sign setup    :: one-command signed release: signed build
                                     ::   + signed Inno Setup installer
                                     ::   (sign and setup require release)
setup\build_setup.cmd                :: unsigned installer from an existing
                                     ::   Release tree (development test)
setup\build_setup.cmd sign           :: sign the Release tree if needed, then
                                     ::   build a signed installer + uninstaller
```

### Release procedure

Versions follow Semantic Versioning: a release with new features raises
MINOR (`0.2.0`, `0.3.0`), a fixes-only release raises PATCH (`0.2.1`), and
every release raises the internal build number shared by the application and
all plugins. The procedure and the one list of records a release changes are
in [`backlog/RELEASE.md`](backlog/RELEASE.md). On the release day the tree is
prepared in one commit by the `/tandem-release <x.y.z>` agent skill, built on
[`tools/release/release.py`](tools/release/release.py): version and build
number, installer version, the dated `CHANGELOG.md` section, the privacy
statement's validity line and the GitHub release notes in
[`release_notes/`](release_notes/). Building the signed program, tagging,
publishing the GitHub release and the winget submission remain the
maintainer's steps.

### Additional prerequisites for releases

- The maintainer's code-signing certificate installed in the Windows
  certificate store (current user, `My`); its SHA-1 thumbprint and the
  timestamp authority are committed in
  [`tools/codesign/codesign.cfg`](tools/codesign/codesign.cfg) — the private
  key never enters the repository
- [Inno Setup 7](https://jrsoftware.org/isinfo.php) for the installer
  (`ISCC.exe` is located automatically; it does not need to be on `PATH`)

### How signing works

The signing core is `tools\codesign\sign_release.ps1` (Windows PowerShell
5.1). It sweeps the Release output tree, signs every PE artifact
(`*.exe`, `*.dll`, `*.spl`, `*.slg`) with the configured certificate —
SHA-256 digests, RFC 3161 timestamp — and ends with a verification pass. The
sweep is **idempotent**: files already signed by the configured certificate
are skipped, so re-running after a network hiccup only finishes what is
missing, and a re-run over a fully signed tree completes in seconds. Files
signed by an *older* certificate are re-signed automatically.

```batch
:: sign an existing build without rebuilding:
powershell -NoProfile -ExecutionPolicy Bypass -File tools\codesign\sign_release.ps1 ^
    -Root "build\tandemcommander\Release_x64"

:: audit signing state without modifying anything:
powershell -NoProfile -ExecutionPolicy Bypass -File tools\codesign\sign_release.ps1 ^
    -Root "build\tandemcommander\Release_x64" -VerifyOnly
```

The signed installer is produced by `setup\build_setup.cmd sign`, which first
runs the same sweep (a signed installer can never package unsigned binaries)
and then compiles `setup\tandemcommander.iss` with `/DSIGN=1`, so Inno Setup
signs both the installer and the uninstaller it deploys. The result lands in
`setup\output\`.

Release output trees contain only distribution files: linker byproducts
(`.pdb`, `.lib`, `.exp`) are redirected outside the tree at build time (PDBs
are preserved under the `obj\` intermediate root for crash-dump
symbolication), and the installer excludes those file types independently as
a safety net.

### Certificate rotation

1. Install the new certificate into the Windows certificate store.
2. Update `thumbprint` in `tools\codesign\codesign.cfg` (one line).
3. Re-run any signing command — every artifact still carrying the old
   certificate is re-signed; timestamps keep previously released binaries
   valid after the old certificate expires.

### Publishing to winget

Released versions are also published to the **Windows Package Manager**
catalogue as `PavelStupka.TandemCommander`, so users can install and update
with `winget install tandemcommander` / `winget upgrade tandemcommander`.

The catalogue stores a manifest that points at the installer already published
on GitHub Releases, so publishing a version means opening a pull request
against [microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs) —
which is one command once the release asset is uploaded:

```batch
powershell -NoProfile -ExecutionPolicy Bypass -File tools\winget\publish.ps1 ^
    -Version 0.2.0 -Submit
```

Without `-Submit` the manifests are only generated into
`tools\winget\manifests\<version>\` and validated, which is the safe way to
review them first. The script downloads the published installer, **verifies
its Authenticode signature** against `tools\codesign\codesign.cfg`, and takes
the release date and release notes from `CHANGELOG.md`. The
`Publish to winget` GitHub workflow runs the same script automatically when a
release is published.

Catalogue metadata (description, tags, URLs) lives in
`tools\winget\templates\` — see
[`tools/winget/README.md`](tools/winget/README.md) for the one-time token
setup, local install testing, and troubleshooting.

## Development Process

Planned work — bugs, ideas, review findings, decisions waiting for the maintainer and steps that need a person — is kept in an ordered backlog: [`backlog/BACKLOG.md`](backlog/BACKLOG.md), with one folder per item in `backlog/items/`. Agents only add new findings to its *Inbox*; the maintainer triages and orders them. The backlog is managed with the `/tandem-backlog` agent skill and the [`bin/backlog.sh`](bin/backlog.sh) tool; `/tandem-backlog-implement` takes the first eligible item and carries it through autonomously, and [`bin/backlog-loop.sh`](bin/backlog-loop.sh) runs item after item.

Each item is developed one at a time through the SpecKit workflow: **specify → clarify → plan → tasks → analyze → implement**. Each feature lives in the [`specs/`](specs/) directory with its full paper trail — specification, implementation plan, task breakdown, research notes, contracts, a running fix log, GUI probes and a closing report — committed alongside the code, so the repository records not only what changed but why. The work starts by reproducing the problem on a real build, and every finished fix is reviewed by an independent agent that tries to refute it before it is accepted. [`specs/FEATURE-HISTORY.md`](specs/FEATURE-HISTORY.md) condenses every feature into a short entry with its traps and evidence, indexed by area.

Project-wide rules (build reproducibility, backward compatibility, incremental modernization, Windows platform commitment, plugin architecture preservation, UI consistency) are codified in the project constitution at [`.specify/memory/constitution.md`](.specify/memory/constitution.md).

## Repository Structure

| Directory | Purpose |
|-----------|---------|
| `src/` | C++ source code: core application, shared code and vendored dependencies (`src/common/`, `src/common/dep/`), 31 plugins (`src/plugins/`), language module (`src/lang/`), shell extension (`src/shellext/`), unit tests (`src/saltests/`) |
| `src/vcxproj/` | Visual Studio solution (`salamand.sln`) and project files |
| `setup/` | Inno Setup installer script and its build command |
| `specs/` | Spec-Driven Development artifacts: one directory per feature, plus `FEATURE-HISTORY.md` |
| `backlog/` | Ordered backlog of planned work and the release procedure (`RELEASE.md`) |
| `bin/` | Backlog tool and the autonomous backlog loop |
| `architecture/` | Architecture documentation: build pipeline, dependencies, plugin API, WebView2 integration, code standards |
| `convert/` | Character conversion tables |
| `doc/` | Licenses and third-party notices |
| `help/` | User manual source (HTML Help) |
| `release_notes/` | GitHub release notes, one file per version |
| `tests/` | Standalone test harnesses |
| `tools/` | Build, signing, branding, translation, release and winget utilities |
| `translations/` | UI translations and the shipped-language policy |
| `.github/workflows/` | Pull request checks and the winget publishing workflow |

See the [`architecture/`](architecture/) documents for a much deeper analysis.

## Privacy

Tandem Commander has no accounts, telemetry, analytics or advertising and sends nothing to the project; it uses the network only when you ask it to. What it stores, what it sends and how to remove it is described in [PRIVACY.md](PRIVACY.md).

## License

Tandem Commander, like the Open Salamander project it derives from, is open-source software licensed under [GPLv2](doc/license/license_gpl.txt) and later. Individual files and libraries carry [different but compatible licenses](doc/third_party.txt). Contributors are listed in [AUTHORS](AUTHORS).
