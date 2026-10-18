// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

// Feature 245: importing settings from Altap Salamander 2.5-4.0 and Open
// Salamander 5.0 - the engine (sources, snapshot, groups, plan, apply).
// See cfgimport.h and specs/245-settings-import-salamander/.

#include "precomp.h"

#include <tlhelp32.h>
#include <shlobj.h>

#include "cfgdlg.h"
#include "mainwnd.h"
#include "usermenu.h"
#include "plugins.h"
#include "fileswnd.h"
#include "find.h"
#include "viewer.h"
#include "pwdmngr.h"
#include "tasklist.h"
#include "salurlpwd.h"
#include "cfgimport.h"

BOOL CfgImpFreshConfigAtStart = FALSE;

// limits of the snapshot (research R1)
#define CFGIMP_MAX_DEPTH 8
#define CFGIMP_MAX_VALUE_BYTES (64 * 1024)
#define CFGIMP_MAX_TOTAL_BYTES (32 * 1024 * 1024)

static_assert(SALCFGIMP_HOTKEY_DIRTY == HOTKEY_DIRTY, "salcfgimport.h mirrors plugins.h");
static_assert(SALCFGIMP_UM_ITEM == umitItem && SALCFGIMP_UM_SUBMENUBEGIN == umitSubmenuBegin &&
                  SALCFGIMP_UM_SUBMENUEND == umitSubmenuEnd && SALCFGIMP_UM_SEPARATOR == umitSeparator,
              "salcfgimport.h mirrors usermenu.h");
static_assert(SALCFGIMP_HOTPATHS == HOT_PATHS_COUNT, "salcfgimport.h mirrors mainwnd.h");
static_assert(CFGIMP_LINE_ADDED == SALIMPORT_REPORT_ADDED && CFGIMP_LINE_NOTE == SALIMPORT_REPORT_NOTE,
              "line kinds are the plugin report kinds");

//
// ****************************************************************************
// helpers
//

// a growing UTF-8 text
class CCfgImpText
{
public:
    char* Buf;
    size_t Len;
    size_t Cap;
    BOOL Failed;

    CCfgImpText() : Buf(NULL), Len(0), Cap(0), Failed(FALSE) {}
    ~CCfgImpText() { free(Buf); }

    void Append(const char* s, size_t l)
    {
        if (Failed)
            return;
        if (Len + l + 1 > Cap)
        {
            size_t cap = Cap == 0 ? 1024 : Cap;
            while (Len + l + 1 > cap)
                cap *= 2;
            char* n = (char*)realloc(Buf, cap);
            if (n == NULL)
            {
                Failed = TRUE;
                return;
            }
            Buf = n;
            Cap = cap;
        }
        memcpy(Buf + Len, s, l);
        Len += l;
        Buf[Len] = 0;
    }
    void Append(const char* s) { Append(s, strlen(s)); }
    void AppendLine(const char* s)
    {
        Append(s);
        Append("\r\n", 2);
    }
    char* Detach()
    {
        if (Failed || Buf == NULL)
        {
            free(Buf);
            Buf = NULL;
            return DupStr("");
        }
        char* r = Buf;
        Buf = NULL;
        Len = Cap = 0;
        return r;
    }
};

// _snprintf_s into a heap string (UTF-8)
static char* CfgImpFormat(const char* fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    int l = _vscprintf(fmt, args);
    va_end(args);
    if (l < 0)
        return DupStr(fmt);
    char* s = (char*)malloc(l + 1);
    if (s == NULL)
        return NULL;
    va_start(args, fmt);
    vsprintf_s(s, l + 1, fmt, args);
    va_end(args);
    return s;
}

// copies a translated text (LoadStrU8 uses a rotating buffer)
static void CfgImpLoad(int id, char* buf, int size)
{
    lstrcpyn(buf, LoadStrU8(id), size);
}

static BOOL CfgImpContainsCI(const char* text, const char* what)
{
    if (text == NULL || what == NULL)
        return FALSE;
    size_t wl = strlen(what);
    const char* s;
    for (s = text; *s != 0; s++)
    {
        if (_strnicmp(s, what, wl) == 0)
            return TRUE;
    }
    return FALSE;
}

// the text of a hot key (UTF-8): "Ctrl+Shift+F"
static void CfgImpHotKeyText(WORD hotKey, char* buf, int size)
{
    buf[0] = 0;
    BYTE vk = LOBYTE(hotKey);
    BYTE mods = HIBYTE(hotKey);
    WCHAR w[200];
    w[0] = 0;
    const BYTE modKeys[3] = {VK_CONTROL, VK_SHIFT, VK_MENU};
    const BYTE modFlags[3] = {HOTKEYF_CONTROL, HOTKEYF_SHIFT, HOTKEYF_ALT};
    int i;
    for (i = 0; i < 3; i++)
    {
        if (mods & modFlags[i])
        {
            WCHAR k[50];
            if (GetKeyNameTextW((LONG)MapVirtualKeyW(modKeys[i], 0) << 16, k, 50) == 0)
                k[0] = 0;
            wcscat_s(w, k);
            wcscat_s(w, L"+");
        }
    }
    LONG scan = (LONG)MapVirtualKeyW(vk, 0) << 16;
    if (vk == VK_INSERT || vk == VK_DELETE || vk == VK_HOME || vk == VK_END || vk == VK_PRIOR || vk == VK_NEXT ||
        vk == VK_LEFT || vk == VK_RIGHT || vk == VK_UP || vk == VK_DOWN)
        scan |= 0x01000000; // extended key
    WCHAR k[50];
    if (GetKeyNameTextW(scan, k, 50) == 0)
        swprintf_s(k, L"#%u", (unsigned)vk);
    wcscat_s(w, k);
    if (SalWToU8(w, -1, buf, size) == 0)
        buf[0] = 0;
}

// a menu text without its '&' markers ("&&" stays one '&')
static void CfgImpStripAmp(const char* in, char* out, int size)
{
    int o = 0;
    const char* s;
    for (s = in != NULL ? in : ""; *s != 0 && o < size - 1; s++)
    {
        if (*s == '&')
        {
            if (s[1] != '&')
                continue;
            s++;
        }
        out[o++] = *s;
    }
    out[o] = 0;
}

// the label of a hot path for reports: "Name (path text)" or "path text"
static char* CfgImpHotPathLabel(const char* name, const char* storedPath)
{
    char* text = (char*)malloc(strlen(storedPath) + 1);
    if (text == NULL)
        return NULL;
    SalCfgImpUnescapeDollars(storedPath, text, (int)strlen(storedPath) + 1);
    char* r = (name != NULL && name[0] != 0) ? CfgImpFormat("%s (%s)", name, text) : DupStr(text);
    free(text);
    return r;
}

//
// ****************************************************************************
// CCfgImpGroup
//

class CCfgImpGroupData
{
public:
    virtual ~CCfgImpGroupData() {}
};

CCfgImpGroup::CCfgImpGroup() : Lines(16, 64)
{
    Id = cigHotPaths;
    PluginIndex = -1;
    PluginKey[0] = 0;
    Title[0] = 0;
    ListKind = TRUE;
    CanReplace = FALSE;
    Selected = FALSE;
    Mode = CFGIMP_MODE_ADD;
    ItemCount = 0;
    Availability = CFGIMP_AVAIL_YES;
    Reason[0] = 0;
    NeedsConsent = FALSE;
    Applied = FALSE;
    ApplyError[0] = 0;
    Data = NULL;
}

CCfgImpGroup::~CCfgImpGroup()
{
    ClearLines();
    delete Data;
}

void CCfgImpGroup::ClearLines()
{
    int i;
    for (i = 0; i < Lines.Count; i++)
        free(Lines[i].Text);
    Lines.DestroyMembers();
    NeedsConsent = FALSE;
}

void CCfgImpGroup::AddLine(int kind, const char* text)
{
    CCfgImpLine l;
    l.Kind = kind;
    l.Text = DupStr(text != NULL ? text : "");
    if (l.Text == NULL)
        return;
    Lines.Add(l);
    if (!Lines.IsGood())
    {
        Lines.ResetState();
        free(l.Text);
        return;
    }
    if (kind == CFGIMP_LINE_REPLACED || kind == CFGIMP_LINE_REMOVED)
        NeedsConsent = TRUE;
}

// adds a line made of a translated format and arguments
static void CfgImpAddLineF(CCfgImpGroup* g, int kind, int fmtId, ...)
{
    char fmt[1024];
    CfgImpLoad(fmtId, fmt, sizeof(fmt));
    va_list args;
    va_start(args, fmtId);
    int l = _vscprintf(fmt, args);
    va_end(args);
    if (l < 0)
    {
        g->AddLine(kind, fmt);
        return;
    }
    char* s = (char*)malloc(l + 1);
    if (s == NULL)
        return;
    va_start(args, fmtId);
    vsprintf_s(s, l + 1, fmt, args);
    va_end(args);
    g->AddLine(kind, s);
    free(s);
}

//
// ****************************************************************************
// sources
//

// reads the existence data of one root (KEY_READ only); FALSE when it is no configuration
static BOOL CfgImpReadRootInfo(const char* keyPath, CCfgImpSource* src)
{
    if (!SalCfgImpIsForeignRootAllowed(keyPath))
        return FALSE;
    WCHAR* wPath = SalU8ToWAlloc(keyPath);
    if (wPath == NULL)
        return FALSE;
    HKEY root;
    BOOL ok = FALSE;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, wPath, 0, KEY_READ, &root) == ERROR_SUCCESS)
    {
        HKEY cfg;
        if (RegOpenKeyExW(root, L"Configuration", 0, KEY_READ, &cfg) == ERROR_SUCCESS)
        {
            RegCloseKey(cfg);
            ok = TRUE;
            DWORD ver = 1; // the rules of LoadConfig: no "Version" key = 1
            HKEY verKey;
            if (RegOpenKeyExW(root, L"Version", 0, KEY_READ, &verKey) == ERROR_SUCCESS)
            {
                ver = 2; // no value = 2
                DWORD v, type, size = sizeof(v);
                if (RegQueryValueExW(verKey, L"Configuration", NULL, &type, (BYTE*)&v, &size) == ERROR_SUCCESS &&
                    type == REG_DWORD && size == sizeof(v))
                    ver = v;
                RegCloseKey(verKey);
            }
            src->ConfigVersion = ver;
            src->Support = SalCfgImpClassify(ver, THIS_CONFIG_VERSION);
            src->SaveInProgress = RegQueryValueExW(root, L"Save In Progress", NULL, NULL, NULL, NULL) == ERROR_SUCCESS;
            lstrcpyn(src->KeyPath, keyPath, (int)sizeof(src->KeyPath));
            if (!SalCfgImpProductName(keyPath, src->ProductName, (int)sizeof(src->ProductName)))
                lstrcpyn(src->ProductName, keyPath, (int)sizeof(src->ProductName));
        }
        RegCloseKey(root);
    }
    free(wPath);
    return ok;
}

#ifdef _DEBUG
// research R2: TC_CFGIMPORT_TEST_ROOT=<HKCU-relative key> - its subkeys are the sources (probes)
static BOOL CfgImpGetTestRoot(char* buf, int size)
{
    WCHAR w[1024];
    DWORD l = GetEnvironmentVariableW(L"TC_CFGIMPORT_TEST_ROOT", w, 1024);
    if (l == 0 || l >= 1024)
        return FALSE;
    return SalWToU8(w, -1, buf, size) != 0;
}
#endif

// calls 'fn' for every candidate root key path (the product table, or the test root's subkeys)
template <class F>
static void CfgImpForEachRoot(F fn)
{
#ifdef _DEBUG
    char testRoot[1024];
    if (CfgImpGetTestRoot(testRoot, (int)sizeof(testRoot)))
    {
        WCHAR* w = SalU8ToWAlloc(testRoot);
        HKEY parent;
        if (w != NULL && RegOpenKeyExW(HKEY_CURRENT_USER, w, 0, KEY_READ, &parent) == ERROR_SUCCESS)
        {
            WCHAR name[256];
            DWORD i;
            for (i = 0;; i++)
            {
                DWORD nl = 256;
                if (RegEnumKeyExW(parent, i, name, &nl, NULL, NULL, NULL, NULL) != ERROR_SUCCESS)
                    break;
                char u8[512];
                if (SalWToU8(name, -1, u8, (int)sizeof(u8)) == 0)
                    continue;
                char path[2048];
                _snprintf_s(path, _TRUNCATE, "%s\\%s", testRoot, u8);
                fn(path, (int)i);
            }
            RegCloseKey(parent);
        }
        free(w);
        return;
    }
#endif
    int i;
    for (i = 0; i < SalCfgImpRootCount(); i++)
        fn(SalCfgImpRoot(i), i);
}

BOOL CfgImpAnySupportedSourceExists()
{
    BOOL found = FALSE;
    CfgImpForEachRoot([&](const char* path, int order)
                      {
        if (found)
            return;
        CCfgImpSource s;
        memset(&s, 0, sizeof(s));
        if (CfgImpReadRootInfo(path, &s) && s.Support == SALCFGIMP_SUPPORTED)
            found = TRUE; });
    return found;
}

static BOOL CfgImpProcessRuns(const WCHAR* exeName)
{
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE)
        return FALSE;
    PROCESSENTRY32W pe;
    pe.dwSize = sizeof(pe);
    BOOL found = FALSE;
    if (Process32FirstW(snap, &pe))
    {
        do
        {
            if (_wcsicmp(pe.szExeFile, exeName) == 0)
            {
                found = TRUE;
                break;
            }
        } while (Process32NextW(snap, &pe));
    }
    CloseHandle(snap);
    return found;
}

BOOL CfgImpOtherInstanceRuns()
{
    CProcessListItem items[MAX_TL_ITEMS];
    DWORD uid;
    int c = TaskList.GetItems(items, &uid);
    DWORD self = GetCurrentProcessId();
    int i;
    for (i = 0; i < c; i++)
    {
        if (items[i].PID != self)
            return TRUE;
    }
    return FALSE;
}

BOOL CfgImpIsFreshConfiguration()
{
    if (SALAMANDER_ROOT_REG == NULL)
        return FALSE;
    char path[MAX_PATH + 50];
    _snprintf_s(path, _TRUNCATE, "%s\\Configuration", SALAMANDER_ROOT_REG);
    WCHAR* w = SalU8ToWAlloc(path);
    if (w == NULL)
        return FALSE;
    HKEY k;
    LONG res = RegOpenKeyExW(HKEY_CURRENT_USER, w, 0, KEY_READ, &k);
    free(w);
    if (res == ERROR_SUCCESS)
    {
        RegCloseKey(k);
        return FALSE;
    }
    return res == ERROR_FILE_NOT_FOUND;
}

//
// ****************************************************************************
// the snapshot reader (research R1): KEY_READ, wide API, limits, no message boxes
//

struct CCfgImpReadBudget
{
    SIZE_T Total;
    BOOL Truncated;
};

