// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

// Feature 245 (plugin interface 108): the FTP client imports its connections -
// bookmarks, proxy servers and user-defined server types - from an older program
// (Altap Salamander 2.5-4.0, Open Salamander 5.0) through the program's settings
// import wizard. Contract: specs/245-settings-import-salamander/contracts/plugin-api-v108.md,
// rules: research R9 (merge) and R10 (passwords).
//
// The source is read only through CSalamanderSettingsImportAbstract::GetSourceKey (a
// read-only view of the program's in-memory copy). The plug-in's own item loaders read
// it; passwords and the proxy references of bookmarks are read raw here, because the
// loaders validate them against the CURRENT configuration (and LoadPassword reads the
// registry directly, which the view does not support).
//
// All or nothing: the three new lists (proxy servers, bookmarks, server types) are built
// completely as copies first; only then are they exchanged with the current ones by
// ImportSwap, which cannot fail. A dry run builds and reports the same, then discards it.

#include "precomp.h"
#include "../../common/salcfgimport.h"

//
// ****************************************************************************
// helpers
//

// a raw password blob of an item: "PasswordE" (AES), else "PasswordS" (scrambled); NULL when none
static BYTE* ImportReadBlob(CSalamanderRegistryAbstract* reg, HKEY key, int* size)
{
    *size = 0;
    const char* names[2] = {"PasswordE", "PasswordS"};
    int i;
    for (i = 0; i < 2; i++)
    {
        DWORD s = 0;
        if (reg->GetSize(key, names[i], REG_BINARY, s) && s > 1 && s < 4096)
        {
            BYTE* b = (BYTE*)SalamanderGeneral->Alloc(s);
            if (b != NULL && reg->GetValue(key, names[i], REG_BINARY, b, s))
            {
                *size = (int)s;
                return b;
            }
            if (b != NULL)
                SalamanderGeneral->Free(b);
        }
    }
    return NULL;
}

static void ImportFreeBlob(BYTE* blob, int size)
{
    if (blob != NULL)
    {
        memset(blob, 0, size);
        SalamanderGeneral->Free(blob);
    }
}

// converts a source password blob to the program's current storage; '*newBlob' NULL = no
// password to store; FALSE = the item has a password that cannot be imported (policy, wrong
// master password, the program's master password not given). A dry run decides the same way
// (the core answers DecryptSourcePassword identically in both runs) but stores nothing.
static BOOL ImportConvertPassword(CSalamanderSettingsImportAbstract* imp, const BYTE* blob, int size, BOOL dryRun,
                                  BYTE** newBlob, int* newSize)
{
    *newBlob = NULL;
    *newSize = 0;
    if (blob == NULL || size <= 1)
        return TRUE;
    char* plain = NULL;
    if (!imp->DecryptSourcePassword(blob, size, &plain) || plain == NULL)
        return FALSE;
    BOOL ok = TRUE;
    if (plain[0] != 0 && !dryRun)
        ok = imp->EncryptForStorage(plain, newBlob, newSize);
    memset(plain, 0, strlen(plain));
    SalamanderGeneral->Free(plain);
    return ok;
}

// 'text' = the string 'fmtId' formatted with 'a' (and 'b'); each format has only %s arguments
static void ImportFormat(char* text, int size, int fmtId, const char* a, const char* b = NULL)
{
    char fmt[500];
    SalCfgImpCopyText(fmt, (int)sizeof(fmt), LoadStrU8(fmtId));
    if (b != NULL)
        SalCfgImpFormatText(text, size, fmt, a, b);
    else
        SalCfgImpFormatText(text, size, fmt, a);
}

static void ImportReport(CSalamanderSettingsImportAbstract* imp, int kind, int fmtId, const char* a, const char* b = NULL)
{
    char text[2000];
    ImportFormat(text, (int)sizeof(text), fmtId, a, b);
    imp->Report(kind, text);
}

static void BookmarkLabel(const CFTPServer* s, char* buf, int size)
{
    ImportFormat(buf, size, IDS_IMPORT_BOOKMARK, HandleNULLStr(s->ItemName), HandleNULLStr(s->Address));
}

static void ProxyLabel(const CFTPProxyServer* p, char* buf, int size)
{
    ImportFormat(buf, size, IDS_IMPORT_PROXY, HandleNULLStr(p->ProxyName));
}

