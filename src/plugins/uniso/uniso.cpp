// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"
#include "dbg.h"

#include "uniso.h"
#include "isoimage.h"
#include "dialogs.h"
#include "splloadstru8.h" // feature 130

#include "uniso.rh"
#include "uniso.rh2"
#include "lang\lang.rh"

// ****************************************************************************

HINSTANCE DLLInstance = NULL; // handle to the SPL - language-independent resources
HINSTANCE HLanguage = NULL;   // handle to the SLG - language-dependent resources

// interface object whose methods are called from Salamander
CPluginInterface PluginInterface;
// portion of the CPluginInterface for the archiver
CPluginInterfaceForArchiver InterfaceForArchiver;
// portion of the CPluginInterface for the viewer
CPluginInterfaceForViewer InterfaceForViewer;

// Salamander's general interface - valid from startup until the plugin is closed
CSalamanderGeneralAbstract* SalamanderGeneral = NULL;

// ZLIB compression/decompression interface;
CSalamanderZLIBAbstract* SalZLIB = NULL;

// BZIP2 compression/decompression interface;
CSalamanderBZIP2Abstract* SalBZIP2 = NULL;

// interface for comfortable work with files
CSalamanderSafeFileAbstract* SalamanderSafeFile = NULL;

// variable definition for "dbg.h"
CSalamanderDebugAbstract* SalamanderDebug = NULL;

// interface providing customized Windows controls used in Salamander
CSalamanderGUIAbstract* SalamanderGUI = NULL;

// variable definition for "spl_com.h"
int SalamanderVersion = 0;

int ConfigVersion = 0;
#define CURRENT_CONFIG_VERSION 6
const char* CONFIG_VERSION = "Version";

// for now this configuration slot is sufficient
//DWORD Options;
COptions Options;

CSalamanderBZIP2Abstract* GetSalamanderBZIP2();

const SYSTEMTIME MinTime = {1980, 01, 2, 01, 00, 00, 00, 000};

int SortByExtDirsAsFiles = FALSE; // current value of Salamander's configuration variable SALCFG_SORTBYEXTDIRSASFILES

//const char *CONFIG_OPTIONS = "Options";
const char* CONFIG_CLEAR_READONLY = "Clear Read Only";
const char* CONFIG_SESSION_AS_DIR = "Show Session As Directory";
const char* CONFIG_BOOTIMAGE_AS_FILE = "Show Boot Image As File";

BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved)
{
    switch (fdwReason)
    {
    case DLL_PROCESS_ATTACH:
    {
        DLLInstance = hinstDLL;
        break;
    }

    case DLL_PROCESS_DETACH:
    {
        break;
    }
    }
    return TRUE; // DLL can be loaded
}

char* LoadStr(int resID)
{
    return SalamanderGeneral->LoadStr(HLanguage, resID);
}

// feature 130: the text as UTF-8, for a sentence that holds a file name or another UTF-8 text
const char* LoadStrU8(int resID)
{
    return SplLoadStrU8(SalamanderGeneral, HLanguage, resID);
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
    DWORD err = GetLastError();
    free(w);
    SetLastError(err);
    return ret;
}

BOOL SetFileAttributesU8(const char* name, DWORD attrs)
{
    WCHAR* w = SplU8ToWExtAlloc(name);
    if (w == NULL)
        return FALSE;
    BOOL ret = SetFileAttributesW(w, attrs);
    DWORD err = GetLastError();
    free(w);
    SetLastError(err);
    return ret;
}

void EnsureU8Name(char* name, int bufSize)
{
    if (name == NULL || SplIsASCII(name))
        return; // ASCII is already valid UTF-8, byte for byte
    if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, name, -1, NULL, 0) > 0)
        return; // valid UTF-8 -> keep the bytes verbatim (never rewrite name bytes)

    // the bytes are not UTF-8 -> the image was produced with a legacy ANSI code page
    WCHAR w[U8_MAX_NAME];
    char u8[U8_MAX_NAME];
    if (MultiByteToWideChar(CP_ACP, 0, name, -1, w, U8_MAX_NAME) == 0 ||
        SplWToU8(w, u8, sizeof(u8)) == 0 || (int)strlen(u8) >= bufSize)
    {
        return; // cannot convert or would not fit -> leave the bytes untouched
    }
    strcpy(name, u8);
}

int WINAPI SalamanderPluginGetReqVer()
{
    return LAST_VERSION_OF_SALAMANDER;
}

