# Project Overview

> **Historical note (2026, feature 032)**: these architecture documents describe
> the Open Salamander codebase this project derives from. The product now ships
> as **Tandem Commander** (`tandemcommander.exe`; first public release 0.1.0,
> see `CHANGELOG.md` for the current version) with its own registry root and
> visual identity; source files, project names, and internal identifiers
> described below intentionally keep their upstream names.

## What is Open Salamander?

Open Salamander is a fast, reliable two-panel file manager for Windows.
It is a pure WinAPI application written in C++ — no MFC, no Qt, no
cross-platform frameworks. The project has over 2,200 source files
across 90 Visual Studio projects.

## History

| Year | Event |
|------|-------|
| 1997 | Petr Šolín releases Servant Salamander as freeware |
| 2001 | First shareware version (Altap founded with Jan Ryšavý) |
| 2007 | Renamed to Altap Salamander 2.5 |
| 2019 | Altap acquired by Fine; Altap Salamander 4.0 released as freeware |
| 2023 | Open-sourced under GPLv2 as Open Salamander 5.0 |

The name "Servant Salamander" was chosen because, unlike "Commander"
file managers, this one was meant to serve the user, not command them.

## Technology Stack

- **Language**: C++ (C++20, `/std:c++latest`)
- **Compiler**: MSVC v143 (Visual Studio 2022)
- **Platform**: Windows 11+ (WinAPI only, no frameworks)
- **Build System**: MSBuild via `.vcxproj` / `.sln`
- **Plugin Format**: `.spl` (plugin DLL) + `.slg` (language resource)
- **License**: GPLv2 or later

The codebase predates modern C++ practices — no smart pointers, no
RAII, no STL, no C++ Core Guidelines. It uses direct WinAPI calls,
custom memory management (`SAFE_ALLOC`), and Hungarian-style naming
in some areas. Many comments are in Czech.

## Repository Layout

```
\                        Project root
├── architecture\        Architecture documentation (this directory)
├── convert\             Conversion tables for the Convert command
├── doc\                 Documentation and license files
├── help\                User manual source files (HTML Help)
├── src\                 All source code
│   ├── common\          Shared libraries and headers
│   │   └── dep\         Third-party dependencies (zlib, bzip2, etc.)
│   ├── lang\            English resources for main application
│   ├── plugins\         35+ plugin source directories
│   │   └── shared\      Shared plugin infrastructure and build props
│   ├── reglib\          Windows Registry file access
│   ├── res\             Image resources and toolbars
│   ├── salopen\         Open files helper utility
│   ├── salspawn\        Process spawning helper
│   ├── setup\           Installer and uninstaller
│   ├── sfx7zip\         Self-extractor based on 7-Zip
│   ├── shellext\        Shell extension DLL (x86 + x64)
│   ├── translator\      UI translation utility
│   ├── tserver\         Trace Server for debug messages
│   └── vcxproj\         Visual Studio solution and project files
├── tools\               Build utilities (code signing, timing)
└── translations\        Translations into other languages
```

## Key Numbers

| Metric | Count |
|--------|-------|
| Visual Studio projects | 90 |
| Plugins | 35 |
| Language modules | 36 (1 main + 35 plugins) |
| Source files (.cpp, .h, .c) | ~2,224 |
| Third-party libraries (included) | 11 |
| Missing external dependencies | 4 |
| Build configurations | 6 (Debug/Release/Utils × x86/x64) |

## Further Reading

- [Original README](../README.md) — prerequisites, building, contributing
- [Solution Structure](02-solution-structure.md) — all 90 projects
- [Build Pipeline](03-build-pipeline.md) — how to build
- [Dependencies](04-dependencies.md) — third-party libraries
