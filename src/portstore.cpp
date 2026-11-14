// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

// Feature 428: the settings store of the portable edition - see portstore.h and
// specs/428-portable-build/contracts/settings-store.md.

#include "precomp.h"

#ifdef TC_PORTABLE

#include <process.h>
#include <list>
#include <string>
#include <vector>

#include "cfgdlg.h" // LoadSaveToRegistryMutex (review A3)
#include "portstore.h"
#include "salportable.h"
#include "salsafereplace.h"
#include "salheapstr.h"
#include "reglib\src\regparse.h"

HKEY PortableStoreRoot = NULL;

namespace
{
    // the configuration's key as reglib names it - the same text an export of the normal edition
    // has, so a settings file of either edition imports into the other (FR-013)
    std::string CfgKeyName;

    std::wstring ProgramDirW;  // long-name form, no trailing backslash ("E:" for a drive root)
    std::string ProgramDirU8;  // the same in UTF-8 - what $(PortableDir) stands for in the file
    std::wstring SettingsDirW; // <program folder>\settings
    std::string SettingsDirU8;
    std::wstring SettingsFileW; // settings\tandemcommander.reg
    std::wstring BakFileW;      // settings\tandemcommander.reg.bak
    std::wstring PendingImportW; // settings\import.reg - Import Configuration, applied at the next start
    std::wstring SessionDirW;   // %TEMP%\TandemCommander-portable-<scope>
    std::wstring SessionHiveW;  // ...\session.dat
    std::string Scope;          // 16 hex digits
    std::string ScopeSuffix;    // "_P<scope>"

    HANDLE StoreMutex = NULL; // Local\TandemCommanderPortable_<scope>_Store
    HANDLE WorkerThread = NULL;
    HANDLE StopEvent = NULL;
    CRITICAL_SECTION PersistCS;
    BOOL PersistCSReady = FALSE;

    volatile LONG Dirty = 0;
    BOOL Joined = FALSE; // another process of this copy was running at start (its session joined)
    HANDLE HeldStartLock = NULL; // the start lock kept until a pending import is applied (review A4)
    volatile LONG Writable = TRUE;
    volatile DWORD LastChangeTick = 0; // the last change of the hive or failed persist (worker's quiet period)
    // persists that did not save, in a row (under PersistCS): after FAIL_STOP_MS of nothing but
    // failures - a file held that long, a dump that keeps failing, a save of another process of the
    // copy that crashed half-way ("Save In Progress") - saving stops and the user is told (re-review 3)
    int FailedPersists = 0;
    DWORD FirstFailureTick = 0;
    const DWORD FAIL_STOP_MS = 60000;
    BOOL PendingImportToDelete = FALSE; // an applied import whose settings are not in the file yet

    // messages that wait for the language module / a free main window
    volatile LONG NoteCannotSave = 0; // 1 = pending, 2 = shown (once per session)
    volatile LONG NotePassword = 0;   // FR-015a: 1 = pending, 2 = shown (once per session)
    BOOL NoteRestoredBak = FALSE;
    BOOL NoteDamaged = FALSE;
    std::string DamagedSuffix; // ".damaged-<UTC>"
    HWND NoteWnd = NULL;

    const DWORD PERSIST_QUIET_MS = 2000;
    const LONGLONG SETTINGS_FILE_MAX = 10000000; // above 10 MB it is not ours (as the import says)

    std::wstring ToW(const char* u8)
    {
        std::wstring w;
        WCHAR* p = SalU8ToWAlloc(u8);
        if (p != NULL)
        {
            w = p;
            free(p);
        }
        return w;
    }

    std::string ToU8(const WCHAR* w)
    {
        std::string s;
        char* p = SalWToU8Alloc(w);
        if (p != NULL)
        {
            s = p;
            free(p);
        }
        return s;
    }

    // "E:" (a drive root kept without its backslash) must reach the API as "E:\"
    std::wstring DirForApi(const std::wstring& dir)
    {
        if (dir.size() == 2 && dir[1] == L':')
            return dir + L"\\";
        return dir;
    }

    BOOL FileExists(const std::wstring& path)
    {
        return GetFileAttributesW(path.c_str()) != INVALID_FILE_ATTRIBUTES;
    }

    BOOL GetProgramDir()
    {
        std::vector<WCHAR> buf(32768);
        DWORD n = GetModuleFileNameW(NULL, buf.data(), (DWORD)buf.size());
        if (n == 0 || n >= buf.size())
            return FALSE;
        std::wstring exe(buf.data(), n);
        size_t slash = exe.find_last_of(L'\\');
        if (slash == std::wstring::npos)
            return FALSE;
        std::wstring dir = exe.substr(0, slash);
        std::wstring api = DirForApi(dir);
        DWORD ln = GetLongPathNameW(api.c_str(), NULL, 0);
        if (ln > 0)
        {
            std::vector<WCHAR> lb(ln + 1);
            DWORD got = GetLongPathNameW(api.c_str(), lb.data(), ln + 1);
            if (got > 0 && got <= ln)
            {
                dir.assign(lb.data(), got);
                while (dir.size() > 2 && dir.back() == L'\\')
                    dir.pop_back();
                if (dir.size() == 3 && dir[1] == L':' && dir[2] == L'\\')
                    dir.resize(2);
            }
        }
        ProgramDirW = dir;
        ProgramDirU8 = ToU8(dir.c_str());
        return !ProgramDirU8.empty();
    }

    void ComputeScope()
    {
        char hex[17];
        SalPortableFolderScope(DirForApi(ProgramDirW).c_str(), hex); // salportscope.h (fcremote.exe: the same rule)
        Scope = hex;
        ScopeSuffix = SalPortableScopeSuffix(Scope);
    }

    std::wstring MutexName(const std::string& scope, const char* what)
    {
        return ToW(("Local\\TandemCommanderPortable_" + scope + "_" + what).c_str());
    }

    // removes a folder tree; never follows a reparse point (a link is removed, not its target)
    void RemoveTree(const std::wstring& dir)
    {
        WIN32_FIND_DATAW fd;
        HANDLE f = FindFirstFileW((dir + L"\\*").c_str(), &fd);
        if (f != INVALID_HANDLE_VALUE)
        {
            do
            {
                if (wcscmp(fd.cFileName, L".") == 0 || wcscmp(fd.cFileName, L"..") == 0)
                    continue;
                std::wstring p = dir + L"\\" + fd.cFileName;
                if (fd.dwFileAttributes & FILE_ATTRIBUTE_READONLY)
                    SetFileAttributesW(p.c_str(), fd.dwFileAttributes & ~FILE_ATTRIBUTE_READONLY);
                if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
                {
                    if (!(fd.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT))
                        RemoveTree(p);
                    else
                        RemoveDirectoryW(p.c_str());
                }
                else
                    DeleteFileW(p.c_str());
            } while (FindNextFileW(f, &fd));
            FindClose(f);
        }
        RemoveDirectoryW(dir.c_str());
    }

