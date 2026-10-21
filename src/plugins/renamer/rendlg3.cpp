// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include "../../common/salsamefile.h" // feature 103: is an existing target the source itself?
#include "../../common/salnameorder.h" // feature 196: "the same name" by the file system's rule
#include "splshortname.h"              // feature 206: a folder that is only another entry's short name
#include "../../common/salmoveback.h"  // feature 281: the move back of an entry moved aside, retried

// feature 199: does 'targetName' exist only as the SHORT (8.3) name of ANOTHER entry
// ("LONGFI~1.TXT" of "longfilename.txt")? Its long name in 'longName' (the 092 name rule).
BOOL TargetIsOnlyShortNameOfOther(const char* targetName, char* longName, int longNameSize)
{
    WCHAR* wTgt = SplU8ToWExtAlloc(targetName);
    if (wTgt == NULL)
        return FALSE;
    WIN32_FIND_DATAW fd;
    HANDLE find = FindFirstFileW(wTgt, &fd);
    free(wTgt);
    if (find == INVALID_HANDLE_VALUE)
        return FALSE;
    FindClose(find);
    if (SplWToU8(fd.cFileName, longName, longNameSize) == 0)
        return FALSE;
    // second review: fail closed - the entry found under the target name has ANOTHER long name, whether
    // or not a short name is reported (a server that resolves short names without listing them)
    const char* tgtPart = SG->SalPathFindFileName(targetName);
    return !SalNameOrderEqualCI(tgtPart, -1, longName, -1);
}

enum CShortClashResult
{
    scrDone,     // the source has the new name, the other entry its long name (a new short name)
    scrFailed,   // nothing renamed, the other entry has its name; *err holds the reason
    scrLeftAside // the other entry could not get its name back: it is at 'leftAt' (report it)
};

// feature 199: the other entry ('longName' in the target's folder) is renamed aside to a temporary
// 8.3 name, the source to 'targetName', the entry back to its long name. The core's Quick Rename
// does the same. Never deletes anything.
static CShortClashResult MoveAsideShortNameClash(const char* sourceName, const char* targetName,
                                                 const char* longName, DWORD* err, char** leftAt, BOOL* renamed)
{
    *err = ERROR_NOT_ENOUGH_MEMORY;
    *renamed = FALSE;
    *leftAt = NULL; // malloc'd: where the other entry stays (scrLeftAside)
    const char* tgtPart = SG->SalPathFindFileName(targetName);
    size_t dirLen = tgtPart - targetName;
    char* entry = (char*)malloc(dirLen + strlen(longName) + 1);
    char* tmp = (char*)malloc(dirLen + 16);
    CShortClashResult res = scrFailed;
    if (entry != NULL && tmp != NULL)
    {
        memcpy(entry, targetName, dirLen);
        strcpy(entry + dirLen, longName);
        memcpy(tmp, targetName, dirLen);
        DWORD num = (GetTickCount() / 10) % 0xFFF;
        BOOL aside = FALSE;
        *err = ERROR_ALREADY_EXISTS;
        for (int i = 0; i < 0x1000 && !aside; i++)
        {
            sprintf(tmp + dirLen, "sal%03X", (unsigned)(num++ & 0xFFF));
            DWORD e = 0;
            if (SG->SalMoveFile(entry, tmp, &e))
                aside = TRUE;
            else
            {
                *err = e;
                if (e != ERROR_FILE_EXISTS && e != ERROR_ALREADY_EXISTS)
                    break;
            }
        }
        if (aside)
        {
            DWORD e = 0;
            BOOL done = SG->SalMoveFile(sourceName, targetName, &e);
            if (!done)
                *err = e;
            DWORD backErr = 0;
            // feature 281: the move back is tried for about a second (another program may hold the entry)
            auto moveBack = [tmp, entry](DWORD* moveErr)
            { return SG->SalMoveFile(tmp, entry, moveErr); };
            if (!SalMoveBackRetry(moveBack, &backErr)) // its long name back (a new short name)
            {
                // Windows may have made the new name the entry's long name: undo the rename and retry
                if (done && SG->SalMoveFile(targetName, sourceName, &e))
                {
                    done = FALSE;
                    *err = backErr; // second review: the reason the rename was undone
                }
                if (!SalMoveBackRetry(moveBack, &backErr))
                {
                    TRACE_E("MoveAsideShortNameClash(): the entry stays under the temporary name " << tmp);
                    *leftAt = tmp;
                    tmp = NULL; // the caller frees it
                    *err = backErr;
                    res = scrLeftAside;
                }
            }
            *renamed = done;
            if (res != scrLeftAside)
                res = done ? scrDone : scrFailed;
        }
    }
    free(entry);
    free(tmp);
    return res;
}

