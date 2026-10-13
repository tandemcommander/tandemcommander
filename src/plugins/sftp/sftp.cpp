// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"
#include "sftp.h"
#include "session.h"
#include "hostkeys.h"
#include "listing.h"
#include "dialogs.h"
#include "logs.h"
#include "fs.h"

// ---------------------------------------------------------------------------
// globals
// ---------------------------------------------------------------------------

HINSTANCE DLLInstance = NULL;
HINSTANCE HLanguage = NULL;

// required by dbg.h / spl_com.h (declared extern there, defined by each plugin)
CSalamanderDebugAbstract* SalamanderDebug = NULL;
int SalamanderVersion = 0;

CSalamanderGeneralAbstract* SalamanderGeneral = NULL;
CSalamanderGUIAbstract* SalamanderGUI = NULL;

char AssignedFSName[MAX_PATH] = "sftp";
int AssignedFSNameLen = 4;

HICON SFTPIcon = NULL;
HICON SFTPLogIcon = NULL;

const char* LOW_MEMORY = "Out of memory.";

CPluginInterface PluginInterface;
CPluginInterfaceForMenuExt InterfaceForMenuExt;
CSFTPConfig Config;

// version 2 (feature 053): the quick-connect entry is no longer persisted. A
// configuration written by an older version still carries its subtree - possibly
// including a saved password - so loading version < 2 schedules a one-time purge.
#define CURRENT_CONFIG_VERSION 2

// feature 053: set when a pre-version-2 configuration was loaded; cleared once the
// stale quick-connect subtree has been deleted (see PurgeQuickConnectIfNeeded)
static BOOL PurgeQuickConnectPending = FALSE;

// ---------------------------------------------------------------------------
// config registry value names
// ---------------------------------------------------------------------------

static const char* CFG_VERSION = "Version";
static const char* CFG_CONNTIMEOUT = "Connect Timeout";
static const char* CFG_OPTIMEOUT = "Operation Timeout";
static const char* CFG_KASEND = "Keep Alive Send Every";
static const char* CFG_KASTOP = "Keep Alive Stop After";
static const char* CFG_RETRIES = "Connect Retries";
static const char* CFG_RETRYDELAY = "Delay Connect Retries";
static const char* CFG_COLVIEW = "Column View";
static const char* CFG_SHOWOCTAL = "Show Octal";
static const char* CFG_RESUMEOVERLAP = "Resume Overlap";
static const char* CFG_RESUMEMIN = "Resume Min File Size";
static const char* CFG_LOGGING = "Enable Logging";
static const char* CFG_LOGMAX = "Log Max Size";
static const char* CFG_LASTBOOKMARK = "Last Bookmark";

static const char* CFG_BOOKMARKS = "Bookmarks";
static const char* CFG_QUICKCONNECT = "QuickConnect"; // feature 017: persist the quick-connect entry (incl. its saved password)
static const char* CFG_KNOWNHOSTS = "Known Hosts";

static const char* SRV_NAME = "Name";
static const char* SRV_ADDRESS = "Address";
static const char* SRV_PORT = "Port";
static const char* SRV_USER = "User";
static const char* SRV_AUTH = "Auth Method";
static const char* SRV_PASSWORDE = "PasswordE";
static const char* SRV_PASSWORDS = "PasswordS";
static const char* SRV_SAVEPWD = "Save Password";
static const char* SRV_KEYFILE = "Key File";
static const char* SRV_PASSPHRASEE = "PassphraseE";
static const char* SRV_PASSPHRASES = "PassphraseS";
static const char* SRV_SAVEPASS = "Save Passphrase";
static const char* SRV_INITPATH = "Initial Path";
static const char* SRV_TARGETPANEL = "Target Panel Path";
static const char* SRV_KACOMPRESS = "Use Compression";

static const char* HK_HOST = "Host";
static const char* HK_PORT = "Port";
static const char* HK_TYPE = "Key Type";
static const char* HK_BLOB = "Public Key";
static const char* HK_FINGERPRINT = "Fingerprint";

// ---------------------------------------------------------------------------
// LoadStr / entry
// ---------------------------------------------------------------------------

char* LoadStr(int resID)
{
    return SalamanderGeneral->LoadStr(HLanguage, resID);
}

const char* LoadStrU8(int resID) // feature 130, see sftp.h
{
    return SplLoadStrU8(SalamanderGeneral, HLanguage, resID);
}

BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved)
{
    if (fdwReason == DLL_PROCESS_ATTACH)
    {
        DLLInstance = hinstDLL;
        INITCOMMONCONTROLSEX initCtrls;
        initCtrls.dwSize = sizeof(INITCOMMONCONTROLSEX);
        initCtrls.dwICC = ICC_BAR_CLASSES | ICC_LISTVIEW_CLASSES;
        InitCommonControlsEx(&initCtrls);
    }
    return TRUE;
}

int WINAPI SalamanderPluginGetReqVer()
{
    return LAST_VERSION_OF_SALAMANDER;
}

CPluginInterfaceAbstract* WINAPI SalamanderPluginEntry(CSalamanderPluginEntryAbstract* salamander)
{
    SalamanderDebug = salamander->GetSalamanderDebug();
    SalamanderVersion = salamander->GetVersion();
    HANDLES_CAN_USE_TRACE();
    CALL_STACK_MESSAGE1("SalamanderPluginEntry()");

    if (SalamanderVersion < LAST_VERSION_OF_SALAMANDER)
    {
        MessageBox(salamander->GetParentWindow(), REQUIRE_LAST_VERSION_OF_SALAMANDER,
                   "SFTP Client" /* do not translate */, MB_OK | MB_ICONERROR);
        return NULL;
    }

    HLanguage = salamander->LoadLanguageModule(salamander->GetParentWindow(), "SFTP Client" /* do not translate */);
    if (HLanguage == NULL)
        return NULL;

    SalamanderGeneral = salamander->GetSalamanderGeneral();
    SalamanderGUI = salamander->GetSalamanderGUI();

    if (!InitSSH())
    {
        MessageBox(salamander->GetParentWindow(), "Cannot initialize the SSH/Winsock subsystem.",
                   "SFTP Client", MB_OK | MB_ICONERROR);
        return NULL;
    }

    salamander->SetBasicPluginData(LoadStr(IDS_PLUGINNAME),
                                   FUNCTION_CONFIGURATION | FUNCTION_LOADSAVECONFIGURATION | FUNCTION_FILESYSTEM,
                                   VERSINFO_VERSION_NO_PLATFORM, VERSINFO_COPYRIGHT,
                                   LoadStr(IDS_PLUGINDESCR), "SFTP", NULL, "sftp");

    SalamanderGeneral->SetPluginUsesPasswordManager();
    SalamanderGeneral->GetPluginFSName(AssignedFSName, 0);
    AssignedFSNameLen = (int)strlen(AssignedFSName);

    return &PluginInterface;
}

// ---------------------------------------------------------------------------
// CSFTPServer
// ---------------------------------------------------------------------------

CSFTPServer::CSFTPServer()
{
    ItemName = NULL;
    Address = NULL;
    Port = SFTP_DEFAULT_PORT;
    UserName = NULL;
    AuthMethod = saPassword;
    EncryptedPassword = NULL;
    EncryptedPasswordSize = 0;
    SavePassword = FALSE;
    KeyFile = NULL;
    EncryptedPassphrase = NULL;
    EncryptedPassphraseSize = 0;
    SavePassphrase = FALSE;
    InitialPath = NULL;
    TargetPanelPath = NULL;
    KeepAliveSendEvery = 0;
    KeepAliveStopAfter = 0;
    UseCompression = FALSE;
}

CSFTPServer::~CSFTPServer()
{
    Clear();
}

// feature 053: Clear() frees the strings and blobs but leaves the scalars alone,
// so an entry it "cleared" still carries the last port, auth method and
// save-secret flags. Reset() is what the transient quick-connect entry needs: the
// constructor's state, i.e. genuinely empty.
void CSFTPServer::Reset()
{
    Clear();
    Port = SFTP_DEFAULT_PORT;
    AuthMethod = saPassword;
    SavePassword = FALSE;
    SavePassphrase = FALSE;
    KeepAliveSendEvery = 0;
    KeepAliveStopAfter = 0;
    UseCompression = FALSE;
}

