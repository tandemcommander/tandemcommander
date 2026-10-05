// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include "undelete.rh"
#include "undelete.rh2"
#include "lang\lang.rh"

#include "miscstr.h"
#include "os.h"

#include "miscstr.h"
#include "volume.h"
#include "snapshot.h"
#include "dialogs.h"
#include "undelete.h"
#include "restore.h"

#include "../../common/salsamefile.h" // feature 115: a folder's identity (FileIdInfo 128-bit, usable ids only)

#define COPY_BUFFER_SIZE (256 * 1024)

// ****************************************************************************
//
// RestoreEncryptedFiles
//

char* GetSCFData(FILETIME* lastWrite, CQuadWord& size);

static CRestoreProgressDlg* Progress;
static HWND hProgressWnd;
static QWORD FileProgress, FileTotal;
static QWORD TotalProgress, GrandTotal;
static DWORD SrcSilentMask, DstSilentMask, DirSilentMask;
static BOOL SkipAllWalkErrors; // feature 115: "Skip all" of the walk's own errors
static const char* TargetRootPath; // feature 115: the target folder of the restore

static void UpdateRestoreProgress()
{
    CALL_STACK_MESSAGE1("UpdateRestoreProgress()");
    if (FileTotal)
        Progress->SetFileProgress((DWORD)(FileProgress * 1000 / FileTotal));
    if (GrandTotal)
        Progress->SetTotalProgress((DWORD)(TotalProgress * 1000 / GrandTotal));
}

// ****************************************************************************
//
// The walk (feature 115)
//
// The source and target paths live in two heap buffers of SAL_MAX_PATH_UTF8 bytes; a level
// appends "\name" and cuts it off again. The tree is walked without recursion (a heap stack of
// open searches), so its depth is bounded by the file system, not by the thread's stack.
//
// Before: per-level stack buffers of 260 / 520 bytes and the results of SalPathAppend ignored -
// a path that did not fit stayed the PARENT's path, so the walk listed the parent again (the
// same folder again and again: a stack overflow, first in GetDirSize at 259 bytes) and restored
// the parent's files into the target folder of the level; a source panel path that did not fit
// (GetPanelPath unchecked) left "" - the selected names were then opened relative to the
// current directory. Now a name that does not fit, a folder that cannot be listed and a folder
// the walk is already in (a directory link back to an ancestor, or the target folder inside the
// selection) are reported - Skip / Skip all / Cancel with the system's text - and never entered.

class CWalkPath
{
public:
    CWalkPath() : Len(0) {}
    BOOL IsGood() { return Buf.Get() != NULL; }
    char* Get() { return Buf.Get(); }
    int Size() const { return Buf.Size(); }
    int GetLen() const { return Len; }

    // the start; FALSE when there is no buffer or the path does not fit
    BOOL Set(const char* path)
    {
        size_t l = strlen(path);
        if (Buf.Get() == NULL || l + 3 >= (size_t)Buf.Size())
            return FALSE;
        memcpy(Buf.Get(), path, l + 1);
        Len = (int)l;
        return TRUE;
    }
    // takes the length of a path written into Get() by someone else; FALSE when it leaves no room
    BOOL Adopt()
    {
        if (Buf.Get() == NULL)
            return FALSE;
        Len = (int)strlen(Buf.Get());
        return Len + 3 < Buf.Size();
    }
    // appends '\' (when needed) and 'name'; FALSE (the path unchanged) when it does not fit -
    // room for "\*" is always kept
    BOOL Append(const char* name)
    {
        char* b = Buf.Get();
        if (b == NULL)
            return FALSE;
        size_t n = strlen(name);
        int sep = (Len > 0 && b[Len - 1] != '\\') ? 1 : 0;
        if ((size_t)Len + sep + n + 3 >= (size_t)Buf.Size())
            return FALSE;
        if (sep)
            b[Len++] = '\\';
        memcpy(b + Len, name, n + 1);
        Len += (int)n;
        return TRUE;
    }
    void Cut(int len)
    {
        Len = len;
        Buf.Get()[len] = 0;
    }

private:
    CSalMaxPathBuffer Buf;
    int Len;
};