static BOOL CfgImpReadTree(HKEY key, CSalCfgKey* node, int depth, CCfgImpReadBudget* budget)
{
    DWORD subKeys = 0, maxSubKeyLen = 0, values = 0, maxValueNameLen = 0, maxValueLen = 0;
    if (RegQueryInfoKeyW(key, NULL, NULL, NULL, &subKeys, &maxSubKeyLen, NULL, &values, &maxValueNameLen,
                         &maxValueLen, NULL, NULL) != ERROR_SUCCESS)
        return FALSE;
    DWORD nameChars = maxValueNameLen + 2;
    if (maxSubKeyLen + 2 > nameChars)
        nameChars = maxSubKeyLen + 2;
    DWORD dataBytes = maxValueLen + 4;
    if (dataBytes > CFGIMP_MAX_VALUE_BYTES + 4)
        dataBytes = CFGIMP_MAX_VALUE_BYTES + 4;
    WCHAR* name = (WCHAR*)malloc(nameChars * sizeof(WCHAR));
    BYTE* data = (BYTE*)malloc(dataBytes);
    if (name == NULL || data == NULL)
    {
        free(name);
        free(data);
        return FALSE;
    }
    BOOL ok = TRUE;
    DWORD i;
    for (i = 0; i < values && ok; i++)
    {
        DWORD nl = nameChars;
        DWORD dl = dataBytes - 4;
        DWORD type = 0;
        LONG res = RegEnumValueW(key, i, name, &nl, NULL, &type, data, &dl);
        if (res == ERROR_MORE_DATA)
        {
            budget->Truncated = TRUE; // too large for the snapshot: left out (the group reports it)
            continue;
        }
        if (res == ERROR_NO_MORE_ITEMS)
            break;
        if (res != ERROR_SUCCESS)
        {
            budget->Truncated = TRUE;
            continue;
        }
        budget->Total += dl + nl * 2;
        if (budget->Total > CFGIMP_MAX_TOTAL_BYTES)
        {
            budget->Truncated = TRUE;
            ok = FALSE;
            break;
        }
        char* u8Name = SalWToU8Alloc(name, (int)nl);
        if (u8Name == NULL)
        {
            budget->Truncated = TRUE;
            continue;
        }
        BOOL added;
        if (type == REG_SZ || type == REG_EXPAND_SZ)
        {
            int chars = (int)(dl / sizeof(WCHAR));
            const WCHAR* w = (const WCHAR*)data;
            while (chars > 0 && w[chars - 1] == 0)
                chars--;
            char* u8 = chars > 0 ? SalWToU8Alloc(w, chars) : DupStr("");
            if (u8 == NULL)
            {
                budget->Truncated = TRUE;
                added = TRUE;
            }
            else
            {
                added = SalCfgKeyAddValue(node, u8Name, type, u8, (DWORD)strlen(u8) + 1);
                free(u8);
            }
        }
        else
            added = SalCfgKeyAddValue(node, u8Name, type, data, dl);
        free(u8Name);
        if (!added)
            ok = FALSE;
    }
    for (i = 0; i < subKeys && ok; i++)
    {
        DWORD nl = nameChars;
        LONG res = RegEnumKeyExW(key, i, name, &nl, NULL, NULL, NULL, NULL);
        if (res == ERROR_NO_MORE_ITEMS)
            break;
        if (res != ERROR_SUCCESS)
        {
            budget->Truncated = TRUE;
            continue;
        }
        char* u8Name = SalWToU8Alloc(name, (int)nl);
        if (u8Name == NULL)
        {
            budget->Truncated = TRUE;
            continue;
        }
        if (depth >= CFGIMP_MAX_DEPTH)
        {
            budget->Truncated = TRUE;
            free(u8Name);
            continue;
        }
        HKEY sub;
        if (RegOpenKeyExW(key, name, 0, KEY_READ, &sub) == ERROR_SUCCESS)
        {
            CSalCfgKey* child = SalCfgKeyAddKey(node, u8Name);
            if (child == NULL)
                ok = FALSE;
            else if (!CfgImpReadTree(sub, child, depth + 1, budget))
                ok = FALSE;
            RegCloseKey(sub);
        }
        else
            budget->Truncated = TRUE;
        free(u8Name);
    }
    free(name);
    free(data);
    return ok;
}

// reads HKCU\<keyPath> into a new snapshot; NULL on failure ('err' gets the system text)
static CSalCfgKey* CfgImpReadSnapshot(const char* keyPath, BOOL* truncated, char* err, int errSize)
{
    *truncated = FALSE;
    if (err != NULL && errSize > 0)
        err[0] = 0;
    WCHAR* w = SalU8ToWAlloc(keyPath);
    if (w == NULL)
        return NULL;
    HKEY root;
    LONG res = RegOpenKeyExW(HKEY_CURRENT_USER, w, 0, KEY_READ, &root);
    free(w);
    if (res != ERROR_SUCCESS)
    {
        if (err != NULL)
            lstrcpyn(err, GetErrorText(res), errSize);
        return NULL;
    }
    CSalCfgKey* tree = SalCfgKeyNew("");
    CCfgImpReadBudget budget;
    budget.Total = 0;
    budget.Truncated = FALSE;
    if (tree == NULL || !CfgImpReadTree(root, tree, 0, &budget))
    {
        if (err != NULL)
            lstrcpyn(err, LoadStrU8(IDS_CFGIMP_TRUNCATED), errSize);
        if (tree != NULL && budget.Truncated) // limits: keep what was read, groups report it
        {
            *truncated = TRUE;
            RegCloseKey(root);
            return tree;
        }
        SalCfgKeyFree(tree);
        RegCloseKey(root);
        return NULL;
    }
    RegCloseKey(root);
    *truncated = budget.Truncated;
    return tree;
}

//
// ****************************************************************************
// the read-only registry view over a snapshot node (handed to plugins, interface 108)
//

class CCfgImpSnapshotRegistry : public CSalamanderRegistryAbstract
{
protected:
    TDirectArray<CSalCfgKey*> Handles; // the nodes handed out (validates every handle)

    CSalCfgKey* Node(HKEY key)
    {
        int i;
        for (i = 0; i < Handles.Count; i++)
        {
            if ((HKEY)Handles[i] == key)
                return Handles[i];
        }
        return NULL;
    }

public:
    CCfgImpSnapshotRegistry() : Handles(16, 64) {}

    HKEY Root(CSalCfgKey* node)
    {
        if (node == NULL)
            return NULL;
        Handles.Add(node);
        return Handles.IsGood() ? (HKEY)node : NULL;
    }

    virtual BOOL WINAPI ClearKey(HKEY key) { return FALSE; }
    virtual BOOL WINAPI CreateKey(HKEY key, const char* name, HKEY& createdKey) { return FALSE; }
    virtual BOOL WINAPI OpenKey(HKEY key, const char* name, HKEY& openedKey)
    {
        CSalCfgKey* n = Node(key);
        if (n == NULL || name == NULL)
            return FALSE;
        CSalCfgKey* child = (CSalCfgKey*)SalCfgKeyFind(n, name);
        if (child == NULL)
            return FALSE;
        Handles.Add(child);
        if (!Handles.IsGood())
        {
            Handles.ResetState();
            return FALSE;
        }
        openedKey = (HKEY)child;
        return TRUE;
    }
    virtual void WINAPI CloseKey(HKEY key) {}
    virtual BOOL WINAPI DeleteKey(HKEY key, const char* name) { return FALSE; }
    virtual BOOL WINAPI GetValue(HKEY key, const char* name, DWORD type, void* buffer, DWORD bufferSize)
    {
        CSalCfgKey* n = Node(key);
        const CSalCfgValue* v = SalCfgValueFind(n, name);
        if (v == NULL || v->Type != type || buffer == NULL)
            return FALSE;
        DWORD size = v->Size;
        if (type == REG_SZ || type == REG_EXPAND_SZ)
            size = (DWORD)strlen((const char*)v->Data) + 1;
        if (size > bufferSize)
            return FALSE;
        memcpy(buffer, v->Data, size);
        return TRUE;
    }
    virtual BOOL WINAPI SetValue(HKEY key, const char* name, DWORD type, const void* data, DWORD dataSize) { return FALSE; }
    virtual BOOL WINAPI DeleteValue(HKEY key, const char* name) { return FALSE; }
    virtual BOOL WINAPI GetSize(HKEY key, const char* name, DWORD type, DWORD& bufferSize)
    {
        CSalCfgKey* n = Node(key);
        const CSalCfgValue* v = SalCfgValueFind(n, name);
        if (v == NULL || v->Type != type)
            return FALSE;
        bufferSize = (type == REG_SZ || type == REG_EXPAND_SZ) ? (DWORD)strlen((const char*)v->Data) + 1 : v->Size;
        return TRUE;
    }
};

//
// ****************************************************************************
// plugins of the source and of this program
//

// the source's plug-in registrations (parsed once per plan)
struct CCfgImpSrcPlugins
{
    CSalCfgImpPlugin* Items;
    int Count;
    CCfgImpSrcPlugins() : Items(NULL), Count(0) {}
    ~CCfgImpSrcPlugins() { SalCfgImpFreePlugins(Items, Count); }
    void Parse(const CSalCfgKey* snapshot)
    {
        SalCfgImpFreePlugins(Items, Count);
        Items = NULL;
        Count = SalCfgImpParsePlugins(SalCfgKeyFind(snapshot, "Plugins"), &Items);
    }
};

// this program's plug-in with the same DLL, -1 when none
static int CfgImpFindTCPlugin(const char* srcDll)
{
    if (srcDll == NULL || *srcDll == 0)
        return -1;
    int i;
    for (i = 0; i < Plugins.GetCount(); i++)
    {
        CPluginData* p = Plugins.Get(i);
        if (p != NULL && p->DLLName != NULL && SalCfgImpSameDll(srcDll, p->DLLName))
            return i;
    }
    return -1;
}

// the configuration key name of a source plug-in that maps to TC's plug-in 'tcIndex' ("" when none)
static const char* CfgImpSrcConfigKeyOf(CCfgImpSrcPlugins* sp, int tcIndex)
{
    int i;
    for (i = 0; i < sp->Count; i++)
    {
        if (sp->Items[i].ConfigKey[0] != 0 && CfgImpFindTCPlugin(sp->Items[i].DLL) == tcIndex)
            return sp->Items[i].ConfigKey;
    }
    return "";
}

static const char* CfgImpTCPluginName(int index)
{
    CPluginData* p = Plugins.Get(index);
    return (p != NULL && p->Name != NULL) ? p->Name : "?";
}

static BOOL CfgImpIsFTPDll(const char* dll) { return SalCfgImpSameDll(dll, "ftp\\ftp.spl"); }

//
// ****************************************************************************
// CCfgImpRun
//

CCfgImpRun::CCfgImpRun() : Sources(8, 8), Groups(16, 16)
{
    Chosen = -1;
    Snapshot = NULL;
    SnapshotTruncated = FALSE;
    memset(&Passwords, 0, sizeof(Passwords));
    Passwords.Policy = SALIMPORT_PWD_SCRAMBLED_ONLY;
    BackupFile[0] = 0;
    Automation = FALSE;
    ApplyDone = FALSE;
    SourceProgramRuns = FALSE;
}

CCfgImpRun::~CCfgImpRun()
{
    FreeSource();
}

void CCfgImpRun::FreeSource()
{
    Groups.DestroyMembers();
    SalCfgKeyFree(Snapshot);
    Snapshot = NULL;
    SnapshotTruncated = FALSE;
    if (Passwords.SourceMasterPassword != NULL)
    {
        SecureZeroMemory(Passwords.SourceMasterPassword, strlen(Passwords.SourceMasterPassword));
        free(Passwords.SourceMasterPassword);
    }
    memset(&Passwords, 0, sizeof(Passwords));
    Passwords.Policy = SALIMPORT_PWD_SCRAMBLED_ONLY;
}

BOOL CCfgImpRun::FindSources()
{
    Sources.DestroyMembers();
    CfgImpForEachRoot([&](const char* path, int order)
                      {
        CCfgImpSource s;
        memset(&s, 0, sizeof(s));
        if (CfgImpReadRootInfo(path, &s))
        {
            s.TableOrder = order;
            Sources.Add(s);
            if (!Sources.IsGood())
                Sources.ResetState();
        } });
    // newest first (insertion sort: a handful of entries)
    int i, j;
    for (i = 1; i < Sources.Count; i++)
    {
        CCfgImpSource s = Sources[i];
        for (j = i - 1; j >= 0 && SalCfgImpCompareSources(s.ConfigVersion, s.TableOrder, Sources[j].ConfigVersion,
                                                          Sources[j].TableOrder) < 0;
             j--)
            Sources[j + 1] = Sources[j];
        Sources[j + 1] = s;
    }
    SourceProgramRuns = CfgImpProcessRuns(L"salamand.exe");
    return TRUE;
}

BOOL CCfgImpRun::IsGroupSelected(CCfgImpGroupId id)
{
    int i;
    for (i = 0; i < Groups.Count; i++)
    {
        if (Groups[i]->Id == id && Groups[i]->Selected && Groups[i]->Availability == CFGIMP_AVAIL_YES)
            return TRUE;
    }
    return FALSE;
}

CCfgImpGroup* CCfgImpRun::FindGroup(CCfgImpGroupId id, int pluginIndex)
{
    int i;
    for (i = 0; i < Groups.Count; i++)
    {
        if (Groups[i]->Id == id && (pluginIndex < 0 || Groups[i]->PluginIndex == pluginIndex))
            return Groups[i];
    }
    return NULL;
}

// forward declarations of the group implementations (below)
static int CfgImpCountGroup(CCfgImpRun* run, CCfgImpGroup* g, CCfgImpSrcPlugins* sp);
static BOOL CfgImpPlanGroup(CCfgImpRun* run, CCfgImpGroup* g, CCfgImpSrcPlugins* sp, HWND parent);
static BOOL CfgImpApplyGroup(CCfgImpRun* run, CCfgImpGroup* g, HWND parent, BOOL* templatesChanged);

static CCfgImpGroup* CfgImpNewGroup(CCfgImpGroupId id, int titleId, BOOL listKind, BOOL canReplace, BOOL selected)
{
    CCfgImpGroup* g = new CCfgImpGroup;
    if (g == NULL)
        return NULL;
    g->Id = id;
    if (titleId != 0)
        CfgImpLoad(titleId, g->Title, (int)sizeof(g->Title));
    g->ListKind = listKind;
    g->CanReplace = canReplace;
    g->Selected = selected;
    g->Mode = listKind ? CFGIMP_MODE_ADD : CFGIMP_MODE_TAKEOVER;
    return g;
}

// TC's plug-ins whose whole settings can be taken over (research R8): shipped, not FTP, not TAR,
// with a configuration in the source
static BOOL CfgImpPluginSettingsCandidate(int tcIndex)
{
    CPluginData* p = Plugins.Get(tcIndex);
    if (p == NULL || !p->SupportLoadSave || p->DLLName == NULL)
        return FALSE;
    if (CfgImpIsFTPDll(p->DLLName) || SalCfgImpSameDll(p->DLLName, "tar\\tar.spl"))
        return FALSE;
    return TRUE;
}

BOOL CCfgImpRun::OpenSource(int index, char* err, int errSize)
{
    FreeSource();
    if (index < 0 || index >= Sources.Count || Sources[index].Support != SALCFGIMP_SUPPORTED)
        return FALSE;
    Chosen = index;
    Snapshot = CfgImpReadSnapshot(Sources[index].KeyPath, &SnapshotTruncated, err, errSize);
    if (Snapshot == NULL)
        return FALSE;

    struct
    {
        CCfgImpGroupId Id;
        int Title;
        BOOL List;
        BOOL Replace;
        BOOL Selected;
    } defs[] = {
        {cigHotPaths, IDS_CFGIMP_GRP_HOTPATHS, TRUE, TRUE, TRUE},
        {cigUserMenu, IDS_CFGIMP_GRP_USERMENU, TRUE, TRUE, TRUE},
        {cigFTP, IDS_CFGIMP_GRP_FTP, TRUE, TRUE, TRUE},
        {cigPluginKeys, IDS_CFGIMP_GRP_PLUGINKEYS, TRUE, TRUE, TRUE},
        {cigViewers, IDS_CFGIMP_GRP_VIEWERS, TRUE, FALSE, TRUE},
        {cigHistories, IDS_CFGIMP_GRP_HISTORIES, TRUE, FALSE, FALSE},
        {cigConfirmations, IDS_CFGIMP_GRP_CONFIRMATIONS, FALSE, FALSE, FALSE},
        {cigPanelOpts, IDS_CFGIMP_GRP_PANELOPTS, FALSE, FALSE, FALSE},
        {cigGeneral, IDS_CFGIMP_GRP_GENERAL, FALSE, FALSE, FALSE},
        {cigViewerOpts, IDS_CFGIMP_GRP_VIEWEROPTS, FALSE, FALSE, FALSE},
        {cigDefaultDirs, IDS_CFGIMP_GRP_DEFAULTDIRS, FALSE, FALSE, FALSE},
    };
    CCfgImpSrcPlugins sp;
    sp.Parse(Snapshot);
    int i;
    for (i = 0; i < (int)(sizeof(defs) / sizeof(defs[0])); i++)
    {
        CCfgImpGroup* g = CfgImpNewGroup(defs[i].Id, defs[i].Title, defs[i].List, defs[i].Replace, defs[i].Selected);
        if (g == NULL)
            return FALSE;
        Groups.Add(g);
        if (!Groups.IsGood())
        {
            Groups.ResetState();
            delete g;
            return FALSE;
        }
    }
    // one group per shipped plug-in with settings in the source
    const CSalCfgKey* pcfg = SalCfgKeyFind(Snapshot, "Plugins Configuration");
    for (i = 0; i < Plugins.GetCount(); i++)
    {
        if (!CfgImpPluginSettingsCandidate(i))
            continue;
        const char* key = CfgImpSrcConfigKeyOf(&sp, i);
        if (*key == 0 || SalCfgKeyFindChild(pcfg, key) == NULL)
            continue;
        CCfgImpGroup* g = CfgImpNewGroup(cigPluginSettings, 0, FALSE, FALSE, FALSE);
        if (g == NULL)
            return FALSE;
        g->PluginIndex = i;
        lstrcpyn(g->PluginKey, key, (int)sizeof(g->PluginKey));
        char fmt[200];
        CfgImpLoad(IDS_CFGIMP_GRP_PLUGIN, fmt, sizeof(fmt));
        _snprintf_s(g->Title, _TRUNCATE, fmt, CfgImpTCPluginName(i));
        Groups.Add(g);
        if (!Groups.IsGood())
        {
            Groups.ResetState();
            delete g;
            return FALSE;
        }
    }
    for (i = 0; i < Groups.Count; i++)
    {
        CCfgImpGroup* g = Groups[i];
        g->ItemCount = CfgImpCountGroup(this, g, &sp);
        if (g->Availability == CFGIMP_AVAIL_YES && g->ItemCount == 0)
        {
            g->Availability = CFGIMP_AVAIL_EMPTY;
            CfgImpLoad(IDS_CFGIMP_AVAIL_EMPTY, g->Reason, (int)sizeof(g->Reason));
        }
        if (g->Availability != CFGIMP_AVAIL_YES)
            g->Selected = FALSE;
    }
    CountFTPPasswords();
    return TRUE;
}