static void TypeLabel(const CServerType* t, char* buf, int size)
{
    const char* n = HandleNULLStr(t->TypeName);
    ImportFormat(buf, size, IDS_IMPORT_SRVTYPE, *n == '*' ? n + 1 : n);
}

// appends one reason (a string with one %s = the text so far) to 'text'
static void ImportAddReason(char* text, int size, int fmtId, const char* b = NULL)
{
    char was[2000];
    SalCfgImpCopyText(was, (int)sizeof(was), text);
    ImportFormat(text, size, fmtId, was, b);
}

static const char* NonNull(const char* s) { return s != NULL ? s : ""; }

static BOOL StrEqCI(const char* a, const char* b)
{
    return SalamanderGeneral->StrICmp(NonNull(a), NonNull(b)) == 0;
}

static BOOL StrEq(const char* a, const char* b) { return strcmp(NonNull(a), NonNull(b)) == 0; }

// the same connection (the name is a label: not part of the identity); 'aProxy'/'bProxy' are
// the proxy server UIDs in the same numbering (the source's are re-mapped first)
static BOOL SameBookmark(const CFTPServer* a, int aProxy, const CFTPServer* b, int bProxy)
{
    return StrEqCI(a->Address, b->Address) && a->Port == b->Port && a->AnonymousConnection == b->AnonymousConnection &&
           (a->AnonymousConnection || StrEq(a->UserName, b->UserName)) && StrEq(a->InitialPath, b->InitialPath) &&
           StrEqCI(a->ServerType, b->ServerType) && aProxy == bProxy;
}

static BOOL SameProxy(const CFTPProxyServer* a, const CFTPProxyServer* b)
{
    return StrEqCI(a->ProxyName, b->ProxyName) && a->ProxyType == b->ProxyType && StrEqCI(a->ProxyHost, b->ProxyHost) &&
           a->ProxyPort == b->ProxyPort && StrEq(a->ProxyUser, b->ProxyUser) && StrEq(a->ProxyScript, b->ProxyScript);
}

// the same definition of a server type (the name compared as the program compares it)
static BOOL SameServerType(CServerType* a, CServerType* b)
{
    const char* an = NonNull(a->TypeName);
    const char* bn = NonNull(b->TypeName);
    if (SalamanderGeneral->StrICmp(*an == '*' ? an + 1 : an, *bn == '*' ? bn + 1 : bn) != 0 ||
        !StrEq(a->AutodetectCond, b->AutodetectCond) || !StrEq(a->RulesForParsing, b->RulesForParsing) ||
        a->Columns.Count != b->Columns.Count)
    {
        return FALSE;
    }
    int i;
    for (i = 0; i < a->Columns.Count; i++)
    {
        char ca[STC_MAXCOLUMNSTR], cb[STC_MAXCOLUMNSTR];
        if (!a->Columns[i]->SaveToStr(ca, (int)sizeof(ca), TRUE) || !b->Columns[i]->SaveToStr(cb, (int)sizeof(cb), TRUE) ||
            strcmp(ca, cb) != 0)
        {
            return FALSE;
        }
    }
    return TRUE;
}

struct CImportNameCtx
{
    CFTPServerList* Bookmarks;
    CFTPProxyServerList* Proxies;
};

static BOOL BookmarkNameExists(void* ctx, const char* name)
{
    CImportNameCtx* c = (CImportNameCtx*)ctx;
    int i;
    for (i = 0; i < c->Bookmarks->Count; i++)
    {
        if (StrEqCI(c->Bookmarks->At(i)->ItemName, name))
            return TRUE;
    }
    return FALSE;
}

static BOOL ProxyNameExists(void* ctx, const char* name)
{
    CImportNameCtx* c = (CImportNameCtx*)ctx;
    int i;
    for (i = 0; i < c->Proxies->GetCount(); i++)
    {
        if (StrEqCI(c->Proxies->GetAt(i)->ProxyName, name))
            return TRUE;
    }
    return FALSE;
}

#define IMPORT_SWAP(type, a, b) \
    { \
        type t_ = a; \
        a = b; \
        b = t_; \
    }

//
// ****************************************************************************
// the lists: what the import needs
//

