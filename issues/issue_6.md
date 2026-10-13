URL: https://github.com/tandemcommander/tandemcommander/issues/6

**Version:** Tandem Commander 0.1.9 (x64), installer from the release page; Windows Server 2008 R2 Standard SP1 (build 7601)

I know only Windows 11 is supported. I am reporting this because the program itself still accepts Windows 7 (`salamdr1.cpp`: "You need at least Windows 7 to run this program."), the cause is a single place, and the failure is completely silent.

**Steps to reproduce**
1. Install 0.1.9 on Windows Server 2008 R2 SP1 (or Windows 7 SP1).
2. Start `tandemcommander.exe`.

**Expected:** the program starts (or tells that the Windows version is not supported).

**Actual:** nothing happens - no window, no message, nothing in the event logs. The process ends with exit code `0xC0000139` (STATUS_ENTRYPOINT_NOT_FOUND). The loader's message box is not shown because servers commonly run with `HKLM\SYSTEM\CurrentControlSet\Control\Windows\ErrorMode = 2`.

**Cause**

`CSalShellOsProbe::GetPackagePath()` in `src/common/salshell.cpp` (the command shell presets of feature 071) calls `GetPackagesByPackageFamily` and `GetPackagePathByFullName` directly. kernel32 has both only since Windows 8, so the static import stops the loader before any code runs. I checked every import of the release tree (the program, the VC runtime DLLs and all plugins, about 5,500 functions) with `GetProcAddress` on the server: these two are the only missing ones.

**Proposed fix** (tested: 0.1.9 with this change starts and works on Windows Server 2008 R2 SP1, and still on Windows 11) - resolve them at run time; without them there are no MSIX packages, so a packaged preset is just not found:

```diff
--- a/src/common/salshell.cpp
+++ b/src/common/salshell.cpp
@@ BOOL CSalShellOsProbe::GetPackagePath(const char* family, char* u8Buf, int bufSize) const
     if (u8Buf == NULL || bufSize <= 0)
         return FALSE;
     u8Buf[0] = 0;
+    // GetPackagesByPackageFamily and GetPackagePathByFullName exist in kernel32 only since
+    // Windows 8; imported statically they stop the program before it starts on Windows 7 /
+    // Server 2008 R2 (C0000139). Resolved at run time; absent = no MSIX packages.
+    static decltype(&GetPackagesByPackageFamily) pGetPackagesByPackageFamily = NULL;
+    static decltype(&GetPackagePathByFullName) pGetPackagePathByFullName = NULL;
+    static BOOL resolved = FALSE;
+    if (!resolved)
+    {
+        HMODULE kernel32 = GetModuleHandleW(L"kernel32.dll");
+        if (kernel32 != NULL)
+        {
+            pGetPackagesByPackageFamily = (decltype(&GetPackagesByPackageFamily))GetProcAddress(kernel32, "GetPackagesByPackageFamily");
+            pGetPackagePathByFullName = (decltype(&GetPackagePathByFullName))GetProcAddress(kernel32, "GetPackagePathByFullName");
+        }
+        resolved = TRUE;
+    }
+    if (pGetPackagesByPackageFamily == NULL || pGetPackagePathByFullName == NULL)
+        return FALSE;
     WCHAR familyW[256];
     if (family == NULL || SalU8ToW(family, -1, familyW, _countof(familyW)) == 0)
         return FALSE;
     UINT32 count = 0;
     UINT32 bufLen = 0;
-    if (GetPackagesByPackageFamily(familyW, &count, NULL, &bufLen, NULL) != ERROR_INSUFFICIENT_BUFFER ||
+    if (pGetPackagesByPackageFamily(familyW, &count, NULL, &bufLen, NULL) != ERROR_INSUFFICIENT_BUFFER ||
         count == 0 || bufLen == 0)
@@
-        GetPackagesByPackageFamily(familyW, &count, names, &bufLen, buffer) == ERROR_SUCCESS && count > 0)
+        pGetPackagesByPackageFamily(familyW, &count, names, &bufLen, buffer) == ERROR_SUCCESS && count > 0)
     {
         UINT32 pathLen = 0;
-        if (GetPackagePathByFullName(names[0], &pathLen, NULL) == ERROR_INSUFFICIENT_BUFFER && pathLen > 0)
+        if (pGetPackagePathByFullName(names[0], &pathLen, NULL) == ERROR_INSUFFICIENT_BUFFER && pathLen > 0)
         {
             WCHAR* pathW = (WCHAR*)malloc(pathLen * sizeof(WCHAR));
-            if (pathW != NULL && GetPackagePathByFullName(names[0], &pathLen, pathW) == ERROR_SUCCESS)
+            if (pathW != NULL && pGetPackagePathByFullName(names[0], &pathLen, pathW) == ERROR_SUCCESS)
```

With the change, `dumpbin /imports tandemcommander.exe` no longer lists the two functions - the only two the server was missing.
