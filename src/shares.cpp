// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later
// CommentsTranslationProject: TRANSLATED

#include "precomp.h"
#include <lm.h>
#include "salheapstr.h" // feature 101

//****************************************************************************
//
// CSharesItem
//

CSharesItem::CSharesItem(const char* localPath, const char* remoteName, const char* comment)
{
    Cleanup();

    if (localPath != NULL && localPath[0] != 0 && localPath[1] == ':')
    {
        char buff[MAX_PATH];
        lstrcpyn(buff, localPath, MAX_PATH);
        SalPathAddBackslash(buff, MAX_PATH); // in case it was only "c:", make sure a root is created
        if (SalGetFullName(buff))            // root "c\\", others without the trailing '\\' at the end
        {
            LocalPath = DupStr(buff);
            RemoteName = DupStr(remoteName);
            Comment = DupStr(comment);
            if (LocalPath != NULL && RemoteName != NULL && Comment != NULL)
            {
                char* s = strrchr(LocalPath, '\\');
                if (s == NULL || *(s + 1) == 0) // root path; s == NULL is only for safety, but it can never happen
                    LocalName = LocalPath;
                else
                    LocalName = s + 1;
            }
            else
            {
                TRACE_E(LOW_MEMORY);
                Destroy();
                Cleanup();
            }
        }
        else
            TRACE_E("Unexpected path (1) in CSharesItem::CSharesItem()");
    }
    else
        TRACE_E("Unexpected path (2) in CSharesItem::CSharesItem()");
}

CSharesItem::~CSharesItem()
{
    Destroy();
}

void CSharesItem::Cleanup()
{
    LocalPath = NULL;
    LocalName = NULL;
    RemoteName = NULL;
    Comment = NULL;
}

void CSharesItem::Destroy()
{
    if (LocalPath != NULL)
        free(LocalPath); // LocalName points into LocalPath, so we do not free it
    if (RemoteName != NULL)
        free(RemoteName);
    if (Comment != NULL)
        free(Comment);
}

//****************************************************************************
//
// CShares
//

/* Share loading section */

void CShares::Refresh()
{
    HANDLES(EnterCriticalSection(&CS));
    Wanted.DestroyMembers();
    Data.DestroyMembers();

    PSHARE_INFO_502 BufPtr, p;
    NET_API_STATUS res;
    DWORD er = 0, tr = 0, resume = 0, i;

    do
    {
        res = NetShareEnum(NULL, 502, (LPBYTE*)&BufPtr, -1, &er, &tr, &resume);
        if (res == ERROR_SUCCESS || res == ERROR_MORE_DATA)
        {
            p = BufPtr;
            for (i = 1; i <= er; i++)
            {
                // feature 069 (F-P1-27): UTF-8 needs up to 3 bytes per character,
                // and a remark may be 256 characters - at MAX_PATH both
                // conversions could fail and the share would vanish from the
                // list and lose its shared-folder marker
                char netname[3 * MAX_PATH];
                char remark[3 * MAX_PATH];
                // 'path' stays at MAX_PATH on purpose, unlike its two
                // neighbours: CSharesItem lstrcpyn's it into a MAX_PATH buffer,
                // which cuts on a BYTE boundary and would tear the last UTF-8
                // sequence.  Leaving it narrow means a path too long for UTF-8
                // falls to the code-page branch below and reaches the item
                // whole - exactly as before, mojibake but readable - while
                // every path that does fit still arrives as UTF-8 and matches
                // the panel.
                char path[MAX_PATH];
                // we do not want specials because Explorer does not show them
                BOOL include = p->shi502_type == 0;
                if (!SubsetOnly && p->shi502_type == 0x80000000) // special share
                    include = TRUE;
                // feature 069 (F-P1-27): NetShareEnum is W-only, so the true name
                // is right here - and it was degraded to the active code page.
                // The cache is then compared against UTF-8 panel data
                // (fileswn3.cpp CFileData::Name, drivelst.cpp the drive root),
                // so a share whose name is not ASCII could never match and its
                // folder never got the shared-folder marker; GetUNCPath could
                // not map such a local path to its UNC form either.  SalWToU8 is
                // total, so no failure branch is needed - only the "does it fit"
                // one, where the legacy conversion still applies.
                if (include &&
                    (SalWToU8(p->shi502_netname, -1, netname, sizeof(netname)) != 0 ||
                     WideCharToMultiByte(CP_ACP, 0, p->shi502_netname, -1, netname, sizeof(netname), NULL, NULL)) &&
                    (SalWToU8(p->shi502_path, -1, path, sizeof(path)) != 0 ||
                     WideCharToMultiByte(CP_ACP, 0, p->shi502_path, -1, path, sizeof(path), NULL, NULL)) &&
                    (SalWToU8(p->shi502_remark, -1, remark, sizeof(remark)) != 0 ||
                     WideCharToMultiByte(CP_ACP, 0, p->shi502_remark, -1, remark, sizeof(remark), NULL, NULL)))
                {
                    //              TRACE_I("Share: " << netname << " = " << path);
                    // add the shared path to the Data array
                    CSharesItem* item = new CSharesItem(path, netname, remark);
                    if (item != NULL && item->IsGood())
                    {
                        Data.Add(item);
                        if (Data.IsGood())
                            item = NULL; // added successfully
                        else
                        {
                            delete item;
                            Data.ResetState();
                            Data.DestroyMembers();
                            break; // error, no point in continuing the enumeration
                        }
                    }
                    if (item != NULL)
                        delete item;
                }
                p++;
            }
            NetApiBufferFree(BufPtr);
        }
        else
            TRACE_I("Error getting shares: (" << res << ") " << GetErrorText(res));
    } while (res == ERROR_MORE_DATA);
    HANDLES(LeaveCriticalSection(&CS));
}