const char* PathBelowRoot(const char* path, const char* root, int rootLen)
{
    while (rootLen > 0 && root[rootLen - 1] == '\\')
        rootLen--;
    // second review: 'path' may be shorter than the root - never read past its end
    if (rootLen == 0 || memchr(path, 0, rootLen + 1) != NULL ||
        !SalNameOrderEqualCI(path, rootLen, root, rootLen) || path[rootLen] != '\\')
    {
        return NULL;
    }
    return path + rootLen + 1;
}

BOOL FolderPartIsShortNameOfOther(const char* path, const char* root, int rootLen)
{
    const char* below = PathBelowRoot(path, root, rootLen);
    const char* last = strrchr(path, '\\');
    if (below == NULL || last == NULL || last < below)
        return FALSE;
    size_t len = last - path;
    char* prefix = (char*)malloc(len + 1);
    if (prefix == NULL)
        return FALSE;
    BOOL found = FALSE;
    for (const char* s = below; s <= last && !found; s++)
    {
        if (*s != '\\' || s == below)
            continue;
        memcpy(prefix, path, s - path);
        prefix[s - path] = 0;
        found = SplPathIsOnlyShortNameOfOther(prefix);
    }
    free(prefix);
    return found;
}

BOOL CRenamerDialog::MoveFile(char* sourceName, char* targetName, char* newPart,
                              BOOL overwrite, BOOL isDir, BOOL& skip)
{
    CALL_STACK_MESSAGE4("CRenamerDialog::MoveFile(, , , %d, %d, %d)", overwrite,
                        isDir, skip);
    // create the path - feature 207: on the heap; an Undo passes the source's original full name,
    // which may have 260+ bytes of UTF-8 (90 CJK letters) - it overran char dir[MAX_PATH]
    char* dir = SG->DupStr(targetName);
    if (dir == NULL)
    {
        SetLastError(ERROR_NOT_ENOUGH_MEMORY);
        FileError(HWindow, sourceName, IDS_MOVEERROR, FALSE, &skip, &SkipAllMove, IDS_ERROR);
        return FALSE;
    }
    SG->CutDirectory(dir);
    BOOL pathMade = CheckAndCreateDirectory(dir, dir + (newPart - targetName), skip);
    free(dir);
    if (!pathMade)
        return FALSE;

    // perform the move
    if (SG->HasTheSameRootPath(sourceName, targetName))
    {
        while (1)
        {
            DWORD err = 0;
            // feature 210: only the very same bytes are "nothing to do" - a case-only difference of a
            // folder is left to the move (Windows does nothing for one file; in a case-sensitive
            // folder "zh" and "ZH" are two folders, and the code-page StrICmp also took two
            // different letters for one): the move was reported done without moving
            if (strcmp(sourceName, targetName) == 0 ||
                SG->SalMoveFile(sourceName, targetName, &err))
                return TRUE; // success

            // feature 103: "already exists" may name the source itself (another spelling of its name
            // on a server that folds more than Windows); the names below cannot tell, the file
            // system's identity can. Such a target is never deleted: the rename goes through a
            // temporary name, which also tells the two apart (a target that outlives the source's
            // name is another file and the overwrite below follows unchanged)
            // feature 196: TRUE when that proves the existing target ANOTHER file - in a case-sensitive
            // folder "a.txt" -> existing "A.txt" is then an ordinary overwrite (it was refused
            // "already exists" as a change of case; the core's rename: feature 158)
            BOOL provenOther = FALSE;
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
                if (SalLinkPointsAtTarget(srcId, srcThrough, tgtId)) // refused (feature 155: said "already exists")
                {
                    SetLastError(NO_ERROR);
                    // a junction renamed onto the folder it points at is a folder (review of 155)
                    if (FileError(HWindow, sourceName, (srcId.Attr & FILE_ATTRIBUTE_DIRECTORY) ? IDS_MOVEDIRTOITSELF : IDS_MOVETOITSELF,
                                  TRUE, &skip, &SkipAllSameFile, IDS_ERROR))
                        continue; // retry
                    return FALSE;
                }
                CSalExistingTargetAction act = SalDecideExistingTarget(FALSE, err, srcId, tgtId);
                // feature 196 (review): two spellings of one name - only the temporary name proves
                // another file (the target outlives the source's name); different ids and metadata
                // do not (ids derived from the path, a file written between the two reads), and the
                // branch below deletes the target
                if (act == setaLegacy && SalNameOrderEqualCI(sourceName, -1, targetName, -1))
                    act = setaViaTempName;
                if (act == setaViaTempName)
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
                    provenOther = TRUE;
                }
            }

            // feature 196: the name rule of the file system (092; the code-page StrICmp folded no
            // letter outside the code page), and a proven other file in a case-sensitive folder
            // feature 199: the new name is only another file's short (8.3) name - that file is moved aside
            // for the rename (it was offered for overwriting and deleted: "longfilename.txt" lost). Such
            // a name NEVER reaches the delete below (review: a failed move aside fell into it)
            char clashLong[3 * MAX_PATH];
            if ((err == ERROR_ALREADY_EXISTS || err == ERROR_FILE_EXISTS) &&
                !SalNameOrderEqualCI(sourceName, -1, targetName, -1) &&
                TargetIsOnlyShortNameOfOther(targetName, clashLong, sizeof(clashLong)))
            {
                DWORD clashErr = 0;
                BOOL renamed = FALSE;
                char* leftAt = NULL;
                CShortClashResult r = MoveAsideShortNameClash(sourceName, targetName, clashLong, &clashErr,
                                                              &leftAt, &renamed);
                if (r == scrDone)
                    return TRUE;       // success
                if (r == scrLeftAside) // the other file is under the temporary name: always say where
                {
                    const char* errText = SG->GetErrorText(clashErr);
                    size_t msgSize = strlen(errText) + strlen(leftAt) + 4;
                    char* msg = (char*)malloc(msgSize);
                    if (msg != NULL)
                        sprintf_s(msg, msgSize, "%s\n\n%s", errText, leftAt);
                    SG->SalMessageBox(HWindow, msg != NULL ? msg : leftAt, LoadStr(IDS_ERROR), MB_OK | MB_ICONEXCLAMATION);
                    free(msg);
                    free(leftAt);
                    if (renamed)
                        return TRUE;
                    skip = TRUE;
                    return FALSE;
                }
                SetLastError(clashErr); // the reason (the other file was not touched)
                if (!FileError(HWindow, sourceName, IDS_MOVEERROR, TRUE, &skip, &SkipAllMove, IDS_ERROR))
                    return FALSE;
                continue; // retry
            }

            if ((err == ERROR_ALREADY_EXISTS || err == ERROR_FILE_EXISTS) &&
                (!SalNameOrderEqualCI(sourceName, -1, targetName, -1) || provenOther))
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
                SetLastError(err); // feature 131: the reason of the move (the calls above may have changed the last error)
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
    // feature 206: below the Renamer's folder (not while undoing - its paths are the sources' old
    // ones), a folder found only as another entry's short (8.3) name is not this name's: it is made
    // as a folder of its own (as the leaf, 199; as an archive's folder, 204) - "LONGDI~1\x.txt" went
    // into "longdirname" and was offered for overwriting a file there under the typed path
    // Only in the relative-path mode: there the folders below the Renamer's folder come from the
    // pattern; a full path is the user's own (a typed short name keeps resolving, as 204's target)
    const char* ownFrom = Undoing || RenamerOptions.Spec != rsRelativePath ? NULL : PathBelowRoot(directory, Root, RootLen);

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
            if (ownFrom != NULL && start >= ownFrom && SplPathIsOnlyShortNameOfOther(directory))
                goto CREATE_PATH; // another folder's short name: this folder is created (moved aside and back)
            if (SplWToU8(fd.cFileName, fdFileName, _countof(fdFileName)) == 0)
                fdFileName[0] = 0;
            // adjust the case of the name - feature 206: only of the folder's own name spelled
            // otherwise; a folder found only under its short (8.3) name ("LONGDI~1" for
            // "longdirname") is another name: kept, the typed path goes into it as Windows resolves
            // it. The old name is on the heap: a long name was copied into a MAX_PATH buffer
            // (230 letters overran it)
            char* old = NULL;
            if (strcmp(start, fdFileName) != 0 && SalNameOrderEqualCI(start, -1, fdFileName, -1))
            {
                size_t oldSize = (start - directory) + strlen(fdFileName) + 1;
                old = (char*)malloc(oldSize);
                if (old == NULL)
                    TRACE_E("CheckAndCreateDirectory(): low memory, the case of the folder stays as it is");
            }
            if (old != NULL)
            {
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
                        {
                            free(old);
                            return FALSE;
                        }
                        break;
                    }
                }
                free(old);
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
            // feature 206: through the core - a name that is only another entry's short (8.3) name gets
            // a folder of its own (feature 203); never "it exists" for that other entry
            DWORD crErr = ERROR_SUCCESS;
            if (SG->SalCreateDirectoryEx(directory, &crErr))
            {
                if (!Undoing)
                    UndoStack.Add(new CUndoStackEntry(directory, NULL, NULL, FALSE, FALSE));
                break;
            }
            SetLastError(crErr);

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

    // feature 199 (review): the target name is only another file's short (8.3) name - the copy
    // would open that file (OPEN_ALWAYS) and write the source into it: refused, nothing touched
    char clashLong[3 * MAX_PATH];
    while (TargetIsOnlyShortNameOfOther(targetName, clashLong, sizeof(clashLong)))
    {
        SetLastError(ERROR_FILE_EXISTS);
        if (!FileError(HWindow, targetName, IDS_MOVEERROR, TRUE, &skip, &SkipAllMove, IDS_ERROR))
            return FALSE;
    }

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
                            // feature 155: its own text - it said "already exists"; a move (the only caller is the
                            // rename into another root), so "move" (review of 155)
                            SetLastError(NO_ERROR);
                            if (FileError(HWindow, targetName, IDS_MOVETOITSELF,
                                          TRUE, &skip, &SkipAllSameFile, IDS_ERROR))
                                goto COPY_AGAIN; // retry
                            return FALSE;
                        }

                        // feature 199 (second review): the target became another file's short name meanwhile -
                        // never written into (the check at the top runs only once)
                        if (TargetIsOnlyShortNameOfOther(targetName, clashLong, sizeof(clashLong)))
                        {
                            CloseHandle(in);
                            SetLastError(ERROR_FILE_EXISTS);
                            if (FileError(HWindow, targetName, IDS_MOVEERROR, TRUE, &skip, &SkipAllMove, IDS_ERROR))
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

                        // feature 131: the reason why the target was not opened - reading its
                        // attributes above (or restoring them) changed the last error
                        SetLastError(err);
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