void CSFTPServer::Clear()
{
    if (ItemName != NULL)
    {
        free(ItemName);
        ItemName = NULL;
    }
    if (Address != NULL)
    {
        free(Address);
        Address = NULL;
    }
    if (UserName != NULL)
    {
        free(UserName);
        UserName = NULL;
    }
    if (KeyFile != NULL)
    {
        free(KeyFile);
        KeyFile = NULL;
    }
    if (InitialPath != NULL)
    {
        free(InitialPath);
        InitialPath = NULL;
    }
    if (TargetPanelPath != NULL)
    {
        free(TargetPanelPath);
        TargetPanelPath = NULL;
    }
    if (EncryptedPassword != NULL)
    {
        free(EncryptedPassword);
        EncryptedPassword = NULL;
    }
    EncryptedPasswordSize = 0;
    if (EncryptedPassphrase != NULL)
    {
        free(EncryptedPassphrase);
        EncryptedPassphrase = NULL;
    }
    EncryptedPassphraseSize = 0;
}

BOOL CSFTPServer::SetString(char** target, const char* value)
{
    if (*target != NULL)
        free(*target);
    if (value == NULL)
    {
        *target = NULL;
        return TRUE;
    }
    *target = _strdup(value);
    return *target != NULL;
}

BOOL CSFTPServer::SetBlob(BYTE** target, int* targetSize, const BYTE* data, int size)
{
    if (*target != NULL)
        free(*target);
    *target = NULL;
    *targetSize = 0;
    if (data == NULL || size == 0)
        return TRUE;
    *target = (BYTE*)malloc(size);
    if (*target == NULL)
        return FALSE;
    memcpy(*target, data, size);
    *targetSize = size;
    return TRUE;
}

BOOL CSFTPServer::Set(const char* itemName, const char* address, int port, const char* user)
{
    if (!SetString(&ItemName, itemName) || !SetString(&Address, address) || !SetString(&UserName, user))
        return FALSE;
    Port = port;
    return TRUE;
}

BOOL CSFTPServer::CopyFrom(const CSFTPServer* src)
{
    Clear();
    if (!SetString(&ItemName, src->ItemName) || !SetString(&Address, src->Address) ||
        !SetString(&UserName, src->UserName) || !SetString(&KeyFile, src->KeyFile) ||
        !SetString(&InitialPath, src->InitialPath) || !SetString(&TargetPanelPath, src->TargetPanelPath))
        return FALSE;
    Port = src->Port;
    AuthMethod = src->AuthMethod;
    SavePassword = src->SavePassword;
    SavePassphrase = src->SavePassphrase;
    KeepAliveSendEvery = src->KeepAliveSendEvery;
    KeepAliveStopAfter = src->KeepAliveStopAfter;
    UseCompression = src->UseCompression;
    if (!SetBlob(&EncryptedPassword, &EncryptedPasswordSize, src->EncryptedPassword, src->EncryptedPasswordSize) ||
        !SetBlob(&EncryptedPassphrase, &EncryptedPassphraseSize, src->EncryptedPassphrase, src->EncryptedPassphraseSize))
        return FALSE;
    return TRUE;
}

// re-encrypt one blob for the master-password transition
static void ReEncryptBlob(HWND parent, BYTE** blob, int* blobSize, BOOL encrypt)
{
    if (*blob == NULL || *blobSize == 0)
        return;
    CSalamanderPasswordManagerAbstract* pm = SalamanderGeneral->GetSalamanderPasswordManager();
    if (pm == NULL)
        return;
    char* plain = NULL;
    if (!pm->DecryptPassword(*blob, *blobSize, &plain) || plain == NULL)
        return;
    BYTE* newBlob = NULL;
    int newSize = 0;
    if (pm->EncryptPassword(plain, &newBlob, &newSize, encrypt) && newBlob != NULL)
    {
        free(*blob);
        // password-manager buffer lives on Salamander's heap
        *blob = (BYTE*)malloc(newSize);
        if (*blob != NULL)
        {
            memcpy(*blob, newBlob, newSize);
            *blobSize = newSize;
        }
        else
            *blobSize = 0; // keep size consistent with the now-NULL blob on OOM
        SalamanderGeneral->Free(newBlob);
    }
    SecureZeroMemory(plain, strlen(plain));
    SalamanderGeneral->Free(plain);
}

void CSFTPServerList::EncryptPasswords(HWND parent, BOOL encrypt)
{
    for (int i = 0; i < Count; i++)
    {
        CSFTPServer* s = At(i);
        ReEncryptBlob(parent, &s->EncryptedPassword, &s->EncryptedPasswordSize, encrypt);
        ReEncryptBlob(parent, &s->EncryptedPassphrase, &s->EncryptedPassphraseSize, encrypt);
    }
    // feature 053: quick connect never holds a secret blob any more, so there is
    // nothing here to re-encrypt
}