BOOL CCfgImpRun::Plan(HWND parent)
{
    CCfgImpSrcPlugins sp;
    sp.Parse(Snapshot);
    BOOL ok = TRUE;
    int i;
    for (i = 0; i < Groups.Count; i++)
    {
        CCfgImpGroup* g = Groups[i];
        g->ClearLines();
        delete g->Data;
        g->Data = NULL;
        g->Applied = FALSE;
        g->ApplyError[0] = 0;
        if (!g->Selected || g->Availability != CFGIMP_AVAIL_YES)
            continue;
        if (!CfgImpPlanGroup(this, g, &sp, parent))
            ok = FALSE;
    }
    return ok;
}

BOOL CCfgImpRun::NeedsConsent()
{
    int i;
    for (i = 0; i < Groups.Count; i++)
    {
        if (Groups[i]->Selected && Groups[i]->Availability == CFGIMP_AVAIL_YES && Groups[i]->NeedsConsent)
            return TRUE;
    }
    return FALSE;
}

// research R11: %APPDATA%\Tandem Commander\Settings backups\before-import-<stamp>[-n].reg (UTF-8 path)
static BOOL CfgImpMakeBackupName(char* buf, int size)
{
    PWSTR appData = NULL;
    if (FAILED(SHGetKnownFolderPath(FOLDERID_RoamingAppData, 0, NULL, &appData)) || appData == NULL)
        return FALSE;
    WCHAR dir[2 * MAX_PATH];
    swprintf_s(dir, L"%s\\Tandem Commander", appData);
    CoTaskMemFree(appData);
    CreateDirectoryW(dir, NULL);
    wcscat_s(dir, L"\\Settings backups");
    CreateDirectoryW(dir, NULL);
    DWORD attr = GetFileAttributesW(dir);
    if (attr == INVALID_FILE_ATTRIBUTES || (attr & FILE_ATTRIBUTE_DIRECTORY) == 0)
        return FALSE;
    SYSTEMTIME st;
    GetLocalTime(&st);
    int n;
    for (n = 1; n < 100; n++)
    {
        WCHAR file[3 * MAX_PATH];
        if (n == 1)
            swprintf_s(file, L"%s\\before-import-%04u%02u%02u-%02u%02u%02u.reg", dir, st.wYear, st.wMonth, st.wDay,
                       st.wHour, st.wMinute, st.wSecond);
        else
            swprintf_s(file, L"%s\\before-import-%04u%02u%02u-%02u%02u%02u-%d.reg", dir, st.wYear, st.wMonth,
                       st.wDay, st.wHour, st.wMinute, st.wSecond, n);
        if (GetFileAttributesW(file) == INVALID_FILE_ATTRIBUTES)
            return SalWToU8(file, -1, buf, size) != 0;
    }
    return FALSE;
}

BOOL CCfgImpRun::Apply(HWND parent, char* err, int errSize)
{
    err[0] = 0;
    if (CfgImpOtherInstanceRuns())
    {
        lstrcpyn(err, LoadStrU8(IDS_CFGIMP_OTHERINSTANCE), errSize);
        return FALSE;
    }
    // the backup reflects the stored configuration (what a restore brings back); a configuration
    // that was never saved is saved first, so the backup exists
    if (CfgImpIsFreshConfiguration())
        MainWindow->SaveConfig(parent);
    if (!CfgImpMakeBackupName(BackupFile, (int)sizeof(BackupFile)) ||
        !ExportConfiguration(parent, BackupFile, TRUE))
    {
        BackupFile[0] = 0;
        lstrcpyn(err, LoadStrU8(IDS_CFGIMP_BACKUPERR), errSize);
        return FALSE;
    }

    CCfgRefreshState oldState;
    oldState.Capture();
    BOOL templatesChanged = FALSE;
    BeginStopRefresh();
    int i;
    for (i = 0; i < Groups.Count; i++)
    {
        CCfgImpGroup* g = Groups[i];
        if (!g->Selected || g->Availability != CFGIMP_AVAIL_YES)
            continue;
        g->Applied = CfgImpApplyGroup(this, g, parent, &templatesChanged);
        if (!g->Applied && g->ApplyError[0] == 0)
            CfgImpLoad(IDS_CFGIMP_FAILEDGROUP, g->ApplyError, (int)sizeof(g->ApplyError));
    }
    MainWindow->RefreshAfterConfiguration(oldState, templatesChanged);
    EndStopRefresh();
    MainWindow->SaveConfig(parent);
    ApplyDone = TRUE;
    return TRUE;
}

char* CCfgImpRun::BuildText(BOOL result)
{
    CCfgImpText t;
    const char* product = (Chosen >= 0 && Chosen < Sources.Count) ? Sources[Chosen].ProductName : "";
    char buf[2048];
    _snprintf_s(buf, _TRUNCATE, LoadStrU8(result ? IDS_CFGIMP_RESULT_HDR : IDS_CFGIMP_PREVIEW_HDR), product);
    t.AppendLine(buf);
    if (result)
    {
        BOOL partial = FALSE;
        int i;
        for (i = 0; i < Groups.Count; i++)
        {
            if (Groups[i]->Selected && Groups[i]->Availability == CFGIMP_AVAIL_YES && !Groups[i]->Applied)
                partial = TRUE;
        }
        if (partial)
            t.AppendLine(LoadStrU8(IDS_CFGIMP_RESULT_PARTIAL));
    }
    if (SnapshotTruncated)
        t.AppendLine(LoadStrU8(IDS_CFGIMP_TRUNCATED));
    t.AppendLine(LoadStrU8(IDS_CFGIMP_LEGEND));
    int i;
    for (i = 0; i < Groups.Count; i++)
    {
        CCfgImpGroup* g = Groups[i];
        if (!g->Selected || g->Availability != CFGIMP_AVAIL_YES)
            continue;
        t.AppendLine("");
        char mode[100];
        CfgImpLoad(g->Mode == CFGIMP_MODE_REPLACE ? IDS_CFGIMP_MODE_REPLACE : g->Mode == CFGIMP_MODE_TAKEOVER ? IDS_CFGIMP_MODE_TAKEOVER
                                                                                                              : IDS_CFGIMP_MODE_ADD,
                   mode, sizeof(mode));
        char title[400];
        _snprintf_s(title, _TRUNCATE, "%s [%s]", g->Title, mode);
        if (result)
        {
            if (g->Applied)
                _snprintf_s(buf, _TRUNCATE, LoadStrU8(IDS_CFGIMP_HDR_APPLIED), title);
            else
                _snprintf_s(buf, _TRUNCATE, LoadStrU8(IDS_CFGIMP_HDR_FAILED), title, g->ApplyError);
            t.AppendLine(buf);
        }
        else
            t.AppendLine(title);
        if (g->Lines.Count == 0)
        {
            t.Append("    ");
            t.AppendLine(LoadStrU8(IDS_CFGIMP_NOTHING));
        }
        int j;
        for (j = 0; j < g->Lines.Count; j++)
        {
            static const char* marks[] = {"?", "+", "=", "~", "-", "x", "!", " "};
            int k = g->Lines[j].Kind;
            t.Append("  ");
            t.Append(k >= 1 && k <= 7 ? marks[k] : "?");
            t.Append(" ");
            t.AppendLine(g->Lines[j].Text);
        }
    }
    t.AppendLine("");
    // what is never imported (FR-013, FR-027)
    t.AppendLine(LoadStrU8(IDS_CFGIMP_ARCHIVERS));
    {
        CCfgImpSrcPlugins sp;
        sp.Parse(Snapshot);
        CCfgImpText names;
        int k;
        for (k = 0; k < sp.Count; k++)
        {
            if (sp.Items[k].DLL[0] == 0 || CfgImpFindTCPlugin(sp.Items[k].DLL) >= 0)
                continue;
            if (names.Len > 0)
                names.Append(", ");
            names.Append(sp.Items[k].Name[0] != 0 ? sp.Items[k].Name : sp.Items[k].DLL);
        }
        if (names.Len > 0 && !names.Failed)
        {
            char* line = CfgImpFormat(LoadStrU8(IDS_CFGIMP_NOTSHIPPED), names.Buf);
            if (line != NULL)
            {
                t.AppendLine(line);
                free(line);
            }
        }
    }
    if (result && BackupFile[0] != 0)
    {
        _snprintf_s(buf, _TRUNCATE, LoadStrU8(IDS_CFGIMP_BACKUPDONE), BackupFile);
        t.AppendLine(buf);
        _snprintf_s(buf, _TRUNCATE, LoadStrU8(IDS_CFGIMP_RESTORE), BackupFile);
        t.AppendLine(buf);
        t.AppendLine(LoadStrU8(IDS_CFGIMP_RESULT_SAVED));
    }
    else if (!result)
        t.AppendLine(LoadStrU8(IDS_CFGIMP_BACKUPNOTE));
    return t.Detach();
}

//
// ****************************************************************************
// passwords (research R10)
//

void CCfgImpRun::CountFTPPasswords()
{
    Passwords.ScrambledCount = Passwords.ProtectedCount = 0;
    const CSalCfgKey* pm = SalCfgKeyFind(Snapshot, "Password Manager");
    DWORD use = 0;
    Passwords.SourceUsesMasterPassword = SalCfgGetDword(pm, "Use Master Password", &use) && use != 0;
    DWORD vs = 0;
    const BYTE* ver = SalCfgGetBinary(pm, "Master Password Verifier", REG_BINARY, &vs);
    Passwords.SourceVerifierValid = ver != NULL && vs == sizeof(Passwords.SourceVerifier);
    if (Passwords.SourceVerifierValid)
        memcpy(Passwords.SourceVerifier, ver, sizeof(Passwords.SourceVerifier));
    CCfgImpGroup* g = FindGroup(cigFTP);
    if (g == NULL || g->PluginKey[0] == 0)
        return;
    char path[200];
    _snprintf_s(path, _TRUNCATE, "Plugins Configuration\\%s", g->PluginKey);
    const CSalCfgKey* ftp = SalCfgKeyFind(Snapshot, path);
    const char* lists[] = {"Bookmarks", "Proxy Servers"};
    // FTP stores "PasswordS" (scrambled, signature 1) or "PasswordE" (AES, signature 2) in both lists
    int l;
    for (l = 0; l < 2; l++)
    {
        const CSalCfgKey* list = SalCfgKeyFindChild(ftp, lists[l]);
        if (list == NULL)
            continue;
        int i;
        for (i = 0; i < list->KeyCount; i++)
        {
            int v;
            for (v = 0; v < list->Keys[i]->ValueCount; v++)
            {
                const CSalCfgValue* val = &list->Keys[i]->Values[v];
                if (val->Type != REG_BINARY || val->Size < 2 || _strnicmp(val->Name, "Password", 8) != 0)
                    continue;
                if (val->Data[0] == 2)
                    Passwords.ProtectedCount++;
                else if (val->Data[0] == 1)
                    Passwords.ScrambledCount++;
            }
        }
    }
}

BOOL CCfgImpRun::CheckSourceMasterPassword(const char* password)
{
    if (!Passwords.SourceVerifierValid || password == NULL || *password == 0)
        return FALSE;
    if (!PasswordManager.VerifyForeignMasterPassword(Passwords.SourceVerifier, (int)sizeof(Passwords.SourceVerifier),
                                                     password))
        return FALSE;
    if (Passwords.SourceMasterPassword != NULL)
    {
        SecureZeroMemory(Passwords.SourceMasterPassword, strlen(Passwords.SourceMasterPassword));
        free(Passwords.SourceMasterPassword);
    }
    Passwords.SourceMasterPassword = DupStr(password);
    return Passwords.SourceMasterPassword != NULL;
}

// the context handed to a plug-in's import handler (interface 108)
class CCfgImpPluginContext : public CSalamanderSettingsImportAbstract
{
public:
    CCfgImpRun* Run;
    CCfgImpGroup* Group;
    HWND Parent;
    CSalCfgKey* SourceKey;
    CCfgImpSnapshotRegistry Registry;

    CCfgImpPluginContext(CCfgImpRun* run, CCfgImpGroup* group, HWND parent, CSalCfgKey* sourceKey)
    {
        Run = run;
        Group = group;
        Parent = parent;
        SourceKey = sourceKey;
    }

    virtual int WINAPI GetMode() { return Group->Mode == CFGIMP_MODE_REPLACE ? SALIMPORT_MODE_REPLACE : SALIMPORT_MODE_ADD; }
    virtual const char* WINAPI GetSourceName() { return Run->Sources[Run->Chosen].ProductName; }
    virtual DWORD WINAPI GetSourceConfigVersion() { return Run->Sources[Run->Chosen].ConfigVersion; }
    virtual BOOL WINAPI GetSourceKey(HKEY* key, CSalamanderRegistryAbstract** registry)
    {
        if (key == NULL || registry == NULL || SourceKey == NULL)
            return FALSE;
        *key = Registry.Root(SourceKey);
        *registry = &Registry;
        return *key != NULL;
    }
    virtual void WINAPI Report(int kind, const char* text)
    {
        if (kind < SALIMPORT_REPORT_ADDED || kind > SALIMPORT_REPORT_NOTE)
            kind = SALIMPORT_REPORT_NOTE;
        Group->AddLine(kind, text);
    }
    virtual int WINAPI GetPasswordPolicy()
    {
        int p = Run->Passwords.Policy;
        // protected passwords would become scrambled without TC's master password: only with consent
        if (p == SALIMPORT_PWD_ALL && !PasswordManager.IsUsingMasterPassword() && !Run->Passwords.AllowWeakerStorage)
            p = SALIMPORT_PWD_SCRAMBLED_ONLY;
        if (p == SALIMPORT_PWD_ALL && Run->Passwords.SourceMasterPassword == NULL)
            p = SALIMPORT_PWD_SCRAMBLED_ONLY;
        return p;
    }
    virtual BOOL WINAPI DecryptSourcePassword(const BYTE* blob, int blobSize, char** plain)
    {
        if (plain != NULL)
            *plain = NULL;
        if (blob == NULL || blobSize < 2 || plain == NULL)
            return FALSE;
        int policy = GetPasswordPolicy();
        if (policy == SALIMPORT_PWD_NONE)
            return FALSE;
        BOOL aes = blob[0] == 2;
        if (aes && policy != SALIMPORT_PWD_ALL)
            return FALSE;
        return PasswordManager.DecryptWithMasterPassword(blob, blobSize, aes ? Run->Passwords.SourceMasterPassword : NULL,
                                                         plain);
    }
    virtual BOOL WINAPI EncryptForStorage(const char* plain, BYTE** blob, int* blobSize)
    {
        if (plain == NULL || blob == NULL || blobSize == NULL)
            return FALSE;
        *blob = NULL;
        *blobSize = 0;
        BOOL encrypt = PasswordManager.IsUsingMasterPassword();
        if (encrypt && !PasswordManager.IsMasterPasswordSet())
        {
            // AskForMasterPassword always shows its dialog, so it is called only when the program's
            // master password was not entered in this session yet - and once per import at most
            if (Run->Automation)
                return FALSE; // nobody to ask
            if (!Run->Passwords.AskedTCMasterPassword)
            {
                Run->Passwords.AskedTCMasterPassword = TRUE;
                Run->Passwords.TCMasterPasswordGiven = PasswordManager.AskForMasterPassword(Parent);
            }
            if (!Run->Passwords.TCMasterPasswordGiven || !PasswordManager.IsMasterPasswordSet())
                return FALSE;
        }
        return PasswordManager.EncryptPassword(plain, blob, blobSize, encrypt);
    }
};