    // a crashed copy's session folder must not stay on the PC: every other session folder whose copy
    // is neither starting (start lock held) nor running (its hive is loaded, delete = sharing) goes
    void CleanStaleSessions(const std::wstring& tempDir, const std::wstring& ownDirName)
    {
        WIN32_FIND_DATAW fd;
        HANDLE f = FindFirstFileW((tempDir + ToW(SALPORTABLE_SESSION_PREFIX) + L"*").c_str(), &fd);
        if (f == INVALID_HANDLE_VALUE)
            return;
        do
        {
            if (!(fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) || (fd.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT))
                continue;
            if (_wcsicmp(fd.cFileName, ownDirName.c_str()) == 0)
                continue;
            std::string name = ToU8(fd.cFileName);
            if (!SalPortableIsSessionDirName(name.c_str()))
                continue;
            std::string scope = name.substr(sizeof(SALPORTABLE_SESSION_PREFIX) - 1);
            HANDLE m = OpenMutexW(SYNCHRONIZE, FALSE, MutexName(scope, "Start").c_str());
            if (m != NULL)
            {
                DWORD w = WaitForSingleObject(m, 0);
                if (w == WAIT_OBJECT_0 || w == WAIT_ABANDONED)
                    ReleaseMutex(m);
                CloseHandle(m);
                if (w == WAIT_TIMEOUT)
                    continue; // that copy is starting right now
            }
            std::wstring dir = tempDir + fd.cFileName;
            std::wstring hive = dir + L"\\session.dat";
            if (DeleteFileW(hive.c_str()) || GetLastError() == ERROR_FILE_NOT_FOUND ||
                GetLastError() == ERROR_PATH_NOT_FOUND)
            {
                TRACE_I("PortableStore: removing a stale session folder of another copy");
                RemoveTree(dir);
            }
        } while (FindNextFileW(f, &fd));
        FindClose(f);
    }

    // ************************************************************************
    // $(PortableDir) on the way to / from the file (research R-03)

    // one string value (UTF-8, no terminator) through the rule
    std::string MapText(const std::string& s, BOOL relativize)
    {
        return relativize ? SalPortableRelativize(s.c_str(), ProgramDirU8.c_str())
                          : SalPortableExpand(s.c_str(), ProgramDirU8.c_str());
    }

    // keys whose values are bound to a drive letter by their NAME: a path there must keep its own
    // drive - "Default Directories" holds the last folder of each drive under the drive's letter
    // ("C" = "C:\\..."), and $(PortableDir) would move it to the drive of the portable folder (the
    // load then refuses it: "Unexpected value" - found by the move probe of 428)
    BOOL KeyKeepsAbsolutePaths(const char* keyPath)
    {
        return _stricmp(keyPath, "\\Default Directories") == 0;
    }

    BOOL PathTransform(const char* keyPath, DWORD type, const BYTE* data, DWORD size, LPBYTE* newData, DWORD* newSize,
                       void* ctx)
    {
        *newData = NULL;
        *newSize = 0;
        BOOL relativize = ctx != NULL;
        if (type != REG_SZ && type != REG_EXPAND_SZ && type != REG_MULTI_SZ)
            return TRUE;
        if (keyPath != NULL && KeyKeepsAbsolutePaths(keyPath))
            return TRUE;
        if (data == NULL || size == 0)
            return TRUE;
        std::string out;
        BOOL changed = FALSE;
        if (type == REG_MULTI_SZ)
        {
            DWORD p = 0;
            while (p < size)
            {
                const BYTE* nul = (const BYTE*)memchr(data + p, 0, size - p);
                if (nul == NULL)
                    return TRUE; // not terminated: leave the value as it is
                std::string s((const char*)data + p, nul - (data + p));
                if (s.empty())
                    break; // the list's terminator
                std::string m = MapText(s, relativize);
                if (m != s)
                    changed = TRUE;
                out += m;
                out.push_back(0);
                p = (DWORD)(nul - data) + 1;
            }
            out.push_back(0);
        }
        else
        {
            const BYTE* nul = (const BYTE*)memchr(data, 0, size);
            if (nul == NULL)
                return TRUE;
            std::string s((const char*)data, nul - data);
            std::string m = MapText(s, relativize);
            if (m == s)
                return TRUE;
            out = m;
            out.push_back(0);
            changed = TRUE;
        }
        if (!changed)
            return TRUE;
        LPBYTE nd = (LPBYTE)malloc(out.size());
        if (nd == NULL)
            return FALSE;
        memcpy(nd, out.data(), out.size());
        *newData = nd;
        *newSize = (DWORD)out.size();
        return TRUE;
    }

    // ************************************************************************
    // the file

