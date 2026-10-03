// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include "../../common/salsamefile.h" // feature 103: is an existing target the source itself?

BOOL CRenamerDialog::MoveFile(char* sourceName, char* targetName, char* newPart,
                              BOOL overwrite, BOOL isDir, BOOL& skip)
{
    CALL_STACK_MESSAGE4("CRenamerDialog::MoveFile(, , , %d, %d, %d)", overwrite,
                        isDir, skip);
    // create the path
    char dir[MAX_PATH];
    strcpy(dir, targetName);
    SG->CutDirectory(dir);
    if (!CheckAndCreateDirectory(dir, dir + (newPart - targetName), skip))
        return FALSE;

    // perform the move
    if (SG->HasTheSameRootPath(sourceName, targetName))
    {
        while (1)
        {
            DWORD err = 0;
            if (SG->StrICmp(sourceName, targetName) == 0 &&
                    strcmp(
                        SG->SalPathFindFileName(sourceName),
                        SG->SalPathFindFileName(targetName)) == 0 ||
                SG->SalMoveFile(sourceName, targetName, &err))
                return TRUE; // success

            // feature 103: "already exists" may name the source itself (another spelling of its name
            // on a server that folds more than Windows); the names below cannot tell, the file
            // system's identity can. Such a target is never deleted: the rename goes through a
            // temporary name, which also tells the two apart (a target that outlives the source's
            // name is another file and the overwrite below follows unchanged)
            if (err == ERROR_ALREADY_EXISTS || err == ERROR_FILE_EXISTS)
            {
                CSalFileIdentity srcId, tgtId;
                WCHAR* wSrc = SplU8ToWExtAlloc(sourceName);
                WCHAR* wTgt = SplU8ToWExtAlloc(targetName);
                SalGetFileIdentityW(wSrc, TRUE, &srcId);
                SalGetFileIdentityW(wTgt, TRUE, &tgtId);
                // a symbolic link / junction renamed onto the file (folder) it points at: the overwrite
                // below would delete that file and leave a link to itself (second review of 103)
                CSalFileIdentity srcThrough;
                SalFileIdentityClear(&srcThrough);
                if (srcId.Valid && (srcId.Attr & FILE_ATTRIBUTE_REPARSE_POINT))
                    SalGetFileIdentityW(wSrc, FALSE, &srcThrough);
                free(wSrc);
                free(wTgt);
                if (SalLinkPointsAtTarget(srcId, srcThrough, tgtId)) // refused, reported as "already exists" (no new string)
                {
                    SetLastError(err);
                    if (FileError(HWindow, sourceName, IDS_MOVEERROR, TRUE, &skip, &SkipAllSameFile, IDS_ERROR))
                        continue; // retry
                    return FALSE;
                }
                if (SalDecideExistingTarget(FALSE, err, srcId, tgtId) == setaViaTempName)
                {
                    int tmpSize = (int)strlen(sourceName) + 16;
                    char* tmp = (char*)malloc(tmpSize);
                    DWORD tmpErr = ERROR_NOT_ENOUGH_MEMORY;
                    CSalViaTempResult res = svtFailed;
                    if (tmp != NULL)
                    {
                        auto move = [](const char* from, const char* to, DWORD* e) -> BOOL
                        { return SG->SalMoveFile(from, to, e); };
                        res = SalRenameViaTempName(sourceName, targetName, move, tmp, tmpSize, GetTickCount() / 10, &tmpErr);
                    }
                    if (res == svtDone)
                    {
                        free(tmp);
                        return TRUE; // success
                    }
                    if (res == svtLeftAtTemp) // the file is under the temporary name: always say where
                    {                         // (also after "Skip All"), then skip it
                        const char* errText = SG->GetErrorText(tmpErr);
                        size_t msgSize = strlen(errText) + strlen(tmp) + 4;
                        char* msg = (char*)malloc(msgSize);
                        if (msg != NULL)
                            sprintf_s(msg, msgSize, "%s\n\n%s", errText, tmp);
                        SG->SalMessageBox(HWindow, msg != NULL ? msg : tmp, LoadStr(IDS_ERROR), MB_OK | MB_ICONEXCLAMATION);
                        free(msg);
                        free(tmp);
                        skip = TRUE;
                        return FALSE;
                    }
                    if (res != svtTargetIsOther) // not renamed (the file is back): report it, the target is never touched
                    {
                        SetLastError(tmpErr);
                        BOOL retry = FileError(HWindow, sourceName, IDS_MOVEERROR,
                                               TRUE, &skip, &SkipAllMove, IDS_ERROR);
                        free(tmp);
                        if (!retry)
                            return FALSE;
                        continue;
                    }
                    free(tmp); // another file: the old handling below
                }
            }

            if ((err == ERROR_ALREADY_EXISTS || err == ERROR_FILE_EXISTS) &&
                SG->StrICmp(sourceName, targetName) != 0)
            {
                DWORD attr = SG->SalGetFileAttributes(targetName);
                if (attr != 0xFFFFFFFF && attr & FILE_ATTRIBUTE_DIRECTORY) // cannot overwrite a directory
                {
                    return FileError(HWindow, targetName,
                                     isDir ? IDS_DIRDIR : IDS_FILEDIR,
                                     FALSE, &skip, &SkipAllFileDir, IDS_ERROR);
                }

                if (!overwrite &&
                    !FileOverwrite(HWindow, targetName, NULL, sourceName, NULL, -1,
                                   IDS_CNFRM_SHOVERWRITE, IDS_OVEWWRITETITLE, &skip, &Silent))
                    return FALSE;

                SG->ClearReadOnlyAttr(targetName); // so it can be deleted ...
                while (1)
                {
                    if (DeleteFileU8(targetName))
                        break;

                    if (!FileError(HWindow, targetName, IDS_OVERWRITEERROR,
                                   TRUE, &skip, &SkipAllOverwrite, IDS_ERROR))
                        return FALSE;
                }
            }
            else
            {
                if (!FileError(HWindow, sourceName, IDS_MOVEERROR,
                               TRUE, &skip, &SkipAllMove, IDS_ERROR))
                    return FALSE;
            }
        }
    }
    else
    {
        if (isDir)
        {
            TRACE_E("Error in the script.");
            return skip = FALSE;
        }
        if (!CopyFile(sourceName, targetName, overwrite, skip))
            return FALSE;
        // we still need to clean up the file from the sources
        SG->ClearReadOnlyAttr(sourceName); // so it can be deleted ...
        while (1)
        {
            if (DeleteFileU8(sourceName))
                break;

            if (!FileError(HWindow, sourceName, IDS_DELETEERROR,
                           TRUE, &skip, &SkipAllDeleteErr, IDS_ERROR))
                return skip;
        }
        return TRUE;
    }
}