CShares::CShares(BOOL subsetOnly)
    : Data(10, 10), Wanted(10, 10, dtNoDelete)
{
    HANDLES(InitializeCriticalSection(&CS));
    SubsetOnly = subsetOnly;
}

CShares::~CShares()
{
    HANDLES(DeleteCriticalSection(&CS));
}

BOOL CShares::GetWantedIndex(const char* name, int& index)
{
    if (Wanted.Count == 0)
    {
        index = 0;
        return FALSE;
    }

    int l = 0, r = Wanted.Count - 1, m;
    while (1)
    {
        m = (l + r) / 2;
        char* hw = Wanted[m]->LocalName;
        int res = StrICmp(hw, name);
        if (res == 0) // found
        {
            index = m;
            return TRUE;
        }
        else
        {
            if (res > 0)
            {
                if (l == r || l > m - 1) // not found
                {
                    index = m; // should be at this position
                    return FALSE;
                }
                r = m - 1;
            }
            else
            {
                if (l == r) // not found
                {
                    index = m + 1; // should be after this position
                    return FALSE;
                }
                l = m + 1;
            }
        }
    }
}

void CShares::PrepareSearch(const char* path)
{
    HANDLES(EnterCriticalSection(&CS));
    // empty the Wanted array
    Wanted.DestroyMembers();

    // put in only the shares that lie on the requested path
    // feature 101: the whole path (it was cut to 259 bytes: a longer panel path could then equal
    // the parent folder of a share that is not in it)
    CSalHeapString buffStr;
    if (!buffStr.Copy(path, 1))
    {
        TRACE_E(LOW_MEMORY);
        HANDLES(LeaveCriticalSection(&CS));
        return;
    }
    char* buff = buffStr.Get();
    if (buff[0] != 0)                               // when we search for shares from this_computer, we must not append a backslash
        SalPathAddBackslash(buff, buffStr.Size()); // we want a backslash at the end
    int pathLen = (int)strlen(buff);

    int i;
    for (i = 0; i < Data.Count; i++)
    {
        CSharesItem* item = Data[i];
        int itemNameLen = (int)(item->LocalName - item->LocalPath);
        if (SalNameEqualOrdinalCI(item->LocalPath, itemNameLen, buff, pathLen)) // feature 092: no byte-length test
        {
            int index;
            if (!GetWantedIndex(item->LocalName, index)) // add the matching share to Wanted array only if it is not already there
            {
                Wanted.Insert(index, item);
            }
        }
    }
    HANDLES(LeaveCriticalSection(&CS));
}

BOOL CShares::Search(const char* name)
{
    HANDLES(EnterCriticalSection(&CS));
    int index;
    BOOL ret = GetWantedIndex(name, index);
    HANDLES(LeaveCriticalSection(&CS));
    return ret;
}