    // reads and parses one settings file into a memory registry (*memReg on spfsOk; Release() it)
    CSalPortableFileState LoadSettingsFile(const std::wstring& path, CSalamanderRegistryExAbstract** memReg)
    {
        *memReg = NULL;
        HANDLE h = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING,
                               FILE_FLAG_SEQUENTIAL_SCAN, NULL);
        if (h == INVALID_HANDLE_VALUE)
        {
            DWORD e = GetLastError();
            return e == ERROR_FILE_NOT_FOUND || e == ERROR_PATH_NOT_FOUND ? spfsAbsent : spfsUnreadable;
        }
        LARGE_INTEGER size;
        if (!GetFileSizeEx(h, &size))
        {
            CloseHandle(h);
            return spfsUnreadable;
        }
        if (size.QuadPart > SETTINGS_FILE_MAX || size.QuadPart < 4)
        {
            CloseHandle(h);
            return spfsBad;
        }
        DWORD bytes = (DWORD)size.QuadPart;
        LPTSTR buf = (LPTSTR)malloc(bytes + 2 * sizeof(WCHAR));
        if (buf == NULL)
        {
            CloseHandle(h);
            return spfsUnreadable; // never treat a file we could not look at as damaged
        }
        DWORD read = 0;
        BOOL ok = ReadFile(h, buf, bytes, &read, NULL) && read == bytes;
        CloseHandle(h);
        if (!ok)
        {
            free(buf);
            return spfsUnreadable;
        }
        memset((BYTE*)buf + bytes, 0, 2 * sizeof(WCHAR));
        if (ConvertIfNeeded(&buf, bytes) == 0)
        {
            free(buf);
            return spfsUnreadable; // out of memory
        }
        CSalamanderRegistryExAbstract* reg = REG_MemRegistryFactory();
        if (reg == NULL)
        {
            free(buf);
            return spfsUnreadable;
        }
        eRPE_ERROR err = Parse(buf, reg, TRUE, SalamanderConfigurationRoots[0], NULL);
        free(buf);
        HKEY key;
        BOOL ours = err == RPE_OK && reg->OpenKey(HKEY_CURRENT_USER, SalamanderConfigurationRoots[0], key); // portable: memory registry
        if (ours)
            reg->CloseKey(key);
        if (!ours)
        {
            TRACE_E("PortableStore: the settings file is not a configuration of ours (" << (int)err << ")");
            reg->Release();
            return spfsBad;
        }
        *memReg = reg;
        return spfsOk;
    }

    // the whole configuration of the session hive as the bytes of the file; FALSE + '*nothing' when
    // the hive holds no configuration yet (a fresh copy before its first save)
    BOOL DumpSession(LPBYTE* data, DWORD* size, BOOL* nothing)
    {
        *data = NULL;
        *size = 0;
        *nothing = FALSE;
        CSalamanderRegistryExAbstract* sysReg = REG_SysRegistryFactory();
        CSalamanderRegistryExAbstract* memReg = REG_MemRegistryFactory();
        BOOL ret = FALSE;
        if (sysReg != NULL && memReg != NULL)
        {
            HKEY probe;
            LONG openErr = RegOpenKeyExW(PortableStoreRoot, ToW(SalamanderConfigurationRoots[0]).c_str(), 0, KEY_READ, &probe);
            if (openErr == ERROR_FILE_NOT_FOUND)
                *nothing = TRUE;
            else if (openErr != ERROR_SUCCESS)
                TRACE_E("PortableStore: the session's configuration cannot be opened (" << openErr << ")"); // a failed dump
            else
            {
                RegCloseKey(probe);
                eRPE_ERROR err = CopyBranchTransform(CfgKeyName.c_str(), sysReg, memReg, PathTransform, (void*)1);
                if (err == RPE_OK)
                    ret = memReg->DumpToBuffer(CfgKeyName.c_str(), data, size);
                else
                    TRACE_E("PortableStore: reading the session hive failed (" << (int)err << ")");
            }
        }
        if (sysReg != NULL)
            sysReg->Release();
        if (memReg != NULL)
            memReg->Release();
        return ret;
    }

    void RotateBackup()
    {
        WCHAR* temp = NULL;
        HANDLE h;
        DWORD err = 0;
        if (!SalCreateTempNextToW(BakFileW.c_str(), L"bak", &temp, &h, &err))
            return;
        CloseHandle(h);
        BOOL copied = CopyFileW(SettingsFileW.c_str(), temp, FALSE);
        if (copied)
        {
            HANDLE f = CreateFileW(temp, GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);
            if (f != INVALID_HANDLE_VALUE)
            {
                FlushFileBuffers(f);
                CloseHandle(f);
            }
            CSalReplaceResult r = SalReplaceWithTempW(BakFileW.c_str(), temp, FileExists(BakFileW), TRUE, &err);
            if (r == srrDone || r == srrLeftAtTemp)
            {
                free(temp);
                return;
            }
        }
        DeleteFileW(temp);
        free(temp);
    }

    BOOL WriteSettingsFile(const BYTE* data, DWORD size, DWORD* err)
    {
        *err = 0;
        // a file the next start would refuse as "not ours" (LoadSettingsFile) is never written:
        // the save fails visibly instead of the next start falling back to defaults (review A7)
        if ((LONGLONG)size > SETTINGS_FILE_MAX)
        {
            *err = ERROR_FILE_TOO_LARGE;
            return FALSE;
        }
        if (!CreateDirectoryW(SettingsDirW.c_str(), NULL) && GetLastError() != ERROR_ALREADY_EXISTS)
        {
            *err = GetLastError();
            return FALSE;
        }
        WCHAR* temp = NULL;
        HANDLE h;
        if (!SalCreateTempNextToW(SettingsFileW.c_str(), L"cfg", &temp, &h, err))
            return FALSE;
        DWORD written = 0;
        BOOL complete = WriteFile(h, data, size, &written, NULL) && written == size && FlushFileBuffers(h);
        if (!complete)
            *err = GetLastError();
        if (!CloseHandle(h) && complete)
        {
            *err = GetLastError();
            complete = FALSE;
        }
        if (!complete)
        {
            DeleteFileW(temp);
            free(temp);
            return FALSE;
        }
        BOOL mainExisted = FileExists(SettingsFileW);
        if (mainExisted)
            RotateBackup();
        // a read-only settings file is the user's "do not save" - it is not cleared (clearReadOnly FALSE)
        CSalReplaceResult r = SalReplaceWithTempW(SettingsFileW.c_str(), temp, mainExisted, FALSE, err);
        if (r == srrDone)
        {
            free(temp);
            return TRUE;
        }
        if (r != srrLeftAtTemp) // srrLeftAtTemp: the temporary file holds the only copy - kept
            DeleteFileW(temp);
        free(temp);
        return FALSE;
    }

    void PostNote()
    {
        HWND w = NoteWnd;
        if (w != NULL)
            PostMessage(w, WM_USER_PORTABLE_NOTE, 0, 0);
    }

    // SalPortableFnv1a64 of the settings file's bytes; FALSE when it is absent or cannot be read
    BOOL FileBytesHash(unsigned __int64* hash)
    {
        HANDLE h = CreateFileW(SettingsFileW.c_str(), GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_DELETE, NULL, OPEN_EXISTING,
                               FILE_FLAG_SEQUENTIAL_SCAN, NULL);
        if (h == INVALID_HANDLE_VALUE)
            return FALSE;
        LARGE_INTEGER size;
        BOOL ok = GetFileSizeEx(h, &size) && size.QuadPart <= SETTINGS_FILE_MAX;
        BYTE* buf = ok ? (BYTE*)malloc((size_t)size.QuadPart + 1) : NULL;
        DWORD read = 0;
        ok = buf != NULL && ReadFile(h, buf, (DWORD)size.QuadPart, &read, NULL) && read == (DWORD)size.QuadPart;
        CloseHandle(h);
        if (ok)
            *hash = SalPortableFnv1a64(buf, (int)read);
        free(buf);
        return ok;
    }

    // the configuration root of the hive holds "Save In Progress": a save of a process of this copy
    // was interrupted (it crashed) - that half-saved state is never written over the file (re-review F2)
    BOOL SaveInterruptedInHive()
    {
        HKEY root;
        if (RegOpenKeyExW(PortableStoreRoot, ToW(SalamanderConfigurationRoots[0]).c_str(), 0, KEY_READ, &root) != ERROR_SUCCESS)
            return FALSE;
        BOOL marked = RegQueryValueExW(root, L"Save In Progress", NULL, NULL, NULL, NULL) == ERROR_SUCCESS;
        RegCloseKey(root);
        return marked;
    }

    // errors after which another try cannot succeed in this session: saving stops and the user is told
    BOOL PermanentWriteError(DWORD err)
    {
        return err == ERROR_FILE_TOO_LARGE || err == ERROR_DISK_FULL || err == ERROR_HANDLE_DISK_FULL ||
               err == ERROR_WRITE_PROTECT || err == ERROR_NOT_READY || err == ERROR_DEV_NOT_EXIST ||
               err == ERROR_PATH_NOT_FOUND || err == ERROR_BAD_NETPATH;
    }

    // TRUE = the settings file holds the session's configuration now (written, already the same, or
    // nothing to save); FALSE = not saved: a transient failure (tried again after the quiet period,
    // Dirty set) or saving is off.
    // Lock order: LoadSaveToRegistryMutex (recursive, per copy: SaveConfig holds it while it rewrites
    // keys, and so does a save of another process of the copy), then PersistCS, then StoreMutex -
    // a dump never sees a half-saved configuration nor keys that vanish under its enumeration
    // (review A3). The main thread's PersistNow after SaveConfig takes them in the same order.
    // "Already the same" compares with the FILE's bytes, not with what this process wrote last: two
    // processes of a copy each see the other's writes, the last one to close wins as in the
    // installed edition, and a start that only hands over to a running window writes nothing
    // (re-review F3, F4).
    BOOL Persist()
    {
        if (!Writable || PortableStoreRoot == NULL)
            return FALSE;
        BOOL cfgLock = LoadSaveToRegistryMutex.IsInitialized(); // not yet during the first moments of a start
        if (cfgLock)
            LoadSaveToRegistryMutex.Enter();
        EnterCriticalSection(&PersistCS);
        DWORD w = StoreMutex != NULL ? WaitForSingleObject(StoreMutex, 15000) : WAIT_OBJECT_0;
        BOOL locked = w == WAIT_OBJECT_0 || w == WAIT_ABANDONED;
        InterlockedExchange(&Dirty, 0); // a change from now on dirties it again (notification)
        BOOL saved = FALSE;
        BOOL retry = FALSE;
        BOOL stop = FALSE;
        if (!locked)
            retry = TRUE; // another process of the copy holds the file - never write without the lock (re-review F9)
        else if (SaveInterruptedInHive())
        {
            TRACE_E("PortableStore: a save in this session was interrupted - the file keeps the last complete one");
            retry = TRUE;
        }
        else
        {
            LPBYTE data = NULL;
            DWORD size = 0;
            BOOL nothing = FALSE;
            if (DumpSession(&data, &size, &nothing))
            {
                unsigned __int64 hash = SalPortableFnv1a64(data, (int)size);
                unsigned __int64 onDisk = 0;
                if (FileBytesHash(&onDisk) && onDisk == hash)
                    saved = TRUE;
                else
                {
                    DWORD err = 0;
                    if (WriteSettingsFile(data, size, &err))
                        saved = TRUE;
                    else
                    {
                        // a sync client, a virus scanner or a backup tool can hold the file for a
                        // moment: try again later; a hopeless error stops saving at once (re-review F1)
                        TRACE_E("PortableStore: the settings could not be written, error " << err);
                        if (PermanentWriteError(err))
                            stop = TRUE;
                        else
                            retry = TRUE;
                    }
                }
                free(data);
            }
            else if (nothing)
                saved = TRUE; // a fresh copy before its first save: nothing to keep yet
            else
            {
                // the dump could not be made (out of memory, a key that changed under it): nothing
                // was written and the file is as it was (review A3)
                TRACE_E("PortableStore: the session could not be dumped; it is tried again");
                retry = TRUE;
            }
        }
        if (saved)
        {
            FailedPersists = 0;
            if (PendingImportToDelete) // the imported settings are in the file now (re-review 3)
            {
                DeleteFileW(PendingImportW.c_str());
                PendingImportToDelete = FALSE;
            }
        }
        else if (retry)
        {
            if (FailedPersists++ == 0)
                FirstFailureTick = GetTickCount();
            else if (GetTickCount() - FirstFailureTick >= FAIL_STOP_MS)
                stop = TRUE, retry = FALSE; // a minute of nothing but failures: the user must know
        }
        if (retry)
        {
            InterlockedExchange(&Dirty, 1);
            LastChangeTick = GetTickCount(); // the worker waits a quiet period again, never spins (re-review F7)
        }
        if (locked && StoreMutex != NULL)
            ReleaseMutex(StoreMutex);
        LeaveCriticalSection(&PersistCS);
        if (cfgLock)
            LoadSaveToRegistryMutex.Leave();
        if (stop)
        {
            InterlockedExchange(&Writable, FALSE);
            if (InterlockedCompareExchange(&NoteCannotSave, 1, 0) == 0)
                PostNote();
        }
        return saved;
    }

    unsigned __stdcall Worker(void*)
    {
        SetThreadNameInVCAndTrace("PortableStore");
        HANDLE changed = CreateEventW(NULL, FALSE, FALSE, NULL);
        if (changed == NULL)
            return 0;
        BOOL armed = RegNotifyChangeKeyValue(PortableStoreRoot, TRUE, REG_NOTIFY_CHANGE_NAME | REG_NOTIFY_CHANGE_LAST_SET,
                                             changed, TRUE) == ERROR_SUCCESS;
        if (!armed)
            TRACE_E("PortableStore: change notification could not be armed");
        for (;;)
        {
            DWORD timeout = INFINITE;
            if (Dirty)
            {
                DWORD since = GetTickCount() - LastChangeTick;
                timeout = since >= PERSIST_QUIET_MS ? 0 : PERSIST_QUIET_MS - since;
            }
            HANDLE hs[2] = {StopEvent, changed};
            DWORD r = WaitForMultipleObjects(armed ? 2 : 1, hs, FALSE, timeout);
            if (r == WAIT_OBJECT_0)
                break;
            if (r == WAIT_OBJECT_0 + 1)
            {
                // re-arm first: a change during the dump below is not lost
                armed = RegNotifyChangeKeyValue(PortableStoreRoot, TRUE, REG_NOTIFY_CHANGE_NAME | REG_NOTIFY_CHANGE_LAST_SET,
                                                changed, TRUE) == ERROR_SUCCESS;
                InterlockedExchange(&Dirty, 1);
                LastChangeTick = GetTickCount();
                continue;
            }
            if (r == WAIT_TIMEOUT && Dirty && Writable)
                Persist();
            else if (r == WAIT_TIMEOUT)
                InterlockedExchange(&Dirty, 0);
            else if (r == WAIT_FAILED)
                break;
        }
        CloseHandle(changed);
        return 0;
    }

    BOOL ProbeWritable()
    {
        if (FileExists(SettingsFileW) && (GetFileAttributesW(SettingsFileW.c_str()) & FILE_ATTRIBUTE_READONLY))
            return FALSE; // the user froze the settings
        std::wstring dir = FileExists(SettingsDirW) ? SettingsDirW : DirForApi(ProgramDirW);
        WCHAR name[64];
        swprintf_s(name, L".tc-write-probe-%lu", GetCurrentProcessId());
        std::wstring probe = dir;
        if (!probe.empty() && probe.back() != L'\\')
            probe += L"\\";
        probe += name;
        HANDLE h = CreateFileW(probe.c_str(), GENERIC_WRITE, 0, NULL, CREATE_NEW,
                               FILE_ATTRIBUTE_TEMPORARY | FILE_ATTRIBUTE_HIDDEN | FILE_FLAG_DELETE_ON_CLOSE, NULL);
        if (h == INVALID_HANDLE_VALUE)
            return FALSE;
        CloseHandle(h);
        return TRUE;
    }

    // leftovers of an interrupted write (cfgXXXX.tmp / bakXXXX.tmp) - removed only when the settings
    // file itself is readable: then none of them can hold the only copy of anything
    void RemoveWriteLeftovers()
    {
        // also the temporary copy ReplaceFileW makes of the replaced file (<name>~RF<hex>.TMP) - a
        // write killed inside the replace leaves it (measured by the kill scenario of 428)
        for (const WCHAR* mask : {L"\\cfg????.tmp", L"\\bak????.tmp", L"\\tandemcommander.reg*~RF*.TMP"})
        {
            WIN32_FIND_DATAW fd;
            HANDLE f = FindFirstFileW((SettingsDirW + mask).c_str(), &fd);
            if (f == INVALID_HANDLE_VALUE)
                continue;
            do
            {
                if (!(fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY))
                    DeleteFileW((SettingsDirW + L"\\" + fd.cFileName).c_str());
            } while (FindNextFileW(f, &fd));
            FindClose(f);
        }
    }

    std::wstring DamagedName(const std::wstring& path)
    {
        return path + ToW(DamagedSuffix.c_str());
    }

    void MakeDamagedSuffix()
    {
        SYSTEMTIME st;
        GetSystemTime(&st);
        char b[64];
        sprintf_s(b, ".damaged-%04u%02u%02u-%02u%02u%02u", st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond);
        DamagedSuffix = b;
    }

    BOOL Seed(CSalamanderRegistryExAbstract* memReg)
    {
        CSalamanderRegistryExAbstract* sysReg = REG_SysRegistryFactory();
        if (sysReg == NULL)
            return FALSE;
        eRPE_ERROR err = CopyBranchTransform(CfgKeyName.c_str(), memReg, sysReg, PathTransform, NULL);
        sysReg->Release();
        // no RegFlushKey: the session hive is a working copy (the settings file is what lasts), and
        // a process that joins sees the loaded hive itself, not its file - SC-009 measured the
        // synchronous flush in the start-up time
        if (err != RPE_OK)
            TRACE_E("PortableStore: seeding the session hive failed (" << (int)err << ")");
        return err == RPE_OK;
    }

    // the mark of a session that must not write the settings file (review A2): a value at the root of
    // the shared hive, outside the configuration that is dumped - it cannot fail to be written while
    // the hive can (a mark file could, re-review F10)
    const WCHAR* const READONLY_MARK = L"TC Session Saves Nothing";

    BOOL SessionMarkedReadOnly()
    {
        return RegQueryValueExW(PortableStoreRoot, READONLY_MARK, NULL, NULL, NULL, NULL) == ERROR_SUCCESS;
    }

    void ReleaseHeldStartLock()
    {
        if (HeldStartLock != NULL)
        {
            ReleaseMutex(HeldStartLock);
            CloseHandle(HeldStartLock);
            HeldStartLock = NULL;
        }
    }

    void ShowEnglishError(const WCHAR* text)
    {
        // the language module is not loaded yet (it is chosen by the configuration)
        MessageBoxW(NULL, text, L"Tandem Commander (portable)", MB_OK | MB_ICONERROR);
    }

    BOOL LoadHive(const std::wstring& path)
    {
        LONG r = RegLoadAppKeyW(path.c_str(), &PortableStoreRoot, KEY_ALL_ACCESS, 0, 0);
        if (r != ERROR_SUCCESS)
        {
            PortableStoreRoot = NULL;
            SetLastError(r);
            return FALSE;
        }
        return TRUE;
    }
} // namespace

