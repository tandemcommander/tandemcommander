// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include "..\undelete.rh2"

#include "miscstr.h"
#include "os.h"
#include "../../../common/salvolpaths.h" // feature 114: UTF-8 <-> UTF-16 of mount paths

// ***************************************************************************
//
//  Global variables
//
static BOOL OSVersionDetected = FALSE;
BOOL IsWindowsNT = FALSE;
BOOL IsWindows2000AndLater = FALSE;
BOOL IsWindows95 = FALSE;
BOOL IsWindows95OSR2AndLater = FALSE;
BOOL IsWindowsVistaAndLater = FALSE;

static HINSTANCE NTShell32DLLInstance = NULL;

// ***************************************************************************
//
//  Static members
//
HMODULE OS<char>::ImageResDLL = NULL;

// ***************************************************************************
//
//  Functions
//
BOOL OS_InitOSVersion()
{
    if (!OSVersionDetected)
    {
        OSVersionDetected = TRUE;

        // To run under W9x we must use the A-version of GetVersionEx().
        OSVERSIONINFOA osvi;
        ZeroMemory(&osvi, sizeof(osvi));
        osvi.dwOSVersionInfoSize = sizeof(osvi);
        if (!GetVersionExA(&osvi))
        {
            DWORD err = GetLastError();
            TRACE_E("GetVersionEx() failed, GetLastError()=" << err);
            return FALSE;
        }
        IsWindowsNT = (osvi.dwPlatformId == VER_PLATFORM_WIN32_NT);
        IsWindows2000AndLater = (osvi.dwPlatformId == VER_PLATFORM_WIN32_NT && osvi.dwMajorVersion >= 5);
        IsWindows95 = (osvi.dwPlatformId == VER_PLATFORM_WIN32_WINDOWS &&
                       osvi.dwMajorVersion == 4 && osvi.dwMinorVersion == 0);
        IsWindows95OSR2AndLater = (osvi.dwPlatformId == VER_PLATFORM_WIN32_WINDOWS &&
                                       (osvi.dwMajorVersion == 4 && osvi.dwMinorVersion == 0 && LOWORD(osvi.dwBuildNumber) > 1080) || // W95OSR2
                                   (osvi.dwMajorVersion == 4 && osvi.dwMinorVersion >= 1));                                           // W98 a WinME
        IsWindowsVistaAndLater = (osvi.dwPlatformId == VER_PLATFORM_WIN32_NT && osvi.dwMajorVersion >= 6);
    }
    return TRUE;
}

// ***************************************************************************
//
//  Explicitly instantiated template methods
//

// ****************************************************************************
//
// ANSI versions
//

// feature 114: the volume functions exist on every supported Windows (Windows 10 2004 and
// later); the plug-in calls their W forms directly and converts UTF-8 <-> UTF-16 (the A forms
// resolved here before read UTF-8 paths as code-page text - see UndGetVolumePathNameU8)
BOOL OS<char>::OS_GetVolumeNameForVolumeMountPointExists() { return TRUE; }
BOOL OS<char>::OS_VolumeEnumExists() { return TRUE; }
BOOL OS<char>::OS_VolumeMountPointEnumExists() { return TRUE; }
BOOL OS<char>::OS_GetLogicalDriveStringsExists() { return TRUE; }
BOOL OS<char>::OS_GetDiskFreeSpaceExExists() { return TRUE; }
BOOL OS<char>::OS_GetVolumePathNamesForVolumeNameExists() { return TRUE; }

template <>
BOOL OS<char>::OS_GetVolumeNameForVolumeMountPoint(const char* VolumeMountPoint, char* VolumeName, DWORD BufferLength)
{
    if (BufferLength > 0)
        VolumeName[0] = 0;
    WCHAR* mpW = SplU8ToWAlloc(VolumeMountPoint);
    if (mpW == NULL)
    {
        SetLastError(ERROR_INVALID_NAME);
        return FALSE;
    }
    WCHAR nameW[MAX_PATH];
    BOOL ok = GetVolumeNameForVolumeMountPointW(mpW, nameW, MAX_PATH);
    DWORD err = GetLastError();
    free(mpW);
    if (ok && !SalVolumePathWToU8(nameW, VolumeName, (int)BufferLength))
    {
        ok = FALSE;
        err = ERROR_INSUFFICIENT_BUFFER;
    }
    SetLastError(ok ? NO_ERROR : err);
    return ok;
}