BOOL CRenamerDialog::CheckAndCreateDirectory(char* directory, char* newPart, BOOL& skip)
{
    CALL_STACK_MESSAGE2("CRenamerDialog::CheckAndCreateDirectory(, , %d)", skip);
    // 'directory' is UTF-8 since plugin interface 104 -> query via the W API
    WIN32_FIND_DATAW fd;
    char fdFileName[3 * MAX_PATH]; // fd.cFileName converted to UTF-8
    HANDLE f;
    char* directoryEnd = directory + strlen(directory);

    // skip drives
    char *start = directory, *end;
    if (start[0] == '\\' && start[1] == '\\') // UNC
    {
        start += 2;
        while (*start != 0 && *start != '\\')
            start++;
        if (*start != 0)
            start++; // '\\'
        while (*start != 0 && *start != '\\')
            start++;
        start++;
    }
    else
        start += 3;

    start = max(start, newPart);

    // existing part
    while (start < directoryEnd)
    {
        end = (char*)GetNextPathComponent(start);
        *end = 0;
        {
            WCHAR* wDirectory = SplU8ToWExtAlloc(directory);
            f = wDirectory != NULL ? FindFirstFileW(wDirectory, &fd) : INVALID_HANDLE_VALUE;
            free(wDirectory);
        }
        if (f == INVALID_HANDLE_VALUE)
            goto CREATE_PATH;
        else
        {
            FindClose(f);
            if (SplWToU8(fd.cFileName, fdFileName, _countof(fdFileName)) == 0)
                fdFileName[0] = 0;
            // adjust the case of the name
            if (strcmp(start, fdFileName))
            {
                char old[MAX_PATH];
                memcpy(old, directory, start - directory);
                strcpy(old + (start - directory), fdFileName);
                while (1)
                {
                    if (SG->SalMoveFile(old, directory, NULL))
                    {
                        if (!Undoing)
                            UndoStack.Add(new CUndoStackEntry(directory, old, NULL, FALSE, FALSE));
                        break;
                    }

                    if (!FileError(HWindow, old, IDS_DIRCASEERROR,
                                   TRUE, &skip, &SkipAllDirChangeCase, IDS_ERROR))
                    {
                        if (!skip)
                            return FALSE;
                        break;
                    }
                }
            }
        }
        *end = '\\';
        start = end + 1;
    }
    // non-existing part
    while (start < directoryEnd)
    {
        end = (char*)GetNextPathComponent(start);
        *end = 0;
    CREATE_PATH:

        while (1)
        {
            if (CreateDirectoryU8(directory))
            {
                if (!Undoing)
                    UndoStack.Add(new CUndoStackEntry(directory, NULL, NULL, FALSE, FALSE));
                break;
            }

            if (!FileError(HWindow, directory, IDS_CREATEDIR,
                           TRUE, &skip, &SkipAllCreateDir, IDS_ERROR))
                return FALSE;
        }
        *end = '\\';
        start = end + 1;
    }
    return TRUE;
}

