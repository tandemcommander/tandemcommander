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

#include "../../common/salrandom.h"      // feature 139: SalGenRandom (the temporary name of an upload)
#include "../../common/salsamefile.h"    // feature 139: the identity of the files a download wrote
#include "../../common/salsafereplace.h" // feature 139: a local file is replaced only by a complete one
#include "../../common/salnameorder.h"   // feature 205: the file system's name rule
#include "splshortname.h"                // feature 205: a local name that is only another entry's short name

#define XFER_BUFSIZE (256 * 1024)

// CF-5: cap recursion so a maliciously/accidentally deep directory tree (server-
// or local-side) cannot exhaust the stack and crash the whole process.
// feature 139: the numbers. The operations run on the program's main thread, whose stack is
// 3 MB (StackReserveSize in src/vcxproj/sal_base.props), a part of it used before the plug-in
// is called. The earlier note here ("nowhere near the ~1 MB stack limit") was wrong for the
// transfers: an upload kept about 30 KB of path buffers per level on the stack (128 levels =
// 3.8 MB - a local tree about 90 levels deep overflowed it), a download about 17 KB (2.2 MB).
// Both now keep the per-level buffers in one heap block (CUploadLevel, CDownloadLevel) and a
// level costs a few hundred bytes of stack; delete / chmod / chown keep one 4 KB path per
// level (0.5 MB at the limit).
#define SFTP_MAX_RECURSION 128

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

// feature 131: UTF-8 as the core hands it (WTF-8: a local name with an unpaired surrogate
// converts back to that name; it became U+FFFD characters = a name that does not exist).
// A text that is not UTF-8 at all (a remote name in another encoding) is still converted
// leniently as before, so that such a file can be stored locally.
static BOOL Utf8ToWide(const char* s, wchar_t* out, int outCount)
{
    if (SplU8ToW(s, out, outCount) > 0)
        return TRUE;
    return MultiByteToWideChar(CP_UTF8, 0, s, -1, out, outCount) > 0;
}

// feature 131: total (an unpaired surrogate is kept as WTF-8); FALSE = does not fit, 'out' empty
static BOOL WideToUtf8(const wchar_t* s, char* out, int outCount)
{
    return SplWToU8(s, out, outCount) > 0;
}

// builds a Windows long-path-capable wide path from a UTF-8 path
static void MakeLocalWidePath(const char* utf8Path, wchar_t* wide, int wideCount)
{
    // CF-18: leave an empty (invalid) path if the conversion fails, so a caller
    // that does not check gets a clean CreateFileW error instead of operating on
    // an uninitialized stack buffer.
    if (wideCount > 0)
        wide[0] = 0;
    if (!Utf8ToWide(utf8Path, wide, wideCount) && wideCount > 0)
        wide[0] = 0; // a failed conversion may have written a part of the path
}