BOOL PortableStore_Open()
{
    CALL_STACK_MESSAGE1("PortableStore_Open()");
    CfgKeyName = std::string("HKEY_CURRENT_USER\\") + SalamanderConfigurationRoots[0];
    if (!PersistCSReady)
    {
        InitializeCriticalSection(&PersistCS);
        PersistCSReady = TRUE;
    }
    if (!GetProgramDir())
    {
        ShowEnglishError(L"The portable edition cannot determine its own folder.");
        return FALSE;
    }
    SettingsDirW = ProgramDirW + L"\\settings"; // "E:" (a drive root) gives "E:\settings"
    SettingsDirU8 = ToU8(SettingsDirW.c_str());
    SettingsFileW = SettingsDirW + L"\\tandemcommander.reg";
    BakFileW = SettingsFileW + L".bak";
    PendingImportW = SettingsDirW + L"\\import.reg";
    ComputeScope();

    WCHAR tempBuf[MAX_PATH + 2];
    DWORD tl = GetTempPathW(_countof(tempBuf), tempBuf);
    if (tl == 0 || tl >= _countof(tempBuf))
    {
        ShowEnglishError(L"The portable edition needs the temporary folder (%TEMP%), which cannot be used. "
                         L"The program cannot start.");
        return FALSE;
    }
    std::wstring tempDir(tempBuf, tl);
    if (tempDir.back() != L'\\')
        tempDir += L"\\";
    std::wstring ownName = ToW(SalPortableSessionDirName(Scope).c_str());
    SessionDirW = tempDir + ownName;
    SessionHiveW = SessionDirW + L"\\session.dat";

    HANDLE startLock = CreateMutexW(NULL, FALSE, MutexName(Scope, "Start").c_str());
    DWORD w = startLock != NULL ? WaitForSingleObject(startLock, 60000) : WAIT_FAILED;
    if (w != WAIT_OBJECT_0 && w != WAIT_ABANDONED)
    {
        if (startLock != NULL)
            CloseHandle(startLock);
        ShowEnglishError(L"Another start of this portable copy does not finish. Try again in a moment.");
        return FALSE;
    }
    StoreMutex = CreateMutexW(NULL, FALSE, MutexName(Scope, "Store").c_str());

    CleanStaleSessions(tempDir, ownName);

    BOOL ok = FALSE;
    for (int attempt = 0; attempt < 2 && !ok; attempt++)
    {
        Joined = FALSE; // decided anew by each attempt (re-review 3)
        CreateDirectoryW(SessionDirW.c_str(), NULL);
        BOOL held = FALSE;
        if (!DeleteFileW(SessionHiveW.c_str()))
        {
            DWORD e = GetLastError();
            held = e == ERROR_SHARING_VIOLATION;
        }
        if (held)
        {
            TRACE_I("PortableStore: joining the session of a running process of this copy");
            Joined = TRUE;
            ok = LoadHive(SessionHiveW);
            if (ok)
            {
                // a session that started without reading the settings file (it could not be read)
                // runs on defaults and must never write over that file - the process that started it
                // left a mark in the session folder, and every process that joins keeps to it (review A2)
                BOOL writable = !SessionMarkedReadOnly() && ProbeWritable();
                InterlockedExchange(&Writable, writable);
                if (!writable)
                    InterlockedExchange(&NoteCannotSave, 1);
            }
            continue;
        }
        DeleteFileW((SessionHiveW + L".LOG1").c_str());
        DeleteFileW((SessionHiveW + L".LOG2").c_str());

        CSalamanderRegistryExAbstract* fileReg = NULL;
        CSalamanderRegistryExAbstract* bakReg = NULL;
        CSalPortableFileState fileState = LoadSettingsFile(SettingsFileW, &fileReg);
        CSalPortableFileState bakState = fileState == spfsOk ? spfsAbsent : LoadSettingsFile(BakFileW, &bakReg);
        if (fileState == spfsOk && FileExists(BakFileW))
            bakState = spfsOk; // not read: the main file is the one that counts
        CSalPortableStartAction action = SalPortableStartDecision(spssFree, fileState, bakState);

        if (!LoadHive(SessionHiveW))
        {
            DWORD e = GetLastError();
            if (fileReg != NULL)
                fileReg->Release();
            if (bakReg != NULL)
                bakReg->Release();
            TRACE_E("PortableStore: the session hive cannot be created, error " << e);
            continue; // a concurrent clean-up of a starting copy can remove the folder once
        }
        BOOL writable = ProbeWritable();
        switch (action)
        {
        case spsaSeedFile:
            ok = Seed(fileReg);
            if (ok)
                RemoveWriteLeftovers();
            break;

        case spsaSeedBak:
            ok = Seed(bakReg);
            if (ok)
            {
                MakeDamagedSuffix();
                // keep the damaged file aside, never overwrite it: when it cannot be moved (a
                // locked file, a read-only folder) this session saves nothing (review A9) and the
                // user is told that, not that it was kept aside; a main file that is simply missing
                // (deleted by hand) is not reported as unreadable (re-review F11)
                if (FileExists(SettingsFileW))
                {
                    if (MoveFileW(SettingsFileW.c_str(), DamagedName(SettingsFileW).c_str()))
                        NoteRestoredBak = TRUE;
                    else
                        writable = FALSE;
                }
            }
            break;

        case spsaDefaultsDamaged:
            MakeDamagedSuffix();
            {
                BOOL moved = FALSE, failed = FALSE;
                for (const std::wstring* f : {&SettingsFileW, &BakFileW})
                {
                    if (!FileExists(*f))
                        continue;
                    if (MoveFileW(f->c_str(), DamagedName(*f).c_str()))
                        moved = TRUE;
                    else
                        failed = TRUE; // never overwrite a damaged file that could not be kept aside (review A9)
                }
                if (failed)
                    writable = FALSE;
                // "kept with names ending ..." exactly when something was kept so (re-review F11, 3)
                NoteDamaged = moved;
            }
            ok = TRUE;
            break;

        case spsaReadOnly:
            writable = FALSE; // a file we could not read is never replaced
            ok = TRUE;
            break;

        default: // spsaDefaults (and spsaJoin, not reachable here)
            ok = TRUE;
            break;
        }
        if (fileReg != NULL)
            fileReg->Release();
        if (bakReg != NULL)
            bakReg->Release();
        if (!ok)
        {
            RegCloseKey(PortableStoreRoot);
            PortableStoreRoot = NULL;
            break;
        }
        InterlockedExchange(&Writable, writable);
        if (!writable)
            InterlockedExchange(&NoteCannotSave, 1);
        if (action == spsaReadOnly || !writable) // processes that join this session keep to it (review A2)
        {
            DWORD one = 1;
            if (RegSetValueExW(PortableStoreRoot, READONLY_MARK, 0, REG_DWORD, (const BYTE*)&one, sizeof(one)) != ERROR_SUCCESS)
            {
                // without the mark a joining process could save this session over the file: no
                // session then (the start fails visibly, the file stays as it is)
                RegCloseKey(PortableStoreRoot);
                PortableStoreRoot = NULL;
                ok = FALSE;
                break;
            }
        }
    }
    // a pending Import Configuration is applied later in the start (it needs the language module);
    // until then no other process of this copy may join this session and later write its
    // pre-import view back (review A4) - the start lock is kept until ApplyPendingImport
    if (ok && PortableStoreRoot != NULL && !Joined && FileExists(PendingImportW))
        HeldStartLock = startLock;
    else
    {
        ReleaseMutex(startLock);
        CloseHandle(startLock);
    }
    if (!ok || PortableStoreRoot == NULL)
    {
        ShowEnglishError(L"The portable edition cannot prepare its settings in the temporary folder (%TEMP%). "
                         L"The program cannot start.");
        return FALSE;
    }

    StopEvent = CreateEventW(NULL, TRUE, FALSE, NULL);
    if (StopEvent != NULL)
        WorkerThread = (HANDLE)_beginthreadex(NULL, 0, Worker, NULL, 0, NULL);
    TRACE_I("PortableStore: open, scope " << Scope.c_str() << (Writable ? "" : ", NOT writable"));
    return TRUE;
}

