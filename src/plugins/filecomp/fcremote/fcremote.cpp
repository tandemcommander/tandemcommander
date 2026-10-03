// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

HINSTANCE DLLInstance = NULL;

void my_memcpy(void* dst, const void* src, int len)
{
    char* d = (char*)dst;
    const char* s = (char*)src;
    while (len--)
        *d++ = *s++;
}

#pragma optimize("", off)
void my_zeromem(void* dst, int len)
{
    char* d = (char*)dst;
    while (len--)
        *d++ = 0;
}
#pragma optimize("", on)

const char*
Concatenate(const char* string1, const char* string2)
{
    static char buffer[5120];
    static int iterator = 0;

    int len1 = lstrlen(string1);
    int len2 = lstrlen(string2);

    if (len1 + len2 >= 5120)
        return "STRING TOO LONG";
    if (iterator + len1 + len2 >= 5120)
        iterator = 0;

    const char* ret = buffer + iterator;
    my_memcpy(buffer + iterator, string1, len1);
    iterator += len1;
    my_memcpy(buffer + iterator, string2, len2);
    iterator += len2;

    buffer[iterator++] = 0;
    return ret;
}

const char*
LoadStr(int resID)
{
    const char* ret;
    switch (resID)
    {
    case IDS_SPLERROR:
        ret = "File Comparator - Error";
        break;
    case IDS_INVALIDARGS:
        ret = "Invalid arguments. Usage:\n\tfcremote.exe [options] first second\nOptions are:\n\t-w\tWait until File Comparator closes.\n\t--wait\tWait until File Comparator closes.";
        break;
    case IDS_MSGERR:
        ret = "Cannot send message to File Comparator plugin.";
        break;
    case IDS_LAUNCHSAL:
        ret = "Unable to launch Tandem Commander.";
        break;
    case IDS_MSGERR2:
        ret = "Cannot send message to File Comparator plugin. Ensure 'Load plugin on Tandem Commander start' option is set in File Comparator configuration.";
        break;
    default:
        ret = "ERROR LOADING STRING";
    }
    return ret;
}

// feature 102: fcremote.exe works on the UTF-16 command line and sends UTF-16 full names
// (channel version 2, see remotmsg.h).  It still has no C runtime: heap memory comes from
// HeapAlloc, strings are handled by the kernel32 lstr*W functions and own loops, and no
// stack frame may grow over a page (__chkstk is in the C runtime).

static void* FcAlloc(SIZE_T size)
{
    return HeapAlloc(GetProcessHeap(), 0, size);
}

static void FcFree(void* ptr)
{
    if (ptr != NULL)
        HeapFree(GetProcessHeap(), 0, ptr);
}

// The full name of 'arg' (FcAlloc'ed), NULL on failure.  This replaces the current directory
// that version 1 sent along: a relative name is put on fcremote's current directory here, by
// FcAbsoluteNameW (fcproto.h), which keeps every component exactly as typed - GetFullPathNameW
// (used at first) drops the trailing dots and spaces of every component, so "dir.\b.txt"
// named "dir\b.txt", a different file (review); the plug-in opens the name with the "\\?\"
// prefix, which takes it literally.
static WCHAR* FullPathW(const WCHAR* arg)
{
    DWORD size = GetCurrentDirectoryW(0, NULL);
    WCHAR* curDir = size > 0 ? (WCHAR*)FcAlloc((SIZE_T)size * sizeof(WCHAR)) : NULL;
    if (curDir == NULL || GetCurrentDirectoryW(size, curDir) == 0)
    {
        FcFree(curDir);
        return NULL;
    }
    // "C:name": the current directory of that drive (Windows keeps one per drive)
    WCHAR* driveDir = NULL;
    if (FcIsDriveW(arg) && !FcIsSlashW(arg[2]))
    {
        WCHAR drive[3] = {arg[0], L':', 0};
        DWORD dsize = GetFullPathNameW(drive, 0, NULL, NULL);
        driveDir = dsize > 0 ? (WCHAR*)FcAlloc((SIZE_T)dsize * sizeof(WCHAR)) : NULL;
        if (driveDir != NULL && GetFullPathNameW(drive, dsize, driveDir, NULL) == 0)
        {
            FcFree(driveDir);
            driveDir = NULL;
        }
    }
    WCHAR* full = FcAbsoluteNameW(arg, curDir, driveDir);
    FcFree(driveDir);
    FcFree(curDir);
    return full;
}

