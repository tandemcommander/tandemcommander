// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later
// CommentsTranslationProject: TRANSLATED

#include "precomp.h"

#include "cfgdlg.h"
#include "zip.h"
#include "plugins.h"
#include "pack.h"

//
// ****************************************************************************
// Constants and global variables
// ****************************************************************************
//

// Table of archive definitions and how to handle them - modifying operations
// !!! WARNING: the row order is the archiver index (PACK7ZIPINDEX, PACKRARINDEX),
// see the note at PackBrowseTable in pack1.cpp
const SPackModifyTable PackModifyTable[] =
    {
        // [PACK7ZIPINDEX] 7-Zip console - no modifying operations, it is offered for
        // browsing and unpacking only (feature 084, research R5)
        {
            (TPackErrorTable*)&SevenZipErrors, TRUE,
            NULL, NULL, FALSE,
            NULL, NULL, PMT_EMPDIRS_DONOTDELETE,
            NULL, NULL, FALSE},
        // [PACKRARINDEX] RAR (WinRAR console, Rar.exe) - the list of files is UTF-16
        // (-scul, research R7a), -idq quiet, -y answers yes to every question
        {
            (TPackErrorTable*)&RARErrors, TRUE,
            "$(SourcePath)", "$(Rar32bitExecutable) a -scul -idq -y \"$(ArchiveFullName)\" -ap\"$(TargetPath)\" @\"$(ListUnicodeFullName)\"", TRUE,
            "$(ArchivePath)", "$(Rar32bitExecutable) d -scul -idq -y \"$(ArchiveFileName)\" @\"$(ListUnicodeFullName)\"", PMT_EMPDIRS_DELETE,
            "$(SourcePath)", "$(Rar32bitExecutable) m -scul -idq -y \"$(ArchiveFullName)\" -ap\"$(TargetPath)\" @\"$(ListUnicodeFullName)\"", FALSE}};

//
// ****************************************************************************
// Functions
// ****************************************************************************
//

//
// ****************************************************************************
// Functions for compression
//

//
// ****************************************************************************
// BOOL PackCompress(HWND parent, CFilesWindow *panel, const char *archiveFileName,
//                   const char *archiveRoot, BOOL move, const char *sourceDir,
//                   SalEnumSelection2 nextName, void *param)
//
//   Function for adding requested files to an archive.
//
//   RET: returns TRUE on success, FALSE on error
//        on error the callback function *PackErrorHandlerPtr is called
//   IN:  parent is the parent window of message boxes
//        panel is a pointer to the Salamander file panel
//        archiveFileName is the name of the archive to pack into
//        archiveRoot is the directory in the archive to pack into
//        move is TRUE if files are moved into the archive
//        sourceDir is the path from which the files are packed
//        nextName is a callback function that enumerates names to pack
//        param contains parameters for the enumeration function
//   OUT:

BOOL PackCompress(HWND parent, CFilesWindow* panel, const char* archiveFileName,
                  const char* archiveRoot, BOOL move, const char* sourceDir,
                  SalEnumSelection2 nextName, void* param)
{
    CALL_STACK_MESSAGE5("PackCompress(, , %s, %s, %d, %s, ,)", archiveFileName,
                        archiveRoot, move, sourceDir);
    // find the correct one according to the table
    int format = PackerFormatConfig.PackIsArchive(archiveFileName);
    // Did not find a supported archive - error
    if (format == 0)
        return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_ARCNAME_UNSUP);

    format--;
    if (!PackerFormatConfig.CanPack(format)) // feature 084: also when the packer program is missing
        return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_PACKER_UNSUP);
    int index = PackerFormatConfig.GetPackerIndex(format);

    // Is this not internal processing (DLL)?
    if (index < 0)
    {
        CPluginData* plugin = Plugins.Get(-index - 1);
        if (plugin == NULL || !plugin->SupportPanelEdit)
        {
            return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_ARCNAME_UNSUP);
        }
        return plugin->PackToArchive(panel, archiveFileName, archiveRoot, move,
                                     sourceDir, nextName, param);
    }

    const SPackModifyTable* modifyTable = ArchiverConfig.GetPackerConfigTable(index);
    if (modifyTable->CompressCommand == NULL) // feature 084: 7-Zip console only unpacks
        return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_PACKER_UNSUP);

    // determine whether we perform copy or move
    const char* compressCommand;
    const char* compressInitDir;
    if (!move)
    {
        compressCommand = modifyTable->CompressCommand;
        compressInitDir = modifyTable->CompressInitDir;
    }
    else
    {
        compressCommand = modifyTable->MoveCommand;
        compressInitDir = modifyTable->MoveInitDir;
        if (compressCommand == NULL)
        {
            BOOL ret = (*PackErrorHandlerPtr)(parent, IDS_PACKQRY_NOMOVE);
            if (ret)
            {
                compressCommand = modifyTable->CompressCommand;
                compressInitDir = modifyTable->CompressInitDir;
            }
            else
                return FALSE;
        }
    }

    //
    // If the archiver does not support packing into a directory, we must handle it
    //
    char archiveRootPath[MAX_PATH];
    if (archiveRoot != NULL && *archiveRoot != '\0')
    {
        if (!PackPathFitsMaxPath(parent, archiveRoot, 0)) // feature 098: it was copied without a bound
            return FALSE;
        strcpy(archiveRootPath, archiveRoot);
        if (!modifyTable->CanPackToDir) // the archiver program does not support it
        {
            if ((*PackErrorHandlerPtr)(parent, IDS_PACKQRY_ARCPATH))
                strcpy(archiveRootPath, "\\"); // the user wants to ignore it
            else
                return FALSE; // the user will mind
        }
    }
    else
        strcpy(archiveRootPath, "\\");

    // and perform the actual packing
    return PackUniversalCompress(parent, compressCommand, modifyTable->ErrorTable,
                                 compressInitDir, TRUE, modifyTable->SupportLongNames, archiveFileName,
                                 sourceDir, archiveRootPath, nextName, param, modifyTable->NeedANSIListFile);
}

//
// ****************************************************************************
// BOOL PackUniversalCompress(HWND parent, const char *command, TPackErrorTable *const errorTable,
//                            const char *initDir, BOOL expandInitDir, const BOOL supportLongNames,
//                            const char *archiveFileName, const char *sourceDir,
//                            const char *archiveRoot, SalEnumSelection2 nextName,
//                            void *param, BOOL needANSIListFile)
//
//   Function for adding requested files to an archive. Unlike the previous one
//   it is more general and does not use configuration tables - it can be called
//   independently, everything is determined only by parameters
//
//   RET: returns TRUE on success, FALSE on error
//        on error the callback function *PackErrorHandlerPtr is called
//   IN:  parent is the parent window for message boxes
//        command is the command line used for packing into the archive
//        errorTable is a pointer to the table of archiver return codes, or NULL if it does not exist
//        initDir is the directory in which the program will be started
//        supportLongNames indicates whether the program supports the use of long names
//        archiveFileName is the name of the archive to pack into
//        sourceDir is the path from which the files are packed
//        archiveRoot is the directory in the archive to pack into
//        nextName is a callback function that enumerates names to pack
//        param contains parameters for the enumeration function
//        needANSIListFile is TRUE if the file list should be in ANSI (not OEM)
//   OUT:

BOOL PackUniversalCompress(HWND parent, const char* command, TPackErrorTable* const errorTable,
                           const char* initDir, BOOL expandInitDir, const BOOL supportLongNames,
                           const char* archiveFileName, const char* sourceDir,
                           const char* archiveRoot, SalEnumSelection2 nextName,
                           void* param, BOOL needANSIListFile)
{
    CALL_STACK_MESSAGE9("PackUniversalCompress(, %s, , %s, %d, %d, %s, %s, %s, , , %d)",
                        command, initDir, expandInitDir, supportLongNames, archiveFileName,
                        sourceDir, archiveRoot, needANSIListFile);

    // feature 097: an external archiver gets the name on its command line and through
    // MAX_PATH buffers below - a longer name is refused here, never cut
    if (!PackArchiveNameFitsHandler(parent, archiveFileName, SAL_ARCHIVE_HANDLER_EXTERNAL))
        return FALSE;
    // feature 098: the source folder is copied into MAX_PATH buffers below (strcpy without a bound:
    // a stack overrun from 260 bytes) and becomes the archiver's working folder - a longer one is
    // refused here, before the list file is written or anything is started
    if (!PackPathFitsMaxPath(parent, sourceDir, 0))
        return FALSE;

    //
    // We must adjust the directory in the archive to the required format
    //
    char rootPath[MAX_PATH];
    rootPath[0] = '\0';
    if (archiveRoot != NULL && *archiveRoot != '\0')
    {
        while (*archiveRoot == '\\')
            archiveRoot++;
        if (*archiveRoot != '\0')
        {
            if (!PackPathFitsMaxPath(parent, archiveRoot, 1)) // feature 098: "\\" + the path (it was unbounded)
                return FALSE;
            strcpy(rootPath, "\\");
            strcat(rootPath, archiveRoot);
            while (rootPath[0] != '\0' && rootPath[strlen(rootPath) - 1] == '\\')
                rootPath[strlen(rootPath) - 1] = '\0';
        }
    }
    // for 32-bit programs there will be empty quotes, for 16-bit we add a slash
    if (!supportLongNames && rootPath[0] == '\0')
    {
        rootPath[0] = '\\';
        rootPath[1] = '\0';
    }

    // For path length checks we need sourceDir in the "short" form
    char sourceShortName[MAX_PATH];
    if (!supportLongNames)
    {
        if (!SalGetShortPathName(sourceDir, sourceShortName, MAX_PATH))
        {
            char buffer[1000];
            strcpy(buffer, "GetShortPathName: ");
            strcat(buffer, GetErrorText(GetLastError()));
            return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_GENERAL, buffer);
        }
    }
    else
        strcpy(sourceShortName, sourceDir);

    //
    // In the %TEMP% directory a helper file will contain the list of files to pack
    //

    // Create the temporary file name
    char tmpListNameBuf[MAX_PATH];
    if (!SalGetTempFileName(NULL, "PACK", tmpListNameBuf, TRUE))
    {
        char buffer[1000];
        strcpy(buffer, "SalGetTempFileName: ");
        strcat(buffer, GetErrorText(GetLastError()));
        return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_GENERAL, buffer);
    }

    // we have the file, now open it
    // feature 084: a command using $(ListUnicodeFullName) gets the list in UTF-16
    EPackListEncoding listEnc = PackGetListEncoding(command, needANSIListFile);
    FILE* listFile;
    // feature 069 (F-P1-06): the narrow CRT resolves the name through the ANSI
    // code page, so under a non-ASCII %TEMP% the list file could not be created
    // at all and the packer aborted with "cannot create the file list"
    WCHAR* tmpListNameW = SalU8ToWAlloc(tmpListNameBuf);
    listFile = tmpListNameW != NULL ? _wfopen(tmpListNameW, listEnc == PACKLIST_UNICODE ? L"wb" : L"w")
                                    : fopen(tmpListNameBuf, listEnc == PACKLIST_UNICODE ? "wb" : "w"); // legacy fallback
    if (tmpListNameW != NULL)
        free(tmpListNameW);
    if (listFile != NULL && listEnc == PACKLIST_UNICODE && fwrite("\xFF\xFE", 1, 2, listFile) != 2)
    {
        fclose(listFile);
        listFile = NULL;
    }
    if (listFile == NULL)
    {
        SalDeleteFile(tmpListNameBuf);
        return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_FILE);
    }

    // and we can fill it
    BOOL isDir;

    const char* name;
    unsigned int maxPath;
    char namecnv[MAX_PATH];
    if (!supportLongNames)
        maxPath = DOS_MAX_PATH;
    else
        maxPath = MAX_PATH;
    // feature 069 (F-P1-05): see the note in pack1.cpp - CharToOem read UTF-8 bytes as if they
    // were in the ANSI code page, so the archiver was given a name that does
    // not exist; the legacy call stays as the fallback for a name the console
    // code page cannot express at all
    if (listEnc == PACKLIST_OEM)
    {
        char sourceOem[2 * MAX_PATH];
        if (SalU8ToOEM(sourceShortName, sourceOem, sizeof(sourceOem)) != 0)
            strcpy(sourceShortName, sourceOem);
        else
            CharToOem(sourceShortName, sourceShortName);
    }
    int sourceDirLen = (int)strlen(sourceShortName) + 1;
    int errorOccured;
    // pick the name
    while ((name = nextName(parent, 1, NULL, &isDir, NULL, NULL, NULL, param, &errorOccured)) != NULL)
    {
        if (listEnc == PACKLIST_UNICODE) // UTF-8 names straight to UTF-16, nothing lost
        {
            if (!isDir && !PackWriteListLineW(listFile, name, NULL, NULL))
            {
                fclose(listFile);
                SalDeleteFile(tmpListNameBuf);
                return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_FILE);
            }
            continue;
        }
        if (supportLongNames)
        {
            if (listEnc == PACKLIST_OEM)
            {
                if (SalU8ToOEM(name, namecnv, _countof(namecnv)) == 0)
                    CharToOem(name, namecnv); // legacy fallback
            }
            else
                lstrcpyn(namecnv, name, _countof(namecnv));
        }
        else
        {
            if (SalGetShortPathName(name, namecnv, MAX_PATH) == 0)
            {
                char buffer[1000];
                strcpy(buffer, "File: ");
                strcat(buffer, name);
                strcat(buffer, ", GetShortPathName: ");
                strcat(buffer, GetErrorText(GetLastError()));
                fclose(listFile);
                SalDeleteFile(tmpListNameBuf);
                return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_GENERAL, buffer);
            }
            if (listEnc == PACKLIST_OEM)
            { // 'namecnv' is the 8.3 form here, ASCII in practice
                char shortOem[MAX_PATH];
                if (SalU8ToOEM(namecnv, shortOem, sizeof(shortOem)) != 0)
                    strcpy(namecnv, shortOem);
                else
                    CharToOem(namecnv, namecnv);
            }
        }

        // check the length
        if (sourceDirLen + strlen(namecnv) >= maxPath)
        {
            char buffer[1000];
            fclose(listFile);
            SalDeleteFile(tmpListNameBuf);
            sprintf(buffer, "%s\\%s", sourceShortName, namecnv);
            return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_PATH, buffer);
        }

        // and put it into the list
        if (!isDir)
        {
            if (fprintf(listFile, "%s\n", namecnv) <= 0)
            {
                fclose(listFile);
                SalDeleteFile(tmpListNameBuf);
                return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_FILE);
            }
        }
    }
    // that's it
    fclose(listFile);

    // if an error occurred and the user decided to cancel the operation, end it
    if (errorOccured == SALENUM_CANCEL)
    {
        SalDeleteFile(tmpListNameBuf);
        return FALSE;
    }

    //
    // Now we will launch the external program for compression
    //
    // construct the command line
    char cmdLine[PACK_CMDLINE_MAXLEN];
    // buffer for a temporary name (when creating an archive with a long name and we need its DOS name,
    // DOSTmpName expands instead of the long name; after creating the archive the file is renamed)
    char DOSTmpName[MAX_PATH];
    if (!PackExpandCmdLine(archiveFileName, rootPath, tmpListNameBuf, NULL,
                           command, cmdLine, PACK_CMDLINE_MAXLEN, DOSTmpName))
    {
        SalDeleteFile(tmpListNameBuf);
        return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_CMDLNERR);
    }

    // hack for RAR 4.x+ that dislikes "-ap""" when addressing the archive root; this cleanup works with older RAR too
    // see https://forum.altap.cz/viewtopic.php?f=2&t=5487
    if (*rootPath == 0 && strstr(command, "$(Rar32bitExecutable) ") == command)
    {
        char* pAP = strstr(cmdLine, "\" -ap\"\" @\"");
        if (pAP != NULL)
            memmove(pAP + 1, "         ", 7); // remove "-ap"" that causes issues with newer RAR
    }
    // hack for copying into a directory in RAR - it fails if the path begins with a backslash; it created e.g. \Test directory but Salam shows it as Test
    // https://forum.altap.cz/viewtopic.php?p=24586#p24586
    if (*rootPath == '\\' && strstr(command, "$(Rar32bitExecutable) ") == command)
    {
        char* pAP = strstr(cmdLine, "\" -ap\"\\");
        if (pAP != NULL)
            memmove(pAP + 6, pAP + 7, strlen(pAP + 7) + 1); // remove the leading backslash
    }

    // check if the command line is not too long
    if (!supportLongNames && strlen(cmdLine) >= 128)
    {
        char buffer[1000];
        strcpy(buffer, cmdLine);
        SalDeleteFile(tmpListNameBuf);
        return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_CMDLNLEN, buffer);
    }

    // construct the current directory
    char currentDir[MAX_PATH];
    if (!expandInitDir)
    {
        if (strlen(initDir) < MAX_PATH)
            strcpy(currentDir, initDir);
        else
        {
            SalDeleteFile(tmpListNameBuf);
            return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_IDIRERR);
        }
    }
    else
    {
        if (!PackExpandInitDir(archiveFileName, sourceDir, rootPath, initDir, currentDir,
                               MAX_PATH))
        {
            SalDeleteFile(tmpListNameBuf);
            return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_IDIRERR);
        }
    }

    // back up the short archive file name, later we check whether the long name
    // survived -> if the short one remained, rename it back to the original long name
    char DOSArchiveFileName[MAX_PATH];
    if (!SalGetShortPathName(archiveFileName, DOSArchiveFileName, MAX_PATH))
        DOSArchiveFileName[0] = 0;

    // and run the external program
    BOOL exec = PackExecute(parent, cmdLine, currentDir, errorTable);
    // meanwhile check whether the long name did not vanish -> if the short one
    // remained, rename it to the original long one
    if (DOSArchiveFileName[0] != 0 &&
        SalGetFileAttributes(archiveFileName) == 0xFFFFFFFF &&
        SalGetFileAttributes(DOSArchiveFileName) != 0xFFFFFFFF)
    {
        SalMoveFile(DOSArchiveFileName, archiveFileName); // if it fails, we don't care...
    }
    if (!exec)
    {
        SalDeleteFile(tmpListNameBuf);
        // feature 084: the user stopped the archiver - the archive may be half written
        if (PackLastRunCancelled)
            (*PackErrorHandlerPtr)(parent, IDS_PACKERR_CANCELLED_ARC, archiveFileName);
        return FALSE; // error message has already been displayed
    }

    // the file list is no longer needed
    SalDeleteFile(tmpListNameBuf);

    // if we used a temporary DOS name, rename all files of that name (name.*) to the desired long name
    if (DOSTmpName[0] != 0)
    {
        char src[2 * MAX_PATH];
        strcpy(src, DOSTmpName);
        char* tmpOrigName;
        CutDirectory(src, &tmpOrigName);
        tmpOrigName = DOSTmpName + (tmpOrigName - src);
        SalPathAddBackslash(src, 2 * MAX_PATH);
        char* srcName = src + strlen(src);
        char dstNameBuf[2 * MAX_PATH];
        strcpy(dstNameBuf, archiveFileName);
        char* dstExt = dstNameBuf + strlen(dstNameBuf);
        //    while (--dstExt > dstNameBuf && *dstExt != '\\' && *dstExt != '.');
        while (--dstExt >= dstNameBuf && *dstExt != '\\' && *dstExt != '.')
            ;
        //    if (dstExt == dstNameBuf || *dstExt == '\\' || *(dstExt - 1) == '\\') dstExt = dstNameBuf + strlen(dstNameBuf); // for "name", ".cvspass", "path\\name" or "path\\.name" there is no extension
        if (dstExt < dstNameBuf || *dstExt == '\\')
            dstExt = dstNameBuf + strlen(dstNameBuf); // for "name" or "path\\name" there is no extension; in Windows ".cvspass" is an extension
        char path[MAX_PATH];
        strcpy(path, DOSTmpName);
        char* ext = path + strlen(path);
        //    while (--ext > path && *ext != '\\' && *ext != '.');
        while (--ext >= path && *ext != '\\' && *ext != '.')
            ;
        //    if (ext == path || *ext == '\\' || *(ext - 1) == '\\') ext = path + strlen(path); // for "name", ".cvspass", "path\\name" or "path\\.name" there is no extension
        if (ext < path || *ext == '\\')
            ext = path + strlen(path); // for "name" or "path\\name" there is no extension; in Windows ".cvspass" is an extension
        strcpy(ext, ".*");
        WIN32_FIND_DATA findData;
        WIN32_FIND_DATAW findDataW; // feature 069 (F-P1-06)
        char findNameU8[SAL_FIND_NAME_U8];
        int i;
        for (i = 0; i < 2; i++)
        {
            // feature 069 (F-P1-06): 'path' is UTF-8 (panel/temp), so the ANSI enumeration missed
            // every non-ASCII entry
            HANDLE find = SalFindFirstFile(path, &findDataW); // registers with HANDLES itself
            if (find != INVALID_HANDLE_VALUE)
            {
                do
                {
                    SalConvertFindDataW(&findDataW, &findData, findNameU8, sizeof(findNameU8), NULL, 0);
                    strcpy(srcName, findNameU8);
                    const char* dst;
                    // feature 092: name identity ('tmpOrigName' is a generated ASCII name - same answer as before)
                    if (SalNameEqualOrdinalCI(tmpOrigName, -1, findNameU8, -1))
                        dst = archiveFileName;
                    else
                    {
                        char* srcExt = findNameU8 + strlen(findNameU8);
                        //            while (--srcExt > findNameU8 && *srcExt != '.');
                        while (--srcExt >= findNameU8 && *srcExt != '.')
                            ;
                        //            if (srcExt == findNameU8) srcExt = findNameU8 + strlen(findNameU8);  // ".cvspass" is an extension in Windows ...
                        if (srcExt < findNameU8)
                            srcExt = findNameU8 + strlen(findNameU8);
                        strcpy(dstExt, srcExt);
                        dst = dstNameBuf;
                    }
                    if (i == 0)
                    {
                        if (SalGetFileAttributes(dst) != 0xffffffff)
                        {
                            HANDLES(FindClose(find)); // this name already exists with some extension, searching further
                            (*PackErrorHandlerPtr)(parent, IDS_PACKERR_UNABLETOREN, src, dst);
                            return TRUE; // succeeded, only the resulting archive names differ slightly (even multivolume)
                        }
                    }
                    else
                    {
                        if (!SalMoveFile(src, dst))
                        {
                            DWORD err = GetLastError();
                            TRACE_E("Error (" << err << ") in SalMoveFile(" << src << ", " << dst << ").");
                        }
                    }
                } while (SalFindNextFile(find, &findDataW));
                HANDLES(FindClose(find)); // this name already exists with some extension, searching further
            }
        }
    }

    return TRUE;
}

