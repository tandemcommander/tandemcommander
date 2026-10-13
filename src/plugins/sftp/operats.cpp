// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"
#include "sftp.h"
#include "sftputils.h"
#include "session.h"
#include "listing.h"
#include "dialogs.h"
#include "logs.h"
#include "operats.h"

#define XFER_BUFSIZE (256 * 1024)

// CF-5: cap recursion so a maliciously/accidentally deep directory tree (server-
// or local-side) cannot exhaust the stack and crash the whole process. 128
// levels is far beyond any real tree yet nowhere near the ~1 MB stack limit.
#define SFTP_MAX_RECURSION 128

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

static BOOL Utf8ToWide(const char* s, wchar_t* out, int outCount)
{
    return MultiByteToWideChar(CP_UTF8, 0, s, -1, out, outCount) > 0;
}

static BOOL WideToUtf8(const wchar_t* s, char* out, int outCount)
{
    return WideCharToMultiByte(CP_UTF8, 0, s, -1, out, outCount, NULL, NULL) > 0;
}

// builds a Windows long-path-capable wide path from a UTF-8 path
static void MakeLocalWidePath(const char* utf8Path, wchar_t* wide, int wideCount)
{
    // CF-18: leave an empty (invalid) path if the conversion fails, so a caller
    // that does not check gets a clean CreateFileW error instead of operating on
    // an uninitialized stack buffer.
    if (wideCount > 0)
        wide[0] = 0;
    Utf8ToWide(utf8Path, wide, wideCount);
}

// Makes a single remote name component safe to use as a local file name:
// replaces path separators and Windows-invalid characters with '_'. Prevents a
// malicious/compromised server from escaping the target directory via a name
// containing '\' or ':' (POSIX only reserves '/').
static void SanitizeLocalName(const char* name, char* out, int outSize)
{
    int i = 0;
    for (; name[i] != 0 && i < outSize - 1; i++)
    {
        unsigned char c = (unsigned char)name[i];
        if (c == '\\' || c == '/' || c == ':' || c == '*' || c == '?' ||
            c == '"' || c == '<' || c == '>' || c == '|' || c < 0x20)
            out[i] = '_';
        else
            out[i] = name[i];
    }
    out[i] = 0;
    // reject "." / ".." which would still traverse
    if (strcmp(out, ".") == 0 || strcmp(out, "..") == 0)
    {
        lstrcpynA(out, "_", outSize);
        return;
    }
    // CF-16: strip trailing dots/spaces (Windows silently drops them, which can
    // collapse the name onto a different existing target) and disarm reserved
    // device basenames a hostile server could use (CON, NUL, COM1..9, LPT1..9,
    // with or without an extension) - opening those hits a device, not a file.
    int len = (int)strlen(out);
    while (len > 0 && (out[len - 1] == '.' || out[len - 1] == ' '))
        out[--len] = 0;
    if (out[0] == 0)
    {
        lstrcpynA(out, "_", outSize);
        return;
    }
    char base[16];
    int b = 0;
    for (; out[b] != 0 && out[b] != '.' && b < (int)sizeof(base) - 1; b++)
    {
        char u = out[b];
        base[b] = (u >= 'a' && u <= 'z') ? (char)(u - 32) : u;
    }
    base[b] = 0;
    static const char* const kReserved[] = {
        "CON", "PRN", "AUX", "NUL",
        "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
        "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"};
    for (int r = 0; r < (int)(sizeof(kReserved) / sizeof(kReserved[0])); r++)
    {
        if (strcmp(base, kReserved[r]) == 0)
        {
            char tmp[600];
            _snprintf_s(tmp, _TRUNCATE, "_%s", out);
            lstrcpynA(out, tmp, outSize);
            break;
        }
    }
}

enum COverwriteMode
{
    ovAsk = 0,
    ovAll = 1,
    ovSkipAll = 2,
};

struct COperationCtx
{
    HWND Parent;
    CSFTPSession* Session;
    volatile BOOL Cancelled;
    int OverwriteMode; // COverwriteMode
    char Buffer[XFER_BUFSIZE];

    COperationCtx(HWND parent, CSFTPSession* session)
    {
        Parent = parent;
        Session = session;
        Cancelled = FALSE;
        OverwriteMode = ovAsk;
    }
    BOOL CheckCancel()
    {
        if (!Cancelled && SalamanderGeneral->GetSafeWaitWindowClosePressed())
            Cancelled = TRUE;
        return Cancelled;
    }
};