//
// ****************************************************************************
// option groups: the allow-list (research R15, contracts/options-table.md)
//

enum CCfgImpOptKind
{
    cokBool,  // REG_DWORD, any non-zero = 1
    cokRange, // REG_DWORD in <Min, Max>
    cokMask,  // REG_DWORD taken as is
    cokNameFormat, // File Name Format: 2..7, 1 = 7 (LoadConfig's conversion)
};

struct CCfgImpOption
{
    CCfgImpGroupId Group;
    const char* SubKey; // relative to the source root
    const char* Name;
    CCfgImpOptKind Kind;
    int Min;
    int Max;
    int* Field;
};

#define CIO_C "Configuration"
#define CIO_CNF "Configuration\\Confirmation"
#define CIO_DRV "Configuration\\Drive Special Settings"
#define CIO_V "Viewer"

static CCfgImpOption CfgImpOptions[] = {
    // confirmations
    {cigConfirmations, CIO_CNF, "Files or Dirs Del", cokBool, 0, 1, &Configuration.CnfrmFileDirDel},
    {cigConfirmations, CIO_CNF, "Non-empty Dir Del", cokBool, 0, 1, &Configuration.CnfrmNEDirDel},
    {cigConfirmations, CIO_CNF, "File Overwrite", cokBool, 0, 1, &Configuration.CnfrmFileOver},
    {cigConfirmations, CIO_CNF, "Directory Overwrite", cokBool, 0, 1, &Configuration.CnfrmDirOver},
    {cigConfirmations, CIO_CNF, "SH File Del", cokBool, 0, 1, &Configuration.CnfrmSHFileDel},
    {cigConfirmations, CIO_CNF, "SH Dir Del", cokBool, 0, 1, &Configuration.CnfrmSHDirDel},
    {cigConfirmations, CIO_CNF, "SH File Overwrite", cokBool, 0, 1, &Configuration.CnfrmSHFileOver},
    {cigConfirmations, CIO_CNF, "NTFS Compress and Uncompress", cokBool, 0, 1, &Configuration.CnfrmNTFSPress},
    {cigConfirmations, CIO_CNF, "NTFS Encrypt and Decrypt", cokBool, 0, 1, &Configuration.CnfrmNTFSCrypt},
    {cigConfirmations, CIO_CNF, "Drag and Drop", cokBool, 0, 1, &Configuration.CnfrmDragDrop},
    {cigConfirmations, CIO_CNF, "Close Archive", cokBool, 0, 1, &Configuration.CnfrmCloseArchive},
    {cigConfirmations, CIO_CNF, "Close Find", cokBool, 0, 1, &Configuration.CnfrmCloseFind},
    {cigConfirmations, CIO_CNF, "Stop Find", cokBool, 0, 1, &Configuration.CnfrmStopFind},
    {cigConfirmations, CIO_CNF, "Create Target Path", cokBool, 0, 1, &Configuration.CnfrmCreatePath},
    {cigConfirmations, CIO_CNF, "Always on Top", cokBool, 0, 1, &Configuration.CnfrmAlwaysOnTop},
    {cigConfirmations, CIO_CNF, "Close Salamander", cokBool, 0, 1, &Configuration.CnfrmOnSalClose},
    {cigConfirmations, CIO_CNF, "Send Email", cokBool, 0, 1, &Configuration.CnfrmSendEmail},
    {cigConfirmations, CIO_CNF, "Add To Archive", cokBool, 0, 1, &Configuration.CnfrmAddToArchive},
    {cigConfirmations, CIO_CNF, "Create Dir", cokBool, 0, 1, &Configuration.CnfrmCreateDir},
    {cigConfirmations, CIO_CNF, "Change Dir TC", cokBool, 0, 1, &Configuration.CnfrmChangeDirTC},
    {cigConfirmations, CIO_CNF, "Show Names To Compare", cokBool, 0, 1, &Configuration.CnfrmShowNamesToCompare},
    {cigConfirmations, CIO_CNF, "DST Shifts Ignored", cokBool, 0, 1, &Configuration.CnfrmDSTShiftsIgnored},
    {cigConfirmations, CIO_CNF, "DST Shifts Occured", cokBool, 0, 1, &Configuration.CnfrmDSTShiftsOccured},
    {cigConfirmations, CIO_CNF, "Copy Move Options Not Supported", cokBool, 0, 1, &Configuration.CnfrmCopyMoveOptionsNS},
    // panel and keyboard behaviour
    {cigPanelOpts, CIO_C, "Select/Deselect Directories", cokBool, 0, 1, &Configuration.IncludeDirs},
    {cigPanelOpts, CIO_C, "Primary Context Menu", cokBool, 0, 1, &Configuration.PrimaryContextMenu},
    {cigPanelOpts, CIO_C, "Hide Hidden and System Files and Directories", cokBool, 0, 1, &Configuration.NotHiddenSystemFiles},
    {cigPanelOpts, CIO_C, "Single Click", cokBool, 0, 1, &Configuration.SingleClick},
    {cigPanelOpts, CIO_C, "Click to Quick Rename", cokBool, 0, 1, &Configuration.ClickQuickRename},
    {cigPanelOpts, CIO_C, "Quick Search Enter Alt", cokBool, 0, 1, &Configuration.QuickSearchEnterAlt},
    {cigPanelOpts, CIO_C, "Use Shift For GoTo HotPath", cokBool, 0, 1, &Configuration.ShiftForHotPaths},
    {cigPanelOpts, CIO_C, "Full Row Select", cokBool, 0, 1, &Configuration.FullRowSelect},
    {cigPanelOpts, CIO_C, "Full Row Highlight", cokBool, 0, 1, &Configuration.FullRowHighlight},
    {cigPanelOpts, CIO_C, "Use Icon Tincture", cokBool, 0, 1, &Configuration.UseIconTincture},
    {cigPanelOpts, CIO_C, "Show Panel Caption", cokBool, 0, 1, &Configuration.ShowPanelCaption},
    {cigPanelOpts, CIO_C, "Show Panel Zoom", cokBool, 0, 1, &Configuration.ShowPanelZoom},
    {cigPanelOpts, CIO_C, "Sort Uses Locale", cokBool, 0, 1, &Configuration.SortUsesLocale},
    {cigPanelOpts, CIO_C, "Sort Detects Numbers", cokBool, 0, 1, &Configuration.SortDetectNumbers},
    {cigPanelOpts, CIO_C, "Sort Newer On Top", cokBool, 0, 1, &Configuration.SortNewerOnTop},
    {cigPanelOpts, CIO_C, "Sort Dirs By Name", cokBool, 0, 1, &Configuration.SortDirsByName},
    {cigPanelOpts, CIO_C, "Sort Dirs By Ext", cokBool, 0, 1, &Configuration.SortDirsByExt},
    {cigPanelOpts, CIO_C, "Quick Rename Select All", cokBool, 0, 1, &Configuration.QuickRenameSelectAll},
    {cigPanelOpts, CIO_C, "Edit New File Select All", cokBool, 0, 1, &Configuration.EditNewSelectAll},
    {cigPanelOpts, CIO_C, "Use DragDrop Min Time", cokBool, 0, 1, &Configuration.UseDragDropMinTime},
    {cigPanelOpts, CIO_C, "DragDrop Min Time", cokRange, 0, 10000, &Configuration.DragDropMinTime},
    {cigPanelOpts, CIO_C, "File Name Format", cokNameFormat, 2, 7, &Configuration.FileNameFormat},
    {cigPanelOpts, CIO_C, "Size Format", cokRange, SIZE_FORMAT_BYTES, SIZE_FORMAT_MIXED, &Configuration.SizeFormat},
    {cigPanelOpts, CIO_C, "Thumbnail Size", cokRange, THUMBNAIL_SIZE_MIN, THUMBNAIL_SIZE_MAX, &Configuration.ThumbnailSize},
    // general options
    {cigGeneral, CIO_C, "Clear Readonly Attribute", cokBool, 0, 1, &Configuration.ClearReadOnly},
    {cigGeneral, CIO_C, "Close Shell Window", cokBool, 0, 1, &Configuration.CloseShell},
    {cigGeneral, CIO_C, "Status Area", cokBool, 0, 1, &Configuration.StatusArea},
    {cigGeneral, CIO_C, "Save History", cokBool, 0, 1, &Configuration.SaveHistory},
    {cigGeneral, CIO_C, "Save Working Dirs", cokBool, 0, 1, &Configuration.SaveWorkDirs},
    {cigGeneral, CIO_C, "Enable CmdLine History", cokBool, 0, 1, &Configuration.EnableCmdLineHistory},
    {cigGeneral, CIO_C, "Save CmdLine History", cokBool, 0, 1, &Configuration.SaveCmdLineHistory},
    {cigGeneral, CIO_C, "Show Errors In Find Files", cokBool, 0, 1, &Configuration.ShowGrepErrors},
    {cigGeneral, CIO_C, "Show Full Row In Find Files", cokBool, 0, 1, &Configuration.FindFullRowSelect},
    {cigGeneral, CIO_C, "Use Speeker Beep", cokBool, 0, 1, &Configuration.MinBeepWhenDone},
    {cigGeneral, CIO_C, "Copy Find Text", cokBool, 0, 1, &Configuration.CopyFindText},
    {cigGeneral, CIO_C, "Netware Fast Dir Move", cokBool, 0, 1, &Configuration.NetwareFastDirMove},
    {cigGeneral, CIO_C, "Async Copy Alg On Network", cokBool, 0, 1, &Configuration.UseAsyncCopyAlg},
    {cigGeneral, CIO_C, "Reload Environment Variables", cokBool, 0, 1, &Configuration.ReloadEnvVariables},
    {cigGeneral, CIO_C, "Title bar show path", cokBool, 0, 1, &Configuration.TitleBarShowPath},
    {cigGeneral, CIO_C, "Title bar mode", cokRange, TITLE_BAR_MODE_DIRECTORY, TITLE_BAR_MODE_FULLPATH, &Configuration.TitleBarMode},
    {cigGeneral, CIO_C, "Title bar prefix", cokBool, 0, 1, &Configuration.UseTitleBarPrefix},
    {cigGeneral, CIO_C, "Change Drive Show My Documents", cokBool, 0, 1, &Configuration.ChangeDriveShowMyDoc},
    {cigGeneral, CIO_C, "Change Drive Show Another", cokBool, 0, 1, &Configuration.ChangeDriveShowAnother},
    {cigGeneral, CIO_C, "Change Drive Show Cloud Storages", cokBool, 0, 1, &Configuration.ChangeDriveCloudStorage},
    {cigGeneral, CIO_C, "Change Drive Network", cokBool, 0, 1, &Configuration.ChangeDriveShowNet},
    {cigGeneral, CIO_C, "Visible Drives", cokMask, 0, 0, (int*)&Configuration.VisibleDrives},
    {cigGeneral, CIO_C, "Separated Drives", cokMask, 0, 0, (int*)&Configuration.SeparatedDrives},
    {cigGeneral, CIO_C, "Compare By Time", cokBool, 0, 1, &Configuration.CompareByTime},
    {cigGeneral, CIO_C, "Compare By Size", cokBool, 0, 1, &Configuration.CompareBySize},
    {cigGeneral, CIO_C, "Compare By Content", cokBool, 0, 1, &Configuration.CompareByContent},
    {cigGeneral, CIO_C, "Compare By Attr", cokBool, 0, 1, &Configuration.CompareByAttr},
    {cigGeneral, CIO_C, "Compare By Subdirs", cokBool, 0, 1, &Configuration.CompareSubdirs},
    {cigGeneral, CIO_C, "Compare By Subdirs Attr", cokBool, 0, 1, &Configuration.CompareSubdirsAttr},
    {cigGeneral, CIO_C, "Compare One Panel Dirs", cokBool, 0, 1, &Configuration.CompareOnePanelDirs},
    {cigGeneral, CIO_C, "Compare More Options", cokBool, 0, 1, &Configuration.CompareMoreOptions},
    {cigGeneral, CIO_C, "Compare Ignore Files", cokBool, 0, 1, &Configuration.CompareIgnoreFiles},
    {cigGeneral, CIO_C, "Compare Ignore Dirs", cokBool, 0, 1, &Configuration.CompareIgnoreDirs},
    {cigGeneral, CIO_C, "Use Time Resolution", cokBool, 0, 1, &Configuration.UseTimeResolution},
    {cigGeneral, CIO_C, "Time Resolution", cokRange, 0, 3600, &Configuration.TimeResolution},
    {cigGeneral, CIO_C, "Ignore DST Shifts", cokBool, 0, 1, &Configuration.IgnoreDSTShifts},
    {cigGeneral, CIO_C, "Keep Plugins Sorted", cokBool, 0, 1, &Configuration.KeepPluginsSorted},
    {cigGeneral, CIO_C, "Use Recycle Bin", cokRange, 0, 2, &Configuration.UseRecycleBin},
    {cigGeneral, CIO_DRV, "Floppy Automatic Refresh", cokBool, 0, 1, &Configuration.DrvSpecFloppyMon},
    {cigGeneral, CIO_DRV, "Floppy Simple Icons", cokBool, 0, 1, &Configuration.DrvSpecFloppySimple},
    {cigGeneral, CIO_DRV, "Removable Automatic Refresh", cokBool, 0, 1, &Configuration.DrvSpecRemovableMon},
    {cigGeneral, CIO_DRV, "Removable Simple Icons", cokBool, 0, 1, &Configuration.DrvSpecRemovableSimple},
    {cigGeneral, CIO_DRV, "Fixed Automatic Refresh", cokBool, 0, 1, &Configuration.DrvSpecFixedMon},
    {cigGeneral, CIO_DRV, "Fixed Simple Icons", cokBool, 0, 1, &Configuration.DrvSpecFixedSimple},
    {cigGeneral, CIO_DRV, "Remote Automatic Refresh", cokBool, 0, 1, &Configuration.DrvSpecRemoteMon},
    {cigGeneral, CIO_DRV, "Remote Simple Icons", cokBool, 0, 1, &Configuration.DrvSpecRemoteSimple},
    {cigGeneral, CIO_DRV, "Remote Do Not Refresh on Activation", cokBool, 0, 1, &Configuration.DrvSpecRemoteDoNotRefreshOnAct},
    {cigGeneral, CIO_DRV, "CDROM Automatic Refresh", cokBool, 0, 1, &Configuration.DrvSpecCDROMMon},
    {cigGeneral, CIO_DRV, "CDROM Simple Icons", cokBool, 0, 1, &Configuration.DrvSpecCDROMSimple},
    // internal viewer
    {cigViewerOpts, CIO_V, "EOL CRLF", cokBool, 0, 1, &Configuration.EOL_CRLF},
    {cigViewerOpts, CIO_V, "EOL CR", cokBool, 0, 1, &Configuration.EOL_CR},
    {cigViewerOpts, CIO_V, "EOL LF", cokBool, 0, 1, &Configuration.EOL_LF},
    {cigViewerOpts, CIO_V, "EOL NULL", cokBool, 0, 1, &Configuration.EOL_NULL},
    {cigViewerOpts, CIO_V, "Wrap Text", cokBool, 0, 1, &Configuration.WrapText},
    {cigViewerOpts, CIO_V, "Auto-Select", cokBool, 0, 1, &Configuration.CodePageAutoSelect},
    {cigViewerOpts, CIO_V, "Auto-Copy Selection", cokBool, 0, 1, &Configuration.AutoCopySelection},
    {cigViewerOpts, CIO_V, "Go to Offset Is Hex", cokBool, 0, 1, &Configuration.GoToOffsetIsHex},
    {cigViewerOpts, CIO_V, "Tabelator Size", cokRange, 1, 30, &Configuration.TabSize},
    {cigViewerOpts, CIO_V, "Default Mode", cokRange, 0, 2, &Configuration.DefViewMode},
};

