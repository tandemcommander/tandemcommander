// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#pragma comment(lib, "UxTheme.lib")

// enables dumping blocks that remain allocated on the heap after the plugin finishes
// #define DUMP_MEM

// plugin interface object whose methods are invoked by Salamander
CPluginInterface PluginInterface;
// portion of CPluginInterface dedicated to menus
CPluginInterfaceForMenu InterfaceForMenu;

CWindowQueue MainWindowQueue("FileComp Windows"); // list of all plugin windows
CThreadQueue ThreadQueue("FileComp Windows, Workers, and Remote Control");
volatile LONG CompareDialogsOpen = 0; // feature 118, see filecomp.h
CMappedFontFactory MappedFontFactory;
HINSTANCE hNormalizDll = NULL;
TNormalizeString PNormalizeString = NULL;
BOOL AlwaysOnTop = FALSE;

extern DWORD MainThreadID; // lukas/utilbase.cpp

// ****************************************************************************
//
// feature 102: UTF-8 texts (see filecomp.h)
//

static SRWLOCK LoadStrU8Lock = SRWLOCK_INIT;
static std::map<int, char*>* LoadStrU8Cache = NULL; // allocated on the first use

const char* LoadStrU8(int resID)
{
    const char* ret = NULL;
    AcquireSRWLockExclusive(&LoadStrU8Lock);
    try
    {
        if (LoadStrU8Cache == NULL)
            LoadStrU8Cache = new std::map<int, char*>;
        std::map<int, char*>::iterator it = LoadStrU8Cache->find(resID);
        if (it != LoadStrU8Cache->end())
            ret = it->second;
        else
        {
            char* u8 = SplWToU8Alloc(SG->LoadStrW(HLanguage, resID));
            if (u8 != NULL)
            {
                try
                {
                    (*LoadStrU8Cache)[resID] = u8;
                    ret = u8;
                }
                catch (...)
                {
                    free(u8);
                }
            }
        }
    }
    catch (...)
    {
    }
    ReleaseSRWLockExclusive(&LoadStrU8Lock);
    return ret != NULL ? ret : LoadStr(resID); // low memory: the code-page form, as before
}

void ReleaseLoadStrU8()
{
    // review: called at unload after ThreadQueue.KillAll - a thread killed while it held the
    // lock would leave it held for ever; then the cache is left to the process (not freed)
    // instead of waiting for ever at exit
    if (!TryAcquireSRWLockExclusive(&LoadStrU8Lock))
    {
        TRACE_E("ReleaseLoadStrU8(): the lock is held (a killed thread?), the cache is not freed");
        return;
    }
    if (LoadStrU8Cache != NULL)
    {
        for (std::map<int, char*>::iterator it = LoadStrU8Cache->begin(); it != LoadStrU8Cache->end(); ++it)
            free(it->second);
        delete LoadStrU8Cache;
        LoadStrU8Cache = NULL;
    }
    ReleaseSRWLockExclusive(&LoadStrU8Lock);
}

char* VSprintfAlloc(const char* format, va_list args)
{
    va_list args2;
    va_copy(args2, args);
    int len = _vscprintf(format, args2);
    va_end(args2);
    if (len < 0)
        return NULL;
    char* buf = (char*)malloc((size_t)len + 1);
    if (buf != NULL)
    {
        va_copy(args2, args);
        _vsnprintf_s(buf, (size_t)len + 1, _TRUNCATE, format, args2);
        va_end(args2);
    }
    return buf;
}

char* SprintfAlloc(const char* format, ...)
{
    va_list args;
    va_start(args, format);
    char* ret = VSprintfAlloc(format, args);
    va_end(args);
    return ret;
}

char* AppendSystemErrorU8(char* text, DWORD error)
{
    if (text == NULL)
        return NULL;
    WCHAR* sysW = NULL;
    if (FormatMessageW(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                       NULL, error, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), (LPWSTR)&sysW, 0, NULL) == 0 ||
        sysW == NULL)
    {
        return text; // no system text: the message without it, as FormatMessage did before
    }
    char* sys = SplWToU8Alloc(sysW);
    LocalFree(sysW);
    if (sys == NULL)
        return text;
    size_t l1 = strlen(text);
    size_t l2 = strlen(sys);
    char* ret = (char*)realloc(text, l1 + l2 + 1);
    if (ret != NULL)
        memcpy(ret + l1, sys, l2 + 1);
    else
        ret = text; // low memory: keep the message without the system text
    free(sys);
    return ret;
}

BOOL CopyU8Truncated(char* dst, size_t dstSize, const char* src)
{
    if (dstSize == 0)
        return FALSE;
    size_t len = strlen(src);
    if (len < dstSize)
    {
        memcpy(dst, src, len + 1);
        return TRUE;
    }
    len = dstSize - 1;
    // do not end inside a character: drop the continuation bytes and the lead byte of the
    // character the limit cut
    if (len > 0 && ((unsigned char)src[len] & 0xC0) == 0x80)
    {
        while (len > 0 && ((unsigned char)src[len] & 0xC0) == 0x80)
            len--;
    }
    memcpy(dst, src, len);
    dst[len] = 0;
    return FALSE;
}

void LabelToU8(const char* label, char* buf, int bufSize)
{
    if (bufSize <= 0)
        return;
    buf[0] = 0;
    if (label == NULL)
        return;
    WCHAR w[300];
    if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, label, -1, NULL, 0) > 0) // already UTF-8 (ASCII too)
    {
        CopyU8Truncated(buf, bufSize, label);
        return;
    }
    if (MultiByteToWideChar(CP_ACP, 0, label, -1, w, _countof(w)) > 0 && SplWToU8(w, buf, bufSize) > 0)
        return;
    CopyU8Truncated(buf, bufSize, label);
}