template <>
HANDLE OS<char>::OS_FindFirstVolume(char* VolumeName, DWORD BufferLength)
{
    // volume GUID paths (\\?\Volume{...}\) are ASCII and always fit MAX_PATH
    WCHAR nameW[MAX_PATH];
    HANDLE h = FindFirstVolumeW(nameW, MAX_PATH);
    if (h != INVALID_HANDLE_VALUE && !SalVolumePathWToU8(nameW, VolumeName, (int)BufferLength))
    {
        FindVolumeClose(h);
        SetLastError(ERROR_INSUFFICIENT_BUFFER);
        return INVALID_HANDLE_VALUE;
    }
    return h;
}

template <>
BOOL OS<char>::OS_FindNextVolume(HANDLE FindVolume, char* VolumeName, DWORD BufferLength)
{
    WCHAR nameW[MAX_PATH];
    while (FindNextVolumeW(FindVolume, nameW, MAX_PATH))
    {
        if (SalVolumePathWToU8(nameW, VolumeName, (int)BufferLength))
            return TRUE;
    }
    return FALSE; // GetLastError() is FindNextVolumeW's (ERROR_NO_MORE_FILES at the end)
}

template <>
BOOL OS<char>::OS_FindVolumeClose(HANDLE FindVolume)
{
    return FindVolumeClose(FindVolume);
}

// the mount folders of a volume (relative paths, e.g. mnt\voila-with-grave\): one whose UTF-8
// form does not fit the caller's buffer is skipped, never cut
template <>
BOOL OS<char>::OS_FindNextVolumeMountPoint(HANDLE FindVolumeMountPoint, char* VolumeMountPoint, DWORD BufferLength)
{
    WCHAR mpW[MAX_PATH];
    while (FindNextVolumeMountPointW(FindVolumeMountPoint, mpW, MAX_PATH))
    {
        if (SalVolumePathWToU8(mpW, VolumeMountPoint, (int)BufferLength))
            return TRUE;
    }
    return FALSE;
}

template <>
HANDLE OS<char>::OS_FindFirstVolumeMountPoint(const char* RootPathName, char* VolumeMountPoint, DWORD BufferLength)
{
    WCHAR* rootW = SplU8ToWAlloc(RootPathName);
    if (rootW == NULL)
    {
        SetLastError(ERROR_INVALID_NAME);
        return INVALID_HANDLE_VALUE;
    }
    WCHAR mpW[MAX_PATH];
    HANDLE h = FindFirstVolumeMountPointW(rootW, mpW, MAX_PATH);
    free(rootW);
    if (h == INVALID_HANDLE_VALUE)
        return h;
    if (SalVolumePathWToU8(mpW, VolumeMountPoint, (int)BufferLength) ||
        OS_FindNextVolumeMountPoint(h, VolumeMountPoint, BufferLength))
    {
        return h;
    }
    FindVolumeMountPointClose(h);
    SetLastError(ERROR_NO_MORE_FILES);
    return INVALID_HANDLE_VALUE;
}

template <>
BOOL OS<char>::OS_FindVolumeMountPointClose(HANDLE FindVolumeMountPoint)
{
    return FindVolumeMountPointClose(FindVolumeMountPoint);
}

// drive roots (C:\) are ASCII: the A function is exact here
template <>
DWORD OS<char>::OS_GetLogicalDriveStrings(size_t bufsize, char* buffer)
{
    return GetLogicalDriveStringsA((DWORD)bufsize, buffer);
}

template <>
BOOL OS<char>::OS_GetDiskFreeSpaceEx(const char* DirectoryName, ULARGE_INTEGER* FreeBytesAvailableToCaller,
                                     ULARGE_INTEGER* TotalNumberOfBytes, ULARGE_INTEGER* TotalNumberOfFreeBytes)
{
    WCHAR* dirW = SplU8ToWAlloc(DirectoryName);
    if (dirW == NULL)
    {
        SetLastError(ERROR_INVALID_NAME);
        return FALSE;
    }
    BOOL ok = GetDiskFreeSpaceExW(dirW, FreeBytesAvailableToCaller, TotalNumberOfBytes, TotalNumberOfFreeBytes);
    DWORD err = GetLastError();
    free(dirW);
    SetLastError(err);
    return ok;
}

