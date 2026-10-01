// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later
// CommentsTranslationProject: TRANSLATED

#include "precomp.h"

#include "dialogs.h"
#include "cfgdlg.h"
#include "mainwnd.h"
#include "plugins.h"
#include "fileswnd.h"
#include "zip.h"
#include "pack.h"
#include "sal7zlist.h" // feature 084

//
// ****************************************************************************
// Constants and global variables
// ****************************************************************************
//

// Pointer to the error handling function
BOOL(*PackErrorHandlerPtr)
(HWND parent, const WORD errNum, ...) = EmptyErrorHandler;

// Table of archive definitions and handling - non-modifying operations
// !!! WARNING: the row order is the archiver index (PACK7ZIPINDEX, PACKRARINDEX)
// stored in the "Archive Association" records; when changing it you must also
// change PackModifyTable, CArchiverConfig::AddDefault, PackACExtensions, the
// default custom packers/unpackers and the externalArchivers array inside
// CPlugins::FindViewEdit
const SPackBrowseTable PackBrowseTable[] =
    {
        // [PACK7ZIPINDEX] 7-Zip console (7z.exe) - browses and unpacks the formats no
        // plug-in handles (feature 084): the bare listing (-ba: no archive comment can
        // reach the parser, see sal7zlist.h) is read as UTF-8 (-sccUTF-8) and
        // the list of files is written as UTF-16 (-scsUTF-16LE; research R7a - 7-Zip
        // rejects 4-byte UTF-8 in a list file)
        {
            (TPackErrorTable*)&SevenZipErrors, TRUE,
            "$(ArchivePath)", "$(SevenZipExecutable) l -slt -ba -sccUTF-8 -scsUTF-8 -- \"$(ArchiveFullName)\"",
            Pack7zList,
            "$(TargetPath)", "$(SevenZipExecutable) x -y -sccUTF-8 -scsUTF-16LE \"$(ArchiveFullName)\" -o\"$(TargetPath)\" @\"$(ListUnicodeFullName)\"",
            "$(TargetPath)", "$(SevenZipExecutable) e -y -sccUTF-8 -scsUTF-8 \"$(ArchiveFullName)\" -o\"$(TargetPath)\" -- \"$(ExtractFullName)\"",
            FALSE},
        // [PACKRARINDEX] RAR (WinRAR console, Rar.exe) - packing only; RAR archives are
        // browsed and unpacked by the 7zip plug-in (feature 084)
        {
            (TPackErrorTable*)&RARErrors, TRUE,
            NULL, NULL, NULL,
            NULL, NULL,
            NULL, NULL,
            FALSE}};

//
// ****************************************************************************
// Functions
// ****************************************************************************
//

//
// ****************************************************************************
// Functions for listing archives
//

// context of Pack7zList
struct SPack7zListCtx
{
    CSalamanderDirectory* Dir;
    BOOL Reported; // an error was already shown to the user
};