BOOL ErrorU8(HWND parent, int resID, const char* name, DWORD lastError)
{
    CALL_STACK_MESSAGE3("ErrorU8(, %d, %s, )", resID, name);
    char* text = SprintfAlloc(LoadStrU8(resID), name);
    if (text != NULL && lastError != ERROR_SUCCESS)
        text = AppendSystemErrorU8(text, lastError);
    if (parent == HWND(-1))
        parent = GetCurrentThreadId() == MainThreadID ? SG->GetMsgBoxParent() : NULL;
    SG->SalMessageBox(parent, text != NULL ? text : LoadStrU8(IDS_LOWMEM), LoadStr(IDS_SPLERROR),
                      MB_OK | MB_ICONERROR | (parent == NULL && AlwaysOnTop ? MB_TOPMOST : 0));
    free(text);
    return FALSE;
}

void SetWindowTitleU8(HWND hWnd, const char* text)
{
    WCHAR* w = SplU8ToWAlloc(text);
    if (w != NULL)
    {
        SplSetWindowTitleW(hWnd, w); // feature 100: exact also on this code-page window
        free(w);
    }
    else
        SetWindowTextA(hWnd, text); // not UTF-8 (cannot happen since feature 102): never blank
}

const char* CONFIG_VERSION = "Version";
const char* CONFIG_CONFIGURATION = "Configuration";
const char* CONFIG_COLORS = "Colors";
const char* CONFIG_CUSTOMCOLORS = "Custom Colors";
const char* CONFIG_DEFOPTIONS = "Default Diff Options";
const char* CONFIG_FORCETEXT = "Force Text";
const char* CONFIG_FORCEBINARY = "Force Binary";
const char* CONFIG_IGNORESPACECHANGE = "Ignore Space Change";
const char* CONFIG_IGNOREALLSPACE = "Ignore All Space";
const char* CONFIG_IGNORELINEBREAKSCHG = "Ignore Line Breaks Changes";
const char* CONFIG_IGNORECASE = "Ignore Case";
const char* CONFIG_EOLCONVERSION0 = "EOL Conversion 0";
const char* CONFIG_EOLCONVERSION1 = "EOL Conversion 1";
const char* CONFIG_REBARBANDSLAYOUT = "Rebar Bands Layout";
const char* CONFIG_HISTORY = "History %d";
const char* CONFIG_LASTCFGPAGE = "Last Configuration Page";
const char* CONFIG_LOADONSTART = "Load On Start";
const char* CONFIG_VIEW_HORIZONTAL = "Horizontal View";
const char* CONFIG_AUTO_COPY = "Auto-Copy Selection";
const char* CONFIG_NORMALIZATION_FORM = "Normalization Form";
const char* CONFIG_ENCODING0 = "Encoding 0";
const char* CONFIG_ENCODING1 = "Encoding 1";
const char* CONFIG_ENDIANS0 = "Endians 0";
const char* CONFIG_ENDIANS1 = "Endians 1";
const char* CONFIG_INPUTENC0 = "InputEnc 0";
const char* CONFIG_INPUTENC1 = "InputEnc 1";
const char* CONFIG_INPUTENCTABLE0 = "InputEnc Table 0";
const char* CONFIG_INPUTENCTABLE1 = "InputEnc Table 1";

BOOL LoadOnStart;

#ifdef DUMP_MEM
_CrtMemState ___CrtMemState;
#endif //DUMP_MEM

int WINAPI SalamanderPluginGetReqVer()
{
    CALL_STACK_MESSAGE_NONE
    return LAST_VERSION_OF_SALAMANDER;
}

CPluginInterfaceAbstract* WINAPI SalamanderPluginEntry(CSalamanderPluginEntryAbstract* salamander)
{
    CALL_STACK_MESSAGE_NONE

#ifdef DUMP_MEM
    _CrtMemCheckpoint(&___CrtMemState);
#endif //DUMP_MEM

    if (!InitLCUtils(salamander, "File Comparator" /* do not translate! */))
        return NULL;

    CALL_STACK_MESSAGE1("SalamanderPluginEntry()");

    SG->SetHelpFileName("filecomp.chm");

    if (!InitDialogs())
    {
        ReleaseLCUtils();
        return NULL;
    }

    InitXUnicode();
    MappedFontFactory.Init();

    hNormalizDll = LoadLibrary("normaliz.dll");
    if (hNormalizDll)
    {
        PNormalizeString = (TNormalizeString)GetProcAddress(hNormalizDll, "NormalizeString"); // Min: Vista
    }

    // set basic metadata about the plugin
    salamander->SetBasicPluginData(LoadStr(IDS_PLUGINNAME),
                                   FUNCTION_LOADSAVECONFIGURATION | FUNCTION_CONFIGURATION,
                                   VERSINFO_VERSION_NO_PLATFORM,
                                   VERSINFO_COPYRIGHT,
                                   LoadStr(IDS_PLUGIN_DESCRIPTION),
                                   "File Comparator" /* do not translate! */);

    salamander->SetPluginHomePageURL("www.tandemcommander.org");

    // The remote comparator (fcremote.exe's receiver) must start after
    // salamander->SetBasicPluginData because worker threads use the plugin version at startup
    // and salamander->SetBasicPluginData updates that value (it used to crash occasionally when
    // the version string was reallocated and the freed buffer was still referenced).
    // feature 102: it starts at the end of LoadConfiguration, which the core calls after this
    // entry point (see there).

    return &PluginInterface;
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
    SG->SalMessageBox(parent, buf, LoadStr(IDS_ABOUT), MB_OK | MB_ICONINFORMATION);
}

