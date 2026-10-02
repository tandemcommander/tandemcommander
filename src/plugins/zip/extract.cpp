// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"
#include <tchar.h>
#include <crtdbg.h>
#include <ostream>
#include <commctrl.h>
#include <stdio.h>

#include "spl_com.h"
#include "spl_base.h"
#include "spl_file.h"
#include "spl_gen.h"
#include "spl_arc.h"
#include "spl_menu.h"
#include "dbg.h"

#include "config.h"
#include "common.h"
#include "zip.rh"
#include "zip.rh2"
#include "lang\lang.rh"
#include "extract.h"
#include "inflate.h"
#include "explode.h"
#include "unshrink.h"
#include "unreduce.h"
#include "unbzip2.h"
#include "crypt.h"
#include "add_del.h"
#include "dialogs.h"

// interface 104: the paths below are UTF-8 and may be long paths, the buffers
// are sized at run time (see CZipUnpack::ExtractFiles)

CZipUnpack::CZipUnpack(const char* zipName, const char* zipRoot, CSalamanderForOperationsAbstract* salamander,
                       TIndirectArray2<char>* archiveVolumes) : CZipCommon(zipName, zipRoot, salamander, archiveVolumes), Passwords(8)
{
    CurPwdEntry = NULL;
    CurPwdForm = 0;
    CALL_STACK_MESSAGE3("CZipUnpack::CZipUnpack(%s, %s, )", zipName, zipRoot);
    Heap = HeapCreate(HEAP_NO_SERIALIZE, INITIAL_HEAP_SIZE, MAXIMUM_HEAP_SIZE);
    if (!Heap)
        ErrorID = IDS_LOWMEM;

    OutputBuffer = NULL;
    Extract = true;
    Unshrinking = false;
    Test = false;
    AllocateWholeFile = true;
    TestAllocateWholeFile = true;
}

int CZipUnpack::UnpackArchive(const char* targetDir, SalEnumSelection next, void* param)
{
    CALL_STACK_MESSAGE2("CZipUnpack::UnpackArchive(%s, , )", targetDir);
    TIndirectArray2<CExtInfo> extrNames(256);  //file names to be extracted
    TIndirectArray2<CFileInfo> extrFiles(256); //file header of files to be extracted
    int dirs;

    int ret = CreateCFile(&ZipFile, ZipName, GENERIC_READ, FILE_SHARE_READ,
                          OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, PE_NOSKIP, NULL,
                          true, false);
    if (ret)
        if (ret == ERR_LOWMEM)
            return ErrorID = IDS_LOWMEM;
        else
            return ErrorID = IDS_NODISPLAY;
    char title[1024];
    sprintf(title, LoadStr(IDS_EXTRPROGTITLE), SalamanderGeneral->SalPathFindFileName(ZipName));
    Salamander->OpenProgressDialog(title, TRUE, NULL, FALSE);
    Salamander->ProgressDialogAddText(LoadStr(IDS_PREPAREDATA), FALSE);
    ErrorID = CheckZip();
    if (!ErrorID && !ZeroZip)
    {
        MatchedTotalSize = CQuadWord(0, 0);
        ExtrFiles = &extrFiles;
        ErrorID = EnumFiles(extrNames, dirs, next, param);
        if (!ErrorID)
        {
            ErrorID = MatchFiles(extrFiles, extrNames, dirs, NULL);
            if (ErrorID && extrFiles.Count)
            {
                if (ErrorID != IDS_NODISPLAY)
                    SalamanderGeneral->ShowMessageBox(LoadStr(ErrorID), LoadStr(IDS_PLUGINNAME), MSGBOX_ERROR);
                ErrorID = 0;
            }
            ProgressTotalSize = MatchedTotalSize;
            if (!ErrorID && extrFiles.Count)
            {
                if (MultiVol)
                {
                    int left = 0, right = 0, i = 0;

                    QuickSortHeaders2(0, extrFiles.Count - 1, extrFiles);
                    while (i < extrFiles.Count)
                    {
                        while (i < extrFiles.Count &&
                               extrFiles[i]->StartDisk == extrFiles[left]->StartDisk)
                        {
                            right = i;
                            i++;
                        }
                        QuickSortHeaders(left, right, extrFiles);
                        left = ++right;
                    }
                }
                else
                {
                    QuickSortHeaders(0, extrFiles.Count - 1, extrFiles);
                }
                if (*OriginalCurrentDir)
                    SetCurrentDirectoryU8(targetDir);
                ErrorID = ExtractFiles(targetDir);
            }
        }
    }
    Salamander->CloseProgressDialog();
    return ErrorID;
}

int CZipUnpack::UnpackOneFile(const char* nameInZip, const CFileData* fileData, const char* targetPath, const char* newFileName)
{
    CALL_STACK_MESSAGE3("CZipUnpack::UnpackOneFile(%s, , %s)", nameInZip, targetPath);
    CFileInfo fileInfo;
    int targetDirLen;
    char* sour;
    CZIPFileData* zipFileData = (CZIPFileData*)fileData->PluginData;

    Unix = zipFileData->Unix;

    int ret = CreateCFile(&ZipFile, ZipName, GENERIC_READ, FILE_SHARE_READ,
                          OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, PE_NOSKIP, NULL, true, false);
    if (ret)
    {
        if (ret == ERR_LOWMEM)
            return ErrorID = IDS_LOWMEM;
        else
            return ErrorID = IDS_NODISPLAY;
    }
    ErrorID = CheckZip();
    if (!ErrorID && !ZeroZip)
    {
        ErrorID = FindFile(nameInZip, &fileInfo, zipFileData->ItemNumber);
        if (!ErrorID)
        {
            // target path + the name from the archive, both UTF-8 -> heap
            int targetDirSize = lstrlen(targetPath) + fileInfo.NameLen +
                                (newFileName != NULL ? lstrlen(newFileName) : 0) + 16;
            TCHAR* targetDir = (TCHAR*)malloc(targetDirSize);
            if (targetDir == NULL)
                return ErrorID = IDS_LOWMEM;
            lstrcpyn(targetDir, targetPath, targetDirSize);
            targetDirLen = lstrlen(targetDir);
            if (targetDirLen && targetDir[targetDirLen - 1] == '\\')
            {
                targetDir[targetDirLen - 1] = 0;
                targetDirLen--;
            }
            fixed_tl64 = NULL;
            fixed_td64 = NULL;
            fixed_tl32 = NULL;
            fixed_td32 = NULL;
            SkipAllIOErrors = 0;
            SkipAllLongNames = 0;
            SkipAllEncrypted = 0;
            SkipAllDataErr = 0;
            SkipAllBadMathods = 0;
            Silent = 0;
            DialogFlags = PE_NOSKIP;
            //fileInfo.FileAttr |= FILE_ATTRIBUTE_TEMPORARY;
            sour = fileInfo.Name + fileInfo.NameLen;
            while (sour > fileInfo.Name)
            {
                if (*sour == '\\')
                    break;
                sour--;
            }
            if (sour > fileInfo.Name)
                RootLen = (int)(sour - fileInfo.Name);
            else
                RootLen = 0;
            InputBuffer = (char*)malloc(DECOMPRESS_INBUFFER_SIZE);
            InBufSize = DECOMPRESS_INBUFFER_SIZE;
            SlideWindow = (char*)malloc(SLIDE_WINDOW_SIZE);
            WinSize = SLIDE_WINDOW_SIZE;
            if (InputBuffer && SlideWindow)
            {
                ErrorID = ExtractSingleFile(targetDir, targetDirLen, &fileInfo, NULL, newFileName);
                InflateFreeFixedHufman();
                free(InputBuffer);
                free(SlideWindow);
            }
            else
            {
                if (InputBuffer)
                    free(InputBuffer);
                if (SlideWindow)
                    free(SlideWindow);
                ErrorID = IDS_LOWMEM;
            }
            free(targetDir);
            //free(fileInfo.Name); the destructor releases it
        }
    }
    return ErrorID;
}

int CZipUnpack::UnpackWholeArchive(const char* mask, const char* targetDir)
{
    CALL_STACK_MESSAGE3("CZipUnpack::UnpackWholeArchive(%s, %s)", mask, targetDir);
    TIndirectArray2<char> maskArray(16);
    TIndirectArray2<CFileInfo> extrFiles(256); //file header of files to be extracted

    int ret = CreateCFile(&ZipFile, ZipName, GENERIC_READ, FILE_SHARE_READ,
                          OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, PE_NOSKIP, NULL,
                          true, false);
    if (ret)
        if (ret == ERR_LOWMEM)
            return ErrorID = IDS_LOWMEM;
        else
            return ErrorID = IDS_NODISPLAY;
    char title[1024];
    sprintf(title, LoadStr(Test ? IDS_TESTPROGTITLE : IDS_EXTRPROGTITLE), SalamanderGeneral->SalPathFindFileName(ZipName));
    Salamander->OpenProgressDialog(title, TRUE, NULL, FALSE);
    Salamander->ProgressDialogAddText(LoadStr(IDS_PREPAREDATA), FALSE);
    ErrorID = CheckZip();
    if (!ErrorID && ArchiveVolumes != NULL)
        ArchiveVolumes->Add(_strdup(ZipName));
    if (!ErrorID && !ZeroZip)
    {
        MatchedTotalSize = CQuadWord(0, 0);
        ExtrFiles = &extrFiles;
        //errorID = EnumFiles(&extrNames, next, param, &extrInfo._CommonInfo);
        ErrorID = PrepareMaskArray(maskArray, mask);
        if (!ErrorID && maskArray.Count)
        {
            ErrorID = MatchFilesToMask(maskArray);
            if (ErrorID && extrFiles.Count)
            {
                if (ErrorID != IDS_NODISPLAY)
                    SalamanderGeneral->ShowMessageBox(LoadStr(ErrorID), LoadStr(IDS_PLUGINNAME), MSGBOX_ERROR);
                ErrorID = 0;
            }
            ProgressTotalSize = MatchedTotalSize;
            if (!ErrorID && extrFiles.Count)
            {
                if (MultiVol)
                {
                    int left = 0,
                        right = 0,
                        i = 0;

                    QuickSortHeaders2(0, extrFiles.Count - 1, extrFiles);
                    while (i < extrFiles.Count)
                    {
                        while (i < extrFiles.Count &&
                               extrFiles[i]->StartDisk == extrFiles[left]->StartDisk)
                        {
                            right = i;
                            i++;
                        }
                        QuickSortHeaders(left, right, extrFiles);
                        left = ++right;
                    }
                }
                else
                {
                    QuickSortHeaders(0, extrFiles.Count - 1, extrFiles);
                }
                if (*OriginalCurrentDir && !Test)
                    SetCurrentDirectoryU8(targetDir);
                ErrorID = ExtractFiles(targetDir);
            }
        }
    }
    Salamander->CloseProgressDialog();
    return ErrorID;
}