// Makes a single remote name component safe to use as a local file name:
// replaces path separators and Windows-invalid characters with '_'. Prevents a
// malicious/compromised server from escaping the target directory via a name
// containing '\' or ':' (POSIX only reserves '/').
// feature 131: returns FALSE ('out' empty) when the name does not fit 'out' - a name is
// never cut (the cut name is another local file); the caller skips the item.
static BOOL SanitizeLocalName(const char* name, char* out, int outSize)
{
    if (strlen(name) >= (size_t)outSize)
    {
        out[0] = 0;
        return FALSE;
    }
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
        return TRUE;
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
        return TRUE;
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
            int n = _snprintf_s(tmp, _TRUNCATE, "_%s", out);
            if (n < 0 || n >= outSize) // the added '_' does not fit
            {
                out[0] = 0;
                return FALSE;
            }
            lstrcpynA(out, tmp, outSize);
            break;
        }
    }
    return TRUE;
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
    BOOL TooLongShown; // feature 131: the "too long path" box was shown in this operation
    // feature 138: the local files this operation has written. Two remote names can land on
    // ONE local file - names that differ in case, in characters Windows cannot hold (a:b /
    // a?b -> a_b), in trailing dots, an 8.3 alias. The second download would overwrite (or
    // "resume") the first, and a move would then remove both sources with one content left.
    // A file of this list is never written again.
    // feature 139: each is remembered by the file system's identity (salsamefile.h: the
    // 128-bit id where there is one, all-zero ids not taken for an id) AND by its path. The
    // hand-made volume + index pair refused every overwrite on a volume that reports zero
    // ids, and a file whose identity could not be read made a complete download fail as
    // "not enough memory". Where the ids cannot tell, the path does (compared like names of
    // the file system: ordinal, any case).
    struct CWrittenFile
    {
        CSalFileIdentity Id; // Valid FALSE: could not be read - the path alone is compared
        wchar_t* Path;       // the final local path (malloc)
        CWrittenFile* Next;
    };
    CWrittenFile* Written;
    BOOL WrittenLost;         // feature 139: a written file could not be remembered (low memory): nothing is overwritten any more
    BOOL RemovalRefusedShown; // feature 138: a source could not be removed - said once, then only logged
    BOOL LinkSkippedShown;    // feature 139: a link folder was skipped by an upload - said once, then only logged
    BOOL ConnLostShown;       // feature 139: the user was told that the connection is gone (see ReportSessionLost)
    // feature 140: what the server refused in a change of attributes / owner. Every refusal is
    // in the log; the user gets ONE box after the operation (the first item, its reason, how
    // many more) - the command used to look successful.
    int RefusedCount;
    char* RefusedPath; // the first refused path (malloc; NULL also when it could not be kept)
    char RefusedReason[600];
    char Buffer[XFER_BUFSIZE];

    COperationCtx(HWND parent, CSFTPSession* session)
    {
        Parent = parent;
        Session = session;
        Cancelled = FALSE;
        OverwriteMode = ovAsk;
        TooLongShown = FALSE;
        Written = NULL;
        WrittenLost = FALSE;
        RemovalRefusedShown = FALSE;
        LinkSkippedShown = FALSE;
        ConnLostShown = FALSE;
        RefusedCount = 0;
        RefusedPath = NULL;
        RefusedReason[0] = 0;
    }
    ~COperationCtx()
    {
        free(RefusedPath);
        while (Written != NULL)
        {
            CWrittenFile* next = Written->Next;
            free(Written->Path);
            free(Written);
            Written = next;
        }
    }
    // remembers the local file 'wpath' (complete, in its final place) as written by this
    // operation; 'id' is its identity, read by the caller (not Valid = unknown). Never fails
    // the download: what cannot be remembered makes WasWritten answer TRUE from now on.
    void NoteWritten(const wchar_t* wpath, const CSalFileIdentity& id)
    {
        CWrittenFile* w = (CWrittenFile*)malloc(sizeof(CWrittenFile));
        wchar_t* path = _wcsdup(wpath);
        if (w == NULL || path == NULL)
        {
            free(w);
            free(path);
            WrittenLost = TRUE;
            return;
        }
        w->Id = id;
        w->Path = path;
        w->Next = Written;
        Written = w;
    }
    // is the existing local file 'wpath' one this operation wrote? TRUE also when that cannot
    // be found out (not everything checked = do not overwrite)
    BOOL WasWritten(const wchar_t* wpath)
    {
        if (WrittenLost)
            return TRUE;
        if (Written == NULL)
            return FALSE;
        // read through links, like the write that would follow; a file that cannot be opened
        // gives its metadata only - no ids, so the paths decide
        CSalFileIdentity id;
        if (!SalGetFileIdentityW(wpath, FALSE, &id))
            return TRUE;
        for (CWrittenFile* w = Written; w != NULL; w = w->Next)
        {
            int match = SalFileIdMatch(w->Id, id);
            if (match == simEqual)
                return TRUE;
            if (match == simUnknown && CompareStringOrdinal(w->Path, -1, wpath, -1, TRUE) == CSTR_EQUAL)
                return TRUE;
        }
        return FALSE;
    }
    BOOL CheckCancel()
    {
        if (!Cancelled && SalamanderGeneral->GetSafeWaitWindowClosePressed())
            Cancelled = TRUE;
        return Cancelled;
    }
    // feature 140: is the session gone (a request timed out, the transport broke)? From then
    // on the session answers no request, and the operation must stop: nothing more is asked,
    // nothing is removed or replaced on either side, and what a failed call "says" is not a
    // fact (a failed stat is not "no such file", a failed listing not "empty"). Every loop
    // asks before each item and after each failed request.
    BOOL SessionLost() { return !Session->IsConnected(); }
    // feature 140 (139 for the transfers): tells the user that the connection was lost - ONE
    // box per operation. Not shown when a failed item's own box has said it already
    // (ShowRequestError), and not for an operation the user stopped.
    void ReportSessionLost()
    {
        if (ConnLostShown || Cancelled)
            return;
        ConnLostShown = TRUE;
        char text[700]; // (UTF-8, like the texts of SFTPShowPathError)
        LostText(text, sizeof(text));
        Logs.Append(Session->GetLogUID(), text);
        SalamanderGeneral->SalMessageBox(Parent, text, LoadStr(IDS_SFTPERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
    }
    // the sentence about the lost connection: the session's text says it (with the library's
    // detail) from the request that ended it; should it hold something else, the plain sentence
    void LostText(char* buf, int bufSize)
    {
        char lost[300];
        SplU8CopyTrunc(lost, sizeof(lost), LoadStrU8(IDS_ERR_CONNLOST));
        const char* text = Session->GetLastErrorText();
        SplU8CopyTrunc(buf, bufSize, strncmp(text, lost, strlen(lost)) == 0 ? text : lost);
    }
    // feature 140: the server refused to change 'path' ('reason': why)
    void NoteRefused(const char* path, const char* reason)
    {
        if (RefusedCount++ == 0)
        {
            RefusedPath = _strdup(path);
            SplU8CopyTrunc(RefusedReason, sizeof(RefusedReason), reason != NULL ? reason : "");
        }
    }
};

static void WaitText(const char* fmt, const char* arg)
{
    char msg[1024];
    if (_snprintf_s(msg, _TRUNCATE, fmt, arg) < 0)
        SplU8TrimTornTail(msg); // shown only: cut at a whole character
    // reflect current file in the wait window title area via a fresh window
    SalamanderGeneral->DestroySafeWaitWindow();
    SalamanderGeneral->CreateSafeWaitWindow(msg, LoadStr(IDS_PLUGINNAME), 0, TRUE, SalamanderGeneral->GetMainWindowHWND());
}

// feature 131: a remote or local path that does not fit its buffer is never used in a
// shortened form (the shortened path names another file or directory): the item is skipped
// and the operation ends as failed. Every skipped item goes to the log; the box is shown
// once per operation (a deep tree would show it for every item).
static void ReportTooLongPath(COperationCtx* ctx, const char* dir, const char* name)
{
    Logs.AppendFmt(ctx->Session->GetLogUID(), "Path too long, item skipped: %s -> %s",
                   CSFTPMsgText(dir).Get(), CSFTPMsgText(name).Get());
    if (!ctx->TooLongShown)
    {
        ctx->TooLongShown = TRUE;
        SalamanderGeneral->SalMessageBox(ctx->Parent, LoadStr(IDS_TOOLONGPATH),
                                         LoadStr(IDS_SFTPERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
    }
}

// feature 139: is the session gone? Then nothing more is tried: every further item would wait
// for its own failure and show its own box. TRUE = not connected; 'what' (may be NULL) goes to
// the log. The box is shown once per operation - and not at all when the item that lost the
// connection has shown its error (ShowRequestError).
// feature 140: asked by every loop of every operation (it was the transfers only), before
// each item and after each failed request.
static BOOL StopIfSessionLost(COperationCtx* ctx, const char* what)
{
    if (!ctx->SessionLost())
        return FALSE;
    if (what != NULL)
        Logs.AppendFmt(ctx->Session->GetLogUID(), "Not connected, not done: %s", CSFTPMsgText(what).Get());
    ctx->ReportSessionLost();
    return TRUE;
}

void SFTPShowPathError(HWND parent, int fmtID, const char* path, const char* reason, int logUID)
{
    CSFTPMsgText text(path); // the server's bytes are not always UTF-8
    char* msg = SftpFormatMsgAlloc(LoadStrU8(fmtID), text.Get(), reason);
    SalamanderGeneral->SalMessageBox(parent, msg != NULL ? msg : LOW_MEMORY, LoadStr(IDS_SFTPERRORTITLE),
                                     MB_OK | MB_ICONEXCLAMATION);
    if (msg != NULL && logUID != -1)
        Logs.Append(logUID, msg);
    free(msg);
}

// feature 140: the error of a step that asked the server. While the session lives: the item's
// box, as before. Once the connection is lost, the operation shows ONE box about it, and this
// is the rule: the first failure met on the dead session shows its own box - the item, and as
// the reason that the connection was lost (the session's text; a reason of the caller's that
// says something else, e.g. where the complete new file was left, follows it) - and every
// later one goes to the log only. Where a step has no box of its own, ReportSessionLost shows
// the plain one instead; never both.
static void ShowRequestError(COperationCtx* ctx, int fmtID, const char* path, const char* reason)
{
    int logUID = ctx->Session->GetLogUID();
    if (!ctx->SessionLost())
    {
        SFTPShowPathError(ctx->Parent, fmtID, path, reason, logUID);
        return;
    }
    char lost[300];
    SplU8CopyTrunc(lost, sizeof(lost), LoadStrU8(IDS_ERR_CONNLOST));
    const char* sessionText = ctx->Session->GetLastErrorText();
    if (strncmp(sessionText, lost, strlen(lost)) != 0)
        sessionText = lost;
    char* both = NULL;
    if (reason == NULL || reason[0] == 0)
        reason = sessionText;
    else if (strstr(reason, lost) == NULL) // the caller's reason does not say it
    {
        both = SftpFormatMsgAlloc("%s - %s", sessionText, reason);
        if (both != NULL)
            reason = both;
    }
    if (!ctx->ConnLostShown)
    {
        ctx->ConnLostShown = TRUE;
        SFTPShowPathError(ctx->Parent, fmtID, path, reason, logUID);
    }
    else
    {
        CSFTPMsgText text(path);
        char* msg = SftpFormatMsgAlloc(LoadStrU8(fmtID), text.Get(), reason);
        if (msg != NULL)
            Logs.Append(logUID, msg);
        free(msg);
    }
    free(both);
}

// feature 139: the text of a system error as a piece of a UTF-8 message
static void ShowSysError(COperationCtx* ctx, int fmtID, const char* path, DWORD err)
{
    SFTPShowPathError(ctx->Parent, fmtID, path, CSFTPMsgText(SalamanderGeneral->GetErrorText(err)).Get(),
                      ctx->Session->GetLogUID());
}

#ifdef _DEBUG
// feature 139, probe seam (debug builds only): TC_SFTP_PROBE_XFER_FAIL = "<name suffix>;<bytes>"
// makes an upload or a download whose REMOTE path ends with <name suffix> fail - as if the
// write to / the read from the server returned an error - once <bytes> bytes of the file were
// transferred (0 = before the first byte; a file shorter than that is transferred whole).
// Returns the number of bytes, or -1 when the path does not match / the variable is not set.
static __int64 ProbeXferFailAfter(const char* remotePath)
{
    static BOOL loaded = FALSE;
    static char suffix[200];
    static __int64 bytes = -1;
    if (!loaded)
    {
        loaded = TRUE;
        suffix[0] = 0;
        char buf[300];
        DWORD n = GetEnvironmentVariableA("TC_SFTP_PROBE_XFER_FAIL", buf, sizeof(buf));
        if (n > 0 && n < sizeof(buf))
        {
            char* sep = strrchr(buf, ';');
            if (sep != NULL && sep != buf && (size_t)(sep - buf) < sizeof(suffix))
            {
                *sep = 0;
                lstrcpynA(suffix, buf, sizeof(suffix));
                bytes = _atoi64(sep + 1);
                if (bytes < 0)
                    bytes = -1;
            }
        }
    }
    if (bytes < 0 || suffix[0] == 0)
        return -1;
    size_t pl = strlen(remotePath), sl = strlen(suffix);
    if (pl < sl || strcmp(remotePath + pl - sl, suffix) != 0)
        return -1;
    return bytes;
}
#endif // _DEBUG

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
    char msg[4096 + 200]; // feature 131: room for the whole local path (the question itself was cut off)
    if (_snprintf_s(msg, _TRUNCATE, "The local file already exists:\n%s\n\nOverwrite it?\n"
                    "(Yes = this file, No = skip; hold nothing - use Cancel to skip the rest)", localPath) < 0)
        SplU8TrimTornTail(msg);
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

// feature 138: 'move' - the source will be removed after this download, so the local file must be
// on the disk for certain: flushed and closed without an error
// feature 140: 'knownKind' - what the path is with links followed (CSftpDownloadKind), when the
// caller knows: the listing's mode of an entry that is not a link, or the caller's own stat of
// a link. -1 = not known: it is asked here.
static CXferResult DownloadOneFileImpl(COperationCtx* ctx, const char* remotePath, const char* localPath,
                                       unsigned __int64 remoteSize, BOOL move, int knownKind);

static CXferResult DownloadOneFile(COperationCtx* ctx, const char* remotePath, const char* localPath,
                                   unsigned __int64 remoteSize, BOOL move, int knownKind)
{
    if (StopIfSessionLost(ctx, remotePath)) // feature 139: no further attempt (and box) per item
        return xrFailed;
    CXferResult res = DownloadOneFileImpl(ctx, remotePath, localPath, remoteSize, move, knownKind);
    // the item failed on a session that is gone: said once (its own box has done so already,
    // unless it failed without one); the caller stops
    if (res == xrFailed && ctx->SessionLost())
        ctx->ReportSessionLost();
    return res;
}

static CXferResult DownloadOneFileImpl(COperationCtx* ctx, const char* remotePath, const char* localPath,
                                       unsigned __int64 remoteSize, BOOL move, int knownKind)
{
    // feature 140: only a regular file is read. A device, a FIFO or a socket - also behind a
    // symbolic link - was opened like a file: the read of /dev/zero never ends, the open of a
    // FIFO never returns. What counts is the path with links FOLLOWED (the listing's mode of
    // a link is the link's own), known before anything is created or asked locally. Asked of
    // the server only when the caller does not know it. An answer the server does not give
    // (or one without a file type) changes nothing: the open reports.
    CSftpDownloadKind kind = sdkUnknown;
    if (knownKind >= 0)
        kind = (CSftpDownloadKind)knownKind;
    else
    {
        LIBSSH2_SFTP_ATTRIBUTES remoteAttrs;
        BOOL known = ctx->Session->Stat(remotePath, TRUE, &remoteAttrs);
        if (ctx->SessionLost()) // the request ended the session: not "the server gave no answer"
        {
            ShowRequestError(ctx, IDS_ERR_DOWNLOAD, remotePath, ctx->Session->GetLastErrorText());
            return xrFailed;
        }
        if (known)
            kind = SftpDownloadKind((remoteAttrs.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS) != 0, remoteAttrs.permissions);
    }
    if (kind == sdkSpecial)
    {
        SFTPShowPathError(ctx->Parent, IDS_ERR_DOWNLOAD, remotePath, "not a regular file (a device, FIFO or socket).",
                          ctx->Session->GetLogUID());
        return xrFailed; // (a move keeps it on the server)
    }

    wchar_t wlocal[4096];
    MakeLocalWidePath(localPath, wlocal, 4096);

    unsigned __int64 startOffset = 0;
    BOOL append = FALSE;
    BOOL existed = FALSE; // a local file of that name exists (and the user agreed to what follows)
    // feature 205: the local name is only another entry's short (8.3) name ("LONGFI~1.TXT" for
    // "longfilename.txt") - that file is not the target: the new file is made by the core, which
    // moves the other entry aside and back (or reports why it cannot); never offered, never replaced
    BOOL shortNameOfOther = FALSE;
    WIN32_FILE_ATTRIBUTE_DATA fad;
    if (GetFileAttributesExW(wlocal, GetFileExInfoStandard, &fad) && SplPathIsOnlyShortNameOfOther(localPath))
        shortNameOfOther = TRUE;
    else if (GetFileAttributesExW(wlocal, GetFileExInfoStandard, &fad) &&
             !(fad.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY))
    {
        existed = TRUE;
        // feature 138: the local file is one this operation has just written - another remote
        // name that lands on the same local file. It is not overwritten and not "resumed";
        // this item fails and its source stays on the server.
        if (ctx->WasWritten(wlocal))
        {
            SFTPShowPathError(ctx->Parent, IDS_ERR_DOWNLOAD, remotePath,
                              "another item of this operation was already saved under the same local name; this one is skipped.",
                              ctx->Session->GetLogUID());
            return xrFailed;
        }
        unsigned __int64 localSize = ((unsigned __int64)fad.nFileSizeHigh << 32) | fad.nFileSizeLow;
        // feature 138: no resume in a move - after it only the tail would be known to come from
        // the server, yet the source would be removed on a size match
        if (!move && localSize > 0 && localSize < remoteSize && localSize >= (unsigned __int64)Config.ResumeMinFileSize)
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
        // feature 139: a read-only local file cannot be replaced (nor resumed) - said here,
        // before the remote file is opened, not after the whole download. After the question:
        // "No" and "skip the rest" stay silent skips.
        if (fad.dwFileAttributes & FILE_ATTRIBUTE_READONLY)
        {
            SFTPShowPathError(ctx->Parent, IDS_ERR_DOWNLOAD, remotePath,
                              "the local file of that name is read-only.", ctx->Session->GetLogUID());
            return xrFailed;
        }
    }

    LIBSSH2_SFTP_HANDLE* h = ctx->Session->OpenRead(remotePath);
    if (h == NULL)
    {
        ShowRequestError(ctx, IDS_ERR_DOWNLOAD, remotePath, ctx->Session->GetLastErrorText());
        return xrFailed;
    }

    // feature 139: an existing local file that is replaced (not resumed) keeps its content until
    // the new content has arrived whole: the data go into a temporary file beside it, which
    // takes its place at the end (salsafereplace.h). The file itself used to be truncated at
    // once, and deleted when the download failed - nothing was left. Only where no temporary
    // file can be made in that folder is the file written in place as before (said in the log).
    WCHAR* tempPath = NULL; // not NULL: the data are written there
    HANDLE lf = INVALID_HANDLE_VALUE;
    if (existed && !append)
    {
        DWORD tempErr = ERROR_SUCCESS;
        if (!SalCreateTempNextToW(wlocal, L"tcp", &tempPath, &lf, &tempErr))
        {
            tempPath = NULL;
            lf = INVALID_HANDLE_VALUE;
            Logs.AppendFmt(ctx->Session->GetLogUID(),
                           "No temporary file could be created next to %s (error %u); the file is overwritten in place.",
                           localPath, (unsigned)tempErr);
        }
    }
    DWORD shortNameErr = ERROR_SUCCESS; // feature 205: why that file could not be made
    if (shortNameOfOther)               // feature 205: a new file of its own (append and tempPath are not set)
    {
        lf = SalamanderGeneral->SalCreateFileEx(localPath, GENERIC_WRITE, 0, FILE_ATTRIBUTE_NORMAL, &shortNameErr);
        if (lf == INVALID_HANDLE_VALUE)
            Logs.AppendFmt(ctx->Session->GetLogUID(),
                           "%s is the short name of another local entry; the file of its own was not made (error %u).",
                           localPath, (unsigned)shortNameErr);
    }
    else if (tempPath == NULL)
    {
        lf = CreateFileW(wlocal, GENERIC_WRITE, 0, NULL,
                         append ? OPEN_EXISTING : CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    }
    if (lf == INVALID_HANDLE_VALUE)
    {
        ctx->Session->CloseHandle(h);
        if (shortNameOfOther) // feature 205: the reason of the core's create (the other entry held open, ...)
        {
            CSFTPMsgText err(SalamanderGeneral->GetErrorText(shortNameErr));
            char why[600]; // no path in it: a path is never cut
            _snprintf_s(why, _TRUNCATE, "the local name is the short name of another entry, which could not be moved aside: %s",
                        err.Get());
            SFTPShowPathError(ctx->Parent, IDS_ERR_DOWNLOAD, remotePath, why, ctx->Session->GetLogUID());
        }
        else
            SFTPShowPathError(ctx->Parent, IDS_ERR_OPENLOCAL, localPath, NULL);
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
#ifdef _DEBUG
    __int64 probeFailAfter = ProbeXferFailAfter(remotePath);
    unsigned __int64 probeGot = 0; // bytes read from the server in this call
#endif
    for (;;)
    {
        if (ctx->CheckCancel())
        {
            res = xrFailed;
            break;
        }
        int want = XFER_BUFSIZE;
        BOOL probeFail = FALSE;
#ifdef _DEBUG
        if (probeFailAfter >= 0) // the seam: exactly that many bytes arrive, then the read "fails"
        {
            unsigned __int64 left = probeGot < (unsigned __int64)probeFailAfter ? (unsigned __int64)probeFailAfter - probeGot : 0;
            if (left == 0)
                probeFail = TRUE;
            else if (left < (unsigned __int64)want)
                want = (int)left;
        }
#endif
        __int64 n = probeFail ? -1 : ctx->Session->Read(h, ctx->Buffer, want);
#ifdef _DEBUG
        if (n > 0)
            probeGot += (unsigned __int64)n;
#endif
        if (n < 0)
        {
            res = xrFailed;
            if (ctx->SessionLost()) // feature 140: that is the reason then - one box per operation
                ShowRequestError(ctx, IDS_ERR_DOWNLOAD, remotePath, ctx->Session->GetLastErrorText());
            else
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
    DWORD writeErr = ERROR_SUCCESS;
    // feature 139: the identity of the file written in place, while it is open (see
    // COperationCtx::Written). One that cannot be read stays "unknown" - the path is remembered.
    CSalFileIdentity writtenId;
    SalFileIdentityClear(&writtenId);
    if (res == xrOk && tempPath == NULL)
        SalFileIdentityFromHandle(lf, &writtenId);
    // flushed before it counts: for a move (the source is removed afterwards, feature 138) and
    // for a temporary file (it replaces the user's file, feature 139)
    if ((move || tempPath != NULL) && res == xrOk && !FlushFileBuffers(lf))
        writeErr = GetLastError();
    if (!CloseHandle(lf) && writeErr == ERROR_SUCCESS)
        writeErr = GetLastError();
    if (res == xrOk && writeErr != ERROR_SUCCESS) // feature 138: not reported before - the copy counted as complete
    {
        res = xrFailed;
        ShowSysError(ctx, IDS_ERR_DOWNLOAD, remotePath, writeErr);
    }
    ctx->Session->CloseHandle(h);

    if (tempPath != NULL)
    {
        BOOL keepTemp = FALSE;
        if (res == xrOk)
        {
            // the complete, closed temporary file takes the place of the user's file
            DWORD repErr = ERROR_SUCCESS;
            CSalReplaceResult rr = SalReplaceWithTempW(wlocal, tempPath, TRUE, FALSE, &repErr);
            if (rr == srrLeftAtTemp)
            {
                // the old file is gone (someone else's doing) and the new content could not be
                // moved to its name: it is the only copy - kept and named, never deleted
                keepTemp = TRUE;
                res = xrFailed;
                char tempU8[4096];
                char reason[4096 + 400];
                if (!WideToUtf8(tempPath, tempU8, sizeof(tempU8)))
                    lstrcpynA(tempU8, "a temporary file next to it", sizeof(tempU8));
                if (_snprintf_s(reason, _TRUNCATE, "%s The complete download was left as: %s",
                                CSFTPMsgText(SalamanderGeneral->GetErrorText(repErr)).Get(), tempU8) < 0)
                    SplU8TrimTornTail(reason);
                SFTPShowPathError(ctx->Parent, IDS_ERR_DOWNLOAD, remotePath, reason, ctx->Session->GetLogUID());
            }
            else if (rr != srrDone) // srrFailedKept: the old file is as it was; srrFailedBothGone: nothing is left
            {
                res = xrFailed;
                ShowSysError(ctx, IDS_ERR_DOWNLOAD, remotePath, repErr);
            }
            else
                SalGetFileIdentityW(wlocal, FALSE, &writtenId); // the file now in place (FALSE leaves it "unknown")
        }
        // a failed or stopped download: only the temporary file goes - the user's file keeps
        // its old content (it used to be deleted here)
        if (res != xrOk && !keepTemp)
            DeleteFileW(tempPath);
        free(tempPath);
    }
    else
    {
        // CF-17: a freshly created/truncated target left partial on cancel/error
        // would replace the user's original file with garbage - remove it. (Append/
        // resume keeps the file, since the original bytes are still valid.)
        // feature 139: reached for a NEW local file, and for an existing one only when no
        // temporary file could be created beside it.
        if (res == xrFailed && !append)
            DeleteFileW(wlocal);
    }
    if (res == xrOk)
        ctx->NoteWritten(wlocal, writtenId); // the FINAL file
    return res;
}

static CXferResult DownloadRecursive(COperationCtx* ctx, const char* remotePath, const char* localPath,
                                     unsigned long mode, BOOL isLink, unsigned __int64 size, int depth, BOOL move);

// feature 138: a source of a move that stays on the server: every one goes to the log, the box
// is shown once per operation (an account that may not delete would show it for every file)
static void ReportNotRemoved(COperationCtx* ctx, int fmtID, const char* remotePath, const char* reason)
{
    if (ctx->SessionLost()) // feature 140: not a refusal - the connection is gone (one box per operation)
    {
        ShowRequestError(ctx, fmtID, remotePath, reason);
        return;
    }
    if (!ctx->RemovalRefusedShown)
    {
        ctx->RemovalRefusedShown = TRUE;
        SFTPShowPathError(ctx->Parent, fmtID, remotePath, reason, ctx->Session->GetLogUID());
        return;
    }
    CSFTPMsgText text(remotePath);
    char* msg = SftpFormatMsgAlloc(LoadStrU8(fmtID), text.Get(), reason);
    if (msg != NULL)
        Logs.Append(ctx->Session->GetLogUID(), msg);
    free(msg);
}

// feature 138: the source file of a move is removed from the server - after its download ended
// without an error and ONLY when the local copy is as long as the server says the source is
// (asked again now). Returns FALSE when the source stays (said in a message; the local copy
// stays too). A move used to remove top-level files without this check, and nothing inside a
// directory at all - a moved directory stayed on the server whole, without a word.
static BOOL RemoveMovedFile(COperationCtx* ctx, const char* remotePath, const char* localPath)
{
    // feature 140: nothing is removed once the connection is lost (the close of the downloaded
    // file may have been the request that timed out). The stat below cannot be answered by a
    // dead session either - "not known" keeps the source.
    if (StopIfSessionLost(ctx, remotePath))
        return FALSE;
    wchar_t wlocal[4096];
    MakeLocalWidePath(localPath, wlocal, 4096);
    WIN32_FILE_ATTRIBUTE_DATA fad;
    BOOL localKnown = GetFileAttributesExW(wlocal, GetFileExInfoStandard, &fad) &&
                      !(fad.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY);
    unsigned __int64 localSize = localKnown ? (((unsigned __int64)fad.nFileSizeHigh << 32) | fad.nFileSizeLow) : 0;
    LIBSSH2_SFTP_ATTRIBUTES attrs;
    BOOL remoteKnown = ctx->Session->Stat(remotePath, TRUE, &attrs) && (attrs.flags & LIBSSH2_SFTP_ATTR_SIZE) != 0;
    if (!SftpMoveMayRemove(TRUE, localKnown, localSize, remoteKnown, remoteKnown ? attrs.filesize : 0))
    {
        // (the reason is a fixed English text, like the server's own reasons)
        ReportNotRemoved(ctx, IDS_ERR_DELETE, remotePath,
                         "the local copy could not be confirmed complete; the file stays on the server.");
        return FALSE;
    }
    if (!ctx->Session->Unlink(remotePath))
    {
        ReportNotRemoved(ctx, IDS_ERR_DELETE, remotePath, ctx->Session->GetLastErrorText());
        return FALSE;
    }
    return TRUE;
}

// feature 139: the path buffers of one directory level of a download - one heap block per
// level instead of about 17 KB of stack (see SFTP_MAX_RECURSION)
struct CDownloadLevel
{
    wchar_t WDir[4096];
    char RPath[4096];
    char LPath[4096];
    char Safe[512];
};

static CXferResult DownloadDirLevel(COperationCtx* ctx, const char* remoteDir, const char* localDir, int depth,
                                    BOOL move, CDownloadLevel* lv);

static CXferResult DownloadDir(COperationCtx* ctx, const char* remoteDir, const char* localDir, int depth, BOOL move)
{
    if (depth > SFTP_MAX_RECURSION) // CF-5
    {
        SalamanderGeneral->SalMessageBox(ctx->Parent, LoadStr(IDS_ERR_TOODEEP),
                                         LoadStr(IDS_SFTPERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
        return xrFailed;
    }
    CDownloadLevel* lv = (CDownloadLevel*)malloc(sizeof(CDownloadLevel));
    if (lv == NULL)
    {
        SalamanderGeneral->SalMessageBox(ctx->Parent, LOW_MEMORY, LoadStr(IDS_SFTPERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
        return xrFailed;
    }
    CXferResult res = DownloadDirLevel(ctx, remoteDir, localDir, depth, move, lv);
    free(lv);
    return res;
}

static CXferResult DownloadDirLevel(COperationCtx* ctx, const char* remoteDir, const char* localDir, int depth,
                                    BOOL move, CDownloadLevel* lv)
{
    if (StopIfSessionLost(ctx, remoteDir)) // feature 139
        return xrFailed;
    wchar_t* wdir = lv->WDir;
    MakeLocalWidePath(localDir, wdir, 4096);
    // feature 205: made by the core - a name that is only another entry's short (8.3) name
    // ("LONGDI~1" for "longdirname") gets a folder of its own (the other entry moved aside and
    // back); the download never goes into the other folder. "Already exists" is fine for the
    // folder's own name - what counts is checked next
    DWORD crErr = ERROR_SUCCESS;
    BOOL crDone = SalamanderGeneral->SalCreateDirectoryEx(localDir, &crErr);
    BOOL notOwn = !crDone && SplPathIsOnlyShortNameOfOther(localDir); // the other folder kept that name

    // feature 138: the local directory must be there. Its creation was not checked: with a file
    // of that name in the way (or no right to create it) an empty remote directory counted as
    // "transferred", and a move removed it from the server with nothing local.
    DWORD dirAttr = GetFileAttributesW(wdir);
    if (notOwn || dirAttr == INVALID_FILE_ATTRIBUTES || !(dirAttr & FILE_ATTRIBUTE_DIRECTORY))
    {
        if (notOwn) // feature 205: the reason of the core's create (a file in the other folder held open, ...)
        {
            CSFTPMsgText err(SalamanderGeneral->GetErrorText(crErr));
            char why[600]; // no path in it: a path is never cut
            _snprintf_s(why, _TRUNCATE, "the name is the short name of another local entry, which could not be moved aside: %s",
                        err.Get());
            SFTPShowPathError(ctx->Parent, IDS_ERR_MKDIR, localDir, why, ctx->Session->GetLogUID());
        }
        else
            SFTPShowPathError(ctx->Parent, IDS_ERR_OPENLOCAL, localDir, NULL);
        return xrFailed;
    }

    TIndirectArray<CSFTPDirEntry> entries(64, 64);
    if (!ctx->Session->ListDir(remoteDir, &entries, &ctx->Cancelled))
    {
        ShowRequestError(ctx, IDS_ERR_LISTDIR, remoteDir, ctx->Session->GetLastErrorText());
        return xrFailed;
    }
    // feature 133: a stop by the user inside the listing returns TRUE with a part of the
    // directory - that is not a directory "fully transferred" (a move would go on to ask the
    // server to remove it)
    if (ctx->Cancelled)
        return xrFailed;

    CXferResult agg = xrOk; // xrOk only if every child fully transferred
    for (int i = 0; i < entries.Count && !ctx->CheckCancel(); i++)
    {
        if (StopIfSessionLost(ctx, NULL)) // feature 139: the rest of the directory is not tried
        {
            agg = xrFailed;
            break;
        }
        CSFTPDirEntry* e = entries[i];
        if (PosixPathAppend(remoteDir, e->Name, lv->RPath, sizeof(lv->RPath)) == NULL || // real remote name
            !SanitizeLocalName(e->Name, lv->Safe, sizeof(lv->Safe)) ||                    // safe local name
            !LocalPathAppend(localDir, lv->Safe, lv->LPath, sizeof(lv->LPath)))
        {
            ReportTooLongPath(ctx, remoteDir, e->Name); // feature 131: skipped, never cut
            agg = xrFailed;
            continue;
        }
        BOOL isLink = e->HasMode && SFTP_S_ISLNK(e->Mode);
        CXferResult r = DownloadRecursive(ctx, lv->RPath, lv->LPath, e->Mode, isLink, e->Size, depth + 1, move);
        if (r == xrFailed) agg = xrFailed;
        else if (r == xrSkipped && agg == xrOk) agg = xrSkipped;
    }
    if (ctx->Cancelled) // feature 133: the loop was left before its end
        return xrFailed;
    // feature 140: nothing is removed once the connection is lost - also when everything
    // before went well (an empty directory: the close of its listing may be what timed out)
    if (move && StopIfSessionLost(ctx, remoteDir))
        return xrFailed;
    // feature 138: a moved directory is removed once every item of it was moved (each item
    // removed itself above; xrOk = all of them did, the listing was complete, nobody stopped it)
    if (move && agg == xrOk && !ctx->Session->Rmdir(remoteDir))
    {
        ReportNotRemoved(ctx, IDS_ERR_RMDIR, remoteDir, ctx->Session->GetLastErrorText());
        return xrFailed;
    }
    return agg;
}

// feature 138: with 'move' a result of xrOk means "transferred AND removed from the server"
static CXferResult DownloadRecursive(COperationCtx* ctx, const char* remotePath, const char* localPath,
                                     unsigned long mode, BOOL isLink, unsigned __int64 size, int depth, BOOL move)
{
    if (ctx->CheckCancel())
        return xrFailed;

    if (isLink)
    {
        if (StopIfSessionLost(ctx, remotePath)) // feature 140
            return xrFailed;
        LIBSSH2_SFTP_ATTRIBUTES attrs;
        BOOL statOk = ctx->Session->Stat(remotePath, TRUE, &attrs);
        if (statOk && (attrs.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS) && SFTP_S_ISDIR(attrs.permissions))
        {
            Logs.AppendFmt(ctx->Session->GetLogUID(), LoadStrU8(IDS_SYMLINK_DIR_SKIPPED), CSFTPMsgText(remotePath).Get());
            return xrSkipped; // directory symlink not followed (clarification #4)
        }
        // feature 140: what the link leads to is handed on - one stat per link. A stat the
        // server refused (a dangling link) is "unknown": the open reports, as before. A stat
        // that ended the session is not "not a directory" - DownloadOneFile stops at once on a
        // session that is gone.
        int linkKind = statOk ? (int)SftpDownloadKind((attrs.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS) != 0, attrs.permissions)
                              : (int)sdkUnknown;
        // feature 131: the translated text the viewer's download already shows (a UTF-8 sentence)
        WaitText(LoadStrU8(IDS_DOWNLOADINGFILE), CSFTPMsgText(PosixBaseName(remotePath)).Get());
        CXferResult linkRes = DownloadOneFile(ctx, remotePath, localPath, size, move, linkKind);
        if (linkRes == xrOk && move && !RemoveMovedFile(ctx, remotePath, localPath))
            linkRes = xrFailed;
        return linkRes;
    }

    if (SFTP_S_ISDIR(mode))
        return DownloadDir(ctx, remotePath, localPath, depth, move);

    WaitText(LoadStrU8(IDS_DOWNLOADINGFILE), CSFTPMsgText(PosixBaseName(remotePath)).Get());
    // feature 140: an entry the listing shows as a regular file is opened as before; anything
    // else (a device, a FIFO, a socket, no mode at all) is asked about first
    CXferResult res = DownloadOneFile(ctx, remotePath, localPath, size, move, SFTP_S_ISREG(mode) ? (int)sdkRegular : -1);
    if (res == xrOk && move && !RemoveMovedFile(ctx, remotePath, localPath))
        res = xrFailed;
    return res;
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
        if (StopIfSessionLost(&ctx, NULL)) // feature 139: the remaining items are not tried
        {
            ok = FALSE;
            break;
        }
        CSFTPDirEntry* e = items[i];
        char rpath[4096], lpath[4096], safe[512];
        if (PosixPathAppend(remoteDir, e->Name, rpath, sizeof(rpath)) == NULL ||
            !SanitizeLocalName(e->Name, safe, sizeof(safe)) ||
            !LocalPathAppend(targetLocalPath, safe, lpath, sizeof(lpath)))
        {
            ReportTooLongPath(&ctx, remoteDir, e->Name); // feature 131: skipped (and not deleted on a move)
            ok = FALSE;
            continue;
        }
        BOOL isLink = e->HasMode && SFTP_S_ISLNK(e->Mode);
        // feature 138: the item removes its own source when - and only when - it arrived whole
        // (RemoveMovedFile, DownloadDir); a source that had to stay makes the result xrFailed
        CXferResult r = DownloadRecursive(&ctx, rpath, lpath, e->Mode, isLink, e->Size, 0, move);
        if (r == xrFailed)
            ok = FALSE;
    }

    SalamanderGeneral->DestroySafeWaitWindow();
    return ok && !ctx.Cancelled;
}

// ---------------------------------------------------------------------------
// upload
// ---------------------------------------------------------------------------

// feature 139: the twin of ConfirmOverwrite for a file that exists on the server (an upload
// used to truncate it without asking). Returns TRUE to replace it, FALSE to skip this file;
// Cancel skips all the remaining existing files of the operation (the same OverwriteMode).
static BOOL ConfirmOverwriteRemote(COperationCtx* ctx, const char* remotePath)
{
    if (ctx->OverwriteMode == ovAll)
        return TRUE;
    if (ctx->OverwriteMode == ovSkipAll)
        return FALSE;
    CSFTPMsgText text(remotePath); // the server's bytes are not always UTF-8
    // feature 258: what a replacement cannot keep is said where the user decides - the file is
    // normally replaced by a complete new copy (feature 139), and SFTP version 3 reports no link
    // count and no ACL
    char* msg = SftpFormatMsgAlloc("The file already exists on the server:\n%s\n\nOverwrite it?\n"
                                   "(Yes = this file, No = skip; Cancel = skip the rest)\n\n"
                                   "It is replaced by a new copy where the server allows it: other hard links to it "
                                   "keep the old content, and its ACL and extended attributes are not carried over.",
                                   text.Get(), NULL);
    if (msg == NULL)
        return FALSE; // the question cannot be asked: the file is not replaced
    int r = SalamanderGeneral->SalMessageBox(ctx->Parent, msg, LoadStr(IDS_SFTPERRORTITLE),
                                             MB_YESNOCANCEL | MB_ICONQUESTION);
    free(msg);
    if (r == IDCANCEL)
    {
        ctx->OverwriteMode = ovSkipAll;
        return FALSE;
    }
    return r == IDYES;
}

// feature 139: a random number for the temporary name of an upload (SalGenRandom; should the
// system's generator fail, a number that at least differs from call to call)
static unsigned long UploadTempRandom()
{
    static unsigned long counter = 0;
    unsigned long r = 0;
    if (!SalGenRandom(&r, sizeof(r)))
        r = (unsigned long)GetTickCount() ^ (++counter * 2654435761UL) ^ ((unsigned long)GetCurrentProcessId() << 16);
    return r;
}

// feature 139: uploads one file. The rule every path below keeps: the old content of a file on
// the server is never gone unless the complete new content is under the final name, or the
// user was told the name of the file that holds it; a move removes the local source only
// after xrOk. (The one exception is the route "in place", the behaviour before 139, which the
// user agreed to by the overwrite question - see below when it is taken.)
//  - a file that exists on the server is replaced only after the user said so; an lstat that
//    cannot tell whether it exists (any failure but "no such file") fails the item;
//  - the data go to a temporary file in the same directory (SftpTempPath); the server is asked
//    for its size, and only a complete file takes the target's name - a failed or stopped
//    upload leaves the old file as it was and no torso under its name;
//  - the route is decided BEFORE any data is sent. Written IN PLACE, each said in the session's
//    log: a target that is not a regular file (a symbolic link would be replaced by a file);
//    one with a set-user-ID / set-group-ID bit (a write clears it on a new file); a directory
//    in which the server refuses to create a file (SftpTempOpenFailureNext); and a temporary
//    file - still empty - that cannot be given the old file's owner, group and permission
//    bits (a new file with another owner in its place is not the file "as it was");
//  - after the data only a refused final rename (target still there, session alive) leads to
//    a second transfer, in place; the complete temporary file is kept until that one is
//    confirmed, and named to the user when it is not;
//  - 'move': the local source is removed here, after its own upload was confirmed (it was
//    removed by listing the local tree again). With 'move', xrOk = uploaded AND removed.

// removes a temporary file of an upload; FALSE (and a line in the log naming it) when it stays
static BOOL UploadDropTemp(COperationCtx* ctx, const char* temp)
{
    if (ctx->Session->Unlink(temp))
        return TRUE;
    Logs.AppendFmt(ctx->Session->GetLogUID(), "The temporary file %s could not be removed: %s", CSFTPMsgText(temp).Get(),
                   ctx->Session->GetLastErrorText());
    // feature 258: the removal could not even be asked - the connection is gone. The file is
    // remembered and offered for deletion at the next upload (UploadOfferLeftTemps). A removal
    // the server refused on a live session is not: asking again would not help.
    if (!ctx->Session->IsConnected() && SftpIsUploadTempPath(temp) && !ctx->Session->NoteLeftTemp(temp))
        Logs.AppendFmt(ctx->Session->GetLogUID(), "(too many left temporary files to remember %s)", CSFTPMsgText(temp).Get());
    return FALSE;
}

// feature 258: temporary files that earlier uploads of this session could not remove because the
// connection was lost (UploadDropTemp) are offered for deletion - once; Yes deletes each that is
// still a regular file, No forgets them. Called at the start of an upload, the session connected.
static void UploadOfferLeftTemps(HWND parent, CSFTPSession* session)
{
    char* paths[CSFTPSession::MAX_LEFT_TEMPS];
    int n = session->TakeLeftTemps(paths);
    if (n == 0)
        return;
    // the list for the question: the full paths, one per line, on the heap (paths can be long)
    size_t listSize = 1;
    for (int i = 0; i < n; i++)
        listSize += strlen(CSFTPMsgText(paths[i]).Get()) + 1;
    char* list = (char*)malloc(listSize);
    if (list != NULL)
    {
        list[0] = 0;
        for (int i = 0; i < n; i++)
        {
            strcat_s(list, listSize, CSFTPMsgText(paths[i]).Get());
            strcat_s(list, listSize, "\n");
        }
    }
    char* msg = SftpFormatMsgAlloc("Earlier uploads lost the connection before they could remove their temporary "
                                   "files; these are left on the server:\n%s\nDelete them now?\n"
                                   "(They hold only copies: the files they were uploaded for were not changed by them.)",
                                   list != NULL ? list : "", NULL);
    free(list);
    int answer = msg != NULL ? SalamanderGeneral->SalMessageBox(parent, msg, LoadStr(IDS_PLUGINNAME), MB_YESNO | MB_ICONQUESTION)
                             : IDNO;
    free(msg);
    int logUID = session->GetLogUID();
    char* failed = NULL; // the first that could not be deleted (with its reason)
    for (int i = 0; i < n; i++)
    {
        if (answer == IDYES)
        {
            LIBSSH2_SFTP_ATTRIBUTES a;
            CSFTPStatResult st = session->StatEx(paths[i], FALSE, &a); // (the link itself, never followed)
            BOOL regular = st == sxFound && (a.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS) != 0 && SFTP_S_ISREG(a.permissions);
            if (st == sxNotFound)
                Logs.AppendFmt(logUID, "The temporary file %s is gone already.", CSFTPMsgText(paths[i]).Get());
            else if (regular && session->Unlink(paths[i]))
                Logs.AppendFmt(logUID, "The left temporary file %s was deleted.", CSFTPMsgText(paths[i]).Get());
            else
            {
                const char* why = st == sxFound && !regular ? "the server does not show it as a regular file"
                                                            : session->GetLastErrorText();
                Logs.AppendFmt(logUID, "The left temporary file %s was not deleted: %s", CSFTPMsgText(paths[i]).Get(), why);
                if (failed == NULL)
                    failed = SftpFormatMsgAlloc("%s (%s)", CSFTPMsgText(paths[i]).Get(), why);
                if (!session->IsConnected()) // the deletion could not be asked: offered again next time
                    session->NoteLeftTemp(paths[i]);
            }
        }
        else
            Logs.AppendFmt(logUID, "The left temporary file %s was kept (the user's answer).", CSFTPMsgText(paths[i]).Get());
        free(paths[i]);
    }
    if (failed != NULL)
    {
        char* box = SftpFormatMsgAlloc("Not every left temporary file could be deleted; the first one:\n%s", failed, NULL);
        SalamanderGeneral->SalMessageBox(parent, box != NULL ? box : failed, LoadStr(IDS_SFTPERRORTITLE),
                                         MB_OK | MB_ICONEXCLAMATION);
        free(box);
        free(failed);
    }
}

// feature 140 (review): a temporary file that could not be removed where no error box of the
// upload follows to name it - the upload was stopped, or it has succeeded (the spare copy of a
// second transfer), or it goes on in place. The user is told its name in a box of its own;
// the item's result is not changed by it. Called right after UploadDropTemp returned FALSE
// (the session's text is the reason of that).
static void UploadTellStrayTemp(COperationCtx* ctx, const char* temp, const char* remotePath)
{
    char why[700];
    SplU8CopyTrunc(why, sizeof(why), ctx->Session->GetLastErrorText());
    CSFTPMsgText target(PosixBaseName(remotePath));
    char* reason = SftpFormatMsgAlloc("%s (a temporary file of the upload of %s; it can be deleted)", why, target.Get());
    if (ctx->SessionLost())
        ctx->ConnLostShown = TRUE; // this box says it: its reason is the session's text
    SFTPShowPathError(ctx->Parent, IDS_ERR_DELETE, temp, reason != NULL ? reason : why, ctx->Session->GetLogUID());
    free(reason);
}

// the one error box of a failed upload; 'strayTemp' (may be NULL): a temporary file that
// could not be removed - of no use, but the user should know it is there
static void UploadShowFailure(COperationCtx* ctx, const char* remotePath, const char* why, const char* strayTemp)
{
    if (strayTemp == NULL)
    {
        ShowRequestError(ctx, IDS_ERR_UPLOAD, remotePath, why); // (feature 140: one box per operation once the connection is lost)
        return;
    }
    CSFTPMsgText tempText(PosixBaseName(strayTemp));
    char* reason = SftpFormatMsgAlloc("%s (the temporary file %s could not be removed)", why, tempText.Get());
    ShowRequestError(ctx, IDS_ERR_UPLOAD, remotePath, reason != NULL ? reason : why);
    free(reason);
}

// the write loop of an upload: the whole local file 'lf', from its beginning, into 'h'.
// Shows nothing: 'why' gets the reason of a failure and stays empty when the user stopped it.
static CXferResult UploadWriteData(COperationCtx* ctx, HANDLE lf, LIBSSH2_SFTP_HANDLE* h, const char* remotePath,
                                   unsigned __int64* bytesSent, char* why, int whySize)
{
    CSFTPSession* session = ctx->Session;
    unsigned __int64 sent = 0;
    *bytesSent = 0;
    why[0] = 0;
    LARGE_INTEGER start;
    start.QuadPart = 0;
    if (!SetFilePointerEx(lf, start, NULL, FILE_BEGIN)) // (a second transfer of the same file)
    {
        DWORD seekErr = GetLastError();
        SplU8CopyTrunc(why, whySize, CSFTPMsgText(SalamanderGeneral->GetErrorText(seekErr)).Get());
        return xrFailed;
    }
    CXferResult res = xrOk;
#ifdef _DEBUG
    __int64 probeFailAfter = ProbeXferFailAfter(remotePath); // the target's name, not the temporary one
#endif
    for (;;)
    {
        if (ctx->CheckCancel())
        {
            res = xrFailed;
            break;
        }
        DWORD read = 0;
        if (!ReadFile(lf, ctx->Buffer, XFER_BUFSIZE, &read, NULL))
        {
            DWORD readErr = GetLastError();
            res = xrFailed; // feature 139: failed without a word before
            SplU8CopyTrunc(why, whySize, CSFTPMsgText(SalamanderGeneral->GetErrorText(readErr)).Get());
            break;
        }
        if (read == 0)
            break;
        // libssh2_sftp_write may accept a partial buffer; loop until all written
        int off = 0;
        while (off < (int)read)
        {
            int len = (int)read - off;
            BOOL probeFail = FALSE;
#ifdef _DEBUG
            if (probeFailAfter >= 0) // the seam: exactly that many bytes are sent, then the write "fails"
            {
                unsigned __int64 left = sent < (unsigned __int64)probeFailAfter ? (unsigned __int64)probeFailAfter - sent : 0;
                if (left == 0)
                    probeFail = TRUE;
                else if (left < (unsigned __int64)len)
                    len = (int)left;
            }
#endif
            __int64 w = probeFail ? -1 : session->Write(h, ctx->Buffer + off, len);
            if (w <= 0) // (0: nothing accepted - would spin here forever)
            {
                res = xrFailed;
                SplU8CopyTrunc(why, whySize, LoadStrU8(IDS_ERR_WRITEREMOTE));
                break;
            }
            off += (int)w;
            sent += (unsigned __int64)w;
        }
        if (res != xrOk)
            break;
    }
    *bytesSent = sent;
    return res;
}

// sends the local file into the open 'h' (the remote file 'writtenPath'), closes 'h' and asks
// the server whether all of it is there. Shows nothing; 'why' as in UploadWriteData.
static CXferResult UploadSendAndConfirm(COperationCtx* ctx, HANDLE lf, LIBSSH2_SFTP_HANDLE* h, const char* writtenPath,
                                        const char* remotePath, unsigned __int64 localSize, char* why, int whySize)
{
    CSFTPSession* session = ctx->Session;
    unsigned __int64 sent = 0;
    CXferResult res = UploadWriteData(ctx, lf, h, remotePath, &sent, why, whySize);
    // the server's answer to the close counts: it may be where a full disk shows
    if (!session->CloseHandleChecked(h) && res == xrOk)
    {
        res = xrFailed;
        SplU8CopyTrunc(why, whySize, session->GetLastErrorText());
    }
    if (res == xrOk)
    {
        // feature 258: a server that will not show the file (an upload-only folder) refuses the
        // size request; then its acknowledgments of every write and of the close confirm it
        LIBSSH2_SFTP_ATTRIBUTES newAttrs;
        CSFTPStatResult st = session->StatEx(writtenPath, TRUE, &newAttrs);
        BOOL sizeKnown = st == sxFound && (newAttrs.flags & LIBSSH2_SFTP_ATTR_SIZE) != 0;
        BOOL sizeRefused = st == sxError && SftpTargetStatRefused(session->IsConnected(), session->GetLastSftpStatus());
        CSftpUploadConfirm conf =
            SftpUploadConfirmation(sizeKnown, sizeKnown ? newAttrs.filesize : 0, sizeRefused, sent, localSize);
        if (conf == ucNo)
        {
            res = xrFailed;
            SplU8CopyTrunc(why, whySize, "the file on the server could not be confirmed complete.");
        }
        else if (conf == ucByAcks)
            Logs.AppendFmt(session->GetLogUID(),
                           "%s: the server does not show the size of the written file (%s); it acknowledged all %I64u bytes and the close.",
                           CSFTPMsgText(writtenPath).Get(), session->GetLastErrorText(), sent);
    }
    return res;
}

enum CUploadTempFit
{
    utfOk,     // the empty temporary file has the old file's owner, group and permission bits
    utfCannot, // it cannot be given them ('why'): this file is written in place
    utfLost,   // the connection died while asking ('why' = the connection's error)
};

// feature 139: can the new, still EMPTY temporary file take the place of the old file "as it
// was"? Decided before any data is sent, so that a file is never transferred twice for this.
// The owner and group are compared when the server reports both; the permission bits are set
// only when they differ.
static CUploadTempFit UploadTempFitsOld(CSFTPSession* session, const char* temp, const LIBSSH2_SFTP_ATTRIBUTES* oldAttrs,
                                        char* why, int whySize)
{
    why[0] = 0;
    LIBSSH2_SFTP_ATTRIBUTES tempAttrs;
    if (session->StatEx(temp, FALSE, &tempAttrs) != sxFound)
    {
        if (!session->IsConnected())
        {
            SplU8CopyTrunc(why, whySize, session->GetLastErrorText());
            return utfLost;
        }
        memset(&tempAttrs, 0, sizeof(tempAttrs)); // nothing reported: no owner to compare, the bits are set
    }
    BOOL oldOwner = (oldAttrs->flags & LIBSSH2_SFTP_ATTR_UIDGID) != 0;
    if (SftpOwnerDiffers(oldOwner, oldAttrs->uid, oldAttrs->gid, (tempAttrs.flags & LIBSSH2_SFTP_ATTR_UIDGID) != 0,
                         tempAttrs.uid, tempAttrs.gid))
    {
        BOOL same = session->Chown(temp, oldAttrs->uid, oldAttrs->gid, TRUE, TRUE);
        if (same) // believed only when the server shows it
        {
            same = session->StatEx(temp, FALSE, &tempAttrs) == sxFound &&
                   (tempAttrs.flags & LIBSSH2_SFTP_ATTR_UIDGID) != 0 &&
                   !SftpOwnerDiffers(TRUE, oldAttrs->uid, oldAttrs->gid, TRUE, tempAttrs.uid, tempAttrs.gid);
        }
        if (!same)
        {
            if (!session->IsConnected())
            {
                SplU8CopyTrunc(why, whySize, session->GetLastErrorText());
                return utfLost;
            }
            SplU8CopyTrunc(why, whySize, "a new file cannot be given the owner and group of the replaced one");
            return utfCannot;
        }
    }
    // (after the owner: a change of owner may clear bits)
    if (SftpModeDiffers((oldAttrs->flags & LIBSSH2_SFTP_ATTR_PERMISSIONS) != 0, oldAttrs->permissions,
                        (tempAttrs.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS) != 0, tempAttrs.permissions) &&
        !session->Chmod(temp, oldAttrs->permissions & 07777))
    {
        if (!session->IsConnected())
        {
            SplU8CopyTrunc(why, whySize, session->GetLastErrorText());
            return utfLost;
        }
        SplU8CopyTrunc(why, whySize, "a new file cannot be given the permissions of the replaced one");
        return utfCannot;
    }
    return utfOk;
}

enum CUploadPlace
{
    uplPlaced,       // the temporary file has the target's name
    uplFailed,       // it has not; 'why' says it ('keepTemp': it is the only copy of the new content)
    uplRetryInPlace, // the server refuses to put it there and the old file is still there: send in place ('why' for the log)
};

// feature 139: the complete, confirmed temporary file 'temp' takes the name 'remotePath'.
// 'existed': a file of that name is being replaced (the user agreed).
static CUploadPlace UploadPlaceTemp(COperationCtx* ctx, const char* temp, const char* remotePath, BOOL existed,
                                    char* why, int whySize, BOOL* keepTemp)
{
    CSFTPSession* session = ctx->Session;
    *keepTemp = FALSE;
    why[0] = 0;
    // 'existed': the user agreed to the replacement. Otherwise the request does not ask for one
    // (and the lstat before the upload said "no such file").
    if (session->Rename(temp, remotePath, existed))
        return uplPlaced;
    SplU8CopyTrunc(why, whySize, session->GetLastErrorText());
    unsigned long status = session->GetLastSftpStatus();
    // Anything further only on a refusal BY THE SERVER of a replacement: after a lost answer
    // the rename may have happened, and the "old" file would be the new one.
    if (!existed || !session->IsConnected() || status == 0)
        return uplFailed;
    LIBSSH2_SFTP_ATTRIBUTES check;
    if (SftpStatusIsPermission(status))
    {
        // files may be written here, not renamed: in place - if the old file is still there
        return session->StatEx(remotePath, FALSE, &check) == sxFound && session->IsConnected() ? uplRetryInPlace : uplFailed;
    }
    // A server without the replacing rename: the old file makes room for the complete new
    // one. Only when the temporary file is still there - the rename did not happen.
    if (session->StatEx(temp, FALSE, &check) != sxFound)
        return uplFailed;
    if (session->Unlink(remotePath))
    {
        if (session->Rename(temp, remotePath, FALSE))
            return uplPlaced;
        // the old file is gone and the new one could not take its name: the temporary file
        // is the only copy - kept and named, never deleted
        *keepTemp = TRUE;
        if (_snprintf_s(why, whySize, _TRUNCATE, "%s - the old file was removed; the complete new file is left as %s",
                        session->GetLastErrorText(), CSFTPMsgText(PosixBaseName(temp)).Get()) < 0)
            SplU8TrimTornTail(why);
        return uplFailed;
    }
    // The removal was reported as failed. Shown to be still there (and the session alive):
    // the old file can be written in place. Otherwise (gone after all, or not known) the
    // temporary file may be the only copy - kept and named.
    char unlinkWhy[600];
    SplU8CopyTrunc(unlinkWhy, sizeof(unlinkWhy), session->GetLastErrorText());
    if (session->StatEx(remotePath, FALSE, &check) == sxFound && session->IsConnected())
    {
        SplU8CopyTrunc(why, whySize, unlinkWhy);
        return uplRetryInPlace;
    }
    *keepTemp = TRUE;
    if (_snprintf_s(why, whySize, _TRUNCATE, "%s - the old file may be gone; the complete new file is left as %s",
                    unlinkWhy, CSFTPMsgText(PosixBaseName(temp)).Get()) < 0)
        SplU8TrimTornTail(why);
    return uplFailed;
}

// feature 139: the second transfer - the complete temporary file 'temp' exists, the server
// refused to give it the target's name ('why'), the old file is still there: the file is sent
// once more, in place. The temporary file is KEPT until that transfer is confirmed: from the
// moment the old file is truncated it is the only complete copy of the new content. When the
// second transfer fails or is stopped, the user is told its name - also after a stop.
static CXferResult UploadSecondPass(COperationCtx* ctx, HANDLE lf, const char* temp, const char* remotePath,
                                    unsigned __int64 localSize, char* why, int whySize)
{
    CSFTPSession* session = ctx->Session;
    int logUID = session->GetLogUID();
    Logs.AppendFmt(logUID, "%s: %s; the file is written in place.", CSFTPMsgText(remotePath).Get(), why);
    if (ctx->CheckCancel()) // before the old file is truncated: it is intact, the spare copy goes
    {
        if (!UploadDropTemp(ctx, temp))
            UploadTellStrayTemp(ctx, temp, remotePath);
        return xrFailed;
    }
    BOOL truncated = TRUE; // the old content is gone for certain
    LIBSSH2_SFTP_HANDLE* h = session->OpenWrite(remotePath, 0644, FALSE);
    if (h == NULL)
    {
        SplU8CopyTrunc(why, whySize, session->GetLastErrorText());
        if (session->IsConnected() && session->GetLastSftpStatus() != 0)
        {
            // refused by the server: nothing was opened, the old file is intact
            BOOL gone = UploadDropTemp(ctx, temp);
            UploadShowFailure(ctx, remotePath, why, gone ? NULL : temp);
            return xrFailed;
        }
        truncated = FALSE; // no answer: the server may have truncated it
    }
    else
    {
        if (UploadSendAndConfirm(ctx, lf, h, remotePath, remotePath, localSize, why, whySize) == xrOk)
        {
            // the new content is under the final name: the spare copy goes. Should it stay,
            // the user is told its name - the upload itself is done
            if (!UploadDropTemp(ctx, temp))
                UploadTellStrayTemp(ctx, temp, remotePath);
            return xrOk;
        }
    }
    CSFTPMsgText tempText(PosixBaseName(temp));
    char* reason = SftpFormatMsgAlloc(truncated ? "%s - the old content of the file is gone; the complete new file is left as %s"
                                                : "%s - the old content of the file may be gone; the complete new file is left as %s",
                                      why[0] != 0 ? why : "the upload was stopped", tempText.Get());
    ShowRequestError(ctx, IDS_ERR_UPLOAD, remotePath, reason != NULL ? reason : tempText.Get());
    free(reason);
    return xrFailed;
}

// feature 258: the upload into a folder whose files the server will not show ("drop" folder:
// it refused the lstat of the target for want of a right). Whether a file of that name exists
// cannot be learned, so the user cannot be asked: the file is only CREATED (exclusive create),
// never opened over anything; a server without the exclusive create is not written to. No
// temporary file: such a server lets nobody rename or remove there. 'lf' stays open.
static CXferResult UploadDropRoute(COperationCtx* ctx, HANDLE lf, const char* remotePath, unsigned __int64 localSize)
{
    CSFTPSession* session = ctx->Session;
    Logs.AppendFmt(session->GetLogUID(),
                   "The server does not show %s (%s); it is created only if no file of that name is there.",
                   CSFTPMsgText(remotePath).Get(), session->GetLastErrorText());
    if (ctx->CheckCancel())
        return xrFailed;
    LIBSSH2_SFTP_HANDLE* h = session->OpenWriteNew(remotePath, 0644);
    if (h == NULL)
    {
        char* reason = SftpFormatMsgAlloc("%s - the server does not show whether a file of that name is there; "
                                          "nothing was replaced",
                                          session->GetLastErrorText(), NULL);
        ShowRequestError(ctx, IDS_ERR_UPLOAD, remotePath, reason != NULL ? reason : session->GetLastErrorText());
        free(reason);
        return xrFailed;
    }
    char why[900];
    if (UploadSendAndConfirm(ctx, lf, h, remotePath, remotePath, localSize, why, sizeof(why)) == xrOk)
        return xrOk;
    // failed or stopped: the file under the name was created by this upload a moment ago - it is
    // removed (once); where the server refuses that, the box says that a part may stay
    if (session->Unlink(remotePath))
    {
        if (why[0] != 0) // (stopped by the user: no box, nothing is left)
            ShowRequestError(ctx, IDS_ERR_UPLOAD, remotePath, why);
        return xrFailed;
    }
    Logs.AppendFmt(session->GetLogUID(), "The partial file %s could not be removed: %s", CSFTPMsgText(remotePath).Get(),
                   session->GetLastErrorText());
    char* reason = SftpFormatMsgAlloc("%s - a partial file may remain on the server under this name (%s)",
                                      why[0] != 0 ? why : "the upload was stopped", session->GetLastErrorText());
    ShowRequestError(ctx, IDS_ERR_UPLOAD, remotePath, reason != NULL ? reason : why);
    free(reason);
    return xrFailed;
}

// the end of an upload of one file ('lf' is closed): with 'move', the local source is removed
// after a confirmed upload; xrOk = uploaded AND removed
static CXferResult UploadFinishMove(COperationCtx* ctx, const wchar_t* wlocal, const char* localPath, CXferResult res,
                                    BOOL move)
{
    // feature 140: nothing is removed once the connection is lost - also on this side (the
    // upload is confirmed; a request after it, the removal of a spare temporary file, may be
    // what ended the session). The source stays; UploadOneFile says why.
    if (res == xrOk && move && ctx->SessionLost())
        res = xrFailed;
    if (res == xrOk && move && !DeleteFileW(wlocal))
    {
        // uploaded, but the source stays (and so does its folder); said once per operation
        DWORD delErr = GetLastError();
        ReportNotRemoved(ctx, IDS_ERR_DELETE, localPath, CSFTPMsgText(SalamanderGeneral->GetErrorText(delErr)).Get());
        res = xrFailed;
    }
    return res;
}

static CXferResult UploadOneFileImpl(COperationCtx* ctx, const char* localPath, const char* remotePath, BOOL move)
{
    CSFTPSession* session = ctx->Session;
    int logUID = session->GetLogUID();

    wchar_t wlocal[4096];
    MakeLocalWidePath(localPath, wlocal, 4096);
    HANDLE lf = CreateFileW(wlocal, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING,
                            FILE_ATTRIBUTE_NORMAL, NULL);
    if (lf == INVALID_HANDLE_VALUE)
    {
        SFTPShowPathError(ctx->Parent, IDS_ERR_OPENLOCAL, localPath, NULL);
        return xrFailed;
    }
    LARGE_INTEGER localSize;
    if (!GetFileSizeEx(lf, &localSize))
    {
        DWORD sizeErr = GetLastError();
        CloseHandle(lf);
        ShowSysError(ctx, IDS_ERR_UPLOAD, remotePath, sizeErr);
        return xrFailed;
    }

    // what holds the target's name now? The link itself is asked about (lstat). An answer
    // other than "found" or "no such file" is no answer: the item fails - the final rename
    // refusing an existing target is OpenSSH's behaviour, not every server's.
    LIBSSH2_SFTP_ATTRIBUTES oldAttrs;
    CSFTPStatResult old = session->StatEx(remotePath, FALSE, &oldAttrs);
    if (old == sxError && SftpTargetStatRefused(session->IsConnected(), session->GetLastSftpStatus()))
    {
        // feature 258: an upload-only folder - created there, or not at all
        CXferResult dr = UploadDropRoute(ctx, lf, remotePath, (unsigned __int64)localSize.QuadPart);
        CloseHandle(lf);
        return UploadFinishMove(ctx, wlocal, localPath, dr, move);
    }
    if (old == sxError)
    {
        CloseHandle(lf);
        ShowRequestError(ctx, IDS_ERR_UPLOAD, remotePath, session->GetLastErrorText());
        return xrFailed;
    }
    BOOL existed = old == sxFound;
    BOOL oldHasMode = existed && (oldAttrs.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS) != 0;
    if (existed)
    {
        if (oldHasMode && SFTP_S_ISDIR(oldAttrs.permissions))
        {
            CloseHandle(lf);
            SFTPShowPathError(ctx->Parent, IDS_ERR_UPLOAD, remotePath, "a directory of that name exists on the server.", logUID);
            return xrFailed;
        }
        if (!ConfirmOverwriteRemote(ctx, remotePath))
        {
            CloseHandle(lf);
            return xrSkipped;
        }
    }

    // ---- the route, decided before any data is sent
    BOOL inPlace = FALSE;
    if (existed && !(oldHasMode && SFTP_S_ISREG(oldAttrs.permissions)))
    {
        inPlace = TRUE;
        Logs.AppendFmt(logUID, "%s is not a regular file (a link or a special file); it is written in place.",
                       CSFTPMsgText(remotePath).Get());
    }
    else if (existed && (oldAttrs.permissions & (SFTP_S_ISUID | SFTP_S_ISGID)) != 0)
    {
        inPlace = TRUE; // (a write by an ordinary account clears these bits on a new file)
        Logs.AppendFmt(logUID, "%s has a set-user-ID or set-group-ID bit; it is written in place.",
                       CSFTPMsgText(remotePath).Get());
    }
    // the temporary file of a replaced file is created with that file's permission bits, so
    // that its content is at no moment readable by more accounts than the old file was
    long tempMode = oldHasMode ? (long)(oldAttrs.permissions & 0777) : 0644;

    char temp[4096];
    char why[900];
    temp[0] = 0;
    why[0] = 0;
    LIBSSH2_SFTP_HANDLE* h = NULL;
    if (!inPlace)
    {
        for (int attempt = 0; attempt < 2; attempt++)
        {
            if (!SftpTempPath(remotePath, UploadTempRandom(), temp, sizeof(temp)))
            {
                CloseHandle(lf);
                ReportTooLongPath(ctx, remotePath, ".tcpart-*");
                return xrFailed;
            }
            h = session->OpenWriteNew(temp, tempMode);
            if (h != NULL)
                break;
            CSftpTempOpenNext next = SftpTempOpenFailureNext(session->IsConnected(), session->GetLastSftpStatus());
            if (next == tonRetryName && attempt == 0)
                continue; // a file of that name exists: another random name, once
            if (next == tonInPlace)
            {
                Logs.AppendFmt(logUID, "No temporary file can be created next to %s (%s); the file is written in place.",
                               CSFTPMsgText(remotePath).Get(), session->GetLastErrorText());
                inPlace = TRUE;
                break;
            }
            // anything else (no answer, no space, quota, ...): the item fails and nothing
            // is opened under the target's name - after an open that timed out the library
            // would hand the temporary file's handle to the next open
            CloseHandle(lf);
            ShowRequestError(ctx, IDS_ERR_UPLOAD, remotePath, session->GetLastErrorText());
            return xrFailed;
        }
        if (h != NULL && existed)
        {
            // can the new file take the old one's place as it was? Asked of the empty file.
            CUploadTempFit fit = UploadTempFitsOld(session, temp, &oldAttrs, why, sizeof(why));
            if (fit != utfOk)
            {
                session->CloseHandle(h);
                h = NULL;
                BOOL gone = UploadDropTemp(ctx, temp); // (empty; the target was not touched)
                if (fit == utfLost)
                {
                    CloseHandle(lf);
                    UploadShowFailure(ctx, remotePath, why, gone ? NULL : temp);
                    return xrFailed;
                }
                Logs.AppendFmt(logUID, "%s: %s; the file is written in place.", CSFTPMsgText(remotePath).Get(), why);
                if (!gone)
                    UploadTellStrayTemp(ctx, temp, remotePath);
                inPlace = TRUE;
            }
        }
    }

    CXferResult res;
    if (h != NULL)
    {
        // ---- through the temporary file: the target is not touched until the rename
        res = UploadSendAndConfirm(ctx, lf, h, temp, remotePath, (unsigned __int64)localSize.QuadPart, why, sizeof(why));
        if (res == xrOk)
        {
            BOOL keepTemp = FALSE;
            CUploadPlace placed = UploadPlaceTemp(ctx, temp, remotePath, existed, why, sizeof(why), &keepTemp);
            if (placed == uplRetryInPlace)
                res = UploadSecondPass(ctx, lf, temp, remotePath, (unsigned __int64)localSize.QuadPart, why, sizeof(why));
            else if (placed != uplPlaced)
            {
                res = xrFailed;
                BOOL gone = keepTemp || UploadDropTemp(ctx, temp);
                UploadShowFailure(ctx, remotePath, why, gone ? NULL : temp);
            }
        }
        else
        {
            // failed or stopped: no partial file stays; the old file is as it was
            BOOL gone = UploadDropTemp(ctx, temp);
            if (why[0] != 0)
                UploadShowFailure(ctx, remotePath, why, gone ? NULL : temp);
            else if (!gone) // stopped by the user: no box of the upload - the file that stays is named all the same
                UploadTellStrayTemp(ctx, temp, remotePath);
        }
    }
    else
    {
        // ---- in place (the behaviour before 139): the old content goes with the open
        if (existed && ctx->CheckCancel()) // the last moment to stop with the old file intact
        {
            CloseHandle(lf);
            return xrFailed;
        }
        if (existed)
            h = session->OpenWrite(remotePath, 0644, FALSE);
        else
        {
            // a new target: created, never opened over something that appeared meanwhile
            // (where the server has no exclusive create: as before 139)
            h = session->OpenWriteNew(remotePath, 0644);
            if (h == NULL && session->IsConnected() && session->GetLastSftpStatus() == LIBSSH2_FX_OP_UNSUPPORTED)
                h = session->OpenWrite(remotePath, 0644, FALSE);
        }
        if (h == NULL)
        {
            CloseHandle(lf);
            ShowRequestError(ctx, IDS_ERR_UPLOAD, remotePath, session->GetLastErrorText());
            return xrFailed;
        }
        res = UploadSendAndConfirm(ctx, lf, h, remotePath, remotePath, (unsigned __int64)localSize.QuadPart, why, sizeof(why));
        if (res != xrOk && why[0] != 0) // (a failed write in place may leave a partial target, as before 139)
            ShowRequestError(ctx, IDS_ERR_UPLOAD, remotePath, why);
    }
    CloseHandle(lf);
    return UploadFinishMove(ctx, wlocal, localPath, res, move);
}

static CXferResult UploadOneFile(COperationCtx* ctx, const char* localPath, const char* remotePath, BOOL move)
{
    if (StopIfSessionLost(ctx, remotePath)) // feature 139: no further attempt (and box) per item
        return xrFailed;
    CXferResult res = UploadOneFileImpl(ctx, localPath, remotePath, move);
    if (res == xrFailed && ctx->SessionLost()) // (see DownloadOneFile)
        ctx->ReportSessionLost();
    return res;
}

// feature 139: the buffers of one directory level of an upload (about 30 KB) - one heap block
// per level; on the stack a local tree about 90 levels deep overflowed it (see SFTP_MAX_RECURSION)
struct CUploadLevel
{
    wchar_t WSelf[4096];
    wchar_t WPattern[4096];
    char Pattern[4096];
    char Name[1024]; // a name of the file system has at most 255 units = 765 bytes
    char LPath[4096];
    char RPath[4096];
    WIN32_FIND_DATAW Fd;
};

// feature 139: a local folder that is a link to another place (a junction, a directory symbolic
// link, a mounted volume) is not entered: its content lies outside the selected tree, and a
// move would remove it there. It used to be skipped without a word and counted as uploaded -
// now every one goes to the log, the box is shown once per operation, and the result is
// "skipped" (the link and its parent folders stay where they are in a move).
static CXferResult SkipLocalLinkDir(COperationCtx* ctx, const char* localDir)
{
    char* msg = SftpFormatMsgAlloc(LoadStrU8(IDS_SYMLINK_DIR_SKIPPED), localDir, NULL);
    if (msg != NULL)
        Logs.Append(ctx->Session->GetLogUID(), msg);
    if (!ctx->LinkSkippedShown)
    {
        ctx->LinkSkippedShown = TRUE;
        SalamanderGeneral->SalMessageBox(ctx->Parent, msg != NULL ? msg : LOW_MEMORY, LoadStr(IDS_SFTPERRORTITLE),
                                         MB_OK | MB_ICONEXCLAMATION);
    }
    free(msg);
    return xrSkipped;
}

static CXferResult UploadDirLevel(COperationCtx* ctx, const char* localDir, const char* remoteDir, int depth,
                                  BOOL move, BOOL linkChecked, CUploadLevel* lv);

// feature 139: returns the tri-state of the download (feature 138) and carries 'move': each
// file removes its own local source after its upload was confirmed, a folder is removed when
// every item of it was moved. (The local tree used to be deleted by listing it again after
// the upload - whatever was in it at that moment, uploaded or not.) With 'move', xrOk =
// uploaded AND removed. 'linkChecked': the caller has seen that 'localDir' is not a link.
static CXferResult UploadDirRecursive(COperationCtx* ctx, const char* localDir, const char* remoteDir, int depth,
                                      BOOL move, BOOL linkChecked)
{
    if (depth > SFTP_MAX_RECURSION) // CF-5
    {
        SalamanderGeneral->SalMessageBox(ctx->Parent, LoadStr(IDS_ERR_TOODEEP),
                                         LoadStr(IDS_SFTPERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
        return xrFailed;
    }
    CUploadLevel* lv = (CUploadLevel*)malloc(sizeof(CUploadLevel));
    if (lv == NULL)
    {
        SalamanderGeneral->SalMessageBox(ctx->Parent, LOW_MEMORY, LoadStr(IDS_SFTPERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
        return xrFailed;
    }
    CXferResult res = UploadDirLevel(ctx, localDir, remoteDir, depth, move, linkChecked, lv);
    free(lv);
    return res;
}

static CXferResult UploadDirLevel(COperationCtx* ctx, const char* localDir, const char* remoteDir, int depth,
                                  BOOL move, BOOL linkChecked, CUploadLevel* lv)
{
    CSFTPSession* session = ctx->Session;
    int logUID = session->GetLogUID();

    if (StopIfSessionLost(ctx, remoteDir)) // feature 139
        return xrFailed;
    MakeLocalWidePath(localDir, lv->WSelf, 4096);
    // CF-6: never traverse a local link (junction / directory symbolic link): following it
    // would pull in files from outside the selected tree, and a move would remove them there.
    // feature 139: only LINKS - the reparse tag tells them from cloud folders (every OneDrive
    // folder is a reparse point; uploading one sent nothing and reported success).
    if (!linkChecked)
    {
        DWORD selfAttr = GetFileAttributesW(lv->WSelf);
        if (selfAttr != INVALID_FILE_ATTRIBUTES && (selfAttr & FILE_ATTRIBUTE_REPARSE_POINT))
        {
            // the tag: FindFirstFile on the directory itself gives it in dwReserved0. A reparse
            // point whose tag cannot be read is taken for a link (not entered, said aloud).
            BOOL isLink = TRUE;
            HANDLE hSelf = FindFirstFileW(lv->WSelf, &lv->Fd);
            if (hSelf != INVALID_HANDLE_VALUE)
            {
                isLink = SftpLocalDirIsLink(lv->Fd.dwFileAttributes, lv->Fd.dwReserved0);
                FindClose(hSelf);
            }
            if (isLink)
                return SkipLocalLinkDir(ctx, localDir);
        }
    }

    if (!LocalPathAppend(localDir, "*", lv->Pattern, sizeof(lv->Pattern)))
    {
        // feature 131: a cut mask would search another directory; nothing is created remotely
        ReportTooLongPath(ctx, localDir, "*");
        return xrFailed;
    }
    MakeLocalWidePath(lv->Pattern, lv->WPattern, 4096);

    // feature 139: the listing is opened before anything is created on the server. A folder
    // that cannot be listed is a failure - it used to count as "nothing to upload", and a move
    // then deleted what was in it.
    HANDLE hFind = FindFirstFileW(lv->WPattern, &lv->Fd);
    if (hFind == INVALID_HANDLE_VALUE)
    {
        DWORD findErr = GetLastError();
        // (a file system that lists no "." entry reports an empty folder this way)
        DWORD dirAttr = findErr == ERROR_FILE_NOT_FOUND ? GetFileAttributesW(lv->WSelf) : INVALID_FILE_ATTRIBUTES;
        if (dirAttr == INVALID_FILE_ATTRIBUTES || !(dirAttr & FILE_ATTRIBUTE_DIRECTORY))
        {
            Logs.AppendFmt(logUID, "The local folder cannot be listed (error %u): %s", (unsigned)findErr, localDir);
            SFTPShowPathError(ctx->Parent, IDS_ERR_OPENLOCAL, localDir, NULL, logUID);
            return xrFailed;
        }
    }

    // feature 139: the directory must be there, as a directory. A failed Mkdir was ignored
    // ("already exists"): with a file of that name in the way, or no right to create it,
    // nothing below was uploaded and all of it counted as uploaded.
    if (!session->Mkdir(remoteDir, 0755))
    {
        char why[600];
        SplU8CopyTrunc(why, sizeof(why), session->GetLastErrorText());
        LIBSSH2_SFTP_ATTRIBUTES dirAttrs;
        if (!session->Stat(remoteDir, TRUE, &dirAttrs) || (dirAttrs.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS) == 0 ||
            !SFTP_S_ISDIR(dirAttrs.permissions))
        {
            if (hFind != INVALID_HANDLE_VALUE)
                FindClose(hFind);
            ShowRequestError(ctx, IDS_ERR_MKDIR, remoteDir, why);
            return xrFailed;
        }
    }

    CXferResult agg = xrOk; // xrOk only if every item was fully transferred (and, in a move, removed)
    DWORD listErr = ERROR_NO_MORE_FILES;
    BOOL more = hFind != INVALID_HANDLE_VALUE;
    while (more && !ctx->CheckCancel())
    {
        if (StopIfSessionLost(ctx, NULL)) // feature 139: the rest of the folder is not tried
        {
            agg = xrFailed;
            break;
        }
        if (wcscmp(lv->Fd.cFileName, L".") != 0 && wcscmp(lv->Fd.cFileName, L"..") != 0)
        {
            CXferResult r;
            if (!WideToUtf8(lv->Fd.cFileName, lv->Name, sizeof(lv->Name)) ||
                !LocalPathAppend(localDir, lv->Name, lv->LPath, sizeof(lv->LPath)) ||
                PosixPathAppend(remoteDir, lv->Name, lv->RPath, sizeof(lv->RPath)) == NULL)
            {
                ReportTooLongPath(ctx, remoteDir, lv->Name); // feature 131: skipped, never cut
                r = xrFailed;
            }
            else if (lv->Fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
            {
                if (SftpLocalDirIsLink(lv->Fd.dwFileAttributes, lv->Fd.dwReserved0))
                    r = SkipLocalLinkDir(ctx, lv->LPath); // a junction inside the tree is not entered
                else
                    r = UploadDirRecursive(ctx, lv->LPath, lv->RPath, depth + 1, move, TRUE);
            }
            else
            {
                WaitText("Uploading %s ...", lv->Name);
                r = UploadOneFile(ctx, lv->LPath, lv->RPath, move);
            }
            if (r == xrFailed)
                agg = xrFailed;
            else if (r == xrSkipped && agg == xrOk)
                agg = xrSkipped;
        }
        if (!FindNextFileW(hFind, &lv->Fd))
        {
            listErr = GetLastError();
            more = FALSE;
        }
    }
    if (hFind != INVALID_HANDLE_VALUE)
        FindClose(hFind);
    if (ctx->Cancelled) // the loop was left before its end
        return xrFailed;
    if (listErr != ERROR_NO_MORE_FILES) // the listing broke off: the folder was not uploaded whole
    {
        Logs.AppendFmt(logUID, "The listing of the local folder ended early (error %u): %s", (unsigned)listErr, localDir);
        SFTPShowPathError(ctx->Parent, IDS_ERR_OPENLOCAL, localDir, NULL, logUID);
        return xrFailed;
    }
    if (move && StopIfSessionLost(ctx, remoteDir)) // feature 140: nothing is removed once the connection is lost
        return xrFailed;
    // a moved folder is removed once every item of it was moved (each removed itself above)
    if (move && agg == xrOk && !RemoveDirectoryW(lv->WSelf))
    {
        DWORD rmErr = GetLastError();
        ReportNotRemoved(ctx, IDS_ERR_RMDIR, localDir, CSFTPMsgText(SalamanderGeneral->GetErrorText(rmErr)).Get());
        return xrFailed;
    }
    return agg;
}

BOOL SFTPUploadToFS(HWND parent, CSFTPSession* session, const char* sourcePath,
                    SalEnumSelection2 next, void* nextParam, const char* targetRemoteDir, BOOL move)
{
    COperationCtx ctx(parent, session);
    if (session->IsConnected()) // feature 258: before the wait window - a question may come
        UploadOfferLeftTemps(parent, session);
    SalamanderGeneral->CreateSafeWaitWindow(LoadStr(IDS_PLUGINNAME), LoadStr(IDS_PLUGINNAME), 500, TRUE,
                                            SalamanderGeneral->GetMainWindowHWND());
    BOOL ok = TRUE;

    // the enumerator returns names relative to 'sourcePath' (feature 131: joined below by
    // LocalPathAppend, which adds the separator; the copy into a 3072-byte buffer cut a
    // longer source path and the upload - and the delete of a move - went elsewhere)

    next(NULL, -1, NULL, NULL, NULL, NULL, NULL, nextParam, NULL); // reset enumeration
    BOOL isDir = FALSE;
    int err = 0;
    const char* name;
    while ((name = next(parent, 0, NULL, &isDir, NULL, NULL, NULL, nextParam, &err)) != NULL)
    {
        if (ctx.CheckCancel() || StopIfSessionLost(&ctx, NULL)) // feature 139: the remaining items are not tried
        {
            ok = FALSE;
            break;
        }
        char lpath[4096], rpath[4096];
        if (!LocalPathAppend(sourcePath, name, lpath, sizeof(lpath)) ||
            PosixPathAppend(targetRemoteDir, PosixBaseName(name), rpath, sizeof(rpath)) == NULL)
        {
            ReportTooLongPath(&ctx, targetRemoteDir, name); // feature 131: skipped (and kept on a move)
            ok = FALSE;
            continue;
        }
        if (err != SALENUM_SUCCESS) // feature 139: the enumerator left something out
            ok = FALSE;
        // feature 139: nothing is deleted here any more - in a move every item removes its own
        // local source when, and only when, its upload was confirmed (UploadOneFile,
        // UploadDirLevel); a source that had to stay makes the result xrFailed. A skipped item
        // (the user's "No", a link folder) is not a failure, as in a download.
        CXferResult r;
        if (isDir)
            r = UploadDirRecursive(&ctx, lpath, rpath, 0, move, FALSE);
        else
        {
            WaitText("Uploading %s ...", name);
            r = UploadOneFile(&ctx, lpath, rpath, move);
        }
        if (r == xrFailed)
            ok = FALSE;
    }
    if (err != SALENUM_SUCCESS) // SALENUM_CANCEL, and SALENUM_ERROR (items were left out): not whole
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
    // feature 140: a delete went on after a request had timed out - every further item waited
    // for its own failure and showed its own box, and the library answered the next request
    // with the reply that belonged to the one before
    if (StopIfSessionLost(ctx, remotePath))
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
        // feature 133: a directory that could not be listed (whole) is not emptied from the
        // part that was read, and the server is not asked to remove it either: what it holds
        // is not known, and "the server refuses a directory that is not empty" is the server's
        // rule, not ours (not everything checked = not deleted). The listing's own reason is shown.
        if (!ctx->Session->ListDir(remotePath, &entries, &ctx->Cancelled))
        {
            ShowRequestError(ctx, IDS_ERR_LISTDIR, remotePath, ctx->Session->GetLastErrorText());
            return FALSE;
        }
        // feature 133: the directory is removed only when every item of it is known to be gone.
        // An item that was skipped or could not be deleted has been reported where it failed; the
        // server used to be asked to remove each parent directory all the same (it refused, and
        // every level added a message of its own).
        BOOL itemsGone = TRUE;
        for (int i = 0; i < entries.Count && !ctx->CheckCancel(); i++)
        {
            if (StopIfSessionLost(ctx, NULL)) // feature 140: the rest is not asked for
            {
                itemsGone = FALSE;
                break;
            }
            CSFTPDirEntry* e = entries[i];
            char child[4096];
            if (PosixPathAppend(remotePath, e->Name, child, sizeof(child)) == NULL)
            {
                ReportTooLongPath(ctx, remotePath, e->Name); // feature 131: never delete the cut path
                itemsGone = FALSE;
                continue;
            }
            BOOL childLink = e->HasMode && SFTP_S_ISLNK(e->Mode);
            if (!DeleteRecursive(ctx, child, e->Mode, childLink, depth + 1))
                itemsGone = FALSE;
        }
        if (ctx->Cancelled || !itemsGone)
            return FALSE; // stopped by the user (also inside the listing), or an item stays
        // feature 140: also for a directory listed as empty - the close of the listing may be
        // the request that ended the session
        if (StopIfSessionLost(ctx, remotePath))
            return FALSE;
        if (!ctx->Session->Rmdir(remotePath))
        {
            ShowRequestError(ctx, IDS_ERR_RMDIR, remotePath, ctx->Session->GetLastErrorText());
            return FALSE;
        }
    }
    else
    {
        if (!ctx->Session->Unlink(remotePath))
        {
            ShowRequestError(ctx, IDS_ERR_DELETE, remotePath, ctx->Session->GetLastErrorText());
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
        if (StopIfSessionLost(&ctx, NULL)) // feature 140: the remaining items are not asked for
        {
            ok = FALSE;
            break;
        }
        CSFTPDirEntry* e = items[i];
        char rpath[4096];
        if (PosixPathAppend(remoteDir, e->Name, rpath, sizeof(rpath)) == NULL)
        {
            ReportTooLongPath(&ctx, remoteDir, e->Name); // feature 131: never delete the cut path
            ok = FALSE;
            continue;
        }
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

// feature 140: a change of attributes / owner that the server refused: a line in the log (as
// before) and counted for the one box after the operation (ShowRefused). 'what' (may be NULL)
// goes before the reason. Not for a session that is gone - that is not a refusal, and the
// operation says it once (ReportSessionLost).
static void NoteAttrRefused(COperationCtx* ctx, int fmtID, const char* remotePath, const char* what, const char* reason)
{
    if (ctx->SessionLost())
        return;
    char* full = what != NULL ? SftpFormatMsgAlloc("%s: %s", what, reason) : NULL;
    if (full != NULL)
        reason = full;
    CSFTPMsgText text(remotePath);
    char* msg = SftpFormatMsgAlloc(LoadStrU8(fmtID), text.Get(), reason);
    if (msg != NULL)
        Logs.Append(ctx->Session->GetLogUID(), msg);
    free(msg);
    ctx->NoteRefused(remotePath, reason);
    free(full);
}

// feature 140: the end of a change of attributes / owner: ONE box - the lost connection, or
// what the server refused (the first item with its reason, and how many more; all of them are
// in the log). Change Attributes and Change Owner used to report nothing at all.
static void ShowRefused(COperationCtx* ctx, int fmtID)
{
    // the lost connection is said here unless the user stopped the operation
    BOOL sayLost = ctx->SessionLost() && !ctx->Cancelled && !ctx->ConnLostShown;
    if (ctx->RefusedCount == 0)
    {
        if (sayLost)
            ctx->ReportSessionLost();
        return;
    }
    const char* reason = ctx->RefusedReason;
    char* withCount = NULL;
    if (ctx->RefusedCount > 1)
    {
        char more[100];
        _snprintf_s(more, _TRUNCATE, "(and %d more refused; see the log)", ctx->RefusedCount - 1);
        withCount = SftpFormatMsgAlloc("%s %s", reason, more);
        if (withCount != NULL)
            reason = withCount;
    }
    const char* path = ctx->RefusedPath != NULL ? ctx->RefusedPath : "";
    if (!sayLost)
        SFTPShowPathError(ctx->Parent, fmtID, path, reason); // (every refusal is in the log already)
    else
    {
        // both in the ONE box: the connection was lost, and what the server had refused before
        char lost[700];
        ctx->LostText(lost, sizeof(lost));
        CSFTPMsgText text(path);
        char* refused = SftpFormatMsgAlloc(LoadStrU8(fmtID), text.Get(), reason);
        char* both = refused != NULL ? SftpFormatMsgAlloc("%s\n\nBefore that: %s", lost, refused) : NULL;
        ctx->ConnLostShown = TRUE;
        Logs.Append(ctx->Session->GetLogUID(), lost);
        SalamanderGeneral->SalMessageBox(ctx->Parent, both != NULL ? both : lost, LoadStr(IDS_SFTPERRORTITLE),
                                         MB_OK | MB_ICONEXCLAMATION);
        free(both);
        free(refused);
    }
    free(withCount);
}

static void ChmodRecursive(COperationCtx* ctx, const char* remotePath, unsigned long mode,
                           BOOL isDir, BOOL recurse, int depth)
{
    if (ctx->CheckCancel() || ctx->SessionLost()) // feature 140: nothing more is asked of a session that is gone
        return;
    if (depth > SFTP_MAX_RECURSION) // CF-5
    {
        NoteAttrRefused(ctx, IDS_ERR_CHMOD, remotePath, NULL, "the directory tree is too deep; nothing below was changed.");
        return;
    }
    if (!ctx->Session->Chmod(remotePath, mode))
        NoteAttrRefused(ctx, IDS_ERR_CHMOD, remotePath, NULL, ctx->Session->GetLastErrorText());
    if (isDir && recurse && !ctx->SessionLost())
    {
        TIndirectArray<CSFTPDirEntry> entries(64, 64);
        if (!ctx->Session->ListDir(remotePath, &entries, &ctx->Cancelled))
        {
            // feature 133: the subtree is skipped - said in the log; feature 140: and counted
            NoteAttrRefused(ctx, IDS_ERR_CHMOD, remotePath, "its items were not changed, the directory cannot be listed",
                            ctx->Session->GetLastErrorText());
        }
        else
        {
            for (int i = 0; i < entries.Count && !ctx->CheckCancel() && !ctx->SessionLost(); i++)
            {
                CSFTPDirEntry* e = entries[i];
                if (e->HasMode && SFTP_S_ISLNK(e->Mode))
                    continue; // do not chmod through symlinks
                char child[4096];
                if (PosixPathAppend(remotePath, e->Name, child, sizeof(child)) == NULL)
                {
                    ReportTooLongPath(ctx, remotePath, e->Name); // feature 131
                    continue;
                }
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
    SplU8CopyTrunc(label, sizeof(label), items[0]->Name); // shown only: cut at a whole character (feature 131)
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

    for (int i = 0; i < items.Count && !ctx.CheckCancel() && !ctx.SessionLost(); i++) // feature 140: stops on a lost connection
    {
        CSFTPDirEntry* e = items[i];
        char rpath[4096];
        if (PosixPathAppend(remoteDir, e->Name, rpath, sizeof(rpath)) == NULL)
        {
            ReportTooLongPath(&ctx, remoteDir, e->Name); // feature 131
            continue;
        }
        BOOL itemIsDir = e->HasMode && SFTP_S_ISDIR(e->Mode);
        ChmodRecursive(&ctx, rpath, mode, itemIsDir, recurse, 0);
        // feature 140: a refused time was not even in the log
        if (setTime && !ctx.Cancelled && !ctx.SessionLost() && !session->SetMTime(rpath, mtime))
            NoteAttrRefused(&ctx, IDS_ERR_CHMOD, rpath, "the time was not set", session->GetLastErrorText());
    }

    SalamanderGeneral->DestroySafeWaitWindow();
    ShowRefused(&ctx, IDS_ERR_CHMOD); // feature 140
    return TRUE;
}

// feature 018: change owner/group of one item, recursing into a directory
// subtree when requested (mirrors ChmodRecursive; skips symlinks).
static void ChownRecursive(COperationCtx* ctx, const char* remotePath,
                           unsigned long uid, unsigned long gid, BOOL setUid, BOOL setGid,
                           BOOL isDir, BOOL recurse, int depth)
{
    if (ctx->CheckCancel() || ctx->SessionLost()) // feature 140 (see ChmodRecursive)
        return;
    if (depth > SFTP_MAX_RECURSION) // CF-5
    {
        NoteAttrRefused(ctx, IDS_ERR_CHOWN, remotePath, NULL, "the directory tree is too deep; nothing below was changed.");
        return;
    }
    if (!ctx->Session->Chown(remotePath, uid, gid, setUid, setGid))
        NoteAttrRefused(ctx, IDS_ERR_CHOWN, remotePath, NULL, ctx->Session->GetLastErrorText());
    if (isDir && recurse && !ctx->SessionLost())
    {
        TIndirectArray<CSFTPDirEntry> entries(64, 64);
        if (!ctx->Session->ListDir(remotePath, &entries, &ctx->Cancelled))
        {
            NoteAttrRefused(ctx, IDS_ERR_CHOWN, remotePath, "its items were not changed, the directory cannot be listed",
                            ctx->Session->GetLastErrorText());
        }
        else
        {
            for (int i = 0; i < entries.Count && !ctx->CheckCancel() && !ctx->SessionLost(); i++)
            {
                CSFTPDirEntry* e = entries[i];
                if (e->HasMode && SFTP_S_ISLNK(e->Mode))
                    continue; // do not chown through symlinks
                char child[4096];
                if (PosixPathAppend(remotePath, e->Name, child, sizeof(child)) == NULL)
                {
                    ReportTooLongPath(ctx, remotePath, e->Name); // feature 131
                    continue;
                }
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
    SplU8CopyTrunc(label, sizeof(label), items[0]->Name); // shown only: cut at a whole character (feature 131)
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

    for (int i = 0; i < items.Count && !ctx.CheckCancel() && !ctx.SessionLost(); i++) // feature 140
    {
        CSFTPDirEntry* e = items[i];
        char rpath[4096];
        if (PosixPathAppend(remoteDir, e->Name, rpath, sizeof(rpath)) == NULL)
        {
            ReportTooLongPath(&ctx, remoteDir, e->Name); // feature 131
            continue;
        }
        BOOL itemIsDir = e->HasMode && SFTP_S_ISDIR(e->Mode);
        ChownRecursive(&ctx, rpath, uid, gid, setUid, setGid, itemIsDir, recurse, 0);
    }

    SalamanderGeneral->DestroySafeWaitWindow();
    ShowRefused(&ctx, IDS_ERR_CHOWN); // feature 140
    return TRUE;
}