CPluginInterfaceAbstract* WINAPI SalamanderPluginEntry(CSalamanderPluginEntryAbstract* salamander)
{
    // set SalamanderDebug for "dbg.h"
    SalamanderDebug = salamander->GetSalamanderDebug();
    // set SalamanderVersion for "spl_com.h"
    SalamanderVersion = salamander->GetVersion();
    HANDLES_CAN_USE_TRACE();

    CALL_STACK_MESSAGE1("SalamanderPluginEntry()");

    // this plugin is built for the current version of Salamander and newer - perform a check
    if (SalamanderVersion < LAST_VERSION_OF_SALAMANDER)
    { // we reject older versions
        MessageBox(salamander->GetParentWindow(),
                   REQUIRE_LAST_VERSION_OF_SALAMANDER,
                   "UnISO" /* do not translate! */, MB_OK | MB_ICONERROR);
        return NULL;
    }

    // load the language module (.slg)
    HLanguage = salamander->LoadLanguageModule(salamander->GetParentWindow(), "UnISO" /* do not translate! */);
    if (HLanguage == NULL)
        return NULL;

    // obtain Salamander's general interface
    SalamanderGeneral = salamander->GetSalamanderGeneral();
    SalZLIB = SalamanderGeneral->GetSalamanderZLIB();
    // obtain the interface providing customized Windows controls used in Salamander
    SalamanderGUI = salamander->GetSalamanderGUI();

#if LAST_VERSION_OF_SALAMANDER >= 33
    SalBZIP2 = SalamanderGeneral->GetSalamanderBZIP2();
#else
    SalBZIP2 = GetSalamanderBZIP2();
#endif

    SalamanderSafeFile = salamander->GetSalamanderSafeFile();

    // set the name of the help file
    SalamanderGeneral->SetHelpFileName("uniso.chm");

    SalamanderGeneral->GetConfigParameter(SALCFG_SORTBYEXTDIRSASFILES, &SortByExtDirsAsFiles,
                                          sizeof(SortByExtDirsAsFiles), NULL);

    if (!InterfaceForArchiver.Init())
        return NULL;

    if (!InitializeWinLib("UnISO" /* do not translate! */, DLLInstance))
        return NULL;
    SetWinLibStrings("Invalid number!", LoadStr(IDS_PLUGINNAME));
    SetupWinLibTheme(SalamanderGeneral); // feature 036: dark theme for WinLib dialogs

    // set up the basic plugin information
    salamander->SetBasicPluginData(LoadStr(IDS_PLUGINNAME),
                                   FUNCTION_PANELARCHIVERVIEW | FUNCTION_CUSTOMARCHIVERUNPACK |
                                       FUNCTION_CONFIGURATION | FUNCTION_LOADSAVECONFIGURATION |
                                       FUNCTION_VIEWER,
                                   VERSINFO_VERSION_NO_PLATFORM,
                                   VERSINFO_COPYRIGHT,
                                   LoadStr(IDS_PLUGIN_DESCRIPTION),
                                   "UnISO" /* do not translate! */, "iso;isz;nrg;bin;img;pdi;cdi;cif;ncd;c2d;dmg");

    salamander->SetPluginHomePageURL("www.tandemcommander.org");

    return &PluginInterface;
}

BOOL Warning(int resID, BOOL quiet, ...)
{
    if (!quiet)
    {
        char buf[1024];
        buf[0] = 0;
        va_list arglist;
        va_start(arglist, quiet);
        vsprintf(buf, LoadStr(resID), arglist);
        va_end(arglist);

        SalamanderGeneral->ShowMessageBox(buf, LoadStr(IDS_PLUGINNAME), MSGBOX_WARNING);
    }
    return FALSE;
}

BOOL Error(int resID, BOOL quiet, ...)
{
    if (!quiet)
    {
        char buf[1024];
        buf[0] = 0;
        va_list arglist;
        va_start(arglist, quiet);
        // feature 130: some callers pass a file name (UTF-8), so the template is UTF-8
        _vsnprintf_s(buf, _TRUNCATE, LoadStrU8(resID), arglist);
        va_end(arglist);
        SplU8TrimTornTail(buf);

        SalamanderGeneral->ShowMessageBox(buf, LoadStr(IDS_PLUGINNAME), MSGBOX_ERROR);
    }
    return FALSE;
}

// 'msg' must be UTF-8 (LoadStrU8): it is joined with GetErrorText(), which is UTF-8 (feature 130)
BOOL Error(const char* msg, DWORD err, BOOL quiet)
{
    if (!quiet)
        if (err != ERROR_FILE_NOT_FOUND && err != ERROR_NO_MORE_FILES) // it is an error
        {
            char buf[1024];
            _snprintf_s(buf, _TRUNCATE, "%s\n\n%s", msg, SalamanderGeneral->GetErrorText(err));
            SplU8TrimTornTail(buf);
            SalamanderGeneral->ShowMessageBox(buf, LoadStr(IDS_PLUGINNAME), MSGBOX_ERROR);
        }

    return FALSE;
}

