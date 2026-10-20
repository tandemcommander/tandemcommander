// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include "fileio.h"
#include "tardll.h"
#include "tar.h"
#include "gzip/gzip.h"
#include "rpm/rpm.h"
#include "splloadstru8.h" // feature 130
#include "../../common/salcasetwins.h" // feature 252: names that differ only in case

#include "tar.rh"
#include "tar.rh2"
#include "lang\lang.rh"

// TODO: resolve case sensitivity
// TODO: handle multiple files with the same name in one archive
// TODO: finish the output in the RPM viewer (convert dates to a readable format, etc.)
// TODO: clean up viewer deallocations; on error it behaves quite opaquely
// TODO: check tar against the specification to cover as many flags as possible (GNU extensions, etc.)
// TODO: review error messages and where they are used (TAR vs. CPIO)
// TODO: fix error reporting when the stream fails (do not rely on its ErrorNumber, ensure there is always text)
// TODO: handle multi-volume archives
// TODO: support archives with sparse files
// TODO: could links be turned into shortcuts?
// TODO: add LZMA compression to RPM (see flex-32bit-2.5.35-43.88.s390x.rpm sample). It seems rather rarely used, so maybe add it when more people ask...

//
// ****************************************************************************
//
// Declarations and definitions
//
// ****************************************************************************
//

// ConfigVersion: 0 - plugin installation or version released with Servant Salamander 2.0
//                    (without a configuration number)
//                1 - work-in-progress version before Servant Salamander 2.5 beta 1, added TBZ, BZ, BZ2, and RPM
//                2 - work-in-progress version before Servant Salamander 2.5 beta 1, added CPIO (including the *.CPIO viewer)
//                3 - work-in-progress version before Servant Salamander 2.5 beta 1, removed the *.CPIO viewer
//                4 - work-in-progress version before Servant Salamander 2.5 beta 1, added .z archives
//                5 - work-in-progress version before Servant Salamander 2.52 beta 2, added .DEB archives

int ConfigVersion = 0;
#define CURRENT_CONFIG_VERSION 5
const char* CONFIG_VERSION = "Version";

// plugin interface object, its methods are called from Salamander
CPluginInterface PluginInterface;
// portion of CPluginInterface used for the archiver
CPluginInterfaceForArchiver InterfaceForArchiver;
// portion of CPluginInterface used for the viewer
CPluginInterfaceForViewer InterfaceForViewer;

// general Salamander interface - valid from plugin start until its termination
CSalamanderGeneralAbstract* SalamanderGeneral = NULL;

// interface for convenient work with files
CSalamanderSafeFileAbstract* SalamanderSafeFile = NULL;

// variable definition for "dbg.h"
CSalamanderDebugAbstract* SalamanderDebug = NULL;

HINSTANCE DLLInstance = NULL; // handle to the SPL - language-independent resources
HINSTANCE HLanguage = NULL;   // handle to the SLG - language-dependent resources

//
// ****************************************************************************
//
// Helper functions
//
// ****************************************************************************
//

// loads a string from the DLL
char* LoadStr(int resID)
{
    return SalamanderGeneral->LoadStr(HLanguage, resID);
}

const char* LoadStrU8(int resID)
{
    return SplLoadStrU8(SalamanderGeneral, HLanguage, resID);
}

// combines a resource string with an optional error string
char* LoadErr(int resID, DWORD LastError)
{
    static char buffer[1000];
    // feature 130: GetErrorText() is UTF-8, so the resource text is loaded as UTF-8 too
    _snprintf_s(buffer, _TRUNCATE, "%s%s", LoadStrU8(resID),
                LastError != 0 ? SalamanderGeneral->GetErrorText(LastError) : "");
    SplU8TrimTornTail(buffer);
    return buffer;
}

//
// interface 104: UTF-8 paths -> W file APIs (see splunicode.h)
//

HANDLE CreateFileU8(const char* name, DWORD access, DWORD share, DWORD disposition, DWORD flags)
{
    WCHAR* w = SplU8ToWExtAlloc(name);
    if (w == NULL)
    {
        SetLastError(ERROR_INVALID_NAME);
        return INVALID_HANDLE_VALUE;
    }
    HANDLE file = CreateFileW(w, access, share, NULL, disposition, flags, NULL);
    DWORD err = GetLastError();
    free(w);
    SetLastError(err); // preserve the API's error across free()
    return file;
}