void WINAPI
LoadOrSaveConfiguration(BOOL load, HKEY regKey, CSalamanderRegistryAbstract* registry, void* param)
{
    CALL_STACK_MESSAGE2("LoadOrSaveConfiguration(%d, , , )", load);
    if (!load)
        PluginInterface.SaveConfiguration((HWND)param, regKey, registry);
}

BOOL CPluginInterface::Release(HWND parent, BOOL force)
{
    CALL_STACK_MESSAGE2("CPluginInterface::Release(, %d)", force);

    // feature 118 (interface 107): an installer is closing the program and nobody sits at the
    // machine. A comparator window holds nothing to lose - it shows what two files contain, also
    // while it is still comparing (it was declared at WM_CREATE) - and closes without a question;
    // its worker is cancelled silently (CW_EXIT). A Compare Files dialog holds typed names and is
    // never closed here: the plug-in refuses (the core has declined before getting here anyway,
    // the dialog is an undeclared window - this is the guard for a dialog opened in between).
    BOOL unattended = !force && SG->IsUnattendedClose();
    if (unattended && InterlockedCompareExchange(&CompareDialogsOpen, 0, 0) > 0)
    {
        TRACE_I("CPluginInterface::Release(): unattended close: a Compare Files dialog is open - refusing");
        return FALSE;
    }

    BOOL ret = CRemoteComparator::Terminate(force) || force;
    if (ret)
    {
        ret = MainWindowQueue.Empty();
        if (!ret)
        {
            if (unattended)
                ret = MainWindowQueue.CloseAllWindows(FALSE, 5000); // the 5 s the 088 viewers get
            else
                ret = MainWindowQueue.CloseAllWindows(force) || force;
        }
        if (ret)
        {
            if (!(unattended ? ThreadQueue.KillAll(FALSE, 5000) : ThreadQueue.KillAll(force)) && !force)
                ret = FALSE;
            else
            {
                //SG->CallLoadOrSaveConfiguration(FALSE, LoadOrSaveConfiguration, parent);

                ReleaseDialogs();
                ReleaseLoadStrU8(); // feature 102: before SG becomes invalid
                ReleaseLCUtils();
                MappedFontFactory.Free();
                if (hNormalizDll)
                    FreeLibrary(hNormalizDll);

#ifdef DUMP_MEM
                _CrtMemDumpAllObjectsSince(&___CrtMemState);
#endif //DUMP_MEM
            }
        }
    }
    _CrtCheckMemory();
    return ret;
}

