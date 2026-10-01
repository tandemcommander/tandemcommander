# Research: Unpredictable salts for encrypted ZIP archives (086)

Checked at HEAD `e10dfa2` (`main`, after feature 085) — the 069 fix-protocol
rule "check the site is still defective at HEAD first".

## R1 — The defect, measured against the code

- `src/plugins/zip/crypt.cpp:118-127` `FillBufferWithRandomData`:
  `srand((unsigned)time(NULL) ^ (unsigned)_getpid())` on the first call of the
  process, then `(rand() >> 7) & 0xff` per byte. Still present.
- Two callers, both while packing:
  - `src/plugins/zip/add.cpp:1632` — the AES salt, `SAL_AES_SALT_LENGTH(strength)`
    bytes = 8 (AES-128, strength 1) or 16 (AES-256, strength 3)
    (`src/plugins/shared/spl_crypt.h:48`). It goes into
    `SalamanderCrypt->AESInit` with the password (WinZip AE: PBKDF2 key
    derivation, then AES-CTR) and is stored in front of the file data.
  - `crypt.cpp:141` `CryptHeader` — 11 random bytes drawn for the 12-byte ZIP
    2.0 (ZipCrypto) encryption header (10 survive when the check value is two
    bytes, the usual case), then encrypted with the password keys.
- The plugin starts no thread of its own (`grep _beginthread/CreateThread` in
  `src/plugins/zip/` — none): packing runs on the thread that calls the plugin,
  and the CRT's `rand` state is per thread, so in practice one seed per run.
- **Severity, stated precisely** (the 085 review said "a repeated salt gives
  the same keystream"): within one run the `rand()` sequence moves on, so salts
  differ. The defect is that every salt is a function of one 32-bit seed built
  from the creation time (seconds) and the process id — guessable to a few
  million candidates — so salts are predictable and can be reproduced, which
  allows precomputing a password search for an archive before it exists; and
  two runs that happen to start with the same seed produce the same salt
  sequence, i.e. with the same password the same AES-CTR keystream. The ZIP 2.0
  header gains known structure on top of a format that is already broken.
- Reading is not affected: extraction takes the salt/header from the archive
  (`extract.cpp`), never generates one. Old archives stay readable by
  construction.

## R2 — Decision: one header-only generator, `src/common/salrandom.h`

**Decision**: `inline BOOL SalGenRandom(void* buf, int len)` in a new
header-only `src/common/salrandom.h` (`BCryptGenRandom(NULL, …,
BCRYPT_USE_SYSTEM_PREFERRED_RNG)`, `#pragma comment(lib, "bcrypt.lib")`).
Both `FillBufferWithRandomData` functions — the core's password manager
(`src/pwdmngr.cpp`, feature 085 F6) and the ZIP plugin's — call it and keep
their own traced fallback to the old generator (FR-002: never leave the buffer
unfilled).

**Rationale**:
- One definition of "where random bytes come from" for the whole product
  (FR-004), testable in `saltests` by including the header.
- Header-only, because a shared `.cpp` does not fit the ZIP project: its files
  use the precompiled header `precomp.h` found next to each source, and
  `zip.props` adds no include directory that would let a file in `src/common`
  find it (the FTP plugin in 085 could, its props add `..`). A header needs no
  project-file change in any of the three projects.
- `#pragma comment(lib)` is the house style for a system library
  (`src/salamdr1.cpp:51`, `src/pwdmngr.cpp` since 085); the ZIP project's
  linker inputs stay untouched.

**Alternatives rejected**:
- *Copy the 085 body into crypt.cpp*: two definitions of the same rule, the
  pattern 081 and 085 removed for the WebView2 options.
- *A plugin-API service* (`CSalamanderCryptAbstract` has no random function):
  would change the plugin interface (106 → 107) for something a plugin can do
  itself.
- *Fail the archive operation when the generator fails*: `BCryptGenRandom`
  with the system-preferred provider does not fail in practice; failing a pack
  for it would be a new error path nobody can test. The traced fallback keeps
  the old behaviour as the worst case, as F6 does.

## R3 — Evidence available without the GUI

- `saltests`: the generator (success, length 0, invalid arguments, two calls
  differ, all 256 byte values appear in 64 KiB).
- Build: `zip.spl` and `tandemcommander.exe` import `bcrypt.dll`
  (`tools/check_runtime_deps.py` `pe_imports`).
- 7-Zip is installed on the development machine
  (`C:\Program Files\7-Zip\7z.exe`): an independent tool for the owed GUI step
  (an archive created by the plugin must test OK with `7z t -p…`), and the
  probe `probe/zip_salts.py` reads the salts / ZipCrypto headers out of any set
  of archives and reports repeats, so SC-001 is checked by a script, not by eye.
- Creating an archive through the plugin needs the Pack dialog (no headless
  entry point); that step is owed to a person (`quickstart.md`).

## R4 — Out of scope

- The vendored 7-Zip engine (`src/plugins/7zip/7za`, 16.04) has its own
  generator for 7z AES (`RandGen.cpp`) — NEXT-WORK item 8.
- ZIP 2.0 encryption itself is weak by design; this feature does not change
  which methods are offered.
- `PRIVACY.md` makes no statement about archive encryption (checked) — no
  update required.
