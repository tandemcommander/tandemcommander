// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"
#include <crtdbg.h>
#include <ostream>
#include <commctrl.h>

#include "spl_com.h"
#include "spl_base.h"
#include "spl_gen.h"
#include "spl_arc.h"
#include "spl_menu.h"
#include "dbg.h"

#include "array2.h"

#include "selfextr/comdefs.h"
#include "config.h"
#include "typecons.h"
#include "zip.rh2"
#include "chicon.h"
#include "common.h"
#include "add_del.h"
#include "../../common/salzipmember.h" // feature 113: where a record keeps its local header offset

int CZipPack::CountFilesInRoot(int* filesInRoot, bool* rootExist)
{
    CALL_STACK_MESSAGE1("CZipPack::CountFilesInRoot(, )");
    CFileHeader* centralHeader;
    char* tempName;
    unsigned tempNameLen;
    int errorID = 0;
    const char* zipRoot = ZipRoot;
    int rootLen = RootLen;

    //centralHeader = (CFileHeader *) malloc( MAX_HEADER_SIZE);
    tempName = (char*)malloc(MAX_HEADER_SIZE);
    if (!tempName)
    {
        return IDS_LOWMEM;
    }
    *filesInRoot = 0;
    *rootExist = false;
    centralHeader = (CFileHeader*)NewCentrDir;
    for (; (char*)centralHeader < NewCentrDir + /*EONewCentrDir.*/ NewCentrDirSize && !errorID;
         centralHeader = (CFileHeader*)((char*)centralHeader +
                                        sizeof(CFileHeader) +
                                        centralHeader->NameLen +
                                        centralHeader->ExtraLen +
                                        centralHeader->CommentLen))
    {
        if ((char*)centralHeader + sizeof(CFileHeader) > NewCentrDir + /*EONewCentrDir.*/ NewCentrDirSize ||
            (char*)centralHeader + sizeof(CFileHeader) + centralHeader->NameLen +
                    centralHeader->ExtraLen + centralHeader->CommentLen >
                NewCentrDir + /*EONewCentrDir.*/ NewCentrDirSize)
        {
            errorID = IDS_ERRFORMAT;
            Fatal = true;
            break;
        }
        tempNameLen = ProcessName(centralHeader, tempName);
        // feature 110: the folder test of the selection (CZipCommon::MatchFiles) - the files
        // counted here are compared with the files that test chose for deletion. The old
        // CompareString ignored case also in a Unix archive: with Dir/a.txt and DIR/b.txt,
        // deleting a.txt counted b.txt too, and the emptied Dir disappeared from the archive.
        if (tempNameLen >= (unsigned)rootLen &&
            (Unix ? memcmp(tempName, zipRoot, rootLen) : SalamanderGeneral->MemICmp(tempName, zipRoot, rootLen)) == 0)
        {
            if (*(tempName + rootLen) == '\\')
                (*filesInRoot)++;
            else
            {
                if (*(tempName + rootLen) == 0)
                    *rootExist = true;
            }
        }
    }
    //TRACE_I("FilesInRoot " << *filesInRoot);
    //free(centralHeader);
    free(tempName);
    return errorID;
}