// one item of the 7-Zip listing -> one panel entry (names stay UTF-8 end to end,
// so the whole listing is in one encoding - the defect feature 069 recorded for
// the OEM column parser cannot occur)
static BOOL Pack7zListItem(const CSal7zListItem* item, void* param)
{
    SPack7zListCtx* ctx = (SPack7zListCtx*)param;

    // separators to '\', a trailing separator means a directory
    char* path = (char*)malloc(item->PathLen + 1);
    if (path == NULL)
    {
        ctx->Reported = TRUE;
        (*PackErrorHandlerPtr)(NULL, IDS_PACKERR_NOMEM);
        return FALSE;
    }
    int len = 0;
    for (int i = 0; i < item->PathLen; i++)
    {
        char c = item->Path[i] == '/' ? '\\' : item->Path[i];
        if (c == '\\' && (len == 0 || path[len - 1] == '\\'))
            continue; // collapse repeated separators
        path[len++] = c;
    }
    BOOL isDir = item->IsDir;
    if (len > 0 && path[len - 1] == '\\')
    {
        len--;
        isDir = TRUE;
    }
    path[len] = 0;
    if (len == 0) // only separators - nothing to show
    {
        free(path);
        return TRUE;
    }

    // split into the directory part and the name
    char* name = strrchr(path, '\\');
    const char* dirPart = NULL;
    if (name != NULL)
    {
        *name++ = 0;
        dirPart = path;
    }
    else
        name = path;

    CFileData newfile;
    newfile.NameLen = (unsigned)strlen(name);
    newfile.Name = (char*)malloc(newfile.NameLen + 1);
    if (newfile.Name == NULL)
    {
        free(path);
        ctx->Reported = TRUE;
        (*PackErrorHandlerPtr)(NULL, IDS_PACKERR_NOMEM);
        return FALSE;
    }
    memcpy(newfile.Name, name, newfile.NameLen + 1);
    char* s = newfile.Name + newfile.NameLen;
    while (--s >= newfile.Name && *s != '.')
        ;
    newfile.Ext = s >= newfile.Name ? s + 1 : newfile.Name + newfile.NameLen; // ".cvspass" is an extension in Windows

    // the time 7-Zip prints is local time; without one the old default 1.1.1980 applies
    SYSTEMTIME t;
    if (item->HasDate)
        t = item->Modified;
    else
    {
        memset(&t, 0, sizeof(t));
        t.wYear = 1980;
        t.wMonth = 1;
        t.wDay = 1;
    }
    FILETIME lt;
    if (!SystemTimeToFileTime(&t, &lt) || !LocalFileTimeToFileTime(&lt, &newfile.LastWrite))
    {
        newfile.LastWrite.dwLowDateTime = 0;
        newfile.LastWrite.dwHighDateTime = 0;
    }

    newfile.Size.Set((DWORD)(item->Size & 0xFFFFFFFF), (DWORD)(item->Size >> 32));
    newfile.Attr = item->Attributes;
    newfile.Hidden = (item->Attributes & FILE_ATTRIBUTE_HIDDEN) != 0 ? 1 : 0;
    newfile.IsOffline = 0;
    newfile.DosName = NULL;
    newfile.PluginData = -1; // -1 just for now, ignored

    BOOL ok;
    if (!isDir)
    {
        newfile.IsLink = IsFileLink(newfile.Ext);
        ok = ctx->Dir->AddFile(dirPart, newfile, NULL);
    }
    else
    {
        newfile.Attr |= FILE_ATTRIBUTE_DIRECTORY;
        newfile.IsLink = 0;
        if (!Configuration.SortDirsByExt)
            newfile.Ext = newfile.Name + newfile.NameLen; // directories have no extension
        ok = ctx->Dir->AddDir(dirPart, newfile, NULL);
    }
    free(path);
    if (!ok)
    {
        // e.g. a name or path longer than the panel accepts: the whole listing
        // fails instead of showing a partial tree
        free(newfile.Name);
        ctx->Reported = TRUE;
        (*PackErrorHandlerPtr)(NULL, IDS_PACKERR_FDATA);
        return FALSE;
    }
    return TRUE;
}

//
// ****************************************************************************
// BOOL Pack7zList(const char *archiveFileName, const char *output, size_t outputLen,
//                 CSalamanderDirectory &dir)
//
//   Parser of the 7-Zip technical listing (7z l -slt), contract
//   specs/084-archiver-cleanup/contracts/7z-slt-listing.md
//
//   RET: TRUE on success, FALSE on error (already reported)

BOOL Pack7zList(const char* archiveFileName, const char* output, size_t outputLen,
                CSalamanderDirectory& dir)
{
    CALL_STACK_MESSAGE2("Pack7zList(%s, , ,)", archiveFileName);
    SPack7zListCtx ctx;
    ctx.Dir = &dir;
    ctx.Reported = FALSE;
    int errorLine = 0;
    int ret = SalParse7zTechList(output, outputLen, Pack7zListItem, &ctx, &errorLine);
    if (ret == SAL7Z_OK)
        return TRUE;
    if (ctx.Reported)
        return FALSE;
    TRACE_E("Pack7zList(): the 7-Zip listing was rejected, code " << ret << ", line " << errorLine);
    return (*PackErrorHandlerPtr)(NULL, IDS_PACKERR_PARSE);
}

//
// ****************************************************************************
// BOOL PackList(CFilesWindow *panel, const char *archiveFileName, CSalamanderDirectory &dir,
//               CPluginDataInterfaceAbstract *&pluginData, CPluginData *&plugin)
//
//   Function to obtain the contents of an archive.
//
//   RET: returns TRUE on success, FALSE on failure
//        on failure the callback function *PackErrorHandlerPtr is called
//   IN:  panel is Salamander's file panel
//        archiveFileName is the name of the archive file to be listed
//   OUT: dir is filled with archive data
//        pluginData is the interface to column data defined by the archiver plug-in
//        plugin is the plug-in record that performed ListArchive