// ---------------------------------------------------------------------------
// CSFTPConfig
// ---------------------------------------------------------------------------

CSFTPConfig::CSFTPConfig()
{
    memset(&ConnectDlgPlacement, 0, sizeof(ConnectDlgPlacement));
    memset(&LogsDlgPlacement, 0, sizeof(LogsDlgPlacement));
    SetDefaults();
}

void CSFTPConfig::SetDefaults()
{
    Version = CURRENT_CONFIG_VERSION;
    ConnectTimeout = 20;
    OperationTimeout = 30;
    KeepAliveSendEvery = 60;
    KeepAliveStopAfter = 30;
    ConnectRetries = 3;
    RetryDelay = 10;
    ColumnView = cvUnixRights;
    ShowOctal = TRUE;
    ResumeOverlap = 4096;
    ResumeMinFileSize = 32768;
    EnableLogging = TRUE;
    LogMaxSize = 256;
    LastBookmark = 0;
}

// ---------------------------------------------------------------------------
// registry helpers
// ---------------------------------------------------------------------------

static void RegGetDword(CSalamanderRegistryAbstract* reg, HKEY key, const char* name, int* value)
{
    DWORD v;
    if (reg->GetValue(key, name, REG_DWORD, &v, sizeof(v)))
        *value = (int)v;
}

static void RegSetDword(CSalamanderRegistryAbstract* reg, HKEY key, const char* name, int value)
{
    DWORD v = (DWORD)value;
    reg->SetValue(key, name, REG_DWORD, &v, sizeof(v));
}

static void RegGetStr(CSalamanderRegistryAbstract* reg, HKEY key, const char* name, char** target)
{
    DWORD size = 0;
    if (reg->GetSize(key, name, REG_SZ, size) && size > 0)
    {
        char* buf = (char*)malloc(size);
        if (buf != NULL && reg->GetValue(key, name, REG_SZ, buf, size))
        {
            if (*target != NULL)
                free(*target);
            *target = buf;
        }
        else if (buf != NULL)
            free(buf);
    }
}

static void RegSetStr(CSalamanderRegistryAbstract* reg, HKEY key, const char* name, const char* value)
{
    if (value != NULL && value[0] != 0)
        reg->SetValue(key, name, REG_SZ, value, (DWORD)strlen(value) + 1);
}

static void RegGetBlob(CSalamanderRegistryAbstract* reg, HKEY key, const char* name, BYTE** blob, int* blobSize)
{
    DWORD size = 0;
    if (reg->GetSize(key, name, REG_BINARY, size) && size > 0)
    {
        BYTE* buf = (BYTE*)malloc(size);
        if (buf != NULL && reg->GetValue(key, name, REG_BINARY, buf, size))
        {
            if (*blob != NULL)
                free(*blob);
            *blob = buf;
            *blobSize = size;
        }
        else if (buf != NULL)
            free(buf);
    }
}

static void RegSetBlob(CSalamanderRegistryAbstract* reg, HKEY key, const char* name, const BYTE* blob, int blobSize)
{
    if (blob != NULL && blobSize > 0)
        reg->SetValue(key, name, REG_BINARY, blob, blobSize);
}