static void WaitText(const char* fmt, const char* arg)
{
    char msg[1024];
    _snprintf_s(msg, _TRUNCATE, fmt, arg);
    // reflect current file in the wait window title area via a fresh window
    SalamanderGeneral->DestroySafeWaitWindow();
    SalamanderGeneral->CreateSafeWaitWindow(msg, LoadStr(IDS_PLUGINNAME), 0, TRUE, SalamanderGeneral->GetMainWindowHWND());
}

// ---------------------------------------------------------------------------
// download
// ---------------------------------------------------------------------------

// tri-state so a "move" only deletes the source that was actually transferred
enum CXferResult
{
    xrOk = 0,      // fully transferred (safe to delete source on move)
    xrSkipped = 1, // deliberately skipped (dir-symlink, user "skip") - keep source
    xrFailed = 2,  // error - keep source, mark operation failed
};

// Confirms overwrite of an existing local target unless the user chose all/none.
// Returns TRUE to proceed with the write, FALSE to skip this file.
static BOOL ConfirmOverwrite(COperationCtx* ctx, const char* localPath)
{
    if (ctx->OverwriteMode == ovAll)
        return TRUE;
    if (ctx->OverwriteMode == ovSkipAll)
        return FALSE;
    char msg[1400];
    _snprintf_s(msg, _TRUNCATE, "The local file already exists:\n%s\n\nOverwrite it?\n"
                "(Yes = this file, No = skip; hold nothing - use Cancel to skip the rest)", localPath);
    // Yes = overwrite this; No = skip this; Cancel = skip all remaining
    int r = SalamanderGeneral->SalMessageBox(ctx->Parent, msg, LoadStr(IDS_SFTPERRORTITLE),
                                             MB_YESNOCANCEL | MB_ICONQUESTION);
    if (r == IDCANCEL)
    {
        ctx->OverwriteMode = ovSkipAll;
        return FALSE;
    }
    return r == IDYES;
}