void CPluginInterface::LoadConfiguration(HWND parent, HKEY regKey, CSalamanderRegistryAbstract* registry)
{
    CALL_STACK_MESSAGE1("CPluginInterface::LoadConfiguration(, , )");

    // initialize default values

    // configuration
    ::Configuration.ConfirmSelection = TRUE;
    ::Configuration.Context = 2;
    ::Configuration.TabSize = 8;
    ::Configuration.UseViewerFont = TRUE;
    ::Configuration.WhiteSpace = (char)0xB7;
    LoadOnStart = FALSE;

    // switches
    ::Configuration.ViewMode = fvmStandard;
    ::Configuration.ShowWhiteSpace = FALSE;
    ::Configuration.DetailedDifferences = TRUE;
    ::Configuration.HorizontalView = FALSE;
    SG->GetConfigParameter(SALCFG_AUTOCOPYSELTOCLIPBOARD, &::Configuration.AutoCopy,
                           sizeof(::Configuration.AutoCopy), NULL);

    // colors
    memcpy(Colors, DefaultColors, sizeof(SALCOLOR) * NUMBER_OF_COLORS);
    BandsParams[0].Width = -1;
    memset(CustomColors, 0, 16 * sizeof(COLORREF));

    // default compare options
    DefCompareOptions = DefaultCompareOptions;

    // history (feature 102: under the lock of the comparator threads)
    {
        CHistoryLock lock(TRUE);
        CBHistoryEntries = 0;
    }

    // last configuration page that was opened
    LastCfgPage = 0;

    if (regKey != NULL) // load from the registry
    {
        DWORD configVersion = 0;
        registry->GetValue(regKey, CONFIG_VERSION, REG_DWORD, &configVersion, sizeof(DWORD));
        if ((configVersion == CURRENT_CONFIG_VERSION) || (configVersion == CURRENT_CONFIG_VERSION_NORECOMPAREBUTTON) || (configVersion == CURRENT_CONFIG_VERSION_PRESEPARATEOPTIONS))
        {
            CRegBLOBConfiguration blob;
            // load configuration from the registry
            if (registry->GetValue(regKey, CONFIG_CONFIGURATION, REG_BINARY, &blob, sizeof(blob)))
            { // Configuration as stored in binary form in registry
                ::Configuration.ConfirmSelection = blob.ConfirmSelection;
                ::Configuration.Context = blob.Context;
                ::Configuration.TabSize = blob.TabSize;
                ::Configuration.FileViewLogFont = blob.FileViewLogFont;
                ::Configuration.UseViewerFont = blob.UseViewerFont;
                ::Configuration.WhiteSpace = blob.WhiteSpace;
                ::Configuration.ViewMode = blob.ViewMode;
                ::Configuration.ShowWhiteSpace = blob.ShowWhiteSpace;
                ::Configuration.DetailedDifferences = blob.DetailedDifferences;
            }

            // load colors
            registry->GetValue(regKey, CONFIG_COLORS, REG_BINARY, Colors, sizeof(SALCOLOR) * NUMBER_OF_COLORS);
            registry->GetValue(regKey, CONFIG_CUSTOMCOLORS, REG_BINARY, CustomColors, 16 * sizeof(COLORREF));
            // default compare options
            if (configVersion == CURRENT_CONFIG_VERSION_PRESEPARATEOPTIONS)
            {
                // import old config
                struct COldOptions
                {
                    int ForceText;
                    int ForceBinary;
                    int IgnoreSpaceChange;
                    int IgnoreAllSpace;
                    int Unused1;
                    int Unused2;
                    int Unused3;
                    int IgnoreCase;
                    char* Unused4[4];
                    char* Unused5[3];
                    unsigned int EolConversion[2];
                } old;
                if (registry->GetValue(regKey, CONFIG_DEFOPTIONS, REG_BINARY, &old, sizeof(COldOptions)))
                {
                    DefCompareOptions.ForceText = old.ForceText;
                    DefCompareOptions.ForceBinary = old.ForceBinary;
                    DefCompareOptions.IgnoreSpaceChange = old.IgnoreSpaceChange;
                    DefCompareOptions.IgnoreAllSpace = old.IgnoreAllSpace;
                    DefCompareOptions.IgnoreCase = old.IgnoreCase;
                    DefCompareOptions.EolConversion[0] = old.EolConversion[0] >> 1;
                    DefCompareOptions.EolConversion[1] = old.EolConversion[1] >> 1;
                }
            }
            else
            {
                _ASSERT(sizeof(int) == 4);
                registry->GetValue(regKey, CONFIG_FORCETEXT, REG_DWORD, &DefCompareOptions.ForceText, 4);
                registry->GetValue(regKey, CONFIG_FORCEBINARY, REG_DWORD, &DefCompareOptions.ForceBinary, 4);
                registry->GetValue(regKey, CONFIG_IGNORESPACECHANGE, REG_DWORD, &DefCompareOptions.IgnoreSpaceChange, 4);
                registry->GetValue(regKey, CONFIG_IGNOREALLSPACE, REG_DWORD, &DefCompareOptions.IgnoreAllSpace, 4);
                registry->GetValue(regKey, CONFIG_IGNORELINEBREAKSCHG, REG_DWORD, &DefCompareOptions.IgnoreLineBreakChanges, 4);
                registry->GetValue(regKey, CONFIG_IGNORECASE, REG_DWORD, &DefCompareOptions.IgnoreCase, 4);
                registry->GetValue(regKey, CONFIG_EOLCONVERSION0, REG_DWORD, &DefCompareOptions.EolConversion[0], 4);
                registry->GetValue(regKey, CONFIG_EOLCONVERSION1, REG_DWORD, &DefCompareOptions.EolConversion[1], 4);
                registry->GetValue(regKey, CONFIG_ENCODING0, REG_DWORD, &DefCompareOptions.Encoding[0], 4);
                registry->GetValue(regKey, CONFIG_ENCODING1, REG_DWORD, &DefCompareOptions.Encoding[1], 4);
                registry->GetValue(regKey, CONFIG_ENDIANS0, REG_DWORD, &DefCompareOptions.Endians[0], 4);
                registry->GetValue(regKey, CONFIG_ENDIANS1, REG_DWORD, &DefCompareOptions.Endians[1], 4);
                registry->GetValue(regKey, CONFIG_INPUTENC0, REG_DWORD, &DefCompareOptions.PerformASCII8InputEnc[0], 4);
                registry->GetValue(regKey, CONFIG_INPUTENC1, REG_DWORD, &DefCompareOptions.PerformASCII8InputEnc[1], 4);
                registry->GetValue(regKey, CONFIG_INPUTENCTABLE0, REG_SZ, DefCompareOptions.ASCII8InputEncTableName[0], 101);
                registry->GetValue(regKey, CONFIG_INPUTENCTABLE1, REG_SZ, DefCompareOptions.ASCII8InputEncTableName[1], 101);
                DWORD dw;
                if (registry->GetValue(regKey, CONFIG_NORMALIZATION_FORM, REG_DWORD, &dw, sizeof(DWORD)))
                    DefCompareOptions.NormalizationForm = dw ? TRUE : FALSE;
            }
            // history of recently used files
            TCHAR buf[32];
            CHistoryLock lock(TRUE); // feature 102
            for (; CBHistoryEntries < MAX_HISTORY_ENTRIES; CBHistoryEntries++)
            {
                _stprintf(buf, CONFIG_HISTORY, CBHistoryEntries);
                if (!registry->GetValue(regKey, buf, REG_SZ, CBHistory[CBHistoryEntries], SizeOf(CBHistory[CBHistoryEntries])))
                    break;
            }
            if (configVersion > CURRENT_CONFIG_VERSION_NORECOMPAREBUTTON)
            {
                // rebar layout: Do not read from config versions prior to 8 because Recompare btn was added in 8
                // and thus the toolbar could be partially covered by Differences
                registry->GetValue(regKey, CONFIG_REBARBANDSLAYOUT, REG_BINARY, BandsParams, sizeof(CBandParams) * 2);
            }
            // last visited page in the configuration dialog
            registry->GetValue(regKey, CONFIG_LASTCFGPAGE, REG_DWORD, &LastCfgPage, sizeof(DWORD));
            // load on start flag
            DWORD dw;
            if (registry->GetValue(regKey, CONFIG_LOADONSTART, REG_DWORD, &dw, sizeof(DWORD)))
                LoadOnStart = dw != 0;
            if (registry->GetValue(regKey, CONFIG_VIEW_HORIZONTAL, REG_DWORD, &dw, sizeof(DWORD)))
                ::Configuration.HorizontalView = dw ? TRUE : FALSE;
            if (registry->GetValue(regKey, CONFIG_AUTO_COPY, REG_DWORD, &dw, sizeof(DWORD)))
                ::Configuration.AutoCopy = dw ? TRUE : FALSE;
        }
    }

    SG->GetConfigParameter(SALCFG_VIEWERFONT, &::Configuration.InternalViewerFont, sizeof(LOGFONT), NULL);
    if (::Configuration.UseViewerFont)
    {
        // Used the font of Internal Viewer;
        ::Configuration.FileViewLogFont = ::Configuration.InternalViewerFont;
    }

    UpdateDefaultColors(Colors, Palette);
    // Do not allow normalization if Normaliz.dll is not present
    if (!PNormalizeString)
        DefCompareOptions.NormalizationForm = FALSE;

    // feature 102: the receiver of fcremote.exe's messages starts only now, with the
    // configuration loaded (it was started in the entry point, before the core calls this
    // function: a message that arrived at once - fcremote starts the program and sends as soon
    // as the receiver runs - started a comparison that read the history, the options and the
    // configuration while this function was still writing them). Created only once.
    CRemoteComparator::CreateRemoteComparator();
}