int CZipUnpack::FindFile(LPCTSTR name, CFileInfo* fileInfo, int nItem)
{
    CALL_STACK_MESSAGE2("CZipUnpack::FindFile(%s, )", name);
    CFileHeader* centralHeader;
    char* tempName;
    int errorID = 0;
    QWORD readOffset;
    QWORD readSize;
    DWORD pathFlag = Unix ? 0 : NORM_IGNORECASE;
    BOOL found = FALSE;

    centralHeader = (CFileHeader*)malloc(MAX_HEADER_SIZE);
    tempName = (char*)malloc(MAX_HEADER_SIZE);
    if (!centralHeader || !tempName)
    {
        if (centralHeader)
            free(centralHeader);
        if (tempName)
            free(tempName);
        return IDS_LOWMEM;
    }
    readOffset = CentrDirOffs + ExtraBytes;
    readSize = 0;
    if (DiskNum != CentrDirStartDisk && MultiVol)
    {
        DiskNum = CentrDirStartDisk;
        errorID = ChangeDisk();
    }
    int i;
    for (i = 0; readSize < CentrDirSize && !errorID; i++)
    {
        unsigned int s;

        errorID = ReadCentralHeader(centralHeader, &readOffset, &s);
        if (errorID)
            break;
        readSize += s;
        if (i == nItem)
        {
            unsigned int tempNameLen = ProcessName(centralHeader, tempName);
            unsigned int nameLen = lstrlen(name);

            if (tempNameLen == nameLen)
            {
                LPCTSTR str = _tcsrchr(name, '\\');
                int pathLen;
                pathLen = str ? (int)(str - name + 1) : 0;
                if ((CompareString(LOCALE_USER_DEFAULT, pathFlag,
                                   name, pathLen,
                                   tempName, pathLen) == CSTR_EQUAL) &&
                    (CompareString(LOCALE_USER_DEFAULT, 0,
                                   name + pathLen, nameLen - pathLen,
                                   tempName + pathLen, nameLen - pathLen) == CSTR_EQUAL))
                {
                    ProcessHeader(centralHeader, fileInfo);
                    if (!fileInfo->IsDir)
                    {
                        fileInfo->NameLen = tempNameLen;
                        fileInfo->Name = _tcsdup(tempName);
                        if (!fileInfo->Name)
                        {
                            errorID = IDS_LOWMEM;
                            break;
                        }
                        found = TRUE;
                        break;
                    }
                }
            }
        }
    }
    if (!found)
        errorID = IDS_FILENOTFOUND;
    free(centralHeader);
    free(tempName);
    return errorID;
}

int CZipUnpack::PrepareMaskArray(TIndirectArray2<char>& maskArray, const char* masks)
{
    CALL_STACK_MESSAGE2("CZipUnpack::PrepareMaskArray(, %s)", masks);
    const char* sour;
    char* dest;
    char* newMask;
    int newMaskLen;
    char buffer[U8_MAX_NAME + 1]; // single mask (UTF-8)

    sour = masks;
    while (*sour)
    {
        dest = buffer;
        while (*sour)
        {
            if (*sour == ';')
            {
                if (*(sour + 1) == ';')
                    sour++;
                else
                    break;
            }
            if (dest == buffer + U8_MAX_NAME)
                return IDS_TOOLONGMASK;
            *dest++ = *sour++;
        }
        while (--dest >= buffer && *dest <= ' ')
            ;
        *(dest + 1) = 0;
        dest = buffer;
        while (*dest != 0 && *dest <= ' ')
            dest++;
        newMaskLen = (int)strlen(dest);
        if (newMaskLen)
        {
            newMask = new char[newMaskLen + 1];
            if (!newMask)
                return IDS_LOWMEM;
            SalamanderGeneral->PrepareMask(newMask, dest);
            if (!maskArray.Add(newMask))
            {
                delete newMask;
                return IDS_LOWMEM;
            }
        }
        if (*sour)
            sour++;
    }
    return 0;
}

int CZipUnpack::MatchFilesToMask(TIndirectArray2<char>& maskArray)
{
    CALL_STACK_MESSAGE1("CZipUnpack::MatchFilesToMask()");
    CFileHeader* centralHeader;
    CFileInfo* fileInfo;
    char* tempName;
    unsigned tempNameLen;
    char* sour;
    int errorID = 0;
    QWORD readOffset;
    QWORD readSize;
    int j; //temporary variable
    bool hasExtension;

    centralHeader = (CFileHeader*)malloc(MAX_HEADER_SIZE);
    tempName = (char*)malloc(MAX_HEADER_SIZE);
    if (!centralHeader || !tempName)
    {
        if (centralHeader)
            free(centralHeader);
        if (tempName)
            free(tempName);
        return IDS_LOWMEM;
    }
    readOffset = CentrDirOffs + ExtraBytes;
    readSize = 0;
    if (DiskNum != CentrDirStartDisk && MultiVol)
    {
        DiskNum = CentrDirStartDisk;
        errorID = ChangeDisk();
    }
    for (; readSize < CentrDirSize && !errorID;)
    {
        unsigned int s;
        errorID = ReadCentralHeader(centralHeader, &readOffset, &s);
        if (errorID)
            break;
        readSize += s;
        tempNameLen = ProcessName(centralHeader, tempName);
        sour = tempName + tempNameLen;
        hasExtension = false;
        while (sour >= tempName && *sour != '\\')
            if (*sour-- == '.')
                hasExtension = true; // ".cvspass" is treated as an extension in Windows
        sour++;
        for (j = 0; j < maskArray.Count; j++)
        {
            if (SalamanderGeneral->AgreeMask(sour, maskArray[j], hasExtension))
            {
                fileInfo = new CFileInfo;
                if (!fileInfo)
                {
                    errorID = IDS_LOWMEM;
                    break;
                }
                ProcessHeader(centralHeader, fileInfo);
                fileInfo->NameLen = tempNameLen;
                fileInfo->Name = (char*)malloc(tempNameLen + 1);
                if (!fileInfo->Name)
                {
                    delete fileInfo;
                    errorID = IDS_LOWMEM;
                    break;
                }
                lstrcpy(fileInfo->Name, tempName);
                if (!ExtrFiles->Add(fileInfo))
                {
                    delete fileInfo;
                    errorID = IDS_LOWMEM;
                };
                if (!ErrorID)
                    MatchedTotalSize += CQuadWord().SetUI64(fileInfo->Size);
                break;
            }
        }
    }
    free(centralHeader);
    free(tempName);
    return errorID;
}

//inflate hi-level routines
#define CZIPUNPACK(decompress) ((CZipUnpack*)decompress->UserData)

void Refill(CDecompressionObject* decompress)
{
    CALL_STACK_MESSAGE1("Refill()");

    if (CZIPUNPACK(decompress)->BytesLeft == 0)
    {
        TRACE_E("Pozadavek na doplneni vstupniho bufferu za hranici zkomprimovanych dat");
        decompress->Input->Error = IDS_EOF;
        return;
    }

    int s = (int)min(CZIPUNPACK(decompress)->InBufSize, CZIPUNPACK(decompress)->BytesLeft);
    decompress->Input->Error =
        CZIPUNPACK(decompress)->SafeRead(CZIPUNPACK(decompress)->InputBuffer, s, NULL);

    if (decompress->Input->Error)
        return;

    CZIPUNPACK(decompress)->BytesLeft -= s;

    if (CZIPUNPACK(decompress)->Encrypted)
    {
        if (CZIPUNPACK(decompress)->AESContextValid)
        {
            SalamanderCrypt->AESDecrypt(&CZIPUNPACK(decompress)->AESContext, CZIPUNPACK(decompress)->InputBuffer, s);
            if (CZIPUNPACK(decompress)->BytesLeft == 0)
            {
                // final chunk, verify the authentication code
                unsigned char mac[AES_MAXHMAC];
                unsigned char macFile[AES_MAXHMAC];
                int mode = CZIPUNPACK(decompress)->AESContext.mode;
                DWORD macLen = SAL_AES_MAC_LENGTH(mode);

                decompress->Input->Error =
                    CZIPUNPACK(decompress)->SafeRead(macFile, macLen, NULL);
                if (decompress->Input->Error)
                    return;

                SalamanderCrypt->AESEnd(&CZIPUNPACK(decompress)->AESContext, mac, &macLen);
                CZIPUNPACK(decompress)->AESContextValid = FALSE;

                if (memcmp(mac, macFile, macLen) != 0)
                {
                    decompress->Input->Error = IDS_MACERROR;
                    return;
                }
            }
        }
        else
            Decrypt(CZIPUNPACK(decompress)->InputBuffer, s, CZIPUNPACK(decompress)->Keys);
    }

    decompress->Input->NextByte = (__UINT8*)CZIPUNPACK(decompress)->InputBuffer;
    decompress->Input->BytesLeft = s;
}

int ExtractFlush(unsigned bytes, CDecompressionObject* decompress)
{
    CALL_STACK_MESSAGE2("ExtractFlush(0x%X, )", bytes);
    uch* buf = CZIPUNPACK(decompress)->Unshrinking ? (decompress->Output->OutBuf) : (decompress->Output->SlideWin);
    //  TRACE_I("Flush");
    CZIPUNPACK(decompress)->Crc = SalamanderGeneral->UpdateCrc32(buf,
                                                                 bytes,
                                                                 CZIPUNPACK(decompress)->Crc);
    if (!CZIPUNPACK(decompress)->Test)
    {
        CZIPUNPACK(decompress)->OutputError =
            CZIPUNPACK(decompress)->Write(CZIPUNPACK(decompress)->OutputFile, buf, bytes, &CZIPUNPACK(decompress)->SkipAllIOErrors);
    }
    else
    {
        CZIPUNPACK(decompress)->ExtractedBytes += bytes;
        CZIPUNPACK(decompress)->OutputError = 0;
    }
    if (!CZIPUNPACK(decompress)->OutputError)
    {
        //CZIPUNPACK(decompress)->OutputPos += bytes;
        if (CZIPUNPACK(decompress)->Salamander->ProgressAddSize(bytes, TRUE))
            return 0;
        else
        {
            CZIPUNPACK(decompress)->UserBreak = true;
            CZIPUNPACK(decompress)->OutputError = 0;
            return 1;
        }
    }
    else
        return 1; //error
}