BOOL DeleteFileU8(const char* name)
{
    WCHAR* w = SplU8ToWExtAlloc(name);
    if (w == NULL)
        return FALSE;
    BOOL ret = DeleteFileW(w);
    free(w);
    return ret;
}

BOOL SetFileAttributesU8(const char* name, DWORD attrs)
{
    WCHAR* w = SplU8ToWExtAlloc(name);
    if (w == NULL)
        return FALSE;
    BOOL ret = SetFileAttributesW(w, attrs);
    free(w);
    return ret;
}

// TAR/CPIO/gzip format boundary (interface 104): these formats store names as raw bytes
// and carry no encoding field. POSIX/GNU tar writes UTF-8 by convention, so bytes that
// are already valid UTF-8 are passed through verbatim (name bytes must never be
// rewritten - see doc\plugin-vnext-migration.md); anything else comes from a legacy
// producer that used the system ANSI code page and is converted to UTF-8. Pure ASCII
// takes neither branch. Reallocates 'name' when it converts (malloc'd, like the
// original, so the callers keep using free()). Returns FALSE only when out of memory.
BOOL ConvertNameToU8(char*& name)
{
    if (name == NULL || SplIsASCII(name))
        return TRUE; // ASCII is already valid UTF-8, byte for byte
    // encoding-check: allow strict-probe-rejects-wtf8 - name bytes read from the archive (format boundary); the WTF-8 form of a core name does not arise there, the code-page reading is the documented fallback (255)
    if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, name, -1, NULL, 0) > 0)
        return TRUE; // valid UTF-8 (the POSIX/GNU convention) -> keep the bytes as they are

    // legacy archive: read the bytes in the system ANSI code page
    int wLen = MultiByteToWideChar(CP_ACP, 0, name, -1, NULL, 0);
    if (wLen <= 0)
        return TRUE; // undecodable either way -> leave the bytes untouched
    WCHAR* w = (WCHAR*)malloc(wLen * sizeof(WCHAR));
    if (w == NULL)
        return FALSE;
    char* u8 = NULL;
    if (MultiByteToWideChar(CP_ACP, 0, name, -1, w, wLen) > 0)
        u8 = SplWToU8Alloc(w);
    free(w);
    if (u8 == NULL)
        return TRUE; // conversion failed -> leave the bytes untouched
    free(name);
    name = u8;
    return TRUE;
}

//
// ****************************************************************************
//
// Plugin initialization
//
// ****************************************************************************
//

BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved)
{
    if (fdwReason == DLL_PROCESS_ATTACH)
        DLLInstance = hinstDLL;
    return TRUE; // DLL can be loaded
}

//
// ****************************************************************************
//
// Functions for communication with Salamander
//
// ****************************************************************************
//

// ****************************************************************************
// SalamanderPluginGetReqVer - returns the required Salamander version
//
int WINAPI SalamanderPluginGetReqVer()
{
    return LAST_VERSION_OF_SALAMANDER;
}

// ****************************************************************************
// SalamanderPluginEntry - main entry point
//
CPluginInterfaceAbstract* WINAPI SalamanderPluginEntry(CSalamanderPluginEntryAbstract* salamander)
{
    // set SalamanderDebug for "dbg.h"
    SalamanderDebug = salamander->GetSalamanderDebug();

    CALL_STACK_MESSAGE1("SalamanderPluginEntry()");

    // this plugin is built for the current Salamander version and newer - perform a check
    if (salamander->GetVersion() < LAST_VERSION_OF_SALAMANDER)
    { // reject older versions
        MessageBox(salamander->GetParentWindow(),
                   REQUIRE_LAST_VERSION_OF_SALAMANDER,
                   "TAR" /* neprekladat! */, MB_OK | MB_ICONERROR);
        return NULL;
    }

    // let Salamander load the language module (.slg)
    HLanguage = salamander->LoadLanguageModule(salamander->GetParentWindow(), "TAR" /* neprekladat! */);
    if (HLanguage == NULL)
        return NULL;

    // obtain Salamander's general interface
    SalamanderGeneral = salamander->GetSalamanderGeneral();
    SalamanderSafeFile = salamander->GetSalamanderSafeFile();

    // log a diagnostic message
    TRACE_I("SalamanderPluginEntry called, Salamander version " << salamander->GetVersion());

    // set basic plugin information
    salamander->SetBasicPluginData(LoadStr(IDS_PLUGINNAME),
                                   FUNCTION_LOADSAVECONFIGURATION |
                                       FUNCTION_PANELARCHIVERVIEW | FUNCTION_CUSTOMARCHIVERUNPACK |
                                       FUNCTION_VIEWER,
                                   VERSINFO_VERSION_NO_PLATFORM,
                                   VERSINFO_COPYRIGHT,
                                   LoadStr(IDS_PLUGIN_DESCRIPTION),
                                   "TAR" /* neprekladat! */, "tar;tgz;taz;tbz;gz;bz;bz2;z;rpm;cpio;deb");

    salamander->SetPluginHomePageURL("www.tandemcommander.org");

    return &PluginInterface;
}

