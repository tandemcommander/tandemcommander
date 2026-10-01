# Closing Report: Working Archivers Only (feature 084)

**Date**: 2026-10-01 · **Branch**: `084-archiver-cleanup` · **Version**: stays
0.1.8 / build 192 (unreleased; `CHANGELOG.md` `[Unreleased]`) · **Plug-in
interface**: 106, unchanged

## What the user gets

- **External archivers work for the first time.** Since 0.1.0 every external
  archiver operation failed with "Unable to execute new process
  ...\utils\salspawn.exe": the helper that started every archiver was never
  built into any release. The archiver is now started directly, in a
  kill-on-close job object.
- **Cancel.** A wait window with *Cancel* appears while an archiver packs or
  unpacks, and Esc cancels too. A listing honours the caller's "Reading list…"
  window and Esc.
- **Only working programs.**
  - Of the 12 archivers of 0.1.8, seven were MS-DOS programs that cannot run
    on 64-bit Windows; all twelve were 1990s versions. They are gone, together
    with their texts, the panel parsers, the floppy presets and the DOS menu
    variables. The DOS variables still expand in existing commands.
  - What remains: **7-Zip** (new; browses and unpacks ARJ, LZH/LHA) and **RAR
    (WinRAR)** (packing).
  - Each is offered only while its program is found. Autoconfiguration finds
    both from their usual installation without a disk scan.
- **Unicode.** Names outside the code page survive listing and unpacking with
  7-Zip (UTF-8 listing, UTF-16 list files; verified with 7-Zip 22.01, emoji
  included, on a `.7z` fixture). The RAR packer uses the same UTF-16 list
  file but has **never been run** (WinRAR is not installed).
- **RAR archives still cannot be opened or unpacked** — that is stage S7,
  blocked (below). The CHANGELOG says so.
- **Upgrade.** Configuration version 106 removes the stored entries and
  associations of the removed archivers once, including edited ones (Q4).
  Entries that call a program by their own path are kept.

## Delivered per stage

| Stage | Status | Evidence |
|---|---|---|
| S1 direct launch, job, Cancel, error wording, `salspawn` removed | done | build; saltests; review #1/#2; experiments by the reviewers |
| S2 archiver table → 7-Zip + RAR, removals, `$(ListUnicodeFullName)` | done | build; reviews; `inventory_check.py` |
| S3 `-slt -ba` parser + 7-Zip browse/unpack | done | saltests `TestSevenZipList084` (real capture, injection refusal); reviewer harness on all fixtures and crafted archives |
| S4 availability, hiding, Autoconfiguration | done (code); GUI unverified | reviews |
| S5 migration 106 | done (code + pure decisions); GUI probe unverified | saltests `TestArchiverMigration084` |
| S6 strings, translations (8 languages), help, docs, inventory, CHANGELOG, PRIVACY | done | per-language HEAD comparison: 0 changed rows, 74 removed, 15 added; full builds |
| **S7 RAR out of the box** | **blocked** | needs NEXT-WORK item 8, the vendored 7-Zip 16.04 → 25.x upgrade (RAR remote-code-execution CVEs) |

## Gates

- `build.cmd full` (Debug) and `build.cmd full release`: **OK**.
  - 20 plug-ins, 189 language modules.
  - Runtime closure OK: 219 modules, 4 runtime DLLs shipped.
  - The Release exe contains the new code and no `salspawn`.
- `saltests`: **1647 checks, 0 failed** (1527 + 120 new checks for the parser and the migration decisions).
- `check_encoding.py --strict`: **TOTAL 0**.
- `probe/inventory_check.py`: **0 problems**. It was proven to fire on two
  planted defects.
- Reviews:
  - #1: **REJECT**, 1 blocker + 4 SHOULD-FIX, all fixed;
  - #2: **ACCEPT WITH FIXES**, 1 SHOULD-FIX, fixed;
  - #3: final truthfulness review of every text and record, **ACCEPT WITH
    FIXES** — 4 SHOULD-FIX and the NITs fixed (CHANGELOG, PRIVACY validity
    line, help, contracts, spec/plan/data model/research, task notes,
    translation terminology); dead strings recorded (`fix-log.md`).
- After review #3: translation merge 0 DeepL characters, comparison with HEAD
  0 changed rows in all 8 languages, `build.cmd full` OK.

## Owed to a person (not done, not claimed)

At the maintainer's request (2026-10-01) the GUI probes were written but **not
run**, because they need the maintainer's own Tandem Commander closed and the
registry key backed up:

- `probe/make_cfg_fixtures.ps1`: the 0.1.8 configuration fixture (T005).
- `probe/gui_probe.ps1`:
  - Autoconfiguration;
  - browsing and extracting ARJ and Unicode through 7-Zip;
  - hiding when `7z.exe` is missing;
  - Cancel on a 7-Zip waiting for a password;
  - the 0.1.8 → 106 migration, with an idempotence check and a diff outside
    the archiver configuration (T017, T042, quickstart §2 and §5).
- The visual pass of the dialogs in English and Czech (T056).
- RAR packing with WinRAR 7.x (quickstart §4); WinRAR is not installed on the
  development machine.

## Follow-ups

1. **NEXT-WORK item 8**: upgrade the vendored 7-Zip to 25.x, then stage S7 of
   this feature (T046–T053): RAR through the 7zip plug-in. The 7zip plug-in's
   texts need translating then (T057).
2. **The translation matcher identity**, the third time it matters: string
   rows are keyed by bundle *ordinal*. 084 avoided the damage by re-keying
   its input (`probe/rekey_stringtables.py`). The tool should key by ID; that
   needs a one-time migration of every `.origin` sidecar.
3. **Open decision (research R5)**: after item 8, the 7zip plug-in could read
   ARJ/LZH itself, without the user installing 7-Zip.
4. **Recorded NITs**:
   - (re-review 3) partial-claim overlap in `AddToExtensions`;
   - (4) Autoconfiguration can switch a hand-made `rar` record's viewer to RAR;
   - (5) whether the cancelling Esc also reaches the panel;
   - (6) `\\?\` paths and disconnected mapped drives at start-up;
   - `IDS_PACKERR_NOOUTPUT`, `IDS_PACKERR_ARCCFG` and `IDS_PACKERR_DATETIME`
     are now unused (remove with the next string change of `salamand`).
6. **FR-003's version clause is open**: no minimum version of 7-Zip or WinRAR
   is stated; only 7-Zip 22.01 was tested. Needs the owed WinRAR test and a
   check of the oldest 7-Zip with `-ba`/`-scc`/`-scs`.
7. **`PRIVACY.md`** now describes 0.1.8 plus the unreleased changes; the
   release updates its validity line as usual.
5. **The 3 disabled languages** keep the old `salamand.slt` layout; re-enabling
   one needs the re-key and the merge.