//
// ****************************************************************************
// Functions for deleting from an archive
//

//
// ****************************************************************************
// BOOL PackDelFromArc(HWND parent, CFilesWindow *panel, const char *archiveFileName,
//                     CPluginDataInterfaceAbstract *pluginData,
//                     const char *archiveRoot, SalEnumSelection nextName,
//                     void *param)
//
//   Function for removing the requested files from an archive.
//
//   RET: returns TRUE on success, FALSE on error
//        on error the callback function *PackErrorHandlerPtr is called
//   IN:  parent is the parent window for message boxes
//        panel is a pointer to the Salamander file panel
//        archiveFileName is the name of the archive we delete from
//        archiveRoot is the directory in the archive we delete from
//        nextName is a callback function that enumerates names to delete
//        param contains parameters for the enumeration function
//   OUT:

BOOL PackDelFromArc(HWND parent, CFilesWindow* panel, const char* archiveFileName,
                    CPluginDataInterfaceAbstract* pluginData,
                    const char* archiveRoot, SalEnumSelection nextName,
                    void* param)
{
    CALL_STACK_MESSAGE3("PackDelFromArc(, , %s, , %s, , ,)", archiveFileName, archiveRoot);

    // find the correct one according to the table
    int format = PackerFormatConfig.PackIsArchive(archiveFileName);
    // Did not find a supported archive - error
    if (format == 0)
        return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_ARCNAME_UNSUP);

    format--;
    if (!PackerFormatConfig.CanPack(format)) // feature 084: also when the packer program is missing
        return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_PACKER_UNSUP);
    int index = PackerFormatConfig.GetPackerIndex(format);

    // Is this not internal processing (DLL)?
    if (index < 0)
    {
        CPluginData* plugin = Plugins.Get(-index - 1);
        if (plugin == NULL || !plugin->SupportPanelEdit)
        {
            return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_ARCNAME_UNSUP);
        }
        return plugin->DeleteFromArchive(panel, archiveFileName, pluginData, archiveRoot,
                                         nextName, param);
    }

    const SPackModifyTable* modifyTable = ArchiverConfig.GetPackerConfigTable(index);
    if (modifyTable->DeleteCommand == NULL) // feature 084: 7-Zip console only unpacks
        return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_PACKER_UNSUP);

    // feature 097: an external archiver gets the name on its command line and through
    // MAX_PATH buffers below - a longer name is refused here, never cut
    if (!PackArchiveNameFitsHandler(parent, archiveFileName, SAL_ARCHIVE_HANDLER_EXTERNAL))
        return FALSE;
    // feature 084: a command using $(ListUnicodeFullName) gets the list in UTF-16
    EPackListEncoding listEnc = PackGetListEncoding(modifyTable->DeleteCommand, modifyTable->NeedANSIListFile);

    //
    // We must adjust the directory in the archive to the required format
    //
    char rootPath[MAX_PATH];
    if (archiveRoot != NULL && *archiveRoot != '\0')
    {
        if (*archiveRoot == '\\')
            archiveRoot++;
        if (*archiveRoot == '\0')
            rootPath[0] = '\0';
        else
        {
            if (!PackPathFitsMaxPath(parent, archiveRoot, 1)) // feature 098: the path + "\\" (it was unbounded)
                return FALSE;
            strcpy(rootPath, archiveRoot);
            if (rootPath[strlen(rootPath) - 1] != '\\')
                strcat(rootPath, "\\");
        }
    }
    else
    {
        rootPath[0] = '\0';
    }

    //
    // in the %TEMP% directory a helper file will contain the list of files to delete
    //
    // buffer for the full name of the helper file
    char tmpListNameBuf[MAX_PATH];
    if (!SalGetTempFileName(NULL, "PACK", tmpListNameBuf, TRUE))
    {
        char buffer[1000];
        strcpy(buffer, "SalGetTempFileName: ");
        strcat(buffer, GetErrorText(GetLastError()));
        return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_GENERAL, buffer);
    }

    // we have the file, now open it
    FILE* listFile;
    // feature 069 (F-P1-06): the narrow CRT resolves the name through the ANSI
    // code page, so under a non-ASCII %TEMP% the list file could not be created
    // at all and the packer aborted with "cannot create the file list"
    WCHAR* tmpListNameW = SalU8ToWAlloc(tmpListNameBuf);
    listFile = tmpListNameW != NULL ? _wfopen(tmpListNameW, listEnc == PACKLIST_UNICODE ? L"wb" : L"w")
                                    : fopen(tmpListNameBuf, listEnc == PACKLIST_UNICODE ? "wb" : "w"); // legacy fallback
    if (tmpListNameW != NULL)
        free(tmpListNameW);
    if (listFile != NULL && listEnc == PACKLIST_UNICODE && fwrite("\xFF\xFE", 1, 2, listFile) != 2)
    {
        fclose(listFile);
        listFile = NULL;
    }
    if (listFile == NULL)
    {
        SalDeleteFile(tmpListNameBuf);
        return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_FILE);
    }

    // and we can fill it
    BOOL isDir;
    const char* name;
    char namecnv[MAX_PATH];
    int errorOccured;
    // feature 069 (F-P1-05): see the note in pack1.cpp
    if (listEnc == PACKLIST_OEM)
    {
        char rootOem[2 * MAX_PATH];
        if (SalU8ToOEM(rootPath, rootOem, sizeof(rootOem)) != 0)
            strcpy(rootPath, rootOem);
        else
            CharToOem(rootPath, rootPath);
    }
    // pick the name
    while ((name = nextName(parent, 1, &isDir, NULL, NULL, param, &errorOccured)) != NULL)
    {
        if (listEnc == PACKLIST_UNICODE) // UTF-8 names straight to UTF-16, nothing lost
        {
            const char* suffix = NULL;
            BOOL write = !isDir;
            if (isDir && modifyTable->DelEmptyDir == PMT_EMPDIRS_DELETE)
                write = TRUE;
            if (isDir && modifyTable->DelEmptyDir == PMT_EMPDIRS_DELETEWITHASTERISK)
            {
                write = TRUE;
                suffix = "\\*";
            }
            if (write && !PackWriteListLineW(listFile, rootPath, name, suffix))
            {
                fclose(listFile);
                SalDeleteFile(tmpListNameBuf);
                return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_FILE);
            }
            continue;
        }
        if (listEnc == PACKLIST_OEM)
        {
            if (SalU8ToOEM(name, namecnv, _countof(namecnv)) == 0)
                CharToOem(name, namecnv); // legacy fallback
        }
        else
            lstrcpyn(namecnv, name, _countof(namecnv));
        // and put it into the list
        if (!isDir)
        {
            if (fprintf(listFile, "%s%s\n", rootPath, namecnv) <= 0)
            {
                fclose(listFile);
                SalDeleteFile(tmpListNameBuf);
                return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_FILE);
            }
        }
        else
        {
            if (modifyTable->DelEmptyDir == PMT_EMPDIRS_DELETE)
            {
                if (fprintf(listFile, "%s%s\n", rootPath, namecnv) <= 0)
                {
                    fclose(listFile);
                    SalDeleteFile(tmpListNameBuf);
                    return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_FILE);
                }
            }
            else
            {
                if (modifyTable->DelEmptyDir == PMT_EMPDIRS_DELETEWITHASTERISK)
                {
                    if (fprintf(listFile, "%s%s\\*\n", rootPath, namecnv) <= 0)
                    {
                        fclose(listFile);
                        SalDeleteFile(tmpListNameBuf);
                        return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_FILE);
                    }
                }
            }
        }
    }
    // that's it
    fclose(listFile);

    // if an error occurred and the user decided to cancel the operation, end it
    if (errorOccured == SALENUM_CANCEL)
    {
        SalDeleteFile(tmpListNameBuf);
        return FALSE;
    }

    //
    // Now we will launch the external program for deletion
    //
    // construct the command line
    char cmdLine[PACK_CMDLINE_MAXLEN];
    if (!PackExpandCmdLine(archiveFileName, NULL, tmpListNameBuf, NULL,
                           modifyTable->DeleteCommand, cmdLine, PACK_CMDLINE_MAXLEN, NULL))
    {
        SalDeleteFile(tmpListNameBuf);
        return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_CMDLNERR);
    }

    // check whether the command line is not too long
    if (!modifyTable->SupportLongNames && strlen(cmdLine) >= 128)
    {
        char buffer[1000];
        SalDeleteFile(tmpListNameBuf);
        strcpy(buffer, cmdLine);
        return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_CMDLNLEN, buffer);
    }

    // construct the current directory
    char currentDir[MAX_PATH];
    if (!PackExpandInitDir(archiveFileName, NULL, NULL, modifyTable->DeleteInitDir,
                           currentDir, MAX_PATH))
    {
        SalDeleteFile(tmpListNameBuf);
        return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_IDIRERR);
    }

    // take the attributes in case we need them later
    DWORD fileAttrs = SalGetFileAttributes(archiveFileName);
    if (fileAttrs == 0xFFFFFFFF)
        fileAttrs = FILE_ATTRIBUTE_ARCHIVE;

    // back up the short archive file name, later we check whether the long name
    // survived -> if the short one remained, rename it back to the original long name
    char DOSArchiveFileName[MAX_PATH];
    if (!SalGetShortPathName(archiveFileName, DOSArchiveFileName, MAX_PATH))
        DOSArchiveFileName[0] = 0;

    // and run the external program
    BOOL exec = PackExecute(NULL, cmdLine, currentDir, modifyTable->ErrorTable);
    // meanwhile, check whether the long name did not vanish -> if the short one
    // remained, rename it to the original long name
    if (DOSArchiveFileName[0] != 0 &&
        SalGetFileAttributes(archiveFileName) == 0xFFFFFFFF &&
        SalGetFileAttributes(DOSArchiveFileName) != 0xFFFFFFFF)
    {
        SalMoveFile(DOSArchiveFileName, archiveFileName); // if it fails, we don't care...
    }
    if (!exec)
    {
        SalDeleteFile(tmpListNameBuf);
        // feature 084: the user stopped the archiver - the archive may be half written
        if (PackLastRunCancelled)
            (*PackErrorHandlerPtr)(parent, IDS_PACKERR_CANCELLED_ARC, archiveFileName);
        return FALSE; // error message has already been displayed
    }

    // if deleting removed the archive, create a zero-length file
    // feature 069 (F-P1-06): archiveFileName is a UTF-8 panel path
    HANDLE tmpHandle = SalCreateFile(archiveFileName, GENERIC_READ, 0, NULL,
                                     OPEN_ALWAYS, fileAttrs, NULL);
    if (tmpHandle != INVALID_HANDLE_VALUE)
        HANDLES(CloseHandle(tmpHandle));

    // the file list is no longer needed
    SalDeleteFile(tmpListNameBuf);

    return TRUE;
}