int CFTPProxyServerList::AddImportedCopy(const CFTPProxyServer* src, const char* name, int uid)
{
    HANDLES(EnterCriticalSection(&ProxyServerListCS));
    int ret = -1;
    if (uid < 0)
        uid = NextFreeProxyUID;
    CFTPProxyServer* n = new CFTPProxyServer(0);
    if (n != NULL && n->Set(uid, name, src->ProxyType, src->ProxyHost, src->ProxyPort, src->ProxyUser,
                            src->ProxyEncryptedPassword, src->ProxyEncryptedPasswordSize, src->SaveProxyPassword,
                            src->ProxyScript))
    {
        Add(n);
        if (IsGood())
        {
            ret = uid;
            if (NextFreeProxyUID <= uid)
                NextFreeProxyUID = uid + 1;
        }
        else
        {
            ResetState();
            delete n;
        }
    }
    else if (n != NULL)
        delete n;
    HANDLES(LeaveCriticalSection(&ProxyServerListCS));
    return ret;
}

void CFTPProxyServerList::ImportStartAfter(CFTPProxyServerList& cur)
{
    HANDLES(EnterCriticalSection(&ProxyServerListCS));
    DestroyMembers();
    NextFreeProxyUID = cur.NextFreeProxyUID; // read in the main thread (the only writer)
    HANDLES(LeaveCriticalSection(&ProxyServerListCS));
}

void CFTPProxyServerList::ImportSwap(CFTPProxyServerList& other)
{
    HANDLES(EnterCriticalSection(&ProxyServerListCS));
    IMPORT_SWAP(void**, Data, other.Data);
    IMPORT_SWAP(int, Count, other.Count);
    IMPORT_SWAP(int, Available, other.Available);
    IMPORT_SWAP(int, Base, other.Base);
    IMPORT_SWAP(int, Delta, other.Delta);
    IMPORT_SWAP(CErrorType, State, other.State);
    IMPORT_SWAP(int, NextFreeProxyUID, other.NextFreeProxyUID);
    HANDLES(LeaveCriticalSection(&ProxyServerListCS));
}

void CFTPServerList::ImportSwap(CFTPServerList& other)
{
    IMPORT_SWAP(void**, Data, other.Data);
    IMPORT_SWAP(int, Count, other.Count);
    IMPORT_SWAP(int, Available, other.Available);
    IMPORT_SWAP(int, Base, other.Base);
    IMPORT_SWAP(int, Delta, other.Delta);
    IMPORT_SWAP(CErrorType, State, other.State);
}

void CServerTypeList::ImportSwap(CServerTypeList& other)
{
    IMPORT_SWAP(void**, Data, other.Data);
    IMPORT_SWAP(int, Count, other.Count);
    IMPORT_SWAP(int, Available, other.Available);
    IMPORT_SWAP(int, Base, other.Base);
    IMPORT_SWAP(int, Delta, other.Delta);
    IMPORT_SWAP(CErrorType, State, other.State);
}

//
// ****************************************************************************
// the source's items
//

struct CImportProxy
{
    CFTPProxyServer* Item; // loaded by the plug-in's loader (password replaced below)
    int SourceUID;
    BYTE* Blob; // raw source password
    int BlobSize;
};

struct CImportBookmark
{
    CFTPServer* Item;
    int SourceProxyUID; // as stored in the source (-1 not used, -2 default)
    int MappedProxyUID; // in the new list's numbering
    BOOL ProxyLost;     // the source's proxy server is missing in the source
    BYTE* Blob;
    int BlobSize;
};

static void FreeImportProxies(TDirectArray<CImportProxy>& list)
{
    int i;
    for (i = 0; i < list.Count; i++)
    {
        delete list[i].Item;
        ImportFreeBlob(list[i].Blob, list[i].BlobSize);
    }
    list.DestroyMembers();
}

static void FreeImportBookmarks(TDirectArray<CImportBookmark>& list)
{
    int i;
    for (i = 0; i < list.Count; i++)
    {
        delete list[i].Item;
        ImportFreeBlob(list[i].Blob, list[i].BlobSize);
    }
    list.DestroyMembers();
}

static void ReportIncomplete(CSalamanderSettingsImportAbstract* imp, int index, const char* list)
{
    char what[100];
    _snprintf_s(what, _TRUNCATE, "%d", index);
    ImportReport(imp, SALIMPORT_REPORT_SKIPPED, IDS_IMPORT_INCOMPLETE, what, list);
}