void CPluginInterface::About(HWND parent)
{
    char buf[1000];
    _snprintf_s(buf, _TRUNCATE,
                "%s " VERSINFO_VERSION "\n\n" VERSINFO_COPYRIGHT "\nbzip2 library Copyright © 1996-2010 Julian R Seward\n\n"
                "%s",
                LoadStr(IDS_PLUGINNAME),
                LoadStr(IDS_PLUGIN_DESCRIPTION));
    SalamanderGeneral->SalMessageBox(parent, buf, LoadStr(IDS_ABOUT), MB_OK | MB_ICONINFORMATION);
}

void CPluginInterface::LoadConfiguration(HWND parent, HKEY regKey, CSalamanderRegistryAbstract* registry)
{
    CALL_STACK_MESSAGE1("CPluginInterface::LoadConfiguration(, ,)");
    if (regKey != NULL) // load from the registry
    {
        if (!registry->GetValue(regKey, CONFIG_VERSION, REG_DWORD, &ConfigVersion, sizeof(DWORD)))
        {
            ConfigVersion = 0; // error - use the version without loading
        }
    }
    else // default configuration
    {
        ConfigVersion = 0; // without loading
    }
}

void CPluginInterface::SaveConfiguration(HWND parent, HKEY regKey, CSalamanderRegistryAbstract* registry)
{
    CALL_STACK_MESSAGE1("CPluginInterface::SaveConfiguration(, ,)");

    DWORD v = CURRENT_CONFIG_VERSION;
    registry->SetValue(regKey, CONFIG_VERSION, REG_DWORD, &v, sizeof(DWORD));
}

void CPluginInterface::Connect(HWND parent, CSalamanderConnectAbstract* salamander)
{
    CALL_STACK_MESSAGE1("CPluginInterface::Connect()");

    // base part:
    salamander->AddCustomUnpacker("TAR (Plugin)",
                                  "*.tar;*.tgz;*.tbz;*.taz;"
                                  "*.tar.gz;*.tar.bz;*.tar.bz2;*.tar.z;"
                                  "*_tar.gz;*_tar.bz;*_tar.bz2;*_tar.z;"
                                  "*_tar_gz;*_tar_bz;*_tar_bz2;*_tar_z;"
                                  "*.tar_gz;*.tar_bz;*.tar_bz2;*.tar_z;"
                                  "*.gz;*.bz;*.bz2;*.z;"
                                  "*.rpm;*.cpio;*.deb",
                                  ConfigVersion < 5);                                       // ignored during upgrades except when upgrading to version 4 - required update because of "*.z" and others
    salamander->AddPanelArchiver("tgz;tbz;taz;tar;gz;bz;bz2;z;rpm;cpio;deb", FALSE, FALSE); // ignored when upgrading the plugin
    salamander->AddViewer("*.rpm", FALSE);                                                  // ignored when upgrading the plugin except when upgrading from a version without the viewer (the version shipped with SS 2.0)

    // section for upgrades:
    if (ConfigVersion < 1) // 1 - work-in-progress version before Servant Salamander 2.5 beta 1, added tbz, bz, bz2, and rpm
    {
        salamander->AddPanelArchiver("tbz;bz;bz2;rpm", FALSE, TRUE);
    }

    if (ConfigVersion < 2) // 2 - work-in-progress version before Servant Salamander 2.5 beta 1, added cpio (including the *.cpio viewer - that was a mistake)
    {
        salamander->AddPanelArchiver("cpio", FALSE, TRUE);

        // adding *.cpio was a mistake, version 3 removes it again
        //salamander->AddViewer("*.cpio", TRUE);
    }

    /*
  if (ConfigVersion < 3)    // 3 - work-in-progress version before Servant Salamander 2.5 beta 1, removed the *.cpio viewer
  {
    salamander->ForceRemoveViewer("*.cpio");   // comment out once we consider it dead code
  }
*/

    if (ConfigVersion < 4) // 4 - work-in-progress version before Servant Salamander 2.5 beta 1, added .z archives
    {
        salamander->AddPanelArchiver("taz;z", FALSE, TRUE);
    }
    if (ConfigVersion < 5) // 5 - work-in-progress version before Servant Salamander 2.52 beta 2, added .deb archives
    {
        salamander->AddPanelArchiver("deb", FALSE, TRUE);
    }
}