// the table's own consistency (also mirrored by saltests): no TC-owned value is ever on it
static BOOL CfgImpOptionTableIsClean()
{
    int i;
    for (i = 0; i < (int)(sizeof(CfgImpOptions) / sizeof(CfgImpOptions[0])); i++)
    {
        const char* sub = CfgImpOptions[i].SubKey;
        if (SalCfgImpIsForbiddenOption(strcmp(sub, CIO_V) == 0 ? "Viewer" : strcmp(sub, CIO_C) == 0 ? "Configuration"
                                                                                                    : sub,
                                       CfgImpOptions[i].Name))
        {
            TRACE_E("CfgImpOptionTableIsClean(): forbidden option on the table: " << CfgImpOptions[i].Name);
            return FALSE;
        }
    }
    return TRUE;
}

// the value the program would use (normalised) or FALSE when the source value is unusable;
// '*present' FALSE when the source has no such value (then no line at all)
static BOOL CfgImpOptionValue(const CSalCfgKey* snapshot, const CCfgImpOption* o, DWORD* value, BOOL* present)
{
    const CSalCfgKey* k = SalCfgKeyFind(snapshot, o->SubKey);
    const CSalCfgValue* v = SalCfgValueFind(k, o->Name);
    *present = v != NULL;
    if (v == NULL)
        return FALSE;
    DWORD d;
    if (!SalCfgGetDword(k, o->Name, &d))
        return FALSE; // another type
    switch (o->Kind)
    {
    case cokBool:
        *value = d != 0 ? 1 : 0;
        return TRUE;
    case cokRange:
        if ((int)d < o->Min || (int)d > o->Max)
            return FALSE;
        *value = d;
        return TRUE;
    case cokMask:
        *value = d;
        return TRUE;
    case cokNameFormat:
        if (d == 1)
            d = 7;
        if ((int)d < o->Min || (int)d > o->Max)
            return FALSE;
        *value = d;
        return TRUE;
    }
    return FALSE;
}

struct CCfgImpOptAssign
{
    int Row;
    DWORD Value;
};

class CCfgImpOptionsData : public CCfgImpGroupData
{
public:
    TDirectArray<CCfgImpOptAssign> Assign;
    CCfgImpOptionsData() : Assign(16, 32) {}
};

static int CfgImpCountOptions(CCfgImpRun* run, CCfgImpGroup* g)
{
    int n = 0;
    int i;
    for (i = 0; i < (int)(sizeof(CfgImpOptions) / sizeof(CfgImpOptions[0])); i++)
    {
        if (CfgImpOptions[i].Group != g->Id)
            continue;
        DWORD v;
        BOOL present;
        CfgImpOptionValue(run->Snapshot, &CfgImpOptions[i], &v, &present);
        if (present)
            n++;
    }
    return n;
}

static BOOL CfgImpPlanOptions(CCfgImpRun* run, CCfgImpGroup* g)
{
    if (!CfgImpOptionTableIsClean())
        return FALSE;
    CCfgImpOptionsData* data = new CCfgImpOptionsData;
    if (data == NULL)
        return FALSE;
    g->Data = data;
    int i;
    for (i = 0; i < (int)(sizeof(CfgImpOptions) / sizeof(CfgImpOptions[0])); i++)
    {
        const CCfgImpOption* o = &CfgImpOptions[i];
        if (o->Group != g->Id)
            continue;
        DWORD v;
        BOOL present;
        if (!CfgImpOptionValue(run->Snapshot, o, &v, &present))
        {
            if (present)
                CfgImpAddLineF(g, CFGIMP_LINE_SKIPPED, IDS_CFGIMP_LN_BADVALUE, o->Name);
            continue;
        }
        DWORD cur = (DWORD)*o->Field;
        if (o->Kind == cokBool)
            cur = cur != 0 ? 1 : 0;
        if (cur == v)
            continue; // the same value: nothing to change
        char a[32], b[32];
        _snprintf_s(a, _TRUNCATE, "%u", cur);
        _snprintf_s(b, _TRUNCATE, "%u", v);
        CfgImpAddLineF(g, CFGIMP_LINE_REPLACED, IDS_CFGIMP_LN_VALUE, o->Name, a, b);
        CCfgImpOptAssign as;
        as.Row = i;
        as.Value = v;
        data->Assign.Add(as);
        if (!data->Assign.IsGood())
        {
            data->Assign.ResetState();
            return FALSE;
        }
    }
    return TRUE;
}

static BOOL CfgImpApplyOptions(CCfgImpRun* run, CCfgImpGroup* g)
{
    CCfgImpOptionsData* data = (CCfgImpOptionsData*)g->Data;
    if (data == NULL)
        return FALSE;
    int i;
    for (i = 0; i < data->Assign.Count; i++)
        *CfgImpOptions[data->Assign[i].Row].Field = (int)data->Assign[i].Value;
    return TRUE;
}

//
// ****************************************************************************
// default directories of drives
//

class CCfgImpDefDirsData : public CCfgImpGroupData
{
public:
    char Dirs[26][MAX_PATH];
    BOOL Changed[26];
    CCfgImpDefDirsData() { memset(Changed, 0, sizeof(Changed)); }
};

static int CfgImpCountDefaultDirs(CCfgImpRun* run)
{
    const CSalCfgKey* k = SalCfgKeyFind(run->Snapshot, "Default Directories");
    return k != NULL ? k->ValueCount : 0;
}

static BOOL CfgImpPlanDefaultDirs(CCfgImpRun* run, CCfgImpGroup* g)
{
    CCfgImpDefDirsData* data = new CCfgImpDefDirsData;
    if (data == NULL)
        return FALSE;
    g->Data = data;
    const CSalCfgKey* k = SalCfgKeyFind(run->Snapshot, "Default Directories");
    if (k == NULL)
        return TRUE;
    int i;
    for (i = 0; i < k->ValueCount; i++)
    {
        const CSalCfgValue* v = &k->Values[i];
        const char* s = (v->Type == REG_SZ || v->Type == REG_EXPAND_SZ) ? (const char*)v->Data : NULL;
        if (s == NULL || !SalCfgImpDefaultDirValid(v->Name, s, MAX_PATH))
        {
            CfgImpAddLineF(g, CFGIMP_LINE_SKIPPED, IDS_CFGIMP_LN_BADVALUE, v->Name);
            continue;
        }
        int d = (v->Name[0] | 0x20) - 'a';
        const char* cur = DefaultDir[d];
        BOOL curSet = strlen(cur) > 3; // " :\" or "X:\" = nothing remembered
        if (SalPathEqualOrdinalCI(cur, s))
            continue;
        lstrcpyn(data->Dirs[d], s, MAX_PATH);
        data->Changed[d] = TRUE;
        if (curSet)
            CfgImpAddLineF(g, CFGIMP_LINE_REPLACED, IDS_CFGIMP_LN_VALUE, v->Name, cur, s);
        else
            g->AddLine(CFGIMP_LINE_ADDED, s);
    }
    return TRUE;
}

static BOOL CfgImpApplyDefaultDirs(CCfgImpRun* run, CCfgImpGroup* g)
{
    CCfgImpDefDirsData* data = (CCfgImpDefDirsData*)g->Data;
    if (data == NULL)
        return FALSE;
    int d;
    for (d = 0; d < 26; d++)
    {
        if (data->Changed[d])
            lstrcpyn(DefaultDir[d], data->Dirs[d], MAX_PATH);
    }
    return TRUE;
}

//
// ****************************************************************************
// hot paths
//

class CCfgImpHotPathsData : public CCfgImpGroupData
{
public:
    CSalCfgImpHotPath Slots[HOT_PATHS_COUNT]; // the new content of changed slots
    BOOL Changed[HOT_PATHS_COUNT];
    CCfgImpHotPathsData()
    {
        memset(Slots, 0, sizeof(Slots));
        memset(Changed, 0, sizeof(Changed));
    }
    ~CCfgImpHotPathsData() { SalCfgImpFreeHotPaths(Slots, HOT_PATHS_COUNT); }
};

static int CfgImpCountHotPaths(CCfgImpRun* run)
{
    CSalCfgImpHotPath hp[HOT_PATHS_COUNT];
    memset(hp, 0, sizeof(hp));
    int n = SalCfgImpParseHotPaths(SalCfgKeyFind(run->Snapshot, "Hot Paths"), run->Sources[run->Chosen].ConfigVersion,
                                   MAX_PATH, HOTPATHITEM_MAXPATH, hp);
    int i;
    for (i = 0; i < HOT_PATHS_COUNT; i++)
    {
        if (hp[i].TooLong)
            n++; // reported, so it counts
    }
    SalCfgImpFreeHotPaths(hp, HOT_PATHS_COUNT);
    return n;
}

// the same stored path (trailing backslash ignored, the file system's case rule)
static BOOL CfgImpSameHotPath(const char* a, const char* b)
{
    char ta[HOTPATHITEM_MAXPATH], tb[HOTPATHITEM_MAXPATH];
    if (!SalCfgImpTrimTrailingSlash(a, ta, HOTPATHITEM_MAXPATH) || !SalCfgImpTrimTrailingSlash(b, tb, HOTPATHITEM_MAXPATH))
        return strcmp(a, b) == 0;
    return SalPathEqualOrdinalCI(ta, tb);
}

// the reason to flag a stored hot path or command (0 = none)
static int CfgImpFlagPath(const char* text)
{
    if (CfgImpContainsCI(text, "$(SalDir)"))
        return IDS_CFGIMP_LN_SALDIR;
    if (CfgImpContainsCI(text, "\\Altap Salamander") || CfgImpContainsCI(text, "\\Open Salamander") ||
        CfgImpContainsCI(text, "\\Servant Salamander") || CfgImpContainsCI(text, "salamand.exe"))
        return IDS_CFGIMP_LN_OLDFOLDER;
    return 0;
}

static BOOL CfgImpPlanHotPaths(CCfgImpRun* run, CCfgImpGroup* g)
{
    CCfgImpHotPathsData* data = new CCfgImpHotPathsData;
    if (data == NULL)
        return FALSE;
    g->Data = data;
    CSalCfgImpHotPath src[HOT_PATHS_COUNT];
    memset(src, 0, sizeof(src));
    SalCfgImpParseHotPaths(SalCfgKeyFind(run->Snapshot, "Hot Paths"), run->Sources[run->Chosen].ConfigVersion, MAX_PATH,
                           HOTPATHITEM_MAXPATH, src);
    char curPath[HOTPATHITEM_MAXPATH];
    char curName[MAX_PATH];
    BOOL occupied[HOT_PATHS_COUNT];
    int i;
    for (i = 0; i < HOT_PATHS_COUNT; i++)
        occupied[i] = MainWindow->HotPaths.GetPathLen(i) > 0;

    if (g->Mode == CFGIMP_MODE_REPLACE)
    {
        for (i = 0; i < HOT_PATHS_COUNT; i++)
        {
            MainWindow->HotPaths.GetPath(i, curPath, HOTPATHITEM_MAXPATH);
            MainWindow->HotPaths.GetName(i, curName, MAX_PATH);
            if (src[i].TooLong)
            {
                char num[16];
                _snprintf_s(num, _TRUNCATE, "#%d", i + 1);
                CfgImpAddLineF(g, CFGIMP_LINE_SKIPPED, IDS_CFGIMP_LN_TOOLONG, num);
            }
            BOOL srcUsed = src[i].Used;
            if (occupied[i] && srcUsed && CfgImpSameHotPath(curPath, src[i].Path) && strcmp(curName, src[i].Name) == 0 &&
                MainWindow->HotPaths.GetVisible(i) == src[i].Visible)
            {
                char* label = CfgImpHotPathLabel(src[i].Name, src[i].Path);
                g->AddLine(CFGIMP_LINE_PRESENT, label);
                free(label);
                continue;
            }
            if (!occupied[i] && !srcUsed)
                continue;
            data->Changed[i] = TRUE;
            data->Slots[i].Visible = srcUsed ? src[i].Visible : TRUE;
            data->Slots[i].Name = DupStr(srcUsed ? src[i].Name : "");
            data->Slots[i].Path = DupStr(srcUsed ? src[i].Path : "");
            data->Slots[i].Used = srcUsed;
            char* curLabel = occupied[i] ? CfgImpHotPathLabel(curName, curPath) : NULL;
            char* newLabel = srcUsed ? CfgImpHotPathLabel(src[i].Name, src[i].Path) : NULL;
            if (occupied[i] && srcUsed)
            {
                char* t = CfgImpFormat("%s -> %s", curLabel != NULL ? curLabel : "", newLabel != NULL ? newLabel : "");
                g->AddLine(CFGIMP_LINE_REPLACED, t);
                free(t);
            }
            else if (occupied[i])
                g->AddLine(CFGIMP_LINE_REMOVED, curLabel);
            else
            {
                int flag = CfgImpFlagPath(src[i].Path);
                if (flag != 0)
                    CfgImpAddLineF(g, CFGIMP_LINE_FLAGGED, flag, newLabel != NULL ? newLabel : "");
                else
                    g->AddLine(CFGIMP_LINE_ADDED, newLabel);
            }
            free(curLabel);
            free(newLabel);
        }
        SalCfgImpFreeHotPaths(src, HOT_PATHS_COUNT);
        return TRUE;
    }

    // Add: current slots stay; new paths go to their slot when free, else the first free slot
    for (i = 0; i < HOT_PATHS_COUNT; i++)
    {
        if (src[i].TooLong)
        {
            char num[16];
            _snprintf_s(num, _TRUNCATE, "#%d", i + 1);
            CfgImpAddLineF(g, CFGIMP_LINE_SKIPPED, IDS_CFGIMP_LN_TOOLONG, num);
            continue;
        }
        if (!src[i].Used)
            continue;
        char* label = CfgImpHotPathLabel(src[i].Name, src[i].Path);
        BOOL present = FALSE;
        int j;
        for (j = 0; j < HOT_PATHS_COUNT && !present; j++)
        {
            if (data->Changed[j])
                present = CfgImpSameHotPath(data->Slots[j].Path, src[i].Path);
            else if (occupied[j])
            {
                MainWindow->HotPaths.GetPath(j, curPath, HOTPATHITEM_MAXPATH);
                present = CfgImpSameHotPath(curPath, src[i].Path);
            }
        }
        if (present)
        {
            g->AddLine(CFGIMP_LINE_PRESENT, label);
            free(label);
            continue;
        }
        int slot = SalCfgImpPlaceHotPath(occupied, HOT_PATHS_COUNT, i);
        if (slot < 0)
        {
            CfgImpAddLineF(g, CFGIMP_LINE_SKIPPED, IDS_CFGIMP_LN_NOSLOT, label != NULL ? label : "");
            free(label);
            continue;
        }
        occupied[slot] = TRUE;
        data->Changed[slot] = TRUE;
        data->Slots[slot].Used = TRUE;
        data->Slots[slot].Visible = src[i].Visible;
        data->Slots[slot].Name = DupStr(src[i].Name);
        data->Slots[slot].Path = DupStr(src[i].Path);
        char* text = slot != i ? NULL : DupStr(label != NULL ? label : "");
        if (slot != i)
        {
            char fmt[300];
            CfgImpLoad(IDS_CFGIMP_LN_SLOTMOVED, fmt, sizeof(fmt));
            text = CfgImpFormat(fmt, label != NULL ? label : "", slot + 1, i + 1);
        }
        int flag = CfgImpFlagPath(src[i].Path);
        if (flag != 0)
            CfgImpAddLineF(g, CFGIMP_LINE_FLAGGED, flag, text != NULL ? text : "");
        else
            g->AddLine(CFGIMP_LINE_ADDED, text);
        free(text);
        free(label);
    }
    SalCfgImpFreeHotPaths(src, HOT_PATHS_COUNT);
    return TRUE;
}