static void LoadServer(CSalamanderRegistryAbstract* reg, HKEY key, CSFTPServer* srv)
{
    RegGetStr(reg, key, SRV_NAME, &srv->ItemName);
    RegGetStr(reg, key, SRV_ADDRESS, &srv->Address);
    RegGetDword(reg, key, SRV_PORT, &srv->Port);
    RegGetStr(reg, key, SRV_USER, &srv->UserName);
    RegGetDword(reg, key, SRV_AUTH, &srv->AuthMethod);
    int sp = 0;
    RegGetDword(reg, key, SRV_SAVEPWD, &sp);
    srv->SavePassword = sp;
    int spp = 0;
    RegGetDword(reg, key, SRV_SAVEPASS, &spp);
    srv->SavePassphrase = spp;
    RegGetBlob(reg, key, SRV_PASSWORDE, &srv->EncryptedPassword, &srv->EncryptedPasswordSize);
    if (srv->EncryptedPassword == NULL)
        RegGetBlob(reg, key, SRV_PASSWORDS, &srv->EncryptedPassword, &srv->EncryptedPasswordSize);
    RegGetBlob(reg, key, SRV_PASSPHRASEE, &srv->EncryptedPassphrase, &srv->EncryptedPassphraseSize);
    if (srv->EncryptedPassphrase == NULL)
        RegGetBlob(reg, key, SRV_PASSPHRASES, &srv->EncryptedPassphrase, &srv->EncryptedPassphraseSize);
    RegGetStr(reg, key, SRV_KEYFILE, &srv->KeyFile);
    RegGetStr(reg, key, SRV_INITPATH, &srv->InitialPath);
    RegGetStr(reg, key, SRV_TARGETPANEL, &srv->TargetPanelPath);
    int uc = 0;
    RegGetDword(reg, key, SRV_KACOMPRESS, &uc);
    srv->UseCompression = uc;
}

static void SaveServer(CSalamanderRegistryAbstract* reg, HKEY key, const CSFTPServer* srv)
{
    RegSetStr(reg, key, SRV_NAME, srv->ItemName);
    RegSetStr(reg, key, SRV_ADDRESS, srv->Address);
    RegSetDword(reg, key, SRV_PORT, srv->Port);
    RegSetStr(reg, key, SRV_USER, srv->UserName);
    RegSetDword(reg, key, SRV_AUTH, srv->AuthMethod);
    RegSetDword(reg, key, SRV_SAVEPWD, srv->SavePassword);
    RegSetDword(reg, key, SRV_SAVEPASS, srv->SavePassphrase);
    if (srv->SavePassword && srv->EncryptedPassword != NULL)
    {
        CSalamanderPasswordManagerAbstract* pm = SalamanderGeneral->GetSalamanderPasswordManager();
        BOOL enc = pm != NULL && pm->IsPasswordEncrypted(srv->EncryptedPassword, srv->EncryptedPasswordSize);
        RegSetBlob(reg, key, enc ? SRV_PASSWORDE : SRV_PASSWORDS, srv->EncryptedPassword, srv->EncryptedPasswordSize);
    }
    if (srv->SavePassphrase && srv->EncryptedPassphrase != NULL)
    {
        CSalamanderPasswordManagerAbstract* pm = SalamanderGeneral->GetSalamanderPasswordManager();
        BOOL enc = pm != NULL && pm->IsPasswordEncrypted(srv->EncryptedPassphrase, srv->EncryptedPassphraseSize);
        RegSetBlob(reg, key, enc ? SRV_PASSPHRASEE : SRV_PASSPHRASES, srv->EncryptedPassphrase, srv->EncryptedPassphraseSize);
    }
    RegSetStr(reg, key, SRV_KEYFILE, srv->KeyFile);
    RegSetStr(reg, key, SRV_INITPATH, srv->InitialPath);
    RegSetStr(reg, key, SRV_TARGETPANEL, srv->TargetPanelPath);
    RegSetDword(reg, key, SRV_KACOMPRESS, srv->UseCompression);
}

// ---------------------------------------------------------------------------
// CPluginInterface
// ---------------------------------------------------------------------------

void WINAPI CPluginInterface::About(HWND parent)
{
    char buf[1000];
    _snprintf_s(buf, _TRUNCATE, LoadStr(IDS_ABOUT), VERSINFO_VERSION, VERSINFO_COPYRIGHT);
    SalamanderGeneral->SalMessageBox(parent, buf, LoadStr(IDS_ABOUTPLUGINTITLE), MB_OK | MB_ICONINFORMATION);
}

// feature 053: delete a quick-connect subtree left behind by an older version.
// It cannot be done in LoadConfiguration (that key is opened read-only) and
// SaveConfiguration is not guaranteed to run - the application calls it on exit
// only when auto-save is enabled - so the purge is forced through
// CallLoadOrSaveConfiguration, which hands the callback a writable key.
static void WINAPI PurgeQuickConnectCallback(BOOL load, HKEY regKey,
                                             CSalamanderRegistryAbstract* registry, void* param)
{
    if (load || regKey == NULL)
        return;
    registry->DeleteKey(regKey, CFG_QUICKCONNECT);
    RegSetDword(registry, regKey, CFG_VERSION, CURRENT_CONFIG_VERSION);
}

