// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include <winhttp.h>
#include <wintrust.h>
#include <softpub.h>
#include <bcrypt.h>
#include <tlhelp32.h>
#include <netlistmgr.h>

#include "mainwnd.h"
#include "updinstall.h"
#include "updhttp.h"

// feature 420: wintrust.dll and bcrypt.dll are delay-loaded (sal_base.props); they are loaded
// only when a downloaded installer is verified
#pragma comment(lib, "wintrust.lib")
#pragma comment(lib, "crypt32.lib")
#pragma comment(lib, "bcrypt.lib")
#pragma comment(lib, "version.lib")

// stored values (contracts/stored-state.md), in the key of feature 123
static const WCHAR* const UPDINST_VAL_LEVEL = L"Update Level";
static const WCHAR* const UPDINST_VAL_VERSION = L"Install Version";
static const WCHAR* const UPDINST_VAL_DIGEST = L"Install Digest";
static const WCHAR* const UPDINST_VAL_SOURCE = L"Install Source";
static const WCHAR* const UPDINST_VAL_TEST = L"Install Test";
static const WCHAR* const UPDINST_VAL_LAUNCHES = L"Install Launches";

// the uninstall entry of the installer (setup/tandemcommander.iss, AppId)
static const WCHAR* const UPDINST_UNINSTALL_KEY =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{35C0B0DC-DB73-429C-AAA8-FBC41C937F66}_is1";

// the download (contracts/download-and-verification.md D2)
#define UPDDL_STEP_MS 30000        // no progress of one step for this long fails the download
#define UPDDL_TOTAL_MS (15 * 60000) // the whole download
#define UPDDL_BUFFER (64 * 1024)

#define UPDINST_MAX_FOLDER 1024 // characters of the updates folder (a longer one is refused)

//
// ****************************************************************************
// registry
//

static BOOL UpdiReadDword(HKEY key, const WCHAR* name, DWORD* value)
{
    DWORD type = 0, data = 0, size = sizeof(data);
    if (NOHANDLES(RegQueryValueExW(key, name, NULL, &type, (BYTE*)&data, &size)) != ERROR_SUCCESS ||
        type != REG_DWORD || size != sizeof(data))
        return FALSE;
    *value = data;
    return TRUE;
}

// a short printable ASCII text value; anything else is "absent"
static BOOL UpdiReadText(HKEY key, const WCHAR* name, char* text, int textSize)
{
    WCHAR data[80];
    DWORD type = 0;
    DWORD size = sizeof(data) - sizeof(WCHAR);
    if (NOHANDLES(RegQueryValueExW(key, name, NULL, &type, (BYTE*)data, &size)) != ERROR_SUCCESS ||
        type != REG_SZ || (size % sizeof(WCHAR)) != 0)
        return FALSE;
    int len = (int)(size / sizeof(WCHAR));
    data[len] = 0;
    len = (int)wcslen(data);
    if (len >= textSize)
        return FALSE;
    for (int i = 0; i < len; i++)
    {
        if (data[i] < 0x20 || data[i] >= 0x7F)
            return FALSE;
        text[i] = (char)data[i];
    }
    text[len] = 0;
    return TRUE;
}

static void UpdiWriteText(HKEY key, const WCHAR* name, const char* text)
{
    WCHAR data[80];
    int len = (int)strlen(text);
    if (len >= _countof(data))
        return;
    for (int i = 0; i <= len; i++)
        data[i] = (WCHAR)(unsigned char)text[i];
    NOHANDLES(RegSetValueExW(key, name, 0, REG_SZ, (const BYTE*)data, (DWORD)((len + 1) * sizeof(WCHAR))));
}

static void UpdiWriteDword(HKEY key, const WCHAR* name, DWORD value)
{
    NOHANDLES(RegSetValueExW(key, name, 0, REG_DWORD, (const BYTE*)&value, sizeof(value)));
}

CSalUpdLevel UpdInstall_GetLevel()
{
    HKEY key;
    DWORD value = 0;
    BOOL present = FALSE;
    if (UpdateCheck_OpenStateKey(FALSE, &key))
    {
        present = UpdiReadDword(key, UPDINST_VAL_LEVEL, &value);
        NOHANDLES(RegCloseKey(key));
    }
    return SalUpdLevelFromStored(present, value);
}

void UpdInstall_SetLevel(CSalUpdLevel level)
{
    HKEY key;
    if (UpdateCheck_OpenStateKey(TRUE, &key))
    {
        UpdiWriteDword(key, UPDINST_VAL_LEVEL, (DWORD)level);
        NOHANDLES(RegCloseKey(key));
    }
}

BOOL UpdInstall_LoadArm(CSalUpdArm* arm)
{
    memset(arm, 0, sizeof(*arm));
    HKEY key;
    if (!UpdateCheck_OpenStateKey(FALSE, &key))
        return FALSE;
    char text[80];
    DWORD source = 0, test = 0, launches = 0;
    BOOL ok = UpdiReadText(key, UPDINST_VAL_VERSION, text, sizeof(text)) &&
              SalUpdParseVersion(text, -1, FALSE, &arm->Version) &&
              UpdiReadText(key, UPDINST_VAL_DIGEST, text, sizeof(text)) && SalUpdParseDigestHex(text, arm->Digest) &&
              UpdiReadDword(key, UPDINST_VAL_SOURCE, &source) &&
              (source == SALUPD_ARM_USER || source == SALUPD_ARM_AUTOMATIC) &&
              UpdiReadDword(key, UPDINST_VAL_TEST, &test) && test <= 1 &&
              UpdiReadDword(key, UPDINST_VAL_LAUNCHES, &launches);
    NOHANDLES(RegCloseKey(key));
    if (!ok)
    {
        memset(arm, 0, sizeof(*arm)); // a partial or invalid arm is no arm
        return FALSE;
    }
    arm->Present = TRUE;
    arm->Source = source;
    arm->Test = test != 0;
    arm->Launches = launches;
    return TRUE;
}

static void UpdiSaveArm(const CSalUpdArm& arm)
{
    char version[SALUPD_VERSION_TEXT_MAX];
    char digest[2 * SALUPD_DIGEST_BYTES + 1];
    HKEY key;
    if (!SalUpdFormatVersion(arm.Version, version, sizeof(version)) ||
        !SalUpdFormatDigestHex(arm.Digest, digest, sizeof(digest)) || !UpdateCheck_OpenStateKey(TRUE, &key))
        return;
    UpdiWriteText(key, UPDINST_VAL_VERSION, version);
    UpdiWriteText(key, UPDINST_VAL_DIGEST, digest);
    UpdiWriteDword(key, UPDINST_VAL_SOURCE, arm.Source);
    UpdiWriteDword(key, UPDINST_VAL_TEST, arm.Test ? 1 : 0);
    UpdiWriteDword(key, UPDINST_VAL_LAUNCHES, arm.Launches);
    NOHANDLES(RegCloseKey(key));
}

void UpdInstall_DropArm()
{
    HKEY key;
    if (!UpdateCheck_OpenStateKey(TRUE, &key))
        return;
    NOHANDLES(RegDeleteValueW(key, UPDINST_VAL_VERSION)); // first: without it the rest is no arm
    NOHANDLES(RegDeleteValueW(key, UPDINST_VAL_DIGEST));
    NOHANDLES(RegDeleteValueW(key, UPDINST_VAL_SOURCE));
    NOHANDLES(RegDeleteValueW(key, UPDINST_VAL_TEST));
    NOHANDLES(RegDeleteValueW(key, UPDINST_VAL_LAUNCHES));
    NOHANDLES(RegCloseKey(key));
}

BOOL UpdInstall_ArmHonoured(const CSalUpdArm& arm)
{
    CUpdateState state;
    UpdateCheck_LoadState(&state);
    return SalUpdArmHonoured(arm, state.CheckAtStartup, UpdInstall_GetLevel(), UpdateTestMode);
}

void UpdInstall_OnSettingsChanged()
{
    CSalUpdArm arm;
    if (UpdInstall_LoadArm(&arm) && arm.Source == SALUPD_ARM_AUTOMATIC && !UpdInstall_ArmHonoured(arm))
    {
        TRACE_I("UpdInstall: the settings no longer allow the automatic arm - dropped");
        UpdInstall_DropArm();
    }
}

//
// ****************************************************************************
// the installation and the connection
//

static BOOL UpdiEligibleKnown = FALSE;
static BOOL UpdiEligible = FALSE;
static BOOL UpdiAllUsers = FALSE;

