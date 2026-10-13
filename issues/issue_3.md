URL: https://github.com/tandemcommander/tandemcommander/issues/3

**Version:** Tandem Commander 0.1.9 (x64), Czech language, Windows 11

**Steps to reproduce**
1. Switch Tandem Commander to Czech (or any language whose translation of "KEY" has non-ASCII letters).
2. Open the Registry Editor plug-in (`reg:`), e.g. `reg:\HKEY_CURRENT_USER\SOFTWARE`.
3. Focus any key and look at the information line (or the Size column in the Detailed view).

**Expected:** `User Menu: KLÍČ, 08.10.2026, 13:45:38`
**Actual:** `User Menu: KL��  , 08.10.2026, 13:45:38` - the accented letters become two replacement characters.

**Cause**

`InitFS()` in `src/plugins/regedt/fs.cpp` loads the text with the code-page `LoadStr(IDS_KEY)`, and `GetSizeText()` in `fs4.cpp` passes it to the core unchanged. The core shows column texts as UTF-8 (feature 004), so the CP1250 bytes `4B 4C CD C8` of "KLÍČ" are invalid UTF-8. English is not affected ("KEY" is ASCII), which is probably why it went unnoticed. Other texts of the plug-in, e.g. "(Default)", already go through `LoadStrW` + `WStrToU8` and display fine.

The buffer `KeyText[10]` is also too small for UTF-8: a longer translation such as the German "SCHLÜSSEL" (10 bytes in UTF-8 + NUL) would be cut.

**Proposed fix** (tested on 0.1.9 with the Czech language module)

```diff
--- a/src/plugins/regedt/regedt.h
+++ b/src/plugins/regedt/regedt.h
@@ -186,7 +186,7 @@ struct CRegTypeText
 
 extern CRegTypeText RegTypeTexts[];
 
-extern char KeyText[10];
+extern char KeyText[64]; // UTF-8, room for any translation
 extern int KeyTextLen;
 
--- a/src/plugins/regedt/fs.cpp
+++ b/src/plugins/regedt/fs.cpp
@@ -49,8 +49,8 @@ CRegTypeText RegTypeTexts[] =
-char KeyText[10];
-int KeyTextLen = 10;
+char KeyText[64]; // UTF-8, room for any translation
+int KeyTextLen = 0;
@@ -104,7 +104,9 @@ BOOL InitFS()
-    lstrcpyn(KeyText, LoadStr(IDS_KEY), 10);
+    // the Size column / info line text goes to the core as UTF-8
+    if (WStrToU8(KeyText, sizeof(KeyText), LoadStrW(IDS_KEY)) == 0)
+        strcpy(KeyText, "KEY");
     KeyTextLen = (int)strlen(KeyText);
```

With the fix the information line shows `KLÍČ` (UTF-8 bytes `4B 4C C3 8D C4 8C`).