// Runs once per plugin load, and only for a configuration written before the
// quick-connect entry became transient. Bounded by the plugin actually being
// loaded - nothing plugin-side can act earlier than that.
static void PurgeQuickConnectIfNeeded()
{
    if (!PurgeQuickConnectPending)
        return;
    PurgeQuickConnectPending = FALSE;
    SalamanderGeneral->CallLoadOrSaveConfiguration(FALSE, PurgeQuickConnectCallback, NULL);
}

BOOL WINAPI CPluginInterface::Release(HWND parent, BOOL force)
{
    // purge cached view copies
    char uniqueFileName[MAX_PATH];
    _snprintf_s(uniqueFileName, _TRUNCATE, "%s:", AssignedFSName);
    SalamanderGeneral->RemoveFilesFromCache(uniqueFileName);
    ReleaseSSH();
    return TRUE;
}

void WINAPI CPluginInterface::LoadConfiguration(HWND parent, HKEY regKey, CSalamanderRegistryAbstract* registry)
{
    Config.SetDefaults();
    if (regKey == NULL)
        return;

    RegGetDword(registry, regKey, CFG_VERSION, &Config.Version);
    RegGetDword(registry, regKey, CFG_CONNTIMEOUT, &Config.ConnectTimeout);
    RegGetDword(registry, regKey, CFG_OPTIMEOUT, &Config.OperationTimeout);
    RegGetDword(registry, regKey, CFG_KASEND, &Config.KeepAliveSendEvery);
    RegGetDword(registry, regKey, CFG_KASTOP, &Config.KeepAliveStopAfter);
    RegGetDword(registry, regKey, CFG_RETRIES, &Config.ConnectRetries);
    RegGetDword(registry, regKey, CFG_RETRYDELAY, &Config.RetryDelay);
    RegGetDword(registry, regKey, CFG_COLVIEW, &Config.ColumnView);
    int so = Config.ShowOctal;
    RegGetDword(registry, regKey, CFG_SHOWOCTAL, &so);
    Config.ShowOctal = so;
    RegGetDword(registry, regKey, CFG_RESUMEOVERLAP, &Config.ResumeOverlap);
    RegGetDword(registry, regKey, CFG_RESUMEMIN, &Config.ResumeMinFileSize);
    int el = Config.EnableLogging;
    RegGetDword(registry, regKey, CFG_LOGGING, &el);
    Config.EnableLogging = el;
    RegGetDword(registry, regKey, CFG_LOGMAX, &Config.LogMaxSize);
    RegGetDword(registry, regKey, CFG_LASTBOOKMARK, &Config.LastBookmark);

    // bookmarks
    HKEY bmKey;
    if (registry->OpenKey(regKey, CFG_BOOKMARKS, bmKey))
    {
        for (int i = 1;; i++)
        {
            char sub[16];
            _snprintf_s(sub, _TRUNCATE, "%d", i);
            HKEY srvKey;
            if (!registry->OpenKey(bmKey, sub, srvKey))
                break;
            CSFTPServer* srv = new CSFTPServer;
            if (srv != NULL)
            {
                LoadServer(registry, srvKey, srv);
                Config.Bookmarks.Add(srv);
                if (!Config.Bookmarks.IsGood())
                {
                    Config.Bookmarks.ResetState();
                    delete srv;
                }
            }
            registry->CloseKey(srvKey);
        }
        registry->CloseKey(bmKey);
    }

    // feature 053: the quick-connect entry is deliberately NOT loaded - it is
    // transient (see CSFTPConfig::QuickConnect). A stale subtree from an earlier
    // version is not read at all, it is deleted; that cannot happen here because
    // 'regKey' is opened read-only, so the purge lives in SaveConfiguration and
    // in the one-time upgrade below.
    if (Config.Version < 2)
        PurgeQuickConnectPending = TRUE; // feature 053: drop the old subtree, incl. any saved secret

    // known hosts
    HKEY hkKey;
    if (registry->OpenKey(regKey, CFG_KNOWNHOSTS, hkKey))
    {
        for (int i = 1;; i++)
        {
            char sub[16];
            _snprintf_s(sub, _TRUNCATE, "%d", i);
            HKEY oneKey;
            if (!registry->OpenKey(hkKey, sub, oneKey))
                break;
            CSFTPHostKey* k = new CSFTPHostKey;
            if (k != NULL)
            {
                RegGetStr(registry, oneKey, HK_HOST, &k->Host);
                RegGetDword(registry, oneKey, HK_PORT, &k->Port);
                RegGetStr(registry, oneKey, HK_TYPE, &k->KeyType);
                RegGetStr(registry, oneKey, HK_BLOB, &k->KeyBlobB64);
                RegGetStr(registry, oneKey, HK_FINGERPRINT, &k->FingerprintSHA256);
                HostKeys.Add(k);
                if (!HostKeys.IsGood())
                {
                    HostKeys.ResetState();
                    delete k;
                }
            }
            registry->CloseKey(oneKey);
        }
        registry->CloseKey(hkKey);
    }
}