// identity of a directory (the one a path or link leads to). Review SF1 of 115: two signals, either
// one proves "the same folder", neither guesses:
//   - the file system's id (salsamefile.h: the 128-bit FileIdInfo id where the file system has
//     one - ReFS 64-bit ids are not unique -, else volume serial + 64-bit index; an id of all
//     zeros or all ones - WebDAV, some NAS redirectors - is NOT an identity; on FAT / exFAT an
//     equal id also needs equal metadata, as in 107's SalDirIsSame);
//   - the normalised final path of the opened folder (GetFinalPathNameByHandleW, links resolved):
//     equal final paths are one folder; kept as a 64-bit hash of its exact UTF-16 units + length.
// A folder whose identity cannot be read at all never matches: no cycle is claimed - the walk is
// then bounded only by the length of a path the file system accepts (every level beyond it is
// reported).
struct CDirId
{
    CDirId() : Known(FALSE), HasFinal(FALSE), FinalLen(0), FinalHash(0) { SalFileIdentityClear(&Ident); }

    BOOL Known; // the folder could be opened
    CSalFileIdentity Ident;
    BOOL HasFinal;
    DWORD FinalLen;
    ULONGLONG FinalHash;
};

static BOOL SameFolder(const CDirId& a, const CDirId& b)
{
    if (!a.Known || !b.Known)
        return FALSE;
    if (a.HasFinal && b.HasFinal && a.FinalLen == b.FinalLen && a.FinalHash == b.FinalHash)
        return TRUE;
    if (SalFileIdMatch(a.Ident, b.Ident) != simEqual)
        return FALSE; // different, or no usable id on one side: no claim
    if (a.Ident.WeakIds || b.Ident.WeakIds) // FAT / exFAT: the id follows the directory entry
        return !(a.HasFinal && b.HasFinal) && SalFileMetaEqual(a.Ident, b.Ident);
    return TRUE;
}

static void GetDirId(const char* path, CDirId* id)
{
    *id = CDirId();
    WCHAR* pathW = SplU8ToWExtAlloc(path);
    if (pathW == NULL)
        return;
    HANDLE h = CreateFileW(pathW, FILE_READ_ATTRIBUTES, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL,
                           OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, NULL);
    if (h != INVALID_HANDLE_VALUE)
    {
        id->Known = TRUE;
        if (SalFileIdentityFromHandle(h, &id->Ident))
            SalFileIdentityVolumeTraits(h, pathW, &id->Ident); // WeakIds (FAT / exFAT)
        DWORD need = GetFinalPathNameByHandleW(h, NULL, 0, FILE_NAME_NORMALIZED | VOLUME_NAME_DOS);
        if (need > 0 && need < 0x10000)
        {
            WCHAR* fin = (WCHAR*)malloc((need + 1) * sizeof(WCHAR));
            if (fin != NULL)
            {
                DWORD n = GetFinalPathNameByHandleW(h, fin, need + 1, FILE_NAME_NORMALIZED | VOLUME_NAME_DOS);
                if (n > 0 && n <= need)
                {
                    ULONGLONG hash = 14695981039346656037ULL; // FNV-1a over the UTF-16 units
                    for (DWORD i = 0; i < n; i++)
                    {
                        hash ^= (ULONGLONG)fin[i];
                        hash *= 1099511628211ULL;
                    }
                    id->HasFinal = TRUE;
                    id->FinalLen = n;
                    id->FinalHash = hash;
                }
                free(fin);
            }
        }
        CloseHandle(h);
    }
    free(pathW);
}

// one open folder of the walk
struct CWalkLevel
{
    HANDLE Find;           // INVALID_HANDLE_VALUE: nothing (more) to list
    BOOL First;            // 'Data' holds the first entry (from FindFirstFileW)
    int SrcLen, DstLen;    // the parent's path lengths - cut back to them when the folder is left
    CDirId Id;             // the source folder
    CDirId DstId;          // the target folder (restore only)
    WIN32_FIND_DATAW Data; // the current entry
};