// reads InstallLocation of the uninstall entry under 'root'\'subkey'; TRUE when it names 'folderU8'
static BOOL UpdiEntryNamesFolder(HKEY root, const WCHAR* subkey, REGSAM view, const char* folderU8)
{
    HKEY key;
    if (NOHANDLES(RegOpenKeyExW(root, subkey, 0, KEY_READ | view, &key)) != ERROR_SUCCESS)
        return FALSE;
    WCHAR location[1100];
    DWORD type = 0;
    DWORD size = sizeof(location) - sizeof(WCHAR);
    LONG res = NOHANDLES(RegQueryValueExW(key, L"InstallLocation", NULL, &type, (BYTE*)location, &size));
    NOHANDLES(RegCloseKey(key));
    if (res != ERROR_SUCCESS || (type != REG_SZ && type != REG_EXPAND_SZ) || (size % sizeof(WCHAR)) != 0)
        return FALSE; // also a value too long for the buffer: refused, never cut
    location[size / sizeof(WCHAR)] = 0;
    int len = (int)wcslen(location);
    while (len > 3 && location[len - 1] == L'\\') // Inno writes the folder with a trailing backslash
        location[--len] = 0;
    char locationU8[4 * _countof(location)];
    if (len == 0 || SalWToU8(location, -1, locationU8, sizeof(locationU8)) <= 0)
        return FALSE;
    return SalPathEqualOrdinalCI(locationU8, folderU8);
}

// the folder of the running program, without a trailing backslash, as UTF-8
static BOOL UpdiProgramFolderU8(char* buf, int bufSize, WCHAR* exeW, int exeWSize)
{
    DWORD n = GetModuleFileNameW(NULL, exeW, exeWSize);
    if (n == 0 || n >= (DWORD)exeWSize - 1)
        return FALSE; // a path that does not fit is refused
    WCHAR folder[2048];
    lstrcpynW(folder, exeW, _countof(folder));
    WCHAR* slash = wcsrchr(folder, L'\\');
    if (slash == NULL)
        return FALSE;
    *slash = 0;
    return SalWToU8(folder, -1, buf, bufSize) > 0;
}

BOOL UpdInstall_IsEligible(BOOL* allUsers)
{
    if (!UpdiEligibleKnown)
    {
        UpdiEligibleKnown = TRUE;
        UpdiEligible = FALSE;
        char folderU8[8200];
        WCHAR exeW[2048];
        if (UpdiProgramFolderU8(folderU8, sizeof(folderU8), exeW, _countof(exeW)))
        {
#ifdef _DEBUG
            // test seam, Debug builds only: "ALLUSERS:<key under HKCU>" or "CURRENTUSER:<key under HKCU>"
            // stands for the uninstall entry, so that a probe can make a build tree "installed"
            WCHAR seam[600];
            DWORD seamLen = GetEnvironmentVariableW(L"TC_UPDATE_PROBE_UNINSTALL", seam, _countof(seam));
            if (seamLen > 0 && seamLen < _countof(seam))
            {
                BOOL all = wcsncmp(seam, L"ALLUSERS:", 9) == 0;
                BOOL cur = wcsncmp(seam, L"CURRENTUSER:", 12) == 0;
                if ((all || cur) &&
                    UpdiEntryNamesFolder(HKEY_CURRENT_USER, seam + (all ? 9 : 12), 0, folderU8))
                {
                    UpdiEligible = TRUE;
                    UpdiAllUsers = all;
                }
                TRACE_I("UpdInstall: probe seam for the installation, eligible " << UpdiEligible);
                if (allUsers != NULL)
                    *allUsers = UpdiAllUsers;
                return UpdiEligible;
            }
#endif // _DEBUG
            if (UpdiEntryNamesFolder(HKEY_LOCAL_MACHINE, UPDINST_UNINSTALL_KEY, KEY_WOW64_64KEY, folderU8))
            {
                UpdiEligible = TRUE;
                UpdiAllUsers = TRUE;
            }
            else if (UpdiEntryNamesFolder(HKEY_CURRENT_USER, UPDINST_UNINSTALL_KEY, 0, folderU8))
            {
                UpdiEligible = TRUE;
                UpdiAllUsers = FALSE;
            }
        }
        TRACE_I("UpdInstall: installed by the installer: " << UpdiEligible << ", all users: " << UpdiAllUsers);
    }
    if (allUsers != NULL)
        *allUsers = UpdiAllUsers;
    return UpdiEligible;
}

BOOL UpdInstall_IsMetered()
{
#ifdef _DEBUG
    // test seam, Debug builds only
    WCHAR seam[8];
    if (GetEnvironmentVariableW(L"TC_UPDATE_PROBE_METERED", seam, _countof(seam)) > 0)
        return seam[0] == L'1';
#endif // _DEBUG
    BOOL metered = FALSE;
    INetworkCostManager* cost = NULL;
    if (SUCCEEDED(CoCreateInstance(CLSID_NetworkListManager, NULL, CLSCTX_ALL, IID_INetworkCostManager,
                                   (void**)&cost)) &&
        cost != NULL)
    {
        DWORD value = 0;
        if (SUCCEEDED(cost->GetCost(&value, NULL)))
        {
            metered = (value & (NLM_CONNECTION_COST_FIXED | NLM_CONNECTION_COST_VARIABLE |
                                NLM_CONNECTION_COST_OVERDATALIMIT | NLM_CONNECTION_COST_ROAMING)) != 0;
        }
        cost->Release();
    }
    TRACE_I("UpdInstall: metered connection: " << metered);
    return metered;
}

//
// ****************************************************************************
// the updates folder
//

// %LOCALAPPDATA%\Tandem Commander\Updates; 'create' makes it when missing
static BOOL UpdiFolder(WCHAR* buf, int bufSize, BOOL create)
{
    WCHAR base[MAX_PATH];
    if (SHGetFolderPathW(NULL, CSIDL_LOCAL_APPDATA, NULL, SHGFP_TYPE_CURRENT, base) != S_OK)
        return FALSE;
    if (_snwprintf_s(buf, bufSize, _TRUNCATE, L"%s\\Tandem Commander\\Updates", base) < 0)
        return FALSE; // never cut
    if (create)
    {
        WCHAR parent[MAX_PATH + 40];
        if (_snwprintf_s(parent, _countof(parent), _TRUNCATE, L"%s\\Tandem Commander", base) < 0)
            return FALSE;
        CreateDirectoryW(parent, NULL);
        CreateDirectoryW(buf, NULL);
    }
    return TRUE;
}

// <folder>\<name> for the ASCII 'name' made by salupdinstall.h
static BOOL UpdiFilePath(const char* name, WCHAR* buf, int bufSize, BOOL create)
{
    WCHAR folder[UPDINST_MAX_FOLDER];
    if (!UpdiFolder(folder, _countof(folder), create))
        return FALSE;
    WCHAR nameW[100];
    int i = 0;
    for (; name[i] != 0 && i < _countof(nameW) - 1; i++)
        nameW[i] = (WCHAR)(unsigned char)name[i];
    if (name[i] != 0)
        return FALSE;
    nameW[i] = 0;
    return _snwprintf_s(buf, bufSize, _TRUNCATE, L"%s\\%s", folder, nameW) >= 0;
}

static BOOL UpdiInstallerPath(const CSalUpdVersion& v, WCHAR* buf, int bufSize, BOOL create = FALSE)
{
    char name[SALUPD_URL_MAX];
    return SalUpdInstallerName(v, name, sizeof(name)) && UpdiFilePath(name, buf, bufSize, create);
}

static BOOL UpdiLogPath(const CSalUpdVersion& v, WCHAR* buf, int bufSize)
{
    char name[SALUPD_URL_MAX];
    return SalUpdLogName(v, name, sizeof(name)) && UpdiFilePath(name, buf, bufSize, FALSE);
}

// deletes the installer, its '.part' and its log of version 'v'
static void UpdiDeleteFiles(const CSalUpdVersion& v)
{
    WCHAR path[UPDINST_MAX_FOLDER + 100];
    if (UpdiInstallerPath(v, path, _countof(path)))
    {
        DeleteFileW(path);
        if (wcslen(path) + 5 < _countof(path))
        {
            wcscat_s(path, L".part");
            DeleteFileW(path);
        }
    }
    if (UpdiLogPath(v, path, _countof(path)))
        DeleteFileW(path);
}