void WINAPI CPluginInterface::SaveConfiguration(HWND parent, HKEY regKey, CSalamanderRegistryAbstract* registry)
{
    RegSetDword(registry, regKey, CFG_VERSION, CURRENT_CONFIG_VERSION);
    RegSetDword(registry, regKey, CFG_CONNTIMEOUT, Config.ConnectTimeout);
    RegSetDword(registry, regKey, CFG_OPTIMEOUT, Config.OperationTimeout);
    RegSetDword(registry, regKey, CFG_KASEND, Config.KeepAliveSendEvery);
    RegSetDword(registry, regKey, CFG_KASTOP, Config.KeepAliveStopAfter);
    RegSetDword(registry, regKey, CFG_RETRIES, Config.ConnectRetries);
    RegSetDword(registry, regKey, CFG_RETRYDELAY, Config.RetryDelay);
    RegSetDword(registry, regKey, CFG_COLVIEW, Config.ColumnView);
    RegSetDword(registry, regKey, CFG_SHOWOCTAL, Config.ShowOctal);
    RegSetDword(registry, regKey, CFG_RESUMEOVERLAP, Config.ResumeOverlap);
    RegSetDword(registry, regKey, CFG_RESUMEMIN, Config.ResumeMinFileSize);
    RegSetDword(registry, regKey, CFG_LOGGING, Config.EnableLogging);
    RegSetDword(registry, regKey, CFG_LOGMAX, Config.LogMaxSize);
    RegSetDword(registry, regKey, CFG_LASTBOOKMARK, Config.LastBookmark);

    HKEY bmKey;
    registry->DeleteKey(regKey, CFG_BOOKMARKS);
    if (registry->CreateKey(regKey, CFG_BOOKMARKS, bmKey))
    {
        for (int i = 0; i < Config.Bookmarks.Count; i++)
        {
            char sub[16];
            _snprintf_s(sub, _TRUNCATE, "%d", i + 1);
            HKEY srvKey;
            if (registry->CreateKey(bmKey, sub, srvKey))
            {
                SaveServer(registry, srvKey, Config.Bookmarks[i]);
                registry->CloseKey(srvKey);
            }
        }
        registry->CloseKey(bmKey);
    }

    // feature 053: quick connect is transient - it is never persisted, and above
    // all never stores a password (feature 017 did both; that is reversed here).
    // This delete is therefore not a preparation for a write but the purge of
    // whatever an earlier version left behind, which is why it has no companion
    // CreateKey. See specs/053-sftp-connect-dialog/contracts/.
    registry->DeleteKey(regKey, CFG_QUICKCONNECT);

    HKEY hkKey;
    registry->DeleteKey(regKey, CFG_KNOWNHOSTS);
    if (registry->CreateKey(regKey, CFG_KNOWNHOSTS, hkKey))
    {
        for (int i = 0; i < HostKeys.Count; i++)
        {
            char sub[16];
            _snprintf_s(sub, _TRUNCATE, "%d", i + 1);
            HKEY oneKey;
            if (registry->CreateKey(hkKey, sub, oneKey))
            {
                CSFTPHostKey* k = HostKeys[i];
                RegSetStr(registry, oneKey, HK_HOST, k->Host);
                RegSetDword(registry, oneKey, HK_PORT, k->Port);
                RegSetStr(registry, oneKey, HK_TYPE, k->KeyType);
                RegSetStr(registry, oneKey, HK_BLOB, k->KeyBlobB64);
                RegSetStr(registry, oneKey, HK_FINGERPRINT, k->FingerprintSHA256);
                registry->CloseKey(oneKey);
            }
        }
        registry->CloseKey(hkKey);
    }
}