void CPluginInterface::SaveConfiguration(HWND parent, HKEY regKey, CSalamanderRegistryAbstract* registry)
{
    CALL_STACK_MESSAGE1("CPluginInterface::SaveConfiguration(, , )");

    // version information
    DWORD dw = CURRENT_CONFIG_VERSION;
    registry->SetValue(regKey, CONFIG_VERSION, REG_DWORD, &dw, sizeof(DWORD));

    // configuration block
    CRegBLOBConfiguration blob;
    // Configuration is stored in binary form in registry
    blob.ConfirmSelection = ::Configuration.ConfirmSelection;
    blob.Context = ::Configuration.Context;
    blob.TabSize = ::Configuration.TabSize;
    blob.FileViewLogFont = ::Configuration.FileViewLogFont;
    blob.UseViewerFont = ::Configuration.UseViewerFont;
    blob.WhiteSpace = ::Configuration.WhiteSpace;
    blob.ViewMode = ::Configuration.ViewMode;
    blob.ShowWhiteSpace = ::Configuration.ShowWhiteSpace;
    blob.DetailedDifferences = ::Configuration.DetailedDifferences;
    registry->SetValue(regKey, CONFIG_CONFIGURATION, REG_BINARY, &blob, sizeof(blob));

    // colors
    registry->SetValue(regKey, CONFIG_COLORS, REG_BINARY, Colors, sizeof(SALCOLOR) * NUMBER_OF_COLORS);
    registry->SetValue(regKey, CONFIG_CUSTOMCOLORS, REG_BINARY, CustomColors, 16 * sizeof(COLORREF));
    // default compare options
    registry->SetValue(regKey, CONFIG_FORCETEXT, REG_DWORD, &DefCompareOptions.ForceText, 4);
    registry->SetValue(regKey, CONFIG_FORCEBINARY, REG_DWORD, &DefCompareOptions.ForceBinary, 4);
    registry->SetValue(regKey, CONFIG_IGNORESPACECHANGE, REG_DWORD, &DefCompareOptions.IgnoreSpaceChange, 4);
    registry->SetValue(regKey, CONFIG_IGNOREALLSPACE, REG_DWORD, &DefCompareOptions.IgnoreAllSpace, 4);
    registry->SetValue(regKey, CONFIG_IGNORELINEBREAKSCHG, REG_DWORD, &DefCompareOptions.IgnoreLineBreakChanges, 4);
    registry->SetValue(regKey, CONFIG_IGNORECASE, REG_DWORD, &DefCompareOptions.IgnoreCase, 4);
    registry->SetValue(regKey, CONFIG_EOLCONVERSION0, REG_DWORD, &DefCompareOptions.EolConversion[0], 4);
    registry->SetValue(regKey, CONFIG_EOLCONVERSION1, REG_DWORD, &DefCompareOptions.EolConversion[1], 4);
    registry->SetValue(regKey, CONFIG_ENCODING0, REG_DWORD, &DefCompareOptions.Encoding[0], 4);
    registry->SetValue(regKey, CONFIG_ENCODING1, REG_DWORD, &DefCompareOptions.Encoding[1], 4);
    registry->SetValue(regKey, CONFIG_ENDIANS0, REG_DWORD, &DefCompareOptions.Endians[0], 4);
    registry->SetValue(regKey, CONFIG_ENDIANS1, REG_DWORD, &DefCompareOptions.Endians[1], 4);
    registry->SetValue(regKey, CONFIG_INPUTENC0, REG_DWORD, &DefCompareOptions.PerformASCII8InputEnc[0], 4);
    registry->SetValue(regKey, CONFIG_INPUTENC1, REG_DWORD, &DefCompareOptions.PerformASCII8InputEnc[1], 4);
    registry->SetValue(regKey, CONFIG_INPUTENCTABLE0, REG_SZ, DefCompareOptions.ASCII8InputEncTableName[0], int(strlen(DefCompareOptions.ASCII8InputEncTableName[0])));
    registry->SetValue(regKey, CONFIG_INPUTENCTABLE1, REG_SZ, DefCompareOptions.ASCII8InputEncTableName[1], int(strlen(DefCompareOptions.ASCII8InputEncTableName[1])));
    dw = DefCompareOptions.NormalizationForm;
    registry->SetValue(regKey, CONFIG_NORMALIZATION_FORM, REG_DWORD, &dw, sizeof(DWORD));
    // history of recently used files
    BOOL b;
    if (SG->GetConfigParameter(SALCFG_SAVEHISTORY, &b, sizeof(BOOL), NULL) && b)
    {
        char buf[32];
        int i;
        CHistoryLock lock(FALSE); // feature 102
        for (i = 0; i < CBHistoryEntries; i++)
        {
            sprintf(buf, CONFIG_HISTORY, i);
            registry->SetValue(regKey, buf, REG_SZ, CBHistory[i], int(strlen(CBHistory[i])));
        }
    }
    else
    {
        // trim the history list
        char buf[32];
        int i;
        for (i = 0; i < MAX_HISTORY_ENTRIES; i++)
        {
            sprintf(buf, CONFIG_HISTORY, i);
            registry->DeleteValue(regKey, buf);
        }
    }
    // rebar layout
    registry->SetValue(regKey, CONFIG_REBARBANDSLAYOUT, REG_BINARY, BandsParams, sizeof(CBandParams) * 2);
    // last configuration page that was opened
    registry->SetValue(regKey, CONFIG_LASTCFGPAGE, REG_DWORD, &LastCfgPage, sizeof(DWORD));
    dw = LoadOnStart;
    registry->SetValue(regKey, CONFIG_LOADONSTART, REG_DWORD, &dw, sizeof(DWORD));
    SG->SetFlagLoadOnSalamanderStart(LoadOnStart);
    dw = ::Configuration.HorizontalView;
    registry->SetValue(regKey, CONFIG_VIEW_HORIZONTAL, REG_DWORD, &dw, sizeof(DWORD));
    dw = ::Configuration.AutoCopy;
    registry->SetValue(regKey, CONFIG_AUTO_COPY, REG_DWORD, &dw, sizeof(DWORD));
}