BOOL CShares::GetUNCPath(const char* path, char* uncPath, int uncPathMax, BOOL* tooLong)
{
    HANDLES(EnterCriticalSection(&CS));
    // feature 101: the whole 'path' is matched (it was cut to 259 bytes, with a backslash
    // appended, before the comparison), and only at a component boundary: the share of local path
    // "C:\foo" holds "C:\foo" and "C:\foo\x", never "C:\foobar" - the prefix test alone (since
    // Open Salamander) turned "C:\foobar\x" into "\\computer\<share of C:\foo>\bar\x"

    int longestIndex = -1; // index into Data array holding the longest matching share
    int longestBytes = 0;  // feature 092: bytes of 'path' that share's local path covers (not always its own length)

    int i;
    for (i = 0; i < Data.Count; i++)
    {
        CSharesItem* item = Data[i];
        int itemNameLen = (int)strlen(item->LocalPath);
        int n = 0;
        if (SalPathIsWithinOrdinalCI(path, item->LocalPath, &n))
        {
            // look for the longest possible share that still matches the requested 'path'
            if (longestIndex == -1 || (int)strlen(Data[longestIndex]->LocalPath) < itemNameLen)
            {
                longestIndex = i;
                longestBytes = n;
            }
        }
    }
    if (longestIndex != -1)
    {
        CSharesItem* item = Data[longestIndex];
        // insert the name of our computer
        char unc[2 * MAX_PATH];
        strcpy(unc, "\\\\");
        DWORD len = MAX_PATH;
        GetComputerName(unc + 2, &len);
        strcat(unc, "\\");
        // feature 098: the share name and the rest of the path are appended only when they fit (the
        // rest comes from the whole 'path', up to 519 bytes: an unbounded strcat), and the result is
        // never cut to 'uncPathMax' - a path that does not fit is not converted
        const char* s = "";
        if (longestBytes < (int)strlen(path))
        {
            s = path + longestBytes;
            if (*s == '\\')
                s++; // skip an optional backslash
        }
        if (strlen(unc) + strlen(item->RemoteName) + 1 + strlen(s) >= sizeof(unc))
        {
            if (tooLong != NULL)
                *tooLong = TRUE; // feature 101
            HANDLES(LeaveCriticalSection(&CS));
            return FALSE;
        }
        // append the share name
        strcat(unc, item->RemoteName);
        SalPathAddBackslash(unc, 2 * MAX_PATH); // we want a backslash at the end
        // from the original path, append the directories starting from the share
        strcat(unc, s);
        if (!SalGetFullName(unc, NULL, NULL, NULL, NULL, 2 * MAX_PATH)) // root "c\\", others without the trailing '\\' at the end
        {
            TRACE_E("Unexpected path in CSharesItem::GetUNCPath()");
            HANDLES(LeaveCriticalSection(&CS));
            return FALSE;
        }
        if ((int)strlen(unc) >= uncPathMax)
        {
            if (tooLong != NULL)
                *tooLong = TRUE; // feature 101
            HANDLES(LeaveCriticalSection(&CS));
            return FALSE;
        }

        lstrcpyn(uncPath, unc, uncPathMax);
        HANDLES(LeaveCriticalSection(&CS));
        return TRUE;
    }
    else
    {
        HANDLES(LeaveCriticalSection(&CS));
        return FALSE;
    }
}

BOOL CShares::GetItem(int index, const char** localPath, const char** remoteName, const char** comment)
{
    HANDLES(EnterCriticalSection(&CS));
    if (index < 0 || index >= Data.Count)
    {
        TRACE_E("CShares::GetItem index=" << index);
        HANDLES(LeaveCriticalSection(&CS));
        return FALSE;
    }
    CSharesItem* item = Data[index];
    if (localPath != NULL)
        *localPath = item->LocalPath;
    if (remoteName != NULL)
        *remoteName = item->RemoteName;
    if (comment != NULL)
        *comment = item->Comment;
    HANDLES(LeaveCriticalSection(&CS));
    return TRUE;
}

//****************************************************************************
//
// CUncSharesJob (feature 125)
//
// Reads the folder shares of one server on a worker thread. The main thread
// waits for 'Done' (with a cancellable wait window) or abandons the job; the
// job is freed by whoever drops the last reference. An abandoned worker ends
// when its system call returns; only the program's exit ends one that is still
// blocked then (AddAuxThread).
//

#include <winnetwk.h>
#include "saluncserver.h"

CUncSharesJob::CUncSharesJob()
{
    ServerW = NULL;
    Shares = NULL;
    Count = 0;
    Error = ERROR_SUCCESS;
    Done = NULL;
    Refs = 1;
    Allocated = 0;
}

CUncSharesJob::~CUncSharesJob()
{
    for (int i = 0; i < Count; i++)
        free(Shares[i].Name);
    free(Shares);
    free(ServerW);
    if (Done != NULL)
        NOHANDLES(CloseHandle(Done)); // not monitored: an abandoned job may outlive the handle check at exit
}