//
// ****************************************************************************
// verification (contracts/download-and-verification.md D4)
//

enum CUpdVerifyResult
{
    suvOk,
    suvIo,       // missing, unreadable
    suvSize,     // larger than SALUPD_MAX_INSTALLER_BYTES
    suvHash,     // SHA-256 differs from the release record's digest
    suvUnsigned, // no valid Authenticode signature
    suvSigner,   // signed, but not with the project's certificate
    suvVersion   // the version resource names another product or version
};

static const char* UpdiVerifyName(CUpdVerifyResult r)
{
    switch (r)
    {
    case suvOk:
        return "ok";
    case suvIo:
        return "io";
    case suvSize:
        return "size";
    case suvHash:
        return "hash";
    case suvUnsigned:
        return "unsigned";
    case suvSigner:
        return "signer";
    case suvVersion:
        return "version";
    }
    return "?";
}

// SHA-256 of the whole file behind 'file' (read from its start)
static BOOL UpdiHashFile(HANDLE file, unsigned char* digest)
{
    BCRYPT_ALG_HANDLE alg = NULL;
    BCRYPT_HASH_HANDLE hash = NULL;
    BOOL ok = FALSE;
    BYTE* buffer = (BYTE*)malloc(UPDDL_BUFFER);
    LARGE_INTEGER zero;
    zero.QuadPart = 0;
    if (buffer != NULL && SetFilePointerEx(file, zero, NULL, FILE_BEGIN) &&
        BCRYPT_SUCCESS(BCryptOpenAlgorithmProvider(&alg, BCRYPT_SHA256_ALGORITHM, NULL, 0)) &&
        BCRYPT_SUCCESS(BCryptCreateHash(alg, &hash, NULL, 0, NULL, 0, 0)))
    {
        ok = TRUE;
        for (;;)
        {
            DWORD read = 0;
            if (!ReadFile(file, buffer, UPDDL_BUFFER, &read, NULL))
            {
                ok = FALSE;
                break;
            }
            if (read == 0)
                break;
            if (!BCRYPT_SUCCESS(BCryptHashData(hash, buffer, read, 0)))
            {
                ok = FALSE;
                break;
            }
        }
        if (ok)
            ok = BCRYPT_SUCCESS(BCryptFinishHash(hash, digest, SALUPD_DIGEST_BYTES, 0));
    }
    if (hash != NULL)
        BCryptDestroyHash(hash);
    if (alg != NULL)
        BCryptCloseAlgorithmProvider(alg, 0);
    if (buffer != NULL)
        free(buffer);
    return ok;
}

// Authenticode: a valid signature (no network: no revocation lookup, only cached addresses) whose
// signer certificate is the project's (SALUPD_SIGNER_THUMBPRINT)
static CUpdVerifyResult UpdiVerifySignature(const WCHAR* path, HANDLE file)
{
    LARGE_INTEGER zero;
    zero.QuadPart = 0;
    SetFilePointerEx(file, zero, NULL, FILE_BEGIN);
    WINTRUST_FILE_INFO fileInfo;
    memset(&fileInfo, 0, sizeof(fileInfo));
    fileInfo.cbStruct = sizeof(fileInfo);
    fileInfo.pcwszFilePath = path;
    fileInfo.hFile = file;
    WINTRUST_DATA data;
    memset(&data, 0, sizeof(data));
    data.cbStruct = sizeof(data);
    data.dwUIChoice = WTD_UI_NONE;
    data.fdwRevocationChecks = WTD_REVOKE_NONE;
    data.dwUnionChoice = WTD_CHOICE_FILE;
    data.pFile = &fileInfo;
    data.dwStateAction = WTD_STATEACTION_VERIFY;
    data.dwProvFlags = WTD_CACHE_ONLY_URL_RETRIEVAL | WTD_REVOCATION_CHECK_NONE;
    GUID action = WINTRUST_ACTION_GENERIC_VERIFY_V2;
    LONG status = WinVerifyTrust((HWND)INVALID_HANDLE_VALUE, &action, &data);
    CUpdVerifyResult result = suvUnsigned;
    if (status == ERROR_SUCCESS)
    {
        result = suvSigner;
        CRYPT_PROVIDER_DATA* prov = WTHelperProvDataFromStateData(data.hWVTStateData);
        CRYPT_PROVIDER_SGNR* signer = prov != NULL ? WTHelperGetProvSignerFromChain(prov, 0, FALSE, 0) : NULL;
        CRYPT_PROVIDER_CERT* cert = signer != NULL ? WTHelperGetProvCertFromChain(signer, 0) : NULL;
        if (cert != NULL && cert->pCert != NULL)
        {
            BYTE thumb[32];
            DWORD thumbSize = sizeof(thumb);
            if (CertGetCertificateContextProperty(cert->pCert, CERT_SHA1_HASH_PROP_ID, thumb, &thumbSize) &&
                SalUpdSignerPinned(thumb, thumbSize))
                result = suvOk;
        }
    }
    else
        TRACE_I("UpdInstall: WinVerifyTrust failed, 0x" << std::hex << status << std::dec);
    data.dwStateAction = WTD_STATEACTION_CLOSE;
    WinVerifyTrust((HWND)INVALID_HANDLE_VALUE, &action, &data);
    return result;
}

// ProductName / ProductVersion of the first translation of the version resource
static BOOL UpdiVersionResourceOk(const WCHAR* path, const CSalUpdVersion& version)
{
    DWORD dummy = 0;
    DWORD size = GetFileVersionInfoSizeW(path, &dummy);
    if (size == 0 || size > 1024 * 1024)
        return FALSE;
    BYTE* info = (BYTE*)malloc(size);
    if (info == NULL)
        return FALSE;
    BOOL ok = FALSE;
    struct CLangCp
    {
        WORD Lang, CodePage;
    }* trans = NULL;
    UINT transLen = 0;
    if (GetFileVersionInfoW(path, 0, size, info) &&
        VerQueryValueW(info, L"\\VarFileInfo\\Translation", (LPVOID*)&trans, &transLen) && trans != NULL &&
        transLen >= sizeof(CLangCp))
    {
        WCHAR query[80];
        WCHAR* name = NULL;
        WCHAR* ver = NULL;
        UINT len = 0;
        swprintf_s(query, L"\\StringFileInfo\\%04x%04x\\ProductName", trans[0].Lang, trans[0].CodePage);
        BOOL hasName = VerQueryValueW(info, query, (LPVOID*)&name, &len) && name != NULL;
        swprintf_s(query, L"\\StringFileInfo\\%04x%04x\\ProductVersion", trans[0].Lang, trans[0].CodePage);
        BOOL hasVer = VerQueryValueW(info, query, (LPVOID*)&ver, &len) && ver != NULL;
        ok = hasName && hasVer && SalUpdInstallerVersionOk(name, ver, version);
    }
    free(info);
    return ok;
}

// Verifies the installer at 'path'. 'keepOpen' (may be NULL) receives the handle that keeps the
// file from being changed or deleted (no write / delete sharing) until the caller closes it - for
// a launch. A failure deletes the file.
static CUpdVerifyResult UpdiVerify(const WCHAR* path, const CSalUpdVersion& version, const unsigned char* digest,
                                   HANDLE* keepOpen)
{
    if (keepOpen != NULL)
        *keepOpen = NULL;
    HANDLE file = NOHANDLES(CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING,
                                        FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN, NULL));
    if (file == INVALID_HANDLE_VALUE)
        return suvIo; // nothing to delete, or somebody holds it (then it is not touched)
    CUpdVerifyResult result = suvOk;
    LARGE_INTEGER size;
    unsigned char hash[SALUPD_DIGEST_BYTES];
    if (!GetFileSizeEx(file, &size))
        result = suvIo;
    else if ((ULONGLONG)size.QuadPart > SALUPD_MAX_INSTALLER_BYTES)
        result = suvSize;
    else if (!UpdiHashFile(file, hash))
        result = suvIo;
    else if (memcmp(hash, digest, SALUPD_DIGEST_BYTES) != 0)
        result = suvHash;
    else if ((result = UpdiVerifySignature(path, file)) == suvOk && !UpdiVersionResourceOk(path, version))
        result = suvVersion;
    TRACE_I("UpdInstall: verification of the installer: " << UpdiVerifyName(result));
    if (result == suvOk && keepOpen != NULL)
        *keepOpen = file;
    else
        NOHANDLES(CloseHandle(file));
    if (result != suvOk && result != suvIo)
        DeleteFileW(path); // never run, never offered again
    return result;
}