BOOL SysError(int title, int error, ...)
{
    int lastErr = GetLastError();
    CALL_STACK_MESSAGE3("SysError(%d, %d, ...)", title, error);
    char buf[1024];
    *buf = 0;
    va_list arglist;
    va_start(arglist, error);
    vsprintf(buf, LoadStr(error), arglist);
    va_end(arglist);
    if (lastErr != ERROR_SUCCESS)
    {
        strcat(buf, " ");
        int l = (int)strlen(buf);
        FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, NULL, lastErr,
                      MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), buf + l, 1024 - l, NULL);
    }
    SalamanderGeneral->ShowMessageBox(buf, LoadStr(title), MSGBOX_ERROR);
    return FALSE;
}

// ****************************************************************************
//
// CPluginInterface
//

void CPluginInterface::About(HWND parent)
{
    char buf[1000];
    _snprintf_s(buf, _TRUNCATE,
                "%s " VERSINFO_VERSION "\n\n" VERSINFO_COPYRIGHT "\n\n"
                "%s",
                LoadStr(IDS_PLUGINNAME),
                LoadStr(IDS_PLUGIN_DESCRIPTION));
    SalamanderGeneral->SalMessageBox(parent, buf, LoadStr(IDS_ABOUT), MB_OK | MB_ICONINFORMATION);
}

BOOL CPluginInterface::Release(HWND parent, BOOL force)
{
    CALL_STACK_MESSAGE2("CPluginInterface::Release(, %d)", force);

    ReleaseWinLib(DLLInstance);

    return TRUE;
}

void CPluginInterface::LoadConfiguration(HWND parent, HKEY regKey, CSalamanderRegistryAbstract* registry)
{
    CALL_STACK_MESSAGE1("CPluginInterface::LoadConfiguration(, ,)");

    if (regKey != NULL) // load from the registry
    {
        if (!registry->GetValue(regKey, CONFIG_VERSION, REG_DWORD, &ConfigVersion, sizeof(DWORD)))
            ConfigVersion = 0; // default configuration
    }
    else
    {
        ConfigVersion = 0; // default configuration
    }

    // set defaults
    Options.ClearReadOnly = TRUE;
    Options.SessionAsDirectory = TRUE; // by default we show how good we are (they can turn it off if they want)
    Options.BootImageAsFile = TRUE;    // by default we show the boot image (they can turn it off if they want)

    if (regKey != NULL) // load from the registry
    {
        registry->GetValue(regKey, CONFIG_CLEAR_READONLY, REG_DWORD, &Options.ClearReadOnly, sizeof(DWORD));
        registry->GetValue(regKey, CONFIG_SESSION_AS_DIR, REG_DWORD, &Options.SessionAsDirectory, sizeof(DWORD));
        registry->GetValue(regKey, CONFIG_BOOTIMAGE_AS_FILE, REG_DWORD, &Options.BootImageAsFile, sizeof(DWORD));
    }
}

void CPluginInterface::SaveConfiguration(HWND parent, HKEY regKey, CSalamanderRegistryAbstract* registry)
{
    CALL_STACK_MESSAGE1("CPluginInterface::SaveConfiguration(, ,)");

    DWORD v = CURRENT_CONFIG_VERSION;
    registry->SetValue(regKey, CONFIG_VERSION, REG_DWORD, &v, sizeof(DWORD));

    registry->SetValue(regKey, CONFIG_CLEAR_READONLY, REG_DWORD, &Options.ClearReadOnly, sizeof(DWORD));
    registry->SetValue(regKey, CONFIG_SESSION_AS_DIR, REG_DWORD, &Options.SessionAsDirectory, sizeof(DWORD));
    registry->SetValue(regKey, CONFIG_BOOTIMAGE_AS_FILE, REG_DWORD, &Options.BootImageAsFile, sizeof(DWORD));
}

void CPluginInterface::Configuration(HWND parent)
{
    CConfigurationDialog dlg(parent);
    dlg.Execute();
}