BOOL PackList(CFilesWindow* panel, const char* archiveFileName, CSalamanderDirectory& dir,
              CPluginDataInterfaceAbstract*& pluginData, CPluginData*& plugin)
{
    CALL_STACK_MESSAGE2("PackList(, %s, , ,)", archiveFileName);
    // clean up just in case
    dir.Clear(NULL);
    pluginData = NULL;
    plugin = NULL;

    // find the correct one according to the table
    int format = PackerFormatConfig.PackIsArchive(archiveFileName);
    // Supported archive not found - error
    if (format == 0)
        return (*PackErrorHandlerPtr)(NULL, IDS_PACKERR_ARCNAME_UNSUP);

    format--;
    int index = PackerFormatConfig.GetUnpackerIndex(format);

    // Is this not internal processing (DLL)?
    if (index < 0)
    {
        plugin = Plugins.Get(-index - 1);
        if (plugin == NULL || !plugin->SupportPanelView)
        {
            return (*PackErrorHandlerPtr)(NULL, IDS_PACKERR_ARCNAME_UNSUP);
        }
        return plugin->ListArchive(panel, archiveFileName, dir, pluginData);
    }

    //
    // We will run an external program with redirected output
    //
    const SPackBrowseTable* browseTable = ArchiverConfig.GetUnpackerConfigTable(index);
    if (browseTable->ListCommand == NULL || browseTable->ListParser == NULL)
        return (*PackErrorHandlerPtr)(NULL, IDS_PACKERR_ARCNAME_UNSUP); // this archiver cannot browse

    // build the current directory
    char currentDir[MAX_PATH];
    if (!PackExpandInitDir(archiveFileName, NULL, NULL, browseTable->ListInitDir,
                           currentDir, MAX_PATH))
        return (*PackErrorHandlerPtr)(NULL, IDS_PACKERR_IDIRERR);

    // build the command line (feature 084: the archiver itself, no helper program)
    char cmdLine[PACK_CMDLINE_MAXLEN];
    if (!PackExpandCmdLine(archiveFileName, NULL, NULL, NULL, browseTable->ListCommand,
                           cmdLine, PACK_CMDLINE_MAXLEN, NULL))
        return (*PackErrorHandlerPtr)(NULL, IDS_PACKERR_CMDLNERR);

    // check whether the command line is too long
    if (!browseTable->SupportLongNames && strlen(cmdLine) >= 128)
    {
        char buffer[1000];
        lstrcpyn(buffer, cmdLine, 1000);
        return (*PackErrorHandlerPtr)(NULL, IDS_PACKERR_CMDLNLEN, buffer);
    }

    CPackOutput output;
    DWORD exitCode;
    EPackRunResult run = PackRunArchiver(NULL, cmdLine, currentDir, &output, &exitCode);
    if (run != PACKRUN_EXITED)
        return FALSE; // a failure was already reported, a cancel needs no message

    // Restore focus back to us
    SetForegroundWindow(MainWindow->HWindow);

    if (exitCode != 0)
        return PackReportExitCode(NULL, cmdLine, exitCode, browseTable->ErrorTable);

    // no output is not an error here: the bare 7-Zip listing of an empty archive is empty
    return browseTable->ListParser(archiveFileName, output.Data != NULL ? output.Data : "", output.Len, dir);
}

//
// ****************************************************************************
// Decompression functions
//

//
// ****************************************************************************
// BOOL PackUncompress(HWND parent, CFilesWindow *panel, const char *archiveFileName,
//                     CPluginDataInterfaceAbstract *pluginData,
//                     const char *targetDir, const char *archiveRoot,
//                     SalEnumSelection nextName, void *param)
//
//   Function for extracting requested files from an archive.
//
//   RET: returns TRUE on success, FALSE on error
//        on error the callback function *PackErrorHandlerPtr is called
//   IN:  parent is the parent window for message boxes
//        panel is a pointer to the Salamander file panel
//        archiveFileName is name of the archive we extract from
//        targetDir is the path where files are extracted
//        archiveRoot is the directory in the archive we extract from
//        nextName is the callback function for enumerating names to extract
//        param are the parameters for the enumeration function
//        pluginData is the interface for working with file/directory data specific to the plugin
//   OUT:

BOOL PackUncompress(HWND parent, CFilesWindow* panel, const char* archiveFileName,
                    CPluginDataInterfaceAbstract* pluginData,
                    const char* targetDir, const char* archiveRoot,
                    SalEnumSelection nextName, void* param)
{
    CALL_STACK_MESSAGE4("PackUncompress(, , %s, , %s, %s, ,)", archiveFileName, targetDir, archiveRoot);
    // find the correct one according to the table
    int format = PackerFormatConfig.PackIsArchive(archiveFileName);
    // Supported archive not found - error
    if (format == 0)
        return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_ARCNAME_UNSUP);

    format--;
    int index = PackerFormatConfig.GetUnpackerIndex(format);

    // Is this not internal processing (DLL)?
    if (index < 0)
    {
        CPluginData* plugin = Plugins.Get(-index - 1);
        if (plugin == NULL || !plugin->SupportPanelView)
        {
            return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_ARCNAME_UNSUP);
        }
        return plugin->UnpackArchive(panel, archiveFileName, pluginData, targetDir, archiveRoot, nextName, param);
    }
    const SPackBrowseTable* browseTable = ArchiverConfig.GetUnpackerConfigTable(index);

    return PackUniversalUncompress(parent, browseTable->UncompressCommand,
                                   browseTable->ErrorTable, browseTable->UncompressInitDir, TRUE, panel,
                                   browseTable->SupportLongNames, archiveFileName, targetDir,
                                   archiveRoot, nextName, param, browseTable->NeedANSIListFile);
}

//
// ****************************************************************************
// BOOL PackUniversalUncompress(HWND parent, const char *command, TPackErrorTable *const errorTable,
//                              const char *initDir, BOOL expandInitDir, CFilesWindow *panel,
//                              const BOOL supportLongNames, const char *archiveFileName,
//                              const char *targetDir, const char *archiveRoot,
//                              SalEnumSelection nextName, void *param, BOOL needANSIListFile)
//
//   Function for extracting requested files from an archive. Unlike the previous
//   one it is more general, does not use configuration tables and can be called
//   standalone; everything is determined only by parameters
//
//   RET: returns TRUE on success, FALSE on error
//        on error the callback function *PackErrorHandlerPtr is called
//   IN:  parent is the parent for message boxes
//        command is the command line used for extraction
//        errorTable is a pointer to the return codes table or NULL if none exists
//        initDir is the directory in which the archiver should run
//        panel is a pointer to the Salamander file panel
//        supportLongNames indicates whether the archiver supports long names
//        archiveFileName is the name of the archive we unpack
//        targetDir is the path where files are extracted
//        archiveRoot is the path in the archive from which we are extracting, or NULL
//        nextName is the callback function enumerating files to extract
//        param are the parameters passed to the callback function
//        needANSIListFile is TRUE if the file list must be in ANSI (not OEM)
//   OUT:

BOOL PackUniversalUncompress(HWND parent, const char* command, TPackErrorTable* const errorTable,
                             const char* initDir, BOOL expandInitDir, CFilesWindow* panel,
                             const BOOL supportLongNames, const char* archiveFileName,
                             const char* targetDir, const char* archiveRoot,
                             SalEnumSelection nextName, void* param, BOOL needANSIListFile)
{
    CALL_STACK_MESSAGE9("PackUniversalUncompress(, %s, , %s, %d, , %d, %s, %s, %s, , , %d)",
                        command, initDir, expandInitDir, supportLongNames, archiveFileName,
                        targetDir, archiveRoot, needANSIListFile);

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
            strcpy(rootPath, archiveRoot);
            strcat(rootPath, "\\");
        }
    }
    else
    {
        rootPath[0] = '\0';
    }

    //
    // Now it's time for the temporary extraction directory

    // Create the name of the temporary directory
    char tmpDirNameBuf[MAX_PATH];
    if (!SalGetTempFileName(targetDir, "PACK", tmpDirNameBuf, FALSE))
    {
        char buffer[1000];
        strcpy(buffer, "SalGetTempFileName: ");
        strcat(buffer, GetErrorText(GetLastError()));
        return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_GENERAL, buffer);
    }

    //
    // Now prepare a helper file with a list of files to extract in the %TEMP% directory
    //

    // Create the name of the temporary file
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
        SalRemoveDirectory(tmpDirNameBuf);
        SalDeleteFile(tmpListNameBuf);
        return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_FILE);
    }

    // and we can fill it
    BOOL isDir;
    CQuadWord size;
    const char* name;
    char namecnv[MAX_PATH];
    CQuadWord totalSize(0, 0);
    int errorOccured;

    // feature 069 (F-P1-05): the names are UTF-8 (CFileData::Name), and
    // CharToOem read those bytes as if they were in the ANSI code page before
    // mapping them to OEM - so the list file named a file that does not exist
    // and the archiver reported it could not find it.  SalU8ToOEM converts
    // properly; where the name cannot be expressed in the console code page at
    // all it fails, and the legacy call keeps the previous (failing) behaviour
    // rather than skipping the file silently.
    if (listEnc == PACKLIST_OEM)
    {
        char rootPathOem[2 * MAX_PATH];
        if (SalU8ToOEM(rootPath, rootPathOem, sizeof(rootPathOem)) != 0)
            strcpy(rootPath, rootPathOem);
        else
            CharToOem(rootPath, rootPath);
    }
    // pick the name
    while ((name = nextName(parent, 1, &isDir, &size, NULL, param, &errorOccured)) != NULL)
    {
        // sum the total size
        totalSize += size;
        if (listEnc == PACKLIST_UNICODE) // UTF-8 names straight to UTF-16, nothing lost
        {
            // the Unpack dialog's default mask "*.*" means every file, but 7-Zip reads
            // it as "names with an extension" - "*" means every file to 7-Zip and RAR alike
            if (rootPath[0] == 0 && strcmp(name, "*.*") == 0)
                name = "*";
            if (!isDir && !PackWriteListLineW(listFile, rootPath, name, NULL))
            {
                fclose(listFile);
                SalDeleteFile(tmpListNameBuf);
                SalRemoveDirectory(tmpDirNameBuf);
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
        // put the name into the list
        if (!isDir)
        {
            if (fprintf(listFile, "%s%s\n", rootPath, namecnv) <= 0)
            {
                fclose(listFile);
                SalDeleteFile(tmpListNameBuf);
                SalRemoveDirectory(tmpDirNameBuf);
                return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_FILE);
            }
        }
    }
    // and that is it
    fclose(listFile);

    // if an error occurred and the user chose to cancel the operation, end the it +
    // also test for enough free disk space
    if (errorOccured == SALENUM_CANCEL ||
        !TestFreeSpace(parent, tmpDirNameBuf, totalSize, LoadStr(IDS_PACKERR_TITLE)))
    {
        SalDeleteFile(tmpListNameBuf);
        SalRemoveDirectory(tmpDirNameBuf);
        return FALSE;
    }

    //
    // Now we will run an external program to unpack
    //
    // build the command line
    char cmdLine[PACK_CMDLINE_MAXLEN];
    if (!PackExpandCmdLine(archiveFileName, tmpDirNameBuf, tmpListNameBuf, NULL,
                           command, cmdLine, PACK_CMDLINE_MAXLEN, NULL))
    {
        SalDeleteFile(tmpListNameBuf);
        SalRemoveDirectory(tmpDirNameBuf);
        return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_CMDLNERR);
    }

    // check if the command line is too long
    if (!supportLongNames && strlen(cmdLine) >= 128)
    {
        char buffer[1000];
        SalDeleteFile(tmpListNameBuf);
        SalRemoveDirectory(tmpDirNameBuf);
        strcpy(buffer, cmdLine);
        return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_CMDLNLEN, buffer);
    }

    // build the current directory
    char currentDir[MAX_PATH];
    if (!expandInitDir)
    {
        if (strlen(initDir) < MAX_PATH)
            strcpy(currentDir, initDir);
        else
        {
            SalDeleteFile(tmpListNameBuf);
            SalRemoveDirectory(tmpDirNameBuf);
            return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_IDIRERR);
        }
    }
    else
    {
        if (!PackExpandInitDir(archiveFileName, NULL, tmpDirNameBuf, initDir, currentDir, MAX_PATH))
        {
            SalDeleteFile(tmpListNameBuf);
            SalRemoveDirectory(tmpDirNameBuf);
            return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_IDIRERR);
        }
    }

    // and run the external program
    if (!PackExecute(NULL, cmdLine, currentDir, errorTable))
    {
        SalDeleteFile(tmpListNameBuf);
        RemoveTemporaryDir(tmpDirNameBuf);
        return FALSE; // the error message has already been shown
    }
    // the file list is no longer needed
    SalDeleteFile(tmpListNameBuf);

    // and now finally move the files where they belong
    char srcDir[MAX_PATH];
    strcpy(srcDir, tmpDirNameBuf);
    if (*rootPath != '\0')
    {
        // locate the extracted subdirectory path - names of subdirectories may not match
        // because of the Czech characters and long names :-(
        char* r = rootPath;
        WIN32_FIND_DATA foundFile;
        WIN32_FIND_DATAW foundFileW; // feature 069 (F-P1-06)
        char foundNameU8[SAL_FIND_NAME_U8];
        char buffer[1000];
        while (1)
        {
            if (*r == 0)
                break;
            while (*r != 0 && *r != '\\')
                r++; // skip one level in the original rootPath
            while (*r == '\\')
                r++; // skip the backslash in the original rootPath
            strcat(srcDir, "\\*");

            // feature 069 (F-P1-06): srcDir is built from SalGetTempFileName output (UTF-8), so
            // the ANSI enumeration found nothing under a non-ASCII %TEMP%
            HANDLE found = SalFindFirstFile(srcDir, &foundFileW); // registers with HANDLES itself
            if (found == INVALID_HANDLE_VALUE)
            {
                strcpy(buffer, "FindFirstFile: ");

            _ERR:

                strcat(buffer, GetErrorText(GetLastError()));
                RemoveTemporaryDir(tmpDirNameBuf);
                return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_GENERAL, buffer);
            }
            SalConvertFindDataW(&foundFileW, &foundFile, foundNameU8, sizeof(foundNameU8), NULL, 0);
            while (foundNameU8[0] == 0 ||
                   strcmp(foundNameU8, ".") == 0 || // we ignore "." and ".."
                   strcmp(foundNameU8, "..") == 0)
            {
                if (!SalFindNextFile(found, &foundFileW))
                {
                    HANDLES(FindClose(found));
                    strcpy(buffer, "FindNextFile: ");
                    goto _ERR;
                }
                // the name must be re-converted for every record, or this test
                // keeps re-reading the first one
                SalConvertFindDataW(&foundFileW, &foundFile, foundNameU8, sizeof(foundNameU8), NULL, 0);
            }
            HANDLES(FindClose(found));

            if (foundFile.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
            { // attach another subdirectory on the path
                srcDir[strlen(srcDir) - 1] = 0;
                strcat(srcDir, foundNameU8);
            }
            else
            {
                TRACE_E("Unexpected error in PackUniversalUncompress().");
                RemoveTemporaryDir(tmpDirNameBuf);
                return FALSE;
            }
        }
    }
    if (!panel->MoveFiles(srcDir, targetDir, tmpDirNameBuf, archiveFileName))
    {
        RemoveTemporaryDir(tmpDirNameBuf);
        return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_MOVE);
    }

    RemoveTemporaryDir(tmpDirNameBuf);
    return TRUE;
}