class CWalkStack
{
public:
    CWalkStack() : Levels(NULL), Count(0), Capacity(0) {}
    ~CWalkStack()
    {
        while (Count > 0)
        {
            if (Levels[Count - 1].Find != INVALID_HANDLE_VALUE)
                HANDLES(FindClose(Levels[Count - 1].Find));
            Count--;
        }
        free(Levels);
    }
    // a new level (zeroed except Find = INVALID_HANDLE_VALUE); NULL when memory is low
    CWalkLevel* Push()
    {
        if (Count == Capacity)
        {
            int cap = Capacity == 0 ? 16 : 2 * Capacity;
            CWalkLevel* l = (CWalkLevel*)realloc(Levels, cap * sizeof(CWalkLevel));
            if (l == NULL)
                return NULL;
            Levels = l;
            Capacity = cap;
        }
        CWalkLevel* l = &Levels[Count++];
        memset(l, 0, sizeof(*l));
        l->Find = INVALID_HANDLE_VALUE;
        return l;
    }
    void Pop()
    {
        if (Count > 0)
        {
            if (Levels[Count - 1].Find != INVALID_HANDLE_VALUE)
                HANDLES(FindClose(Levels[Count - 1].Find));
            Count--;
        }
    }
    CWalkLevel* Top() { return Count > 0 ? &Levels[Count - 1] : NULL; }
    int GetCount() const { return Count; }
    // is the folder 'id' one the walk is already in, or one it has created in the target?
    BOOL Contains(const CDirId& id) const
    {
        for (int i = 0; i < Count; i++)
            if (SameFolder(Levels[i].Id, id) || SameFolder(Levels[i].DstId, id))
                return TRUE;
        return FALSE;
    }

private:
    CWalkLevel* Levels;
    int Count, Capacity;
};

// the walk cannot go on with 'name' (a name or a folder path) because of 'err': Skip / Skip all /
// Cancel; TRUE = skip it and go on
static BOOL WalkError(const char* name, DWORD err)
{
    if (SkipAllWalkErrors)
        return TRUE;
    switch (SalamanderGeneral->DialogError(hProgressWnd, BUTTONS_SKIPCANCEL, name,
                                           SalamanderGeneral->GetErrorText(err), NULL))
    {
    case DIALOG_SKIPALL:
        SkipAllWalkErrors = TRUE;
        // no break
    case DIALOG_SKIP:
        return TRUE;
    }
    return FALSE;
}

// starts listing the folder 'path' into 'level'; FALSE with the error when it cannot be listed
// (an empty listing is not an error)
static BOOL StartListing(CWalkPath& path, CWalkLevel* level, DWORD* err)
{
    *err = NO_ERROR;
    int len = path.GetLen();
    char* b = path.Get();
    if (len > 0 && b[len - 1] == '\\')
        strcpy(b + len, "*");
    else
        strcpy(b + len, "\\*"); // room kept by CWalkPath
    WCHAR* w = SplU8ToWExtAlloc(b);
    b[len] = 0;
    if (w == NULL)
    {
        *err = ERROR_NOT_ENOUGH_MEMORY;
        return FALSE;
    }
    level->Find = HANDLES_Q(FindFirstFileW(w, &level->Data));
    DWORD e = GetLastError();
    free(w);
    if (level->Find != INVALID_HANDLE_VALUE)
    {
        level->First = TRUE;
        return TRUE;
    }
    if (e == ERROR_FILE_NOT_FOUND || e == ERROR_NO_MORE_FILES)
        return TRUE; // nothing to list
    *err = e;
    return FALSE;
}

// the next entry of the folder (not "." / ".."), its name in 'name' (UTF-8); FALSE at the end
// or on an error ('*err' != NO_ERROR)
static BOOL NextEntry(CWalkLevel* level, char* name, int nameSize, DWORD* err)
{
    *err = NO_ERROR;
    while (level->Find != INVALID_HANDLE_VALUE)
    {
        if (level->First)
            level->First = FALSE;
        else if (!FindNextFileW(level->Find, &level->Data))
        {
            DWORD e = GetLastError();
            if (e != ERROR_NO_MORE_FILES)
                *err = e;
            return FALSE;
        }
        const WCHAR* n = level->Data.cFileName;
        if (n[0] == 0 || wcscmp(n, L".") == 0 || wcscmp(n, L"..") == 0)
            continue;
        if (SplWToU8(n, name, nameSize) > 0) // WTF-8: total for a name of up to 255 units
            return TRUE;
    }
    return FALSE;
}