CPluginInterfaceForArchiverAbstract*
CPluginInterface::GetInterfaceForArchiver()
{
    return &InterfaceForArchiver;
}

CPluginInterfaceForViewerAbstract*
CPluginInterface::GetInterfaceForViewer()
{
    return &InterfaceForViewer;
}

//
// ****************************************************************************
//
// Operational functions provided by the plugin
//
// ****************************************************************************
//

BOOL CPluginInterfaceForArchiver::ListArchive(CSalamanderForOperationsAbstract* salamander,
                                              const char* fileName,
                                              CSalamanderDirectoryAbstract* dir,
                                              CPluginDataInterfaceAbstract*& pluginData)
{
    CALL_STACK_MESSAGE2("CPluginInterfaceForArchiver::ListArchive(, %s, ,)", fileName);
    pluginData = NULL;

    // create the archive object
    CArchiveAbstract* archive = CreateArchive(fileName, salamander);
    // and list it
    if (archive)
    {
        // feature 252: built case-sensitively - folders "D" and "d" stay two folders (merged, the
        // byte-exact extraction of the merged folder left the other one's files behind); the flag
        // is kept only when some folder holds names that differ only in case, otherwise the
        // listing is exactly the case-insensitive one it always was. One read of the archive.
        dir->SetFlags(SALDIRFLAG_CASESENSITIVE);
        BOOL ret = archive->ListArchive(NULL, dir);
        if (!SalDirTreeHasCaseTwins(dir))
            dir->SetFlags(0);
        delete archive;
        return ret;
    }
    return FALSE;
}

BOOL CPluginInterfaceForArchiver::UnpackArchive(CSalamanderForOperationsAbstract* salamander,
                                                const char* fileName, CPluginDataInterfaceAbstract* pluginData,
                                                const char* targetDir, const char* archiveRoot,
                                                SalEnumSelection next, void* nextParam)
{
    CALL_STACK_MESSAGE4("CPluginInterfaceForArchiver::UnpackArchive(, %s, , %s, %s,,,)",
                        fileName, targetDir, archiveRoot);

    // create the archive object
    CArchiveAbstract* archive = CreateArchive(fileName, salamander);
    // and extract it
    if (archive)
    {
        BOOL ret = archive->UnpackArchive(targetDir, archiveRoot, next, nextParam);
        delete archive;
        return ret;
    }
    return FALSE;
}

BOOL CPluginInterfaceForArchiver::UnpackOneFile(CSalamanderForOperationsAbstract* salamander,
                                                const char* fileName, CPluginDataInterfaceAbstract* pluginData,
                                                const char* nameInArchive, const CFileData* fileData,
                                                const char* targetDir, const char* newFileName,
                                                BOOL* renamingNotSupported)
{
    CALL_STACK_MESSAGE4("CPluginInterfaceForArchiver::UnpackOneFile(, %s, , %s, , %s, ,)",
                        fileName, nameInArchive, targetDir);

    // create the archive object
    CArchiveAbstract* archive = CreateArchive(fileName, salamander);
    // and extract it
    if (archive)
    {
        BOOL ret = archive->UnpackOneFile(nameInArchive, fileData, targetDir, newFileName);
        delete archive;
        return ret;
    }
    return FALSE;
}

BOOL CPluginInterfaceForArchiver::UnpackWholeArchive(CSalamanderForOperationsAbstract* salamander,
                                                     const char* fileName, const char* mask,
                                                     const char* targetDir, BOOL delArchiveWhenDone,
                                                     CDynamicString* archiveVolumes)
{
    CALL_STACK_MESSAGE5("CPluginInterfaceForArchiver::UnpackWholeArchive(, %s, %s, %s, %d,)",
                        fileName, mask, targetDir, delArchiveWhenDone);

    // create the archive object
    CArchiveAbstract* archive = CreateArchive(fileName, salamander);
    // and extract it
    if (archive)
    {
        if (delArchiveWhenDone)
            archiveVolumes->Add(fileName, -2); // FIXME: once the plugin learns multi-volume archives, add all volumes here (so the entire archive gets deleted)
        BOOL ret = archive->UnpackWholeArchive(mask, targetDir);
        delete archive;
        return ret;
    }
    return FALSE;
}