void CUncSharesJob::Release()
{
    if (InterlockedDecrement(&Refs) == 0)
        delete this;
}

// adds a share when it is a folder share; FALSE = out of memory
BOOL CUncSharesJob::Add(const WCHAR* nameW, DWORD type)
{
    if (nameW == NULL || nameW[0] == 0 || !SalUncShareOffered(type))
        return TRUE;
    char* name = SalWToU8Alloc(nameW, -1); // the whole name, any length
    if (name == NULL)
        return FALSE;
    if (Count == Allocated)
    {
        int newAlloc = Allocated == 0 ? 32 : 2 * Allocated;
        CUncShare* n = (CUncShare*)realloc(Shares, newAlloc * sizeof(CUncShare));
        if (n == NULL)
        {
            free(name);
            return FALSE;
        }
        Shares = n;
        Allocated = newAlloc;
    }
    Shares[Count].Name = name;
    Shares[Count].Hidden = SalUncShareHidden(name, type);
    Count++;
    return TRUE;
}

static int UncSharesCompare(const void* a, const void* b)
{
    const CUncShare* sa = (const CUncShare*)a;
    const CUncShare* sb = (const CUncShare*)b;
    return SalUncShareCompare(sa->Name, sa->Hidden, sb->Name, sb->Hidden);
}

void CUncSharesJob::Read()
{
#ifdef _DEBUG
    // probe seam, Debug builds only (specs/125-unc-server-shares/contracts/probe-seam.md)
    {
        WCHAR env[4000];
        DWORD len = GetEnvironmentVariableW(L"TC_PROBE_UNC_DELAY", env, _countof(env));
        if (len > 0 && len < _countof(env))
            Sleep(_wtoi(env));
        len = GetEnvironmentVariableW(L"TC_PROBE_UNC_ERROR", env, _countof(env));
        if (len > 0 && len < _countof(env))
        {
            Error = (DWORD)_wtoi(env);
            return;
        }
        len = GetEnvironmentVariableW(L"TC_PROBE_UNC_SHARES", env, _countof(env));
        if (len > 0 && len < _countof(env))
        {
            WCHAR* s = env;
            while (*s != 0)
            {
                WCHAR* e = s;
                while (*e != 0 && *e != L'|')
                    e++;
                WCHAR* next = *e != 0 ? e + 1 : e;
                *e = 0;
                DWORD type = STYPE_DISKTREE;
                WCHAR* star = wcschr(s, L'*');
                if (star != NULL)
                {
                    *star = 0;
                    type = wcstoul(star + 1, NULL, 10);
                }
                if (!Add(s, type))
                {
                    Error = ERROR_NOT_ENOUGH_MEMORY;
                    return;
                }
                s = next;
            }
            qsort(Shares, Count, sizeof(CUncShare), UncSharesCompare);
            return;
        }
    }
#endif // _DEBUG

    // level 1: names, types and remarks of all shares, hidden ones included
    DWORD firstErr = ERROR_SUCCESS;
    DWORD resume = 0;
    NET_API_STATUS res;
    do
    {
        SHARE_INFO_1* buf = NULL;
        DWORD read = 0, total = 0;
        res = NetShareEnum(ServerW, 1, (LPBYTE*)&buf, MAX_PREFERRED_LENGTH, &read, &total, &resume);
        if (res == ERROR_SUCCESS || res == ERROR_MORE_DATA)
        {
            for (DWORD i = 0; buf != NULL && i < read; i++)
            {
                if (!Add(buf[i].shi1_netname, buf[i].shi1_type))
                {
                    NetApiBufferFree(buf);
                    Error = ERROR_NOT_ENOUGH_MEMORY;
                    return;
                }
            }
        }
        else
            firstErr = res;
        if (buf != NULL)
            NetApiBufferFree(buf);
    } while (res == ERROR_MORE_DATA);

    // a server that was not found is not asked a second time (another network timeout)
    BOOL notFound = firstErr == ERROR_BAD_NETPATH || firstErr == ERROR_REM_NOT_LIST ||
                    firstErr == ERROR_NETWORK_UNREACHABLE || firstErr == ERROR_HOST_UNREACHABLE;
    if (notFound)
        Error = firstErr;
    else if (firstErr != ERROR_SUCCESS && Count == 0)
    {
        // the share list was refused (commonly ERROR_ACCESS_DENIED): the visible disk shares as
        // the network provider enumerates them for the session Windows already has
        NETRESOURCEW nr;
        memset(&nr, 0, sizeof(nr));
        nr.dwScope = RESOURCE_GLOBALNET;
        nr.dwType = RESOURCETYPE_DISK;
        nr.dwDisplayType = RESOURCEDISPLAYTYPE_SERVER;
        nr.dwUsage = RESOURCEUSAGE_CONTAINER;
        nr.lpRemoteName = ServerW;
        HANDLE hEnum;
        DWORD err = WNetOpenEnumW(RESOURCE_GLOBALNET, RESOURCETYPE_DISK, 0, &nr, &hEnum);
        if (err == NO_ERROR)
        {
            DWORD bufSize = 32 * 1024;
            BYTE* buf = (BYTE*)malloc(bufSize);
            if (buf == NULL)
                err = ERROR_NOT_ENOUGH_MEMORY;
            while (err == NO_ERROR)
            {
                DWORD count = (DWORD)-1;
                DWORD size = bufSize;
                err = WNetEnumResourceW(hEnum, &count, buf, &size);
                if (err == NO_ERROR)
                {
                    NETRESOURCEW* r = (NETRESOURCEW*)buf;
                    for (DWORD i = 0; i < count; i++)
                    {
                        const WCHAR* remote = r[i].lpRemoteName; // "\\server\share"
                        const WCHAR* name = remote != NULL ? wcsrchr(remote, L'\\') : NULL;
                        if (name != NULL && r[i].dwType == RESOURCETYPE_DISK && !Add(name + 1, STYPE_DISKTREE))
                            err = ERROR_NOT_ENOUGH_MEMORY;
                    }
                }
            }
            if (err == ERROR_NO_MORE_ITEMS)
                err = NO_ERROR;
            free(buf);
            WNetCloseEnum(hEnum);
        }
        // the first refusal is the one reported when the second way fails too
        Error = err == NO_ERROR ? ERROR_SUCCESS : firstErr;
    }
    if (Count > 1)
        qsort(Shares, Count, sizeof(CUncShare), UncSharesCompare);
}