void WINAPI CPluginInterface::Configuration(HWND parent)
{
    ShowConfigDialog(parent);
}

void WINAPI CPluginInterface::Connect(HWND parent, CSalamanderConnectAbstract* salamander)
{
    salamander->SetChangeDriveMenuItem(LoadStr(IDS_SFTPCHNGDRVITEM), 0);
    salamander->SetPluginIcon(0);
    salamander->SetPluginMenuAndToolbarIcon(0);

    salamander->AddMenuItem(-1, LoadStr(IDS_MENU_CONNECT), SALHOTKEY('S', HOTKEYF_CONTROL | HOTKEYF_SHIFT),
                            SFTPCMD_CONNECT, FALSE, MENU_EVENT_TRUE, 0, MENU_SKILLLEVEL_ALL);
    salamander->AddMenuItem(-1, LoadStr(IDS_MENU_ORGANIZEBOOKMARKS), 0, SFTPCMD_ORGANIZEBOOKMARKS, FALSE,
                            MENU_EVENT_TRUE, 0, MENU_SKILLLEVEL_ALL);
    salamander->AddMenuItem(-1, LoadStr(IDS_MENU_CREATESYMLINK), 0, SFTPCMD_CREATESYMLINK, FALSE,
                            MENU_EVENT_THIS_PLUGIN_FS, 0, MENU_SKILLLEVEL_ALL);
    salamander->AddMenuItem(-1, LoadStr(IDS_MENU_SHOWLOGS), 0, SFTPCMD_SHOWLOGS, FALSE,
                            MENU_EVENT_TRUE, 0, MENU_SKILLLEVEL_ALL);

    // feature 053: Connect() runs after LoadConfiguration, on the main thread, and
    // once per plugin load - the first point at which the stale quick-connect
    // subtree can be deleted
    PurgeQuickConnectIfNeeded();
}

void WINAPI CPluginInterface::ReleasePluginDataInterface(CPluginDataInterfaceAbstract* pluginData)
{
    if (pluginData != NULL)
        delete (CSFTPListingData*)pluginData;
}

CPluginInterfaceForMenuExtAbstract* WINAPI CPluginInterface::GetInterfaceForMenuExt()
{
    return &InterfaceForMenuExt;
}

CPluginInterfaceForFSAbstract* WINAPI CPluginInterface::GetInterfaceForFS()
{
    return &InterfaceForFS;
}

void WINAPI CPluginInterface::Event(int event, DWORD param)
{
}

void WINAPI CPluginInterface::PasswordManagerEvent(HWND parent, int event)
{
    // re-encrypt stored secrets on master-password create/change/remove
    BOOL encrypt = (event == PME_MASTERPASSWORDCREATED || event == PME_MASTERPASSWORDCHANGED);
    Config.Bookmarks.EncryptPasswords(parent, encrypt);
}

// ---------------------------------------------------------------------------
// CPluginInterfaceForMenuExt
// ---------------------------------------------------------------------------

DWORD WINAPI CPluginInterfaceForMenuExt::GetMenuItemState(int id, DWORD eventMask)
{
    return MENU_ITEM_STATE_ENABLED;
}

BOOL WINAPI CPluginInterfaceForMenuExt::ExecuteMenuItem(CSalamanderForOperationsAbstract* salamander, HWND parent,
                                                        int id, DWORD eventMask)
{
    switch (id)
    {
    case SFTPCMD_CONNECT:
        ConnectSFTPServer(parent, PANEL_SOURCE);
        return FALSE;
    case SFTPCMD_ORGANIZEBOOKMARKS:
        ShowConnectDialog(parent, TRUE, NULL);
        return FALSE;
    case SFTPCMD_SHOWLOGS:
        ShowLogsDialog(parent, -1);
        return FALSE;
    case SFTPCMD_CREATESYMLINK:
    {
        // handled contextually by the active FS
        SalamanderGeneral->SalMessageBox(parent,
                                         "Select the SFTP panel and use the Create Symbolic Link command from there.",
                                         LoadStr(IDS_PLUGINNAME), MB_OK | MB_ICONINFORMATION);
        return FALSE;
    }
    case SFTPCMD_DEFERREDCD:
        ExecuteDeferredCd(); // deferred path change from ExecuteCommandLine (safe here)
        return FALSE;
    }
    return FALSE;
}