/*
BOOL
CPluginInterfaceForArchiver::PackToArchive(CSalamanderForOperationsAbstract *salamander,
                                           const char *fileName, const char *archiveRoot,
                                           BOOL move, const char *sourcePath,
                                           SalEnumSelection2 next, void *nextParam)
{
  CALL_STACK_MESSAGE5("CPluginInterfaceForArchiver::PackToArchive(, %s, %s, %d, %s,,)",
                      fileName, archiveRoot, move, sourcePath);
  return FALSE;
}

BOOL
CPluginInterfaceForArchiver::DeleteFromArchive(CSalamanderForOperationsAbstract *salamander,
                                               const char *fileName, CPluginDataInterfaceAbstract *pluginData,
                                               const char *archiveRoot, SalEnumSelection next,
                                               void *nextParam)
{
  CALL_STACK_MESSAGE3("CPluginInterfaceForArchiver::DeleteFromArchive(, %s, , %s, ,)",
                      fileName, archiveRoot);
  return FALSE;
}
*/

// function for the "file viewer"; called when the viewer should open and load a file
// 'name', 'left'+'right'+'width'+'height'+'showCmd'+'alwaysOnTop' is the recommended window placement
// if 'returnUnlock' is FALSE, 'unlock'+'unlockOwner' have no meaning
// if 'returnUnlock' is TRUE, the viewer should return the system event 'unlock'
// in the non-signaled state; it transitions to the signaled state when viewing
// the file 'name' finishes (the file is removed from the temporary directory at that time). It should also
// return TRUE in 'unlockOwner' if the caller should close the 'unlock' object (FALSE means
// the viewer closes 'unlock' itself); if the viewer does not set 'unlock' (stays NULL)
// the file 'name' is valid only until this ViewFile call ends. If
// 'viewerData' is not NULL, it passes extended parameters to the viewer (see
// CSalamanderGeneralAbstract::ViewFileInPluginViewer). Returns TRUE on success
// (FALSE indicates failure; 'unlock' and 'unlockOwner' have no meaning in that case)
BOOL CPluginInterfaceForViewer::ViewFile(const char* name, int left, int top, int width, int height,
                                         UINT showCmd, BOOL alwaysOnTop, BOOL returnUnlock, HANDLE* unlock,
                                         BOOL* unlockOwner, CSalamanderPluginViewerData* viewerData,
                                         int enumFilesSourceUID, int enumFilesCurrentIndex)
{
    CALL_STACK_MESSAGE11("CPluginInterfaceForViewer::ViewFile(%s, %d, %d, %d, %d, "
                         "0x%X, %d, %d, , , , %d, %d)",
                         name, left, top, width, height,
                         showCmd, alwaysOnTop, returnUnlock, enumFilesSourceUID, enumFilesCurrentIndex);

    // unlock stays NULL, we do not need locking
    //   therefore we also ignore returnUnlock and unlockOwner
    // viewerData is not used

    // store the original cursor and show the hourglass (even though it should not take long...)
    HCURSOR hOldCur = SetCursor(LoadCursor(NULL, IDC_WAIT));

    // open the input file ('name' is UTF-8 since interface 104 -> W API)
    HANDLE file = CreateFileU8(name, GENERIC_READ, FILE_SHARE_READ, OPEN_EXISTING,
                               FILE_FLAG_SEQUENTIAL_SCAN);
    if (file == INVALID_HANDLE_VALUE)
    {
        int err = GetLastError();
        SetCursor(hOldCur);
        SalamanderGeneral->ShowMessageBox(LoadErr(IDS_GZERR_FOPEN, err),
                                          LoadStr(IDS_GZERR_TITLE), MSGBOX_ERROR);
        return FALSE;
    }
    // allocate a buffer for reading the file
    unsigned char* buffer = (unsigned char*)malloc(BUFSIZE);
    if (buffer == NULL)
    {
        SetCursor(hOldCur);
        SalamanderGeneral->ShowMessageBox(LoadStr(IDS_ERR_MEMORY), LoadStr(IDS_GZERR_TITLE),
                                          MSGBOX_ERROR);
        CloseHandle(file);
        return FALSE;
    }
    // read the first block of data
    DWORD read;
    if (!ReadFile(file, buffer, BUFSIZE, &read, NULL))
    {
        // read error
        int err = GetLastError();
        SetCursor(hOldCur);
        free(buffer);
        CloseHandle(file);
        SalamanderGeneral->ShowMessageBox(LoadErr(IDS_ERR_FREAD, err), LoadStr(IDS_GZERR_TITLE), MSGBOX_ERROR);
        return FALSE;
    }
    // obtain a name for the temporary text file with the results
    char tempFileName[MAX_PATH];
    if (!SalamanderGeneral->SalGetTempFileName(NULL, "RPV", tempFileName, TRUE, NULL))
    {
        SetCursor(hOldCur);
        free(buffer);
        CloseHandle(file);
        SalamanderGeneral->ShowMessageBox(LoadStr(IDS_RPMERR_TMPNAME), LoadStr(IDS_ERR_RPMTITLE), MSGBOX_ERROR);
        return FALSE;
    }

    // create the temporary file (the name comes from the core: UTF-8 -> W CRT API)
    WCHAR* wTempFileName = SplU8ToWExtAlloc(tempFileName);
    FILE* fContents = wTempFileName != NULL ? _wfopen(wTempFileName, L"wt") : NULL;
    free(wTempFileName);
    if (fContents == NULL)
    {
        char buff[500];
        SetCursor(hOldCur);
        free(buffer);
        CloseHandle(file);
        // feature 130: 'name' is UTF-8, so is the text in front of it
        _snprintf_s(buff, _TRUNCATE, "%s%s", LoadStrU8(IDS_RPMERR_TMPFILE), name);
        SplU8TrimTornTail(buff);
        SalamanderGeneral->ShowMessageBox(buff, LoadStr(IDS_ERR_RPMTITLE), MSGBOX_ERROR);
        return FALSE;
    }
    // create the RPM object and fill the temporary file with information
    CDecompressFile* archive = new CRPM(name, file, buffer, read, fContents);
    if (archive == NULL)
    {
        SetCursor(hOldCur);
        fclose(fContents);
        DeleteFileU8(tempFileName);
        free(buffer);
        CloseHandle(file);
        SalamanderGeneral->ShowMessageBox(LoadStr(IDS_ERR_MEMORY), LoadStr(IDS_ERR_RPMTITLE), MSGBOX_ERROR);
        return FALSE;
    }
    // TODO: probably make sure errors are not reported inside and only a flag is set according to the error
    if (!archive->IsOk())
    {
        SetCursor(hOldCur);
        fclose(fContents);
        DeleteFileU8(tempFileName);
        free(buffer);
        CloseHandle(file);
        if (archive->GetErrorCode() == 0)
            SalamanderGeneral->ShowMessageBox(LoadStr(IDS_ERR_NORPM), LoadStr(IDS_ERR_RPMTITLE), MSGBOX_ERROR);
        else
            SalamanderGeneral->ShowMessageBox(LoadStr(archive->GetErrorCode()),
                                              LoadStr(IDS_ERR_RPMTITLE), MSGBOX_ERROR);
        delete archive;
        return FALSE;
    }
    // now we can close the archive again...
    // the input file and buffer are cleaned up in the CDecompressFile destructor
    delete archive;
    // done
    fclose(fContents);

    // prepare the structure for Salamander's text viewer
    CSalamanderPluginInternalViewerData textViewerData;
    textViewerData.Size = sizeof(textViewerData);
    textViewerData.FileName = tempFileName;
    textViewerData.Mode = 0; // text mode
    char caption[500];
    // feature 130: 'name' is UTF-8 and the viewer shows a valid UTF-8 caption as UTF-8, so the
    // title word is UTF-8 too and a cut name does not leave half a character
    strncpy_s(caption, 451, name, _TRUNCATE);
    SplU8TrimTornTail(caption);
    strncat_s(caption, " - ", _TRUNCATE);
    strncat_s(caption, LoadStrU8(IDS_RPM_VIEWTITLE), _TRUNCATE);
    SplU8TrimTornTail(caption);
    textViewerData.Caption = caption;
    textViewerData.WholeCaption = TRUE;
    // show the file in Salamander's text viewer and delete it afterwards
    int err;
    SalamanderGeneral->ViewFileInPluginViewer(NULL, &textViewerData, TRUE, NULL, "rpm_dump.txt", err);

    // and finally clean up
    SetCursor(hOldCur);
    return TRUE;
}