// ****************************************************************************

struct IMPORT_CONTEXT
{
    SAFE_FILE* file;
    HWND parent;
};

static DWORD WINAPI RestoreCallback(PBYTE data, PVOID _ctx, PULONG plen)
{
    CALL_STACK_MESSAGE1("RestoreCallback()");
    IMPORT_CONTEXT* ctx = (IMPORT_CONTEXT*)_ctx;
    DWORD numread;
    if (!SalamanderSafeFile->SafeFileRead(ctx->file, data, *plen, &numread, ctx->parent, BUTTONS_RETRYCANCEL, NULL, NULL) ||
        Progress->GetWantCancel())
    {
        return ERROR_CANCELLED;
    }
    FileProgress += numread;
    TotalProgress += numread;
    UpdateRestoreProgress();
    *plen = numread;
    return ERROR_SUCCESS;
}

// restores the file 'srcpath' as 'dstpath' (full paths; 'dstpath' loses a ".bak" of a real backup)
static BOOL RestoreFileAt(const char* srcpath, char* dstpath)
{
    CALL_STACK_MESSAGE3("RestoreFileAt(%s, %s)", srcpath, dstpath);

    BOOL ret = TRUE;

    // open source file
    SAFE_FILE srcfile;
    DWORD button;
    if (!SalamanderSafeFile->SafeFileOpen(&srcfile, srcpath, GENERIC_READ, FILE_SHARE_READ, OPEN_EXISTING,
                                          FILE_FLAG_SEQUENTIAL_SCAN, hProgressWnd, BUTTONS_RETRYSKIPCANCEL, &button, &SrcSilentMask))
    {
        return button != DIALOG_CANCEL;
    }

    // get information from source file (local disk: W file API, interface 104)
    DWORD attr = FILE_ATTRIBUTE_NORMAL;
    CQuadWord size(0, 0);
    WIN32_FIND_DATAW w32fd;
    WCHAR* srcpathW = SplU8ToWExtAlloc(srcpath);
    HANDLE hfind = srcpathW == NULL ? INVALID_HANDLE_VALUE : FindFirstFileW(srcpathW, &w32fd);
    free(srcpathW);
    if (hfind != INVALID_HANDLE_VALUE)
    {
        attr = w32fd.dwFileAttributes;
        size = CQuadWord(w32fd.nFileSizeLow, w32fd.nFileSizeHigh);
        FindClose(hfind);
    }
    FILETIME times[3];
    GetFileTime(srcfile.HFile, times, times + 1, times + 2);

    // ensure it really is backup of encrypted file:
    // - extension must be .bak
    // - it must contain 'ROBS' signature (feature 115: READ - a .bak file shorter than the
    //   signature, or one that could not be read, counted as a real backup and was handed to
    //   the EFS import, which failed with "Could not undelete encrypted file")
    BOOL real = FALSE;
    size_t srclen = strlen(srcpath);
    if (srclen > 4 && !_stricmp(srcpath + srclen - 4, ".bak"))
    {
        DWORD sig[3], numread;
        real = ReadFile(srcfile.HFile, sig, sizeof(sig), &numread, NULL) &&
               numread == sizeof(sig) && sig[1] == 0x004f0052 && sig[2] == 0x00530042;
        SetFilePointer(srcfile.HFile, 0, NULL, FILE_BEGIN);
    }

    // remove .bak extension for target file, if it is real backup
    if (real)
        dstpath[strlen(dstpath) - 4] = 0;

    // init progress
    FileProgress = 1;
    FileTotal = size.Value + 1;
    TotalProgress++;
    UpdateRestoreProgress();
    Progress->SetSourceFileName(srcpath);
    Progress->SetDestFileName(dstpath);

    // create target file
    SAFE_FILE dstfile;
    BOOL skipped;
    HANDLE hdst = SalamanderSafeFile->SafeFileCreate(dstpath, GENERIC_WRITE, FILE_SHARE_READ,
                                                     FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN, FALSE, hProgressWnd, srcpath,
                                                     GetSCFData(times, size), &DstSilentMask, TRUE, &skipped, NULL, 0, NULL, &dstfile);
    if (skipped)
    {
        SalamanderSafeFile->SafeFileClose(&srcfile);
        // skip file in progress
        FileProgress = 0;
        TotalProgress += size.Value;
        UpdateRestoreProgress();
        return TRUE;
    }
    if (hdst == INVALID_HANDLE_VALUE)
    {
        SalamanderSafeFile->SafeFileClose(&srcfile); // feature 115: the source stayed open
        return FALSE;
    }

    // recover encrypted files from backup
    if (real)
    {
        // OpenEncryptedFileRaw (and others) unfortunately has own write to output file, we will open file
        // with SafeFileCreate anyway for error handling, but we need to close it
        SalamanderSafeFile->SafeFileClose(&dstfile);

        // restore
        IMPORT_CONTEXT ctx = {&srcfile, hProgressWnd};
        PVOID context = NULL;
        DWORD result;
        // restore target lives on the local disk: use the W API (interface 104)
        WCHAR* dstpathW = SplU8ToWExtAlloc(dstpath);
        if ((result = dstpathW == NULL ? ERROR_INVALID_NAME : OpenEncryptedFileRawW(dstpathW, CREATE_FOR_IMPORT, &context)) != ERROR_SUCCESS ||
            (result = WriteEncryptedFileRaw(RestoreCallback, (PVOID)&ctx, context)) != ERROR_SUCCESS)
        {
            if (result != ERROR_CANCELLED) // return on cancel from user
            {
                SetLastError(result);
                String<char>::SysError(IDS_UNDELETE, IDS_ERRORENCRYPTED);
            }
            ret = FALSE;
        }
        if (context != NULL) // feature 115: not opened = nothing to close
            CloseEncryptedFileRaw(context);
        free(dstpathW);
    }
    else // otherwise only copy
    {
        BYTE* buffer = new BYTE[COPY_BUFFER_SIZE];

        DWORD numread;
        do
        {
            DWORD numwritten;
            if (!SalamanderSafeFile->SafeFileRead(&srcfile, buffer, COPY_BUFFER_SIZE, &numread, hProgressWnd, BUTTONS_RETRYCANCEL, NULL, NULL) ||
                !SalamanderSafeFile->SafeFileWrite(&dstfile, buffer, numread, &numwritten, hProgressWnd, BUTTONS_RETRYCANCEL, NULL, NULL) ||
                Progress->GetWantCancel())
            {
                ret = FALSE;
                break;
            }
            FileProgress += numread;
            TotalProgress += numread;
            UpdateRestoreProgress();
        } while (numread == COPY_BUFFER_SIZE);

        delete[] buffer;
        SalamanderSafeFile->SafeFileClose(&dstfile);
    }
    SalamanderSafeFile->SafeFileClose(&srcfile);

    // set time and attributes (local disk target: W file API, interface 104)
    WCHAR* dstpathW = SplU8ToWExtAlloc(dstpath);
    if (ret)
    {
        HANDLE hf = dstpathW == NULL ? INVALID_HANDLE_VALUE : CreateFileW(dstpathW, GENERIC_WRITE, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
        if (hf != INVALID_HANDLE_VALUE)
        {
            SetFileTime(hf, times, times + 1, times + 2);
            CloseHandle(hf);
        }
        if (dstpathW != NULL)
            SetFileAttributesW(dstpathW, attr | FILE_ATTRIBUTE_ENCRYPTED);
    }
    // on cancel remove incomplete file
    else if (Progress->GetWantCancel())
    {
        if (dstpathW != NULL)
            DeleteFileW(dstpathW);
    }
    free(dstpathW);

    return ret;
}

// restores the file 'fileName' of the source folder 'src' into the target folder 'dst'
static BOOL RestoreFile(CWalkPath& src, CWalkPath& dst, const char* fileName)
{
    CALL_STACK_MESSAGE2("RestoreFile(, , %s)", fileName);
    int srcLen = src.GetLen();
    int dstLen = dst.GetLen();
    BOOL ret;
    if (!src.Append(fileName) || !dst.Append(fileName))
        ret = WalkError(fileName, ERROR_FILENAME_EXCED_RANGE); // past SAL_MAX_PATH_UTF8: unreachable in practice (Windows refuses 32,767+ units first - reported by the file call)
    else
        ret = RestoreFileAt(src.Get(), dst.Get());
    src.Cut(srcLen);
    dst.Cut(dstLen);
    return ret;
}

// enters the folder 'dirName' of 'src': creates it in 'dst', starts listing it and pushes a level;
// returns 1 (entered), 0 (skipped - paths unchanged) or -1 (cancel - paths unchanged)
static int EnterDir(CWalkPath& src, CWalkPath& dst, const char* dirName, CWalkStack& stack, CDirId& targetRoot)
{
    int srcLen = src.GetLen();
    int dstLen = dst.GetLen();
    if (!src.Append(dirName) || !dst.Append(dirName))
    {
        src.Cut(srcLen);
        dst.Cut(dstLen);
        return WalkError(dirName, ERROR_FILENAME_EXCED_RANGE) ? 0 : -1;
    }

    // a folder the walk is already in (a directory link to an ancestor), the target folder or a
    // folder this restore created in it (the target lies inside the selection): entering it would
    // restore it into itself without an end
    CDirId id;
    GetDirId(src.Get(), &id);
    if (!targetRoot.Known) // a target folder that did not exist yet: it may exist by now
        GetDirId(TargetRootPath, &targetRoot);
    if (stack.Contains(id) || SameFolder(id, targetRoot))
    {
        BOOL skip = WalkError(src.Get(), ERROR_CANT_RESOLVE_FILENAME);
        src.Cut(srcLen);
        dst.Cut(dstLen);
        return skip ? 0 : -1;
    }

    // update progress
    FileProgress = 0;
    FileTotal = 1;
    TotalProgress++;
    UpdateRestoreProgress();
    Progress->SetSourceFileName(src.Get());
    Progress->SetDestFileName(dst.Get());

    // create directory
    BOOL skipped;
    if (SalamanderSafeFile->SafeFileCreate(dst.Get(), 0, 0, 0, TRUE, hProgressWnd, NULL, NULL,
                                           &DirSilentMask, TRUE, &skipped, NULL, 0, NULL, NULL) == INVALID_HANDLE_VALUE)
    {
        src.Cut(srcLen);
        dst.Cut(dstLen);
        return skipped ? 0 : -1;
    }

    CWalkLevel* level = stack.Push();
    if (level == NULL)
    {
        src.Cut(srcLen);
        dst.Cut(dstLen);
        String<char>::Error(IDS_UNDELETE, IDS_LOWMEM);
        return -1;
    }
    level->SrcLen = srcLen;
    level->DstLen = dstLen;
    level->Id = id;
    GetDirId(dst.Get(), &level->DstId);
    DWORD err;
    if (!StartListing(src, level, &err) && !WalkError(src.Get(), err))
        return -1; // the level stays pushed: the caller leaves it (attributes, paths)
    return 1;
}

// leaves the top folder: sets the target folder's attributes from the source folder, cuts the
// paths back to the parent's
static void LeaveDir(CWalkPath& src, CWalkPath& dst, CWalkStack& stack)
{
    CWalkLevel* level = stack.Top();
    DWORD attr = SalamanderGeneral->SalGetFileAttributes(src.Get());
    if (attr != INVALID_FILE_ATTRIBUTES)
    {
        WCHAR* dstpathW = SplU8ToWExtAlloc(dst.Get());
        if (dstpathW != NULL)
        {
            SetFileAttributesW(dstpathW, attr);
            free(dstpathW);
        }
    }
    src.Cut(level->SrcLen);
    dst.Cut(level->DstLen);
    stack.Pop();
}

static BOOL RestoreDir(CWalkPath& src, CWalkPath& dst, const char* dirName, CDirId& targetRoot)
{
    CALL_STACK_MESSAGE2("RestoreDir(, , %s)", dirName);

    CWalkStack stack;
    int e = EnterDir(src, dst, dirName, stack, targetRoot);
    if (e == 0)
        return TRUE;
    BOOL ret = e > 0;
    char name[3 * MAX_PATH]; // a name: up to 255 UTF-16 units = 765 bytes of UTF-8
    while (stack.GetCount() > 0)
    {
        CWalkLevel* level = stack.Top();
        DWORD err = NO_ERROR;
        if (!ret || !NextEntry(level, name, sizeof(name), &err))
        {
            if (ret && err != NO_ERROR && !WalkError(src.Get(), err))
                ret = FALSE;
            LeaveDir(src, dst, stack);
            continue;
        }
        if (level->Data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
        {
            if (EnterDir(src, dst, name, stack, targetRoot) < 0) // 'level' may move (realloc)
                ret = FALSE;
        }
        else
            ret = RestoreFile(src, dst, name);
    }
    return ret;
}

// the size of the folder 'dirName' of 'path' (+1 per item, the progress unit); 'path' is
// unchanged afterwards. Folders that do not fit, cannot be listed or are already being walked
// are not counted (the restore reports them).
static QWORD GetDirSize(CWalkPath& path, const char* dirName, BOOL* cancel)
{
    SLOW_CALL_STACK_MESSAGE2("GetDirSize(, %s)", dirName);

    QWORD total = 0;
    CWalkStack stack;
    char name[3 * MAX_PATH];
    const char* enter = dirName;
    while (1)
    {
        if (enter != NULL)
        {
            int len = path.GetLen();
            if (path.Append(enter))
            {
                CDirId id;
                GetDirId(path.Get(), &id);
                CWalkLevel* level = stack.Contains(id) ? NULL : stack.Push();
                DWORD err;
                if (level != NULL)
                {
                    level->SrcLen = len;
                    level->Id = id;
                    StartListing(path, level, &err); // a folder that cannot be listed counts 0
                }
                else
                    path.Cut(len);
            }
            enter = NULL;
        }

        CWalkLevel* level = stack.Top();
        if (level == NULL)
            break;
        DWORD err = NO_ERROR;
        if (!NextEntry(level, name, sizeof(name), &err))
        {
            path.Cut(level->SrcLen);
            stack.Pop();
            continue;
        }
        if (level->Data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
        {
            total++;
            enter = name;
        }
        else
            total += MAKEQWORD(level->Data.nFileSizeLow, level->Data.nFileSizeHigh) + 1;

        if (*cancel || (GetAsyncKeyState(VK_ESCAPE) & 0x8001) ||
            SalamanderGeneral->GetSafeWaitWindowClosePressed())
        {
            *cancel = TRUE;
            while (stack.Top() != NULL)
            {
                path.Cut(stack.Top()->SrcLen);
                stack.Pop();
            }
            return 0;
        }
    }
    return total;
}

BOOL RestoreEncryptedFiles(const char* targetPath, HWND parent)
{
    CALL_STACK_MESSAGE2("RestoreEncryptedFiles(%s, )", targetPath);

    // check EFS support on target path
    char resolvedPath[MAX_PATH];
    UndeleteGetResolvedRootPath(targetPath, resolvedPath);

    DWORD flags;
    // feature 114: the W layer (resolvedPath is UTF-8)
    if (!OS<char>::OS_GetVolumeInfo(resolvedPath, NULL, 0, NULL, NULL, &flags, NULL, 0) ||
        !(flags & FILE_SUPPORTS_ENCRYPTION))
    {
        return String<char>::Error(IDS_RESTORE, IDS_NOEFS);
    }

    // init (feature 115: the walk's paths on the heap; the source panel's path of any length - it
    // was read into MAX_PATH bytes unchecked, so a deeper panel gave "" and relative names)
    CWalkPath src, dst;
    if (!src.IsGood() || !dst.IsGood())
        return String<char>::Error(IDS_UNDELETE, IDS_LOWMEM);
    // the buffer holds any panel path, so a failure here is not "too long": the core refuses only
    // off the main thread, on low memory or for a panel it cannot describe (review NIT of 115)
    if (!SalamanderGeneral->GetPanelPath(PANEL_SOURCE, src.Get(), src.Size(), NULL, NULL) || src.Get()[0] == 0)
        return String<char>::Error(IDS_UNDELETE, IDS_LOWMEM);
    // a path within 3 bytes of the buffer's end (the panel) or the dialog's target (at most
    // MAX_PATH bytes) - unreachable in practice, Windows gives up at 32,767 UTF-16 units
    if (!src.Adopt() || !dst.Set(targetPath))
    {
        SalamanderGeneral->DialogError(parent, BUTTONS_OK, src.Adopt() ? targetPath : src.Get(),
                                       SalamanderGeneral->GetErrorText(ERROR_FILENAME_EXCED_RANGE), NULL);
        return FALSE;
    }
    CDirId targetRoot;
    TargetRootPath = targetPath;
    GetDirId(TargetRootPath, &targetRoot);
    int selfiles, seldirs;
    SalamanderGeneral->GetPanelSelection(PANEL_SOURCE, &selfiles, &seldirs);
    BOOL focused = (selfiles == 0 && seldirs == 0);

    // get total size of selected files and directories
    SalamanderGeneral->CreateSafeWaitWindow(String<char>::LoadStr(IDS_READINGTREE), NULL, 1500, TRUE, parent);
    const CFileData* fd;
    FileProgress = FileTotal = 0;
    TotalProgress = GrandTotal = 0;
    BOOL isdir, cancel = FALSE;
    int index = 0;
    while (!cancel)
    {
        if (focused)
            fd = SalamanderGeneral->GetPanelFocusedItem(PANEL_SOURCE, &isdir);
        else
            fd = SalamanderGeneral->GetPanelSelectedItem(PANEL_SOURCE, &index, &isdir);
        if (fd == NULL)
            break;

        if (isdir)
            GrandTotal += GetDirSize(src, fd->Name, &cancel) + 1;
        else
            GrandTotal += fd->Size.Value + 1;

        if (focused)
            break;
    }
    SalamanderGeneral->DestroySafeWaitWindow();
    if (cancel)
        return FALSE;

    // test free space
    if (!SalamanderGeneral->TestFreeSpace(parent, targetPath, CQuadWord().SetUI64(GrandTotal), String<char>::LoadStr(IDS_RESTORE)))
        return FALSE;

    // todo: test if sourcePath == targetPath - it is error (feature 115: a file restored onto
    // itself fails - the source is open without write sharing; a target folder inside the
    // selection is refused by the walk)

    // open progress
    CRestoreProgressDlg dlg(parent, ooStatic);
    if (dlg.Create() == NULL)
        return String<char>::SysError(IDS_UNDELETE, IDS_ERROROPENINGPROGRESS);
    EnableWindow(parent, FALSE);
    Progress = &dlg;
    hProgressWnd = dlg.HWindow;
    SetForegroundWindow(hProgressWnd);

    // restore
    BOOL ret = TRUE;
    index = 0;
    SrcSilentMask = DstSilentMask = DirSilentMask = 0;
    SkipAllWalkErrors = FALSE;
    while (ret)
    {
        if (focused)
            fd = SalamanderGeneral->GetPanelFocusedItem(PANEL_SOURCE, &isdir);
        else
            fd = SalamanderGeneral->GetPanelSelectedItem(PANEL_SOURCE, &index, &isdir);
        if (fd == NULL)
            break;

        if (isdir)
            ret = RestoreDir(src, dst, fd->Name, targetRoot);
        else
            ret = RestoreFile(src, dst, fd->Name);

        if (focused)
            break;
    }

    // close progress
    EnableWindow(parent, TRUE);
    DestroyWindow(hProgressWnd);

    return ret;
}