// is a verified installer of 'release' in the updates folder?
static BOOL UpdiHasVerified(const CSalUpdRelease& release)
{
    WCHAR path[UPDINST_MAX_FOLDER + 100];
    if (!release.HasDigest || !UpdiInstallerPath(release.Version, path, _countof(path)))
        return FALSE;
    if (GetFileAttributesW(path) == INVALID_FILE_ATTRIBUTES)
        return FALSE;
    return UpdiVerify(path, release.Version, release.Digest, NULL) == suvOk;
}

//
// ****************************************************************************
// starting the installer (contracts/installer-launch.md)
//

static HWND UpdiWatchNotify = NULL;

static DWORD WINAPI UpdiWatcherThread(void* param)
{
    HANDLE process = (HANDLE)param;
    WaitForSingleObject(process, INFINITE);
    DWORD code = 0;
    if (!GetExitCodeProcess(process, &code))
        code = (DWORD)-1;
    NOHANDLES(CloseHandle(process));
    TRACE_I("UpdInstall: the installer ended with " << code);
    if (code != 0 && UpdiWatchNotify != NULL)
        PostMessage(UpdiWatchNotify, WM_USER_UPDATEINSTALL_DONE, (WPARAM)code, 0);
    return 0;
}

// Starts the installer of 'version' (verified, held open by 'held', which this closes). Records the
// launch in the arm first. 'watch': a thread waits for the process and reports a failure.
static BOOL UpdiLaunch(CSalUpdLaunchKind kind, const CSalUpdVersion& version, HANDLE held, BOOL watch,
                       DWORD* error)
{
    *error = 0;
    BOOL allUsers = FALSE;
    WCHAR exe[UPDINST_MAX_FOLDER + 100];
    WCHAR log[UPDINST_MAX_FOLDER + 100];
    WCHAR folder[UPDINST_MAX_FOLDER];
    WCHAR args[SALUPD_ARGS_MAX];
    BOOL noRestart = FALSE;
#ifdef _DEBUG
    // test seam, Debug builds only: a restart after a probe's installation would appear on the
    // visible desktop
    WCHAR seam[8];
    noRestart = GetEnvironmentVariableW(L"TC_UPDATE_PROBE_NORESTART", seam, _countof(seam)) > 0;
#endif // _DEBUG
    if (!UpdInstall_IsEligible(&allUsers) || !UpdiInstallerPath(version, exe, _countof(exe)) ||
        !UpdiLogPath(version, log, _countof(log)) || !UpdiFolder(folder, _countof(folder), FALSE) ||
        !SalUpdBuildInstallerArgs(kind, allUsers, noRestart, log, args, _countof(args)) ||
        wcschr(exe, L'"') != NULL)
    {
        if (held != NULL)
            NOHANDLES(CloseHandle(held));
        *error = ERROR_INVALID_PARAMETER;
        return FALSE;
    }

    CSalUpdArm arm;
    if (UpdInstall_LoadArm(&arm) && SalUpdVersionCompare(arm.Version, version) == 0)
    {
        arm.Launches++;
        UpdiSaveArm(arm);
    }

    size_t cmdSize = wcslen(exe) + wcslen(args) + 4;
    WCHAR* cmd = (WCHAR*)malloc(cmdSize * sizeof(WCHAR));
    if (cmd == NULL)
    {
        if (held != NULL)
            NOHANDLES(CloseHandle(held));
        *error = ERROR_NOT_ENOUGH_MEMORY;
        return FALSE;
    }
    swprintf_s(cmd, cmdSize, L"\"%s\" %s", exe, args);

    BOOL ok = FALSE;
#ifdef _DEBUG
    // test seam, Debug builds only: the probe reads what would be started
    WCHAR runLog[MAX_PATH];
    DWORD len = GetEnvironmentVariableW(L"TC_UPDATE_PROBE_RUNLOG", runLog, _countof(runLog));
    if (len > 0 && len < _countof(runLog))
    {
        HANDLE f = NOHANDLES(CreateFileW(runLog, FILE_APPEND_DATA, FILE_SHARE_READ, NULL, OPEN_ALWAYS,
                                         FILE_ATTRIBUTE_NORMAL, NULL));
        if (f != INVALID_HANDLE_VALUE)
        {
            char line[4 * 2600];
            char cmdU8[4 * 2400];
            if (SalWToU8(cmd, -1, cmdU8, sizeof(cmdU8)) > 0)
            {
                _snprintf_s(line, _TRUNCATE, "%s|%s\r\n", SalUpdLaunchKindName(kind), cmdU8);
                DWORD written;
                WriteFile(f, line, (DWORD)strlen(line), &written, NULL);
            }
            NOHANDLES(CloseHandle(f));
        }
        ok = TRUE;
        TRACE_I("UpdInstall: probe seam - the installer was logged, not started");
    }
    else
#endif // _DEBUG
    {
        STARTUPINFOW si;
        memset(&si, 0, sizeof(si));
        si.cb = sizeof(si);
        PROCESS_INFORMATION pi;
        memset(&pi, 0, sizeof(pi));
        ok = CreateProcessW(exe, cmd, NULL, NULL, FALSE, 0, NULL, folder, &si, &pi);
        if (!ok)
            *error = GetLastError();
        else
        {
            TRACE_I("UpdInstall: the installer was started (" << SalUpdLaunchKindName(kind) << ")");
            NOHANDLES(CloseHandle(pi.hThread));
            HANDLE thread = NULL;
            if (watch)
            {
                DWORD id;
                thread = HANDLES(CreateThread(NULL, 0, UpdiWatcherThread, pi.hProcess, 0, &id));
            }
            if (thread != NULL)
                AddAuxThread(thread); // it may wait until the program is closed by the installer
            else
                NOHANDLES(CloseHandle(pi.hProcess));
        }
    }
    free(cmd);
    if (held != NULL)
        NOHANDLES(CloseHandle(held)); // only now: the file could not change until the process existed
    return ok;
}

void UpdInstall_Arm(const CSalUpdRelease& release, DWORD source)
{
    CSalUpdArm arm;
    CSalUpdArm old;
    memset(&arm, 0, sizeof(arm));
    arm.Present = TRUE;
    arm.Version = release.Version;
    memcpy(arm.Digest, release.Digest, sizeof(arm.Digest));
    arm.Source = source;
    arm.Test = UpdateTestMode;
    if (UpdInstall_LoadArm(&old) && SalUpdVersionCompare(old.Version, release.Version) == 0 &&
        old.Test == arm.Test)
    {
        arm.Launches = old.Launches;
        if (old.Source == SALUPD_ARM_USER)
            arm.Source = SALUPD_ARM_USER; // a click is not weakened by the automatic level
    }
    UpdiSaveArm(arm);
    TRACE_I("UpdInstall: armed for the exit, source " << arm.Source << ", test " << arm.Test);
}

static void UpdiReportRunError(HWND parent, const CSalUpdVersion& version, DWORD error)
{
    char ver[SALUPD_VERSION_TEXT_MAX];
    SalUpdFormatVersion(version, ver, sizeof(ver));
    char reason[1000];
    if (SalWToU8(GetErrorTextW(error), -1, reason, sizeof(reason)) <= 0)
        reason[0] = 0;
    char text[1500];
    _snprintf_s(text, _TRUNCATE, LoadStrU8(IDS_UPDATE_ERR_RUN), ver, reason);
    char title[200];
    lstrcpyn(title, LoadStrU8(IDS_UPDATE_TITLE), _countof(title));
    SalMessageBox(parent, text, title, MB_OK | MB_ICONEXCLAMATION);
}

BOOL UpdInstall_InstallNow(HWND parent, const CSalUpdRelease& release)
{
    CALL_STACK_MESSAGE1("UpdInstall_InstallNow()");
    WCHAR path[UPDINST_MAX_FOLDER + 100];
    HANDLE held = NULL;
    if (!release.HasDigest || !UpdiInstallerPath(release.Version, path, _countof(path)) ||
        UpdiVerify(path, release.Version, release.Digest, &held) != suvOk)
    {
        UpdiReportRunError(parent, release.Version, ERROR_FILE_NOT_FOUND);
        return FALSE;
    }
    UpdInstall_Arm(release, SALUPD_ARM_USER); // should it fail, the exit installs it
    UpdiWatchNotify = MainWindow != NULL ? MainWindow->HWindow : parent;
    DWORD error;
    if (!UpdiLaunch(sulkNow, release.Version, held, TRUE, &error))
    {
        UpdiReportRunError(parent, release.Version, error);
        return FALSE;
    }
    return TRUE;
}