void PortableStore_Close()
{
    CALL_STACK_MESSAGE1("PortableStore_Close()");
    ReleaseHeldStartLock();
    if (PortableStoreRoot == NULL)
        return;
    if (WorkerThread != NULL)
    {
        SetEvent(StopEvent);
        // a persist can wait for StoreMutex and then write to a slow stick; if the worker is still
        // busy after a minute, nothing it uses is closed under it (review A6) - the process ends
        // anyway, and the next start of the copy cleans the session folder
        if (WaitForSingleObject(WorkerThread, 60000) != WAIT_OBJECT_0)
        {
            // it must not run on while the process's static objects are destroyed after this
            // (re-review F5); a write it was in cannot damage the file (a temporary file, replaced
            // only when complete), a mutex it held is abandoned and the next owner gets it; PersistCS
            // may be held by it, so this process saves nothing more here
            // stopping only that thread could leave it inside the heap or a registry call and hang the
            // teardown that follows (re-review 3): the process ends here, with nothing more run
            TRACE_E("PortableStore: the worker did not end; the process ends now, the session as it is");
            TerminateProcess(GetCurrentProcess(), 1);
            return;
        }
        CloseHandle(WorkerThread);
        WorkerThread = NULL;
    }
    if (StopEvent != NULL)
    {
        CloseHandle(StopEvent);
        StopEvent = NULL;
    }
    // writes only when the file differs from the session; a file held for a moment by another program
    // is tried again a few times before the program ends (re-review F1)
    BOOL savedAtExit = !Writable; // a session that saves nothing has nothing to report here (told at start)
    for (int attempt = 0; attempt < 4 && Writable; attempt++)
    {
        if (Persist())
        {
            savedAtExit = TRUE;
            break;
        }
        Sleep(500);
    }
    if (!savedAtExit)
    {
        std::wstring text = L"Tandem Commander could not save its settings in this folder:\n" + SettingsDirW +
                            L"\n\nThe changes made since the last successful save are lost. The settings file may be "
                            L"held by another program (a sync client, a virus scanner) or the folder is no longer available.";
        MessageBoxW(NULL, text.c_str(), L"Tandem Commander (portable)", MB_OK | MB_ICONWARNING | MB_SETFOREGROUND);
    }
    // the unload and the removal under the copy's start lock: a start that sees the hive held and
    // decides to join must find it still loaded, never an empty new one created where this process
    // just deleted it (review A1); a start that comes after finds no hive and seeds from the file
    HANDLE startLock = CreateMutexW(NULL, FALSE, MutexName(Scope, "Start").c_str());
    DWORD sw = startLock != NULL ? WaitForSingleObject(startLock, 60000) : WAIT_FAILED;
    BOOL startLocked = sw == WAIT_OBJECT_0 || sw == WAIT_ABANDONED;
    RegCloseKey(PortableStoreRoot);
    PortableStoreRoot = NULL;
    // the last process of this copy removes the session folder (its hive is unloaded with the
    // last handle - measured: deletable at once)
    for (int i = 0; i < 10; i++)
    {
        if (DeleteFileW(SessionHiveW.c_str()) || GetLastError() == ERROR_FILE_NOT_FOUND)
        {
            DeleteFileW((SessionHiveW + L".LOG1").c_str());
            DeleteFileW((SessionHiveW + L".LOG2").c_str());
            RemoveTree(SessionDirW);
            break;
        }
        if (GetLastError() != ERROR_SHARING_VIOLATION)
            break;
        Sleep(50); // another process of this copy runs (or a key is still open here): it cleans up
    }
    if (startLock != NULL)
    {
        if (startLocked)
            ReleaseMutex(startLock);
        CloseHandle(startLock);
    }
    if (StoreMutex != NULL)
    {
        CloseHandle(StoreMutex);
        StoreMutex = NULL;
    }
}