int CZipUnpack::InflateFile(CFileInfo* fileInfo, BOOL deflate64, int* errorID)
{
    CALL_STACK_MESSAGE1("CZipUnpack::InflateFile(, )");
    CDecompressionObject decompress;
    COutputManager output;
    CInputManager input;
    int exitCode = DEC_NOERROR;
    //int                  result;

    ZipFile->FilePointer = fileInfo->DataOffset;
    BytesLeft = fileInfo->CompSize;
    if (Encrypted)
        BytesLeft -= AESContextValid ? SAL_AES_SALT_LENGTH(AESContext.mode) + SAL_AES_PWD_VER_LENGTH + AES_MAXHMAC : ENCRYPT_HEADER_SIZE;
    Crc = INIT_CRC;
    input.NextByte = (__UINT8*)InputBuffer;
    input.BytesLeft = 0;
    input.Error = 0;
    input.Refill = Refill;
    output.SlideWin = (__UINT8*)SlideWindow;
    output.WinSize = WinSize;
    output.Flush = ExtractFlush;
    decompress.Input = &input;
    decompress.Output = &output;
    decompress.UserData = this;
    decompress.HeapInfo = (void*)Heap;
    decompress.fixed_tl64 = (huft*)fixed_tl64;
    decompress.fixed_td64 = (huft*)fixed_td64;
    decompress.fixed_bl64 = fixed_bl64;
    decompress.fixed_bd64 = fixed_bd64;
    decompress.fixed_tl32 = (huft*)fixed_tl32;
    decompress.fixed_td32 = (huft*)fixed_td32;
    decompress.fixed_bl32 = fixed_bl32;
    decompress.fixed_bd32 = fixed_bd32;
    switch (Inflate(&decompress, deflate64))
    {
    case 1:;
    case 2:
    {
    BadData:
        switch (ProcessError(IDS_ERRCOMPDATA, 0, FileNameDisp,
                             PE_NORETRY | DialogFlags, &SkipAllDataErr))
        {
        case ERR_SKIP:
            exitCode = DEC_SKIP;
            break;
        case ERR_CANCEL:
            exitCode = DEC_CANCEL;
            *errorID = IDS_NODISPLAY;
        }
        break;
    }

    case 3:
        exitCode = DEC_CANCEL;
        *errorID = IDS_LOWMEM;
        break;
    case 4:
    {
        if (decompress.Input->Error == IDS_EOF)
            goto BadData;
        if (decompress.Input->Error == IDS_MACERROR)
        {
            switch (ProcessError(IDS_MACERROR, 0, FileNameDisp,
                                 PE_NORETRY | DialogFlags, &SkipAllDataErr))
            {
            case ERR_SKIP:
                exitCode = DEC_SKIP;
                break;
            case ERR_CANCEL:
                exitCode = DEC_CANCEL;
                *errorID = IDS_NODISPLAY;
            }
        }
        else
        {
            exitCode = DEC_CANCEL;
            *errorID = decompress.Input->Error;
        }
        break;
    }

    case 5:
    {
        switch (OutputError)
        {
        case ERR_SKIP:
            exitCode = DEC_SKIP;
            break;
        case ERR_CANCEL:
            exitCode = DEC_CANCEL;
            *errorID = IDS_NODISPLAY;
        }
    }
    }
    fixed_tl64 = decompress.fixed_tl64;
    fixed_td64 = decompress.fixed_td64;
    fixed_bl64 = decompress.fixed_bl64;
    fixed_bd64 = decompress.fixed_bd64;
    fixed_tl32 = decompress.fixed_tl32;
    fixed_td32 = decompress.fixed_td32;
    fixed_bl32 = decompress.fixed_bl32;
    fixed_bd32 = decompress.fixed_bd32;
    return exitCode;
}

void CZipUnpack::InflateFreeFixedHufman()
{
    CALL_STACK_MESSAGE1("CZipUnpack::InflateFreeFixedHufman()");
    CDecompressionObject decompress;

    decompress.HeapInfo = (void*)Heap;
    decompress.fixed_tl64 = (huft*)fixed_tl64;
    decompress.fixed_td64 = (huft*)fixed_td64;
    decompress.fixed_tl32 = (huft*)fixed_tl32;
    decompress.fixed_td32 = (huft*)fixed_td32;
    FreeFixedHufman(&decompress);
}

int CZipUnpack::UnStoreFile(CFileInfo* fileInfo, int* errorID)
{
    CALL_STACK_MESSAGE1("CZipUnpack::UnStoreFile(, )");
    int exitCode = DEC_NOERROR;
    unsigned readBytes;
    QWORD bytesLeft;
    int result;

    ZipFile->FilePointer = fileInfo->DataOffset;
    bytesLeft = fileInfo->CompSize;
    if (Encrypted)
        bytesLeft -= AESContextValid ? SAL_AES_SALT_LENGTH(AESContext.mode) + SAL_AES_PWD_VER_LENGTH + AES_MAXHMAC : ENCRYPT_HEADER_SIZE;
    Crc = INIT_CRC;
    while (bytesLeft && !UserBreak)
    {
        readBytes = (unsigned)min(InBufSize, bytesLeft);
        *errorID = SafeRead(InputBuffer, readBytes, NULL);
        if (*errorID)
        {
            if (*errorID == IDS_EOF)
            {
                switch (ProcessError(IDS_ERRCOMPDATA, 0, FileNameDisp,
                                     PE_NORETRY | DialogFlags, &SkipAllDataErr))
                {
                case ERR_SKIP:
                    exitCode = DEC_SKIP;
                    *errorID = 0;
                    break;
                case ERR_CANCEL:
                    exitCode = DEC_CANCEL;
                    *errorID = IDS_NODISPLAY;
                }
            }
            else
            {
                exitCode = DEC_CANCEL;
            }
            break;
        }
        else
        {
            bytesLeft -= readBytes;
            if (Encrypted)
            {
                if (AESContextValid)
                {
                    SalamanderCrypt->AESDecrypt(&AESContext, InputBuffer, readBytes);
                    if (bytesLeft == 0)
                    {
                        // final chunk, verify the authentication code
                        unsigned char mac[AES_MAXHMAC];
                        unsigned char macFile[AES_MAXHMAC];
                        int mode = AESContext.mode;

                        *errorID = SafeRead(macFile, SAL_AES_MAC_LENGTH(mode), NULL);
                        if (*errorID)
                        {
                            if (*errorID == IDS_EOF)
                            {
                                switch (ProcessError(IDS_ERRCOMPDATA, 0, FileNameDisp,
                                                     PE_NORETRY | DialogFlags, &SkipAllDataErr))
                                {
                                case ERR_SKIP:
                                    exitCode = DEC_SKIP;
                                    *errorID = 0;
                                    break;
                                case ERR_CANCEL:
                                    exitCode = DEC_CANCEL;
                                    *errorID = IDS_NODISPLAY;
                                }
                            }
                            else
                            {
                                exitCode = DEC_CANCEL;
                            }
                            break;
                        }

                        DWORD macLen;
                        SalamanderCrypt->AESEnd(&AESContext, mac, &macLen);
                        AESContextValid = FALSE;

                        if (memcmp(mac, macFile, macLen) != 0)
                        {
                            switch (ProcessError(IDS_MACERROR, 0, FileNameDisp,
                                                 PE_NORETRY | DialogFlags, &SkipAllDataErr))
                            {
                            case ERR_SKIP:
                                exitCode = DEC_SKIP;
                                *errorID = 0;
                                break;
                            case ERR_CANCEL:
                                exitCode = DEC_CANCEL;
                                *errorID = IDS_NODISPLAY;
                            }
                            break;
                        }
                    }
                }
                else
                    Decrypt(InputBuffer, readBytes, Keys);
            }
            Crc = SalamanderGeneral->UpdateCrc32(InputBuffer, readBytes, Crc);
            if (!Test)
            {
                result = Write(OutputFile, InputBuffer, readBytes, &SkipAllIOErrors);
                if (result)
                {
                    switch (result)
                    {
                    case ERR_SKIP:
                        exitCode = DEC_SKIP;
                        break;
                    case ERR_CANCEL:
                        exitCode = DEC_CANCEL;
                        *errorID = IDS_NODISPLAY;
                    }
                    break;
                }
            }
            if (!Salamander->ProgressAddSize(readBytes, TRUE))
                UserBreak = true;
        }
    }
    return exitCode;
}

int CZipUnpack::ExplodeFile(CFileInfo* fileInfo, int* errorID)
{
    CALL_STACK_MESSAGE1("CZipUnpack::ExplodeFile(, )");
    CDecompressionObject decompress;
    COutputManager output;
    CInputManager input;
    int exitCode = DEC_NOERROR;

    ZipFile->FilePointer = fileInfo->DataOffset;
    BytesLeft = fileInfo->CompSize;
    if (Encrypted)
        BytesLeft -= AESContextValid ? SAL_AES_SALT_LENGTH(AESContext.mode) + SAL_AES_PWD_VER_LENGTH + AES_MAXHMAC : ENCRYPT_HEADER_SIZE;
    decompress.csize = BytesLeft;
    Crc = INIT_CRC;
    input.NextByte = (__UINT8*)InputBuffer;
    input.BytesLeft = 0;
    input.Error = 0;
    input.Refill = Refill;
    output.SlideWin = (__UINT8*)SlideWindow;
    output.WinSize = WinSize;
    output.Flush = ExtractFlush;
    decompress.Input = &input;
    decompress.Output = &output;
    decompress.UserData = this;
    decompress.HeapInfo = (void*)Heap;
    decompress.ucsize = fileInfo->Size;
    decompress.Flag = fileInfo->Flag;
    switch (Explode(&decompress))
    {
    case 1:;
    case 2:
    {
    BadData:
        switch (ProcessError(IDS_ERRCOMPDATA, 0, FileNameDisp,
                             PE_NORETRY | DialogFlags, &SkipAllDataErr))
        {
        case ERR_SKIP:
            exitCode = DEC_SKIP;
            break;
        case ERR_CANCEL:
            exitCode = DEC_CANCEL;
            *errorID = IDS_NODISPLAY;
        }
        break;
    }

    case 3:
        exitCode = DEC_CANCEL;
        *errorID = IDS_LOWMEM;
        break;

    case 4:
    {
        if (decompress.Input->Error == IDS_EOF)
            goto BadData;
        if (decompress.Input->Error == IDS_MACERROR)
        {
            switch (ProcessError(IDS_MACERROR, 0, FileNameDisp,
                                 PE_NORETRY | DialogFlags, &SkipAllDataErr))
            {
            case ERR_SKIP:
                exitCode = DEC_SKIP;
                break;
            case ERR_CANCEL:
                exitCode = DEC_CANCEL;
                *errorID = IDS_NODISPLAY;
            }
        }
        else
        {
            exitCode = DEC_CANCEL;
            *errorID = decompress.Input->Error;
        }
        break;
    }

    case 5:
    {
        switch (OutputError)
        {
        case ERR_SKIP:
            exitCode = DEC_SKIP;
            break;
        case ERR_CANCEL:
            exitCode = DEC_CANCEL;
            *errorID = IDS_NODISPLAY;
        }
    }
    }
    return exitCode;
}