// removes the last component of 'path' (keeps the backslash of a root "C:\")
static void FcPathRemoveFileSpecW(WCHAR* path)
{
    int len = lstrlenW(path);
    WCHAR* iterator = path + len - 1;
    while (iterator >= path)
    {
        if (*iterator == L'\\')
        {
            if (iterator - 1 < path || *(iterator - 1) == L':')
                iterator++;
            *iterator = 0;
            break;
        }
        iterator--;
    }
}

// appends 'more' to 'path' with a backslash between them; 'path' has 'size' WCHARs
static BOOL FcPathAppendW(WCHAR* path, const WCHAR* more, int size)
{
    int len = lstrlenW(path);
    int moreLen = lstrlenW(more);
    if (len > 1 && path[len - 1] != L'\\' && more[0] != L'\\')
    {
        if (len + 1 >= size)
            return FALSE;
        path[len++] = L'\\';
    }
    if (len + moreLen >= size)
        return FALSE;
    lstrcpyW(path + len, more);
    return TRUE;
}

#ifndef ASFW_ANY
#define ASFW_ANY ((DWORD) - 1)
#endif

// the name of the shared buffer of a channel version-1 receiver (CMessageCenter of 0.1.8 and
// older: Name + " - Buffer v" + Version)
#define MessageCenterBufferV1 MessageCenterName " - Buffer v1"

#define FC_MAX_ARGS 4 // fcremote.exe [-w|--wait] first second