// FALSE = out of memory (nothing may be imported then)
static BOOL ReadSourceProxies(HWND parent, CSalamanderSettingsImportAbstract* imp, CSalamanderRegistryAbstract* reg,
                              HKEY root, TDirectArray<CImportProxy>& out)
{
    HKEY listKey;
    if (!reg->OpenKey(root, CONFIG_FTPPROXYLIST, listKey))
        return TRUE;
    BOOL ok = TRUE;
    char buf[30];
    int i;
    for (i = 1; ok; i++)
    {
        HKEY sub;
        if (!reg->OpenKey(listKey, _itoa(i, buf, 10), sub))
            break;
        CImportProxy p;
        p.Item = new CFTPProxyServer(0);
        p.Blob = NULL;
        p.BlobSize = 0;
        p.SourceUID = -1;
        if (p.Item == NULL)
            ok = FALSE;
        else if (p.Item->Load(parent, sub, reg))
        {
            p.SourceUID = p.Item->ProxyUID;
            p.Blob = ImportReadBlob(reg, sub, &p.BlobSize);
            if (p.Blob == NULL && p.Item->ProxyEncryptedPassword != NULL && p.Item->ProxyEncryptedPasswordSize > 0)
            { // the oldest format, already converted to a scrambled blob by the loader
                p.Blob = (BYTE*)SalamanderGeneral->Alloc(p.Item->ProxyEncryptedPasswordSize);
                if (p.Blob != NULL)
                {
                    memcpy(p.Blob, p.Item->ProxyEncryptedPassword, p.Item->ProxyEncryptedPasswordSize);
                    p.BlobSize = p.Item->ProxyEncryptedPasswordSize;
                }
            }
            out.Add(p);
            if (!out.IsGood())
            {
                out.ResetState();
                delete p.Item;
                ImportFreeBlob(p.Blob, p.BlobSize);
                ok = FALSE;
            }
        }
        else
        {
            delete p.Item;
            ReportIncomplete(imp, i, CONFIG_FTPPROXYLIST);
        }
        reg->CloseKey(sub);
    }
    reg->CloseKey(listKey);
    return ok;
}

static BOOL ReadSourceBookmarks(HWND parent, CSalamanderSettingsImportAbstract* imp, CSalamanderRegistryAbstract* reg,
                                HKEY root, TDirectArray<CImportBookmark>& out)
{
    HKEY listKey;
    if (!reg->OpenKey(root, CONFIG_FTPSERVERLIST, listKey))
        return TRUE;
    BOOL ok = TRUE;
    char buf[30];
    int i;
    for (i = 1; ok; i++)
    {
        HKEY sub;
        if (!reg->OpenKey(listKey, _itoa(i, buf, 10), sub))
            break;
        CImportBookmark b;
        b.Item = new CFTPServer;
        b.Blob = NULL;
        b.BlobSize = 0;
        b.SourceProxyUID = -2;
        b.MappedProxyUID = -2;
        b.ProxyLost = FALSE;
        if (b.Item == NULL)
            ok = FALSE;
        else if (b.Item->Load(parent, sub, reg))
        {
            DWORD uid;
            if (reg->GetValue(sub, "Proxy Server UID", REG_DWORD, &uid, sizeof(DWORD)))
                b.SourceProxyUID = (int)uid; // raw: the loader checks it against the CURRENT proxy list
            b.Blob = ImportReadBlob(reg, sub, &b.BlobSize);
            if (b.Blob == NULL && b.Item->EncryptedPassword != NULL && b.Item->EncryptedPasswordSize > 0)
            {
                b.Blob = (BYTE*)SalamanderGeneral->Alloc(b.Item->EncryptedPasswordSize);
                if (b.Blob != NULL)
                {
                    memcpy(b.Blob, b.Item->EncryptedPassword, b.Item->EncryptedPasswordSize);
                    b.BlobSize = b.Item->EncryptedPasswordSize;
                }
            }
            out.Add(b);
            if (!out.IsGood())
            {
                out.ResetState();
                delete b.Item;
                ImportFreeBlob(b.Blob, b.BlobSize);
                ok = FALSE;
            }
        }
        else
        {
            delete b.Item;
            ReportIncomplete(imp, i, CONFIG_FTPSERVERLIST);
        }
        reg->CloseKey(sub);
    }
    reg->CloseKey(listKey);
    return ok;
}

