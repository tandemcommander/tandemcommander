URL: https://github.com/tandemcommander/tandemcommander/issues/7

**Version:** Tandem Commander 0.1.9 (x64), Czech language, Windows 11

Several places compose a translated template from the code-page `LoadStr()` with UTF-8 text (file names, paths, and since feature 010 also the text of a Windows error from `GetErrorText()`). In a translation whose template has non-ASCII letters the composed text is not valid UTF-8, the UTF-8 sinks take their legacy path and draw everything as code page: the translated part looks right, the names and error texts are garbage. English is not affected (its templates are pure ASCII, which is valid UTF-8), which is probably why it went unnoticed.

**1. Find Files - the "Searching" status line**

1. Czech language; a folder with files named like `Příliš žluťoučký kůň 01.docx`.
2. Find Files (Alt+F7), *Search file content*, any text in *Containing*, *Find Now*; watch the status line.

Expected `Vyhledávání: C:\Data\Příliš žluťoučký kůň 01.docx`, actual `Vyhledávání: C:\Data\PĹ™Ă­liĹˇ ĹľluĹĄouÄŤkĂ˝ ...`.

The line is `CSearchingString`: a base set once in the `CFindDialog` constructor (`finddlg1.cpp`) from `LoadStr(IDS_FF_SEARCHING)` plus the UTF-8 path appended by the grep thread; the owner-drawn status bar (`WM_DRAWITEM` for `IDC_FIND_STATUS`) fails `SalU8ToWAlloc` and takes `DrawText`. The duplicates' result text (`IDS_FIND_DUPS_RESULTS`) is the same, and a long path cut by `lstrcpyn` to the line's buffer can end in the middle of a UTF-8 character, which makes the line invalid again.

**2. Find Files - the log ("Messages")**

1. Czech language; a folder with a subfolder you may not list: `icacls C:\Temp\test\denied /deny "%USERDOMAIN%\%USERNAME%:(RD)"`.
2. Find Files, *Look in* `C:\Temp\test`, *Include subdirectories*, *Find Now*, open the log.

Expected `Chyba při čtení adresáře: (5) Přístup byl odepřen.`, actual `Chyba při čtení adresáře: (5) PĹ™Ă­stup byl odepĹ™en.`

`find.cpp` composes `sprintf(message, LoadStr(IDS_DIRERRORFORMAT), GetErrorText(err))` (and the same for file open/read errors); `CFindLogDialog::Transfer` sets it with `SalListViewSetItemTextU8`, which falls back to the code page.

**3. Message boxes**

The same composition reaches `CMessageBox` (`SalU8ToWAlloc` fails, `DrawText`) in: a folder that cannot be read during Copy/Move, a name that is too long, a file too big for FAT32, a viewer/editor/command that cannot be started, a drive label that cannot be changed, file associations that cannot be read, a temporary file that cannot be created, plugin configuration import, errors in the viewer's `convert.cfg`.

**Why `tools/check_encoding.py` did not catch it**