int RemoteCompareFiles(HINSTANCE hInstance, const WCHAR* lpCmdLine)
{
    WCHAR* argv[FC_MAX_ARGS];
    int argc = 0;
    int first = 0, second = 0;
    BOOL wait = FALSE;
    WCHAR* path1 = NULL;
    WCHAR* path2 = NULL;
    CRCMessage* msg = NULL;

    // prepare argv
    BOOL argOK = FcSplitArgsW(lpCmdLine, argv, argc, FC_MAX_ARGS) && // fcproto.h: the rules of version 1
                 3 <= argc && argc <= 4;
    if (argOK)
    {
        if (argc == 3)
        {
            first = 1;
            second = 2;
        }
        else
        {
            if (lstrcmpW(argv[1], L"-w") == 0 || lstrcmpW(argv[1], L"--wait") == 0)
                wait = TRUE;
            else
                argOK = FALSE;
            first = 2;
            second = 3;
        }
    }
    if (argOK)
    {
        path1 = FullPathW(argv[first]);
        path2 = FullPathW(argv[second]);
        if (path1 == NULL || path2 == NULL)
            argOK = FALSE;
    }
    FcFreeArgsW(argv, argc);

    if (!argOK)
    {
        MessageBox(NULL, LoadStr(IDS_INVALIDARGS), LoadStr(IDS_SPLERROR), MB_OK | MB_ICONERROR);
        FcFree(path1);
        FcFree(path2);
        return -1;
    }

    // the message (channel version 2): the fixed part, then both names with their terminators
    int len1 = lstrlenW(path1);
    int len2 = lstrlenW(path2);
    SIZE_T msgSize = (SIZE_T)RCMESSAGE_HEADER_SIZE + ((SIZE_T)len1 + 1 + len2 + 1) * sizeof(WCHAR);
    if (msgSize < (SIZE_T)CMessageCenter::MaxMessage) // always so for names Windows can have
        msg = (CRCMessage*)FcAlloc(msgSize);
    if (msg == NULL)
    {
        MessageBox(NULL, LoadStr(IDS_MSGERR), LoadStr(IDS_SPLERROR), MB_OK | MB_ICONERROR);
        FcFree(path1);
        FcFree(path2);
        return -1;
    }
    my_zeromem(msg, (int)RCMESSAGE_HEADER_SIZE);
    msg->Header.Size = (int)msgSize;
    msg->Magic = RCMESSAGE_MAGIC;
    msg->Path1Len = (DWORD)len1;
    msg->Path2Len = (DWORD)len2;
    lstrcpyW(msg->Names, path1);
    lstrcpyW(msg->Names + len1 + 1, path2);
    FcFree(path1);
    FcFree(path2);

    HANDLE releaseEvent = NULL;
    HANDLE receiver = NULL;
    BOOL firstTry = TRUE;
    int ret = -1;
    while (1)
    {
        CMessageCenter mc(MessageCenterName, TRUE);
        if (!mc.IsGood())
        {
            // a File Comparator of an older version is listening (channel version 1): it would
            // not understand the message - report it instead of starting the program again
            HANDLE oldBuffer = OpenFileMappingA(FILE_MAP_READ, FALSE, MessageCenterBufferV1);
            if (oldBuffer != NULL)
            {
                CloseHandle(oldBuffer);
                MessageBox(NULL, LoadStr(IDS_MSGERR), LoadStr(IDS_SPLERROR), MB_OK | MB_ICONERROR);
                break;
            }
            if (firstTry)
            {
                // try to launch Salamander (UTF-16: the installation may be in a folder outside
                // the code page, e.g. a per-user installation under such a user name)
                const int salSize = 32768;
                WCHAR* sal = (WCHAR*)FcAlloc(salSize * sizeof(WCHAR));
                BOOL launched = FALSE;
                if (sal != NULL)
                {
                    DWORD got = GetModuleFileNameW(hInstance, sal, salSize);
                    if (got > 0 && got < (DWORD)salSize)
                    {
                        FcPathRemoveFileSpecW(sal); // fcremote.exe
                        FcPathRemoveFileSpecW(sal); // filecomp
                        FcPathRemoveFileSpecW(sal); // plugins
                        if (FcPathAppendW(sal, L"tandemcommander.exe", salSize))
                        {
                            STARTUPINFOW si;
                            PROCESS_INFORMATION pi;
                            my_zeromem(&si, sizeof(STARTUPINFOW));
                            si.cb = sizeof(STARTUPINFOW);
                            si.lpTitle = NULL;
                            si.dwFlags = STARTF_USESHOWWINDOW;
                            si.wShowWindow = SW_SHOWNORMAL;
                            if (CreateProcessW(sal, NULL, NULL, NULL, FALSE, CREATE_DEFAULT_ERROR_MODE | NORMAL_PRIORITY_CLASS, NULL, NULL, &si, &pi))
                            {
                                launched = TRUE;
                                HANDLE started =
                                    CreateEvent(NULL, TRUE, FALSE, StartedEventName);
                                WaitForSingleObject(started, 5000);
                                CloseHandle(started);
                                CloseHandle(pi.hProcess);
                                CloseHandle(pi.hThread);
                            }
                        }
                    }
                    FcFree(sal);
                }
                if (!launched)
                {
                    MessageBox(NULL, LoadStr(IDS_LAUNCHSAL), LoadStr(IDS_SPLERROR), MB_OK | MB_ICONERROR);
                    break;
                }
                firstTry = FALSE;
                continue; // try again with Salamander already running
            }
            MessageBox(NULL, LoadStr(IDS_MSGERR2), LoadStr(IDS_SPLERROR), MB_OK | MB_ICONERROR);
            break;
        }

        if (wait)
        {
            wsprintf(msg->ReleaseEvent, "FCREMOTE%X", GetCurrentProcessId());
            releaseEvent = CreateEvent(NULL, TRUE, FALSE, msg->ReleaseEvent);
            if (releaseEvent == NULL)
                *msg->ReleaseEvent = 0;
        }
        else
            *msg->ReleaseEvent = 0;

        // -w also ends when the program ends (the plug-in signals the event when the comparison
        // window closes; a process that ends without that must not leave fcremote waiting); the
        // process is opened BEFORE the message is sent, so an exit right after the send cannot
        // be missed (review)
        if (releaseEvent != NULL)
            receiver = OpenProcess(SYNCHRONIZE, FALSE, mc.GetRecieverPid());

        AllowSetForegroundWindow(ASFW_ANY);
        if (!mc.SendMessage(&msg->Header, 5000))
        {
            MessageBox(NULL, LoadStr(IDS_MSGERR), LoadStr(IDS_SPLERROR), MB_OK | MB_ICONERROR);
            break; // feature 102: -w does not wait for a message that was never delivered
        }
        ret = 0;
        break;
    }
    FcFree(msg);
    if (releaseEvent != NULL)
    {
        if (ret == 0)
        {
            HANDLE handles[2] = {releaseEvent, receiver};
            DWORD res = WaitForMultipleObjects(receiver != NULL ? 2 : 1, handles, FALSE, INFINITE);
            if (res != WAIT_OBJECT_0)
                ret = -1; // the program ended without finishing the comparison
        }
        CloseHandle(releaseEvent);
    }
    if (receiver != NULL)
        CloseHandle(receiver);
    if (DLLInstance)
        FreeLibrary(DLLInstance);
    return ret;
}

