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

static void UpdateRestoreProgress()
{
    CALL_STACK_MESSAGE1("UpdateRestoreProgress()");
    if (FileTotal)
        Progress->SetFileProgress((DWORD)(FileProgress * 1000 / FileTotal));
    if (GrandTotal)
        Progress->SetTotalProgress((DWORD)(TotalProgress * 1000 / GrandTotal));
}

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

static BOOL RestoreFile(const char* fileName, const char* sourcePath, const char* targetPath)
{
    CALL_STACK_MESSAGE4("RestoreFile(%s, %s, %s)", fileName, sourcePath, targetPath);

    BOOL ret = TRUE;
    char srcpath[2 * MAX_PATH];
    char dstpath[2 * MAX_PATH];

    // prepare source and target paths
    lstrcpyn(srcpath, sourcePath, 2 * MAX_PATH);
    lstrcpyn(dstpath, targetPath, 2 * MAX_PATH);
    SalamanderGeneral->SalPathAppend(srcpath, fileName, 2 * MAX_PATH);
    SalamanderGeneral->SalPathAppend(dstpath, fileName, 2 * MAX_PATH);

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
    BOOL real = FALSE;
    if (strlen(srcpath) > 3)
        real = !_stricmp(srcpath + strlen(srcpath) - 4, ".bak");
    // - it must contain 'ROBS' signature
    DWORD sig[3], numread;
    if (real && ReadFile(srcfile.HFile, sig, sizeof(sig), &numread, NULL) &&
        numread == sizeof(sig) && (sig[1] != 0x004f0052 || sig[2] != 0x00530042))
        real = FALSE;
    SetFilePointer(srcfile.HFile, 0, NULL, FILE_BEGIN);

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
        return FALSE;

    // recover encrypted files from backup
    if (real)
    {
        // OpenEncryptedFileRaw (and others) unfortunately has own write to output file, we will open file
        // with SafeFileCreate anyway for error handling, but we need to close it
        SalamanderSafeFile->SafeFileClose(&dstfile);

        // restore
        IMPORT_CONTEXT ctx = {&srcfile, hProgressWnd};
        PVOID context;
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
        CloseEncryptedFileRaw(context);
        free(dstpathW);
    }
    else // otherwise only copy
    {
        BYTE* buffer = new BYTE[COPY_BUFFER_SIZE];

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

static BOOL RestoreDir(const char* fileName, const char* sourcePath, const char* targetPath)
{
    CALL_STACK_MESSAGE4("RestoreDir(%s, %s, %s)", fileName, sourcePath, targetPath);

    // prepare source and target paths
    char srcpath[2 * MAX_PATH], dstpath[2 * MAX_PATH];
    lstrcpyn(srcpath, sourcePath, 2 * MAX_PATH);
    lstrcpyn(dstpath, targetPath, 2 * MAX_PATH);
    SalamanderGeneral->SalPathAppend(srcpath, fileName, 2 * MAX_PATH);
    SalamanderGeneral->SalPathAppend(dstpath, fileName, 2 * MAX_PATH);

    // update progress
    FileProgress = 0;
    FileTotal = 1;
    TotalProgress++;
    UpdateRestoreProgress();
    Progress->SetSourceFileName(srcpath);
    Progress->SetDestFileName(dstpath);

    // create directory
    BOOL skipped;
    if (SalamanderSafeFile->SafeFileCreate(dstpath, 0, 0, 0, TRUE, hProgressWnd, NULL, NULL,
                                           &DirSilentMask, TRUE, &skipped, NULL, 0, NULL, NULL) == INVALID_HANDLE_VALUE)
    {
        return skipped;
    }

    // list and restore all files in directory (local disk: W file API, names
    // kept as UTF-8 for the interface, interface 104)
    BOOL ret = TRUE;
    HANDLE hFind;
    static WIN32_FIND_DATAW fd;
    char fdNameU8[3 * MAX_PATH];
    int plen = (int)strlen(srcpath);
    strcat(srcpath, "\\*");

    WCHAR* srcpathW = SplU8ToWExtAlloc(srcpath);
    hFind = srcpathW == NULL ? INVALID_HANDLE_VALUE : HANDLES_Q(FindFirstFileW(srcpathW, &fd));
    free(srcpathW);
    if (hFind != INVALID_HANDLE_VALUE)
    {
        srcpath[plen] = 0;
        do
        {
            if (fd.cFileName[0] != 0 && wcscmp(fd.cFileName, L".") && wcscmp(fd.cFileName, L"..") &&
                SplWToU8(fd.cFileName, fdNameU8, sizeof(fdNameU8)) > 0)
            {
                if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
                    ret = RestoreDir(fdNameU8, srcpath, dstpath);
                else
                    ret = RestoreFile(fdNameU8, srcpath, dstpath);
            }
        } while (ret && FindNextFileW(hFind, &fd));
        HANDLES(FindClose(hFind));
    }
    srcpath[plen] = 0;

    // set attribute (local disk target: W file API, interface 104)
    DWORD attr = SalamanderGeneral->SalGetFileAttributes(srcpath);
    if (attr != INVALID_FILE_ATTRIBUTES)
    {
        WCHAR* dstpathW = SplU8ToWExtAlloc(dstpath);
        if (dstpathW != NULL)
        {
            SetFileAttributesW(dstpathW, attr);
            free(dstpathW);
        }
    }

    return ret;
}

static QWORD GetDirSize(char* path, char* dirname, BOOL* cancel)
{
    SLOW_CALL_STACK_MESSAGE3("GetDirSize(%s, %s)", path, dirname);

    // local disk enumeration on the W layer; recursion names kept as UTF-8 (interface 104)
    HANDLE hFind;
    static WIN32_FIND_DATAW fd;
    char fdNameU8[3 * MAX_PATH];
    int plen1 = (int)strlen(path);
    SalamanderGeneral->SalPathAppend(path, dirname, MAX_PATH);
    int plen2 = (int)strlen(path);
    strcat(path, "\\*");
    QWORD total = 0;

    WCHAR* pathW = SplU8ToWExtAlloc(path);
    hFind = pathW == NULL ? INVALID_HANDLE_VALUE : HANDLES_Q(FindFirstFileW(pathW, &fd));
    free(pathW);
    if (hFind != INVALID_HANDLE_VALUE)
    {
        path[plen2] = 0;
        do
        {
            if (fd.cFileName[0] != 0 && wcscmp(fd.cFileName, L".") && wcscmp(fd.cFileName, L"..") &&
                SplWToU8(fd.cFileName, fdNameU8, sizeof(fdNameU8)) > 0)
            {
                if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
                    total += GetDirSize(path, fdNameU8, cancel) + 1;
                else
                    total += MAKEQWORD(fd.nFileSizeLow, fd.nFileSizeHigh) + 1;
            }

            if (*cancel || (GetAsyncKeyState(VK_ESCAPE) & 0x8001) ||
                SalamanderGeneral->GetSafeWaitWindowClosePressed())
            {
                HANDLES(FindClose(hFind));
                *cancel = TRUE;
                return 0;
            }
        } while (FindNextFileW(hFind, &fd));
        HANDLES(FindClose(hFind));
    }
    path[plen1] = 0;

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

    // init
    char sourcePath[MAX_PATH];
    SalamanderGeneral->GetPanelPath(PANEL_SOURCE, sourcePath, MAX_PATH, NULL, NULL);
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
            GrandTotal += GetDirSize(sourcePath, fd->Name, &cancel);
        else
            GrandTotal += fd->Size.Value;

        if (focused)
            break;
    }
    SalamanderGeneral->DestroySafeWaitWindow();
    if (cancel)
        return FALSE;

    // test free space
    if (!SalamanderGeneral->TestFreeSpace(parent, targetPath, CQuadWord().SetUI64(GrandTotal), String<char>::LoadStr(IDS_RESTORE)))
        return FALSE;

    // todo: test if sourcePath == targetPath - it is error

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
    while (ret)
    {
        if (focused)
            fd = SalamanderGeneral->GetPanelFocusedItem(PANEL_SOURCE, &isdir);
        else
            fd = SalamanderGeneral->GetPanelSelectedItem(PANEL_SOURCE, &index, &isdir);
        if (fd == NULL)
            break;

        if (isdir)
            ret = RestoreDir(fd->Name, sourcePath, targetPath);
        else
            ret = RestoreFile(fd->Name, sourcePath, targetPath);

        if (focused)
            break;
    }

    // close progress
    EnableWindow(parent, TRUE);
    DestroyWindow(hProgressWnd);

    return ret;
}