BOOL CRenamerDialog::CopyFile(char* sourceName, char* targetName, BOOL overwrite,
                              BOOL& skip)
{
    CALL_STACK_MESSAGE3("CRenamerDialog::CopyFile(, , %d, %d)", overwrite, skip);
    char buffer[OPERATION_BUFFER];

    CQuadWord operationDone;

COPY_AGAIN:

    operationDone.Set(0, 0);
    HANDLE in;

    while (1)
    {
        in = CreateFileU8(sourceName, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE,
                          OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN);
        if (in != INVALID_HANDLE_VALUE)
        {
            HANDLE out;
            while (1)
            {
                out = CreateFileU8(targetName, GENERIC_WRITE, 0,
                                   CREATE_NEW, FILE_FLAG_SEQUENTIAL_SCAN);
                if (out != INVALID_HANDLE_VALUE)
                {
                COPY:

                    DWORD readed;
                    while (1)
                    {
                        if (ReadFile(in, buffer, OPERATION_BUFFER, &readed, NULL))
                        {
                            DWORD writen;
                            if (readed == 0)
                                break; // EOF

                            while (1)
                            {
                                if (WriteFile(out, buffer, readed, &writen, NULL) &&
                                    readed == writen)
                                    break;

                                while (1)
                                {
                                    if (!FileError(HWindow, targetName, IDS_WRITEERROR,
                                                   TRUE, &skip, &SkipAllBadWrite, IDS_ERROR))
                                    {
                                        if (in != NULL)
                                            CloseHandle(in);
                                        if (out != NULL)
                                            CloseHandle(out);
                                        DeleteFileU8(targetName);
                                        return FALSE;
                                    }

                                    // retry
                                    if (out != NULL)
                                        CloseHandle(out); // close the invalid handle
                                    out = CreateFileU8(targetName, GENERIC_WRITE, 0,
                                                       OPEN_ALWAYS, FILE_FLAG_SEQUENTIAL_SCAN);
                                    if (out != INVALID_HANDLE_VALUE) // opened, now set the offset
                                    {
                                        CQuadWord size;
                                        DWORD err;
                                        if (!SG->SalGetFileSize(out, size, err) ||
                                            size < operationDone)
                                        { // cannot get the size or the file is too small, start over
                                            CloseHandle(in);
                                            CloseHandle(out);
                                            DeleteFileU8(targetName);
                                            goto COPY_AGAIN;
                                        }
                                        else // success (the file is large enough), set the offset
                                        {
                                            LONG lo, hi;
                                            lo = operationDone.LoDWord;
                                            hi = operationDone.HiDWord;
                                            lo = SetFilePointer(out, lo, &hi, FILE_BEGIN);
                                            if (lo == 0xFFFFFFFF && GetLastError() != NO_ERROR ||
                                                lo != (LONG)operationDone.LoDWord ||
                                                hi != (LONG)operationDone.HiDWord)
                                            { // cannot set the offset, start over
                                                CloseHandle(in);
                                                CloseHandle(out);
                                                DeleteFileU8(targetName);
                                                goto COPY_AGAIN;
                                            }
                                            break;
                                        }
                                    }
                                    else // cannot open it, the problem persists ...
                                    {
                                        out = NULL;
                                    }
                                }
                            }

                            operationDone.Value += readed;
                        }
                        else
                        {
                            while (1)
                            {
                                if (!FileError(HWindow, targetName, IDS_READERROR,
                                               TRUE, &skip, &SkipAllBadRead, IDS_ERROR))
                                {
                                    if (in != NULL)
                                        CloseHandle(in);
                                    if (out != NULL)
                                        CloseHandle(out);
                                    DeleteFileU8(targetName);
                                    return FALSE;
                                }

                                if (in != NULL)
                                    CloseHandle(in); // close the invalid handle
                                in = CreateFileU8(sourceName, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE,
                                                  OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN);
                                if (in != INVALID_HANDLE_VALUE) // opened, now set the offset
                                {
                                    CQuadWord size;
                                    DWORD err;
                                    if (!SG->SalGetFileSize(out, size, err) ||
                                        size < operationDone)
                                    { // cannot get the size or the file is too small, start over
                                        CloseHandle(in);
                                        CloseHandle(out);
                                        DeleteFileU8(targetName);
                                        goto COPY_AGAIN;
                                    }
                                    else // success (the file is large enough), set the offset
                                    {
                                        LONG lo, hi;
                                        lo = operationDone.LoDWord;
                                        hi = operationDone.HiDWord;
                                        lo = SetFilePointer(in, lo, &hi, FILE_BEGIN);
                                        if (lo == 0xFFFFFFFF && GetLastError() != NO_ERROR ||
                                            lo != (LONG)operationDone.LoDWord ||
                                            hi != (LONG)operationDone.HiDWord)
                                        { // cannot set the offset, start over
                                            CloseHandle(in);
                                            CloseHandle(out);
                                            DeleteFileU8(targetName);
                                            goto COPY_AGAIN;
                                        }
                                        break;
                                    }
                                }
                                else // cannot open it, the problem persists ...
                                {
                                    in = NULL;
                                }
                            }
                        }
                    }

                    FILETIME creation, lastAccess, lastWrite;
                    GetFileTime(in, &creation, &lastAccess, &lastWrite);
                    SetFileTime(out, &creation, &lastAccess, &lastWrite);

                    CloseHandle(in);
                    CloseHandle(out);

                    DWORD attr;
                    attr = SG->SalGetFileAttributes(sourceName);
                    if (attr != -1)
                        SetFileAttributesU8(targetName, attr | FILE_ATTRIBUTE_ARCHIVE);
                    return TRUE;
                }
                else
                {
                    DWORD err = GetLastError();
                    DWORD attr = SG->SalGetFileAttributes(targetName);
                    if (err == ERROR_FILE_EXISTS || err == ERROR_ALREADY_EXISTS)
                    {
                        // feature 103: the existing target may be the source itself under another path (an
                        // alias root: SUBST, \\localhost\C$, a second server name). Overwriting it would
                        // truncate the source (only its open handle stops that, and not on a WebDAV alias)
                        // and MoveFile above then deletes the source: refused, reported as "already exists"
                        CSalFileIdentity srcId, tgtId;
                        SalFileIdentityFromHandle(in, &srcId);
                        WCHAR* wTgt = SplU8ToWExtAlloc(targetName);
                        SalGetFileIdentityW(wTgt, FALSE, &tgtId);
                        free(wTgt);
                        if (SalDecideExistingTarget(TRUE, err, srcId, tgtId) == setaRefuseSame)
                        {
                            CloseHandle(in);
                            SetLastError(err);
                            if (FileError(HWindow, targetName, IDS_OPENFILEERROR,
                                          TRUE, &skip, &SkipAllSameFile, IDS_ERROR))
                                goto COPY_AGAIN; // retry
                            return FALSE;
                        }

                        // overwrite the file?
                        if (!overwrite &&
                            !FileOverwrite(HWindow, targetName, NULL, sourceName, NULL, attr,
                                           IDS_CNFRM_SHOVERWRITE, IDS_OVEWWRITETITLE, &skip, &Silent))
                        {
                            CloseHandle(in);
                            return FALSE;
                        }

                        // so it can be overwritten
                        BOOL readonly = FALSE;
                        if (attr != 0xFFFFFFFF && (attr & FILE_ATTRIBUTE_READONLY))
                        {
                            readonly = TRUE;
                            SetFileAttributesU8(targetName, attr & (~FILE_ATTRIBUTE_READONLY));
                        }

                        out = CreateFileU8(targetName, GENERIC_WRITE, 0,
                                           OPEN_ALWAYS, FILE_FLAG_SEQUENTIAL_SCAN);

                        if (out != INVALID_HANDLE_VALUE)
                        {
                            // write from the start of the file (this seek was forced by Windows XP)
                            SetFilePointer(out, 0, NULL, FILE_BEGIN);

                            SetEndOfFile(out); // reset the file length to zero
                            goto COPY;
                        }
                        else
                        {
                            err = GetLastError();
                            if (readonly)
                                SetFileAttributesU8(targetName, attr);
                            goto NORMAL_ERROR;
                        }
                    }
                    else // plain error
                    {
                    NORMAL_ERROR:

                        if (!FileError(HWindow, targetName, IDS_OPENFILEERROR,
                                       TRUE, &skip, &SkipAllOpenOut, IDS_ERROR))
                        {
                            CloseHandle(in);
                            return FALSE;
                        }
                    }
                }
            }
        }
        else
        {
            if (!FileError(HWindow, sourceName, IDS_OPENFILEERROR,
                           TRUE, &skip, &SkipAllOpenIn, IDS_ERROR))
                return FALSE;
        }
    }
}