// ****************************************************************************
// EnableExceptionsOn64
//

// We want to be notified about SEH exceptions even on x64 Windows 7 SP1 and newer
// http://blog.paulbetts.org/index.php/2010/07/20/the-case-of-the-disappearing-onload-exception-user-mode-callback-exceptions-in-x64/
// http://connect.microsoft.com/VisualStudio/feedback/details/550944/hardware-exceptions-on-x64-machines-are-silently-caught-in-wndproc-messages
// http://support.microsoft.com/kb/976038
void EnableExceptionsOn64()
{
    typedef BOOL(WINAPI * FSetProcessUserModeExceptionPolicy)(DWORD dwFlags);
    typedef BOOL(WINAPI * FGetProcessUserModeExceptionPolicy)(LPDWORD dwFlags);
    typedef BOOL(WINAPI * FIsWow64Process)(HANDLE, PBOOL);
#define PROCESS_CALLBACK_FILTER_ENABLED 0x1

    HINSTANCE hDLL = LoadLibrary("KERNEL32.DLL");
    if (hDLL != NULL)
    {
        FIsWow64Process isWow64 = (FIsWow64Process)GetProcAddress(hDLL, "IsWow64Process");                                                      // Min: XP SP2
        FSetProcessUserModeExceptionPolicy set = (FSetProcessUserModeExceptionPolicy)GetProcAddress(hDLL, "SetProcessUserModeExceptionPolicy"); // Min: Vista with hotfix
        FGetProcessUserModeExceptionPolicy get = (FGetProcessUserModeExceptionPolicy)GetProcAddress(hDLL, "GetProcessUserModeExceptionPolicy"); // Min: Vista with hotfix
        if (isWow64 != NULL && set != NULL && get != NULL)
        {
            BOOL bIsWow64;
            if (isWow64(GetCurrentProcess(), &bIsWow64) && bIsWow64)
            {
                DWORD dwFlags;
                if (get(&dwFlags))
                    set(dwFlags & ~PROCESS_CALLBACK_FILTER_ENABLED);
            }
        }
        FreeLibrary(hDLL);
    }
}

// requires VC2008
void* __cdecl operator new(size_t size)
{
    return HeapAlloc(GetProcessHeap(), 0, size);
}

void __cdecl operator delete(void* ptr)
{
    HeapFree(GetProcessHeap(), 0, ptr);
}

// requires VC2015
void* __cdecl operator new[](size_t size)
{
    return HeapAlloc(GetProcessHeap(), 0, size);
}

void __cdecl operator delete[](void* ptr)
{
    HeapFree(GetProcessHeap(), 0, ptr);
}

void WinMainCRTStartup()
{
    EnableExceptionsOn64();
    // avoid critical errors such as "no disk in drive A:"
    SetErrorMode(SetErrorMode(0) | SEM_FAILCRITICALERRORS);

    int ret = RemoteCompareFiles(GetModuleHandle(NULL), GetCommandLineW()); // feature 102: UTF-16
    ExitProcess(ret);
}