// the mount paths of a volume as a UTF-8 multi-string (*ReturnLength = bytes used); a path
// whose UTF-8 form does not fit the buffer is left out, never cut (SalVolumePathsWToU8)
template <>
BOOL OS<char>::OS_GetVolumePathNamesForVolumeName(const char* VolumeName, char* VolumePathNames,
                                                  DWORD BufferLength, DWORD* ReturnLength)
{
    if (ReturnLength != NULL)
        *ReturnLength = 0;
    if (BufferLength < 2)
    {
        SetLastError(ERROR_INSUFFICIENT_BUFFER);
        return FALSE;
    }
    VolumePathNames[0] = VolumePathNames[1] = 0;
    WCHAR* nameW = SplU8ToWAlloc(VolumeName);
    if (nameW == NULL)
    {
        SetLastError(ERROR_INVALID_NAME);
        return FALSE;
    }
    DWORD lenW = MAX_PATH;
    WCHAR* pathsW = NULL;
    BOOL ok = FALSE;
    DWORD err = ERROR_NOT_ENOUGH_MEMORY;
    for (int attempt = 0; attempt < 4; attempt++)
    {
        free(pathsW);
        pathsW = (WCHAR*)malloc(lenW * sizeof(WCHAR));
        if (pathsW == NULL)
        {
            err = ERROR_NOT_ENOUGH_MEMORY;
            break;
        }
        DWORD need = 0;
        if (GetVolumePathNamesForVolumeNameW(nameW, pathsW, lenW, &need))
        {
            ok = TRUE;
            break;
        }
        err = GetLastError();
        if (err != ERROR_MORE_DATA || need <= lenW)
            break;
        lenW = need;
    }
    free(nameW);
    if (ok)
    {
        SalVolumePathsWToU8(pathsW, VolumePathNames, (int)BufferLength);
        if (ReturnLength != NULL)
        {
            const char* p = VolumePathNames;
            while (*p != 0)
                p += strlen(p) + 1;
            *ReturnLength = (DWORD)(p - VolumePathNames) + 1;
        }
    }
    free(pathsW);
    SetLastError(ok ? NO_ERROR : err);
    return ok;
}

BOOL UndGetVolumePathNameU8(const char* path, char* root, DWORD rootSize)
{
    if (rootSize > 0)
        root[0] = 0;
    WCHAR* pathW = SplU8ToWAlloc(path);
    if (pathW == NULL)
    {
        SetLastError(ERROR_INVALID_NAME);
        return FALSE;
    }
    // the volume path is never longer than the path itself (plus the backslash GetVolumePathNameW adds)
    DWORD capW = (DWORD)wcslen(pathW) + MAX_PATH;
    WCHAR* rootW = (WCHAR*)malloc(capW * sizeof(WCHAR));
    BOOL ok = rootW != NULL && GetVolumePathNameW(pathW, rootW, capW);
    DWORD err = rootW == NULL ? ERROR_NOT_ENOUGH_MEMORY : GetLastError();
    free(pathW);
    if (ok && !SalVolumePathWToU8(rootW, root, (int)rootSize))
    {
        ok = FALSE;
        err = ERROR_FILENAME_EXCED_RANGE;
    }
    free(rootW);
    SetLastError(ok ? NO_ERROR : err);
    return ok;
}

BOOL OS<char>::OS_InitShell32Bindings()
{
    return TRUE;
}

void OS<char>::OS_ReleaseShell32Bindings()
{
}

template <>
VolumeType OS<char>::OS_GetVolumeType(const char* root)
{
    // root is UTF-8 (plugin interface 104): query on the W layer
    WCHAR* rootW = SplU8ToWAlloc(root);
    VolumeType type = static_cast<VolumeType>(rootW == NULL ? DRIVE_UNKNOWN : ::GetDriveTypeW(rootW));
    free(rootW);
    return type;
}