void PortableStore_PersistNow()
{
    if (PortableStoreRoot != NULL && Writable)
        Persist();
}

BOOL PortableStore_IsWritable()
{
    return Writable != FALSE;
}

const WCHAR* PortableStore_SettingsDirW()
{
    return SettingsDirW.c_str();
}

const char* PortableStore_SettingsDirU8()
{
    return SettingsDirU8.c_str();
}

const WCHAR* PortableStore_SessionDirW()
{
    return SessionDirW.c_str();
}

void ShowFileError(HWND hParent, int errTextID, const char* fileName, DWORD err); // salamdr2.cpp

void PortableStore_ApplyPendingImport()
{
    // a session another process of this copy runs on would overwrite the import at its exit (the
    // installed edition's Registry Editor import asks to close every window first): wait for a start
    // that is alone
    // a session that saves nothing keeps the pending file for a start that can (re-review F6)
    if (Joined || !Writable || GetFileAttributesW(PendingImportW.c_str()) == INVALID_FILE_ATTRIBUTES)
    {
        ReleaseHeldStartLock();
        return;
    }
    char* fileU8 = SalWToU8Alloc(PendingImportW.c_str());
    if (fileU8 != NULL)
    {
        BOOL skipped = FALSE;
        TRACE_I("PortableStore: importing the pending configuration file");
        if (ImportConfiguration(NULL, fileU8, TRUE, FALSE, &skipped)) // a refusal shows its message
        {
            // the settings file of another portable copy names its folder $(PortableDir): the
            // imported values are read back and written again through the same expansion the start
            // uses (Seed), so this session sees this copy's folder in them
            CSalamanderRegistryExAbstract* sysReg = REG_SysRegistryFactory();
            CSalamanderRegistryExAbstract* memReg = REG_MemRegistryFactory();
            if (sysReg != NULL && memReg != NULL && CopyBranch(CfgKeyName.c_str(), sysReg, memReg) == RPE_OK)
                Seed(memReg);
            if (sysReg != NULL)
                sysReg->Release();
            if (memReg != NULL)
                memReg->Release();
        }
        free(fileU8);
    }
    // the imported settings are in the file before the pending copy goes (a crash later in the
    // start must not lose the import - review A4); once, also after a refusal (the user's own file
    // is where it was; this is our copy of it)
    InterlockedExchange(&Dirty, 1);
    EnterCriticalSection(&PersistCS);
    PendingImportToDelete = TRUE; // deleted by the first persist that saves (now, or a later one - re-review 3)
    LeaveCriticalSection(&PersistCS);
    Persist();
    ReleaseHeldStartLock();
}