int CZipPack::DeleteFiles(int* deletedFiles, QWORD dataEnd)
{
    CALL_STACK_MESSAGE1("CZipPack::DeleteFiles()");
    char* buffer;
    int i = 0;
    QWORD delta = 0;
    QWORD writePos;
    QWORD readPos;
    QWORD moveSize;
    QWORD delSize;
    CFileInfo* curFile;
    CFileInfo* nextFile;
    CLocalFileHeader localHeader;
    unsigned bytesRead;
    int errorID = 0;
    int ret;
    //bool              cancel =  false;
    char progrTextBuf[U8_MAX_NAME + MAX_PATH + 32]; // UTF-8 name of the deleted file
    char* progrText;
    char* sour;
    int progrPrefixLen; //"deleting: "

    buffer = (char*)malloc(DECOMPRESS_INBUFFER_SIZE);
    if (!buffer)
        return IDS_LOWMEM;
    if (Pack)
        sour = LoadStr(IDS_REMOVING);
    else
        sour = LoadStr(IDS_DELETING);
    progrText = progrTextBuf;
    while (*sour)
        *progrText++ = *sour++;
    progrPrefixLen = (int)(progrText - progrTextBuf);
    if (Config.BackupZip)
    {
        Salamander->ProgressDialogAddText(LoadStr(IDS_BACKUPING), TRUE);
        Salamander->ProgressSetTotalSize(CQuadWord().SetUI64(DelFiles[0]->LocHeaderOffs),
                                         ProgressTotalSize);
        errorID = MoveData(0, 0, DelFiles[0]->LocHeaderOffs, buffer);
    }
    if (Pack)
        Salamander->ProgressDialogAddText(LoadStr(IDS_REMOVEFILES), TRUE);
    else
        Salamander->ProgressDialogAddText(LoadStr(IDS_DELETEFILES), TRUE);
    if (!errorID && !UserBreak)
    {
        writePos = DelFiles[0]->LocHeaderOffs;
        for (i; i < DelFiles.Count; i++)
        {
            curFile = DelFiles[i];
            /*
      TRACE_I("Deleting file: " << curFile->Name <<
              ", method: " << curFile->Method <<
              ", flag: " << curFile->Flag <<
              ", isdir: " << curFile->IsDir <<
              ", file attr:" << curFile->FileAttr);
*/
            lstrcpyn(progrText, curFile->Name + RootLen + (RootLen ? 1 : 0), (int)sizeof(progrTextBuf) - progrPrefixLen);
            Salamander->ProgressDialogAddText(progrTextBuf, TRUE);
            if (i + 1 < DelFiles.Count)
                nextFile = DelFiles[i + 1];
            else
                nextFile = NULL;
            ZipFile->FilePointer = curFile->LocHeaderOffs;
            ret = Read(ZipFile, &localHeader, sizeof(CLocalFileHeader), &bytesRead, NULL);
            if (ret || bytesRead != sizeof(CLocalFileHeader))
            {
                if (ret)
                    errorID = IDS_NODISPLAY;
                else
                {
                    Fatal = true;
                    errorID = IDS_ERRFORMAT;
                }
                break;
            }
            else
            {
                int descSize = 0;

                if (curFile->Flag & GPF_DATADESCR)
                {
                    if ((curFile->Size >= 0xFFFFFFFF) || (curFile->CompSize >= 0xFFFFFFFF) || (curFile->LocHeaderOffs >= 0xFFFFFFFF))
                        descSize = sizeof(CZip64DataDescriptor);
                    else
                        descSize = sizeof(CDataDescriptor);
                }
                // feature 113: the same count as SalZipMemberSpan (salzipmember.h), which RestoreReplaced
                // copies back (add.cpp asserts that the structure sizes are the header's constants)
                delSize = sizeof(CLocalFileHeader) +
                          localHeader.NameLen +
                          localHeader.ExtraLen +
                          curFile->CompSize + descSize;
                readPos = curFile->LocHeaderOffs + delSize;
                // feature 113: the member must end where the next member ON DISK (or the old central
                // directory) begins, or before. A data descriptor written without its optional signature
                // (12 bytes, not the 16 counted above) made readPos pass it: the next DELETED member ->
                // moveSize underflowed, the rest moved shifted by 4 bytes; an untouched member in between
                // -> moved without its first 4 bytes (silently). Refused before anything is moved. The
                // records above curFile still hold original offsets (earlier regions lie below it), and the
                // added files of DeleteAfterPack begin at CentrDirOffs.
                // The bound fails closed: a record that cannot be read (or a truncated directory) refuses too.
                unsigned long long nextOnDisk;
                if (!SalZipNextMemberOffset((const unsigned char*)NewCentrDir, (size_t)NewCentrDirSize,
                                            curFile->LocHeaderOffs, CentrDirOffs, &nextOnDisk) ||
                    readPos > nextOnDisk)
                {
                    Fatal = true;
                    errorID = IDS_ERRFORMAT;
                    break;
                }
                delta = readPos - writePos;
                if (nextFile)
                    moveSize = nextFile->LocHeaderOffs - readPos;
                else
                    moveSize = dataEnd - readPos; // the central directory, or the end of the added files (113)
                // feature 113: after packing (DeleteAfterPack) a cancel is not taken - every added file is
                // stored, and stopping half-way would leave the replaced members beside them
                if (!Salamander->ProgressSetSize(CQuadWord(0, 0), CQuadWord(-1, -1), TRUE) && !DeleteAfterPack)
                {
                    UserBreak = true;
                    break;
                }
                Salamander->ProgressSetTotalSize(CQuadWord().SetUI64(moveSize), ProgressTotalSize);
                errorID = MoveData(writePos, readPos, moveSize, buffer);
                // feature 113: the directory follows the data only when the data was moved (before, the
                // offsets were updated also after MoveData failed - in-place, a failure on the first
                // block left every entry of the region pointing at data that had not moved)
                if (errorID)
                    break;
                UpdateCentrDir(curFile, nextFile, delta);
                if (DeleteAfterPack && !nextFile)
                    UpdateAddedOffsets(curFile, nextFile, delta); // the added files are all after the last old member
                writePos += moveSize;
                if (!Salamander->ProgressAddSize(localHeader.NameLen + localHeader.ExtraLen + descSize, TRUE) && !DeleteAfterPack)
                {
                    if (!UserBreak)
                        Salamander->ProgressDialogAddText(LoadStr(IDS_CANCELING), FALSE);
                    UserBreak = true;
                }
                if (UserBreak && !DeleteAfterPack)
                {
                    if (!Config.BackupZip)
                        i++;
                    break;
                }
            }
        }
    }
    *deletedFiles = i;
    if (*deletedFiles == DelFiles.Count)
        /*EONewCentrDir.*/ NewCentrDirOffs = writePos;
    free(buffer);
    return errorID;
}

