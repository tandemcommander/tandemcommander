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
// master password, the program's master password not given)
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

static void ImportReport(CSalamanderSettingsImportAbstract* imp, int kind, int fmtId, const char* a, const char* b = NULL)
{
    char fmt[500];
    lstrcpyn(fmt, LoadStrU8(fmtId), (int)sizeof(fmt));
    char text[2000];
    if (b != NULL)
        _snprintf_s(text, _TRUNCATE, fmt, a, b);
    else
        _snprintf_s(text, _TRUNCATE, fmt, a);
    imp->Report(kind, text);
}

static void BookmarkLabel(const CFTPServer* s, char* buf, int size)
{
    char fmt[200];
    lstrcpyn(fmt, LoadStrU8(IDS_IMPORT_BOOKMARK), (int)sizeof(fmt));
    _snprintf_s(buf, size, _TRUNCATE, fmt, HandleNULLStr(s->ItemName), HandleNULLStr(s->Address));
}

static void ProxyLabel(const CFTPProxyServer* p, char* buf, int size)
{
    char fmt[200];
    lstrcpyn(fmt, LoadStrU8(IDS_IMPORT_PROXY), (int)sizeof(fmt));
    _snprintf_s(buf, size, _TRUNCATE, fmt, HandleNULLStr(p->ProxyName));
}

static const char* NonNull(const char* s) { return s != NULL ? s : ""; }

static BOOL StrEqCI(const char* a, const char* b)
{
    return SalamanderGeneral->StrICmp(NonNull(a), NonNull(b)) == 0;
}

static BOOL StrEq(const char* a, const char* b) { return strcmp(NonNull(a), NonNull(b)) == 0; }

// the same connection (the name is a label: not part of the identity)
static BOOL SameBookmark(const CFTPServer* a, const CFTPServer* b)
{
    return StrEqCI(a->Address, b->Address) && a->Port == b->Port && a->AnonymousConnection == b->AnonymousConnection &&
           (a->AnonymousConnection || StrEq(a->UserName, b->UserName)) && StrEq(a->InitialPath, b->InitialPath) &&
           StrEqCI(a->ServerType, b->ServerType);
}

static BOOL SameProxy(const CFTPProxyServer* a, const CFTPProxyServer* b)
{
    return StrEqCI(a->ProxyName, b->ProxyName) && a->ProxyType == b->ProxyType && StrEqCI(a->ProxyHost, b->ProxyHost) &&
           a->ProxyPort == b->ProxyPort && StrEq(a->ProxyUser, b->ProxyUser) && StrEq(a->ProxyScript, b->ProxyScript);
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

//
// ****************************************************************************
// CFTPProxyServerList: what the import needs
//

int CFTPProxyServerList::AddImportedCopy(const CFTPProxyServer* src, const char* name)
{
    HANDLES(EnterCriticalSection(&ProxyServerListCS));
    int uid = -1;
    CFTPProxyServer* n = new CFTPProxyServer(0);
    if (n != NULL && n->Set(NextFreeProxyUID, name, src->ProxyType, src->ProxyHost, src->ProxyPort, src->ProxyUser,
                            src->ProxyEncryptedPassword, src->ProxyEncryptedPasswordSize, src->SaveProxyPassword,
                            src->ProxyScript))
    {
        Add(n);
        if (IsGood())
            uid = NextFreeProxyUID++;
        else
        {
            ResetState();
            delete n;
        }
    }
    else if (n != NULL)
        delete n;
    HANDLES(LeaveCriticalSection(&ProxyServerListCS));
    return uid;
}

void CFTPProxyServerList::ImportClear()
{
    HANDLES(EnterCriticalSection(&ProxyServerListCS));
    DestroyMembers();
    NextFreeProxyUID = 1;
    HANDLES(LeaveCriticalSection(&ProxyServerListCS));
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

static void ReadSourceProxies(HWND parent, CSalamanderSettingsImportAbstract* imp, CSalamanderRegistryAbstract* reg,
                              HKEY root, TDirectArray<CImportProxy>& out)
{
    HKEY listKey;
    if (!reg->OpenKey(root, CONFIG_FTPPROXYLIST, listKey))
        return;
    char buf[30];
    int i;
    for (i = 1;; i++)
    {
        HKEY sub;
        if (!reg->OpenKey(listKey, _itoa(i, buf, 10), sub))
            break;
        CImportProxy p;
        p.Item = new CFTPProxyServer(0);
        p.Blob = NULL;
        p.BlobSize = 0;
        p.SourceUID = -1;
        if (p.Item != NULL && p.Item->Load(parent, sub, reg))
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
            }
        }
        else
        {
            delete p.Item;
            char what[100];
            _snprintf_s(what, _TRUNCATE, "%d", i);
            ImportReport(imp, SALIMPORT_REPORT_SKIPPED, IDS_IMPORT_INCOMPLETE, what, CONFIG_FTPPROXYLIST);
        }
        reg->CloseKey(sub);
    }
    reg->CloseKey(listKey);
}