void CPluginInterface::Configuration(HWND parent)
{
    CALL_STACK_MESSAGE1("CPluginInterface::Configuration()");

    DWORD flag;
    CConfigurationDialog dlg(parent, &::Configuration, Colors, &DefCompareOptions, &flag);
    dlg.Execute();
    if (flag)
        MainWindowQueue.BroadcastMessage(WM_USER_CFGCHNG, flag, 0);
}

void CPluginInterface::Connect(HWND parent, CSalamanderConnectAbstract* salamander)
{
    CALL_STACK_MESSAGE1("CPluginInterface::Connect(,)");

    /* used by the export_mnu.py script that generates salmenu.mnu for the Translator
   keep synchronized with the salamander->AddMenuItem() calls below...
MENU_TEMPLATE_ITEM PluginMenu[] =
{
  {MNTT_PB, 0
  {MNTT_IT, IDS_COMPAREFILES
  {MNTT_PE, 0
};
*/
    salamander->AddMenuItem(-1, LoadStr(IDS_COMPAREFILES), SALHOTKEY('C', HOTKEYF_CONTROL | HOTKEYF_SHIFT), MID_COMPAREFILES, FALSE,
                            MENU_EVENT_DISK, 0, MENU_SKILLLEVEL_ALL);
    // assign the plugin icon
    HBITMAP hBmp = (HBITMAP)LoadImage(DLLInstance, MAKEINTRESOURCE(IDB_FILECOMP),
                                      IMAGE_BITMAP, 16, 16, LR_DEFAULTCOLOR);
    salamander->SetBitmapWithIcons(hBmp);
    DeleteObject(hBmp);
    salamander->SetPluginIcon(0);
    salamander->SetPluginMenuAndToolbarIcon(0);
}

CPluginInterfaceForMenuExtAbstract*
CPluginInterface::GetInterfaceForMenuExt()
{
    CALL_STACK_MESSAGE_NONE
    return &InterfaceForMenu;
}

void CPluginInterface::Event(int event, DWORD param) // FIXME_X64 - is a 32-bit DWORD sufficient here?
{
    CALL_STACK_MESSAGE2("CPluginInterface::Event(, 0x%X)", param);
    switch (event)
    {
    case PLUGINEVENT_COLORSCHANGED:
    {
        // the text color may have changed
        MainWindowQueue.BroadcastMessage(WM_USER_CFGCHNG, CC_COLORS, 0);
        break;
    }

    case PLUGINEVENT_CONFIGURATIONCHANGED:
    {
        // Cache the value for use in Config dialog
        SG->GetConfigParameter(SALCFG_VIEWERFONT, &::Configuration.InternalViewerFont, sizeof(LOGFONT), NULL);
        // the viewer font may have changed
        if (::Configuration.UseViewerFont)
        {
            ::Configuration.FileViewLogFont = ::Configuration.InternalViewerFont;
            MainWindowQueue.BroadcastMessage(WM_USER_CFGCHNG, CC_FONT, 0);
        }
        break;
    }
    }
}

void CPluginInterface::ClearHistory(HWND parent)
{
    CALL_STACK_MESSAGE1("CPluginInterface::ClearHistory()");
    MainWindowQueue.BroadcastMessage(WM_USER_CLEARHISTORY, 0, 0);
    int i;
    CHistoryLock lock(TRUE); // feature 102
    for (i = 0; i < MAX_HISTORY_ENTRIES; i++)
        CBHistory[i][0] = 0;
}