Rule `mixed-composition` looks for a `LoadStr` format with a *name* argument handed to a message box. Case 1 composes in `CSearchingString`, not in one printf-family call. In cases 2 and 3 `GetErrorText()` was not counted as a UTF-8 argument, and neither `MSGBOXEX_PARAMS.Text` (when `SalMessageBoxEx` is more than 14 lines below, behind the button-names comment block) nor the Find Files log (`FIND_LOG_ITEM.Text`) were counted as sinks. With the extension in the diff below the rule reports exactly the 21 places of cases 2 and 3 on the current code and nothing after the fix. One more place it then reports, `InformAboutIconOvrlsHanCrash` in `callstk.cpp`, is correct as it is (the handler's name is read with `RegEnumKeyExA`, code page like the template) and is marked as an allowed exception.

**Proposed fix** (tested on 0.1.9 with the Czech language module)

- the templates are taken with `LoadStrU8`, so the whole text is valid UTF-8; the base of the status line's buffer grows to 300 bytes (a UTF-8 translation of "Searching:" takes up to three bytes a character)
- a long name cut to the status line's buffer is cut at a whole UTF-8 character (`SalFindTrimTornTail`, the existing helper of `salfindtext.h`, already included in `find.cpp`)
- the unbounded `sprintf` into arrays became `_snprintf_s(..., _TRUNCATE, ...)`: a UTF-8 template is longer than the code-page one
- the plain texts of the Find Files log use `LoadStrU8` too, for consistency (they were drawn correctly through the fallback)
- `check_encoding.py` extended as described above

Tested: the status line shows the Czech names correctly; the log case shows `Chyba při čtení adresáře: (5) Přístup byl odepřen.` (the log list read back with `LVM_GETITEMTEXTW`; before the fix the same probe read `PĹ™Ă­stup byl odepĹ™en.`); `check_encoding.py` reports 0 findings.

Not changed, worth a look: `CSalamanderGeneral::GetCommonFSOperSourceDescr` (`zip.cpp`) composes a code-page template with a UTF-8 file name for plugins; whether to change it depends on how plugins display the result. `drivelst.cpp` (reconnect dialog texts) only runs before Windows 7.

The diffs are against my tree, which carries other changes, so line numbers differ and one hunk's context names `TestFileBytes` (upstream: `TestFileContent`); the changed lines are the same.

Status line and duplicates (case 1):

```diff
--- a/src/finddlg1.cpp
+++ b/src/finddlg1.cpp
@@ -1405,8 +1405,10 @@ CFindDialog::CFindDialog(HWND hCenterAgainst, const char* initPath)
     StateOfFindCloseQuery = sofcqNotUsed;
     CanClose = TRUE;
     GrepThread = NULL;
-    char buf[100];
-    sprintf(buf, "%s ", LoadStr(IDS_FF_SEARCHING));
+    // the base is UTF-8 like the names appended to it: a code-page prefix made
+    // the whole line invalid UTF-8 and the status bar drew the names as code page
+    char buf[300];
+    _snprintf_s(buf, _TRUNCATE, "%s ", LoadStrU8(IDS_FF_SEARCHING));
     SearchingText.SetBase(buf);
     UpdateStatusBar = FALSE;
     ContextMenu = NULL;
--- a/src/find.cpp
+++ b/src/find.cpp
@@ -1034,7 +1034,7 @@ void CDuplicateCandidates::Examine(CGrepData* data)
     BOOL byContent = bySize && (data->FindDupFlags & FIND_DUPLICATES_CONTENT) != 0;
 
     // search completed, preparing results (MD5 computation may still follow)
-    data->SearchingText->Set(LoadStr(IDS_FIND_DUPS_RESULTS));
+    data->SearchingText->Set(LoadStrU8(IDS_FIND_DUPS_RESULTS));
 
     // sort them according to selected criteria
     QuickSort(0, Count - 1, byName, bySize, FALSE);
@@ -1114,7 +1114,7 @@ void CDuplicateCandidates::Examine(CGrepData* data)
             }
 
             // search finished, preparing results
-            data->SearchingText->Set(LoadStr(IDS_FIND_DUPS_RESULTS));
+            data->SearchingText->Set(LoadStrU8(IDS_FIND_DUPS_RESULTS));
 
             // sort the files again
             if (Count > 0)
@@ -2247,6 +2247,9 @@ void CSearchingString::Set(const char* buf)
 {
     HANDLES(EnterCriticalSection(&Section));
     lstrcpyn(Buffer + BaseLen, buf, MAX_PATH + 50 - BaseLen);
+    // a long name is cut to the buffer: at a whole character, or the line is
+    // not UTF-8 any more and the status bar draws it as code page
+    SalFindTrimTornTail(Buffer + BaseLen);
     Dirty = TRUE;
     HANDLES(LeaveCriticalSection(&Section));
 }
```

Find log, message boxes and the check (cases 2 and 3):

```diff
diff --git a/src/callstk.cpp b/src/callstk.cpp
index 72ad78c8..a27b6bb9 100644
--- a/src/callstk.cpp
+++ b/src/callstk.cpp
@@ -498,4 +498,5 @@ void InformAboutIconOvrlsHanCrash(const char* iconOvrlsHanName)
     {
         static char buf[900];
+        // encoding-check: allow mixed-composition - the handler's name is a registry key name read with RegEnumKeyExA (shiconov.cpp): code page, like the template
         _snprintf_s(buf, _TRUNCATE, LoadStr(IDS_ICONOVRLS_CRASH), iconOvrlsHanName);
 
diff --git a/src/codetbl.cpp b/src/codetbl.cpp
index b6fb558e..2b3fc1c5 100644
--- a/src/codetbl.cpp
+++ b/src/codetbl.cpp
@@ -178,5 +178,5 @@ void InitAux(HWND hWindow, TIndirectArray<CCodeTablesData>& Data,
                                         if (text != NULL)
                                         {
-                                            sprintf(textBuf, LoadStr(IDS_VIEWERERROPENFILE), fullName, text);
+                                            sprintf(textBuf, LoadStrU8(IDS_VIEWERERROPENFILE), fullName, text); // UTF-8 template: the composed text is UTF-8 (error text, names)
                                             text = textBuf;
                                         }
@@ -202,5 +202,5 @@ void InitAux(HWND hWindow, TIndirectArray<CCodeTablesData>& Data,
                                                 else
                                                 {
-                                                    sprintf(textBuf, LoadStr(IDS_VIEWERBADINTCODING), convertCfgFileName);
+                                                    sprintf(textBuf, LoadStrU8(IDS_VIEWERBADINTCODING), convertCfgFileName); // UTF-8 template: the composed text is UTF-8 (error text, names)
                                                     text = textBuf;
                                                 }
@@ -216,5 +216,5 @@ void InitAux(HWND hWindow, TIndirectArray<CCodeTablesData>& Data,
                                             if (text != NULL)
                                             {
-                                                sprintf(textBuf, LoadStr(IDS_VIEWERERROPENFILE), fileName, text);
+                                                sprintf(textBuf, LoadStrU8(IDS_VIEWERERROPENFILE), fileName, text); // UTF-8 template: the composed text is UTF-8 (error text, names)
                                                 text = textBuf;
                                             }
@@ -228,5 +228,5 @@ void InitAux(HWND hWindow, TIndirectArray<CCodeTablesData>& Data,
                             if (!white || txt < endTxt && *txt == '=')
                             {
-                                sprintf(textBuf, LoadStr(IDS_VIEWERINVALIDLINE), convertCfgFileName);
+                                sprintf(textBuf, LoadStrU8(IDS_VIEWERINVALIDLINE), convertCfgFileName); // UTF-8 template: the composed text is UTF-8 (error text, names)
                                 text = textBuf;
                             }
diff --git a/src/dialogs3.cpp b/src/dialogs3.cpp
index d06661a3..3b789ba4 100644
--- a/src/dialogs3.cpp
+++ b/src/dialogs3.cpp
@@ -1310,5 +1310,5 @@ void CDriveInfo::Validate(CTransferInfo& ti)
             {
                 char buf[MAX_PATH + 100];
-                sprintf(buf, LoadStr(IDS_UNABLETOCHANGEDRIVELABEL), GetErrorText(err));
+                _snprintf_s(buf, _TRUNCATE, LoadStrU8(IDS_UNABLETOCHANGEDRIVELABEL), GetErrorText(err)); // UTF-8 template: the composed text is UTF-8 (error text, names)
                 SalMessageBox(HWindow, buf, LoadStr(IDS_ERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
                 ti.ErrorOn(IDE_VOLNAME);
diff --git a/src/fileswn5.cpp b/src/fileswn5.cpp
index 5100f1d3..6b86a77f 100644
--- a/src/fileswn5.cpp
+++ b/src/fileswn5.cpp
@@ -1158,5 +1158,5 @@ BOOL ViewFileInt(HWND parent, const char* name, BOOL altView, DWORD handlerID, B
                         DWORD err = GetLastError();
                         char buff[4 * MAX_PATH];
-                        sprintf(buff, LoadStr(IDS_ERROREXECVIEW), expCommand, GetErrorText(err));
+                        _snprintf_s(buff, _TRUNCATE, LoadStrU8(IDS_ERROREXECVIEW), expCommand, GetErrorText(err)); // UTF-8 template: the composed text is UTF-8 (error text, names)
                         SalMessageBox(parent, buff, LoadStr(IDS_ERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
                     }
@@ -1481,5 +1481,5 @@ void CFilesWindow::EditFile(char* name, DWORD handlerID)
                     DWORD err = GetLastError();
                     char buff[4 * MAX_PATH];
-                    sprintf(buff, LoadStr(IDS_ERROREXECEDIT), expCommand, GetErrorText(err));
+                    _snprintf_s(buff, _TRUNCATE, LoadStrU8(IDS_ERROREXECEDIT), expCommand, GetErrorText(err)); // UTF-8 template: the composed text is UTF-8 (error text, names)
                     SalMessageBox(HWindow, buff, LoadStr(IDS_ERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
                 }
diff --git a/src/fileswn6.cpp b/src/fileswn6.cpp
index 3c6c8e88..f7aa0051 100644
--- a/src/fileswn6.cpp
+++ b/src/fileswn6.cpp
@@ -2051,5 +2051,5 @@ BOOL CFilesWindow::BuildScriptDir(COperations* script, CActionType type, char* s
     {                                                               // rejected folder ops in long-path dirs even though the
         *sourceEnd = 0;                                             // W-API enumeration below handles them)
-        _snprintf_s(text, _TRUNCATE, LoadStr(IDS_NAMEISTOOLONG), dirName, sourcePath);
+        _snprintf_s(text, _TRUNCATE, LoadStrU8(IDS_NAMEISTOOLONG), dirName, sourcePath); // UTF-8 template: the composed text is UTF-8 (error text, names)
         BOOL skip = TRUE;
         if (!ErrTooLongSrcDirNameSkipAll)
@@ -2120,5 +2120,5 @@ MENU_TEMPLATE_ITEM MsgBoxButtons[] =
             *sourceEnd = 0;                              // restoring sourcePath
             *targetEnd = 0;                              // restoring targetPath
-            _snprintf_s(text, _TRUNCATE, LoadStr(IDS_TOOLONGNAME2), targetPath, s2);
+            _snprintf_s(text, _TRUNCATE, LoadStrU8(IDS_TOOLONGNAME2), targetPath, s2); // UTF-8 template: the composed text is UTF-8 (error text, names)
             BOOL skip = TRUE;
             if (!ErrTooLongTgtDirNameSkipAll)
@@ -2432,5 +2432,5 @@ MENU_TEMPLATE_ITEM MsgBoxButtons[] =
                                     if (err != ERROR_FILE_NOT_FOUND && err != ERROR_NO_MORE_FILES)
                                     {
-                                        _snprintf_s(text, _TRUNCATE, LoadStr(IDS_CANNOTREADDIR), sourcePath, GetErrorText(err)); // path may exceed the message buffer (feature 012)
+                                        _snprintf_s(text, _TRUNCATE, LoadStrU8(IDS_CANNOTREADDIR), sourcePath, GetErrorText(err)); // path may exceed the message buffer (feature 012)
                                         BOOL skip = TRUE;
                                         if (!ErrListDirSkipAll)
@@ -2650,5 +2650,5 @@ MENU_TEMPLATE_ITEM MsgBoxButtons[] =
             if (err != ERROR_FILE_NOT_FOUND && err != ERROR_NO_MORE_FILES)
             {
-                _snprintf_s(text, _TRUNCATE, LoadStr(IDS_CANNOTREADDIR), sourcePath, GetErrorText(err)); // path may exceed the message buffer (feature 012)
+                _snprintf_s(text, _TRUNCATE, LoadStrU8(IDS_CANNOTREADDIR), sourcePath, GetErrorText(err)); // path may exceed the message buffer (feature 012)
                 *sourceEnd = 0;                                                                          // restoring sourcePath
                 if (targetEnd != NULL)
@@ -2807,5 +2807,5 @@ MENU_TEMPLATE_ITEM MsgBoxButtons[] =
             if (testFindNextErr && err != ERROR_NO_MORE_FILES)
             {
-                _snprintf_s(text, _TRUNCATE, LoadStr(IDS_CANNOTREADDIR), sourcePath, GetErrorText(err)); // path may exceed the message buffer (feature 012)
+                _snprintf_s(text, _TRUNCATE, LoadStrU8(IDS_CANNOTREADDIR), sourcePath, GetErrorText(err)); // path may exceed the message buffer (feature 012)
                 BOOL skip = TRUE;
                 if (!ErrListDirSkipAll)
@@ -3083,5 +3083,5 @@ BOOL CFilesWindow::BuildScriptFile(COperations* script, CActionType type, char*
             if (!ErrTooBigFileFAT32SkipAll)
             {
-                _snprintf_s(message, _TRUNCATE, LoadStr(IDS_FILEISTOOBIGFORFAT32), op.SourceName);
+                _snprintf_s(message, _TRUNCATE, LoadStrU8(IDS_FILEISTOOBIGFORFAT32), op.SourceName); // UTF-8 template: the composed text is UTF-8 (error text, names)
                 MSGBOXEX_PARAMS params;
                 memset(&params, 0, sizeof(params));
diff --git a/src/find.cpp b/src/find.cpp
index 2562d906..e00edfc5 100644
--- a/src/find.cpp
+++ b/src/find.cpp
@@ -867,5 +867,5 @@ BOOL CDuplicateCandidates::GetMD5Digest(CGrepData* data, CFoundFilesData* file,
 
                 char buf[MAX_PATH + 100];
-                sprintf(buf, LoadStr(IDS_ERROR_READING_FILE2), GetErrorText(err));
+                _snprintf_s(buf, _TRUNCATE, LoadStrU8(IDS_ERROR_READING_FILE2), GetErrorText(err)); // UTF-8 template: the composed text is UTF-8 (error text, names)
                 FIND_LOG_ITEM log;
                 log.Flags = FLI_ERROR;
@@ -919,5 +919,5 @@ BOOL CDuplicateCandidates::GetMD5Digest(CGrepData* data, CFoundFilesData* file,
 
         char buf[MAX_PATH + 100];
-        sprintf(buf, LoadStr(IDS_ERROR_OPENING_FILE2), GetErrorText(err));
+        _snprintf_s(buf, _TRUNCATE, LoadStrU8(IDS_ERROR_OPENING_FILE2), GetErrorText(err)); // UTF-8 template: the composed text is UTF-8 (error text, names)
         FIND_LOG_ITEM log;
         log.Flags = FLI_ERROR;
@@ -1370,5 +1370,5 @@ BOOL TestFileContentAux(BOOL& ok, CQuadWord& fileOffset, const CQuadWord& totalS
         FIND_LOG_ITEM log;
         log.Flags = FLI_ERROR;
-        log.Text = LoadStr(IDS_FILEREADERROR2);
+        log.Text = LoadStrU8(IDS_FILEREADERROR2);
         log.Path = path;
         SendMessage(data->HWindow, WM_USER_ADDLOG, (WPARAM)&log, 0);
@@ -1684,5 +1684,5 @@ static BOOL TestFileBytes(DWORD sizeLow, DWORD sizeHigh, const char* path, CGrep
         {
             char buf[MAX_PATH + 100];
-            sprintf(buf, LoadStr(getLinkFileSizeErr ? IDS_GETLINKTGTFILESIZEERROR : IDS_ERROR_OPENING_FILE2),
+            _snprintf_s(buf, _TRUNCATE, LoadStrU8(getLinkFileSizeErr ? IDS_GETLINKTGTFILESIZEERROR : IDS_ERROR_OPENING_FILE2), // UTF-8 template: the composed text is UTF-8 (error text, names)
                     GetErrorText(err));
             FIND_LOG_ITEM log;
@@ -1759,5 +1759,5 @@ BOOL AddFoundItem(const char* path, const char* name, DWORD sizeLow, DWORD sizeH
         FIND_LOG_ITEM log;
         log.Flags = FLI_ERROR;
-        log.Text = LoadStr(IDS_CANTSHOWRESULTS);
+        log.Text = LoadStrU8(IDS_CANTSHOWRESULTS);
         log.Path = NULL;
         SendMessage(data->HWindow, WM_USER_ADDLOG, (WPARAM)&log, 0);
@@ -2096,5 +2096,5 @@ void SearchDirectory(const char* path, int startPathLen,
         FIND_LOG_ITEM log;
         log.Flags = FLI_INFO;
-        log.Text = LoadStr(IDS_FINDLOG_SKIP);
+        log.Text = LoadStrU8(IDS_FINDLOG_SKIP);
         log.Path = path;
         SendMessage(data->HWindow, WM_USER_ADDLOG, (WPARAM)&log, 0);
@@ -2271,5 +2271,5 @@ void SearchDirectory(const char* path, int startPathLen,
         if (testFindNextErr && err != ERROR_NO_MORE_FILES)
         {
-            sprintf(message, LoadStr(IDS_DIRERRORFORMAT), GetErrorText(err));
+            _snprintf_s(message, _TRUNCATE, LoadStrU8(IDS_DIRERRORFORMAT), GetErrorText(err)); // UTF-8 template: the composed text is UTF-8 (error text, names)
             FIND_LOG_ITEM log;
             log.Flags = FLI_ERROR;
@@ -2313,5 +2313,5 @@ void SearchDirectory(const char* path, int startPathLen,
         if (err != ERROR_FILE_NOT_FOUND && err != ERROR_NO_MORE_FILES)
         {
-            sprintf(message, LoadStr(IDS_DIRERRORFORMAT), GetErrorText(err));
+            _snprintf_s(message, _TRUNCATE, LoadStrU8(IDS_DIRERRORFORMAT), GetErrorText(err)); // UTF-8 template: the composed text is UTF-8 (error text, names)
 
             FIND_LOG_ITEM log;
diff --git a/src/icncache.cpp b/src/icncache.cpp
index c30b69a8..604bf44f 100644
--- a/src/icncache.cpp
+++ b/src/icncache.cpp
@@ -1237,5 +1237,5 @@ void CAssociations::ReadAssociations(BOOL showWaitWnd)
                 // ukoncit enumeraci uz pri prvni chybe, jinak zacne cyklit a zarat pamet (zrejme jde
                 // o interni chybu Windowsu), nikdo dalsi to nehlasil, takze to dal neresime
-                _snprintf_s(errBuf, _TRUNCATE, LoadStr(IDS_UNABLETOGETASSOC), GetErrorText(enumRet));
+                _snprintf_s(errBuf, _TRUNCATE, LoadStrU8(IDS_UNABLETOGETASSOC), GetErrorText(enumRet)); // UTF-8 template: the composed text is UTF-8 (error text, names)
                 SalMessageBox(parent, errBuf, LoadStr(IDS_UNABLETOGETASSOCTITLE), MB_OK | MB_ICONEXCLAMATION);
             }
@@ -1284,5 +1284,5 @@ void CAssociations::ReadAssociations(BOOL showWaitWnd)
                     // ukoncit enumeraci uz pri prvni chybe, jinak zacne cyklit a zrat pamet (zrejme jde
                     // o interni chybu Windowsu), nikdo dalsi to nehlasil, takze to dal neresime
-                    _snprintf_s(errBuf, _TRUNCATE, LoadStr(IDS_UNABLETOGETASSOC), GetErrorText(enumRet));
+                    _snprintf_s(errBuf, _TRUNCATE, LoadStrU8(IDS_UNABLETOGETASSOC), GetErrorText(enumRet)); // UTF-8 template: the composed text is UTF-8 (error text, names)
                     SalMessageBox(parent, errBuf, LoadStr(IDS_UNABLETOGETASSOCTITLE), MB_OK | MB_ICONEXCLAMATION);
                 }
diff --git a/src/mainwnd4.cpp b/src/mainwnd4.cpp
index 8091ae3f..dffea01e 100644
--- a/src/mainwnd4.cpp
+++ b/src/mainwnd4.cpp
@@ -257,5 +257,5 @@ void CMainWindow::MakeFileList()
                 DWORD err = GetLastError();
                 char errorText[200 + 2 * MAX_PATH];
-                sprintf(errorText, "%s\n\n%s", LoadStr(IDS_ERRORCREATINGTMPFILE),
+                _snprintf_s(errorText, _TRUNCATE, "%s\n\n%s", LoadStrU8(IDS_ERRORCREATINGTMPFILE), // UTF-8 template: the composed text is UTF-8 (error text, names)
                         GetErrorText(err));
                 SalMessageBox(HWindow, errorText, LoadStr(IDS_ERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
@@ -950,5 +950,5 @@ MENU_TEMPLATE_ITEM MsgBoxButtons[] =
                             if (strlen(cmdLine) > 2 * MAX_PATH) // "always false" (arguments are in 'arguments'): shorten overly long command lines for error display
                                 strcpy(cmdLine + 2 * MAX_PATH - 4, "...");
-                            sprintf(buff, LoadStr(IDS_EXECERROR), cmdLine, GetErrorText(err));
+                            _snprintf_s(buff, _TRUNCATE, LoadStrU8(IDS_EXECERROR), cmdLine, GetErrorText(err)); // UTF-8 template: the composed text is UTF-8 (error text, names)
                             SalMessageBox(parent, buff, LoadStr(IDS_ERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
                             break;
@@ -1017,5 +1017,5 @@ MENU_TEMPLATE_ITEM MsgBoxButtons[] =
                             if (strlen(cmdLine) > 2 * MAX_PATH)
                                 strcpy(cmdLine + 2 * MAX_PATH, "..."); // shorten just in case (probably never needed)
-                            sprintf(buff, LoadStr(IDS_EXECERROR), cmdLine, GetErrorText(err));
+                            _snprintf_s(buff, _TRUNCATE, LoadStrU8(IDS_EXECERROR), cmdLine, GetErrorText(err)); // UTF-8 template: the composed text is UTF-8 (error text, names)
                             DiskCache.ReleaseName(batUniqueName, FALSE);
                             SalMessageBox(parent, buff, LoadStr(IDS_ERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
diff --git a/src/salamdr1.cpp b/src/salamdr1.cpp
index e0dd1eee..d7662167 100644
--- a/src/salamdr1.cpp
+++ b/src/salamdr1.cpp
@@ -1126,5 +1126,5 @@ char* BuildName(char* path, char* name, char* dosName, BOOL* skip, BOOL* skipAll
     {
         char text[2 * MAX_PATH + 100];
-        _snprintf_s(text, _TRUNCATE, LoadStr(IDS_NAMEISTOOLONG), name, path);
+        _snprintf_s(text, _TRUNCATE, LoadStrU8(IDS_NAMEISTOOLONG), name, path); // UTF-8 template: the composed text is UTF-8 (error text, names)
 
         if (skip != NULL)
@@ -3435,5 +3435,5 @@ BOOL FindPluginsWithoutImportedCfg(BOOL* doNotDeleteImportedCfg)
             sprintf(skippedNames, LoadStr(IDS_NUMOFSKIPPEDPLUGINNAMES), skipped);
         char msg[2000];
-        sprintf(msg, LoadStr(IDS_NOTALLPLUGINSCFGIMPORTED), names, skippedNames);
+        _snprintf_s(msg, _TRUNCATE, LoadStrU8(IDS_NOTALLPLUGINSCFGIMPORTED), names, skippedNames); // UTF-8 template: the composed text is UTF-8 (error text, names)
         params.Text = msg;
         char aliasBtnNames[200];
diff --git a/tools/check_encoding.py b/tools/check_encoding.py
index 0398664e..fb358751 100644
--- a/tools/check_encoding.py
+++ b/tools/check_encoding.py
@@ -23,6 +23,8 @@ cp-acp-display   A name is converted with WideCharToMultiByte(CP_ACP, ...) on a
 mixed-composition
                  A printf-family call whose FORMAT comes from LoadStr() (legacy
-                 codepage) and whose arguments include a file name (UTF-8), with
-                 the result handed to a message box.  The composed string is then
+                 codepage) and whose arguments include a file name or the text
+                 of a Windows error (GetErrorText, both UTF-8), with the result
+                 handed to a message box (also through MSGBOXEX_PARAMS.Text) or
+                 to the Find Files log (FIND_LOG_ITEM.Text, drawn as UTF-8).  The composed string is then
                  not valid UTF-8, so CMessageBox refuses its own wide drawing
                  path and falls back to the legacy one - which renders the
@@ -164,6 +166,9 @@ FMT_IS_LOADSTR = re.compile(r'\b(?:sprintf|sprintf_s|_snprintf|_snprintf_s|wspri
 # prompted this feature - because the name arrived from an accessor called
 # GetEquivalentPairNoticeName().  Recorded in research.md R5.
-NAME_ARG = re.compile(r'[A-Za-z_]*(?:[Nn]ame|[Pp]ath|[Ff]ile|[Dd]ir|[Mm]ask|[Aa]rchive)[A-Za-z_]*')
-MSGBOX = re.compile(r'\b(?:SalMessageBox|SalMessageBoxEx|ShowMessageBox)\b')
+NAME_ARG = re.compile(r'[A-Za-z_]*(?:[Nn]ame|[Pp]ath|[Ff]ile|[Dd]ir|[Mm]ask|[Aa]rchive)[A-Za-z_]*'
+                      # the text of a Windows error is UTF-8 too (feature 010)
+                      r'|\bGetErrorText\s*\(')
+# also the MSGBOXEX_PARAMS text and the Find Files log (its list draws UTF-8)
+MSGBOX = re.compile(r'\b(?:SalMessageBox|SalMessageBoxEx|ShowMessageBox)\b|\bparams\.Text\s*=|\blog\.Text\s*=')
 
 CP_ACP_W2A = re.compile(r'\bWideCharToMultiByte\s*\(\s*CP_ACP\b')
```