static BOOL CfgImpApplyHotPaths(CCfgImpRun* run, CCfgImpGroup* g)
{
    CCfgImpHotPathsData* data = (CCfgImpHotPathsData*)g->Data;
    if (data == NULL)
        return FALSE;
    int i;
    for (i = 0; i < HOT_PATHS_COUNT; i++)
    {
        if (!data->Changed[i])
            continue;
        CSalCfgImpHotPath* s = &data->Slots[i];
        MainWindow->HotPaths.Set(i, s->Name != NULL ? s->Name : "", s->Path != NULL ? s->Path : "", s->Visible);
        MainWindow->HotPaths.SetIconIndex(i, 0);
    }
    return TRUE;
}

//
// ****************************************************************************
// user menu
//

class CCfgImpUserMenuData : public CCfgImpGroupData
{
public:
    CSalCfgImpMenuItem* NewMenu; // the complete new menu
    int NewCount;
    CCfgImpUserMenuData() : NewMenu(NULL), NewCount(0) {}
    ~CCfgImpUserMenuData() { SalCfgImpFreeMenu(NewMenu, NewCount); }
};

static int CfgImpCountUserMenu(CCfgImpRun* run)
{
    CSalCfgImpMenuItem* items = NULL;
    int stop;
    int c = SalCfgImpParseUserMenu(SalCfgKeyFind(run->Snapshot, "User Menu"), MAX_PATH, USRMNUARGS_MAXLEN, &items, &stop);
    int n = 0;
    int i;
    for (i = 0; i < c; i++)
    {
        if (items[i].Type == SALCFGIMP_UM_ITEM || items[i].Type == SALCFGIMP_UM_SUBMENUBEGIN)
            n++;
    }
    SalCfgImpFreeMenu(items, c);
    return n + (stop != 0 ? 1 : 0);
}

// the records of the program's current user menu (allocated copies)
static int CfgImpCurrentUserMenu(CSalCfgImpMenuItem** out)
{
    CUserMenuItems* um = MainWindow->UserMenuItems;
    *out = (CSalCfgImpMenuItem*)calloc(um->Count + 1, sizeof(CSalCfgImpMenuItem));
    if (*out == NULL)
        return -1;
    int i;
    for (i = 0; i < um->Count; i++)
    {
        CUserMenuItem* it = um->At(i);
        CSalCfgImpMenuItem* r = &(*out)[i];
        r->Name = DupStr(it->ItemName != NULL ? it->ItemName : "");
        r->Command = DupStr(it->UMCommand != NULL ? it->UMCommand : "");
        r->Arguments = DupStr(it->Arguments != NULL ? it->Arguments : "");
        r->InitDir = DupStr(it->InitDir != NULL ? it->InitDir : "");
        r->Icon = DupStr(it->Icon != NULL ? it->Icon : "");
        r->ThroughShell = it->ThroughShell;
        r->CloseShell = it->CloseShell;
        r->UseWindow = it->UseWindow;
        r->ShowInToolbar = it->ShowInToolbar;
        r->Type = (DWORD)it->Type;
        if (r->Name == NULL || r->Command == NULL || r->Arguments == NULL || r->InitDir == NULL || r->Icon == NULL)
        {
            SalCfgImpFreeMenu(*out, i + 1);
            *out = NULL;
            return -1;
        }
    }
    return um->Count;
}

static BOOL CfgImpCopyMenuItem(CSalCfgImpMenuItem* dst, const CSalCfgImpMenuItem* src)
{
    *dst = *src;
    dst->Name = DupStr(src->Name);
    dst->Command = DupStr(src->Command);
    dst->Arguments = DupStr(src->Arguments);
    dst->InitDir = DupStr(src->InitDir);
    dst->Icon = DupStr(src->Icon);
    return dst->Name != NULL && dst->Command != NULL && dst->Arguments != NULL && dst->InitDir != NULL && dst->Icon != NULL;
}

// the reason a menu item's command should be checked (0 = none); 'prog' gets the program
static int CfgImpFlagCommand(const char* command, char* prog, int progSize)
{
    prog[0] = 0;
    if (command == NULL || *command == 0)
        return 0;
    int flag = CfgImpFlagPath(command);
    if (flag != 0)
        return flag;
    // an absolute program path without variables that does not exist
    const char* s = command;
    char path[MAX_PATH];
    if (*s == '"')
    {
        const char* e = strchr(s + 1, '"');
        int l = e != NULL ? (int)(e - s - 1) : (int)strlen(s + 1);
        if (l >= MAX_PATH)
            return 0;
        memcpy(path, s + 1, l);
        path[l] = 0;
    }
    else
        lstrcpyn(path, s, MAX_PATH);
    if (strchr(path, '$') != NULL || strchr(path, '%') != NULL)
        return 0;
    BOOL absolute = (path[0] != 0 && path[1] == ':' && path[2] == '\\') || (path[0] == '\\' && path[1] == '\\');
    if (!absolute)
        return 0;
    if (SalGetFileAttributes(path) == INVALID_FILE_ATTRIBUTES)
    {
        lstrcpyn(prog, path, progSize);
        return IDS_CFGIMP_LN_NOPROGRAM;
    }
    return 0;
}

// adds the report line of one menu block (its first entry) with a possible flag
static void CfgImpMenuLine(CCfgImpGroup* g, int kind, const CSalCfgImpMenuItem* items, int start, int end)
{
    char name[MAX_PATH];
    CfgImpStripAmp(items[start].Name, name, MAX_PATH);
    if (kind == CFGIMP_LINE_ADDED)
    {
        int i;
        for (i = start; i < end; i++)
        {
            char prog[MAX_PATH];
            int flag = CfgImpFlagCommand(items[i].Command, prog, MAX_PATH);
            if (flag == IDS_CFGIMP_LN_NOPROGRAM)
            {
                CfgImpAddLineF(g, CFGIMP_LINE_FLAGGED, flag, name, prog);
                return;
            }
            if (flag != 0)
            {
                CfgImpAddLineF(g, CFGIMP_LINE_FLAGGED, flag, name);
                return;
            }
        }
    }
    g->AddLine(kind, name);
}

static BOOL CfgImpPlanUserMenu(CCfgImpRun* run, CCfgImpGroup* g)
{
    CCfgImpUserMenuData* data = new CCfgImpUserMenuData;
    if (data == NULL)
        return FALSE;
    g->Data = data;
    CSalCfgImpMenuItem* src = NULL;
    int stop = 0;
    int srcCount = SalCfgImpParseUserMenu(SalCfgKeyFind(run->Snapshot, "User Menu"), MAX_PATH, USRMNUARGS_MAXLEN, &src,
                                          &stop);
    CSalCfgImpMenuItem* cur = NULL;
    int curCount = CfgImpCurrentUserMenu(&cur);
    if (curCount < 0)
    {
        SalCfgImpFreeMenu(src, srcCount);
        return FALSE;
    }
    BOOL ok = TRUE;
    data->NewMenu = (CSalCfgImpMenuItem*)calloc(curCount + srcCount + 1, sizeof(CSalCfgImpMenuItem));
    if (data->NewMenu == NULL)
        ok = FALSE;
    if (ok && g->Mode == CFGIMP_MODE_REPLACE)
    {
        // the new menu = the source's; report removed / added / unchanged top-level blocks
        int c = 0;
        while (c < curCount)
        {
            int ce = SalCfgImpMenuBlockEnd(cur, curCount, c);
            if (cur[c].Type == SALCFGIMP_UM_ITEM || cur[c].Type == SALCFGIMP_UM_SUBMENUBEGIN)
            {
                BOOL inSrc = FALSE;
                int s = 0;
                while (s < srcCount && !inSrc)
                {
                    int se = SalCfgImpMenuBlockEnd(src, srcCount, s);
                    inSrc = SalCfgImpMenuBlockEqual(cur, c, ce, src, s, se);
                    s = se;
                }
                if (!inSrc)
                {
                    char name[MAX_PATH];
                    CfgImpStripAmp(cur[c].Name, name, MAX_PATH);
                    g->AddLine(CFGIMP_LINE_REMOVED, name);
                }
            }
            c = ce;
        }
        int s = 0;
        while (s < srcCount)
        {
            int se = SalCfgImpMenuBlockEnd(src, srcCount, s);
            if (src[s].Type == SALCFGIMP_UM_ITEM || src[s].Type == SALCFGIMP_UM_SUBMENUBEGIN)
            {
                BOOL inCur = FALSE;
                int c2 = 0;
                while (c2 < curCount && !inCur)
                {
                    int ce = SalCfgImpMenuBlockEnd(cur, curCount, c2);
                    inCur = SalCfgImpMenuBlockEqual(cur, c2, ce, src, s, se);
                    c2 = ce;
                }
                CfgImpMenuLine(g, inCur ? CFGIMP_LINE_PRESENT : CFGIMP_LINE_ADDED, src, s, se);
            }
            s = se;
        }
        int i;
        for (i = 0; i < srcCount && ok; i++)
        {
            if (!CfgImpCopyMenuItem(&data->NewMenu[data->NewCount++], &src[i]))
                ok = FALSE;
        }
    }
    else if (ok)
    {
        int* decision = (int*)malloc((srcCount + 1) * sizeof(int));
        if (decision == NULL)
            ok = FALSE;
        else
        {
            SalCfgImpPlanUserMenuAdd(cur, curCount, src, srcCount, decision);
            int i;
            for (i = 0; i < curCount && ok; i++)
            {
                if (!CfgImpCopyMenuItem(&data->NewMenu[data->NewCount++], &cur[i]))
                    ok = FALSE;
            }
            BOOL appendingBlock = FALSE;
            for (i = 0; i < srcCount && ok; i++)
            {
                int d = decision[i];
                if (d != SALCFGIMP_UMD_INBLOCK)
                    appendingBlock = d == SALCFGIMP_UMD_APPEND;
                if (d == SALCFGIMP_UMD_APPEND || (d == SALCFGIMP_UMD_INBLOCK && appendingBlock))
                {
                    if (!CfgImpCopyMenuItem(&data->NewMenu[data->NewCount++], &src[i]))
                        ok = FALSE;
                }
                if (src[i].Type == SALCFGIMP_UM_ITEM || src[i].Type == SALCFGIMP_UM_SUBMENUBEGIN)
                {
                    if (d == SALCFGIMP_UMD_APPEND)
                        CfgImpMenuLine(g, CFGIMP_LINE_ADDED, src, i, SalCfgImpMenuBlockEnd(src, srcCount, i));
                    else if (d == SALCFGIMP_UMD_PRESENT)
                    {
                        char name[MAX_PATH];
                        CfgImpStripAmp(src[i].Name, name, MAX_PATH);
                        g->AddLine(CFGIMP_LINE_PRESENT, name);
                    }
                }
            }
            free(decision);
        }
    }
    if (stop != 0)
        g->AddLine(CFGIMP_LINE_SKIPPED, LoadStrU8(IDS_CFGIMP_LN_STOPPED));
    SalCfgImpFreeMenu(src, srcCount);
    SalCfgImpFreeMenu(cur, curCount);
    return ok;
}

static BOOL CfgImpApplyUserMenu(CCfgImpRun* run, CCfgImpGroup* g)
{
    CCfgImpUserMenuData* data = (CCfgImpUserMenuData*)g->Data;
    if (data == NULL || data->NewMenu == NULL)
        return FALSE;
    CUserMenuItems* tmp = new CUserMenuItems(50, 10);
    CUserMenuIconDataArr* collect = new CUserMenuIconDataArr(); // the icons are read by LoadUMI below
    if (tmp == NULL || collect == NULL)
    {
        delete tmp;
        delete collect;
        return FALSE;
    }
    BOOL ok = TRUE;
    int i;
    for (i = 0; i < data->NewCount && ok; i++)
    {
        CSalCfgImpMenuItem* r = &data->NewMenu[i];
        CUserMenuItem* item = new CUserMenuItem(r->Name, r->Command, r->Arguments, r->InitDir, r->Icon, r->ThroughShell,
                                                r->CloseShell, r->UseWindow, r->ShowInToolbar,
                                                (CUserMenuItemType)r->Type, collect);
        if (item == NULL || !item->IsGood())
        {
            delete item;
            ok = FALSE;
            break;
        }
        tmp->Add(item);
        if (!tmp->IsGood())
        {
            tmp->ResetState();
            delete item;
            ok = FALSE;
        }
    }
    if (ok)
        ok = MainWindow->UserMenuItems->LoadUMI(*tmp, TRUE);
    delete tmp;
    delete collect;
    return ok;
}

//
// ****************************************************************************
// viewers, alternative viewers, editors (Add only, research R5/R7)
//

struct CCfgImpViewerList
{
    const char* Key;
    BOOL Editors;
};

static const CCfgImpViewerList CfgImpViewerLists[3] = {
    {"Viewers", FALSE}, {"Alternative Viewers", FALSE}, {"Editors", TRUE}};

class CCfgImpViewersData : public CCfgImpGroupData
{
public:
    CViewerMasks* Viewers[2]; // the complete new lists
    CEditorMasks* Editors;
    CCfgImpViewersData()
    {
        Viewers[0] = Viewers[1] = NULL;
        Editors = NULL;
    }
    ~CCfgImpViewersData()
    {
        delete Viewers[0];
        delete Viewers[1];
        delete Editors;
    }
};

static int CfgImpCountViewers(CCfgImpRun* run)
{
    int n = 0;
    int l;
    for (l = 0; l < 3; l++)
    {
        CSalCfgImpViewer* rows = NULL;
        int stop;
        int c = SalCfgImpParseViewers(SalCfgKeyFind(run->Snapshot, CfgImpViewerLists[l].Key), CfgImpViewerLists[l].Editors,
                                      run->Sources[run->Chosen].ConfigVersion, MAX_PATH, &rows, &stop);
        n += c + (stop != 0 ? 1 : 0);
        SalCfgImpFreeViewers(rows, c);
    }
    return n;
}

static BOOL CfgImpIsCatchAll(const char* masks)
{
    char key[MAX_PATH];
    return SalCfgImpMasksKey(masks, key, MAX_PATH) && (strcmp(key, "*") == 0 || strcmp(key, "*.*") == 0);
}

