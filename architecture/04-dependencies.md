# Dependencies

## Dependency Management

Open Salamander has **zero external package managers** — no NuGet, no
vcpkg, no Conan. All third-party libraries are embedded as source code
in the repository or provided as pre-built binaries in
`src\plugins\shared\libs\`.

## Included Third-Party Libraries

| Library | Location | License | GPLv2 OK | Used By |
|---------|----------|---------|----------|---------|
| zlib | src/common/dep/zlib/ | zlib License | Yes | salamand, zip plugin |
| bzip2 | src/common/dep/bzip2/ | BSD-like | Yes | salamand |
| AES (Gladman) | src/common/dep/crypt/ | BSD | Yes | salamand (encryption) |
| SQLite | src/common/dep/sqlite/ | Public Domain | Yes | dbviewer plugin |
| PNGLite | src/common/dep/pnglite/ | zlib License | Yes | salamand (PNG support) |
| NanoSVG | src/common/dep/nanosvg/ | zlib License | Yes | salamand (SVG icons) |
| fmt | src/common/dep/fmt/ | MIT | Yes | salamand (formatting) |
| WIL | src/common/dep/wil/ | MIT | Yes | salamand, plugins |
| libssh2 | src/common/dep/libssh2/ | BSD-3-Clause | Yes | sftp plugin (WinCNG backend) |
| libexif | src/plugins/pictview/ | LGPL 2.1 | Yes | pictview plugin |
| CHMLIB | src/plugins/unchm/ | LGPL 2.1 | Yes | unchm plugin |

### Library Details

**zlib** — General-purpose compression. Used by the main application
for decompression tasks and by the ZIP plugin for archive handling.
Embedded as C source files (adler32.c, compress.c, crc32.c, deflate.c,
inffast.c, inflate.c, inftrees.c, trees.c, zutil.c).

**bzip2** — Alternative compression algorithm. Embedded as C source
with `BZ_NO_STDIO` preprocessor definition.

**AES (Brian Gladman)** — AES encryption implementation. Used for
encrypted archive support. Files: aescrypt.c, aeskey.c, aestab.c,
fileenc.c, hmac.c, pwd2key.c, sha1.c.

**SQLite** — Embedded relational database. Used by the dbviewer
plugin. Built as a separate DLL project (sqlite.vcxproj) with
`SQLITE_API=extern __declspec(dllexport)`.

**WIL (Windows Implementation Library)** — Microsoft's lightweight
C++ helpers for Windows programming. Header-only library providing
RAII wrappers, error handling, and COM helpers.

**fmt** — Modern C++ formatting library. Used as an alternative to
printf-style formatting.

**NanoSVG** — Lightweight SVG parser and rasterizer. Used for
scalable icon rendering.

**PNGLite** — Minimal PNG reader. Used for loading PNG images
without heavy dependencies.


## Missing / External Dependencies

These dependencies are required by certain plugins but are NOT included
in the repository.

| Dependency | Required By | Issue | Impact | Proposed Solution |
|------------|-------------|-------|--------|-------------------|
| pvw32cnv.dll | pictview | Proprietary image engine, not open-sourced | PictView cannot convert all image formats | Replace with [WIC](https://learn.microsoft.com/en-us/windows/win32/wic/-wic-about-windows-imaging-codec) (Windows Imaging Component) |
| unrar.dll | unrar (off in `plugins.cfg`) | Not shipped. The UnRAR licence **permits** redistribution (clause 3, <https://spdx.org/licenses/UnRAR.html>); the real issue is that the "unRAR restriction" is not GPL-compatible (feature 084 research R4) | RAR archives cannot be browsed out of the box yet. The plan (feature 084 stage S7): read them through the 7zip plug-in, whose source-built engine already contains 7-Zip's RAR decoder (same unRAR restriction, documented in `doc/third_party.txt`), once the vendored 7-Zip is upgraded to 25.x (NEXT-WORK item 8) | Keep the plug-in off |
| OpenSSL | ftp | Libraries not included | FTP plugin lacks FTPS (SSL/TLS) support | Build from [openssl.org](https://www.openssl.org/) source or use vcpkg |

### Build Impact of Missing Dependencies

| Plugin | Can Build? | Functionality Loss |
|--------|-----------|-------------------|
| pictview | Yes (partial) | Some image formats not supported without pvw32cnv.dll |
| unrar | Yes (compiles) | Cannot function at runtime without unrar.dll (not needed: see above) |
| ftp | Yes (partial) | No SSL/TLS support without OpenSSL |

## Windows SDK Dependencies

The application links against standard Windows SDK libraries:

| Library | Purpose |
|---------|---------|
| kernel32.lib | Core Windows API (implicit) |
| user32.lib | Window management (implicit) |
| gdi32.lib | Graphics (implicit) |
| htmlhelp.lib | HTML Help system |
| comctl32.lib | Common controls (ListView, TreeView, etc.) |
| mpr.lib | WAN networking functions |
| wsock32.lib | Windows Sockets |
| netapi32.lib | Network management |
| msimg32.lib | Image manipulation (AlphaBlend, etc.) |
| shlwapi.lib | Shell utility functions |

## Pre-Built Binaries

`src\plugins\shared\libs\` contains pre-built library files for x86
and x64 platforms. These are referenced by plugins that need shared
binary components.

## License Compatibility Summary

All included libraries are GPLv2-compatible:
- Public Domain (SQLite) — no restrictions
- BSD/MIT/zlib (zlib, bzip2, AES, PNGLite, NanoSVG, fmt, WIL, cmark-gfm) — permissive
- LGPL 2.1 (libexif, CHMLIB) — compatible when dynamically linked

The missing pvw32cnv.dll is proprietary and cannot be distributed.
Any replacement must be GPLv2-compatible.