int CZipPack::MoveData(QWORD writePos, QWORD readPos, QWORD moveSize, char* buffer)
{
    CALL_STACK_MESSAGE4("CZipPack::MoveData(%I64u, %I64u, %I64u, , )", writePos,
                        readPos, moveSize);
    unsigned readSize;
    unsigned bytesRead;
    int ret;
    int errorID = 0;

    while (moveSize)
    {
        if (moveSize > DECOMPRESS_INBUFFER_SIZE)
            readSize = DECOMPRESS_INBUFFER_SIZE;
        else
            readSize = (unsigned)moveSize;
        ZipFile->FilePointer = readPos;
        ret = Read(ZipFile, buffer, readSize, &bytesRead, NULL);
        if (ret || bytesRead != readSize)
        {
            if (ret)
                errorID = IDS_NODISPLAY;
            else
            {
                Fatal = true;
                errorID = IDS_ERRFORMAT;
            }
            break;
        }
        TempFile->FilePointer = writePos;
        if (Write(TempFile, buffer, readSize, NULL))
        {
            errorID = IDS_NODISPLAY;
            break;
        }
        moveSize -= readSize;
        writePos += readSize;
        readPos += readSize;
        if (!Salamander->ProgressAddSize(readSize, TRUE))
        {
            if (!UserBreak)
                Salamander->ProgressDialogAddText(LoadStr(IDS_CANCELING), FALSE);
            Salamander->ProgressEnableCancel(FALSE);
            UserBreak = true;
            if (Config.BackupZip)
                break;
        }
    }
    return errorID;
}