int CZipUnpack::UnShrinkFile(CFileInfo* fileInfo, int* errorID)
{
    CALL_STACK_MESSAGE1("CZipUnpack::UnShrinkFile(, )");
    CDecompressionObject decompress;
    COutputManager output;
    CInputManager input;
    int exitCode = DEC_NOERROR;
    //int                  result;

    ZipFile->FilePointer = fileInfo->DataOffset;
    BytesLeft = fileInfo->CompSize;
    if (Encrypted)
        BytesLeft -= AESContextValid ? SAL_AES_SALT_LENGTH(AESContext.mode) + SAL_AES_PWD_VER_LENGTH + AES_MAXHMAC : ENCRYPT_HEADER_SIZE;
    decompress.CompBytesLeft = BytesLeft;
    Crc = INIT_CRC;
    input.NextByte = (__UINT8*)InputBuffer;
    input.BytesLeft = 0;
    input.Error = 0;
    input.Refill = Refill;
    output.SlideWin = (__UINT8*)SlideWindow;
    output.WinSize = WinSize;
    output.Flush = ExtractFlush;
    if (!OutputBuffer)
    {
        OutputBuffer = (char*)malloc(OUTPUT_BUFFER_SIZE);
        if (!OutputBuffer)
        {
            *errorID = IDS_LOWMEM;
            return DEC_CANCEL;
        }
        OutBufSize = OUTPUT_BUFFER_SIZE;
    }
    output.OutBuf = (uch*)OutputBuffer;
    output.BufSize = OutBufSize;
    decompress.Input = &input;
    decompress.Output = &output;
    decompress.UserData = this;
    decompress.HeapInfo = (void*)Heap;
    Unshrinking = true;
    switch (Unshrink(&decompress))
    {
    case 1:
    {
        if (decompress.Input->Error == IDS_EOF ||
            decompress.Input->Error == IDS_MACERROR)
        {
            switch (ProcessError(
                decompress.Input->Error == IDS_MACERROR ? IDS_MACERROR : IDS_ERRCOMPDATA,
                0, FileNameDisp,
                PE_NORETRY | DialogFlags, &SkipAllDataErr))
            {
            case ERR_SKIP:
                exitCode = DEC_SKIP;
                break;
            case ERR_CANCEL:
                exitCode = DEC_CANCEL;
                *errorID = IDS_NODISPLAY;
            }
        }
        else
        {
            exitCode = DEC_CANCEL;
            *errorID = decompress.Input->Error;
        }
        break;
    }

    case 2:
    {
        switch (OutputError)
        {
        case ERR_SKIP:
            exitCode = DEC_SKIP;
            break;
        case ERR_CANCEL:
            exitCode = DEC_CANCEL;
            *errorID = IDS_NODISPLAY;
        }
    }
    }
    Unshrinking = false;
    return exitCode;
}

int CZipUnpack::UnReduceFile(CFileInfo* fileInfo, int* errorID)
{
    CALL_STACK_MESSAGE1("CZipUnpack::UnReduceFile(, )");
    CDecompressionObject decompress;
    COutputManager output;
    CInputManager input;
    int exitCode = DEC_NOERROR;

    ZipFile->FilePointer = fileInfo->DataOffset;
    BytesLeft = fileInfo->CompSize;
    if (Encrypted)
        BytesLeft -= AESContextValid ? SAL_AES_SALT_LENGTH(AESContext.mode) + SAL_AES_PWD_VER_LENGTH + AES_MAXHMAC : ENCRYPT_HEADER_SIZE;
    decompress.CompBytesLeft = BytesLeft;
    Crc = INIT_CRC;
    input.NextByte = (__UINT8*)InputBuffer;
    input.BytesLeft = 0;
    input.Error = 0;
    input.Refill = Refill;
    output.SlideWin = (__UINT8*)SlideWindow;
    output.WinSize = WinSize;
    output.Flush = ExtractFlush;
    decompress.Input = &input;
    decompress.Output = &output;
    decompress.UserData = this;
    decompress.HeapInfo = (void*)Heap;
    decompress.ucsize = fileInfo->Size;
    decompress.Method = fileInfo->Method;
    switch (Unreduce(&decompress))
    {
    case 1:
    {
        if (decompress.Input->Error == IDS_EOF ||
            decompress.Input->Error == IDS_MACERROR)
        {
            switch (ProcessError(
                decompress.Input->Error == IDS_MACERROR ? IDS_MACERROR : IDS_ERRCOMPDATA,
                0, FileNameDisp,
                PE_NORETRY | DialogFlags, &SkipAllDataErr))
            {
            case ERR_SKIP:
                exitCode = DEC_SKIP;
                break;
            case ERR_CANCEL:
                exitCode = DEC_CANCEL;
                *errorID = IDS_NODISPLAY;
            }
        }
        else
        {
            exitCode = DEC_CANCEL;
            *errorID = decompress.Input->Error;
        }
        break;
    }

    case 2:
    {
        switch (OutputError)
        {
        case ERR_SKIP:
            exitCode = DEC_SKIP;
            break;
        case ERR_CANCEL:
            exitCode = DEC_CANCEL;
            *errorID = IDS_NODISPLAY;
        }
    }
    }
    return exitCode;
}

int CZipUnpack::UnBZIP2File(CFileInfo* fileInfo, int* errorID)
{
    CALL_STACK_MESSAGE1("CZipUnpack::UnBZIP2File(, )");
    CDecompressionObject decompress;
    COutputManager output;
    CInputManager input;
    int ret, exitCode = DEC_NOERROR;

    memset(&decompress, 0, sizeof(decompress));
    ZipFile->FilePointer = fileInfo->DataOffset;
    BytesLeft = fileInfo->CompSize;
    if (Encrypted)
        BytesLeft -= AESContextValid ? SAL_AES_SALT_LENGTH(AESContext.mode) + SAL_AES_PWD_VER_LENGTH + AES_MAXHMAC : ENCRYPT_HEADER_SIZE;
    decompress.CompBytesLeft = BytesLeft;
    Crc = INIT_CRC;
    input.NextByte = (__UINT8*)InputBuffer;
    input.BytesLeft = 0;
    input.Error = 0;
    input.Refill = Refill;
    output.SlideWin = (__UINT8*)SlideWindow;
    output.WinSize = WinSize;
    output.Flush = ExtractFlush;
    decompress.Input = &input;
    decompress.Output = &output;
    decompress.UserData = this;
    decompress.ucsize = fileInfo->Size;
    switch (ret = UnBZIP2(&decompress))
    {
    case 1:
    {
        if (decompress.Input->Error == IDS_EOF ||
            decompress.Input->Error == IDS_MACERROR)
        {
            switch (ProcessError(
                decompress.Input->Error == IDS_MACERROR ? IDS_MACERROR : IDS_ERRCOMPDATA,
                0, FileNameDisp,
                PE_NORETRY | DialogFlags, &SkipAllDataErr))
            {
            case ERR_SKIP:
                exitCode = DEC_SKIP;
                break;
            case ERR_CANCEL:
                exitCode = DEC_CANCEL;
                *errorID = IDS_NODISPLAY;
            }
        }
        else
        {
            exitCode = DEC_CANCEL;
            *errorID = decompress.Input->Error;
        }
        break;
    }

    case 2:
    {
        switch (OutputError)
        {
        case ERR_SKIP:
            exitCode = DEC_SKIP;
            break;
        case ERR_CANCEL:
            exitCode = DEC_CANCEL;
            *errorID = IDS_NODISPLAY;
            break;
        }
        break;
    }
    case 3: // Out of memory
    case 4: // Error uncompressing BZIP2 stream
        switch (ProcessError(
            ret == 3 ? IDS_LOWMEM : IDS_ERRBZIP2,
            0, FileNameDisp,
            PE_NORETRY | DialogFlags, &SkipAllDataErr))
        {
        case ERR_SKIP:
            exitCode = DEC_SKIP;
            break;
        case ERR_CANCEL:
            exitCode = DEC_CANCEL;
            *errorID = IDS_NODISPLAY;
            break;
        }
        break;
    }
    return exitCode;
}

//
// feature 094: the byte forms of a typed password (src/common/salzippwd.h,
// specs/094-plugin-password-encoding/contracts/zip-password-forms.md Z4)
//

// the n-th candidate of 'entry' in trying order: the form an item already
// verified with goes first, the others keep their order
static int PwdOrder(const CZipPwdEntry* entry, int n)
{
    if (entry->Preferred < 0 || entry->Preferred >= entry->Cands.Count)
        return n;
    if (n == 0)
        return entry->Preferred;
    return n <= entry->Preferred ? n - 1 : n;
}

