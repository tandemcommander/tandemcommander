# Contract: `CSalamanderGeneralAbstract::ExpandPluralBytesFilesDirs` returns UTF-8 (feature 157)

**Interface version:** 107, unchanged (no new method, no new parameter).

**Before:** the plural template was the core's code-page text (`LoadStr`); the number came from
`NumberToStr`, whose thousands separator is UTF-8 (`SalGetLocaleInfoU8`; a no-break space in
cs, fr, hu). The result was valid in neither encoding.

**After:** the whole text is UTF-8 (`LoadStrU8` template). The purpose of the method is the
information line (`useSubTexts` marks the number for `LookForSubTexts` /
`CPluginDataInterfaceAbstract::GetInfoLineContent`), and the core draws the information line as
UTF-8 (`CStatusWindow::SetText`, `SalU8ToWDisplayAlloc`).

**Callers in the tree:** the FTP client (`plugins/ftp/fs4.cpp`, the information line - now
correct); demoplug and regedt only in commented-out examples. A plug-in that shows the text
elsewhere must use a wide API or a core service that takes UTF-8 - the same rule as
`GetCommonFSOperSourceDescr` since feature 134.

**Unchanged:** `ExpandPluralFilesDirs` and `ExpandPluralString` for plug-ins (the Batch Renamer
relies on the code-page result of `ExpandPluralFilesDirs`, feature 131).