// Options > Import Configuration: the file is checked now and imported at the next start, before
// the configuration is loaded - the same moment the installed edition's start-up import uses, and
// one that the running program's save at exit cannot overwrite
void PortableStore_ImportConfigurationCommand(HWND parent)
{
    if (!PortableStore_IsWritable())
    {
        CSalHeapString text;
        text.Printf(LoadStrU8(IDS_PORTABLE_CANNOTSAVE), SettingsDirU8.c_str());
        SalMessageBox(parent, text.Size() > 0 ? text.Get() : SettingsDirU8.c_str(), LoadStr(IDS_ERRORTITLE),
                      MB_OK | MB_ICONEXCLAMATION);
        return;
    }
    WCHAR fileW[2 * MAX_PATH];
    fileW[0] = 0;
    WCHAR filterW[500];
    lstrcpynW(filterW, LoadStrW(IDS_REGFILTER), _countof(filterW));
    for (WCHAR* f = filterW; *f != 0; f++) // a double-null-terminated list
        if (*f == L'|')
            *f = 0;
    OPENFILENAMEW ofn;
    memset(&ofn, 0, sizeof(ofn));
    ofn.lStructSize = sizeof(ofn);
    ofn.hwndOwner = parent;
    ofn.lpstrFilter = filterW;
    ofn.nFilterIndex = 1;
    ofn.lpstrFile = fileW;
    ofn.nMaxFile = _countof(fileW);
    ofn.lpstrInitialDir = SettingsDirW.c_str();
    ofn.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_HIDEREADONLY;
    ofn.lpstrDefExt = L"reg";
    if (!GetOpenFileNameW(&ofn))
        return;
    char* fileU8 = SalWToU8Alloc(fileW);
    if (fileU8 == NULL)
        return;
    BOOL skipped = FALSE;
    if (ImportConfiguration(parent, fileU8, FALSE, FALSE, &skipped, TRUE /* check only */))
    {
        // our copy of the file: written beside the target and renamed, so the next start never
        // sees half of it; the user's file stays where it is
        CreateDirectoryW(SettingsDirW.c_str(), NULL);
        std::wstring part = PendingImportW + L".part";
        BOOL ok = CopyFileW(fileW, part.c_str(), FALSE) &&
                  MoveFileExW(part.c_str(), PendingImportW.c_str(), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH);
        DWORD err = ok ? 0 : GetLastError();
        if (!ok)
        {
            DeleteFileW(part.c_str());
            ShowFileError(parent, IDS_IMPORTCFG_OPENERR, fileU8, err);
        }
        else
        {
            CSalHeapString text;
            text.Printf(LoadStrU8(IDS_PORTABLE_IMPORTPENDING), fileU8);
            if (SalMessageBox(parent, text.Size() > 0 ? text.Get() : fileU8, LoadStr(IDS_QUESTION),
                              MB_YESNO | MB_ICONQUESTION) == IDYES)
                PostMessage(parent, WM_COMMAND, CM_EXIT, 0);
        }
    }
    free(fileU8);
}

