Thank you for the report and for the analysis - it is confirmed, and it led to more than the one word.

**Verdict: valid.** Fixed for the next release, **0.1.10** (feature 124, branch `124-regedt-key-text`).

### What was measured on 0.1.9

I reproduced it on the released 0.1.9 in English and in all eight shipped translations (a test key under `HKCU\Software`, the panel and the information line read from screen captures, the plug-in's Find window read with `LVM_GETITEMTEXTW`):

| Place | 0.1.9 |
|---|---|
| Information line, a key focused (`name: KEY, date, time`) | garbled in Czech (`KL��`), German (`Schl�ssel`), Slovak (`K���`) - as reported |
| Information line, keys/values selected (`1 vybraný klíč`) | garbled in Czech, German, French, Hungarian, Slovak |
| Information line, the `(Default)` value focused | its translated name garbled in Czech, French, Hungarian, Slovak |
| Information line, a text value with accented data focused | the data garbled **in every language, English included** |
| Size column of the Detailed view | **correct** in all nine languages |
| The plug-in's Find window, Size cell of a found key | correct in all nine languages |

Two corrections to the report:

- **The Size column is not affected.** The panel draws a cell that is not valid UTF-8 as code-page text, so `KLÍČ` comes out right there; only the information line (which has no such fallback) shows the replacement characters. The cause you named is right all the same - the column only worked by that fallback.
- **The proposed patch would break the Find window.** `CFoundFilesData::GetText` (`finddlg.cpp`) converts `KeyText` with `CP_ACP`; once `KeyText` is UTF-8, found keys show `KLĂŤÄŚ` there. I built that variant as a control and measured exactly this in Czech, German and Slovak.

### The fix

All in `src/plugins/regedt`, no new strings, no interface change:

- the word for a key is kept twice: UTF-8 for the panel (Size column, information line) and the wide original for the Find window; a translation is never cut - the buffers hold every translation in the repository (the German word needs 10 bytes in UTF-8, the Russian 12; the old buffer held 9), and a text that would not fit is replaced by `KEY`, not shortened;
- the selection texts (`N selected keys / values`, the size prefix) are loaded as UTF-8;
- the name of the `(Default)` value is UTF-8 like every other name the plug-in gives to the panel (also inside the overwrite question of a copy/move);
- the preview of text values (`REG_SZ`, `REG_EXPAND_SZ`, `REG_MULTI_SZ`) is UTF-8; a long text ends with `...` after a whole character (it used to be cut at a byte position);
- the date and time of a key come from the wide locale functions;
- *Copy Name*, *Copy Full Name* and *Copy Path* put the text on the clipboard as Unicode (a name with accented letters was copied garbled), and the Find window shows a size of 1,000 and more with the right group separator.

The three before the last were found by an independent review of the first version of the fix - they sit in the same information line and had the same cause. The last one was found by a second, independent verification of the finished fix.

One visible difference besides the encoding: the preview of a text value is limited to 199 bytes of UTF-8 (it was 199 characters), so a long text with many accented letters ends with `...` earlier.

### Tests

An automated probe drives the program on a hidden desktop in each of the nine shipped languages (81 checks): Size column, information line for a key / the `(Default)` value / an accented text value / a 320-byte text / a selection of keys and values, the Find window, and a clean exit.

| Build | Result |
|---|---|
| 0.1.9 | 48 pass, **33 fail** (the rows listed above, and the 320-byte text in every language) |
| with the fix (run again on a clean rebuild of the final code) | **81 pass, 0 fail** |
| the fix with the Find window line as in the proposed patch | Find window fails in Czech, German, Slovak |

A static check confirms that all eleven translations of `KEY` in the repository fit whole.

### Left out on purpose

- Column *names* (`Type/Date`, `Size`, ...) are code-page text in the whole program (the core's own columns too) and are shown correctly wherever the language fits the Windows code page; that is a separate, program-wide matter.
- The plug-in's message boxes that put a registry name into a translated sentence belong to the class described in #7; five of them are handled there. Two older ones were found while this fix was verified and are fixed too (feature 129): the question whether to create a missing target key (Copy / Move) was an **empty** Yes / No box, and the "unable to open registry key" error was cut, when the key's name had a letter such as `č` or `ř`. The same cause made the values of different such keys share one temporary file when viewed with F3.
- The clipboard commands above could not be checked by the automated probe (it has no clipboard); they are checked by hand before the release.

The fix will be part of **Tandem Commander 0.1.10**.