void CPluginInterface::Connect(HWND parent, CSalamanderConnectAbstract* salamander)
{
    CALL_STACK_MESSAGE1("CPluginInterface::Connect(,)");

    /*  GENERAL RULES FOR IMPLEMENTING CONNECT (for more complex plugins with a configuration version - the
                                                ConfigVersion variable and the CURRENT_CONFIG_VERSION constant):
    - with each change you need to increase the CURRENT_CONFIG_VERSION number
      (in the first version CURRENT_CONFIG_VERSION = 1, not 0, so an upgrade can be distinguished from
       an installation)
    - in the base part (before the "if (ConfigVersion < YYY)" conditions):
      - write the code for the first installation of the plugin (the state where the plugin does not yet have a record
        in Salamander)
      - for AddCustomPacker and AddCustomUnpacker calls provide the condition "ConfigVersion < XXX" in the 'update'
        parameter, where XXX is the number of the last version in which the extensions for custom packers or
        unpackers changed (XXX for packers may differ from unpackers)
      - AddMenuItem, SetChangeDriveMenuItem, and SetThumbnailLoader work the same every time the plugin is loaded
        (installation/upgrades make no difference - we always start on a clean slate)
    - in the upgrade section (after the base part):
      - add a condition "if (ConfigVersion < XXX)", where XXX is the new value of the
        CURRENT_CONFIG_VERSION constant + add a comment from that version;
        in the body of that condition call:
        - if extensions were added for the "panel archiver", call
          "AddPanelArchiver(PPP, EEE, TRUE)", where PPP are only the new extensions separated
          by a semicolon and EEE is TRUE/FALSE ("panel view+edit"/"panel view only")
        - if extensions were added for the "viewer", call "AddViewer(PPP, TRUE)",
          where PPP are only the new extensions separated by a semicolon
        - if some old extensions for the "viewer" need to be removed, call
          "ForceRemoveViewer(PPP)" for each such extension PPP
        - if extensions for the "panel archiver" need to be removed, let Petr know; nobody has
          needed it yet, so it is not implemented
  */

    // Davide, when you add more extensions you need to increase CURRENT_CONFIG_VERSION, see ^^^

    // BASE PART
    // AddViewer and AddPanelArchiver are subject to the UPGRADE SECTION
    salamander->AddViewer("*.bin;*.img;*.iso;*.isz;*.nrg;*.pdi;*.cdi;*.cif;*.ncd;*.c2d;*.mdf", FALSE); // default (plugin installation), otherwise Salamander ignores it
    salamander->AddPanelArchiver("iso;isz;nrg;bin;img;pdi;cdi;cif;ncd;c2d;mdf;dmg", FALSE, FALSE);

    // in version 3 we added C2D
    // in version 4 we added MDF
    salamander->AddCustomUnpacker("UnISO (Plugin)",
                                  "*.iso;*.isz;*.nrg;*.bin;*.img;*.pdi;*.cdi;*.cif;*.ncd;*.c2d;*.mdf;*.dmg", ConfigVersion < 6);

    // set the plugin icon
    HBITMAP hBmp = (HBITMAP)LoadImage(DLLInstance, MAKEINTRESOURCE(IDB_UNISO),
                                      IMAGE_BITMAP, 16, 16, LR_DEFAULTCOLOR);
    salamander->SetBitmapWithIcons(hBmp);
    DeleteObject(hBmp);
    salamander->SetPluginIcon(0);
    salamander->SetPluginMenuAndToolbarIcon(0);

    // UPGRADE SECTION
    if (ConfigVersion < 2) // addition of NRG, PDI, CDI, CIF, NCD
    {
        salamander->AddViewer("*.nrg;*.pdi;*.cdi;*.cif;*.ncd", TRUE);
        salamander->AddPanelArchiver("nrg;pdi;cdi;cif;ncd", FALSE, TRUE);
    }

    if (ConfigVersion < 3) // addition of C2D
    {
        salamander->AddViewer("*.c2d", TRUE);
        salamander->AddPanelArchiver("c2d", FALSE, TRUE);
    }

    if (ConfigVersion < 4) // addition of MDF/MDS
    {
        salamander->AddViewer("*.mdf", TRUE);
        salamander->AddPanelArchiver("mdf", FALSE, TRUE);
    }

    if (ConfigVersion < 5) // addition of DMG
    {
        salamander->AddViewer("*.dmg", TRUE);
        salamander->AddPanelArchiver("dmg", FALSE, TRUE);
    }

    if (ConfigVersion < 6) // addition of ISZ
    {
        salamander->AddViewer("*.isz", TRUE);
        salamander->AddPanelArchiver("isz", FALSE, TRUE);
    }
    //  _CrtSetBreakAlloc(13012);
}

void CPluginInterface::Event(int event, DWORD param)
{
    if (event == PLUGINEVENT_CONFIGURATIONCHANGED)
    {
        SalamanderGeneral->GetConfigParameter(SALCFG_SORTBYEXTDIRSASFILES, &SortByExtDirsAsFiles,
                                              sizeof(SortByExtDirsAsFiles), NULL);
    }
}