// AES: tries the byte forms of one typed password against the 2-byte verifier.
// On TRUE the AES context is ready (AESContextValid) and CurPwdEntry/CurPwdForm
// say which form it is. On FALSE '*err' (may be NULL) is the message for the
// user: as before for a single form.
BOOL CZipUnpack::AESTryPassword(CZipPwdEntry* entry, int strength, unsigned char* salt,
                                WORD pwdVerFile, int* err)
{
    CALL_STACK_MESSAGE1("CZipUnpack::AESTryPassword()");
    bool mismatch = false, tooLong = false;
    for (int n = 0; n < entry->Cands.Count; n++)
    {
        int form = PwdOrder(entry, n);
        WORD pwdVer;
        switch (SalamanderCrypt->AESInit(&AESContext, strength, entry->Cands.Forms[form].Bytes,
                                         entry->Cands.Forms[form].Len, salt, &pwdVer))
        {
        case SAL_AES_ERR_GOOD_RETURN:
            if (memcmp(&pwdVer, &pwdVerFile, sizeof(pwdVerFile)) == 0)
            {
                AESContextValid = TRUE;
                CurPwdEntry = entry;
                CurPwdForm = form;
                return TRUE;
            }
            else
            {
                unsigned char dummy[AES_MAXHMAC];
                SalamanderCrypt->AESEnd(&AESContext, dummy, NULL);
                mismatch = true;
            }
            break;
        case SAL_AES_ERR_PASSWORD_TOO_LONG:
            tooLong = true;
            break;
        default:
            if (err != NULL)
                *err = IDS_AESERROR;
            return FALSE;
        }
    }
    if (err != NULL)
        *err = (tooLong && !mismatch) ? IDS_PWDTOOLONG : IDS_BADPWD;
    return FALSE;
}

// classic encryption: appends every byte form of 'entry' that passes the
// one-byte check to 'pass'
void CZipUnpack::ClassicCollect(CZipPwdEntry* entry, const char* header, char check,
                                CZipPwdPass* pass, int* passCount)
{
    __UINT32 keys[3];
    for (int n = 0; n < entry->Cands.Count && *passCount < ZIPPWD_MAX_PASS; n++)
    {
        int form = PwdOrder(entry, n);
        if (!InitKeys(entry->Cands.Forms[form].Bytes, header, check, keys))
        {
            pass[*passCount].Entry = entry;
            pass[*passCount].Form = form;
            (*passCount)++;
        }
    }
    SecureZeroMemory(keys, sizeof(keys));
}

struct CZipPwdVerify
{
    CZipUnpack* Unpack;
    QWORD Left;       // encrypted bytes not read yet
    __UINT32 Keys[3]; // of the candidate
    __UINT32 Crc;
    QWORD SincePump;
    bool Cancelled;
    bool IoError;
};

// reads the next piece of the item into the unpacker's input buffer and
// decrypts it; 0 = nothing more / cannot read
static unsigned VerifyRead(CZipPwdVerify* v)
{
    CZipUnpack* u = v->Unpack;
    if (v->Left == 0 || v->Cancelled)
        return 0;
    unsigned want = (unsigned)min((QWORD)u->InBufSize, v->Left);
    unsigned got = 0;
    if (u->Read(u->ZipFile, u->InputBuffer, want, &got, NULL) || got != want)
    {
        v->IoError = true;
        return 0;
    }
    v->Left -= want;
    Decrypt(u->InputBuffer, want, v->Keys);
    v->SincePump += want;
    if (v->SincePump >= 4 * 1024 * 1024) // keep the progress window alive; Cancel works
    {
        v->SincePump = 0;
        if (!u->Salamander->ProgressAddSize(0, TRUE))
            v->Cancelled = true;
    }
    return want;
}

static void VerifyRefill(CDecompressionObject* decompress)
{
    CZipPwdVerify* v = (CZipPwdVerify*)decompress->UserData;
    unsigned got = VerifyRead(v);
    if (got == 0)
    {
        decompress->Input->Error = IDS_EOF;
        return;
    }
    decompress->Input->NextByte = (__UINT8*)v->Unpack->InputBuffer;
    decompress->Input->BytesLeft = got;
}

static int VerifyFlush(unsigned bytes, CDecompressionObject* decompress)
{
    CZipPwdVerify* v = (CZipPwdVerify*)decompress->UserData;
    v->Crc = SalamanderGeneral->UpdateCrc32(decompress->Output->SlideWin, bytes, v->Crc);
    return v->Cancelled ? 1 : 0;
}

// classic encryption: does the item's content verify (checksum) with the byte
// string 'bytes'? Reads and unpacks the item without any output and without
// the questions of the unpacking path; only a failure of reading the archive
// shows its ordinary I/O error dialog (CZipCommon::Read). 1 = yes, 0 = no,
// -1 = cannot tell (a method or an archive this routine does not handle, a
// read error), -2 = cancelled by the user
int CZipUnpack::ClassicVerify(CFileInfo* fileInfo, CLocalFileHeader* localHeader,
                              const char* header, char check, const char* bytes)
{
    CALL_STACK_MESSAGE1("CZipUnpack::ClassicVerify()");
    if (MultiVol ||
        fileInfo->Method != CM_STORED && fileInfo->Method != CM_DEFLATED && fileInfo->Method != CM_DEFLATE64 ||
        fileInfo->CompSize < ENCRYPT_HEADER_SIZE ||
        fileInfo->DataOffset + fileInfo->CompSize > ZipFile->Size)
        return -1;

    CZipPwdVerify v;
    v.Unpack = this;
    v.Left = fileInfo->CompSize - ENCRYPT_HEADER_SIZE;
    v.Crc = INIT_CRC;
    v.SincePump = 0;
    v.Cancelled = false;
    v.IoError = false;
    if (InitKeys(bytes, header, check, v.Keys))
        return 0;
    ZipFile->FilePointer = fileInfo->DataOffset + ENCRYPT_HEADER_SIZE;

    int ret;
    if (fileInfo->Method == CM_STORED)
    {
        unsigned got;
        while ((got = VerifyRead(&v)) != 0)
            v.Crc = SalamanderGeneral->UpdateCrc32(InputBuffer, got, v.Crc);
        ret = 1;
    }
    else
    {
        CDecompressionObject decompress;
        COutputManager output;
        CInputManager input;
        input.NextByte = (__UINT8*)InputBuffer;
        input.BytesLeft = 0;
        input.Error = 0;
        input.Refill = VerifyRefill;
        output.SlideWin = (__UINT8*)SlideWindow;
        output.WinSize = WinSize;
        output.Flush = VerifyFlush;
        decompress.Input = &input;
        decompress.Output = &output;
        decompress.UserData = &v;
        decompress.HeapInfo = (void*)Heap;
        decompress.fixed_tl64 = (huft*)fixed_tl64;
        decompress.fixed_td64 = (huft*)fixed_td64;
        decompress.fixed_bl64 = fixed_bl64;
        decompress.fixed_bd64 = fixed_bd64;
        decompress.fixed_tl32 = (huft*)fixed_tl32;
        decompress.fixed_td32 = (huft*)fixed_td32;
        decompress.fixed_bl32 = fixed_bl32;
        decompress.fixed_bd32 = fixed_bd32;
        switch (Inflate(&decompress, fileInfo->Method == CM_DEFLATE64))
        {
        case 0:
            ret = 1;
            break;
        case 3: // low memory
            ret = -1;
            break;
        default: // bad data: the usual end of a wrong key
            ret = 0;
            break;
        }
        fixed_tl64 = decompress.fixed_tl64;
        fixed_td64 = decompress.fixed_td64;
        fixed_bl64 = decompress.fixed_bl64;
        fixed_bd64 = decompress.fixed_bd64;
        fixed_tl32 = decompress.fixed_tl32;
        fixed_td32 = decompress.fixed_td32;
        fixed_bl32 = decompress.fixed_bl32;
        fixed_bd32 = decompress.fixed_bd32;
    }
    // the same test as after the real unpacking (see ExtractSingleFile)
    if (ret == 1 && v.Crc != fileInfo->Crc &&
        ((fileInfo->Flag & GPF_DATADESCR) || v.Crc != localHeader->Crc))
        ret = 0;
    if (v.IoError)
        ret = -1;
    if (v.Cancelled)
        ret = -2;
    SecureZeroMemory(v.Keys, sizeof(v.Keys));
    return ret;
}

// classic encryption, more than one byte string passed the check: the index
// of the first one the content verifies with; 0 (the first, as before this
// feature) when it cannot be told; ZIPPWD_CHOOSE_NONE when the content was
// decoded with every one of them and verifies with none (a wrong password);
// ZIPPWD_CHOOSE_CANCEL when the user cancelled
int CZipUnpack::ClassicChoose(CFileInfo* fileInfo, CLocalFileHeader* localHeader,
                              const char* header, char check, CZipPwdPass* pass, int passCount)
{
    CALL_STACK_MESSAGE2("CZipUnpack::ClassicChoose(%d)", passCount);
    for (int i = 0; i < passCount; i++)
    {
        switch (ClassicVerify(fileInfo, localHeader, header, check,
                              pass[i].Entry->Cands.Forms[pass[i].Form].Bytes))
        {
        case 1:
            return i;
        case -1:
            return 0;
        case -2:
            return ZIPPWD_CHOOSE_CANCEL;
        }
    }
    return ZIPPWD_CHOOSE_NONE;
}