void UpdInstall_OnInstallerEnded(HWND parent, DWORD exitCode)
{
    CSalUpdArm arm;
    char ver[SALUPD_VERSION_TEXT_MAX] = "";
    if (UpdInstall_LoadArm(&arm))
        SalUpdFormatVersion(arm.Version, ver, sizeof(ver));
    char text[1000];
    _snprintf_s(text, _TRUNCATE, LoadStrU8(IDS_UPDATE_INSTALL_FAILED), ver, (unsigned)exitCode);
    char title[200];
    lstrcpyn(title, LoadStrU8(IDS_UPDATE_TITLE), _countof(title));
    SalMessageBox(parent, text, title, MB_OK | MB_ICONEXCLAMATION);
}

void UpdInstall_SkipVersion(const CSalUpdVersion& version)
{
    CSalUpdArm arm;
    if (UpdInstall_LoadArm(&arm) && SalUpdVersionCompare(arm.Version, version) == 0)
        UpdInstall_DropArm();
    UpdiDeleteFiles(version);
}

//
// ****************************************************************************
// the download worker (contracts/download-and-verification.md D2, D3)
//

struct CUpdDownloadContext
{
    HWND Notify;
    HANDLE CancelEvent; // manual-reset; signalled by a cancel, closed by the worker
    BOOL Cancelled;     // guarded by UpdiCS
    CSalUpdRelease Release;
};

static CRITICAL_SECTION UpdiCS; // never deleted: a worker may outlive an exit in progress
static LONG UpdiCSInitialized = 0;
static CUpdDownloadContext* UpdiRunning = NULL; // guarded by UpdiCS
static BOOL UpdiHasDone = FALSE;                // guarded by UpdiCS
static CUpdDownloadDone UpdiDone;               // guarded by UpdiCS
static BOOL UpdiShutDown = FALSE;               // guarded by UpdiCS
static HANDLE UpdiThread = NULL;                // main thread only

static void UpdiEnsureCS()
{
    if (InterlockedCompareExchange(&UpdiCSInitialized, 1, 0) == 0)
        NOHANDLES(InitializeCriticalSection(&UpdiCS));
}

static BOOL UpdiIsCancelled(CUpdDownloadContext* ctx)
{
    NOHANDLES(EnterCriticalSection(&UpdiCS));
    BOOL c = ctx->Cancelled;
    NOHANDLES(LeaveCriticalSection(&UpdiCS));
    return c;
}

// One request of the download: opens it, sends it, waits for the headers. 'request' stays open
// for the caller. Returns the HTTP status or 0 (no answer, cancelled, timed out).
struct CUpdiHop
{
    HINTERNET Connect;
    HINTERNET Request;
    BOOL CallbackSet;
};

// FALSE when the request handle did not report its closing: a late callback may still touch
// 'async' and the read buffer, so the caller must leave them allocated (as feature 123 does)
static BOOL UpdiCloseHop(CUpdiHop* hop, CUpdAsync* async)
{
    BOOL quiet = TRUE;
    if (hop->Request != NULL)
    {
        WinHttpCloseHandle(hop->Request);
        if (hop->CallbackSet)
            quiet = WaitForSingleObject(async->Closed, 5000) == WAIT_OBJECT_0;
        ResetEvent(async->Closed);
        hop->Request = NULL;
    }
    if (hop->Connect != NULL)
    {
        WinHttpCloseHandle(hop->Connect);
        hop->Connect = NULL;
    }
    hop->CallbackSet = FALSE;
    return quiet;
}

static DWORD UpdiOpenHop(CUpdDownloadContext* ctx, HINTERNET session, CUpdAsync* async, CUpdiHop* hop,
                         const WCHAR* host, INTERNET_PORT port, BOOL secure, const WCHAR* path, BOOL first,
                         DWORD totalStart)
{
    memset(hop, 0, sizeof(*hop));
    hop->Connect = WinHttpConnect(session, host, port, 0);
    if (hop->Connect == NULL)
        return 0;
    hop->Request = WinHttpOpenRequest(hop->Connect, L"GET", path, NULL, WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES,
                                      secure ? WINHTTP_FLAG_SECURE : 0);
    if (hop->Request == NULL)
        return 0;
    // no cookie jar, no logon with the user's Windows credentials, no redirect followed by WinHTTP
    // (the program follows only the allowed ones itself)
    DWORD disable = WINHTTP_DISABLE_COOKIES | WINHTTP_DISABLE_AUTHENTICATION | WINHTTP_DISABLE_REDIRECTS;
    DWORD_PTR context = (DWORD_PTR)async;
    if (!WinHttpSetOption(hop->Request, WINHTTP_OPTION_DISABLE_FEATURE, &disable, sizeof(disable)) ||
        !WinHttpSetOption(hop->Request, WINHTTP_OPTION_CONTEXT_VALUE, &context, sizeof(context)) ||
        WinHttpSetStatusCallback(hop->Request, UpdHttpStatusCallback,
                                 WINHTTP_CALLBACK_FLAG_ALL_COMPLETIONS | WINHTTP_CALLBACK_FLAG_HANDLES,
                                 0) == WINHTTP_INVALID_STATUS_CALLBACK)
        return 0;
    hop->CallbackSet = TRUE;
    if (UpdiIsCancelled(ctx))
        return 0;
    BOOL timedOut = FALSE;
    DWORD status = 0;
    DWORD statusSize = sizeof(status);
    DWORD stepStart = GetTickCount();
    DWORD stepMs = UPDDL_STEP_MS;
    DWORD totalLeft = UPDDL_TOTAL_MS - min(UPDDL_TOTAL_MS, GetTickCount() - totalStart);
    if (stepMs > totalLeft)
        stepMs = totalLeft;
    if (!WinHttpSendRequest(hop->Request, first ? SALUPD_DOWNLOAD_HEADERS_W : WINHTTP_NO_ADDITIONAL_HEADERS,
                            first ? (DWORD)-1L : 0, WINHTTP_NO_REQUEST_DATA, 0, 0, (DWORD_PTR)async) ||
        UpdHttpAwait(ctx->CancelEvent, async, stepStart, stepMs, &timedOut) != WINHTTP_CALLBACK_STATUS_SENDREQUEST_COMPLETE)
        return 0;
    stepStart = GetTickCount();
    if (!WinHttpReceiveResponse(hop->Request, NULL) ||
        UpdHttpAwait(ctx->CancelEvent, async, stepStart, stepMs, &timedOut) != WINHTTP_CALLBACK_STATUS_HEADERS_AVAILABLE ||
        !WinHttpQueryHeaders(hop->Request, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                             WINHTTP_HEADER_NAME_BY_INDEX, &status, &statusSize, WINHTTP_NO_HEADER_INDEX))
        return 0;
    return status;
}