void CPluginInterface::ReleasePluginDataInterface(CPluginDataInterfaceAbstract* pluginData)
{
    delete ((CPluginDataInterface*)pluginData);
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

// ****************************************************************************
//
// CPluginInterfaceForArchiver
//

CPluginInterfaceForArchiver::CPluginInterfaceForArchiver()
{
}

BOOL CPluginInterfaceForArchiver::Init()
{
    CALL_STACK_MESSAGE1("CPluginInterfaceForArchiver::Init()");

    return TRUE;
}

BOOL CPluginInterfaceForArchiver::ListArchive(CSalamanderForOperationsAbstract* salamander,
                                              const char* fileName,
                                              CSalamanderDirectoryAbstract* dir,
                                              CPluginDataInterfaceAbstract*& pluginData)
{
    CALL_STACK_MESSAGE2("CPluginInterfaceForArchiver::ListArchive(, %s, ,)", fileName);

    pluginData = new CPluginDataInterface();
    if (pluginData == NULL)
    {
        return Error(IDS_INSUFFICIENT_MEMORY);
    }

    CPluginDataInterface* pd = (CPluginDataInterface*)pluginData;

    // try to open the ISO image
    BOOL ret = FALSE;
    HWND hParent = SalamanderGeneral->GetMsgBoxParent();
    CISOImage isoImage; // the destructor calls Close
    isoImage.DisplayMissingCCDWarning = pd->DisplayMissingCCDWarning;
    if (isoImage.Open(fileName, FALSE))
    {
        // hand over the complete listing to Salamander's core
        if (isoImage.ListImage(dir, pluginData))
        {
            ret = TRUE;

            pd->DisplayMissingCCDWarning = isoImage.DisplayMissingCCDWarning;
        }
    }

    if (ret == FALSE)
    {
        delete (CPluginDataInterface*)pluginData;
        pluginData = NULL;
    }

    return ret;
}

void FreeString(void* strig)
{
    free(strig);
}

BOOL CPluginInterfaceForArchiver::UnpackArchive(CSalamanderForOperationsAbstract* salamander, const char* fileName,
                                                CPluginDataInterfaceAbstract* pluginData, const char* targetDir,
                                                const char* archiveRoot, SalEnumSelection next, void* nextParam)
{
    CALL_STACK_MESSAGE4("CPluginInterfaceForArchiver::UnpackArchive(, %s, , %s, %s, ,)", fileName, targetDir, archiveRoot);

    if (pluginData == NULL)
    {
        TRACE_E("Internal error");
        return FALSE;
    }

    CPluginDataInterface* pd = (CPluginDataInterface*)pluginData;

    // try to open the ISO image
    CISOImage isoImage; // the destructor calls Close
    isoImage.DisplayMissingCCDWarning = pd->DisplayMissingCCDWarning;
    if (!isoImage.Open(fileName, FALSE))
        return FALSE;

    BOOL ret = FALSE;
    // compute 'totalSize' for the progress dialog
    BOOL isDir;
    CQuadWord size;
    CQuadWord totalSize(0, 0);
    CQuadWord fileCount(0, 0);
    const char* name;
    const CFileData* fileData;
    int errorOccured;
    while ((name = next(SalamanderGeneral->GetMsgBoxParent(), 1, &isDir, &size, &fileData, nextParam, &errorOccured)) != NULL)
    {
        if (!isDir)
        {
            totalSize += size;
            ++fileCount;
        } // if

        totalSize += CQuadWord(1, 0);
    }

    // unpack
    BOOL delTempDir = TRUE;
    if (errorOccured != SALENUM_CANCEL && // test to see whether an error occurred and the user did not request to cancel the operation (Cancel button)
        SalamanderGeneral->TestFreeSpace(SalamanderGeneral->GetMsgBoxParent(),
                                         targetDir, totalSize, LoadStr(IDS_UNPACKING_ARCHIVE)))
    {
        salamander->OpenProgressDialog(LoadStr(IDS_UNPACKING_ARCHIVE), TRUE, NULL, FALSE);
        salamander->ProgressSetTotalSize(CQuadWord(0, 0), totalSize);

        DWORD silent = 0;
        BOOL toSkip = FALSE, bAudioEncountered = FALSE;

        // path inside the image; UTF-8 names can be up to 3x longer than before
        // (interface 104), so copy bounded instead of with a plain strcpy
        char currentISOPath[ISO_MAX_PATH_LEN];
        lstrcpyn(currentISOPath, archiveRoot, ISO_MAX_PATH_LEN);

        ret = TRUE;
        next(NULL, -1, NULL, NULL, NULL, nextParam, NULL);
        // the target path is UTF-8 and may be long (interface 104) -> heap buffer
        CU8PathBuf destPath;
        if (!destPath.IsOk())
        {
            Error(IDS_INSUFFICIENT_MEMORY);
            salamander->CloseProgressDialog();
            pd->DisplayMissingCCDWarning = isoImage.DisplayMissingCCDWarning;
            return FALSE;
        }
        while ((name = next(NULL /* we do not print the errors a second time */, 1, &isDir, &size, &fileData, nextParam, NULL)) != NULL)
        {
            // directories do not interest us; they are created while unpacking files
            lstrcpyn(destPath, targetDir, U8_MAX_PATH);

            if (SalamanderGeneral->SalPathAppend(destPath, name, U8_MAX_PATH))
            {
                if (isDir)
                {
                    if (isoImage.UnpackDir(destPath, fileData) == UNPACK_CANCEL ||
                        !salamander->ProgressAddSize(1, TRUE))
                    {
                        ret = FALSE;
                        break;
                    }
                }
                else
                {
                    salamander->ProgressDialogAddText(name, TRUE); // delayedPaint==TRUE, so we do not slow things down

                    //  if the destination path does not exist -> create it
                    char* lastComp = strrchr(destPath, '\\');
                    if (lastComp != NULL)
                    {
                        *lastComp = '\0';
                        SalamanderGeneral->CheckAndCreateDirectory(destPath);
                    } // if

                    salamander->ProgressSetSize(CQuadWord(0, 0), CQuadWord(-1, -1), TRUE);
                    salamander->ProgressSetTotalSize(fileData->Size + CQuadWord(1, 0), CQuadWord(-1, -1));

                    int err = isoImage.UnpackFile(salamander, currentISOPath, destPath, fileData, silent, toSkip);

                    if ((UNPACK_AUDIO_UNSUP == err) && !bAudioEncountered)
                    {
                        bAudioEncountered = TRUE;
                        Error(IDS_AUDIO_NOT_EXTRACTABLE);
                    }

                    if (err == UNPACK_CANCEL || !salamander->ProgressAddSize(1, TRUE)) // correction for zero-sized files
                    {
                        ret = FALSE;
                        break;
                    }
                }
            }
            else
            {
                Error(IDS_ERR_TOO_LONG_NAME);
                ret = FALSE;
                break;
            }
        } // while

        salamander->CloseProgressDialog();
    }

    pd->DisplayMissingCCDWarning = isoImage.DisplayMissingCCDWarning;

    return ret;
}

BOOL CPluginInterfaceForArchiver::UnpackOneFile(CSalamanderForOperationsAbstract* salamander,
                                                const char* fileName, CPluginDataInterfaceAbstract* pluginData,
                                                const char* nameInArchive, const CFileData* fileData,
                                                const char* targetDir, const char* newFileName,
                                                BOOL* renamingNotSupported)
{
    CALL_STACK_MESSAGE4("CPluginInterfaceForArchiver::UnpackOneFile(, %s, , %s, , %s, ,)", fileName,
                        nameInArchive, targetDir);

    if (newFileName != NULL)
    {
        *renamingNotSupported = TRUE;
        return FALSE;
    }

    if (pluginData == NULL)
    {
        TRACE_E("Internal error");
        return FALSE;
    }

    CPluginDataInterface* pd = (CPluginDataInterface*)pluginData;

    // try to open the ISO image
    CISOImage isoImage; // the destructor calls Close
    isoImage.DisplayMissingCCDWarning = pd->DisplayMissingCCDWarning;
    if (!isoImage.Open(fileName, FALSE))
        return FALSE;

    BOOL ret = TRUE;

    salamander->OpenProgressDialog(LoadStr(IDS_UNPACKING_ARCHIVE), FALSE, NULL, FALSE);
    salamander->ProgressSetTotalSize(fileData->Size + CQuadWord(1, 0), CQuadWord(-1, -1));

    // 'targetDir' is UTF-8 and may be a long path, 'nameInArchive' is a UTF-8 path
    // inside the image (interface 104) -> heap buffers
    CU8PathBuf name;
    CU8PathBuf srcPath;
    if (!name.IsOk() || !srcPath.IsOk())
    {
        Error(IDS_INSUFFICIENT_MEMORY);
        salamander->CloseProgressDialog();
        pd->DisplayMissingCCDWarning = isoImage.DisplayMissingCCDWarning;
        return FALSE;
    }
    lstrcpyn(name, targetDir, U8_MAX_PATH);
    const char* lastComp = strrchr(nameInArchive, '\\');
    if (lastComp != NULL)
        lastComp++;
    else
        lastComp = nameInArchive;

    if (SalamanderGeneral->SalPathAppend(name, lastComp, U8_MAX_PATH))
    {
        DWORD silent = 0;
        BOOL toSkip = FALSE;
        int err;

        salamander->ProgressDialogAddText(name, TRUE); // delayedPaint==TRUE, so we do not slow things down

        lstrcpyn(srcPath, nameInArchive, U8_MAX_PATH);
        char* lComp = strrchr(srcPath, '\\');
        if (lComp != NULL)
            *lComp = '\0';

        err = isoImage.UnpackFile(salamander, srcPath, targetDir, fileData, silent, toSkip);
        if (UNPACK_AUDIO_UNSUP == err)
            Error(IDS_AUDIO_NOT_EXTRACTABLE);
        ret = err == UNPACK_OK;
    } // if
    else
    {
        Error(IDS_ERR_TOO_LONG_NAME);
        ret = FALSE;
    }

    salamander->CloseProgressDialog();

    pd->DisplayMissingCCDWarning = isoImage.DisplayMissingCCDWarning;

    return ret;
}

void CalcSize(CSalamanderDirectoryAbstract const* dir, const char* mask, char* path, int pathBufSize,
              CQuadWord& size, CQuadWord& fileCount)
{
    int count = dir->GetFilesCount();
    int i;
    for (i = 0; i < count; i++)
    {
        CFileData const* file = dir->GetFile(i);
        //    TRACE_I("CalcSize(): file: " << path << (path[0] != 0 ? "\\" : "") << file->Name);

        if (SalamanderGeneral->AgreeMask(file->Name, mask, file->Ext[0] != 0))
        {
            size += file->Size + CQuadWord(1, 0);
            ++fileCount;
        }
    }

    count = dir->GetDirsCount();
    int pathLen = (int)strlen(path);
    int j;
    for (j = 0; j < count; j++)
    {
        CFileData const* file = dir->GetDir(j);
        //    TRACE_I("CalcSize(): directory: " << path << (path[0] != 0 ? "\\" : "") << file->Name);
        SalamanderGeneral->SalPathAppend(path, file->Name, pathBufSize);
        CSalamanderDirectoryAbstract const* subDir = dir->GetSalDir(j);
        CalcSize(subDir, mask, path, pathBufSize, size, fileCount);
        path[pathLen] = 0;
    }
}

BOOL CPluginInterfaceForArchiver::UnpackWholeArchive(CSalamanderForOperationsAbstract* salamander, const char* fileName,
                                                     const char* mask, const char* targetDir, BOOL delArchiveWhenDone,
                                                     CDynamicString* archiveVolumes)
{
    CALL_STACK_MESSAGE5("CPluginInterfaceForArchiver::UnpackWholeArchive(, %s, %s, %s, %d,)",
                        fileName, mask, targetDir, delArchiveWhenDone);

    CSalamanderDirectoryAbstract* dir = SalamanderGeneral->AllocSalamanderDirectory(FALSE);
    if (dir == NULL)
        return Error(IDS_INSUFFICIENT_MEMORY);

    BOOL ret = FALSE;
    CPluginDataInterfaceAbstract* pluginData = NULL;
    if (ListArchive(salamander, fileName, dir, pluginData))
    {
        // paths built from UTF-8 names (interface 104) -> heap buffers
        CU8PathBuf path;
        if (!path.IsOk())
        {
            if (pluginData != NULL)
            {
                dir->Clear(pluginData);
                PluginInterface.ReleasePluginDataInterface(pluginData);
            }
            SalamanderGeneral->FreeSalamanderDirectory(dir);
            return Error(IDS_INSUFFICIENT_MEMORY);
        }
        path[0] = 0;

        CQuadWord totalSize(0, 0);
        CQuadWord fileCount(0, 0);
        CalcSize(dir, mask, path, U8_MAX_PATH, totalSize, fileCount);

        BOOL delTempDir = TRUE;
        if (SalamanderGeneral->TestFreeSpace(SalamanderGeneral->GetMsgBoxParent(),
                                             targetDir, totalSize, LoadStr(IDS_UNPACKING_ARCHIVE)))
        {
            salamander->OpenProgressDialog(LoadStr(IDS_UNPACKING_ARCHIVE), TRUE, NULL, FALSE);
            salamander->ProgressSetTotalSize(CQuadWord(0, 0), totalSize);

            char modmask[256];
            SalamanderGeneral->PrepareMask(modmask, mask);

            // try to open the ISO image
            CISOImage isoImage; // the destructor calls Close
            if (isoImage.Open(fileName, FALSE))
            {
                if (delArchiveWhenDone)
                    archiveVolumes->Add(fileName, -2);

                DWORD silent = 0;
                BOOL toSkip = FALSE;
                // 'targetDir' is UTF-8 and may be a long path (interface 104) -> heap buffer
                CU8PathBuf strTarget;
                if (strTarget.IsOk())
                {
                    lstrcpyn(strTarget, targetDir, U8_MAX_PATH);
                    char srcPath[ISO_MAX_PATH_LEN];
                    srcPath[0] = '\0';
                    ret = isoImage.ExtractAllItems(salamander, srcPath, dir, modmask, strTarget, U8_MAX_PATH, silent, toSkip) != UNPACK_CANCEL;
                }
                else
                    Error(IDS_INSUFFICIENT_MEMORY);
            }

            salamander->CloseProgressDialog();
        }

        if (pluginData != NULL)
        {
            dir->Clear(pluginData);
            PluginInterface.ReleasePluginDataInterface(pluginData);
        }

        int panel = -1;
        CanCloseArchive(salamander, fileName, TRUE, panel);
    }

    SalamanderGeneral->FreeSalamanderDirectory(dir);

    return ret;
}

BOOL CPluginInterfaceForArchiver::CanCloseArchive(CSalamanderForOperationsAbstract* salamander,
                                                  const char* fileName,
                                                  BOOL force, int panel)
{
    CALL_STACK_MESSAGE4("CPluginInterfaceForArchiver::CanCloseArchive(, %s, %d, %d)", fileName, force, panel);

    return TRUE;
}

//
// ****************************************************************************
// CPluginInterfaceForViewer
//

BOOL CPluginInterfaceForViewer::ViewFile(const char* name, int left, int top, int width,
                                         int height, UINT showCmd, BOOL alwaysOnTop,
                                         BOOL returnLock, HANDLE* lock, BOOL* lockOwner,
                                         CSalamanderPluginViewerData* viewerData,
                                         int enumFilesSourceUID, int enumFilesCurrentIndex)
{
    CALL_STACK_MESSAGE11("CPluginInterfaceForViewer::ViewFile(%s, %d, %d, %d, %d, "
                         "0x%X, %d, %d, , , , %d, %d)",
                         name, left, top, width, height,
                         showCmd, alwaysOnTop, returnLock, enumFilesSourceUID, enumFilesCurrentIndex);

    // we do not set 'lock' or 'lockOwner'; we only need the validity of the file 'name'
    // within this method

    HCURSOR hOldCur = SetCursor(LoadCursor(NULL, IDC_WAIT));

    CISOImage* image;
    if ((image = new CISOImage()) == NULL)
    {
        SetCursor(hOldCur);
        return Error(IDS_INSUFFICIENT_MEMORY);
    }

    if (!image->Open(name))
    {
        delete image;
        SetCursor(hOldCur);
        return FALSE;
    }

    /*
  // open the last track
  int lastTrack = image->GetLastTrack();
  if (!image->OpenTrack(lastTrack)) {
    Error(IDS_CANT_OPEN_TRACK, FALSE, lastTrack);
    delete image;
    return FALSE;
  }
*/

    char tempFileName[MAX_PATH];
    if (SalamanderGeneral->SalGetTempFileName(NULL, "ISO", tempFileName, TRUE, NULL))
    {
        char caption[2000];
        int err;
        CSalamanderPluginInternalViewerData vData;

        // create a temporary file and pour the module dump into it
        // (the name comes from the core: UTF-8 since interface 104 -> W CRT API)
        WCHAR* wTempFileName = SplU8ToWExtAlloc(tempFileName);
        FILE* outStream = wTempFileName != NULL ? _wfopen(wTempFileName, L"w") : NULL;
        free(wTempFileName);
        if (outStream == NULL)
        {
            delete image;
            Error(IDS_CANT_CREATE_TEMP);
            return FALSE;
        }
        if (!image->DumpInfo(outStream))
        {
            // can this even happen?
        }
        fclose(outStream);
        delete image;

        // hand the file over to Salamander - it will move it into the cache and once it stops
        // using it, it will delete it
        vData.Size = sizeof(vData);
        vData.FileName = tempFileName;
        vData.Mode = 0;                                                            // text mode
        _snprintf_s(caption, _TRUNCATE, "%s - %s", name, LoadStrU8(IDS_PLUGINNAME)); // 'name' is a UTF-8 path, may be long; the viewer takes a UTF-8 caption (feature 130)
        SplU8TrimTornTail(caption);
        vData.Caption = caption;
        vData.WholeCaption = TRUE;
        if (!SalamanderGeneral->ViewFileInPluginViewer(NULL, &vData, TRUE, NULL, "iso_dump.txt", err))
        {
            // the file is deleted even in case of failure
        }
    }
    else
    {
        SetCursor(hOldCur);
        SalamanderGeneral->SalMessageBox(SalamanderGeneral->GetMsgBoxParent(), LoadStr(IDS_ERR_TMP),
                                         LoadStr(IDS_PLUGINNAME), MB_OK | MB_ICONEXCLAMATION);
        delete image;
    }

    SetCursor(hOldCur);
    return TRUE;
}

BOOL CPluginInterfaceForViewer::CanViewFile(const char* name)
{
    CALL_STACK_MESSAGE2("CPluginInterfaceForViewer::CanViewFile(%s)", name);

    BOOL canView = FALSE;

    CISOImage* image;
    if ((image = new CISOImage()) != NULL)
    {
        if (image->Open(name, TRUE))
            canView = TRUE;

        delete image;
    }

    return canView;
}

// ****************************************************************************
//
// CPluginDataInterface
//

CPluginDataInterface::CPluginDataInterface()
{
    // initialy display the 'missing CCD file' warning
    DisplayMissingCCDWarning = TRUE;
}

CPluginDataInterface::~CPluginDataInterface()
{
}

void CPluginDataInterface::ReleasePluginData(CFileData& file, BOOL isDir)
{
    CALL_STACK_MESSAGE1("CPluginDataInterface::ReleasePluginData(, )");

    delete (CISOImage::CFilePos*)(file.PluginData);
    file.PluginData = NULL;
}