int CZipUnpack::ExtractSingleFile(char* targetDir, int targetDirLen,
                                  CFileInfo* fileInfo, BOOL* success, const char* newFileName)
{
    CALL_STACK_MESSAGE2("CZipUnpack::ExtractSingleFile(, %d, , )", targetDirLen);
    CLocalFileHeader* localHeader;
    LPTSTR pathBuf;
    LPTSTR path;
    LPTSTR name;
    LPCTSTR sour;
    LPTSTR dest;
    int errorID = 0;
    //bool                retry;
    //bool                reopenZipFile;
    int result;
    bool skip, bCheckCRC = true;
    bool verifyCancelled = false; // feature 094: Cancel while a password form was being verified
    char errBuf[128];
    CAESExtraField aesExtraField;
    /*
  TRACE_I("Unpacking file: " << fileInfo->Name <<
          ", method: " << fileInfo->Method <<
          ", flag: " << fileInfo->Flag <<
          ", isdir: " << fileInfo->IsDir <<
          ", file attr:" << fileInfo->FileAttr);
*/
    AESContextValid = FALSE; // initialization
    CurPwdEntry = NULL;
    CurPwdForm = 0;
    if (success)
        *success = FALSE;
    localHeader = (CLocalFileHeader*)malloc(MAX_HEADER_SIZE);
    // the name from the archive is UTF-8 and may be long -> size the buffer by the name
    pathBuf = (LPTSTR)malloc(sizeof(TCHAR) * (fileInfo->NameLen + 2));
    if (!localHeader || !pathBuf)
    {
        if (localHeader)
            free(localHeader);
        if (pathBuf)
            free(pathBuf);
        return IDS_LOWMEM;
    }
    *(targetDir + targetDirLen++) = '\\';
    if (DiskNum != fileInfo->StartDisk && MultiVol)
    {
        DiskNum = fileInfo->StartDisk;
        errorID = ChangeDisk();
    }
    if (!errorID)
    {
        errorID = ReadLocalHeader(localHeader, fileInfo->LocHeaderOffs);
        if (!errorID)
        {
            ProcessLocalHeader(localHeader, fileInfo, &aesExtraField);
            path = pathBuf;
            SplitPath(&path, &name, fileInfo->Name + RootLen + (RootLen ? 1 : 0));
            if (newFileName)
                name = (LPTSTR)newFileName;
            sour = path;
            dest = targetDir + targetDirLen;
            if (*sour)
            {
                while (*sour)
                    *dest++ = *sour++;
                *dest++ = '\\';
            }
            if (fileInfo->IsDir)
            {
                if (!Test)
                {
                    //*dest++ = '\\';
                    sour = name;
                    while (*sour)
                        *dest++ = *sour++;
                    *dest = 0;
                    bool retry;
                    do
                    {
                        retry = false;
                        if (!SalamanderGeneral->CheckAndCreateDirectory(targetDir, NULL, TRUE, errBuf, 128))
                        {
                            switch (ProcessError(IDS_ERRCREATEDIR, 0, targetDir, DialogFlags,
                                                 &SkipAllIOErrors, errBuf))
                            {
                            case ERR_RETRY:
                                retry = true;
                                break;
                            case ERR_CANCEL:
                                errorID = IDS_NODISPLAY;
                            }
                        }
                    } while (retry);
                    if (!errorID)
                    {
                        SetFileAttributesU8(targetDir, fileInfo->FileAttr & FILE_ATTTRIBUTE_MASK);
                        if (success)
                        {
                            *success = TRUE;
                        }
                    }
                }
                else if (success)
                {
                    *success = TRUE;
                }
            }
            else
            {
                *dest = 0;
                skip = false;
                bool retry;
                if (!Test)
                {
                    do
                    {
                        retry = false;
                        if (!SalamanderGeneral->CheckAndCreateDirectory(targetDir, NULL, TRUE, errBuf, 128))
                        {
                            switch (ProcessError(IDS_ERRCREATEDIR, 0, targetDir, DialogFlags,
                                                 &SkipAllIOErrors, errBuf))
                            {
                            case ERR_RETRY:
                                retry = true;
                                break;
                            case ERR_CANCEL:
                                errorID = IDS_NODISPLAY;
                            }
                        }
                    } while (retry);
                }
                if (!errorID)
                {
                    sour = name;
                    while (*sour)
                        *dest++ = *sour++;
                    *dest = 0;
                    FileNameDisp = fileInfo->Name + RootLen + (RootLen ? 1 : 0);
                    skip = false;
                    if (fileInfo->Flag & GPF_ENCRYPTED)
                    {
                        if (SkipAllEncrypted)
                            skip = true;
                        else
                        {
                            if (fileInfo->Method == CM_AES)
                            {
                                if (aesExtraField.HeaderID != AES_HEADER_ID ||
                                    aesExtraField.DataSize < sizeof(CAESExtraField) - 4 ||
                                    aesExtraField.Strength < 1 ||
                                    aesExtraField.Strength > 3)
                                {
                                    switch (ProcessError(IDS_BADAES, 0, FileNameDisp,
                                                         PE_NORETRY | DialogFlags, &SkipAllEncrypted))
                                    {
                                    case ERR_SKIP:
                                        skip = true;
                                        break;
                                    default:
                                        errorID = IDS_NODISPLAY;
                                        break;
                                    }
                                }
                                else
                                {
                                    if (aesExtraField.VendorID != AES_NONVENDOR_ID ||
                                        ((AES_VERSION_1 != aesExtraField.Version) && (AES_VERSION_2 != aesExtraField.Version)))
                                        TRACE_E("POZOR: soubor '" << FileNameDisp << "' je zakryptovan neznamou verzi AES, mozne komplikace");

                                    WCHAR pwd[MAX_PASSWORD]; // feature 094: the typed text
                                    unsigned char salt[SAL_AES_MAX_SALT_LENGTH];
                                    WORD pwdVerFile;
                                    bool repeat;

                                    // AES v2 doesn't store CRC, seems to be created by TC
                                    if (AES_VERSION_2 == aesExtraField.Version)
                                        bCheckCRC = false;
                                    ZipFile->FilePointer = fileInfo->DataOffset;
                                    errorID = SafeRead(salt, SAL_AES_SALT_LENGTH(aesExtraField.Strength), NULL);
                                    if (!errorID)
                                        SafeRead(&pwdVerFile, sizeof(pwdVerFile), NULL);
                                    if (!errorID)
                                    {
                                        // try the passwords typed earlier in this operation, every byte form of each
                                        int i;
                                        for (i = 0; i < Passwords.Count && !AESContextValid; i++)
                                            AESTryPassword(Passwords[i], aesExtraField.Strength, salt, pwdVerFile, NULL);
                                        if (!AESContextValid) // the password was not found in the cache
                                            do
                                            {
                                                repeat = false;
                                                pwd[0] = 0;
                                                switch (PasswordDialog(SalamanderGeneral->GetMsgBoxParent(),
                                                                       FileNameDisp, pwd))
                                                {
                                                case IDOK:
                                                {
                                                    int err = IDS_LOWMEM;
                                                    CZipPwdEntry* entry = new CZipPwdEntry;
                                                    if (entry != NULL)
                                                    {
                                                        SalZipPwdCandidates(pwd, &entry->Cands);
                                                        if (AESTryPassword(entry, aesExtraField.Strength, salt, pwdVerFile, &err))
                                                        {
                                                            Passwords.Add(entry);
                                                            err = 0;
                                                        }
                                                        else
                                                            delete entry;
                                                    }
                                                    if (err)
                                                    {
                                                        SalamanderGeneral->ShowMessageBox(LoadStr(err),
                                                                                          LoadStr(IDS_BADPWDTITLE), MSGBOX_ERROR);
                                                        repeat = true;
                                                    }
                                                    break;
                                                }

                                                case IDC_SKIPALL:
                                                    SkipAllEncrypted = true;
                                                case IDC_SKIP:
                                                    skip = true;
                                                    break;
                                                case IDCANCEL:
                                                default:
                                                    errorID = IDS_NODISPLAY;
                                                    break;
                                                }
                                                SecureZeroMemory(pwd, sizeof(pwd));
                                            } while (repeat);
                                        if (AESContextValid)
                                        {
                                            fileInfo->DataOffset +=
                                                SAL_AES_SALT_LENGTH(aesExtraField.Strength) + SAL_AES_PWD_VER_LENGTH;
                                            Encrypted = true;
                                            fileInfo->Method = aesExtraField.Method;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                WCHAR pwd[MAX_PASSWORD]; // feature 094: the typed text
                                char check;
                                char header[ENCRYPT_HEADER_SIZE];

                                ZipFile->FilePointer = fileInfo->DataOffset;
                                errorID = SafeRead(header, ENCRYPT_HEADER_SIZE, NULL);
                                if (!errorID)
                                {
                                    check = fileInfo->Flag & GPF_DATADESCR ? localHeader->Time >> 8 : fileInfo->Crc >> 24;
                                    // feature 094: every byte form of every password typed in this
                                    // operation that passes the one-byte check
                                    CZipPwdPass pass[ZIPPWD_MAX_PASS];
                                    int passCount = 0;
                                    int use = -1;                   // index into 'pass' of the form to decrypt with
                                    CZipPwdEntry* typedEntry = NULL; // the password typed for this item, not in the cache yet
                                    int i;
                                    for (i = 0; i < Passwords.Count; i++)
                                        ClassicCollect(Passwords[i], header, check, pass, &passCount);
                                    for (;;)
                                    {
                                        if (passCount > 0)
                                        {
                                            // the check lets a wrong byte string through 1 time in 256: when
                                            // more than one passed, find the one the content verifies with
                                            // BEFORE anything is written (no output file, no overwrite question)
                                            use = passCount > 1 ? ClassicChoose(fileInfo, localHeader, header, check, pass, passCount) : 0;
                                            if (use != ZIPPWD_CHOOSE_NONE)
                                                break; // a form to use, or cancelled
                                            // the content was decoded with every form that passed and verifies
                                            // with none: a wrong password, told as such before the target file
                                            // is touched (with ONE passing form there is no such knowledge and
                                            // the old path runs: unpack, checksum error)
                                            use = -1;
                                            passCount = 0;
                                            if (typedEntry != NULL)
                                            {
                                                delete typedEntry;
                                                typedEntry = NULL;
                                                SalamanderGeneral->ShowMessageBox(LoadStr(IDS_BADPWD), LoadStr(IDS_BADPWDTITLE), MSGBOX_ERROR);
                                            }
                                        }
                                        // pwd not found in cache
                                        bool again = false;
                                        pwd[0] = 0;
                                        switch (PasswordDialog(SalamanderGeneral->GetMsgBoxParent(), FileNameDisp, pwd))
                                        {
                                        case IDOK:
                                        {
                                            typedEntry = new CZipPwdEntry;
                                            if (typedEntry != NULL)
                                            {
                                                SalZipPwdCandidates(pwd, &typedEntry->Cands);
                                                ClassicCollect(typedEntry, header, check, pass, &passCount);
                                            }
                                            if (passCount == 0)
                                            {
                                                if (typedEntry != NULL)
                                                    delete typedEntry;
                                                typedEntry = NULL;
                                                SalamanderGeneral->ShowMessageBox(LoadStr(IDS_BADPWD), LoadStr(IDS_BADPWDTITLE), MSGBOX_ERROR);
                                            }
                                            again = true;
                                            break;
                                        }
                                        case IDC_SKIPALL:
                                            SkipAllEncrypted = true;
                                        case IDC_SKIP:
                                            skip = true;
                                            break;
                                        case IDCANCEL:
                                        default:
                                            errorID = IDS_NODISPLAY;
                                            break;
                                        }
                                        SecureZeroMemory(pwd, sizeof(pwd));
                                        if (!again)
                                            break;
                                    }
                                    if (use >= 0)
                                    {
                                        if (typedEntry != NULL)
                                        {
                                            Passwords.Add(typedEntry);
                                            typedEntry = NULL;
                                        }
                                        InitKeys(pass[use].Entry->Cands.Forms[pass[use].Form].Bytes, header, check, Keys);
                                        CurPwdEntry = pass[use].Entry;
                                        CurPwdForm = pass[use].Form;
                                        fileInfo->DataOffset += ENCRYPT_HEADER_SIZE;
                                        Encrypted = true;
                                    }
                                    else if (use == ZIPPWD_CHOOSE_CANCEL) // cancelled by the user while verifying
                                    {
                                        verifyCancelled = true;
                                        skip = true;
                                    }
                                    if (typedEntry != NULL)
                                        delete typedEntry;
                                }
                            }
                        }
                        if (skip)
                            UserBreak = !ProgressAddSize(fileInfo->Size);
                        if (verifyCancelled)
                            UserBreak = true;
                    }
                    else
                        Encrypted = false;
                    if (!errorID && !skip)
                    {
                        if (!Test)
                        {
                            char attr[101];
                            int len = lstrlen(ZipName);
                            // name shown in the overwrite dialog: archive + name in archive (UTF-8) -> heap
                            int bufSize = len + fileInfo->NameLen + 2;
                            char* buf = (char*)malloc(bufSize);
                            if (buf == NULL)
                                result = ERR_LOWMEM;
                            else
                            {
                                lstrcpy(buf, ZipName);
                                *(buf + len++) = '\\';
                                lstrcpyn(buf + len, fileInfo->Name, bufSize - len);
                                GetInfo(attr, &fileInfo->LastWrite, fileInfo->Size);
                                result = SafeCreateCFile(&OutputFile, targetDir, buf, attr, GENERIC_WRITE,
                                                         FILE_SHARE_READ, fileInfo->FileAttr & ~FILE_ATTRIBUTE_READONLY | FILE_FLAG_SEQUENTIAL_SCAN,
                                                         DialogFlags, &Silent, &SkipAllIOErrors, fileInfo->Size);
                                free(buf);
                            }
                        }
                        else
                        {
                            result = 0;
                            ExtractedBytes = 0;
                        }
                        if (result)
                        {
                            switch (result)
                            {
                            case ERR_LOWMEM:
                                errorID = IDS_LOWMEM;
                                break;
                            case ERR_SKIP:
                                UserBreak = !ProgressAddSize(fileInfo->Size);
                                break;
                            case ERR_CANCEL:
                                errorID = IDS_NODISPLAY;
                            }
                        }
                        else
                        {
                            switch (fileInfo->Method)
                            {
                            case CM_DEFLATE64:
                                result = InflateFile(fileInfo, TRUE, &errorID);
                                break;
                            case CM_DEFLATED:
                                result = InflateFile(fileInfo, FALSE, &errorID);
                                break;
                            case CM_STORED:
                                result = UnStoreFile(fileInfo, &errorID);
                                break;
                            case CM_IMPLODED:
                                result = ExplodeFile(fileInfo, &errorID);
                                break;
                            case CM_SHRINKED:
                                result = UnShrinkFile(fileInfo, &errorID);
                                break;
                            case CM_REDUCED1:
                            case CM_REDUCED2:
                            case CM_REDUCED3:
                            case CM_REDUCED4:
                                result = UnReduceFile(fileInfo, &errorID);
                                break;
                            case CM_BZIP2:
                                result = UnBZIP2File(fileInfo, &errorID);
                                break;
                            default:
                            {
                                switch (ProcessError(IDS_BADMETHOD, 0, FileNameDisp,
                                                     PE_NORETRY | DialogFlags, &SkipAllBadMathods))
                                {
                                case ERR_SKIP:
                                    result = DEC_SKIP;
                                    break;
                                case ERR_CANCEL:
                                    result = DEC_CANCEL;
                                    errorID = IDS_NODISPLAY;
                                }
                            }
                            } //switch (fileHeader->Method)
                            QWORD remain;
                            if (!Test)
                            {
                                remain = fileInfo->Size - OutputFile->FilePointer;
                                if (result == DEC_NOERROR)
                                {
                                    switch (Flush(OutputFile, OutputFile->OutputBuffer, OutputFile->BufferPosition, &SkipAllIOErrors))
                                    {
                                    case ERR_NOERROR:
                                        result = DEC_NOERROR;
                                        break;
                                    case ERR_SKIP:
                                        result = DEC_SKIP;
                                        break;
                                    case ERR_CANCEL:
                                        result = DEC_CANCEL;
                                        break;
                                    }
                                }
                                SetFileTime(OutputFile->File, &fileInfo->LastWrite,
                                            NULL, &fileInfo->LastWrite);
                                CloseCFile(OutputFile);
                                if (result || UserBreak)
                                    DeleteFileU8(targetDir);
                                else
                                    SetFileAttributesU8(targetDir, fileInfo->FileAttr & FILE_ATTTRIBUTE_MASK);
                            }
                            else
                                remain = fileInfo->Size - ExtractedBytes;
                            if (!UserBreak)
                            {
                                switch (result)
                                {
                                case DEC_NOERROR:
                                {
                                    // sometimes the local header stores different data than the
                                    // central header, so compare the CRC with both
                                    if (bCheckCRC && ((Crc != fileInfo->Crc) &&
                                                      ((fileInfo->Flag & GPF_DATADESCR) || Crc != localHeader->Crc)))
                                    {
                                        if (ProcessError(IDS_ERRCRC, 0, FileNameDisp, PE_NORETRY | DialogFlags,
                                                         &SkipAllDataErr) == ERR_CANCEL)
                                        {
                                            result = DEC_CANCEL;
                                            errorID = IDS_NODISPLAY;
                                        }
                                        if (!Test)
                                        {
                                            SalamanderGeneral->ClearReadOnlyAttr(targetDir);
                                            DeleteFileU8(targetDir);
                                        }
                                    }
                                    else
                                    {
                                        // feature 094: the item verified (checksum; for AES the
                                        // authentication code) - only now is its byte form remembered
                                        // (an empty item "verifies" with any key and says nothing)
                                        if (Encrypted && CurPwdEntry != NULL && fileInfo->Size != 0)
                                            CurPwdEntry->Preferred = CurPwdForm;
                                        if (success)
                                        {
                                            *success = TRUE;
                                        }
                                    }
                                    break;
                                }
                                case DEC_SKIP:
                                    UserBreak = !ProgressAddSize(remain);
                                    break;
                                case DEC_CANCEL:
                                    break;
                                }
                            }
                        }
                    }
                }
            }
#ifdef TRACE_ENABLE
            if (dest - targetDir >= U8_MAX_PATH)
                TRACE_E("Max path length exceeded");
#endif
        }
    }
    *(targetDir + --targetDirLen) = 0;
    free(localHeader);
    free(pathBuf);
    if (AESContextValid)
    {
        unsigned char dummy[AES_MAXHMAC];
        SalamanderCrypt->AESEnd(&AESContext, dummy, NULL);
    }
    return errorID;
} /* CZipUnpack::ExtractSingleFile */

int CZipUnpack::ExtractFiles(const char* targetDir)
{
    CALL_STACK_MESSAGE2("CZipUnpack::ExtractFiles(%s)", targetDir);
    CLocalFileHeader* localHeader;
    CFileInfo* fileInfo;
    char* tempDir;
    int tempDirLen;
    LPTSTR progrTextBuf;
    LPTSTR progrText;
    const char* sour;
    //int                 rootLen = lstrlen(ZipRoot);
    int errorID = 0;
    int i;

    // the target path and the names from the archive are UTF-8 and may be long ->
    // size the buffers by the longest name we are going to extract
    int maxNameLen = 0;
    for (i = 0; i < ExtrFiles->Count; i++)
        if ((int)(*ExtrFiles)[i]->NameLen > maxNameLen)
            maxNameLen = (*ExtrFiles)[i]->NameLen;
    int tempDirSize = lstrlen(targetDir) + maxNameLen + 16;

    InputBuffer = (char*)malloc(DECOMPRESS_INBUFFER_SIZE);
    InBufSize = DECOMPRESS_INBUFFER_SIZE;
    SlideWindow = (char*)malloc(SLIDE_WINDOW_SIZE);
    WinSize = SLIDE_WINDOW_SIZE;
    localHeader = (CLocalFileHeader*)malloc(MAX_HEADER_SIZE);
    tempDir = (char*)malloc(sizeof(TCHAR) * tempDirSize);
    progrTextBuf = (LPTSTR)malloc(sizeof(TCHAR) * (maxNameLen + 128)); // + the "extracting" prefix
    if (!localHeader || !tempDir || !progrTextBuf ||
        !InputBuffer || !SlideWindow)
    {
        if (localHeader)
            free(localHeader);
        if (tempDir)
            free(tempDir);
        if (progrTextBuf)
            free(progrTextBuf);
        if (InputBuffer)
            free(InputBuffer);
        if (SlideWindow)
            free(SlideWindow);
        return IDS_LOWMEM;
    }
    /*
  if (!SalGetTempFileName(targetDir, "Sal", tempDir, FALSE, NULL))
    errorID = IDS_ERRTEMPDIR;
  else
  {
  */
    lstrcpy(tempDir, targetDir);
    tempDirLen = lstrlen(tempDir);
    if (tempDirLen && tempDir[tempDirLen - 1] == '\\')
    {
        tempDir[tempDirLen - 1] = 0;
        tempDirLen--;
    }
    if (!Test && !SalamanderGeneral->TestFreeSpace(SalamanderGeneral->GetMsgBoxParent(),
                                                   targetDir, ProgressTotalSize, LoadStr(IDS_PLUGINNAME)))
        errorID = IDS_NODISPLAY;
    {
        progrText = progrTextBuf;
        sour = LoadStr(Test ? IDS_TESTING : IDS_EXTRACTING);
        while (*sour)
            *progrText++ = *sour++;
        fixed_tl64 = NULL; //for
        fixed_td64 = NULL;
        fixed_tl32 = NULL; //for
        fixed_td32 = NULL;
        DialogFlags = 0;
        SkipAllIOErrors = 0;
        SkipAllLongNames = 0;
        SkipAllEncrypted = 0;
        SkipAllDataErr = 0;
        SkipAllBadMathods = 0;
        Silent = 0;
        ProgressTotalSize += CQuadWord(ExtrFiles->Count, 0);
        Salamander->ProgressDialogAddText(LoadStr(Test ? IDS_TESTFILES : IDS_EXTRACTFILES), FALSE);
        for (i = 0; i < ExtrFiles->Count && !errorID && !UserBreak; i++)
        {
            fileInfo = (*ExtrFiles)[i];
            // long paths are supported (W API + \\?\), only the OS limit still applies
            DWORD pathLen = tempDirLen + 1 + fileInfo->NameLen - RootLen - (RootLen ? 1 : 0);
            if (pathLen >= (DWORD)tempDirSize || (!Test && pathLen >= U8_MAX_PATH))
            {
                switch (ProcessError(IDS_TOOLONGNAME3, 0, fileInfo->Name + RootLen + (RootLen ? 1 : 0),
                                     PE_NORETRY | DialogFlags, &SkipAllLongNames))
                {
                case ERR_SKIP:
                    UserBreak = !ProgressAddSize(fileInfo->Size + 1);
                    continue;
                case ERR_CANCEL:
                    errorID = IDS_NODISPLAY;
                }
                break;
            }
            lstrcpy(progrText, fileInfo->Name + RootLen + (RootLen ? 1 : 0));
            Salamander->ProgressDialogAddText(progrTextBuf, TRUE);
            if (Salamander->ProgressSetSize(CQuadWord(0, 0), CQuadWord(-1, -1), TRUE))
            {
                Salamander->ProgressSetTotalSize(CQuadWord().SetUI64(fileInfo->Size), ProgressTotalSize);
                BOOL ok;
                errorID = ExtractSingleFile(tempDir, tempDirLen, fileInfo, &ok);
                if (!ok)
                    AllFilesOK = FALSE; // for archive testing
                UserBreak = !Salamander->ProgressAddSize(1, TRUE);
            }
            else
                UserBreak = true;
        }
        InflateFreeFixedHufman();
    }
    /*
    Salamander->CloseProgressDialog();
    if (!errorID && !UserBreak)
    {
      char  buf[MAX_PATH + 1];
      int   len;

      lstrcpyn(buf, ZipName, MAX_PATH + 1);
      len = lstrlen(buf);
      if (RootLen)
      {
        *(buf + len) = '\\';
        len++;
      }
      lstrcpyn(buf + len, ZipRoot, MAX_PATH + 1 - lstrlen(buf));
      Salamander->MoveFiles(tempDir, targetDir, tempDir, buf);
    }
    SalamanderGeneral->RemoveTemporaryDir(tempDir);
  }
  */
    free(localHeader);
    free(tempDir);
    free(progrTextBuf);
    free(InputBuffer);
    free(SlideWindow);
    return errorID;
}

int CZipUnpack::SafeRead(void* buffer, unsigned bytesToRead, bool* skipAll)
{
    CALL_STACK_MESSAGE2("CZipUnpack::SafeRead(, 0x%X, )", bytesToRead);
    unsigned read, readTotal = 0;
    int err = 0;

    while (!err)
    {
        if (Read(ZipFile, (char*)buffer + readTotal, bytesToRead, &read, skipAll))
            return IDS_NODISPLAY;

        readTotal += read;
        bytesToRead -= read;

        if (bytesToRead == 0)
            break;

        if (!MultiVol)
        {
            Fatal = true;
            return IDS_EOF;
        }

        DiskNum++;
        err = ChangeDisk();
    }

    return err;
}

/*
int CZipUnpack::SafeRead(void * buffer, unsigned bytesToRead,
                         unsigned * bytesRead, bool * skipAll)
{
  CALL_STACK_MESSAGE2("CZipUnpack::SafeRead(, 0x%X, , )", bytesToRead);
  unsigned  read;
  int       err = 0;
  
  if (Read(ZipFile, buffer, bytesToRead, &read, skipAll))
  {
    err = IDS_NODISPLAY;
  }
  else
  {
    if (!read)
    {
      if (MultiVol)
      {
        DiskNum++;
        err = ChangeDisk();
        if (!err)
        {
          if (Read(ZipFile, buffer, bytesToRead, &read, skipAll))
          {
            err = IDS_NODISPLAY;
          }
          else
          {
            if (!read)
            {
              err = IDS_EOF;
            }
          }
        }
      }
      else
      {
        Fatal = true;
        err = IDS_EOF;
      }
    }
  }
  *bytesRead = read;
  return err;
}
*/

int CZipUnpack::SafeCreateCFile(CFile** file, const char* fileName, const char* arcName,
                                const char* fileData, unsigned int access, unsigned int share,
                                unsigned int attributes, int flags, DWORD* silent,
                                bool* skipAll, QWORD size)
{
    CALL_STACK_MESSAGE8("CZipUnpack::SafeCreateCFile(, %s, %s, %s, 0x%X, 0x%X, "
                        "0x%X, %d, , )",
                        fileName, arcName, fileData, access,
                        share, attributes, flags);
    int result; //temp variable
    int errorID = 0;
    int lastError; //value returned by GetLastError()
    int len = lstrlen(fileName);
    BOOL toSkip = FALSE;
    int flagsNoRetry;

    if ((*file = (CFile*)malloc(sizeof(CFile))) == NULL ||
        ((*file)->FileName = (char*)malloc(len + 1)) == NULL)
    {
        if ((*file)->FileName)
        {
            free((*file)->FileName);
        }
        if (*file)
        {
            free(*file);
            *file = NULL;
        }
        return ERR_LOWMEM;
    }
    (*file)->OutputBuffer = NULL;
    (*file)->InputBuffer = NULL;
    if (access & GENERIC_WRITE &&
        ((*file)->OutputBuffer = (char*)malloc(OUTPUT_BUFFER_SIZE)) == NULL)
    {
        free((*file)->FileName);
        free(*file);
        *file = NULL;
        return ERR_LOWMEM;
    }
    else
    {
        flagsNoRetry = 0;
        while (1)
        {
            CQuadWord q = CQuadWord().SetUI64(size);
            bool allocate = AllocateWholeFile &&
                            CQuadWord(2, 0) < q && q < CQuadWord(0, 0x80000000);
            if (TestAllocateWholeFile)
                q += CQuadWord(0, 0x80000000);

            (*file)->File = SalamanderSafeFile->SafeFileCreate(fileName, access, share, attributes,
                                                               FALSE, SalamanderGeneral->GetMsgBoxParent(), arcName, fileData,
                                                               silent, TRUE, &toSkip, NULL, 0, allocate ? &q : NULL, NULL);
            if ((*file)->File != INVALID_HANDLE_VALUE)
            {
                lstrcpy((*file)->FileName, fileName);
                (*file)->FilePointer = 0;
                (*file)->RealFilePointer = 0;
                (*file)->Flags = flags;
                (*file)->BufferPosition = 0;
                (*file)->Size = 0;
                (*file)->BigFile = 1;

                if (allocate)
                {
                    if (q == CQuadWord(0, 0x80000000))
                    {
                        // allocation failed and we will not attempt it again
                        AllocateWholeFile = false;
                        TestAllocateWholeFile = false;
                    }
                    else if (q == CQuadWord(0, 0x00000000))
                    {
                        // allocation failed, but we will try again next time
                    }
                    else
                    {
                        // allocation succeeded
                        TestAllocateWholeFile = false;
                    }
                }

                // // to avoid fragmenting the disk, preallocate the target file size
                // LONG distHi = HIDWORD(size);
                // if (SetFilePointer((*file)->File, LODWORD(size), &distHi, FILE_BEGIN) != 0xFFFFFFFF &&
                //     GetLastError() == NO_ERROR)
                // {
                //   SetEndOfFile((*file)->File);
                //   // move the file pointer back to the beginning
                //   if (SetFilePointer((*file)->File, 0, NULL, FILE_BEGIN) == 0xFFFFFFFF &&
                //       GetLastError() != NO_ERROR)
                //   {
                //     errorID = IDS_ERRACCESS;
                //   }
                // }
                if (errorID == 0)
                    return 0; //OK
            }
            else
            {
                if (toSkip)
                    result = ERR_SKIP;
                else
                    result = ERR_CANCEL;
                goto SCF_ABORT;
            }
            lastError = GetLastError();
            if ((*file)->File != INVALID_HANDLE_VALUE)
                CloseHandle((*file)->File);
            result = ProcessError(errorID, lastError, fileName, flags | flagsNoRetry, skipAll);
            if (result != ERR_RETRY)
            {

            SCF_ABORT:
                free((*file)->FileName);
                if (access & GENERIC_WRITE)
                    free((*file)->OutputBuffer);
                free(*file);
                *file = NULL;
                return result;
            }
        }
    }
}

void CZipUnpack::QuickSortHeaders2(int left, int right, TIndirectArray2<CFileInfo>& headers)
{
    CALL_STACK_MESSAGE_NONE

LABEL_QuickSortHeaders2:

    int i = left, j = right;
    int pivotDiskNum = headers[(i + j) / 2]->StartDisk;
    do
    {
        while (headers[i]->StartDisk <= pivotDiskNum && i < right)
            i++;
        while (pivotDiskNum <= headers[j]->StartDisk && j > left)
            j--;
        if (i <= j)
        {
            CFileInfo* tmp = headers[i];
            headers[i] = headers[j];
            headers[j] = tmp;
            i++;
            j--;
        }
    } while (i <= j); // should they be the same?

    // the following "nice" code was replaced with a stack-saving variant (maximum log(N) recursion depth)
    //  if (left < j) QuickSortHeaders2(left, j, headers);
    //  if (i < right) QuickSortHeaders2(i, right, headers);

    if (left < j)
    {
        if (i < right)
        {
            if (j - left < right - i) // both "halves" need sorting; recurse into the smaller one and handle the other via goto
            {
                QuickSortHeaders2(left, j, headers);
                left = i;
                goto LABEL_QuickSortHeaders2;
            }
            else
            {
                QuickSortHeaders2(i, right, headers);
                right = j;
                goto LABEL_QuickSortHeaders2;
            }
        }
        else
        {
            right = j;
            goto LABEL_QuickSortHeaders2;
        }
    }
    else
    {
        if (i < right)
        {
            left = i;
            goto LABEL_QuickSortHeaders2;
        }
    }
}

BOOL CZipUnpack::ProgressAddSize(QWORD size)
{
    CALL_STACK_MESSAGE_NONE
    while ((__int64)size > 0)
    {
        int s = (int)min(size, INT_MAX);
        if (!Salamander->ProgressAddSize(s, TRUE))
            return FALSE;
        size -= s;
    }
    return TRUE;
}