// downloads into 'partPath', hashing; TRUE when exactly the record's bytes with its digest arrived
static BOOL UpdiDownloadBody(CUpdDownloadContext* ctx, CUpdiHop* hop, CUpdAsync* async, const WCHAR* partPath,
                             BYTE* buffer, DWORD totalStart)
{
    const CSalUpdRelease& rel = ctx->Release;
    // an announced length must be the record's size
    DWORD announced = 0;
    DWORD announcedSize = sizeof(announced);
    if (WinHttpQueryHeaders(hop->Request, WINHTTP_QUERY_CONTENT_LENGTH | WINHTTP_QUERY_FLAG_NUMBER,
                            WINHTTP_HEADER_NAME_BY_INDEX, &announced, &announcedSize, WINHTTP_NO_HEADER_INDEX) &&
        (ULONGLONG)announced != rel.AssetSize)
    {
        TRACE_I("UpdInstall: the announced length is not the record's size");
        return FALSE;
    }
    HANDLE file = NOHANDLES(CreateFileW(partPath, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL));
    if (file == INVALID_HANDLE_VALUE)
        return FALSE;
    BCRYPT_ALG_HANDLE alg = NULL;
    BCRYPT_HASH_HANDLE hash = NULL;
    BOOL ok = BCRYPT_SUCCESS(BCryptOpenAlgorithmProvider(&alg, BCRYPT_SHA256_ALGORITHM, NULL, 0)) &&
              BCRYPT_SUCCESS(BCryptCreateHash(alg, &hash, NULL, 0, NULL, 0, 0));
    ULONGLONG total = 0;
    BOOL complete = FALSE;
    while (ok)
    {
        if (GetTickCount() - totalStart >= UPDDL_TOTAL_MS)
        {
            ok = FALSE;
            break;
        }
        BOOL timedOut = FALSE;
        if (!WinHttpQueryDataAvailable(hop->Request, NULL) ||
            UpdHttpAwait(ctx->CancelEvent, async, GetTickCount(), UPDDL_STEP_MS, &timedOut) !=
                WINHTTP_CALLBACK_STATUS_DATA_AVAILABLE)
        {
            ok = FALSE;
            break;
        }
        DWORD avail = async->Number;
        if (avail == 0)
        {
            complete = TRUE;
            break;
        }
        if (!WinHttpReadData(hop->Request, buffer, min(avail, (DWORD)UPDDL_BUFFER), NULL) ||
            UpdHttpAwait(ctx->CancelEvent, async, GetTickCount(), UPDDL_STEP_MS, &timedOut) !=
                WINHTTP_CALLBACK_STATUS_READ_COMPLETE)
        {
            ok = FALSE;
            break;
        }
        DWORD read = async->Number;
        if (read == 0)
        {
            complete = TRUE;
            break;
        }
        total += read;
        if (total > rel.AssetSize)
        {
            TRACE_I("UpdInstall: more bytes than the record's size");
            ok = FALSE;
            break;
        }
        DWORD written = 0;
        if (!WriteFile(file, buffer, read, &written, NULL) || written != read ||
            !BCRYPT_SUCCESS(BCryptHashData(hash, buffer, read, 0)))
            ok = FALSE;
    }
    unsigned char digest[SALUPD_DIGEST_BYTES];
    if (ok && complete && total == rel.AssetSize && BCRYPT_SUCCESS(BCryptFinishHash(hash, digest, sizeof(digest), 0)) &&
        memcmp(digest, rel.Digest, sizeof(digest)) == 0)
        ok = FlushFileBuffers(file);
    else
    {
        if (ok && complete)
            TRACE_I("UpdInstall: the download does not match the record (size " << total << ")");
        ok = FALSE;
    }
    if (hash != NULL)
        BCryptDestroyHash(hash);
    if (alg != NULL)
        BCryptCloseAlgorithmProvider(alg, 0);
    NOHANDLES(CloseHandle(file));
    return ok;
}

static BOOL UpdiDownload(CUpdDownloadContext* ctx)
{
    const CSalUpdRelease& rel = ctx->Release;
    WCHAR finalPath[UPDINST_MAX_FOLDER + 100];
    WCHAR partPath[UPDINST_MAX_FOLDER + 110];
    if (!UpdiInstallerPath(rel.Version, finalPath, _countof(finalPath), TRUE) ||
        _snwprintf_s(partPath, _countof(partPath), _TRUNCATE, L"%s.part", finalPath) < 0)
        return FALSE;

    // the first address: the API address of the asset (constructed from its validated number)
    WCHAR host[100] = L"api.github.com";
    INTERNET_PORT port = INTERNET_DEFAULT_HTTPS_PORT;
    BOOL secure = TRUE;
    WCHAR* path = (WCHAR*)malloc((SALUPD_LOCATION_MAX + 2) * sizeof(WCHAR));
    WCHAR* location = (WCHAR*)malloc((SALUPD_LOCATION_MAX + 2) * sizeof(WCHAR));
    BYTE* buffer = (BYTE*)malloc(UPDDL_BUFFER);
    CUpdAsync* async = (CUpdAsync*)malloc(sizeof(CUpdAsync));
    char pathA[SALUPD_URL_MAX];
    if (path == NULL || location == NULL || buffer == NULL || async == NULL ||
        !SalUpdAssetApiPath(rel.AssetId, pathA, sizeof(pathA)))
    {
        free(path);
        free(location);
        free(buffer);
        free(async);
        return FALSE;
    }
    for (int i = 0; i <= (int)strlen(pathA); i++)
        path[i] = (WCHAR)(unsigned char)pathA[i];
#ifdef _DEBUG
    // test seam, Debug builds only: with TC_UPDATECHECK_URL (123's loopback fixture) the asset
    // comes from the same fixture server, plain HTTP; a redirect must stay on it
    WCHAR seamUrl[300];
    WCHAR seamPath[300];
    int seamPort = 0;
    BOOL seam = FALSE;
    DWORD seamLen = GetEnvironmentVariableW(L"TC_UPDATECHECK_URL", seamUrl, _countof(seamUrl));
    if (seamLen > 0 && seamLen < _countof(seamUrl) &&
        SalUpdParseLoopbackUrl(seamUrl, &seamPort, seamPath, _countof(seamPath)))
    {
        seam = TRUE;
        wcscpy_s(host, L"127.0.0.1");
        port = (INTERNET_PORT)seamPort;
        secure = FALSE;
    }
#endif // _DEBUG

    memset(async, 0, sizeof(*async));
    async->Event = NOHANDLES(CreateEventW(NULL, FALSE, FALSE, NULL));
    async->Closed = NOHANDLES(CreateEventW(NULL, TRUE, FALSE, NULL));
    HINTERNET session = NULL;
    if (async->Event != NULL && async->Closed != NULL)
    {
        session = WinHttpOpen(SALUPD_DOWNLOAD_USER_AGENT_W,
                              secure ? WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY : WINHTTP_ACCESS_TYPE_NO_PROXY,
                              WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, WINHTTP_FLAG_ASYNC);
        if (session == NULL && secure)
            session = WinHttpOpen(SALUPD_DOWNLOAD_USER_AGENT_W, WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
                                  WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, WINHTTP_FLAG_ASYNC);
    }
    BOOL ok = FALSE;
    BOOL quiet = TRUE;
    if (session != NULL)
    {
        WinHttpSetTimeouts(session, UPDDL_STEP_MS, UPDDL_STEP_MS, UPDDL_STEP_MS, UPDDL_STEP_MS);
        DWORD protocols = WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_2 | 0x00002000 /* WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_3 */;
        BOOL protocolsSet = !secure || WinHttpSetOption(session, WINHTTP_OPTION_SECURE_PROTOCOLS, &protocols, sizeof(protocols));
        if (!protocolsSet)
        {
            protocols = WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_2;
            protocolsSet = WinHttpSetOption(session, WINHTTP_OPTION_SECURE_PROTOCOLS, &protocols, sizeof(protocols));
        }
        DWORD totalStart = GetTickCount();
        for (int hopNo = 0; protocolsSet && hopNo <= SALUPD_MAX_REDIRECTS && !UpdiIsCancelled(ctx); hopNo++)
        {
            CUpdiHop hop;
            DWORD status = UpdiOpenHop(ctx, session, async, &hop, host, port, secure, path, hopNo == 0, totalStart);
            TRACE_I("UpdInstall: download step " << hopNo << ", HTTP status " << status);
            if (SalUpdIsRedirectStatus(status))
            {
                DWORD size = (SALUPD_LOCATION_MAX + 1) * sizeof(WCHAR);
                BOOL hasLocation = WinHttpQueryHeaders(hop.Request, WINHTTP_QUERY_LOCATION, WINHTTP_HEADER_NAME_BY_INDEX,
                                                       location, &size, WINHTTP_NO_HEADER_INDEX);
                if (!UpdiCloseHop(&hop, async))
                {
                    quiet = FALSE;
                    break;
                }
                if (!hasLocation)
                    break;
                BOOL allowed = FALSE;
#ifdef _DEBUG
                if (seam)
                {
                    int p = 0;
                    allowed = SalUpdParseLoopbackUrl(location, &p, path, SALUPD_LOCATION_MAX + 2) && p == seamPort;
                }
                else
#endif // _DEBUG
                {
                    allowed = SalUpdRedirectAllowed(location, host, _countof(host), path, SALUPD_LOCATION_MAX + 2);
                    port = INTERNET_DEFAULT_HTTPS_PORT;
                    secure = TRUE;
                }
                if (!allowed)
                {
                    TRACE_I("UpdInstall: a redirect to a host that is not allowed - refused");
                    break;
                }
                continue;
            }
            if (status == 200)
                ok = UpdiDownloadBody(ctx, &hop, async, partPath, buffer, totalStart);
            if (!UpdiCloseHop(&hop, async))
                quiet = FALSE;
            break;
        }
        WinHttpCloseHandle(session);
    }
    if (quiet)
    {
        if (async->Event != NULL)
            NOHANDLES(CloseHandle(async->Event));
        if (async->Closed != NULL)
            NOHANDLES(CloseHandle(async->Closed));
        free(async);
        free(buffer);
    }
    else
    {
        TRACE_E("UpdInstall: a request handle did not close; its buffers are left allocated");
        ok = FALSE;
    }
    free(path);
    free(location);
    if (ok && !UpdiIsCancelled(ctx))
        ok = MoveFileExW(partPath, finalPath, MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH);
    else
        ok = FALSE;
    DeleteFileW(partPath); // gone after a success too (renamed); a failure leaves nothing
    if (ok)
        ok = UpdiVerify(finalPath, rel.Version, rel.Digest, NULL) == suvOk; // deletes a failure
    return ok;
}