void CZipPack::UpdateCentrDir(CFileInfo* curFile, CFileInfo* nextFile, QWORD delta)
{
    CALL_STACK_MESSAGE2("CZipPack::UpdateCentrDir(, , 0x%I64X)", delta);
    CFileHeader* centrHeader;
    char* sour;
    int i;
    unsigned size;

    centrHeader = (CFileHeader*)NewCentrDir;
    for (i = 0; (char*)centrHeader < NewCentrDir + /*EONewCentrDir.*/ NewCentrDirSize;)
    {
        QWORD locHeaderOffs = centrHeader->LocHeaderOffs;
        char* locHeaderOffsOffs = NULL;
        bool noOffset = false; // feature 113: a zip64 marker without a value - never adjusted

        if (0xFFFFFFFF == locHeaderOffs)
        {
            // feature 113: the zip64 block is found by its id (SalZipCentralRecordOffsetPos), not assumed
            // to be the first block - a member put back by RestoreReplaced, or a foreign archive, can
            // have it after an AES / time-stamp / NTFS block, and the old code then read (and wrote) the
            // offset inside that other block
            size_t recLen = sizeof(CFileHeader) + centrHeader->NameLen + centrHeader->ExtraLen + centrHeader->CommentLen;
            size_t avail = (size_t)((NewCentrDir + NewCentrDirSize) - (char*)centrHeader);
            size_t pos = SalZipCentralRecordOffsetPos((const unsigned char*)centrHeader, recLen <= avail ? recLen : avail);
            if (pos != 0 && pos != 42)
            {
                locHeaderOffsOffs = (char*)(centrHeader) + pos;
                memcpy(&locHeaderOffs, locHeaderOffsOffs, sizeof(QWORD));
            }
            else
                noOffset = true; // (before: 0xFFFFFFFF - delta could be written into the 32-bit field)
        }

        if (locHeaderOffs == curFile->LocHeaderOffs)
        {
            sour = (char*)centrHeader +
                   sizeof(CFileHeader) +
                   centrHeader->NameLen +
                   centrHeader->ExtraLen +
                   centrHeader->CommentLen;
            size = (int)((NewCentrDir + /*EONewCentrDir.*/ NewCentrDirSize) - sour);
            /*EONewCentrDir.*/ NewCentrDirSize -= sizeof(CFileHeader) +
                                                  centrHeader->NameLen +
                                                  centrHeader->ExtraLen +
                                                  centrHeader->CommentLen;
            memmove(centrHeader, sour, size);
            EONewCentrDir.TotalEntries--;
            EONewCentrDir.DiskTotalEntries--;
            continue;
        }
        if (!noOffset && locHeaderOffs > curFile->LocHeaderOffs &&
            (!nextFile || locHeaderOffs < nextFile->LocHeaderOffs))
        {
            locHeaderOffs -= delta;
            if (!locHeaderOffsOffs)
            {
                // Was 32bit, still is 32bit
                centrHeader->LocHeaderOffs = (__UINT32)locHeaderOffs;
            }
            else
            {
                // We leave Zip64 record here even when no longer needed, it is not a violation
                memcpy(locHeaderOffsOffs, &locHeaderOffs, sizeof(QWORD));
            }
        }
        centrHeader = (CFileHeader*)((char*)centrHeader +
                                     sizeof(CFileHeader) +
                                     centrHeader->NameLen +
                                     centrHeader->ExtraLen +
                                     centrHeader->CommentLen);
        i++;
    }
}

void CZipPack::UpdateAddedOffsets(CFileInfo* curFile, CFileInfo* nextFile, QWORD delta)
{
    CALL_STACK_MESSAGE2("CZipPack::UpdateAddedOffsets(, , 0x%I64X)", delta);
    int i;
    for (i = 0; i < AddFiles.Count; i++)
    {
        CAddInfo* added = AddFiles[i];
        if (added->Action != AF_ADD && added->Action != AF_OVERWRITE)
            continue; // not stored - its offset means nothing
        if (added->LocHeaderOffs > curFile->LocHeaderOffs &&
            (!nextFile || added->LocHeaderOffs < nextFile->LocHeaderOffs))
            added->LocHeaderOffs -= delta;
    }
}

void CZipPack::Recover(bool withAdded)
{
    CALL_STACK_MESSAGE2("CZipPack::Recover(%d)", withAdded);
    RecoverOK = false;
    TempFile->Flags |= PE_QUIET;
    if (withAdded)
    {
        // feature 113: the error came after packing (in-place mode, DeleteReplacedAfterPack): the added
        // files are in the archive, so their entries are written with the remaining old ones
        RecoverOK = FinishPack() == 0;
        return;
    }
    /*
  if (!WriteCentrDir())
    if (!WriteEOCentrDirRecord())
      if(SetEndOfFile(TempFile->File))
        RecoverOK = true;
        */
    if (!WriteCentrDir() && !WriteEOCentrDirRecord() &&
        !Flush(TempFile, TempFile->OutputBuffer, TempFile->BufferPosition, NULL) &&
        SetEndOfFile(TempFile->File))
    {
        RecoverOK = true;
    }
}