// ****************************************************************************
//
// CPluginInterfaceForMenu
//

BOOL CPluginInterfaceForMenu::ExecuteMenuItem(CSalamanderForOperationsAbstract* salamander, HWND parent,
                                              int id, DWORD eventMask)
{
    CALL_STACK_MESSAGE3("CPluginInterfaceForMenu::ExecuteMenuItem(, , %d, 0x%X)",
                        id, eventMask);
    switch (id)
    {
    case MID_COMPAREFILES:
    {
        // feature 102: room for any panel path (a 260-byte buffer made GetPanelPath fail on a
        // path of about 86 Chinese characters and the command did nothing at all)
        CSalMaxPathBuffer file1Buf;
        CSalMaxPathBuffer file2Buf;
        if (file1Buf.Get() == NULL || file2Buf.Get() == NULL)
            return Error((HWND)-1, IDS_LOWMEM);
        char* file1 = file1Buf.Get();
        char* file2 = file2Buf.Get();
        const CFileData *fd1, *fd2 = NULL;
        int index = 0;
        BOOL isDir;
        BOOL secondFromSource = FALSE;
        int tgtPathType;
        SG->GetPanelPath(PANEL_TARGET, NULL, 0, &tgtPathType, NULL);
        BOOL tgtPanelIsDisk = (tgtPathType == PATH_TYPE_WINDOWS);

        *file1 = 0;
        *file2 = 0;

        fd1 = SG->GetPanelSelectedItem(PANEL_SOURCE, &index, &isDir);

        if (fd1 && isDir)
            goto SELECTION_FINISHED; // ignore directories

        if (fd1)
        {
            // we have the first selected file; try to find a second one in the source panel
            fd2 = SG->GetPanelSelectedItem(PANEL_SOURCE, &index, &isDir);

            if (fd2 && isDir)
                goto SELECTION_FINISHED; // ignore directories

            if (!fd2)
            {
                // one item is selected and we take the other either from focus
                // or from the selection in the target panel
                index = 0;
                fd2 = SG->GetPanelSelectedItem(PANEL_TARGET, &index, &isDir);
                if (!tgtPanelIsDisk || !fd2 || SG->GetPanelSelectedItem(PANEL_TARGET, &index, &isDir))
                {
                    // the target panel contains zero or more than one selected file
                    // so fall back to the focused item in the source panel
                    fd2 = SG->GetPanelFocusedItem(PANEL_SOURCE, &isDir);
                }
                else
                    fd2 = NULL;
            }
            else
            {
                // we have two selected files; ensure a third one is not selected
                // three selected files are ignored
                if (SG->GetPanelSelectedItem(PANEL_SOURCE, &index, &isDir))
                    goto SELECTION_FINISHED;
            }
        }
        else
        {
            // no file was selected; use the focused item instead
            fd1 = SG->GetPanelFocusedItem(PANEL_SOURCE, &isDir);

            if (fd1 && isDir)
                goto SELECTION_FINISHED; // ignore directories
        }

        if (fd1 == NULL)
            goto SELECTION_FINISHED; // empty panel

        // store the name of the first file
        // feature 102: an append that does not fit leaves the field empty (the dialog then asks
        // for the file) instead of offering the folder as the file - it cannot happen with these
        // buffers, which hold the longest path Windows has
        if (!SG->GetPanelPath(PANEL_SOURCE, file1, FC_NAME_SIZE, NULL, NULL))
            return NULL;
        if (!SG->SalPathAppend(file1, fd1->Name, FC_NAME_SIZE))
            *file1 = 0;

        if (fd2 &&
            !isDir && fd2 != fd1) // in case we take the file from the focus
        {
            // store the name of the second file
            if (!SG->GetPanelPath(PANEL_SOURCE, file2, FC_NAME_SIZE, NULL, NULL) ||
                !SG->SalPathAppend(file2, fd2->Name, FC_NAME_SIZE))
            {
                *file2 = 0;
            }
            secondFromSource = TRUE;
        }
        else
        {
            if (tgtPanelIsDisk)
            {
                // we still need to pick the second file from the target panel
                index = 0;
                fd2 = SG->GetPanelSelectedItem(PANEL_TARGET, &index, &isDir);

                if (!fd2 || isDir || SG->GetPanelSelectedItem(PANEL_TARGET, &index, &isDir))
                {
                    // find the file with the same name as the first one
                    index = 0;
                    while ((fd2 = SG->GetPanelItem(PANEL_TARGET, &index, &isDir)) != 0)
                    {
                        if (!isDir && SG->StrICmp(fd1->Name, fd2->Name) == 0)
                            break;
                    }
                }

                if (fd2)
                {
                    // store the name of the second file
                    if (!SG->GetPanelPath(PANEL_TARGET, file2, FC_NAME_SIZE, NULL, NULL))
                        return NULL;
                    if (!SG->SalPathAppend(file2, fd2->Name, FC_NAME_SIZE))
                        *file2 = 0;
                }
            }
        }

    SELECTION_FINISHED:

        BOOL doNotSwapNames = secondFromSource || SG->GetSourcePanel() == PANEL_LEFT;
        SG->GetConfigParameter(SALCFG_ALWAYSONTOP, &AlwaysOnTop, sizeof(AlwaysOnTop), NULL);
        CFilecompThread* d = new CFilecompThread(doNotSwapNames ? file1 : file2, doNotSwapNames ? file2 : file1, FALSE, "");
        if (!d)
            return Error((HWND)-1, IDS_LOWMEM);
        if (!d->Create(ThreadQueue))
            delete d;
        SG->SetUserWorkedOnPanelPath(PANEL_SOURCE); // treat this command as working with the path (appears in Alt+F12)
        if (!secondFromSource && file2[0])
            SG->SetUserWorkedOnPanelPath(PANEL_TARGET); // also record the target panel

        return FALSE;
    }
    }
    return FALSE;
}