static unsigned UpdiDownloadBodyThread(void* param)
{
    CALL_STACK_MESSAGE1("UpdiDownloadBodyThread()");
    SetThreadNameInVCAndTrace("UpdateDownload");
    CUpdDownloadContext* ctx = (CUpdDownloadContext*)param;
    BOOL ok = UpdiDownload(ctx);
    TRACE_I("UpdInstall: download " << (ok ? "verified" : "failed"));
    NOHANDLES(EnterCriticalSection(&UpdiCS));
    HWND notify = NULL;
    if (UpdiRunning == ctx)
    {
        UpdiRunning = NULL;
        if (!UpdiShutDown && !ctx->Cancelled)
        {
            UpdiDone.Ok = ok;
            UpdiDone.Release = ctx->Release;
            UpdiHasDone = TRUE;
            notify = ctx->Notify;
        }
    }
    NOHANDLES(LeaveCriticalSection(&UpdiCS));
    if (notify != NULL)
        PostMessage(notify, WM_USER_UPDATEDOWNLOAD_DONE, 0, 0);
    NOHANDLES(CloseHandle(ctx->CancelEvent));
    free(ctx);
    return 0;
}

static unsigned UpdiDownloadEH(void* param)
{
#ifndef CALLSTK_DISABLE
    __try
    {
#endif // CALLSTK_DISABLE
        return UpdiDownloadBodyThread(param);
#ifndef CALLSTK_DISABLE
    }
    __except (CCallStack::HandleException(GetExceptionInformation()))
    {
        TRACE_I("Thread UpdateDownload: calling ExitProcess(1).");
        TerminateProcess(GetCurrentProcess(), 1);
        return 1;
    }
#endif // CALLSTK_DISABLE
}

static DWORD WINAPI UpdiDownloadThreadF(void* param)
{
#ifndef CALLSTK_DISABLE
    CCallStack stack;
#endif // CALLSTK_DISABLE
    return UpdiDownloadEH(param);
}

static BOOL UpdiStartDownload(HWND mainWindow, const CSalUpdRelease& release)
{
    UpdiEnsureCS();
    BOOL started = FALSE;
    NOHANDLES(EnterCriticalSection(&UpdiCS));
    if (UpdiRunning != NULL)
        started = SalUpdVersionCompare(UpdiRunning->Release.Version, release.Version) == 0; // already on it
    else if (!UpdiShutDown)
    {
        CUpdDownloadContext* ctx = (CUpdDownloadContext*)malloc(sizeof(CUpdDownloadContext));
        if (ctx != NULL)
        {
            memset(ctx, 0, sizeof(*ctx));
            ctx->Notify = mainWindow;
            ctx->Release = release;
            ctx->CancelEvent = NOHANDLES(CreateEventW(NULL, TRUE, FALSE, NULL));
            if (ctx->CancelEvent != NULL)
            {
                UpdiRunning = ctx;
                UpdiHasDone = FALSE;
                DWORD id;
                HANDLE thread = HANDLES(CreateThread(NULL, 0, UpdiDownloadThreadF, ctx, 0, &id));
                if (thread == NULL)
                {
                    UpdiRunning = NULL;
                    NOHANDLES(CloseHandle(ctx->CancelEvent));
                    free(ctx);
                }
                else
                {
                    if (UpdiThread != NULL)
                        AddAuxThread(UpdiThread); // an earlier, finished or abandoned worker
                    UpdiThread = thread;
                    started = TRUE;
                }
            }
            else
                free(ctx);
        }
    }
    NOHANDLES(LeaveCriticalSection(&UpdiCS));
    TRACE_I("UpdInstall: download started: " << started);
    return started;
}

BOOL UpdInstall_IsDownloading()
{
    if (UpdiCSInitialized == 0)
        return FALSE;
    NOHANDLES(EnterCriticalSection(&UpdiCS));
    BOOL running = UpdiRunning != NULL;
    NOHANDLES(LeaveCriticalSection(&UpdiCS));
    return running;
}

BOOL UpdInstall_TakeDownloadResult(CUpdDownloadDone* done)
{
    if (UpdiCSInitialized == 0)
        return FALSE;
    NOHANDLES(EnterCriticalSection(&UpdiCS));
    BOOL has = UpdiHasDone;
    if (has)
    {
        *done = UpdiDone;
        UpdiHasDone = FALSE;
    }
    NOHANDLES(LeaveCriticalSection(&UpdiCS));
    return has;
}

CSalUpdAfterCheck UpdInstall_AfterCheck(HWND mainWindow, const CSalUpdRelease& release, BOOL* readyNow)
{
    CALL_STACK_MESSAGE1("UpdInstall_AfterCheck()");
    *readyNow = FALSE;
    CUpdateState state;
    UpdateCheck_LoadState(&state);
    CSalUpdLevel level = UpdInstall_GetLevel();
    BOOL eligible = UpdInstall_IsEligible(NULL);
    // the metered test only when it can matter (it creates a COM object)
    BOOL metered = level != sulNotify && eligible && UpdInstall_IsMetered();
    CSalUpdAfterCheck decision = SalUpdAfterCheck(level, state.CheckAtStartup || UpdateTestMode, eligible, metered, release);
    TRACE_I("UpdInstall: after the check - level " << (int)level << ", eligible " << eligible << ", metered " << metered
                                                   << ", download " << (decision == suacDownload));
    if (decision != suacDownload)
        return decision;
    // a verified installer of that version from an earlier session is used again (not in test mode:
    // its start deleted every installer, so a test always downloads)
    if (UpdiHasVerified(release))
    {
        *readyNow = TRUE;
        return decision;
    }
    if (!UpdiStartDownload(mainWindow, release))
        return suacNotify;
    return decision;
}

//
// ****************************************************************************
// start-up and exit
//

static BOOL UpdiStarted = FALSE; // start-up completed: only such a run installs at its exit

static BOOL UpdiLastInstance(); // below