static BOOL CfgImpPlanViewers(CCfgImpRun* run, CCfgImpGroup* g, CCfgImpSrcPlugins* sp)
{
    CCfgImpViewersData* data = new CCfgImpViewersData;
    if (data == NULL)
        return FALSE;
    g->Data = data;
    data->Viewers[0] = new CViewerMasks(10, 5);
    data->Viewers[1] = new CViewerMasks(10, 5);
    data->Editors = new CEditorMasks(10, 5);
    if (data->Viewers[0] == NULL || data->Viewers[1] == NULL || data->Editors == NULL)
        return FALSE;
    MainWindow->EnterViewerMasksCS();
    BOOL ok = data->Viewers[0]->Load(*MainWindow->ViewerMasks);
    MainWindow->LeaveViewerMasksCS();
    ok = ok && data->Viewers[1]->Load(*MainWindow->AltViewerMasks) && data->Editors->Load(*MainWindow->EditorMasks);
    if (!ok)
        return FALSE;
    int l;
    for (l = 0; l < 3; l++)
    {
        CSalCfgImpViewer* rows = NULL;
        int stop = 0;
        int c = SalCfgImpParseViewers(SalCfgKeyFind(run->Snapshot, CfgImpViewerLists[l].Key), CfgImpViewerLists[l].Editors,
                                      run->Sources[run->Chosen].ConfigVersion, MAX_PATH, &rows, &stop);
        // insertion point: before the current catch-all row ("*.*"), else at the end
        int count = l < 2 ? data->Viewers[l]->Count : data->Editors->Count;
        int insertAt = count;
        int i;
        for (i = 0; i < count; i++)
        {
            const char* m = l < 2 ? data->Viewers[l]->At(i)->Masks->GetMasksString() : data->Editors->At(i)->Masks->GetMasksString();
            if (CfgImpIsCatchAll(m))
            {
                insertAt = i;
                break;
            }
        }
        for (i = 0; i < c && ok; i++)
        {
            CSalCfgImpViewer* r = &rows[i];
            char key[MAX_PATH];
            if (!SalCfgImpMasksKey(r->Masks, key, MAX_PATH))
                key[0] = 0;
            // already covered: the same masks in the current list
            BOOL covered = FALSE;
            int n = l < 2 ? data->Viewers[l]->Count : data->Editors->Count;
            int j;
            for (j = 0; j < n && !covered; j++)
            {
                char k2[MAX_PATH];
                const char* m = l < 2 ? data->Viewers[l]->At(j)->Masks->GetMasksString() : data->Editors->At(j)->Masks->GetMasksString();
                covered = SalCfgImpMasksKey(m, k2, MAX_PATH) && strcmp(k2, key) == 0;
            }
            char label[2 * MAX_PATH];
            if (r->Type < 0 && l < 2)
            {
                int srcIndex = -r->Type - 1;
                const char* srcDll = (srcIndex >= 0 && srcIndex < sp->Count) ? sp->Items[srcIndex].DLL : "";
                const char* srcName = (srcIndex >= 0 && srcIndex < sp->Count && sp->Items[srcIndex].Name[0] != 0) ? sp->Items[srcIndex].Name : srcDll;
                int tc = CfgImpFindTCPlugin(srcDll);
                CPluginData* p = tc >= 0 ? Plugins.Get(tc) : NULL;
                _snprintf_s(label, _TRUNCATE, "%s: %s", r->Masks, srcName);
                if (p == NULL || !p->SupportViewer)
                {
                    CfgImpAddLineF(g, CFGIMP_LINE_SKIPPED, IDS_CFGIMP_LN_NOPLUGIN, r->Masks, srcName);
                    continue;
                }
                r->Type = -(tc + 1);
                _snprintf_s(label, _TRUNCATE, "%s: %s", r->Masks, p->Name);
            }
            else if (l < 2 && r->Type != VIEWER_EXTERNAL && r->Type != VIEWER_INTERNAL)
            {
                CfgImpAddLineF(g, CFGIMP_LINE_SKIPPED, IDS_CFGIMP_LN_BADVALUE, r->Masks);
                continue;
            }
            else if (r->Command[0] != 0)
                _snprintf_s(label, _TRUNCATE, "%s: %s", r->Masks, r->Command);
            else
                lstrcpyn(label, r->Masks, (int)sizeof(label));
            if (covered)
            {
                CfgImpAddLineF(g, CFGIMP_LINE_PRESENT, IDS_CFGIMP_LN_COVERED, label);
                continue;
            }
            if (l < 2)
            {
                CViewerMasksItem* item = new CViewerMasksItem(r->Masks, r->Command, r->Arguments, r->InitDir, r->Type, FALSE);
                if (item == NULL || !item->IsGood())
                {
                    delete item;
                    ok = FALSE;
                    break;
                }
                data->Viewers[l]->Insert(insertAt, item);
                if (!data->Viewers[l]->IsGood())
                {
                    data->Viewers[l]->ResetState();
                    delete item;
                    ok = FALSE;
                    break;
                }
            }
            else
            {
                CEditorMasksItem* item = new CEditorMasksItem(r->Masks, r->Command, r->Arguments, r->InitDir);
                if (item == NULL || !item->IsGood())
                {
                    delete item;
                    ok = FALSE;
                    break;
                }
                data->Editors->Insert(insertAt, item);
                if (!data->Editors->IsGood())
                {
                    data->Editors->ResetState();
                    delete item;
                    ok = FALSE;
                    break;
                }
            }
            insertAt++;
            char prog[MAX_PATH];
            int flag = r->Type == VIEWER_EXTERNAL || l == 2 ? CfgImpFlagCommand(r->Command, prog, MAX_PATH) : 0;
            if (flag == IDS_CFGIMP_LN_NOPROGRAM)
                CfgImpAddLineF(g, CFGIMP_LINE_FLAGGED, flag, label, prog);
            else if (flag != 0)
                CfgImpAddLineF(g, CFGIMP_LINE_FLAGGED, flag, label);
            else
                g->AddLine(CFGIMP_LINE_ADDED, label);
        }
        if (stop != 0)
            g->AddLine(CFGIMP_LINE_SKIPPED, LoadStrU8(IDS_CFGIMP_LN_STOPPED));
        SalCfgImpFreeViewers(rows, c);
    }
    return ok;
}

static BOOL CfgImpApplyViewers(CCfgImpRun* run, CCfgImpGroup* g)
{
    CCfgImpViewersData* data = (CCfgImpViewersData*)g->Data;
    if (data == NULL || data->Viewers[0] == NULL || data->Viewers[1] == NULL || data->Editors == NULL)
        return FALSE;
    // swap the lists (each swap is complete or does not happen)
    MainWindow->EnterViewerMasksCS();
    CViewerMasks* old = MainWindow->ViewerMasks;
    MainWindow->ViewerMasks = data->Viewers[0];
    data->Viewers[0] = old;
    MainWindow->LeaveViewerMasksCS();
    old = MainWindow->AltViewerMasks;
    MainWindow->AltViewerMasks = data->Viewers[1];
    data->Viewers[1] = old;
    CEditorMasks* oldE = MainWindow->EditorMasks;
    MainWindow->EditorMasks = data->Editors;
    data->Editors = oldE;
    return TRUE;
}

//
// ****************************************************************************
// shortcuts of plugin commands (research R5)
//

struct CCfgImpKeyAssign
{
    int Plugin; // TC plug-in index
    int Item;   // index in its MenuItems
    DWORD HotKey; // new value (with HOTKEY_DIRTY), or HOTKEY_DIRTY alone = removed
};

class CCfgImpKeysData : public CCfgImpGroupData
{
public:
    TDirectArray<CCfgImpKeyAssign> Assign;
    CCfgImpKeysData() : Assign(16, 16) {}
};

static int CfgImpFindMenuItem(CPluginData* p, DWORD id)
{
    int i;
    for (i = 0; i < p->MenuItems.Count; i++)
    {
        CPluginMenuItem* it = p->MenuItems[i];
        if (it->Name != NULL && (DWORD)it->ID == id)
            return i;
    }
    return -1;
}

static int CfgImpCountPluginKeys(CCfgImpRun* run, CCfgImpSrcPlugins* sp)
{
    int n = 0;
    int i, k;
    for (i = 0; i < sp->Count; i++)
    {
        for (k = 0; k < sp->Items[i].KeyCount; k++)
        {
            if (sp->Items[i].Keys[k].HotKey & HOTKEY_DIRTY)
                n++;
        }
    }
    return n;
}

static BOOL CfgImpPlanPluginKeys(CCfgImpRun* run, CCfgImpGroup* g, CCfgImpSrcPlugins* sp)
{
    CCfgImpKeysData* data = new CCfgImpKeysData;
    if (data == NULL)
        return FALSE;
    g->Data = data;
    int i, k;
    for (i = 0; i < sp->Count; i++)
    {
        CSalCfgImpPlugin* sp1 = &sp->Items[i];
        for (k = 0; k < sp1->KeyCount; k++)
        {
            CSalCfgImpPluginKey* key = &sp1->Keys[k];
            if ((key->HotKey & HOTKEY_DIRTY) == 0)
                continue; // predefined by the plug-in, not the user's
            WORD hk = HOTKEY_GET(key->HotKey);
            char keyText[100];
            CfgImpHotKeyText(hk, keyText, sizeof(keyText));
            char label[MAX_PATH + 200];
            char itemName[MAX_PATH];
            CfgImpStripAmp(key->Name, itemName, MAX_PATH);
            _snprintf_s(label, _TRUNCATE, "%s / %s (%s)", sp1->Name[0] != 0 ? sp1->Name : sp1->DLL, itemName, keyText);
            int tc = CfgImpFindTCPlugin(sp1->DLL);
            CPluginData* p = tc >= 0 ? Plugins.Get(tc) : NULL;
            if (p == NULL)
            {
                CfgImpAddLineF(g, CFGIMP_LINE_SKIPPED, IDS_CFGIMP_LN_NOPLUGIN, label, sp1->Name[0] != 0 ? sp1->Name : sp1->DLL);
                continue;
            }
            int item = CfgImpFindMenuItem(p, key->ID);
            if (item < 0)
            {
                CfgImpAddLineF(g, CFGIMP_LINE_SKIPPED, IDS_CFGIMP_LN_NOCOMMAND, label);
                continue;
            }
            CfgImpStripAmp(p->MenuItems[item]->Name, itemName, MAX_PATH);
            _snprintf_s(label, _TRUNCATE, "%s / %s (%s)", p->Name, itemName, keyText);
            if (IsSalHotKey(hk))
            {
                CfgImpAddLineF(g, CFGIMP_LINE_SKIPPED, IDS_CFGIMP_LN_KEYTC, label);
                continue;
            }
            DWORD curKey = p->MenuItems[item]->HotKey;
            if (HOTKEY_GET(curKey) == hk)
            {
                g->AddLine(CFGIMP_LINE_PRESENT, label);
                continue;
            }
            if (HOTKEY_GET(curKey) != 0 && g->Mode != CFGIMP_MODE_REPLACE)
            { // Add never changes a current shortcut, the plug-in's own default included (FR-010c)
                CfgImpAddLineF(g, CFGIMP_LINE_SKIPPED, IDS_CFGIMP_LN_KEYHAS, label);
                continue;
            }
            // the key used by another command (current, or assigned earlier in this plan)?
            int otherPlugin = -1, otherItem = -1;
            int a;
            for (a = 0; a < data->Assign.Count; a++)
            {
                if (HOTKEY_GET(data->Assign[a].HotKey) == hk)
                {
                    otherPlugin = data->Assign[a].Plugin;
                    otherItem = data->Assign[a].Item;
                }
            }
            if (otherPlugin < 0)
            {
                int fp = -1, fi = -1;
                if (Plugins.FindHotKey(hk, TRUE, NULL, &fp, &fi))
                {
                    otherPlugin = fp;
                    otherItem = fi;
                    // an assignment this plan already changes no longer counts
                    for (a = 0; a < data->Assign.Count; a++)
                    {
                        if (data->Assign[a].Plugin == fp && data->Assign[a].Item == fi)
                            otherPlugin = -1;
                    }
                }
            }
            BOOL removeOther = FALSE;
            if (otherPlugin >= 0 && !(otherPlugin == tc && otherItem == item))
            {
                CPluginData* op = Plugins.Get(otherPlugin);
                char otherName[MAX_PATH + 100];
                char otherItemName[MAX_PATH];
                CfgImpStripAmp((op != NULL && otherItem >= 0 && otherItem < op->MenuItems.Count && op->MenuItems[otherItem]->Name != NULL) ? op->MenuItems[otherItem]->Name : "?",
                               otherItemName, MAX_PATH);
                _snprintf_s(otherName, _TRUNCATE, "%s / %s", op != NULL ? op->Name : "?", otherItemName);
                if (g->Mode != CFGIMP_MODE_REPLACE)
                {
                    CfgImpAddLineF(g, CFGIMP_LINE_SKIPPED, IDS_CFGIMP_LN_KEYUSED, label, otherName);
                    continue;
                }
                removeOther = TRUE;
                char removed[MAX_PATH + 200];
                _snprintf_s(removed, _TRUNCATE, "%s (%s)", otherName, keyText);
                g->AddLine(CFGIMP_LINE_REMOVED, removed);
            }
            if (removeOther)
            {
                CCfgImpKeyAssign rm;
                rm.Plugin = otherPlugin;
                rm.Item = otherItem;
                rm.HotKey = HOTKEY_DIRTY; // the user's removal
                data->Assign.Add(rm);
            }
            CCfgImpKeyAssign as;
            as.Plugin = tc;
            as.Item = item;
            as.HotKey = hk | HOTKEY_DIRTY;
            data->Assign.Add(as);
            if (!data->Assign.IsGood())
            {
                data->Assign.ResetState();
                return FALSE;
            }
            if (HOTKEY_GET(curKey) != 0)
            {
                char old[100];
                CfgImpHotKeyText(HOTKEY_GET(curKey), old, sizeof(old));
                char* t = CfgImpFormat("%s: %s -> %s", label, old, keyText);
                g->AddLine(CFGIMP_LINE_REPLACED, t);
                free(t);
            }
            else
                g->AddLine(CFGIMP_LINE_ADDED, label);
        }
    }
    return TRUE;
}

static BOOL CfgImpApplyPluginKeys(CCfgImpRun* run, CCfgImpGroup* g)
{
    CCfgImpKeysData* data = (CCfgImpKeysData*)g->Data;
    if (data == NULL)
        return FALSE;
    int a;
    for (a = 0; a < data->Assign.Count; a++)
    {
        CPluginData* p = Plugins.Get(data->Assign[a].Plugin);
        if (p == NULL || data->Assign[a].Item < 0 || data->Assign[a].Item >= p->MenuItems.Count)
            continue;
        p->MenuItems[data->Assign[a].Item]->HotKey = data->Assign[a].HotKey;
    }
    return TRUE;
}

//
// ****************************************************************************
// histories (Add, passwords removed - FR-021)
//

struct CCfgImpHistory
{
    const char* Name;
    char** Array;
    int Size;
    BOOL (*Strip)(char* text);
};

static CCfgImpHistory CfgImpHistories[] = {
    {"Named History", FindNamedHistory, FIND_NAMED_HISTORY_SIZE, NULL},
    {"Look In History", FindLookInHistory, FIND_LOOKIN_HISTORY_SIZE, SalStripUrlPasswords},
    {"Grep History", FindGrepHistory, FIND_GREP_HISTORY_SIZE, NULL},
    {"Select History", Configuration.SelectHistory, SELECT_HISTORY_SIZE, NULL},
    {"Copy History", Configuration.CopyHistory, COPY_HISTORY_SIZE, SalStripUrlPasswords},
    {"ChangeDir History", Configuration.ChangeDirHistory, CHANGEDIR_HISTORY_SIZE, SalStripUrlPasswords},
    {"Viewer History", ViewerHistory, VIEWER_HISTORY_SIZE, NULL},
    {"Command History", Configuration.EditHistory, EDIT_HISTORY_SIZE, SalStripCommandLinePasswords},
    {"File List History", Configuration.FileListHistory, FILELIST_HISTORY_SIZE, NULL},
    {"Create Directory History", Configuration.CreateDirHistory, CREATEDIR_HISTORY_SIZE, NULL},
    {"Quick Rename History", Configuration.QuickRenameHistory, QUICKRENAME_HISTORY_SIZE, NULL},
    {"Edit New History", Configuration.EditNewHistory, EDITNEW_HISTORY_SIZE, NULL},
    {"Convert History", Configuration.ConvertHistory, CONVERT_HISTORY_SIZE, NULL},
    {"Filter History", Configuration.FilterHistory, FILTER_HISTORY_SIZE, NULL},
};
#define CFGIMP_HISTORIES ((int)(sizeof(CfgImpHistories) / sizeof(CfgImpHistories[0])))

class CCfgImpHistData : public CCfgImpGroupData
{
public:
    char** New[CFGIMP_HISTORIES]; // allocated arrays (Size entries) of allocated strings, NULL = unchanged
    CCfgImpHistData() { memset(New, 0, sizeof(New)); }
    ~CCfgImpHistData()
    {
        int h;
        for (h = 0; h < CFGIMP_HISTORIES; h++)
        {
            if (New[h] == NULL)
                continue;
            int i;
            for (i = 0; i < CfgImpHistories[h].Size; i++)
                free(New[h][i]);
            free(New[h]);
        }
    }
};

static int CfgImpCountHistories(CCfgImpRun* run)
{
    int n = 0;
    int h;
    for (h = 0; h < CFGIMP_HISTORIES; h++)
    {
        const char* items[64];
        char path[100];
        _snprintf_s(path, _TRUNCATE, "Configuration\\%s", CfgImpHistories[h].Name);
        n += SalCfgImpParseHistory(SalCfgKeyFind(run->Snapshot, path), items, min(64, CfgImpHistories[h].Size));
    }
    return n;
}