BOOL WINAPI
CPluginInterfaceForMenu::HelpForMenuItem(HWND parent, int id)
{
    int helpID = 0;
    switch (id)
    {
    case MID_COMPAREFILES:
        helpID = IDH_COMPAREFILES;
        break;
    }
    if (helpID != 0)
        SG->OpenHtmlHelp(parent, HHCDisplayContext, helpID, FALSE);
    return helpID != 0;
}

// ****************************************************************************
//
// CFilecompThread
//

unsigned
CFilecompThread::Body()
{
    CALL_STACK_MESSAGE1("CFilecompThread::CThreadBody()");
    BOOL succes = FALSE;
    BOOL dialogBox = TRUE;
    HWND wnd;
    CCompareOptions options = DefCompareOptions;

    if (Path1 == NULL || Path2 == NULL) // feature 102: heap buffers
    {
        Error(HWND(NULL), IDS_LOWMEM);
        goto LBODYFINAL;
    }

    if (!*Path1 || !*Path2 || !DontConfirmSelection && Configuration.ConfirmSelection)
    {
        CCompareFilesDialog* dlg = new CCompareFilesDialog(0, Path1, Path2, succes, &options);
        if (!dlg)
        {
            Error(HWND(NULL), IDS_LOWMEM);
            goto LBODYFINAL;
        }
        wnd = dlg->Create();
        if (!wnd)
        {
            TRACE_E("Nepodarilo se vytvorit CompareFilesDialog");
            goto LBODYFINAL;
        }
        SetForegroundWindow(wnd);
    }
    else
    {
        AddToHistory(Path2);
        AddToHistory(Path1);
        goto LLAUNCHFC;
    }

    while (1)
    {
        if (!MainWindowQueue.Add(new CWindowQueueItem(wnd)))
        {
            TRACE_E("Low memory");
            DestroyWindow(wnd);
            break;
        }

        // feature 102: a wide loop - a code-page loop converts every character typed into the
        // dialog's (Unicode) path fields to the code page, so a name outside it arrived as '?'
        // (the feature 093 rule).  The comparator window is a code-page window and still gets
        // its characters converted by DispatchMessageW, exactly as before; its menu is a
        // standard menu and the accelerators are virtual-key accelerators.
        MSG msg;
        while (IsWindow(wnd) && GetMessageW(&msg, NULL, 0, 0))
        {
            if (!dialogBox && !TranslateAcceleratorW(wnd, HAccels, &msg) ||
                dialogBox && !IsDialogMessageW(wnd, &msg))
            {
                TranslateMessage(&msg);
                DispatchMessageW(&msg);
            }
        }

        if (!dialogBox || !succes)
            break; // exit the message loop

    LLAUNCHFC:

        WINDOWPLACEMENT wp;
        wp.length = sizeof(wp);
        GetWindowPlacement(SG->GetMainWindowHWND(), &wp);
        // GetWindowPlacement respects the taskbar, so if the taskbar is at the top or left
        // the coordinates are offset by its size. Apply a correction.
        RECT monitorRect;
        RECT workRect;
        SG->MultiMonGetClipRectByRect(&wp.rcNormalPosition, &workRect, &monitorRect);
        OffsetRect(&wp.rcNormalPosition, workRect.left - monitorRect.left,
                   workRect.top - monitorRect.top);

        // if the main window is minimized, keep the File Comparator restored instead
        CMainWindow* win = new CMainWindow(Path1, Path2, &options,
                                           wp.showCmd == SW_SHOWMAXIMIZED ? SW_SHOWMAXIMIZED : SW_SHOW);
        if (!win)
        {
            Error(HWND(NULL), IDS_LOWMEM);
            break;
        }
        wnd = win->CreateEx(AlwaysOnTop ? WS_EX_TOPMOST : 0,
                            MAINWINDOW_CLASSNAME,
                            LoadStr(IDS_PLUGINNAME),
                            WS_OVERLAPPEDWINDOW | WS_VISIBLE | (wp.showCmd == SW_SHOWMAXIMIZED ? WS_MAXIMIZE : 0),
                            wp.rcNormalPosition.left,
                            wp.rcNormalPosition.top,
                            wp.rcNormalPosition.right - wp.rcNormalPosition.left,
                            wp.rcNormalPosition.bottom - wp.rcNormalPosition.top,
                            NULL, // parent
                            LoadMenu(HLanguage, MAKEINTRESOURCE(IDM_MENU)),
                            DLLInstance,
                            win);
        if (!wnd)
        {
            TRACE_E("Nepodarilo se vytvorit MainWindow, GetLastError() = " << GetLastError());
            break;
        }
        SG->ThemeApplyToTopLevel(wnd); // feature 036: dark title bar
        dialogBox = FALSE;
    }
LBODYFINAL:
    if (*ReleaseEvent)
    {
        // allow filecomp.exe to continue
        HANDLE event = OpenEvent(EVENT_MODIFY_STATE, FALSE, ReleaseEvent);
        SetEvent(event);
        CloseHandle(event);
    }

    return 0;
}