static CXferResult DownloadOneFile(COperationCtx* ctx, const char* remotePath, const char* localPath,
                                   unsigned __int64 remoteSize)
{
    wchar_t wlocal[4096];
    MakeLocalWidePath(localPath, wlocal, 4096);

    unsigned __int64 startOffset = 0;
    BOOL append = FALSE;
    WIN32_FILE_ATTRIBUTE_DATA fad;
    if (GetFileAttributesExW(wlocal, GetFileExInfoStandard, &fad) &&
        !(fad.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY))
    {
        unsigned __int64 localSize = ((unsigned __int64)fad.nFileSizeHigh << 32) | fad.nFileSizeLow;
        if (localSize > 0 && localSize < remoteSize && localSize >= (unsigned __int64)Config.ResumeMinFileSize)
        {
            // partial file: offer resume (FR-011)
            int r = ShowResumePrompt(ctx->Parent, PosixBaseName(remotePath)); // Yes=resume No=overwrite Cancel=skip
            if (r == IDYES) { startOffset = localSize; append = TRUE; }
            else if (r == IDCANCEL) return xrSkipped;
            // IDNO falls through to overwrite
        }
        else
        {
            // full/existing file: confirm overwrite so we never silently destroy it
            if (!ConfirmOverwrite(ctx, localPath))
                return xrSkipped;
        }
    }

    LIBSSH2_SFTP_HANDLE* h = ctx->Session->OpenRead(remotePath);
    if (h == NULL)
    {
        char msg[1200];
        // feature 130: a UTF-8 sentence (template, path, reason) - see LoadStrU8 in sftp.h
        _snprintf_s(msg, _TRUNCATE, LoadStrU8(IDS_ERR_DOWNLOAD), CSFTPMsgText(remotePath).Get(), ctx->Session->GetLastErrorText());
        SplU8TrimTornTail(msg);
        SalamanderGeneral->SalMessageBox(ctx->Parent, msg, LoadStr(IDS_SFTPERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
        Logs.Append(ctx->Session->GetLogUID(), msg);
        return xrFailed;
    }

    HANDLE lf = CreateFileW(wlocal, GENERIC_WRITE, 0, NULL,
                            append ? OPEN_EXISTING : CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (lf == INVALID_HANDLE_VALUE)
    {
        ctx->Session->CloseHandle(h);
        char msg[1200];
        // (the local path ends with the remote name - the server's bytes, not always UTF-8)
        _snprintf_s(msg, _TRUNCATE, LoadStrU8(IDS_ERR_OPENLOCAL), CSFTPMsgText(localPath).Get());
        SplU8TrimTornTail(msg);
        SalamanderGeneral->SalMessageBox(ctx->Parent, msg, LoadStr(IDS_SFTPERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
        return xrFailed;
    }
    if (append)
    {
        LARGE_INTEGER li;
        li.QuadPart = startOffset;
        SetFilePointerEx(lf, li, NULL, FILE_BEGIN);
        ctx->Session->SeekWrite(h, startOffset);
    }

    CXferResult res = xrOk;
    for (;;)
    {
        if (ctx->CheckCancel())
        {
            res = xrFailed;
            break;
        }
        __int64 n = ctx->Session->Read(h, ctx->Buffer, XFER_BUFSIZE);
        if (n < 0)
        {
            res = xrFailed;
            SalamanderGeneral->SalMessageBox(ctx->Parent, LoadStr(IDS_ERR_READREMOTE),
                                             LoadStr(IDS_SFTPERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
            break;
        }
        if (n == 0)
            break;
        DWORD written = 0;
        if (!WriteFile(lf, ctx->Buffer, (DWORD)n, &written, NULL) || written != (DWORD)n)
        {
            res = xrFailed;
            SalamanderGeneral->SalMessageBox(ctx->Parent, LoadStr(IDS_ERR_DISKFULL),
                                             LoadStr(IDS_SFTPERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
            break;
        }
    }
    CloseHandle(lf);
    ctx->Session->CloseHandle(h);
    // CF-17: a freshly created/truncated target left partial on cancel/error
    // would replace the user's original file with garbage - remove it. (Append/
    // resume keeps the file, since the original bytes are still valid.)
    if (res == xrFailed && !append)
        DeleteFileW(wlocal);
    return res;
}

static CXferResult DownloadRecursive(COperationCtx* ctx, const char* remotePath, const char* localPath,
                                     unsigned long mode, BOOL isLink, unsigned __int64 size, int depth);

static CXferResult DownloadDir(COperationCtx* ctx, const char* remoteDir, const char* localDir, int depth)
{
    if (depth > SFTP_MAX_RECURSION) // CF-5
    {
        SalamanderGeneral->SalMessageBox(ctx->Parent, LoadStr(IDS_ERR_TOODEEP),
                                         LoadStr(IDS_SFTPERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
        return xrFailed;
    }
    wchar_t wdir[4096];
    MakeLocalWidePath(localDir, wdir, 4096);
    CreateDirectoryW(wdir, NULL); // ignore "already exists"

    TIndirectArray<CSFTPDirEntry> entries(64, 64);
    if (!ctx->Session->ListDir(remoteDir, &entries, &ctx->Cancelled))
    {
        char msg[1200];
        _snprintf_s(msg, _TRUNCATE, LoadStrU8(IDS_ERR_LISTDIR), CSFTPMsgText(remoteDir).Get(), ctx->Session->GetLastErrorText());
        SplU8TrimTornTail(msg);
        SalamanderGeneral->SalMessageBox(ctx->Parent, msg, LoadStr(IDS_SFTPERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
        return xrFailed;
    }

    CXferResult agg = xrOk; // xrOk only if every child fully transferred
    for (int i = 0; i < entries.Count && !ctx->CheckCancel(); i++)
    {
        CSFTPDirEntry* e = entries[i];
        char rpath[4096], lpath[4096], safe[512];
        PosixPathAppend(remoteDir, e->Name, rpath, sizeof(rpath)); // real remote name
        SanitizeLocalName(e->Name, safe, sizeof(safe));            // safe local name
        _snprintf_s(lpath, _TRUNCATE, "%s\\%s", localDir, safe);
        BOOL isLink = e->HasMode && SFTP_S_ISLNK(e->Mode);
        CXferResult r = DownloadRecursive(ctx, rpath, lpath, e->Mode, isLink, e->Size, depth + 1);
        if (r == xrFailed) agg = xrFailed;
        else if (r == xrSkipped && agg == xrOk) agg = xrSkipped;
    }
    return agg;
}

static CXferResult DownloadRecursive(COperationCtx* ctx, const char* remotePath, const char* localPath,
                                     unsigned long mode, BOOL isLink, unsigned __int64 size, int depth)
{
    if (ctx->CheckCancel())
        return xrFailed;

    if (isLink)
    {
        LIBSSH2_SFTP_ATTRIBUTES attrs;
        if (ctx->Session->Stat(remotePath, TRUE, &attrs) && (attrs.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS) &&
            SFTP_S_ISDIR(attrs.permissions))
        {
            Logs.AppendFmt(ctx->Session->GetLogUID(), LoadStrU8(IDS_SYMLINK_DIR_SKIPPED), CSFTPMsgText(remotePath).Get());
            return xrSkipped; // directory symlink not followed (clarification #4)
        }
        WaitText("Downloading %s ...", PosixBaseName(remotePath));
        return DownloadOneFile(ctx, remotePath, localPath, size);
    }

    if (SFTP_S_ISDIR(mode))
        return DownloadDir(ctx, remotePath, localPath, depth);

    WaitText("Downloading %s ...", PosixBaseName(remotePath));
    return DownloadOneFile(ctx, remotePath, localPath, size);
}

// collects the panel's selection (or focus) into 'items', storing the true
// remote name (SFTPRealName) so operations target the correct server file
static void CollectPanelItems(int panel, TIndirectArray<CSFTPDirEntry>* items)
{
    int index = 0;
    BOOL isDir = FALSE;
    for (;;)
    {
        const CFileData* it = SalamanderGeneral->GetPanelSelectedItem(panel, &index, &isDir);
        if (it == NULL)
            break;
        CSFTPDirEntry* e = new CSFTPDirEntry;
        if (e == NULL)
            break;
        e->Name = _strdup(SFTPRealName(it));
        if (e->Name == NULL) { delete e; break; } // CF-19: e->Name is dereferenced later
        CSFTPItemData* d = (CSFTPItemData*)it->PluginData;
        if (d != NULL) { e->Mode = d->Mode; e->HasMode = d->HasMode; e->Uid = d->Uid; e->Gid = d->Gid; } // feature 018: Uid/Gid seed the owner/group dialog
        e->Size = it->Size.Value;
        items->Add(e);
        if (!items->IsGood()) { items->ResetState(); delete e; break; }
    }
    if (items->Count == 0)
    {
        const CFileData* it = SalamanderGeneral->GetPanelFocusedItem(panel, &isDir);
        if (it != NULL && strcmp(it->Name, "..") != 0)
        {
            CSFTPDirEntry* e = new CSFTPDirEntry;
            if (e != NULL)
            {
                e->Name = _strdup(SFTPRealName(it));
                CSFTPItemData* d = (CSFTPItemData*)it->PluginData;
                if (d != NULL) { e->Mode = d->Mode; e->HasMode = d->HasMode; }
                e->Size = it->Size.Value;
                if (e->Name == NULL) { delete e; } // CF-19
                else
                {
                    items->Add(e);
                    if (!items->IsGood()) { items->ResetState(); delete e; }
                }
            }
        }
    }
}

BOOL SFTPDownloadFromPanel(HWND parent, CSFTPSession* session, int panel,
                           const char* remoteDir, const char* targetLocalPath, BOOL move)
{
    COperationCtx ctx(parent, session);
    SalamanderGeneral->CreateSafeWaitWindow(LoadStr(IDS_PLUGINNAME), LoadStr(IDS_PLUGINNAME), 500, TRUE,
                                            SalamanderGeneral->GetMainWindowHWND());

    BOOL ok = TRUE;
    TIndirectArray<CSFTPDirEntry> items(16, 16);
    CollectPanelItems(panel, &items);

    for (int i = 0; i < items.Count && !ctx.CheckCancel(); i++)
    {
        CSFTPDirEntry* e = items[i];
        char rpath[4096], lpath[4096], safe[512];
        PosixPathAppend(remoteDir, e->Name, rpath, sizeof(rpath));
        SanitizeLocalName(e->Name, safe, sizeof(safe));
        _snprintf_s(lpath, _TRUNCATE, "%s\\%s", targetLocalPath, safe);
        BOOL isLink = e->HasMode && SFTP_S_ISLNK(e->Mode);
        CXferResult r = DownloadRecursive(&ctx, rpath, lpath, e->Mode, isLink, e->Size, 0);
        if (r == xrFailed)
            ok = FALSE;
        else if (r == xrOk && move)
        {
            // delete the source ONLY when the item was fully transferred
            if (e->HasMode && SFTP_S_ISDIR(e->Mode))
                session->Rmdir(rpath); // best-effort; fails (kept) if not fully emptied
            else
                session->Unlink(rpath);
        }
    }

    SalamanderGeneral->DestroySafeWaitWindow();
    return ok && !ctx.Cancelled;
}

// ---------------------------------------------------------------------------
// upload
// ---------------------------------------------------------------------------

static BOOL UploadOneFile(COperationCtx* ctx, const char* localPath, const char* remotePath)
{
    wchar_t wlocal[4096];
    MakeLocalWidePath(localPath, wlocal, 4096);
    HANDLE lf = CreateFileW(wlocal, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING,
                            FILE_ATTRIBUTE_NORMAL, NULL);
    if (lf == INVALID_HANDLE_VALUE)
    {
        char msg[1200];
        _snprintf_s(msg, _TRUNCATE, LoadStrU8(IDS_ERR_OPENLOCAL), localPath);
        SplU8TrimTornTail(msg);
        SalamanderGeneral->SalMessageBox(ctx->Parent, msg, LoadStr(IDS_SFTPERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
        return FALSE;
    }

    LIBSSH2_SFTP_HANDLE* h = ctx->Session->OpenWrite(remotePath, 0644, FALSE);
    if (h == NULL)
    {
        CloseHandle(lf);
        char msg[1200];
        _snprintf_s(msg, _TRUNCATE, LoadStrU8(IDS_ERR_UPLOAD), CSFTPMsgText(remotePath).Get(), ctx->Session->GetLastErrorText());
        SplU8TrimTornTail(msg);
        SalamanderGeneral->SalMessageBox(ctx->Parent, msg, LoadStr(IDS_SFTPERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
        return FALSE;
    }

    BOOL ok = TRUE;
    for (;;)
    {
        if (ctx->CheckCancel())
        {
            ok = FALSE;
            break;
        }
        DWORD read = 0;
        if (!ReadFile(lf, ctx->Buffer, XFER_BUFSIZE, &read, NULL))
        {
            ok = FALSE;
            break;
        }
        if (read == 0)
            break;
        // libssh2_sftp_write may accept a partial buffer; loop until all written
        int off = 0;
        while (off < (int)read)
        {
            __int64 w = ctx->Session->Write(h, ctx->Buffer + off, (int)read - off);
            if (w < 0)
            {
                ok = FALSE;
                SalamanderGeneral->SalMessageBox(ctx->Parent, LoadStr(IDS_ERR_WRITEREMOTE),
                                                 LoadStr(IDS_SFTPERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
                break;
            }
            off += (int)w;
        }
        if (!ok)
            break;
    }
    ctx->Session->CloseHandle(h);
    CloseHandle(lf);
    return ok;
}

static BOOL UploadDirRecursive(COperationCtx* ctx, const char* localDir, const char* remoteDir, int depth)
{
    if (depth > SFTP_MAX_RECURSION) // CF-5
    {
        SalamanderGeneral->SalMessageBox(ctx->Parent, LoadStr(IDS_ERR_TOODEEP),
                                         LoadStr(IDS_SFTPERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
        return FALSE;
    }
    // CF-6: never traverse a local reparse point (junction/dir-symlink). Following
    // it would pull in files from outside the selected tree, and the paired
    // move-delete (DeleteLocalTree) would then destroy the link target's contents.
    wchar_t wself[4096];
    MakeLocalWidePath(localDir, wself, 4096);
    DWORD selfAttr = GetFileAttributesW(wself);
    if (selfAttr != INVALID_FILE_ATTRIBUTES && (selfAttr & FILE_ATTRIBUTE_REPARSE_POINT))
        return TRUE; // skip the link; nothing to upload

    ctx->Session->Mkdir(remoteDir, 0755); // ignore "already exists"

    wchar_t wpattern[4096];
    char pattern[4096];
    _snprintf_s(pattern, _TRUNCATE, "%s\\*", localDir);
    MakeLocalWidePath(pattern, wpattern, 4096);

    WIN32_FIND_DATAW fd;
    HANDLE hFind = FindFirstFileW(wpattern, &fd);
    if (hFind == INVALID_HANDLE_VALUE)
        return TRUE;

    BOOL ok = TRUE;
    do
    {
        if (ctx->CheckCancel())
        {
            ok = FALSE;
            break;
        }
        if (wcscmp(fd.cFileName, L".") == 0 || wcscmp(fd.cFileName, L"..") == 0)
            continue;
        char name[1024];
        WideToUtf8(fd.cFileName, name, sizeof(name));
        char lpath[4096], rpath[4096];
        _snprintf_s(lpath, _TRUNCATE, "%s\\%s", localDir, name);
        PosixPathAppend(remoteDir, name, rpath, sizeof(rpath));
        if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
        {
            if (!UploadDirRecursive(ctx, lpath, rpath, depth + 1))
                ok = FALSE;
        }
        else
        {
            WaitText("Uploading %s ...", name);
            if (!UploadOneFile(ctx, lpath, rpath))
                ok = FALSE;
        }
    } while (FindNextFileW(hFind, &fd));
    FindClose(hFind);
    return ok;
}

// recursively deletes a local directory tree (for move disk->FS)
static void DeleteLocalTree(const char* localDir, int depth)
{
    if (depth > SFTP_MAX_RECURSION) // CF-5
        return;
    wchar_t wdir[4096];
    MakeLocalWidePath(localDir, wdir, 4096);
    // CF-6: if this directory is a reparse point (junction/dir-symlink), remove
    // only the link - descending would delete the link TARGET's contents, which
    // live outside the moved tree. Each recursion level re-checks, so nested
    // links are handled too.
    DWORD selfAttr = GetFileAttributesW(wdir);
    if (selfAttr != INVALID_FILE_ATTRIBUTES && (selfAttr & FILE_ATTRIBUTE_REPARSE_POINT))
    {
        RemoveDirectoryW(wdir);
        return;
    }
    wchar_t wpattern[4096];
    char pattern[4096];
    _snprintf_s(pattern, _TRUNCATE, "%s\\*", localDir);
    MakeLocalWidePath(pattern, wpattern, 4096);
    WIN32_FIND_DATAW fd;
    HANDLE hFind = FindFirstFileW(wpattern, &fd);
    if (hFind != INVALID_HANDLE_VALUE)
    {
        do
        {
            if (wcscmp(fd.cFileName, L".") == 0 || wcscmp(fd.cFileName, L"..") == 0)
                continue;
            char name[1024], child[4096];
            WideToUtf8(fd.cFileName, name, sizeof(name));
            _snprintf_s(child, _TRUNCATE, "%s\\%s", localDir, name);
            wchar_t wchild[4096];
            MakeLocalWidePath(child, wchild, 4096);
            if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
                DeleteLocalTree(child, depth + 1);
            else
                DeleteFileW(wchild);
        } while (FindNextFileW(hFind, &fd));
        FindClose(hFind);
    }
    RemoveDirectoryW(wdir);
}

BOOL SFTPUploadToFS(HWND parent, CSFTPSession* session, const char* sourcePath,
                    SalEnumSelection2 next, void* nextParam, const char* targetRemoteDir, BOOL move)
{
    COperationCtx ctx(parent, session);
    SalamanderGeneral->CreateSafeWaitWindow(LoadStr(IDS_PLUGINNAME), LoadStr(IDS_PLUGINNAME), 500, TRUE,
                                            SalamanderGeneral->GetMainWindowHWND());
    BOOL ok = TRUE;

    // the enumerator returns names relative to 'sourcePath'; ensure a separator
    char srcBase[3072];
    lstrcpynA(srcBase, sourcePath, sizeof(srcBase));
    SalamanderGeneral->SalPathAddBackslash(srcBase, sizeof(srcBase));

    next(NULL, -1, NULL, NULL, NULL, NULL, NULL, nextParam, NULL); // reset enumeration
    BOOL isDir = FALSE;
    int err = 0;
    const char* name;
    while ((name = next(parent, 0, NULL, &isDir, NULL, NULL, NULL, nextParam, &err)) != NULL)
    {
        if (ctx.CheckCancel())
        {
            ok = FALSE;
            break;
        }
        char lpath[4096], rpath[4096];
        _snprintf_s(lpath, _TRUNCATE, "%s%s", srcBase, name);
        PosixPathAppend(targetRemoteDir, PosixBaseName(name), rpath, sizeof(rpath));
        BOOL itemOk;
        if (isDir)
            itemOk = UploadDirRecursive(&ctx, lpath, rpath, 0);
        else
        {
            WaitText("Uploading %s ...", name);
            itemOk = UploadOneFile(&ctx, lpath, rpath);
        }
        if (!itemOk)
            ok = FALSE;
        else if (move) // delete the local source only after a fully successful upload
        {
            wchar_t wl[4096];
            MakeLocalWidePath(lpath, wl, 4096);
            if (isDir)
                DeleteLocalTree(lpath, 0);
            else
                DeleteFileW(wl);
        }
    }
    if (err == SALENUM_CANCEL)
        ok = FALSE;

    SalamanderGeneral->DestroySafeWaitWindow();
    return ok && !ctx.Cancelled;
}

// ---------------------------------------------------------------------------
// delete
// ---------------------------------------------------------------------------

static BOOL DeleteRecursive(COperationCtx* ctx, const char* remotePath, unsigned long mode, BOOL isLink, int depth)
{
    if (ctx->CheckCancel())
        return FALSE;
    if (depth > SFTP_MAX_RECURSION) // CF-5
    {
        SalamanderGeneral->SalMessageBox(ctx->Parent, LoadStr(IDS_ERR_TOODEEP),
                                         LoadStr(IDS_SFTPERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
        return FALSE;
    }

    if (!isLink && SFTP_S_ISDIR(mode))
    {
        TIndirectArray<CSFTPDirEntry> entries(64, 64);
        if (ctx->Session->ListDir(remotePath, &entries, &ctx->Cancelled))
        {
            for (int i = 0; i < entries.Count && !ctx->CheckCancel(); i++)
            {
                CSFTPDirEntry* e = entries[i];
                char child[4096];
                PosixPathAppend(remotePath, e->Name, child, sizeof(child));
                BOOL childLink = e->HasMode && SFTP_S_ISLNK(e->Mode);
                DeleteRecursive(ctx, child, e->Mode, childLink, depth + 1);
            }
        }
        if (!ctx->Session->Rmdir(remotePath))
        {
            char msg[1200];
            _snprintf_s(msg, _TRUNCATE, LoadStrU8(IDS_ERR_RMDIR), CSFTPMsgText(remotePath).Get(), ctx->Session->GetLastErrorText());
            SplU8TrimTornTail(msg);
            SalamanderGeneral->SalMessageBox(ctx->Parent, msg, LoadStr(IDS_SFTPERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
            return FALSE;
        }
    }
    else
    {
        if (!ctx->Session->Unlink(remotePath))
        {
            char msg[1200];
            _snprintf_s(msg, _TRUNCATE, LoadStrU8(IDS_ERR_DELETE), CSFTPMsgText(remotePath).Get(), ctx->Session->GetLastErrorText());
            SplU8TrimTornTail(msg);
            SalamanderGeneral->SalMessageBox(ctx->Parent, msg, LoadStr(IDS_SFTPERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
            return FALSE;
        }
    }
    return TRUE;
}

BOOL SFTPDeleteFromPanel(HWND parent, CSFTPSession* session, int panel, const char* remoteDir)
{
    COperationCtx ctx(parent, session);
    SalamanderGeneral->CreateSafeWaitWindow(LoadStr(IDS_PLUGINNAME), LoadStr(IDS_PLUGINNAME), 500, TRUE,
                                            SalamanderGeneral->GetMainWindowHWND());
    BOOL ok = TRUE;

    TIndirectArray<CSFTPDirEntry> items(16, 16);
    CollectPanelItems(panel, &items);

    for (int i = 0; i < items.Count && !ctx.CheckCancel(); i++)
    {
        CSFTPDirEntry* e = items[i];
        char rpath[4096];
        PosixPathAppend(remoteDir, e->Name, rpath, sizeof(rpath));
        WaitText("Deleting %s ...", e->Name);
        BOOL isLink = e->HasMode && SFTP_S_ISLNK(e->Mode);
        if (!DeleteRecursive(&ctx, rpath, e->Mode, isLink, 0))
            ok = FALSE;
    }

    SalamanderGeneral->DestroySafeWaitWindow();
    return ok && !ctx.Cancelled;
}

// ---------------------------------------------------------------------------
// chmod
// ---------------------------------------------------------------------------

static void ChmodRecursive(COperationCtx* ctx, const char* remotePath, unsigned long mode,
                           BOOL isDir, BOOL recurse, int depth)
{
    if (ctx->CheckCancel())
        return;
    if (depth > SFTP_MAX_RECURSION) // CF-5
        return;
    if (!ctx->Session->Chmod(remotePath, mode))
    {
        char msg[1200];
        _snprintf_s(msg, _TRUNCATE, LoadStrU8(IDS_ERR_CHMOD), CSFTPMsgText(remotePath).Get(), ctx->Session->GetLastErrorText());
        SplU8TrimTornTail(msg);
        Logs.Append(ctx->Session->GetLogUID(), msg);
    }
    if (isDir && recurse)
    {
        TIndirectArray<CSFTPDirEntry> entries(64, 64);
        if (ctx->Session->ListDir(remotePath, &entries, &ctx->Cancelled))
        {
            for (int i = 0; i < entries.Count && !ctx->CheckCancel(); i++)
            {
                CSFTPDirEntry* e = entries[i];
                if (e->HasMode && SFTP_S_ISLNK(e->Mode))
                    continue; // do not chmod through symlinks
                char child[4096];
                PosixPathAppend(remotePath, e->Name, child, sizeof(child));
                ChmodRecursive(ctx, child, mode, SFTP_S_ISDIR(e->Mode), recurse, depth + 1);
            }
        }
    }
}

BOOL SFTPChangeAttrsFromPanel(HWND parent, CSFTPSession* session, int panel, const char* remoteDir)
{
    // Collect the working set FIRST (real remote names) - the panel CFileData
    // pointers are invalidated once the modal chmod dialog pumps messages, so we
    // must not dereference them afterwards.
    TIndirectArray<CSFTPDirEntry> items(16, 16);
    CollectPanelItems(panel, &items);
    if (items.Count == 0)
        return FALSE;

    // seed the dialog mode/label from the collected copy (not a live pointer)
    unsigned long mode = 0644;
    char label[256];
    if (items[0]->HasMode)
        mode = items[0]->Mode & 07777;
    lstrcpynA(label, items[0]->Name, sizeof(label));
    BOOL multiple = items.Count > 1;
    if (multiple)
        _snprintf_s(label, _TRUNCATE, "%d item(s)", items.Count);

    BOOL recurse = FALSE, setTime = FALSE;
    __int64 mtime = 0;
    if (!ShowChmodDialog(parent, label, multiple, &mode, &recurse, &setTime, &mtime))
        return FALSE;

    COperationCtx ctx(parent, session);
    SalamanderGeneral->CreateSafeWaitWindow(LoadStr(IDS_PLUGINNAME), LoadStr(IDS_PLUGINNAME), 500, TRUE,
                                            SalamanderGeneral->GetMainWindowHWND());

    for (int i = 0; i < items.Count && !ctx.CheckCancel(); i++)
    {
        CSFTPDirEntry* e = items[i];
        char rpath[4096];
        PosixPathAppend(remoteDir, e->Name, rpath, sizeof(rpath));
        BOOL itemIsDir = e->HasMode && SFTP_S_ISDIR(e->Mode);
        ChmodRecursive(&ctx, rpath, mode, itemIsDir, recurse, 0);
        if (setTime)
            session->SetMTime(rpath, mtime);
    }

    SalamanderGeneral->DestroySafeWaitWindow();
    return TRUE;
}

// feature 018: change owner/group of one item, recursing into a directory
// subtree when requested (mirrors ChmodRecursive; skips symlinks).
static void ChownRecursive(COperationCtx* ctx, const char* remotePath,
                           unsigned long uid, unsigned long gid, BOOL setUid, BOOL setGid,
                           BOOL isDir, BOOL recurse, int depth)
{
    if (ctx->CheckCancel())
        return;
    if (depth > SFTP_MAX_RECURSION) // CF-5
        return;
    if (!ctx->Session->Chown(remotePath, uid, gid, setUid, setGid))
    {
        char msg[1200];
        _snprintf_s(msg, _TRUNCATE, LoadStrU8(IDS_ERR_CHOWN), CSFTPMsgText(remotePath).Get(), ctx->Session->GetLastErrorText());
        SplU8TrimTornTail(msg);
        Logs.Append(ctx->Session->GetLogUID(), msg);
    }
    if (isDir && recurse)
    {
        TIndirectArray<CSFTPDirEntry> entries(64, 64);
        if (ctx->Session->ListDir(remotePath, &entries, &ctx->Cancelled))
        {
            for (int i = 0; i < entries.Count && !ctx->CheckCancel(); i++)
            {
                CSFTPDirEntry* e = entries[i];
                if (e->HasMode && SFTP_S_ISLNK(e->Mode))
                    continue; // do not chown through symlinks
                char child[4096];
                PosixPathAppend(remotePath, e->Name, child, sizeof(child));
                ChownRecursive(ctx, child, uid, gid, setUid, setGid, SFTP_S_ISDIR(e->Mode), recurse, depth + 1);
            }
        }
    }
}

BOOL SFTPChangeOwnerFromPanel(HWND parent, CSFTPSession* session, int panel, const char* remoteDir)
{
    // snapshot the selection BEFORE the modal dialog (panel CFileData go stale
    // once the dialog pumps messages) - same rule as SFTPChangeAttrsFromPanel
    TIndirectArray<CSFTPDirEntry> items(16, 16);
    CollectPanelItems(panel, &items);
    if (items.Count == 0)
        return FALSE;

    char label[256];
    lstrcpynA(label, items[0]->Name, sizeof(label));
    BOOL multiple = items.Count > 1;
    if (multiple)
        _snprintf_s(label, _TRUNCATE, "%d item(s)", items.Count);

    BOOL hasDir = FALSE;
    for (int i = 0; i < items.Count; i++)
        if (items[i]->HasMode && SFTP_S_ISDIR(items[i]->Mode))
        {
            hasDir = TRUE;
            break;
        }

    unsigned long uid = items[0]->Uid, gid = items[0]->Gid;
    BOOL setUid = FALSE, setGid = FALSE, recurse = FALSE;
    if (!ShowOwnerGroupDialog(parent, label, hasDir, &uid, &setUid, &gid, &setGid, &recurse))
        return FALSE;

    COperationCtx ctx(parent, session);
    SalamanderGeneral->CreateSafeWaitWindow(LoadStr(IDS_PLUGINNAME), LoadStr(IDS_PLUGINNAME), 500, TRUE,
                                            SalamanderGeneral->GetMainWindowHWND());

    for (int i = 0; i < items.Count && !ctx.CheckCancel(); i++)
    {
        CSFTPDirEntry* e = items[i];
        char rpath[4096];
        PosixPathAppend(remoteDir, e->Name, rpath, sizeof(rpath));
        BOOL itemIsDir = e->HasMode && SFTP_S_ISDIR(e->Mode);
        ChownRecursive(&ctx, rpath, uid, gid, setUid, setGid, itemIsDir, recurse, 0);
    }

    SalamanderGeneral->DestroySafeWaitWindow();
    return TRUE;
}
