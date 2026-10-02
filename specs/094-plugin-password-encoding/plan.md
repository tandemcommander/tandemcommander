# Implementation Plan: ZIP and SFTP password forms

**Branch**: `094-plugin-password-encoding` (from `main`) | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

## Summary

The ZIP plug-in keeps the typed password as UTF-16 and derives byte forms
from it: one form for packing (code page if representable, else UTF-8), an
ordered candidate list for unpacking. The SFTP plug-in's three secret reads
get buffers that cannot overflow into the code-page fallback.

## Technical Context

- C++ (MSVC v143). ZIP plug-in `src/plugins/zip` is an ANSI build with its own
  dialogs (`DialogBoxParam`, `GetDlgItemTextA`); SFTP plug-in
  `src/plugins/sftp`.
- Pure logic (candidate derivation, representability) in a header-only helper
  under `src/common` (the ZIP project cannot compile a shared `.cpp` - see
  feature 086, `salrandom.h`), tested by saltests.
- No new strings, no interface change (107), no configuration change.
- `PRIVACY.md`: the crash report no longer can contain a ZIP password through
  the call-stack text - reviewed and updated in the same change.

## Constitution Check

Backward compatibility: every archive an earlier version created opens with
the password the user remembers (candidate 4 for the `?` form); in-code-page
archives are written exactly as before. Incremental: two plug-ins, two
stages. Plug-in architecture: untouched. Gate passes.

## Stages

| Stage | Content | Evidence |
|---|---|---|
| **S1** ZIP | helper `src/common/salzippwd.h`; wide read in the three password dialogs; pack form; unpack candidates for AES and classic encryption, with the retry after a checksum failure and "remember only what verified"; password out of the call-stack text; wipes | saltests; `probe/zipkey.py` (which bytes key an archive); `probe/zip_gui_probe.ps1` extended, new and previous build, hidden desktop |
| **S2** SFTP | the three secret reads cannot fall back | `probe/sftp_gui_probe.ps1` with the logging server |
| **S3** gates & records | builds, saltests, guard, earlier probes, CHANGELOG, NEXT-WORK, CLAUDE.md, PRIVACY.md, quickstart | - |

Each stage: implement, build, test, independent review, fixes, commit.

## Risks

1. Unpack path state (which form verified, the session cache of passwords,
   multi-item archives with different passwords) - the 093 lesson: a form is
   chosen per item, never per archive.
2. The classic encryption's weak check: a wrong form that passes it writes
   garbage before the checksum fails - the retry must restart that item
   cleanly (output file handling as on today's CRC-error path) and must not
   delete or overwrite anything the old path would not.
3. AES 128-byte limit against forms of different lengths.
4. The self-extractor shares source files with the plug-in (`crypt.cpp` may be
   compiled into the stub): changes must not break or alter the stub.

## Project Structure

```
specs/094-plugin-password-encoding/  spec.md plan.md research.md tasks.md
                                     contracts/zip-password-forms.md
                                     quickstart.md fix-log.md probe/
src/common/salzippwd.h               new, header-only
src/plugins/zip/{dialogs,extract,add,crypt,...}   S1
src/plugins/sftp/dialogs.cpp         S2
src/saltests/saltests.cpp
```