static BOOL CfgImpPlanHistories(CCfgImpRun* run, CCfgImpGroup* g)
{
    CCfgImpHistData* data = new CCfgImpHistData;
    if (data == NULL)
        return FALSE;
    g->Data = data;
    int h;
    for (h = 0; h < CFGIMP_HISTORIES; h++)
    {
        CCfgImpHistory* hi = &CfgImpHistories[h];
        const char* raw[64];
        char path[100];
        _snprintf_s(path, _TRUNCATE, "Configuration\\%s", hi->Name);
        int rc = SalCfgImpParseHistory(SalCfgKeyFind(run->Snapshot, path), raw, min(64, hi->Size));
        if (rc == 0)
            continue;
        // cleaned copies of the imported entries
        char* imp[64];
        BOOL stripped[64];
        int i;
        for (i = 0; i < rc; i++)
        {
            imp[i] = DupStr(raw[i]);
            stripped[i] = FALSE;
            if (imp[i] != NULL && hi->Strip != NULL)
                stripped[i] = hi->Strip(imp[i]);
        }
        int curCount = 0;
        while (curCount < hi->Size && hi->Array[curCount] != NULL)
            curCount++;
        const char* merged[64];
        int mc = SalCfgImpMergeHistory((const char* const*)hi->Array, curCount, (const char* const*)imp, rc, merged,
                                       min(64, hi->Size));
        data->New[h] = (char**)calloc(hi->Size, sizeof(char*));
        BOOL ok = data->New[h] != NULL;
        for (i = 0; i < mc && ok; i++)
        {
            data->New[h][i] = DupStr(merged[i]);
            ok = data->New[h][i] != NULL;
        }
        // lines: every imported entry once
        for (i = 0; i < rc && ok; i++)
        {
            if (imp[i] == NULL || imp[i][0] == 0)
                continue;
            BOOL inCur = FALSE, inMerged = FALSE;
            int j;
            for (j = 0; j < curCount && !inCur; j++)
                inCur = strcmp(hi->Array[j], imp[i]) == 0;
            BOOL earlier = FALSE;
            for (j = 0; j < i && !earlier; j++)
                earlier = imp[j] != NULL && strcmp(imp[j], imp[i]) == 0;
            if (earlier)
                continue;
            for (j = 0; j < mc && !inMerged; j++)
                inMerged = merged[j] == imp[i];
            if (inCur)
                g->AddLine(CFGIMP_LINE_PRESENT, imp[i]);
            else if (!inMerged)
                CfgImpAddLineF(g, CFGIMP_LINE_SKIPPED, IDS_CFGIMP_LN_HISTFULL, imp[i]);
            else if (stripped[i])
                CfgImpAddLineF(g, CFGIMP_LINE_FLAGGED, IDS_CFGIMP_HISTPWD, imp[i]);
            else
                g->AddLine(CFGIMP_LINE_ADDED, imp[i]);
        }
        for (i = 0; i < rc; i++)
        {
            if (imp[i] != NULL)
            {
                SecureZeroMemory(imp[i], strlen(imp[i]));
                free(imp[i]);
            }
        }
        if (!ok)
            return FALSE;
    }
    return TRUE;
}

static BOOL CfgImpApplyHistories(CCfgImpRun* run, CCfgImpGroup* g)
{
    CCfgImpHistData* data = (CCfgImpHistData*)g->Data;
    if (data == NULL)
        return FALSE;
    int h;
    for (h = 0; h < CFGIMP_HISTORIES; h++)
    {
        if (data->New[h] == NULL)
            continue;
        CCfgImpHistory* hi = &CfgImpHistories[h];
        int i;
        for (i = 0; i < hi->Size; i++)
        {
            free(hi->Array[i]);
            hi->Array[i] = data->New[h][i]; // ownership moves
            data->New[h][i] = NULL;
        }
    }
    return TRUE;
}

//
// ****************************************************************************
// settings of a whole plug-in (research R8)
//

static int CfgImpCountPluginSettings(CCfgImpRun* run, CCfgImpGroup* g)
{
    char path[200];
    _snprintf_s(path, _TRUNCATE, "Plugins Configuration\\%s", g->PluginKey);
    const CSalCfgKey* k = SalCfgKeyFind(run->Snapshot, path);
    return k != NULL ? max(1, k->ValueCount + k->KeyCount) : 0;
}

static BOOL CfgImpPlanPluginSettings(CCfgImpRun* run, CCfgImpGroup* g)
{
    CPluginData* p = Plugins.Get(g->PluginIndex);
    if (p == NULL)
        return FALSE;
    char* t = CfgImpFormat("%s", g->Title);
    g->AddLine(CFGIMP_LINE_REPLACED, t);
    free(t);
    g->AddLine(CFGIMP_LINE_NOTE, LoadStrU8(IDS_CFGIMP_PLUGINNEXTUSE));
    return TRUE;
}

// writes a snapshot subtree under 'key' (wide API; strings UTF-8 -> UTF-16)
static BOOL CfgImpWriteTree(HKEY key, const CSalCfgKey* node)
{
    int i;
    for (i = 0; i < node->ValueCount; i++)
    {
        const CSalCfgValue* v = &node->Values[i];
        WCHAR* name = SalU8ToWAlloc(v->Name);
        if (name == NULL)
            return FALSE;
        LONG res;
        if (v->Type == REG_SZ || v->Type == REG_EXPAND_SZ)
        {
            WCHAR* w = SalU8ToWAlloc((const char*)v->Data);
            if (w == NULL)
            {
                free(name);
                return FALSE;
            }
            res = RegSetValueExW(key, name, 0, v->Type, (const BYTE*)w, (DWORD)((wcslen(w) + 1) * sizeof(WCHAR)));
            free(w);
        }
        else
            res = RegSetValueExW(key, name, 0, v->Type, v->Data, v->Size);
        free(name);
        if (res != ERROR_SUCCESS)
            return FALSE;
    }
    for (i = 0; i < node->KeyCount; i++)
    {
        WCHAR* name = SalU8ToWAlloc(node->Keys[i]->Name);
        if (name == NULL)
            return FALSE;
        HKEY sub;
        LONG res = RegCreateKeyExW(key, name, 0, NULL, 0, KEY_READ | KEY_WRITE, NULL, &sub, NULL);
        free(name);
        if (res != ERROR_SUCCESS)
            return FALSE;
        BOOL ok = CfgImpWriteTree(sub, node->Keys[i]);
        RegCloseKey(sub);
        if (!ok)
            return FALSE;
    }
    return TRUE;
}

static BOOL CfgImpApplyPluginSettings(CCfgImpRun* run, CCfgImpGroup* g, HWND parent)
{
    CPluginData* p = Plugins.Get(g->PluginIndex);
    if (p == NULL || p->RegKeyName == NULL || *p->RegKeyName == 0 || SALAMANDER_ROOT_REG == NULL)
        return FALSE;
    char path[200];
    _snprintf_s(path, _TRUNCATE, "Plugins Configuration\\%s", g->PluginKey);
    const CSalCfgKey* src = SalCfgKeyFind(run->Snapshot, path);
    if (src == NULL)
        return FALSE;
    if (p->GetLoaded() && !p->Unload(parent, FALSE)) // saves its current settings first (when saving on exit is on)
    {
        CfgImpLoad(IDS_CFGIMP_LN_PLUGINUNLOAD, g->ApplyError, (int)sizeof(g->ApplyError));
        return FALSE;
    }
    if (p->GetLoaded())
    {
        CfgImpLoad(IDS_CFGIMP_LN_PLUGINUNLOAD, g->ApplyError, (int)sizeof(g->ApplyError));
        return FALSE;
    }
    // the plug-in is unloaded: SaveConfig does not rewrite its key (plugins2.cpp, only loaded ones save)
    char keyPath[2 * MAX_PATH];
    _snprintf_s(keyPath, _TRUNCATE, "%s\\Plugins Configuration", SALAMANDER_ROOT_REG);
    WCHAR* wKeyPath = SalU8ToWAlloc(keyPath);
    WCHAR* wName = SalU8ToWAlloc(p->RegKeyName);
    BOOL ok = FALSE;
    if (wKeyPath != NULL && wName != NULL)
    {
        LoadSaveToRegistryMutex.Enter();
        HKEY parentKey;
        if (RegCreateKeyExW(HKEY_CURRENT_USER, wKeyPath, 0, NULL, 0, KEY_READ | KEY_WRITE, NULL, &parentKey, NULL) == ERROR_SUCCESS)
        {
            LONG res = RegDeleteTreeW(parentKey, wName);
            if (res == ERROR_SUCCESS || res == ERROR_FILE_NOT_FOUND)
            {
                HKEY k;
                if (RegCreateKeyExW(parentKey, wName, 0, NULL, 0, KEY_READ | KEY_WRITE, NULL, &k, NULL) == ERROR_SUCCESS)
                {
                    ok = CfgImpWriteTree(k, src);
                    RegCloseKey(k);
                }
            }
            RegCloseKey(parentKey);
        }
        LoadSaveToRegistryMutex.Leave();
    }
    free(wKeyPath);
    free(wName);
    return ok;
}

//
// ****************************************************************************
// FTP connections through the plug-in's import handler (interface 108)
//

static int CfgImpFTPIndex()
{
    int i;
    for (i = 0; i < Plugins.GetCount(); i++)
    {
        CPluginData* p = Plugins.Get(i);
        if (p != NULL && p->DLLName != NULL && CfgImpIsFTPDll(p->DLLName))
            return i;
    }
    return -1;
}

static int CfgImpCountFTP(CCfgImpRun* run, CCfgImpGroup* g, CCfgImpSrcPlugins* sp)
{
    g->PluginIndex = CfgImpFTPIndex();
    if (g->PluginIndex < 0)
    {
        g->Availability = CFGIMP_AVAIL_NO;
        CfgImpLoad(IDS_CFGIMP_AVAIL_NOPLUGIN, g->Reason, (int)sizeof(g->Reason));
        return 0;
    }
    const char* key = CfgImpSrcConfigKeyOf(sp, g->PluginIndex);
    lstrcpyn(g->PluginKey, *key != 0 ? key : "FTP", (int)sizeof(g->PluginKey));
    char path[200];
    _snprintf_s(path, _TRUNCATE, "Plugins Configuration\\%s", g->PluginKey);
    const CSalCfgKey* ftp = SalCfgKeyFind(run->Snapshot, path);
    if (ftp == NULL)
        return 0;
    const CSalCfgKey* bm = SalCfgKeyFindChild(ftp, "Bookmarks");
    const CSalCfgKey* px = SalCfgKeyFindChild(ftp, "Proxy Servers");
    return (bm != NULL ? bm->KeyCount : 0) + (px != NULL ? px->KeyCount : 0);
}

// a plug-in's handler behind an exception guard (no C++ objects in this frame)
static BOOL CfgImpCallHandler(CPluginSettingsImportAbstract* handler, HWND parent, CSalamanderSettingsImportAbstract* ctx,
                              BOOL dryRun)
{
    __try
    {
        return handler->ImportSettings(parent, ctx, dryRun);
    }
    __except (EXCEPTION_EXECUTE_HANDLER)
    {
        TRACE_E("CfgImpCallHandler(): the plugin's import handler crashed");
        return FALSE;
    }
}

static BOOL CfgImpRunFTP(CCfgImpRun* run, CCfgImpGroup* g, HWND parent, BOOL dryRun)
{
    CPluginData* p = Plugins.Get(g->PluginIndex);
    if (p == NULL)
        return FALSE;
    if (!p->GetLoaded() && !p->InitDLL(parent, run->Automation))
    {
        CfgImpLoad(IDS_CFGIMP_NOHANDLER, g->ApplyError, (int)sizeof(g->ApplyError));
        return FALSE;
    }
    CPluginSettingsImportAbstract* handler = p->GetSettingsImport();
    if (handler == NULL)
    {
        if (dryRun)
            g->AddLine(CFGIMP_LINE_SKIPPED, LoadStrU8(IDS_CFGIMP_NOHANDLER));
        CfgImpLoad(IDS_CFGIMP_NOHANDLER, g->ApplyError, (int)sizeof(g->ApplyError));
        return FALSE;
    }
    char path[200];
    _snprintf_s(path, _TRUNCATE, "Plugins Configuration\\%s", g->PluginKey);
    CSalCfgKey* src = (CSalCfgKey*)SalCfgKeyFind(run->Snapshot, path);
    CCfgImpPluginContext ctx(run, g, parent, src);
    if (!dryRun)
        g->ClearLines(); // the result shows what really happened
    BOOL ret = CfgImpCallHandler(handler, parent, &ctx, dryRun);
    if (!dryRun && !ret && g->ApplyError[0] == 0)
        CfgImpLoad(IDS_CFGIMP_FAILEDGROUP, g->ApplyError, (int)sizeof(g->ApplyError));
    if (!dryRun && ret && run->Passwords.AskedTCMasterPassword && !run->Passwords.TCMasterPasswordGiven)
        g->AddLine(CFGIMP_LINE_NOTE, LoadStrU8(IDS_CFGIMP_TCMPWDNEEDED));
    return ret;
}

//
// ****************************************************************************
// dispatch
//

static int CfgImpCountGroup(CCfgImpRun* run, CCfgImpGroup* g, CCfgImpSrcPlugins* sp)
{
    switch (g->Id)
    {
    case cigHotPaths:
        return CfgImpCountHotPaths(run);
    case cigUserMenu:
        return CfgImpCountUserMenu(run);
    case cigFTP:
        return CfgImpCountFTP(run, g, sp);
    case cigPluginKeys:
        return CfgImpCountPluginKeys(run, sp);
    case cigViewers:
        return CfgImpCountViewers(run);
    case cigHistories:
        return CfgImpCountHistories(run);
    case cigConfirmations:
    case cigPanelOpts:
    case cigGeneral:
    case cigViewerOpts:
        return CfgImpCountOptions(run, g);
    case cigDefaultDirs:
        return CfgImpCountDefaultDirs(run);
    case cigPluginSettings:
        return CfgImpCountPluginSettings(run, g);
    default:
        return 0;
    }
}

static BOOL CfgImpPlanGroup(CCfgImpRun* run, CCfgImpGroup* g, CCfgImpSrcPlugins* sp, HWND parent)
{
    switch (g->Id)
    {
    case cigHotPaths:
        return CfgImpPlanHotPaths(run, g);
    case cigUserMenu:
        return CfgImpPlanUserMenu(run, g);
    case cigFTP:
        return CfgImpRunFTP(run, g, parent, TRUE);
    case cigPluginKeys:
        return CfgImpPlanPluginKeys(run, g, sp);
    case cigViewers:
        return CfgImpPlanViewers(run, g, sp);
    case cigHistories:
        return CfgImpPlanHistories(run, g);
    case cigConfirmations:
    case cigPanelOpts:
    case cigGeneral:
    case cigViewerOpts:
        return CfgImpPlanOptions(run, g);
    case cigDefaultDirs:
        return CfgImpPlanDefaultDirs(run, g);
    case cigPluginSettings:
        return CfgImpPlanPluginSettings(run, g);
    default:
        return FALSE;
    }
}

static BOOL CfgImpApplyGroup(CCfgImpRun* run, CCfgImpGroup* g, HWND parent, BOOL* templatesChanged)
{
    switch (g->Id)
    {
    case cigHotPaths:
        return CfgImpApplyHotPaths(run, g);
    case cigUserMenu:
        return CfgImpApplyUserMenu(run, g);
    case cigFTP:
        return CfgImpRunFTP(run, g, parent, FALSE);
    case cigPluginKeys:
        return CfgImpApplyPluginKeys(run, g);
    case cigViewers:
        return CfgImpApplyViewers(run, g);
    case cigHistories:
        return CfgImpApplyHistories(run, g);
    case cigConfirmations:
    case cigPanelOpts:
    case cigGeneral:
    case cigViewerOpts:
        return CfgImpApplyOptions(run, g);
    case cigDefaultDirs:
        return CfgImpApplyDefaultDirs(run, g);
    case cigPluginSettings:
        return CfgImpApplyPluginSettings(run, g, parent);
    default:
        return FALSE;
    }
}
