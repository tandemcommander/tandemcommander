# Verdicts: the 78 findings of `check_encoding.py --plugins` (feature 255)

Lines are those at e849e68c (`baseline_e849e68c.txt`, the scan's order). *Shipped* is the plug-in's
`plugins.cfg` value (`shared` = shared code). A *false positive* carries the same reason in a
`// encoding-check: allow <rule> - <reason>` marker above its line; a *real defect* is left
unannotated and has a backlog item. Totals: 68 false positives, 10 real defects in
8 items (+ the follow-up `plugin-encoding-scan-strict-in-build`). Rows 35, 65,
66 and 74 were changed by the independent review (fix-log, *Review*).

| # | Site | Rule | Shipped | Verdict | Reason / item |
|---|---|---|---|---|---|
| 1 | `plugins/7zip/dialogs.cpp:601` | utf8-to-legacy-sink | on | false positive | the control is the core's static text (AttachStaticText): the bytes reach CStaticText unchanged and are drawn as UTF-8 (131, 255) |
| 2 | `plugins/automation/cfgdlg.cpp:747` | utf8-to-legacy-sink | off | real defect | `automation-script-folder-list-code-page` |
| 3 | `plugins/checkver/dialogs.cpp:314` | mixed-composition | off | false positive | itemName is read from the ANSI list box (LB_GETTEXT) - code page like the LoadStr template (255) |
| 4 | `plugins/dbviewer/dialogs.cpp:524` | utf8-to-legacy-sink | on | real defect | `dbviewer-field-length-separator` |
| 5 | `plugins/dbviewer/dialogs.cpp:530` | utf8-to-legacy-sink | on | false positive | a number printed with %d - ASCII (255) |
| 6 | `plugins/filecomp/controls.cpp:275` | utf8-to-legacy-sink | on | false positive | digits, '%' and the locale decimal separator, ASCII ',' or '.' unless the user sets another decimal symbol - latent, deferred like the core's twin (067, ledger L06) (255) |
| 7 | `plugins/filecomp/controls.cpp:411` | utf8-to-legacy-sink | on | false positive | digits, '%' and the locale decimal separator, ASCII ',' or '.' unless the user sets another decimal symbol - latent, deferred like the core's twin (067, ledger L06) (255) |
| 8 | `plugins/filecomp/mainwnd.cpp:806` | utf8-to-legacy-sink | on | false positive | SendMessageW with the UTF-16 text (SplU8ToWAlloc) - the wide message (255) |
| 9 | `plugins/ftp/dialogs6.cpp:121` | dead-dispinfow | on | false positive | both list views get ListView_SetUnicodeFormat(TRUE) below, so the W handler runs (010, 255) |
| 10 | `plugins/mmviewer/renmain.cpp:93` | mixed-composition | off | real defect | `mmviewer-open-error-name-mojibake` |
| 11 | `plugins/pictview/dialogs.cpp:232` | ansi-template-number | on | false positive | the number is printed by the template's %d (ASCII, not grouped); template and Static_SetText are code page (255) |
| 12 | `plugins/pictview/dialogs.cpp:236` | ansi-template-number | on | false positive | the number is printed by the template's %d (ASCII, not grouped); template and Static_SetText are code page (255) |
| 13 | `plugins/pictview/pictview.cpp:1577` | mixed-composition | on | false positive | path is converted to the code page just above (CP_ACP), like the LoadStr template (255) |
| 14 | `plugins/regedt/finddlg2.cpp:996` | dead-dispinfow | on | false positive | CFindDialog is a CDialogEx created by CreateDialogParamW - a Unicode dialog, so its list view sends W notifications (255) |
| 15 | `plugins/unmime/unmime.cpp:408` | mixed-composition | off | real defect | `unmime-progress-title-name-mojibake` |
| 16 | `plugins/unmime/unmime.cpp:449` | mixed-composition | off | real defect | `unmime-progress-title-name-mojibake` |
| 17 | `plugins/zip/add.cpp:3374` | mixed-composition | on | false positive | inside the commented-out old CZipPack::LoadDefaults - not compiled; the live copy in add_del.cpp uses LoadStrU8 (130, 255) |
| 18 | `plugins/zip/prevsfx.cpp:131` | utf8-to-legacy-sink | on | false positive | a code-page path (GetCurrentDirectoryA) shown in the ANSI preview of the self-extractor dialog - code page on both sides (255) |
| 19 | `plugins/zip/selfextr/dialog.cpp:243` | utf8-to-legacy-sink | on | false positive | the self-extractor is a stand-alone ANSI program; its texts are code-page bytes the ZIP plug-in wrote from ANSI edits, LoadStr or a .sfx package (255) |
| 20 | `plugins/zip/selfextr/dialog.cpp:244` | utf8-to-legacy-sink | on | false positive | the self-extractor is a stand-alone ANSI program; its texts are code-page bytes the ZIP plug-in wrote from ANSI edits, LoadStr or a .sfx package (255) |
| 21 | `plugins/zip/selfextr/dialog.cpp:678` | utf8-to-legacy-sink | on | false positive | the self-extractor is a stand-alone ANSI program; TargetPath comes from ANSI APIs and its own ANSI edit - code page on both sides (255) |
| 22 | `plugins/zip/selfextr/dialog.cpp:763` | utf8-to-legacy-sink | on | false positive | the self-extractor is a stand-alone ANSI program; TargetPath comes from ANSI APIs and its own ANSI edit - code page on both sides (255) |
| 23 | `plugins/zip/selfextr/dialog.cpp:786` | utf8-to-legacy-sink | on | false positive | the self-extractor is a stand-alone ANSI program; TargetPath comes from ANSI APIs and its own ANSI edit - code page on both sides (255) |
| 24 | `plugins/zip/selfextr/dialog.cpp:787` | utf8-to-legacy-sink | on | false positive | the self-extractor is a stand-alone ANSI program; its texts are code-page bytes the ZIP plug-in wrote from ANSI edits, LoadStr or a .sfx package (255) |
| 25 | `plugins/zip/selfextr/dialog.cpp:789` | utf8-to-legacy-sink | on | false positive | the self-extractor is a stand-alone ANSI program; its texts are code-page bytes the ZIP plug-in wrote from ANSI edits, LoadStr or a .sfx package (255) |
| 26 | `plugins/zip/selfextr/dialog.cpp:790` | utf8-to-legacy-sink | on | false positive | the self-extractor is a stand-alone ANSI program; its texts are code-page bytes the ZIP plug-in wrote from ANSI edits, LoadStr or a .sfx package (255) |
| 27 | `plugins/zip/selfextr/dialog.cpp:794` | utf8-to-legacy-sink | on | false positive | the self-extractor is a stand-alone ANSI program; its texts are code-page bytes the ZIP plug-in wrote from ANSI edits, LoadStr or a .sfx package (255) |
| 28 | `plugins/zip/selfextr/dialog.cpp:802` | utf8-to-legacy-sink | on | false positive | the self-extractor is a stand-alone ANSI program; its texts are code-page bytes the ZIP plug-in wrote from ANSI edits, LoadStr or a .sfx package (255) |
| 29 | `plugins/automation/fileinfo.cpp:250` | lossy-lenient-at-intake | off | false positive | the text is only shown (DialogError / DialogOverwrite / DialogQuestion), never used to find a file (255) |
| 30 | `plugins/automation/fileinfo.cpp:260` | lossy-lenient-at-intake | off | false positive | the text is only shown (DialogError / DialogOverwrite / DialogQuestion), never used to find a file (255) |
| 31 | `plugins/automation/fileinfo.cpp:265` | lossy-lenient-at-intake | off | false positive | the text is only shown (DialogError / DialogOverwrite / DialogQuestion), never used to find a file (255) |
| 32 | `plugins/automation/strconv.cpp:48` | lossy-lenient-at-intake | off | false positive | OLE2A serves a question text and a trace only - shown, never a name for an operation (255) |
| 33 | `plugins/automation/strconv.cpp:55` | lossy-lenient-at-intake | off | false positive | OLE2A serves a question text and a trace only - shown, never a name for an operation (255) |
| 34 | `plugins/automation/strconv.cpp:59` | lossy-lenient-at-intake | off | false positive | OLE2A serves a question text and a trace only - shown, never a name for an operation (255) |
| 35 | `plugins/checkver/logwnd.cpp:172` | strict-probe-rejects-wtf8 | off | real defect | `checkver-log-script-path-garbled` |
| 36 | `plugins/codeview/intake.cpp:163` | lossy-lenient-at-intake | on | false positive | decoded file contents for the viewer (shown), not a name (255) |
| 37 | `plugins/codeview/intake.cpp:168` | lossy-lenient-at-intake | on | false positive | decoded file contents for the viewer (shown), not a name (255) |
| 38 | `plugins/codeview/webglue.cpp:54` | lossy-lenient-at-intake | on | false positive | a virtual-host request path, compared with fixed ASCII asset names (255) |
| 39 | `plugins/codeview/webglue.cpp:57` | lossy-lenient-at-intake | on | false positive | a virtual-host request path, compared with fixed ASCII asset names (255) |
| 40 | `plugins/filecomp/filecomp.cpp:173` | strict-probe-rejects-wtf8 | on | false positive | an encoding label (e.g. 'UTF-8', 'windows-1250'), not a name (255) |
| 41 | `plugins/ftp/ftputils.cpp:3627` | strict-probe-rejects-wtf8 | on | false positive | bytes of a server's listing (protocol); a server does not send the WTF-8 form, the code-page reading is the documented fallback (224, 255) |
| 42 | `plugins/ftp/ftputils.cpp:3645` | lossy-lenient-at-intake | on | false positive | the input was decoded from the code page just above - valid Unicode by construction (255) |
| 43 | `plugins/ftp/ftputils.cpp:3651` | lossy-lenient-at-intake | on | false positive | the input was decoded from the code page just above - valid Unicode by construction (255) |
| 44 | `plugins/mdview/htmlgen.cpp:38` | lossy-lenient-at-intake | on | false positive | document text for the page (shown), not a name (255) |
| 45 | `plugins/mdview/htmlgen.cpp:41` | lossy-lenient-at-intake | on | false positive | document text for the page (shown), not a name (255) |
| 46 | `plugins/mdview/viewer.cpp:30` | lossy-lenient-at-intake | on | false positive | document text for the page (shown), not a name (255) |
| 47 | `plugins/mdview/viewer.cpp:34` | lossy-lenient-at-intake | on | false positive | document text for the page (shown), not a name (255) |
| 48 | `plugins/mdview/viewer.cpp:70` | lossy-lenient-at-intake | on | false positive | a link URI from WebView2 navigation is percent-encoded ASCII; a lone surrogate cannot be written in a URL (255) |
| 49 | `plugins/mmviewer/mmviewer.cpp:1412` | lossy-lenient-at-intake | off | false positive | the input was decoded from the code page just above - valid Unicode by construction (255) |
| 50 | `plugins/mmviewer/mmviewer.cpp:1468` | lossy-lenient-at-intake | off | false positive | a tag text of the media file (shown), not a name (255) |
| 51 | `plugins/mmviewer/mmviewer.cpp:1473` | lossy-lenient-at-intake | off | false positive | a tag text of the media file (shown), not a name (255) |
| 52 | `plugins/mmviewer/mp3/id3tagv2.cpp:258` | lossy-lenient-at-intake | off | false positive | an ID3 tag text (shown), not a name (255) |
| 53 | `plugins/portables/device.cpp:69` | lossy-lenient-at-intake | on | false positive | a device's friendly name from the WPD manager, converted the same way wherever it is used, so a look-up by it still matches; not a file name (255) |
| 54 | `plugins/portables/device.cpp:72` | lossy-lenient-at-intake | on | false positive | a device's friendly name from the WPD manager, converted the same way wherever it is used, so a look-up by it still matches; not a file name (255) |
| 55 | `plugins/regedt/fs2.cpp:585` | lossy-lenient-at-intake | on | false positive | a preview of a registry value's data (shown in the panel), not a name (255) |
| 56 | `plugins/regedt/regedt.cpp:90` | lossy-lenient-at-intake | on | false positive | a resource string (LoadStrW) - valid Unicode by construction (255) |
| 57 | `plugins/regedt/regedt.cpp:102` | lossy-lenient-at-intake | on | false positive | a resource string (LoadStrW) - valid Unicode by construction (255) |
| 58 | `plugins/regedt/regedt.cpp:106` | lossy-lenient-at-intake | on | false positive | a resource string (LoadStrW) - valid Unicode by construction (255) |
| 59 | `plugins/regedt/regedt.cpp:157` | lossy-lenient-at-intake | on | false positive | the system's error text (FormatMessageW) - shown, not a name (255) |
| 60 | `plugins/renamer/crenamer.cpp:800` | strict-probe-rejects-wtf8 | on | false positive | deliberate (208): a part that is not strict UTF-8 (WTF-8 too) is copied unchanged - the name keeps its bytes, only the case change is skipped (255) |
| 61 | `plugins/renamer/crenamer.cpp:811` | strict-probe-rejects-wtf8 | on | false positive | the same text the strict probe above accepted (255) |
| 62 | `plugins/renamer/crenamer.cpp:894` | lossy-lenient-at-intake | on | false positive | UTF-16 from a strict UTF-8 decode, case-changed or normalized - valid Unicode by construction (255) |
| 63 | `plugins/renamer/crenamer.cpp:899` | lossy-lenient-at-intake | on | false positive | UTF-16 from a strict UTF-8 decode, case-changed or normalized - valid Unicode by construction (255) |
| 64 | `plugins/renamer/preview.cpp:140` | strict-probe-rejects-wtf8 | on | real defect | `renamer-wtf8-names-shown-as-mojibake` |
| 65 | `plugins/shared/lukas/utildlg.cpp:12` | strict-probe-rejects-wtf8 | shared | false positive | not compiled: no project builds shared/lukas/utildlg.cpp; the Renamer links its own HistoryComboBox (renamer/dialogs.cpp, SplU8ToWAlloc) (255) |
| 66 | `plugins/shared/lukas/utildlg.cpp:17` | strict-probe-rejects-wtf8 | shared | false positive | not compiled: no project builds shared/lukas/utildlg.cpp; the Renamer links its own HistoryComboBox (renamer/dialogs.cpp, SplU8ToWAlloc) (255) |
| 67 | `plugins/tar/tardll.cpp:149` | strict-probe-rejects-wtf8 | on | false positive | name bytes read from the archive (format boundary); the WTF-8 form of a core name does not arise there, the code-page reading is the documented fallback (255) |
| 68 | `plugins/uncab/uncab.cpp:211` | strict-probe-rejects-wtf8 | on | false positive | name bytes read from the archive (format boundary); the WTF-8 form of a core name does not arise there, the code-page reading is the documented fallback (255) |
| 69 | `plugins/uniso/hfs.cpp:276` | lossy-lenient-at-intake | on | real defect | `uniso-hfs-names-lossy-surrogates` |
| 70 | `plugins/uniso/hfs.cpp:321` | lossy-lenient-at-intake | on | real defect | `uniso-hfs-names-lossy-surrogates` |
| 71 | `plugins/uniso/iso9660.cpp:326` | lossy-lenient-at-intake | on | false positive | fallback after SplWToU8 (WTF-8, total since 089), which fails only on a too small buffer; a Joliet name (length byte <= 255, <= 127 units) always fits 'final' (255) |
| 72 | `plugins/uniso/udf.cpp:159` | lossy-lenient-at-intake | on | false positive | fallback after SplWToU8 (WTF-8, total since 089), which fails only on a too small buffer; a UDF name (length byte <= 255) always fits 'final' (255) |
| 73 | `plugins/uniso/udfiso.cpp:135` | lossy-lenient-at-intake | on | false positive | fallback after SplWToU8 (WTF-8, total since 089), which fails only on a too small buffer; 64 units always fit 'volId' (255) |
| 74 | `plugins/uniso/uniso.cpp:144` | strict-probe-rejects-wtf8 | on | real defect | `uniso-joliet-file-names-wtf8-garbled` |
| 75 | `plugins/unmime/parser.cpp:659` | strict-probe-rejects-wtf8 | off | false positive | name bytes read from the archive (format boundary); the WTF-8 form of a core name does not arise there, the code-page reading is the documented fallback (255) |
| 76 | `plugins/unole/unole2.cpp:213` | lossy-lenient-at-intake | off | false positive | fallback after SplWToU8 (WTF-8, total since 089), which fails only on a too small buffer; an OLE element name (<= 31 units) always fits 'name' (255) |
| 77 | `plugins/zip/common.cpp:1703` | lossy-lenient-at-intake | on | false positive | the input was decoded from the code page just above - valid Unicode by construction (255) |
| 78 | `plugins/zip/common.cpp:1709` | lossy-lenient-at-intake | on | false positive | the input was decoded from the code page just above - valid Unicode by construction (255) |