static void ReadSourceBookmarks(HWND parent, CSalamanderSettingsImportAbstract* imp, CSalamanderRegistryAbstract* reg,
                                HKEY root, TDirectArray<CImportBookmark>& out)
{
    HKEY listKey;
    if (!reg->OpenKey(root, CONFIG_FTPSERVERLIST, listKey))
        return;
    char buf[30];
    int i;
    for (i = 1;; i++)
    {
        HKEY sub;
        if (!reg->OpenKey(listKey, _itoa(i, buf, 10), sub))
            break;
        CImportBookmark b;
        b.Item = new CFTPServer;
        b.Blob = NULL;
        b.BlobSize = 0;
        b.SourceProxyUID = -2;
        if (b.Item != NULL && b.Item->Load(parent, sub, reg))
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
            }
        }
        else
        {
            delete b.Item;
            char what[100];
            _snprintf_s(what, _TRUNCATE, "%d", i);
            ImportReport(imp, SALIMPORT_REPORT_SKIPPED, IDS_IMPORT_INCOMPLETE, what, CONFIG_FTPSERVERLIST);
        }
        reg->CloseKey(sub);
    }
    reg->CloseKey(listKey);
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

BOOL WINAPI CFTPSettingsImport::ImportSettings(HWND parent, CSalamanderSettingsImportAbstract* imp, BOOL dryRun)
{
    CALL_STACK_MESSAGE2("CFTPSettingsImport::ImportSettings(, , %d)", dryRun);
    HKEY root;
    CSalamanderRegistryAbstract* reg;
    if (!imp->GetSourceKey(&root, &reg))
        return TRUE; // the old program has no FTP settings: nothing to do
    BOOL replace = imp->GetMode() == SALIMPORT_MODE_REPLACE;
    char suffix1[100], suffixN[100];
    lstrcpyn(suffix1, LoadStrU8(IDS_IMPORT_SUFFIX), (int)sizeof(suffix1));
    lstrcpyn(suffixN, LoadStrU8(IDS_IMPORT_SUFFIXN), (int)sizeof(suffixN));

    TDirectArray<CImportProxy> srcProxies(8, 8);
    TDirectArray<CImportBookmark> srcBookmarks(16, 16);
    ReadSourceProxies(parent, imp, reg, root, srcProxies);
    ReadSourceBookmarks(parent, imp, reg, root, srcBookmarks);
    CServerTypeList srcTypes;
    srcTypes.Load(parent, root, reg);

    // the new lists, complete before anything is changed (all or nothing)
    CFTPProxyServerList newProxies;
    CFTPServerList newBookmarks;
    BOOL ok = TRUE;
    if (replace)
        newProxies.ImportClear();
    else
        ok = Config.FTPProxyServerList.CopyMembersToList(newProxies) && Config.FTPServerList.CopyMembersToList(newBookmarks);
    CImportNameCtx names;
    names.Bookmarks = &newBookmarks;
    names.Proxies = &newProxies;
    char label[1000];

    // proxy servers: identical ones are reused, others added under a new UID (and a free name)
    TDirectArray<int> uidMap(8, 8); // pairs: source UID, new UID
    int i, j;
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
        for (j = 0; j < newProxies.GetCount() && newUID < 0; j++)
        {
            if (SameProxy(newProxies.GetAt(j), sp))
                newUID = newProxies.GetAt(j)->ProxyUID;
        }
        if (newUID >= 0)
        {
            imp->Report(replace ? SALIMPORT_REPORT_ADDED : SALIMPORT_REPORT_PRESENT, label);
        }
        else
        {
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
            newUID = newProxies.AddImportedCopy(sp, name);
            if (newUID < 0)
            {
                ok = FALSE;
                break;
            }
            if (strcmp(name, HandleNULLStr(sp->ProxyName)) != 0)
                ImportReport(imp, SALIMPORT_REPORT_FLAGGED, IDS_IMPORT_RENAMED, label, name);
            else if (!pwdOk)
                ImportReport(imp, SALIMPORT_REPORT_FLAGGED, IDS_IMPORT_NOPASSWORD, label);
            else
                imp->Report(SALIMPORT_REPORT_ADDED, label);
        }
        uidMap.Add(srcProxies[i].SourceUID);
        uidMap.Add(newUID);
    }

    // bookmarks
    if (replace && ok)
    {
        for (i = 0; i < Config.FTPServerList.Count; i++)
        {
            CFTPServer* cur = Config.FTPServerList.At(i);
            BOOL inSrc = FALSE;
            for (j = 0; j < srcBookmarks.Count && !inSrc; j++)
                inSrc = SameBookmark(cur, srcBookmarks[j].Item);
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
        BookmarkLabel(sb, label, (int)sizeof(label));
        BOOL present = FALSE;
        for (j = 0; j < newBookmarks.Count && !present; j++)
            present = SameBookmark(newBookmarks.At(j), sb);
        if (present)
        {
            imp->Report(SALIMPORT_REPORT_PRESENT, label);
            continue;
        }
        // the proxy reference, re-mapped to the new list
        int src = srcBookmarks[i].SourceProxyUID;
        int mapped = src;
        BOOL proxyLost = FALSE;
        if (src != -1 && src != -2)
        {
            mapped = -2;
            proxyLost = TRUE;
            int k;
            for (k = 0; k + 1 < uidMap.Count; k += 2)
            {
                if (uidMap[k] == src)
                {
                    mapped = uidMap[k + 1];
                    proxyLost = FALSE;
                }
            }
        }
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
        BYTE* pwd;
        int pwdSize;
        BOOL pwdOk = sb->AnonymousConnection ||
                     ImportConvertPassword(imp, srcBookmarks[i].Blob, srcBookmarks[i].BlobSize, dryRun, &pwd, &pwdSize);
        if (sb->AnonymousConnection)
        {
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
        if (renamed)
            ImportReport(imp, SALIMPORT_REPORT_FLAGGED, IDS_IMPORT_RENAMED, label, name);
        else if (proxyLost)
            ImportReport(imp, SALIMPORT_REPORT_FLAGGED, IDS_IMPORT_NOPROXY, label);
        else if (!pwdOk)
            ImportReport(imp, SALIMPORT_REPORT_FLAGGED, IDS_IMPORT_NOPASSWORD, label);
        else
            imp->Report(SALIMPORT_REPORT_ADDED, label);
    }

    // user-defined server types ('*' in front of the name); built-in ones are the program's
    TIndirectArray<CServerType> addTypes(4, 4, dtNoDelete);
    TDirectArray<int> removeTypes(4, 4);
    CServerTypeList* curTypes = Config.LockServerTypeList();
    for (i = 0; i < srcTypes.Count && ok; i++)
    {
        CServerType* st = srcTypes[i];
        if (st->TypeName == NULL || st->TypeName[0] != '*')
            continue;
        char fmt[200];
        lstrcpyn(fmt, LoadStrU8(IDS_IMPORT_SRVTYPE), (int)sizeof(fmt));
        _snprintf_s(label, _TRUNCATE, fmt, st->TypeName + 1);
        int index;
        if (curTypes->ContainsTypeName(st->TypeName, NULL, &index))
            imp->Report(SALIMPORT_REPORT_PRESENT, label);
        else
        {
            addTypes.Add(st);
            imp->Report(SALIMPORT_REPORT_ADDED, label);
        }
    }
    if (replace && ok)
    {
        for (i = 0; i < curTypes->Count; i++)
        {
            CServerType* cur = curTypes->At(i);
            if (cur->TypeName == NULL || cur->TypeName[0] != '*')
                continue;
            if (!srcTypes.ContainsTypeName(cur->TypeName, NULL, NULL))
            {
                char fmt[200];
                lstrcpyn(fmt, LoadStrU8(IDS_IMPORT_SRVTYPE), (int)sizeof(fmt));
                _snprintf_s(label, _TRUNCATE, fmt, cur->TypeName + 1);
                imp->Report(SALIMPORT_REPORT_REMOVED, label);
                removeTypes.Add(i);
            }
        }
    }
    Config.UnlockServerTypeList();

    if (ok && !dryRun)
    {
        // commit: the lists are swapped in as complete copies
        ok = newProxies.CopyMembersToList(Config.FTPProxyServerList) && newBookmarks.CopyMembersToList(Config.FTPServerList);
        if (ok)
        {
            CServerTypeList* types = Config.LockServerTypeList();
            for (i = removeTypes.Count - 1; i >= 0; i--)
                types->Delete(removeTypes[i]);
            for (i = 0; i < addTypes.Count; i++)
                types->AddServerType(addTypes[i]->TypeName, addTypes[i]);
            Config.UnlockServerTypeList();
            Config.FTPServerList.CheckProxyServersUID(Config.FTPProxyServerList);
        }
    }
    FreeImportProxies(srcProxies);
    FreeImportBookmarks(srcBookmarks);
    return ok;
}
