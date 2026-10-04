# Implementation Plan: A pack never writes its archive over a file it packs (feature 106)

**Branch**: `106-zip-overwrite-source` (from `105-pictview-saveas-loss`) | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

| Stage | Content |
|---|---|
| S0 measure | Pre-change build preserved (`Debug_x64_pre106`). Code reading of every pack route that creates, truncates or deletes an output (ZIP plug-in: normal, multi-volume, self-extractor, Create SFX, repair; 7-Zip plug-in; TAR; core Pack dialog, F5/F6/drag into an archive, external packers). `probe/packself_probe.ps1` on the build before (`probe/packself_result_measurement_pre106.txt`) |
| S1 rule | `src/common/salsamefile.h` (header-only, pure): `SalPackOutputIsSource` (same id incl. hard links, or no usable ids + equal metadata), `SalPackTargetInSelection` (a file item = the archive; a folder item = one of the archive's folders) |
| S2 core | `fileswn7.cpp`: `PackArchiveIsSelectedSource` (identity of the archive, of its folders up to the root, of each selected item) before the "Overwrite" delete; refusal `IDS_CANNOTCOPYFILETOITSELF` under `IDS_ERROROVERWRITINGFILE`, back to the dialog |
| S3 ZIP | `add.cpp`: `PackMultiVol` and `PackSelfExtract` list the files before creating anything; `CZipPack::IsPackedSource` (identity check against every file in `AddFiles`) at every volume (`CreateNextFile`, also with "overwrite all") and before the self-extractor; `RefusePackedSource` (`IDS_PACKEDSOURCE`); `TempNameOurs` - the cleanup deletes only a volume this operation created. New string 1255 (`zip.rh2`, `lang.rc2`) |
| S4 tests | saltests `TestPackSelf106`: the pure rules; real NTFS: 8.3 spelling, case, hard link, another file of equal size, the archive's own folder |
| S5 translations | `build_langs.cmd --export-templates --module zip`; `translate.merge --module zip` (DeepL); review; pins in `ui-overrides.json` (`_feature_106`); the committed files carry only the new row (the tool's unrelated re-layout of 510 controls not taken - recorded) |
| S6 probe | `probe/packself_probe.ps1` on both builds (hidden desktop); regressions 094 ZIP, 099 linkmove, 097 arcwork (subset), 103 samefile; full Release build; records |

No plug-in interface change (107), no configuration format change.