const char* PortableStore_ScopeSuffix()
{
    return ScopeSuffix.c_str();
}

namespace
{
    // the scoped names given out so far (stable addresses: a list never moves its elements)
    std::list<std::string> ScopedNames;
    std::list<std::wstring> ScopedNamesW;
    CRITICAL_SECTION ScopedNamesCS;
    INIT_ONCE ScopedNamesOnce = INIT_ONCE_STATIC_INIT;

    BOOL CALLBACK InitScopedNamesCS(PINIT_ONCE, PVOID, PVOID*)
    {
        InitializeCriticalSection(&ScopedNamesCS);
        return TRUE;
    }
} // namespace

const char* PortableScopedName(const char* base)
{
    InitOnceExecuteOnce(&ScopedNamesOnce, InitScopedNamesCS, NULL, NULL);
    EnterCriticalSection(&ScopedNamesCS);
    std::string name = std::string(base) + ScopeSuffix;
    const char* ret = NULL;
    for (const std::string& n : ScopedNames)
        if (n == name)
            ret = n.c_str();
    if (ret == NULL)
    {
        ScopedNames.push_back(name);
        ret = ScopedNames.back().c_str();
    }
    LeaveCriticalSection(&ScopedNamesCS);
    return ret;
}

const WCHAR* PortableScopedNameW(const WCHAR* base)
{
    InitOnceExecuteOnce(&ScopedNamesOnce, InitScopedNamesCS, NULL, NULL);
    EnterCriticalSection(&ScopedNamesCS);
    std::wstring name = std::wstring(base) + ToW(ScopeSuffix.c_str());
    const WCHAR* ret = NULL;
    for (const std::wstring& n : ScopedNamesW)
        if (n == name)
            ret = n.c_str();
    if (ret == NULL)
    {
        ScopedNamesW.push_back(name);
        ret = ScopedNamesW.back().c_str();
    }
    LeaveCriticalSection(&ScopedNamesCS);
    return ret;
}

void PortableStore_AttachMainWindow(HWND mainWnd)
{
    NoteWnd = mainWnd;
#ifdef _DEBUG
    // test seam (Debug builds only, probe/pwdnote_probe.py): the password note requested as a stored
    // password would request it - the trigger itself lives in plug-in dialogs (FTP, SFTP) that a
    // probe cannot drive on the hidden desktop
    if (GetEnvironmentVariableW(L"TC_PORTABLE_TEST_PWDNOTE", NULL, 0) > 0)
        InterlockedCompareExchange(&NotePassword, 1, 0);
#endif
    if (NoteRestoredBak || NoteDamaged || NoteCannotSave == 1 || NotePassword == 1)
        PostNote();
}

void PortableStore_RequestPasswordNote()
{
    if (InterlockedCompareExchange(&NotePassword, 1, 0) == 0)
        PostNote(); // no main window yet: AttachMainWindow posts it
}

void PortableStore_ShowPendingNotes(HWND parent)
{
    CALL_STACK_MESSAGE1("PortableStore_ShowPendingNotes()");
    if (NoteDamaged)
    {
        NoteDamaged = FALSE;
        CSalHeapString text;
        text.Printf(LoadStrU8(IDS_PORTABLE_DAMAGED), SettingsDirU8.c_str(), DamagedSuffix.c_str());
        SalMessageBox(parent, text.Size() > 0 ? text.Get() : SettingsDirU8.c_str(), SALAMANDER_TEXT_VERSION,
                      MB_OK | MB_ICONWARNING);
    }
    if (NoteRestoredBak)
    {
        NoteRestoredBak = FALSE;
        CSalHeapString text;
        text.Printf(LoadStrU8(IDS_PORTABLE_RESTOREDBAK), SettingsDirU8.c_str(), DamagedSuffix.c_str());
        SalMessageBox(parent, text.Size() > 0 ? text.Get() : SettingsDirU8.c_str(), SALAMANDER_TEXT_VERSION,
                      MB_OK | MB_ICONWARNING);
    }
    if (InterlockedCompareExchange(&NoteCannotSave, 2, 1) == 1)
    {
        CSalHeapString text;
        text.Printf(LoadStrU8(IDS_PORTABLE_CANNOTSAVE), SettingsDirU8.c_str());
        SalMessageBox(parent, text.Size() > 0 ? text.Get() : SettingsDirU8.c_str(), SALAMANDER_TEXT_VERSION,
                      MB_OK | MB_ICONWARNING);
    }
    if (InterlockedCompareExchange(&NotePassword, 2, 1) == 1)
        PortableShowPasswordNote(parent);
}

#ifdef _DEBUG

BOOL PortableStore_RunSelfTest(int* exitCode)
{
    int argc = 0;
    LPWSTR* argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    if (argv == NULL)
        return FALSE;
    BOOL asked = argc >= 2 && wcscmp(argv[1], L"--portabletest-roundtrip") == 0;
    if (!asked)
    {
        LocalFree(argv);
        return FALSE;
    }
    *exitCode = 10;
    if (argc == 6)
    {
        CfgKeyName = std::string("HKEY_CURRENT_USER\\") + SalamanderConfigurationRoots[0];
        if (!PersistCSReady)
        {
            InitializeCriticalSection(&PersistCS);
            PersistCSReady = TRUE;
        }
        ProgramDirW = argv[5];
        ProgramDirU8 = ToU8(argv[5]);
        // 1. dump the source hive
        *exitCode = 11;
        if (LoadHive(argv[2]))
        {
            LPBYTE data = NULL;
            DWORD size = 0;
            BOOL nothing = FALSE;
            BOOL dumped = DumpSession(&data, &size, &nothing);
            RegCloseKey(PortableStoreRoot);
            PortableStoreRoot = NULL;
            *exitCode = 12;
            if (dumped)
            {
                HANDLE h = CreateFileW(argv[3], GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, 0, NULL);
                DWORD written = 0;
                BOOL ok = h != INVALID_HANDLE_VALUE && WriteFile(h, data, size, &written, NULL) && written == size;
                if (h != INVALID_HANDLE_VALUE)
                    CloseHandle(h);
                free(data);
                // 2. seed the destination hive from the dump
                *exitCode = 13;
                CSalamanderRegistryExAbstract* reg = NULL;
                if (ok && LoadSettingsFile(argv[3], &reg) == spfsOk)
                {
                    *exitCode = 14;
                    if (LoadHive(argv[4]))
                    {
                        if (Seed(reg))
                            *exitCode = 0;
                        RegCloseKey(PortableStoreRoot);
                        PortableStoreRoot = NULL;
                    }
                    reg->Release();
                }
            }
        }
    }
    LocalFree(argv);
    return TRUE;
}

#endif // _DEBUG

#endif // TC_PORTABLE