void UpdInstall_OnStartupComplete(HWND mainWindow)
{
    CALL_STACK_MESSAGE1("UpdInstall_OnStartupComplete()");
    if (SALAMANDER_ROOT_REG == NULL)
        return;
    UpdiStarted = TRUE;
    CSalUpdArm arm;
    UpdInstall_LoadArm(&arm);
    CSalUpdVersion running;
    UpdateCheck_GetInstalledVersion(&running);
    BOOL eligible = UpdInstall_IsEligible(NULL);
    CSalUpdStartupArm decision = SalUpdStartupArmDecision(arm, UpdInstall_ArmHonoured(arm), UpdateTestMode, running, eligible);
    TRACE_I("UpdInstall: start-up decision about the armed update: " << SalUpdStartupArmName(decision)
                                                                       << " (launches " << arm.Launches << ")");
    switch (decision)
    {
    case susaDropAll:
    case susaDone:
        UpdInstall_DropArm();
        UpdiDeleteFiles(arm.Version);
        break;
    case susaDropState:
    case susaGiveUp:
        UpdInstall_DropArm();
        break;
    default:
        break;
    }

    // leftovers of the updates folder (data-model.md, Files)
    WCHAR folder[UPDINST_MAX_FOLDER];
    WCHAR pattern[UPDINST_MAX_FOLDER + 4];
    if (UpdiFolder(folder, _countof(folder), FALSE) &&
        _snwprintf_s(pattern, _countof(pattern), _TRUNCATE, L"%s\\*", folder) >= 0)
    {
        WIN32_FIND_DATAW fd;
        HANDLE find = NOHANDLES(FindFirstFileW(pattern, &fd));
        if (find != INVALID_HANDLE_VALUE)
        {
            do
            {
                if ((fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0)
                    continue;
                char nameA[MAX_PATH];
                int i = 0;
                for (; fd.cFileName[i] != 0 && i < MAX_PATH - 1; i++)
                {
                    if (fd.cFileName[i] >= 0x80)
                        break;
                    nameA[i] = (char)fd.cFileName[i];
                }
                if (fd.cFileName[i] != 0)
                    continue; // not a name of ours
                nameA[i] = 0;
                CSalUpdVersion v;
                CSalUpdFileKind kind;
                if (SalUpdParseUpdateFileName(nameA, &v, &kind) &&
                    !SalUpdKeepUpdateFile(kind, v, running, UpdateTestMode, decision == susaComplete, arm.Version))
                {
                    WCHAR path[UPDINST_MAX_FOLDER + MAX_PATH + 2];
                    if (_snwprintf_s(path, _countof(path), _TRUNCATE, L"%s\\%s", folder, fd.cFileName) >= 0)
                        DeleteFileW(path);
                }
            } while (FindNextFileW(find, &fd));
            NOHANDLES(FindClose(find));
        }
    }

    if (decision == susaComplete)
    {
        // Only the first instance completes: while another instance runs, the arm is its own
        // (made by it, for its exit) and the installer would close that instance's windows.
        if (UpdiLastInstance())
            PostMessage(mainWindow, WM_USER_UPDATEINSTALL, 0, 0); // the update the exit did not install
        else
            TRACE_I("UpdInstall: another instance runs - the armed update waits for the last exit");
    }
}

void UpdInstall_CompleteArmed(HWND parent)
{
    CALL_STACK_MESSAGE1("UpdInstall_CompleteArmed()");
    CSalUpdArm arm;
    if (!UpdInstall_LoadArm(&arm))
        return;
    WCHAR path[UPDINST_MAX_FOLDER + 100];
    HANDLE held = NULL;
    if (!UpdiInstallerPath(arm.Version, path, _countof(path)) ||
        UpdiVerify(path, arm.Version, arm.Digest, &held) != suvOk)
    {
        TRACE_I("UpdInstall: the armed installer is gone or not ours - the arm is dropped");
        UpdInstall_DropArm();
        UpdiDeleteFiles(arm.Version);
        return;
    }
    TRACE_I("UpdInstall: completing the update the exit did not install");
    UpdiWatchNotify = MainWindow != NULL ? MainWindow->HWindow : parent;
    DWORD error;
    if (!UpdiLaunch(sulkNow, arm.Version, held, TRUE, &error))
        UpdiReportRunError(parent, arm.Version, error);
}

// TRUE when no other process of this executable runs in this session (an inaccessible one of the
// session counts as running: the exit must not close a window the user still has)
static BOOL UpdiLastInstance()
{
    WCHAR exe[2048];
    DWORD n = GetModuleFileNameW(NULL, exe, _countof(exe));
    if (n == 0 || n >= _countof(exe) - 1)
        return FALSE;
    char exeU8[8200];
    if (SalWToU8(exe, -1, exeU8, sizeof(exeU8)) <= 0)
        return FALSE;
    const WCHAR* exeName = wcsrchr(exe, L'\\');
    exeName = exeName != NULL ? exeName + 1 : exe;
    DWORD self = GetCurrentProcessId();
    DWORD session = 0;
    if (!ProcessIdToSessionId(self, &session))
        return FALSE;
    HANDLE snap = NOHANDLES(CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0));
    if (snap == INVALID_HANDLE_VALUE)
        return FALSE;
    BOOL last = TRUE;
    PROCESSENTRY32W pe;
    pe.dwSize = sizeof(pe);
    for (BOOL more = Process32FirstW(snap, &pe); more && last; more = Process32NextW(snap, &pe))
    {
        DWORD otherSession = 0;
        if (pe.th32ProcessID == self || CompareStringOrdinal(pe.szExeFile, -1, exeName, -1, TRUE) != CSTR_EQUAL ||
            !ProcessIdToSessionId(pe.th32ProcessID, &otherSession) || otherSession != session)
            continue;
        HANDLE process = NOHANDLES(OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pe.th32ProcessID));
        if (process == NULL)
        {
            last = FALSE;
            continue;
        }
        WCHAR other[2048];
        DWORD otherLen = _countof(other);
        char otherU8[8200];
        if (!QueryFullProcessImageNameW(process, 0, other, &otherLen) ||
            SalWToU8(other, -1, otherU8, sizeof(otherU8)) <= 0 || SalPathEqualOrdinalCI(otherU8, exeU8))
            last = FALSE;
        NOHANDLES(CloseHandle(process));
    }
    NOHANDLES(CloseHandle(snap));
    return last;
}

static HANDLE UpdiExitHeld = NULL; // the verified installer, held from PrepareExit to RunAtExit
// TRUE: the main window was destroyed by an installer's close, a critical shutdown or a sign-out /
// shutdown of Windows (recorded by UpdInstall_Shutdown while those flags were still set)
static BOOL UpdiExitNotNormal = FALSE;
static CSalUpdVersion UpdiExitVersion;

void UpdInstall_PrepareExit()
{
    CALL_STACK_MESSAGE1("UpdInstall_PrepareExit()");
    UpdiExitHeld = NULL;
    if (SALAMANDER_ROOT_REG == NULL || !UpdiStarted)
        return;
    CSalUpdArm arm;
    if (!UpdInstall_LoadArm(&arm))
        return;
    CSalUpdVersion running;
    UpdateCheck_GetInstalledVersion(&running);
    BOOL normalExit = !UpdiExitNotNormal && !UnattendedClose && !CriticalShutdown && GetSystemMetrics(SM_SHUTTINGDOWN) == 0;
    BOOL honoured = UpdInstall_ArmHonoured(arm);
    BOOL eligible = UpdInstall_IsEligible(NULL);
    BOOL last = normalExit && honoured && eligible && UpdiLastInstance();
    BOOL install = SalUpdExitDecision(arm, honoured, normalExit, last, eligible, UpdateTestMode, running);
    TRACE_I("UpdInstall: at exit - normal " << normalExit << ", honoured " << honoured << ", last instance " << last
                                            << ", install " << install);
    if (!install)
        return;
    WCHAR path[UPDINST_MAX_FOLDER + 100];
    HANDLE held = NULL;
    if (!UpdiInstallerPath(arm.Version, path, _countof(path)) ||
        UpdiVerify(path, arm.Version, arm.Digest, &held) != suvOk)
    {
        UpdInstall_DropArm();
        UpdiDeleteFiles(arm.Version);
        return;
    }
    UpdiExitHeld = held;
    UpdiExitVersion = arm.Version;
}

void UpdInstall_RunAtExit()
{
    if (UpdiExitHeld == NULL)
        return;
    DWORD error;
    HANDLE held = UpdiExitHeld;
    UpdiExitHeld = NULL;
    UpdiLaunch(sulkExit, UpdiExitVersion, held, FALSE, &error); // a failure: the next start completes it
}

void UpdInstall_Shutdown()
{
    // The main window is being destroyed. Whether this exit is the user's is decided NOW: an
    // installer's close (feature 080) sets UnattendedClose only for the time of its WM_ENDSESSION
    // and resets it before the end of the exit runs PrepareExit - measured in the end-to-end run:
    // without this, the exit started a second installer while the first was installing.
    UpdiExitNotNormal = UnattendedClose || CriticalShutdown || GetSystemMetrics(SM_SHUTTINGDOWN) != 0;
    TRACE_I("UpdInstall: the main window closes; a user's exit: " << !UpdiExitNotNormal);
    UpdiWatchNotify = NULL;
    if (UpdiCSInitialized == 0)
        return;
    NOHANDLES(EnterCriticalSection(&UpdiCS));
    UpdiShutDown = TRUE;
    UpdiHasDone = FALSE;
    if (UpdiRunning != NULL)
    {
        UpdiRunning->Cancelled = TRUE;
        SetEvent(UpdiRunning->CancelEvent);
        UpdiRunning = NULL;
    }
    NOHANDLES(LeaveCriticalSection(&UpdiCS));
    // a cancelled worker abandons its request at once; the exit never waits for the network
    if (UpdiThread != NULL)
    {
        WaitForSingleObject(UpdiThread, 1500);
        AddAuxThread(UpdiThread);
        UpdiThread = NULL;
    }
}