static unsigned UncSharesThreadFBody(void* param)
{
    CALL_STACK_MESSAGE1("UncSharesThreadFBody()");
    SetThreadNameInVCAndTrace("UncShares");
    CUncSharesJob* job = (CUncSharesJob*)param;
    job->Read();
    SetEvent(job->Done);
    job->Release();
    return 0;
}

static unsigned UncSharesThreadFEH(void* param)
{
    CALL_STACK_MESSAGE_NONE
#ifndef CALLSTK_DISABLE
    __try
    {
#endif // CALLSTK_DISABLE
        return UncSharesThreadFBody(param);
#ifndef CALLSTK_DISABLE
    }
    __except (CCallStack::HandleException(GetExceptionInformation()))
    {
        TRACE_I("Thread UncShares: calling ExitProcess(1).");
        TerminateProcess(GetCurrentProcess(), 1); // harder exit (this one still calls something)
        return 1;
    }
#endif // CALLSTK_DISABLE
}

static DWORD WINAPI UncSharesThreadF(void* param)
{
    CALL_STACK_MESSAGE_NONE
#ifndef CALLSTK_DISABLE
    CCallStack stack;
#endif // CALLSTK_DISABLE
    return UncSharesThreadFEH(param);
}

CUncSharesJob* CUncSharesJob::Start(const char* server)
{
    CUncSharesJob* job = new CUncSharesJob;
    if (job == NULL)
        return NULL;
    char unc[MAX_PATH + 3];
    WCHAR* serverW = NULL;
    if (server != NULL && strlen(server) < MAX_PATH)
    {
        unc[0] = '\\';
        unc[1] = '\\';
        strcpy(unc + 2, server);
        serverW = SalU8ToWAlloc(unc);
    }
    job->ServerW = serverW;
    job->Done = NOHANDLES(CreateEvent(NULL, TRUE, FALSE, NULL));
    if (serverW == NULL || job->Done == NULL)
    {
        job->Release();
        return NULL;
    }
    InterlockedIncrement(&job->Refs); // the worker's reference
    DWORD threadID;
    HANDLE thread = HANDLES(CreateThread(NULL, 0, UncSharesThreadF, job, 0, &threadID));
    if (thread == NULL)
    {
        job->Release(); // the worker's
        job->Release(); // ours
        return NULL;
    }
    // the exit path knows the thread: a worker still blocked in a network call when the program
    // ends (the user gave up waiting) is closed with the other auxiliary threads
    AddAuxThread(thread, TRUE);
    return job;
}