//
// ****************************************************************************
// const char * WINAPI PackEnumMask(HWND parent, int enumFiles, BOOL *isDir, CQuadWord *size,
//                                  const CFileData **fileData, void *param, int *errorOccured)
//
//   Callback function for enumerating given masks
//
//   RET: Returns the mask currently processed or NULL when it is done
//   IN:  enumFiles is ignored
//        fileData is ignored (only initialized to NULL)
//        param is a pointer to a string of file masks separated by semicolon
//   OUT: isDir is always FALSE
//        size is always 0
//        the string of masks separated by semicolon is modified (";"->"\0" when separating masks, ";;"->";" with the trailing ";" removed)

const char* WINAPI PackEnumMask(HWND parent, int enumFiles, BOOL* isDir, CQuadWord* size,
                                const CFileData** fileData, void* param, int* errorOccured)
{
    CALL_STACK_MESSAGE2("PackEnumMask(%d, , ,)", enumFiles);
    if (errorOccured != NULL)
        *errorOccured = SALENUM_SUCCESS;
    // set unused variables
    if (isDir != NULL)
        *isDir = FALSE;
    if (size != NULL)
        *size = CQuadWord(0, 0);
    if (fileData != NULL)
        *fileData = NULL;

    // if there are no more masks return NULL - finished
    if (param == NULL || *(char**)param == NULL)
        return NULL;

    // drop a possible semicolon at the end of the string (shorten the string)
    char* ptr = *(char**)param + strlen(*(char**)param) - 1;
    char* endPtr = ptr;
    while (1)
    {
        while (ptr >= *(char**)param && *ptr == ';')
            ptr--;
        if (((endPtr - ptr) & 1) == 1)
            *endPtr-- = 0; // ignore ';' only if odd (even count will later be converted ";;"->";")
        if (endPtr >= *(char**)param && *endPtr <= ' ')
        {
            endPtr--;
            while (endPtr >= *(char**)param && *endPtr <= ' ')
                endPtr--; // ignore trailing white - spaces
            *(endPtr + 1) = 0;
            ptr = endPtr; // must try again to see if an odd ';' has to be skipped
        }
        else
            break;
    }
    // no mask left, there are only semicolons and white spaces (or nothing :-))
    if (endPtr < *(char**)param)
        return NULL;

    // otherwise find the last semicolon (only if their count is odd, otherwise ";;" will be replaced with ";") - before the last mask
    while (ptr >= *(char**)param)
    {
        if (*ptr == ';')
        {
            char* p = ptr - 1;
            while (p >= *(char**)param && *p == ';')
                p--;
            if (((ptr - p) & 1) == 1)
                break;
            else
                ptr = p;
        }
        else
            ptr--;
    }

    if (ptr < *(char**)param)
    {
        // if there is no semicolon left we have only one
        *(char**)param = NULL;
    }
    else
    {
        // cut off the last mask from the rest by placing zero instead of the found semicolon
        *ptr = '\0';
    }

    while (*(ptr + 1) != 0 && *(ptr + 1) <= ' ')
        ptr++; // skip white - spaces at the beginning of the mask
    char* s = ptr + 1;
    while (*s != 0)
    {
        if (*s == ';' && *(s + 1) == ';')
            memmove(s, s + 1, strlen(s + 1) + 1);
        s++;
    }
    // and return it
    return ptr + 1;
}