template <>
void OS<char>::OS_GetDisplayNameFromSystem(const char* root, char* volumeName, int volumeNameBufSize)
{
    CALL_STACK_MESSAGE2("GetDisplayNameFromSystem(%s)", root);

    // root is UTF-8 (plugin interface 104): query on the W layer and hand the
    // display name back as UTF-8
    SHFILEINFOW fi = {0};
    WCHAR* rootW = SplU8ToWAlloc(root);
    if (rootW != NULL && SHGetFileInfoW(rootW, 0, &fi, sizeof(fi), SHGFI_DISPLAYNAME))
    {
        SplWToU8(fi.szDisplayName, volumeName, volumeNameBufSize);
        char* s = strrchr(volumeName, '('); // ASCII '(' is a single UTF-8 byte
        if (s != NULL)
        {
            while (s > volumeName && *(s - 1) == ' ')
                s--;
            *s = 0;
        }
    }
    else
        volumeName[0] = 0;
    free(rootW);
}

template <>
BOOL OS<char>::OS_GetVolumeInfo(const char* rootPathName, char* volumeNameBuffer, DWORD volumeNameSize,
                                DWORD* volumeSerialNumber, DWORD* maximumComponentLength,
                                DWORD* fileSystemFlags, char* fileSystemNameBuffer, DWORD fileSystemNameSize)
{
    // rootPathName is UTF-8 (plugin interface 104): query on the W layer and
    // hand the volume label and file-system name back as UTF-8
    WCHAR* rootW = SplU8ToWAlloc(rootPathName);
    if (rootW == NULL)
        return FALSE;
    WCHAR volNameW[MAX_PATH];
    WCHAR fsNameW[MAX_PATH];
    BOOL ok = ::GetVolumeInformationW(rootW, volumeNameBuffer != NULL ? volNameW : NULL,
                                      volumeNameBuffer != NULL ? MAX_PATH : 0,
                                      volumeSerialNumber, maximumComponentLength, fileSystemFlags,
                                      fileSystemNameBuffer != NULL ? fsNameW : NULL,
                                      fileSystemNameBuffer != NULL ? MAX_PATH : 0);
    free(rootW);
    if (ok)
    {
        if (volumeNameBuffer != NULL)
            SplWToU8(volNameW, volumeNameBuffer, (int)volumeNameSize);
        if (fileSystemNameBuffer != NULL)
            SplWToU8(fsNameW, fileSystemNameBuffer, (int)fileSystemNameSize);
    }
    return ok;
}

template <>
HANDLE OS<char>::OS_CreateFile(const char* fileName, DWORD desiredAccess, DWORD shareMode,
                               SECURITY_ATTRIBUTES* securityAttributes, DWORD creationDisposition,
                               DWORD flagsAndAttributes, HANDLE templateFile)
{
    // fileName is UTF-8 (plugin interface 104): a "\\.\X:" volume/device path or
    // a user-selected disk-image file that may carry Unicode. Convert plainly
    // (NOT the extended "\\?\" form, which would corrupt "\\.\" device paths).
    WCHAR* fileNameW = SplU8ToWAlloc(fileName);
    if (fileNameW == NULL)
    {
        SetLastError(ERROR_INVALID_NAME);
        return INVALID_HANDLE_VALUE;
    }
    HANDLE h = HANDLES_Q(CreateFileW(fileNameW, desiredAccess, shareMode, securityAttributes,
                                     creationDisposition, flagsAndAttributes, templateFile));
    DWORD err = GetLastError();
    free(fileNameW);
    SetLastError(err); // preserve the API's error across free()
    return h;
}

// ****************************************************************************
//
// get drives icons
//

template <>
HICON OS<char>::OS_GetFileOrPathIconAux(const char* path, BOOL large)
{
    __try
    {
        // feature 114: 'path' is UTF-8 (a drive root or a mount folder): the W function
        SHFILEINFOW shi;
        shi.hIcon = NULL;
        WCHAR* pathW = SplU8ToWAlloc(path);
        if (pathW != NULL)
            SHGetFileInfoW(pathW, 0, &shi, sizeof(shi),
                           SHGFI_ICON | SHGFI_SHELLICONSIZE | (large ? 0 : SHGFI_SMALLICON));
        free(pathW);
        return shi.hIcon;
    }
    __except (EXCEPTION_EXECUTE_HANDLER)
    {
        return NULL;
    }
}