// the source's server types (like CServerTypeList::Load, but an invalid entry is reported)
static BOOL ReadSourceTypes(HWND parent, CSalamanderSettingsImportAbstract* imp, CSalamanderRegistryAbstract* reg,
                            HKEY root, CServerTypeList& out)
{
    HKEY listKey;
    if (!reg->OpenKey(root, CONFIG_SERVERTYPES, listKey))
        return TRUE;
    BOOL ok = TRUE;
    char buf[30];
    int i;
    for (i = 1; ok; i++)
    {
        HKEY sub;
        if (!reg->OpenKey(listKey, _itoa(i, buf, 10), sub))
            break;
        CServerType* item = new CServerType;
        if (item == NULL)
            ok = FALSE;
        else if (item->Load(parent, sub, reg))
        {
            out.Add(item);
            if (!out.IsGood())
            {
                out.ResetState();
                delete item;
                ok = FALSE;
            }
        }
        else
        {
            delete item;
            ReportIncomplete(imp, i, CONFIG_SERVERTYPES);
        }
        reg->CloseKey(sub);
    }
    reg->CloseKey(listKey);
    return ok;
}

//
// ****************************************************************************
// the handler
//

class CFTPSettingsImport : public CPluginSettingsImportAbstract
{
public:
    virtual BOOL WINAPI ImportSettings(HWND parent, CSalamanderSettingsImportAbstract* imp, BOOL dryRun);
};

static CFTPSettingsImport FTPSettingsImport;

CPluginSettingsImportAbstract* GetFTPSettingsImport() { return &FTPSettingsImport; }

static int FindProxy(CFTPProxyServerList& list, const CFTPProxyServer* p)
{
    int j;
    for (j = 0; j < list.GetCount(); j++)
    {
        if (SameProxy(list.GetAt(j), p))
            return j;
    }
    return -1;
}

static int FindBookmark(CFTPServerList& list, const CFTPServer* b, int proxy)
{
    int j;
    for (j = 0; j < list.Count; j++)
    {
        if (SameBookmark(list.At(j), list.At(j)->ProxyServerUID, b, proxy))
            return j;
    }
    return -1;
}