//
// ****************************************************************************
// BOOL PackUnpackOneFile(CFilesWindow *panel, const char *archiveFileName,
//                        CPluginDataInterfaceAbstract *pluginData, const char *nameInArchive,
//                        CFileData *fileData, const char *targetDir, const char *newFileName,
//                        BOOL *renamingNotSupported)
//
//   Function for extracting a single file from an archive (for the viewer).
//
//   RET: returns TRUE on success, FALSE on error
//        on error the callback function *PackErrorHandlerPtr is called
//   IN:  panel is the Salamander file panel
//        archiveFileName is the name of the archive from which we extract
//        nameInArchive is the name of the file we extract
//        fileData is a pointer to the CFileData structure of the extracted file
//        targetDir is the path where the file should be extracted
//        newFileName (if not NULL) is the new name of the extracted file (during extraction, the file
//          must be renamed from its original name to this new one)
//        renamingNotSupported (only if newFileName is not NULL) - set TRUE if the plugin
//          does not support renaming during extraction, Salamander will show an error
//   OUT:

BOOL PackUnpackOneFile(CFilesWindow* panel, const char* archiveFileName,
                       CPluginDataInterfaceAbstract* pluginData, const char* nameInArchive,
                       CFileData* fileData, const char* targetDir, const char* newFileName,
                       BOOL* renamingNotSupported)
{
    CALL_STACK_MESSAGE5("PackUnpackOneFile(, %s, , %s, , %s, %s, )",
                        archiveFileName, nameInArchive, targetDir, newFileName);

    // find the correct one according to the table
    int format = PackerFormatConfig.PackIsArchive(archiveFileName);
    // No supported archive found - error
    if (format == 0)
        return (*PackErrorHandlerPtr)(NULL, IDS_PACKERR_ARCNAME_UNSUP);

    format--;
    int index = PackerFormatConfig.GetUnpackerIndex(format);

    // Is this not internal processing (DLL)?
    if (index < 0)
    {
        CPluginData* plugin = Plugins.Get(-index - 1);
        if (plugin == NULL || !plugin->SupportPanelView)
        {
            return (*PackErrorHandlerPtr)(NULL, IDS_PACKERR_ARCNAME_UNSUP);
        }
        return plugin->UnpackOneFile(panel, archiveFileName, pluginData, nameInArchive,
                                     fileData, targetDir, newFileName, renamingNotSupported);
    }

    if (newFileName != NULL) // external archivers do not support renaming yet (we did not even check if they can)
    {
        return (*PackErrorHandlerPtr)(NULL, IDS_PACKERR_INVALIDNAME);
    }

    //
    // Create a temporary directory into which we unpack the file
    //

    // buffer for the full name of the temporary directory
    char tmpDirNameBuf[MAX_PATH];
    if (!SalGetTempFileName(targetDir, "PACK", tmpDirNameBuf, FALSE))
    {
        char buffer[1000];
        strcpy(buffer, "SalGetTempFileName: ");
        strcat(buffer, GetErrorText(GetLastError()));
        return (*PackErrorHandlerPtr)(NULL, IDS_PACKERR_GENERAL, buffer);
    }

    //
    // Now we will run an external program to unpack
    //
    const SPackBrowseTable* browseTable = ArchiverConfig.GetUnpackerConfigTable(index);

    // build the command line
    char cmdLine[PACK_CMDLINE_MAXLEN];
    if (!PackExpandCmdLine(archiveFileName, tmpDirNameBuf, NULL, nameInArchive,
                           browseTable->ExtractCommand, cmdLine, PACK_CMDLINE_MAXLEN, NULL))
    {
        RemoveTemporaryDir(tmpDirNameBuf);
        return (*PackErrorHandlerPtr)(NULL, IDS_PACKERR_CMDLNERR);
    }

    // check whether the command line is too long
    if (!browseTable->SupportLongNames && strlen(cmdLine) >= 128)
    {
        char buffer[1000];
        RemoveTemporaryDir(tmpDirNameBuf);
        strcpy(buffer, cmdLine);
        return (*PackErrorHandlerPtr)(NULL, IDS_PACKERR_CMDLNLEN, buffer);
    }

    // build the current directory
    char currentDir[MAX_PATH];
    if (!PackExpandInitDir(archiveFileName, NULL, tmpDirNameBuf, browseTable->ExtractInitDir,
                           currentDir, MAX_PATH))
    {
        RemoveTemporaryDir(tmpDirNameBuf);
        return (*PackErrorHandlerPtr)(NULL, IDS_PACKERR_IDIRERR);
    }

    // and run the external program
    if (!PackExecute(NULL, cmdLine, currentDir, browseTable->ErrorTable))
    {
        RemoveTemporaryDir(tmpDirNameBuf);
        return FALSE; // the error message has already been shown
    }

    // find the extracted file - the name may not match due to the Czech characters and long names :-(
    char* extractedFile = (char*)malloc(strlen(tmpDirNameBuf) + 2 + 1);
    WIN32_FIND_DATA foundFile;
    WIN32_FIND_DATAW foundFileW; // feature 069 (F-P1-06)
    char foundNameU8[SAL_FIND_NAME_U8];
    strcpy(extractedFile, tmpDirNameBuf);
    strcat(extractedFile, "\\*");
    // feature 069 (F-P1-06): extractedFile lives under the UTF-8 temp directory, and the name the
    // ANSI enumeration returned was then spliced into that UTF-8 path - the
    // strict SalMoveFile rejected the mixture and the extracted file never
    // reached the panel ("MoveFile: <error>")
    HANDLE found = SalFindFirstFile(extractedFile, &foundFileW); // registers with HANDLES itself
    if (found == INVALID_HANDLE_VALUE)
    {
        char buffer[1000];
        strcpy(buffer, "FindFirstFile: ");
        strcat(buffer, GetErrorText(GetLastError()));
        RemoveTemporaryDir(tmpDirNameBuf);
        free(extractedFile);
        return (*PackErrorHandlerPtr)(NULL, IDS_PACKERR_GENERAL, buffer);
    }
    free(extractedFile);
    SalConvertFindDataW(&foundFileW, &foundFile, foundNameU8, sizeof(foundNameU8), NULL, 0);
    while (foundNameU8[0] == 0 ||
           strcmp(foundNameU8, ".") == 0 || strcmp(foundNameU8, "..") == 0)
    {
        if (!SalFindNextFile(found, &foundFileW))
        {
            char buffer[1000];
            strcpy(buffer, "FindNextFile: ");
            strcat(buffer, GetErrorText(GetLastError()));
            HANDLES(FindClose(found));
            RemoveTemporaryDir(tmpDirNameBuf);
            return (*PackErrorHandlerPtr)(NULL, IDS_PACKERR_GENERAL, buffer);
        }
        // re-convert every record - see the note at the twin loop above
        SalConvertFindDataW(&foundFileW, &foundFile, foundNameU8, sizeof(foundNameU8), NULL, 0);
    }
    HANDLES(FindClose(found));

    // and finally move it where it belongs
    char* srcName = (char*)malloc(strlen(tmpDirNameBuf) + 1 + strlen(foundNameU8) + 1);
    strcpy(srcName, tmpDirNameBuf);
    strcat(srcName, "\\");
    strcat(srcName, foundNameU8);
    const char* onlyName = strrchr(nameInArchive, '\\');
    if (onlyName == NULL)
        onlyName = nameInArchive;
    char* destName = (char*)malloc(strlen(targetDir) + 1 + strlen(onlyName) + 1);
    strcpy(destName, targetDir);
    strcat(destName, "\\");
    strcat(destName, onlyName);
    if (!SalMoveFile(srcName, destName))
    {
        char buffer[1000];
        strcpy(buffer, "MoveFile: ");
        strcat(buffer, GetErrorText(GetLastError()));
        RemoveTemporaryDir(tmpDirNameBuf);
        free(srcName);
        free(destName);
        return (*PackErrorHandlerPtr)(NULL, IDS_PACKERR_GENERAL, buffer);
    }

    // and clean up
    free(srcName);
    free(destName);
    RemoveTemporaryDir(tmpDirNameBuf);
    return TRUE;
}
