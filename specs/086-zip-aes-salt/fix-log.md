# Fix log: 086 unpredictable salts for encrypted ZIP archives

Baseline `e10dfa2` (`main`, after feature 085). Branch `086-zip-aes-salt`.
Protocol: `specs/069-finish-encoding-fixes/contracts/fix-protocol.md`.

## T001 — HEAD check

| Site | Defect | Present at `e10dfa2` |
|---|---|---|
| `src/plugins/zip/crypt.cpp:118-127` `FillBufferWithRandomData` | `srand(time ^ pid)` once, `(rand() >> 7) & 0xff` per byte | yes |
| `src/plugins/zip/add.cpp:1632` | AES salt (8/16 B) from it | yes |
| `src/plugins/zip/crypt.cpp:141` `CryptHeader` | 11 random bytes of the ZIP 2.0 header from it | yes |

Severity as measured in research R1: predictable (one guessable 32-bit seed
per run), repeated only across runs with an equal seed.

## T002–T005, T008 — the change

- `src/common/salrandom.h` (new, header-only): `SalGenRandom` —
  `BCryptGenRandom`, system-preferred RNG; `#pragma comment(lib, "bcrypt.lib")`.
- `src/plugins/zip/crypt.cpp` `FillBufferWithRandomData` → `SalGenRandom`; the
  old `srand(time ^ pid)` / `rand()` generator only as a `TRACE_E`-traced
  fallback.
- `src/pwdmngr.cpp` `FillBufferWithRandomData` (feature 085 F6) → the same
  `SalGenRandom` instead of its own `BCryptGenRandom` call; fallback unchanged.
- `src/saltests/saltests.cpp` `TestRandom086`: saltests 1816 → **1829 checks,
  0 failed**.
- Debug build: `crypt.cpp` and `pwdmngr.cpp` compiled, no warnings in them;
  `zip.spl` and `tandemcommander.exe` import `bcrypt.dll`.

## T006 — salt reader

`probe/zip_salts.py --selftest`: **PASS** — reads the AES-256, AES-128 and
ZipCrypto entries of five archives 7-Zip made (salt 16/8 bytes, header 12),
reports 0 repeats among them, and reports exactly 1 when the same archive is
given twice.

## T007 — ZIP 2.0 header and the other paths (analysis finding U1)

- `CryptHeader` (`crypt.cpp`) draws its 11 random bytes only through
  `FillBufferWithRandomData`; no other `rand()`/`srand()` exists anywhere in
  `src/plugins/zip/` (including `selfextr/`, `sfxmake/`, `zip2sfx/`) — the
  only hits are the fallback and comments in `crypt.cpp`.
- Multi-volume archives go through the same `add.cpp` path (`PA_MULTIVOL`).
- **A self-extracting archive cannot use AES at all**: `add_del.cpp:112`
  refuses it (`IDS_ECRYPTSFX`); SFX archives use ZIP 2.0 encryption, covered
  by `CryptHeader`. Spec edge case corrected accordingly.

## T009 — gates

| Gate | Result |
|---|---|
| Debug x64 (`build.cmd`) | succeeded, no warnings in the touched files |
| `build.cmd full release` | succeeded; runtime closure OK (219 modules) |
| `saltests` | 1829 checks, 0 failed |
| `probe/zip_salts.py --selftest` | PASS |
| `tools/check_encoding.py` | TOTAL: 0 |
| imports | `bcrypt.dll` in Debug and Release `zip.spl`, and in `tandemcommander.exe` |
| plugin interface | `git diff src/plugins/shared/` empty — interface 106 |

## T010 — independent review: ACCEPT

No blocker. Confirmed: one `BCryptGenRandom` call over exactly `len` bytes;
both fallbacks still fill the buffer; include order safe in all three modules;
`inline` in a header included by one source per module; no
`/NODEFAULTLIB`; salt buffer 16 + 2 bytes; no other `rand()` in the plugin
(temp-file names from `GetTickCount` are not security-relevant); the reading
path never generates random data; the probe's 0x9901 parsing is correct;
severity statement and the SFX/AES restriction accurate. Its four NITs were
applied:

- the ZIP 2.0 header has 11 random bytes **drawn**, of which 10 survive when
  the time check is two bytes (the usual case) — records reworded;
- the probe compares the 10-byte random prefix of ZipCrypto headers (the
  encrypted check bytes differ with the time and would hide a repeated
  prefix); same password assumed, as the quickstart does;
- the probe no longer raises `IndexError` on a truncated 0x9901 field;
- `salrandom.h` is listed in `salamand.vcxproj` / `.filters`.

The reviewer also noted that statistical tests cannot tell a weak generator
from a strong one (the old one would pass them too); the evidence for the
source is the code and the import table, not the tests.

## Owed to a person

`quickstart.md` steps 1–7: create AES-256/AES-128/ZIP 2.0 archives through the
Pack dialog, run `probe/zip_salts.py` over them (repeats: 0), test them with
7-Zip, extract them in Tandem Commander, and open an encrypted archive made by
0.1.8.