BOOL WINAPI CFTPSettingsImport::ImportSettings(HWND parent, CSalamanderSettingsImportAbstract* imp, BOOL dryRun)
{
    CALL_STACK_MESSAGE2("CFTPSettingsImport::ImportSettings(, , %d)", dryRun);
    HKEY root;
    CSalamanderRegistryAbstract* reg;
    if (!imp->GetSourceKey(&root, &reg))
        return TRUE; // the old program has no FTP settings: nothing to do
    BOOL replace = imp->GetMode() == SALIMPORT_MODE_REPLACE;
    char suffix1[100], suffixN[100];
    SalCfgImpCopyText(suffix1, (int)sizeof(suffix1), LoadStrU8(IDS_IMPORT_SUFFIX));
    SalCfgImpCopyText(suffixN, (int)sizeof(suffixN), LoadStrU8(IDS_IMPORT_SUFFIXN));

    TDirectArray<CImportProxy> srcProxies(8, 8);
    TDirectArray<CImportBookmark> srcBookmarks(16, 16);
    CServerTypeList srcTypes;
    BOOL ok = ReadSourceProxies(parent, imp, reg, root, srcProxies) &&
              ReadSourceBookmarks(parent, imp, reg, root, srcBookmarks) &&
              ReadSourceTypes(parent, imp, reg, root, srcTypes);

    // the new lists, complete before anything is changed (all or nothing); Add starts from
    // copies of the current lists, Replace from empty ones whose new proxy UIDs continue after
    // the current ones (a reference to a removed proxy server never points to another one)
    CFTPProxyServerList newProxies;
    CFTPServerList newBookmarks;
    CServerTypeList newTypes;
    if (ok)
    {
        if (replace)
            newProxies.ImportStartAfter(Config.FTPProxyServerList);
        else
            ok = Config.FTPProxyServerList.CopyMembersToList(newProxies) && Config.FTPServerList.CopyMembersToList(newBookmarks);
    }
    if (ok)
    {
        CServerTypeList* cur = Config.LockServerTypeList();
        ok = newTypes.CopyItemsFrom(cur);
        Config.UnlockServerTypeList();
    }
    CImportNameCtx names;
    names.Bookmarks = &newBookmarks;
    names.Proxies = &newProxies;
    char label[1000];
    char text[2000];
    int i, j;

    // proxy servers: identical ones are reused (Replace keeps the UID of a current identical
    // one), others are added under a new UID and a free name
    TDirectArray<int> uidMap(8, 8); // pairs: source UID, new UID; the first source entry of a UID wins
    if (replace && ok)
    {
        for (i = 0; i < Config.FTPProxyServerList.GetCount(); i++)
        {
            CFTPProxyServer* cur = Config.FTPProxyServerList.GetAt(i);
            BOOL inSrc = FALSE;
            for (j = 0; j < srcProxies.Count && !inSrc; j++)
                inSrc = SameProxy(cur, srcProxies[j].Item);
            if (!inSrc)
            {
                ProxyLabel(cur, label, (int)sizeof(label));
                imp->Report(SALIMPORT_REPORT_REMOVED, label);
            }
        }
    }
    for (i = 0; i < srcProxies.Count && ok; i++)
    {
        CFTPProxyServer* sp = srcProxies[i].Item;
        ProxyLabel(sp, label, (int)sizeof(label));
        int newUID = -1;
        int found = FindProxy(newProxies, sp);
        if (found >= 0) // Add: already present; Replace: the same proxy twice in the source
        {
            newUID = newProxies.GetAt(found)->ProxyUID;
            imp->Report(SALIMPORT_REPORT_PRESENT, label);
        }
        else
        {
            int curIndex = replace ? FindProxy(Config.FTPProxyServerList, sp) : -1;
            char name[PROXYSRVNAME_MAX_SIZE];
            if (!SalCfgImpUniqueName(HandleNULLStr(sp->ProxyName), suffix1, suffixN, ProxyNameExists, &names, name,
                                     PROXYSRVNAME_MAX_SIZE))
            {
                ImportReport(imp, SALIMPORT_REPORT_SKIPPED, IDS_IMPORT_INCOMPLETE, HandleNULLStr(sp->ProxyName), CONFIG_FTPPROXYLIST);
                continue;
            }
            BYTE* pwd;
            int pwdSize;
            BOOL pwdOk = ImportConvertPassword(imp, srcProxies[i].Blob, srcProxies[i].BlobSize, dryRun, &pwd, &pwdSize);
            // the item takes the converted password (or none)
            if (sp->ProxyEncryptedPassword != NULL)
                ImportFreeBlob(sp->ProxyEncryptedPassword, sp->ProxyEncryptedPasswordSize);
            sp->ProxyEncryptedPassword = pwd;
            sp->ProxyEncryptedPasswordSize = pwdSize;
            sp->SaveProxyPassword = pwd != NULL;
            newUID = newProxies.AddImportedCopy(sp, name, curIndex >= 0 ? Config.FTPProxyServerList.GetAt(curIndex)->ProxyUID : -1);
            if (newUID < 0)
            {
                ok = FALSE;
                break;
            }
            BOOL renamed = strcmp(name, HandleNULLStr(sp->ProxyName)) != 0;
            SalCfgImpCopyText(text, (int)sizeof(text), label);
            if (renamed)
                ImportFormat(text, (int)sizeof(text), IDS_IMPORT_RENAMED, label, name);
            if (!pwdOk)
                ImportAddReason(text, (int)sizeof(text), IDS_IMPORT_NOPASSWORD);
            imp->Report(curIndex >= 0 ? SALIMPORT_REPORT_REPLACED : (renamed || !pwdOk) ? SALIMPORT_REPORT_FLAGGED : SALIMPORT_REPORT_ADDED,
                        text);
        }
        int src = srcProxies[i].SourceUID;
        BOOL mapped = src <= 0; // UIDs start at 1; an invalid one is never mapped
        int k;
        for (k = 0; k + 1 < uidMap.Count && !mapped; k += 2)
            mapped = uidMap[k] == src;
        if (!mapped)
        {
            uidMap.Add(src);
            uidMap.Add(newUID);
            if (!uidMap.IsGood())
            {
                uidMap.ResetState();
                ok = FALSE;
            }
        }
    }
    // Replace: the default proxy server is reset when it is removed
    BOOL resetDefaultProxy = FALSE;
    if (ok && replace && Config.DefaultProxySrvUID != -1 && !newProxies.IsValidUID(Config.DefaultProxySrvUID))
    {
        resetDefaultProxy = TRUE;
        for (i = 0; i < Config.FTPProxyServerList.GetCount(); i++)
        {
            CFTPProxyServer* cur = Config.FTPProxyServerList.GetAt(i);
            if (cur->ProxyUID == Config.DefaultProxySrvUID)
                ImportReport(imp, SALIMPORT_REPORT_REMOVED, IDS_IMPORT_DEFPROXY, HandleNULLStr(cur->ProxyName));
        }
    }

    // bookmarks: the proxy reference of each is re-mapped to the new list first (it is part of
    // the identity of a connection)
    for (i = 0; i < srcBookmarks.Count && ok; i++)
    {
        int src = srcBookmarks[i].SourceProxyUID;
        int mapped = src;
        if (src != -1 && src != -2)
        {
            mapped = -2;
            srcBookmarks[i].ProxyLost = TRUE;
            int k;
            for (k = 0; k + 1 < uidMap.Count; k += 2)
            {
                if (uidMap[k] == src)
                {
                    mapped = uidMap[k + 1];
                    srcBookmarks[i].ProxyLost = FALSE;
                    break;
                }
            }
        }
        srcBookmarks[i].MappedProxyUID = mapped;
    }
    if (replace && ok)
    {
        for (i = 0; i < Config.FTPServerList.Count; i++)
        {
            CFTPServer* cur = Config.FTPServerList.At(i);
            BOOL inSrc = FALSE;
            for (j = 0; j < srcBookmarks.Count && !inSrc; j++)
                inSrc = SameBookmark(cur, cur->ProxyServerUID, srcBookmarks[j].Item, srcBookmarks[j].MappedProxyUID);
            if (!inSrc)
            {
                BookmarkLabel(cur, label, (int)sizeof(label));
                imp->Report(SALIMPORT_REPORT_REMOVED, label);
            }
        }
    }
    for (i = 0; i < srcBookmarks.Count && ok; i++)
    {
        CFTPServer* sb = srcBookmarks[i].Item;
        int mapped = srcBookmarks[i].MappedProxyUID;
        BookmarkLabel(sb, label, (int)sizeof(label));
        if (FindBookmark(newBookmarks, sb, mapped) >= 0) // Add: already present; Replace: twice in the source
        {
            imp->Report(SALIMPORT_REPORT_PRESENT, label);
            continue;
        }
        BOOL replacesCurrent = replace && FindBookmark(Config.FTPServerList, sb, mapped) >= 0;
        sb->ProxyServerUID = mapped;
        char name[BOOKMARKNAME_MAX_SIZE];
        if (!SalCfgImpUniqueName(HandleNULLStr(sb->ItemName), suffix1, suffixN, BookmarkNameExists, &names, name,
                                 BOOKMARKNAME_MAX_SIZE))
        {
            ImportReport(imp, SALIMPORT_REPORT_SKIPPED, IDS_IMPORT_INCOMPLETE, HandleNULLStr(sb->ItemName), CONFIG_FTPSERVERLIST);
            continue;
        }
        BOOL renamed = strcmp(name, HandleNULLStr(sb->ItemName)) != 0;
        if (renamed)
        {
            char* n = SalamanderGeneral->DupStr(name);
            if (n == NULL)
            {
                ok = FALSE;
                break;
            }
            SalamanderGeneral->Free(sb->ItemName);
            sb->ItemName = n;
        }
        BYTE* pwd = NULL;
        int pwdSize = 0;
        BOOL pwdOk = sb->AnonymousConnection ||
                     ImportConvertPassword(imp, srcBookmarks[i].Blob, srcBookmarks[i].BlobSize, dryRun, &pwd, &pwdSize);
        if (sb->AnonymousConnection && pwd != NULL)
        {
            ImportFreeBlob(pwd, pwdSize);
            pwd = NULL;
            pwdSize = 0;
        }
        if (sb->EncryptedPassword != NULL)
            ImportFreeBlob(sb->EncryptedPassword, sb->EncryptedPasswordSize);
        sb->EncryptedPassword = pwd;
        sb->EncryptedPasswordSize = pwdSize;
        sb->SavePassword = pwd != NULL;
        newBookmarks.Add(sb);
        if (!newBookmarks.IsGood())
        {
            newBookmarks.ResetState();
            ok = FALSE;
            break;
        }
        srcBookmarks[i].Item = NULL; // owned by newBookmarks now
        SalCfgImpCopyText(text, (int)sizeof(text), label);
        if (renamed)
            ImportFormat(text, (int)sizeof(text), IDS_IMPORT_RENAMED, label, name);
        if (srcBookmarks[i].ProxyLost)
            ImportAddReason(text, (int)sizeof(text), IDS_IMPORT_NOPROXY);
        if (!pwdOk)
            ImportAddReason(text, (int)sizeof(text), IDS_IMPORT_NOPASSWORD);
        BOOL flagged = renamed || srcBookmarks[i].ProxyLost || !pwdOk;
        imp->Report(replacesCurrent ? SALIMPORT_REPORT_REPLACED : flagged ? SALIMPORT_REPORT_FLAGGED : SALIMPORT_REPORT_ADDED,
                    text);
    }

    // user-defined server types ('*' in front of the name); the program compares type names
    // without the '*', so a user type may meet a built-in one of the same name
    if (replace && ok)
    {
        for (i = newTypes.Count - 1; i >= 0; i--)
        {
            CServerType* cur = newTypes[i];
            if (cur->TypeName == NULL || cur->TypeName[0] != '*')
                continue;
            int index;
            if (!srcTypes.ContainsTypeName(cur->TypeName, NULL, &index) || srcTypes[index]->TypeName == NULL ||
                srcTypes[index]->TypeName[0] != '*') // a user type the source does not have: removed
            {
                TypeLabel(cur, label, (int)sizeof(label));
                imp->Report(SALIMPORT_REPORT_REMOVED, label);
                newTypes.Delete(i);
            }
        }
    }
    for (i = 0; i < srcTypes.Count && ok; i++)
    {
        CServerType* st = srcTypes[i];
        if (st->TypeName == NULL || st->TypeName[0] != '*')
            continue; // built-in types are the program's
        TypeLabel(st, label, (int)sizeof(label));
        int index;
        if (newTypes.ContainsTypeName(st->TypeName, NULL, &index))
        {
            if (SameServerType(newTypes[index], st))
                imp->Report(SALIMPORT_REPORT_PRESENT, label);
            else if (!replace)
                ImportReport(imp, SALIMPORT_REPORT_SKIPPED, IDS_IMPORT_TYPEKEPT, label);
            else
            {
                CServerType* copy = st->MakeCopy();
                if (copy == NULL)
                {
                    ok = FALSE;
                    break;
                }
                newTypes.Delete(index);
                newTypes.Insert(index, copy);
                if (!newTypes.IsGood())
                {
                    newTypes.ResetState();
                    delete copy;
                    ok = FALSE;
                    break;
                }
                imp->Report(SALIMPORT_REPORT_REPLACED, label);
            }
        }
        else
        {
            if (!newTypes.AddServerType(st->TypeName, st))
            {
                ok = FALSE;
                break;
            }
            imp->Report(SALIMPORT_REPORT_ADDED, label);
        }
    }

    if (ok && !dryRun)
    {
        // commit: the complete new lists are exchanged with the current ones (cannot fail);
        // the old contents are released with the local lists
        Config.FTPProxyServerList.ImportSwap(newProxies);
        Config.FTPServerList.ImportSwap(newBookmarks);
        CServerTypeList* types = Config.LockServerTypeList();
        types->ImportSwap(newTypes);
        newTypes.DestroyMembers(); // the old types, released while the list is locked
        Config.UnlockServerTypeList();
        if (resetDefaultProxy)
            Config.DefaultProxySrvUID = -1;
        Config.FTPServerList.CheckProxyServersUID(Config.FTPProxyServerList);
    }
    FreeImportProxies(srcProxies);
    FreeImportBookmarks(srcBookmarks);
    return ok;
}
