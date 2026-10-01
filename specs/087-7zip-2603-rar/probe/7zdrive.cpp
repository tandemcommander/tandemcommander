// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later
//
// 7zdrive.cpp - feature 087 engine driver. Talks to a built 7za.dll through
// the same COM interfaces and the same rules the 7zip plugin uses (format by
// signature, volume callback, UTF-16 password, memory-request bound, names
// cleaned by src/common/salarcname.h), so the engine and those rules can be
// verified without the GUI. Compiled against the interface headers of the
// vendored 7-Zip tree only - no 7-Zip .cpp file is linked, so the same exe can
// also drive an older engine DLL (the binary interface is unchanged).
//
//   7zdrive formats <dll>
//   7zdrive list    <dll> <archive> [-p<pw>]
//   7zdrive extract <dll> <archive> <outdir> [-p<pw>] [-mem=<bytes>]
//   7zdrive test    <dll> <archive> [-p<pw>]
//   7zdrive create  <dll> <archive.7z> <srcdir> [-p<pw>] [-mhe] [-ms=off] [-mx=<n>]
//   7zdrive hostile <dll> <archive.7z>        (entries with unsafe names)
//   7zdrive bigtree <dll> <archive.7z> <n>    (n tiny entries, for timing)
//   7zdrive props   <dll> [-i4]               (every compression setting of the plugin's dialog)
//   any command: -spl=<obj\spl\7zip.spl>      (thread trampoline check, fakespl.c)
//
// Exit code: 0 = success, 1 = operation error(s), 2 = usage / load error.

#include <windows.h>
#include <oleauto.h>

#include <stdio.h>
#include <string>
#include <vector>

#include "Common/MyInitGuid.h"
#include "Common/MyCom.h"
#include "7zip/Archive/IArchive.h"
#include "7zip/IPassword.h"
#include "7zip/IStream.h"
#include "7zip/PropID.h"

#include "../../../src/common/salarcname.h"

// ---------------------------------------------------------------- helpers

static std::string W2U8(const wchar_t* w)
{
    if (w == NULL)
        return std::string();
    int n = WideCharToMultiByte(CP_UTF8, 0, w, -1, NULL, 0, NULL, NULL);
    std::string s(n > 0 ? n - 1 : 0, '\0');
    if (n > 1)
        WideCharToMultiByte(CP_UTF8, 0, w, -1, &s[0], n, NULL, NULL);
    return s;
}

static std::wstring U82W(const char* s)
{
    int n = MultiByteToWideChar(CP_UTF8, 0, s, -1, NULL, 0);
    std::wstring w(n > 0 ? n - 1 : 0, L'\0');
    if (n > 1)
        MultiByteToWideChar(CP_UTF8, 0, s, -1, &w[0], n);
    return w;
}

static std::wstring ArgW(const char* a) // command-line arguments arrive in the ANSI code page
{
    int n = MultiByteToWideChar(CP_ACP, 0, a, -1, NULL, 0);
    std::wstring w(n > 0 ? n - 1 : 0, L'\0');
    if (n > 1)
        MultiByteToWideChar(CP_ACP, 0, a, -1, &w[0], n);
    return w;
}

static std::wstring DirOf(const std::wstring& path)
{
    size_t p = path.find_last_of(L"\\/");
    return p == std::wstring::npos ? L"." : path.substr(0, p);
}

static std::wstring NameOf(const std::wstring& path)
{
    size_t p = path.find_last_of(L"\\/");
    return p == std::wstring::npos ? path : path.substr(p + 1);
}

static void CreateDirs(const std::wstring& dir)
{
    for (size_t i = 3; i < dir.size(); i++)
        if (dir[i] == L'\\')
            CreateDirectoryW(dir.substr(0, i).c_str(), NULL);
    CreateDirectoryW(dir.c_str(), NULL);
}

struct CProp
{
    PROPVARIANT v;
    CProp() { PropVariantInit(&v); }
    ~CProp() { PropVariantClear(&v); }
    bool Bool() const { return v.vt == VT_BOOL && v.boolVal != VARIANT_FALSE; }
    UInt64 U64() const
    {
        switch (v.vt)
        {
        case VT_UI8: return v.uhVal.QuadPart;
        case VT_UI4: return v.ulVal;
        case VT_UI2: return v.uiVal;
        default: return 0;
        }
    }
};

static std::wstring g_password;
static bool g_havePassword = false;
static UInt64 g_memLimit = 0; // 0 = default rule

// the plugin's rule (contracts/plugin-engine.md P5)
static UInt64 AllowedMemory()
{
    if (g_memLimit != 0)
        return g_memLimit;
    MEMORYSTATUSEX ms;
    ms.dwLength = sizeof(ms);
    UInt64 half = GlobalMemoryStatusEx(&ms) ? ms.ullTotalPhys / 2 : ((UInt64)1 << 31);
    UInt64 cap = (UInt64)1 << 32;
    return half < cap ? half : cap;
}

// ---------------------------------------------------------------- streams

class CInFile Z7_final : public IInStream, public IStreamGetSize, public CMyUnknownImp
{
    Z7_IFACES_IMP_UNK_2(IInStream, IStreamGetSize)
    Z7_IFACE_COM7_IMP(ISequentialInStream)
public:
    HANDLE H = INVALID_HANDLE_VALUE;
    ~CInFile()
    {
        if (H != INVALID_HANDLE_VALUE)
            CloseHandle(H);
    }
    bool Open(const std::wstring& path)
    {
        H = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
        return H != INVALID_HANDLE_VALUE;
    }
};

Z7_COM7F_IMF(CInFile::Read(void* data, UInt32 size, UInt32* processed))
{
    DWORD rd = 0;
    BOOL ok = ReadFile(H, data, size, &rd, NULL);
    if (processed)
        *processed = rd;
    return ok ? S_OK : HRESULT_FROM_WIN32(GetLastError());
}

Z7_COM7F_IMF(CInFile::Seek(Int64 offset, UInt32 origin, UInt64* newPos))
{
    LARGE_INTEGER d, n;
    d.QuadPart = offset;
    if (!SetFilePointerEx(H, d, &n, origin))
        return HRESULT_FROM_WIN32(GetLastError());
    if (newPos)
        *newPos = (UInt64)n.QuadPart;
    return S_OK;
}

Z7_COM7F_IMF(CInFile::GetSize(UInt64* size))
{
    LARGE_INTEGER s;
    if (!GetFileSizeEx(H, &s))
        return HRESULT_FROM_WIN32(GetLastError());
    *size = (UInt64)s.QuadPart;
    return S_OK;
}

class COutFile Z7_final : public IOutStream, public CMyUnknownImp
{
    Z7_IFACES_IMP_UNK_1(IOutStream)
    Z7_IFACE_COM7_IMP(ISequentialOutStream)
public:
    HANDLE H = INVALID_HANDLE_VALUE;
    ~COutFile()
    {
        if (H != INVALID_HANDLE_VALUE)
            CloseHandle(H);
    }
    bool Create(const std::wstring& path)
    {
        H = CreateFileW(path.c_str(), GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, 0, NULL);
        return H != INVALID_HANDLE_VALUE;
    }
};

Z7_COM7F_IMF(COutFile::Write(const void* data, UInt32 size, UInt32* processed))
{
    DWORD wr = 0;
    BOOL ok = WriteFile(H, data, size, &wr, NULL);
    if (processed)
        *processed = wr;
    return ok ? S_OK : HRESULT_FROM_WIN32(GetLastError());
}

Z7_COM7F_IMF(COutFile::Seek(Int64 offset, UInt32 origin, UInt64* newPos))
{
    LARGE_INTEGER d, n;
    d.QuadPart = offset;
    if (!SetFilePointerEx(H, d, &n, origin))
        return HRESULT_FROM_WIN32(GetLastError());
    if (newPos)
        *newPos = (UInt64)n.QuadPart;
    return S_OK;
}

Z7_COM7F_IMF(COutFile::SetSize(UInt64 size))
{
    LARGE_INTEGER d;
    d.QuadPart = (LONGLONG)size;
    return SetFilePointerEx(H, d, NULL, FILE_BEGIN) && SetEndOfFile(H) ? S_OK : E_FAIL;
}

class CMemIn Z7_final : public ISequentialInStream, public CMyUnknownImp
{
    Z7_IFACES_IMP_UNK_1(ISequentialInStream)
public:
    std::string Data;
    size_t Pos = 0;
};

Z7_COM7F_IMF(CMemIn::Read(void* data, UInt32 size, UInt32* processed))
{
    size_t n = Data.size() - Pos;
    if (n > size)
        n = size;
    memcpy(data, Data.data() + Pos, n);
    Pos += n;
    if (processed)
        *processed = (UInt32)n;
    return S_OK;
}

// ---------------------------------------------------------------- callbacks

static HRESULT ReturnPassword(BSTR* password)
{
    if (!g_havePassword)
        return E_ABORT; // the plugin: a cancelled prompt
    *password = SysAllocString(g_password.c_str());
    return *password ? S_OK : E_OUTOFMEMORY;
}

static HRESULT AnswerMemory(UInt32 flags, UInt64 requiredSize, UInt64* allowedSize, UInt32* answerFlags)
{
    UInt64 allowed = AllowedMemory();
    printf("  memory request: %llu bytes (flags 0x%X), allowed %llu\n",
           (unsigned long long)requiredSize, flags, (unsigned long long)allowed);
    if (requiredSize <= allowed)
    {
        *allowedSize = allowed;
        *answerFlags = NRequestMemoryAnswerFlags::k_Allow;
    }
    else
        *answerFlags = NRequestMemoryAnswerFlags::k_Limit_Exceeded;
    return S_OK;
}

class COpenCallback Z7_final : public IArchiveOpenCallback,
                               public IArchiveOpenVolumeCallback,
                               public ICryptoGetTextPassword,
                               public IArchiveRequestMemoryUseCallback,
                               public CMyUnknownImp
{
    Z7_IFACES_IMP_UNK_4(IArchiveOpenCallback, IArchiveOpenVolumeCallback, ICryptoGetTextPassword,
                        IArchiveRequestMemoryUseCallback)
public:
    std::wstring Folder, FirstName;
    int VolumesOpened = 0;
};

Z7_COM7F_IMF(COpenCallback::SetTotal(const UInt64*, const UInt64*)) { return S_OK; }
Z7_COM7F_IMF(COpenCallback::SetCompleted(const UInt64*, const UInt64*)) { return S_OK; }

Z7_COM7F_IMF(COpenCallback::GetProperty(PROPID propID, PROPVARIANT* value))
{
    PropVariantInit(value);
    if (propID == kpidName)
    {
        value->vt = VT_BSTR;
        value->bstrVal = SysAllocString(FirstName.c_str());
        return value->bstrVal ? S_OK : E_OUTOFMEMORY;
    }
    return S_OK;
}

Z7_COM7F_IMF(COpenCallback::GetStream(const wchar_t* name, IInStream** inStream))
{
    *inStream = NULL;
    // a sibling in the first part's folder only: a name with a separator is refused
    if (name == NULL || wcschr(name, L'\\') || wcschr(name, L'/') || wcschr(name, L':'))
        return S_FALSE;
    CInFile* f = new CInFile;
    CMyComPtr<IInStream> keep = f;
    if (!f->Open(Folder + L"\\" + name))
        return S_FALSE; // the handler reports a missing volume
    VolumesOpened++;
    *inStream = keep.Detach();
    return S_OK;
}

Z7_COM7F_IMF(COpenCallback::CryptoGetTextPassword(BSTR* password)) { return ReturnPassword(password); }

Z7_COM7F_IMF(COpenCallback::RequestMemoryUse(UInt32 flags, UInt32, UInt32, const wchar_t*, UInt64 requiredSize,
                                             UInt64* allowedSize, UInt32* answerFlags))
{
    return AnswerMemory(flags, requiredSize, allowedSize, answerFlags);
}

class CExtractCallback Z7_final : public IArchiveExtractCallback,
                                  public ICryptoGetTextPassword,
                                  public IArchiveRequestMemoryUseCallback,
                                  public CMyUnknownImp
{
    Z7_IFACES_IMP_UNK_3(IArchiveExtractCallback, ICryptoGetTextPassword, IArchiveRequestMemoryUseCallback)
    Z7_IFACE_COM7_IMP(IProgress)
public:
    IInArchive* Archive = NULL;
    std::wstring OutDir; // empty = test
    int Errors = 0, Files = 0, Skipped = 0, Links = 0;
    std::wstring Current;
    bool SkipResult = false; // the current item was skipped: its result is not ours to judge
};

Z7_COM7F_IMF(CExtractCallback::SetTotal(UInt64)) { return S_OK; }
Z7_COM7F_IMF(CExtractCallback::SetCompleted(const UInt64*)) { return S_OK; }

Z7_COM7F_IMF(CExtractCallback::GetStream(UInt32 index, ISequentialOutStream** outStream, Int32 askExtractMode))
{
    *outStream = NULL;
    Current.clear();
    SkipResult = false;
    if (askExtractMode != NArchive::NExtract::NAskMode::kExtract || OutDir.empty())
        return S_OK;
    CProp path, isDir, isAlt, symLink, hardLink;
    Archive->GetProperty(index, kpidPath, &path.v);
    Archive->GetProperty(index, kpidIsDir, &isDir.v);
    Archive->GetProperty(index, kpidIsAltStream, &isAlt.v);
    Archive->GetProperty(index, kpidSymLink, &symLink.v);
    Archive->GetProperty(index, kpidHardLink, &hardLink.v);
    if (isAlt.Bool())
    {
        Skipped++;
        SkipResult = true;
        return S_OK; // never written (contracts/plugin-engine.md P6)
    }
    std::string raw = W2U8(path.v.vt == VT_BSTR ? path.v.bstrVal : L"");
    char clean[4 * MAX_PATH];
    if (!SalArcCleanItemPath(raw.c_str(), clean, sizeof(clean)))
        return E_FAIL;
    // the plugin's rule (extract.cpp IsLinkItem): a link property, or the Unix
    // symbolic-link mode in the attributes (RAR4 and Unix-made 7z have no link property)
    CProp attrib, posix;
    Archive->GetProperty(index, kpidAttrib, &attrib.v);
    Archive->GetProperty(index, kpidPosixAttrib, &posix.v);
    bool unixLink = attrib.v.vt == VT_UI4 && (attrib.v.ulVal & 0x8000) != 0 &&
                        ((attrib.v.ulVal >> 16) & 0170000) == 0120000 ||
                    posix.v.vt == VT_UI4 && (posix.v.ulVal & 0170000) == 0120000;
    if (unixLink || symLink.v.vt == VT_BSTR && symLink.v.bstrVal && symLink.v.bstrVal[0] ||
        hardLink.v.vt == VT_BSTR && hardLink.v.bstrVal && hardLink.v.bstrVal[0])
    {
        Links++;
        SkipResult = true;
        printf("  skipped link: %s\n", clean); // links are never created (P9)
        return S_OK;
    }
    std::wstring full = OutDir + L"\\" + U82W(clean);
    if (isDir.Bool())
    {
        CreateDirs(full);
        return S_OK;
    }
    CreateDirs(DirOf(full));
    COutFile* f = new COutFile;
    CMyComPtr<ISequentialOutStream> keep = f;
    if (!f->Create(full))
    {
        printf("  cannot create %s\n", W2U8(full.c_str()).c_str());
        return E_FAIL;
    }
    Current = full;
    Files++;
    *outStream = keep.Detach();
    return S_OK;
}

Z7_COM7F_IMF(CExtractCallback::PrepareOperation(Int32)) { return S_OK; }

Z7_COM7F_IMF(CExtractCallback::SetOperationResult(Int32 opRes))
{
    if (SkipResult)
        return S_OK; // a skipped link has no data to judge (a hard link reports "unsupported")
    if (opRes != NArchive::NExtract::NOperationResult::kOK)
    {
        Errors++;
        printf("  operation result %d%s%s\n", (int)opRes, Current.empty() ? "" : " for ",
               W2U8(Current.c_str()).c_str());
        if (!Current.empty())
            DeleteFileW(Current.c_str()); // the plugin removes a half-written file too
    }
    return S_OK;
}

Z7_COM7F_IMF(CExtractCallback::CryptoGetTextPassword(BSTR* password)) { return ReturnPassword(password); }

Z7_COM7F_IMF(CExtractCallback::RequestMemoryUse(UInt32 flags, UInt32, UInt32, const wchar_t*, UInt64 requiredSize,
                                                UInt64* allowedSize, UInt32* answerFlags))
{
    return AnswerMemory(flags, requiredSize, allowedSize, answerFlags);
}

struct CNewItem
{
    std::wstring Name;
    std::wstring DiskPath; // empty = in-memory data
    std::string Data;
    bool IsDir = false;
};

class CUpdateCallback Z7_final : public IArchiveUpdateCallback, public ICryptoGetTextPassword2, public CMyUnknownImp
{
    Z7_IFACES_IMP_UNK_2(IArchiveUpdateCallback, ICryptoGetTextPassword2)
    Z7_IFACE_COM7_IMP(IProgress)
public:
    std::vector<CNewItem> Items;
};

Z7_COM7F_IMF(CUpdateCallback::SetTotal(UInt64)) { return S_OK; }
Z7_COM7F_IMF(CUpdateCallback::SetCompleted(const UInt64*)) { return S_OK; }

Z7_COM7F_IMF(CUpdateCallback::GetUpdateItemInfo(UInt32, Int32* newData, Int32* newProps, UInt32* indexInArchive))
{
    if (newData)
        *newData = 1;
    if (newProps)
        *newProps = 1;
    if (indexInArchive)
        *indexInArchive = (UInt32)(Int32)-1;
    return S_OK;
}

Z7_COM7F_IMF(CUpdateCallback::GetProperty(UInt32 index, PROPID propID, PROPVARIANT* value))
{
    PropVariantInit(value);
    const CNewItem& it = Items[index];
    switch (propID)
    {
    case kpidIsAnti: value->vt = VT_BOOL; value->boolVal = VARIANT_FALSE; break;
    case kpidPath: value->vt = VT_BSTR; value->bstrVal = SysAllocString(it.Name.c_str()); break;
    case kpidIsDir: value->vt = VT_BOOL; value->boolVal = it.IsDir ? VARIANT_TRUE : VARIANT_FALSE; break;
    case kpidSize:
    {
        UInt64 sz = it.Data.size();
        if (!it.DiskPath.empty())
        {
            WIN32_FILE_ATTRIBUTE_DATA fa;
            if (GetFileAttributesExW(it.DiskPath.c_str(), GetFileExInfoStandard, &fa))
                sz = ((UInt64)fa.nFileSizeHigh << 32) | fa.nFileSizeLow;
        }
        value->vt = VT_UI8;
        value->uhVal.QuadPart = sz;
        break;
    }
    case kpidAttrib: value->vt = VT_UI4; value->ulVal = it.IsDir ? FILE_ATTRIBUTE_DIRECTORY : FILE_ATTRIBUTE_ARCHIVE; break;
    case kpidMTime:
    {
        FILETIME ft;
        GetSystemTimeAsFileTime(&ft);
        value->vt = VT_FILETIME;
        value->filetime = ft;
        break;
    }
    default: break;
    }
    return S_OK;
}

Z7_COM7F_IMF(CUpdateCallback::GetStream(UInt32 index, ISequentialInStream** inStream))
{
    *inStream = NULL;
    const CNewItem& it = Items[index];
    if (it.IsDir)
        return S_OK;
    if (!it.DiskPath.empty())
    {
        CInFile* f = new CInFile;
        CMyComPtr<IInStream> keep = f;
        if (!f->Open(it.DiskPath))
            return S_FALSE;
        *inStream = keep.Detach();
        return S_OK;
    }
    CMemIn* m = new CMemIn;
    CMyComPtr<ISequentialInStream> keep = m;
    m->Data = it.Data;
    *inStream = keep.Detach();
    return S_OK;
}

Z7_COM7F_IMF(CUpdateCallback::SetOperationResult(Int32)) { return S_OK; }

Z7_COM7F_IMF(CUpdateCallback::CryptoGetTextPassword2(Int32* passwordIsDefined, BSTR* password))
{
    *passwordIsDefined = g_havePassword ? 1 : 0;
    *password = SysAllocString(g_havePassword ? g_password.c_str() : L"");
    return *password ? S_OK : E_OUTOFMEMORY;
}

// ---------------------------------------------------------------- engine

typedef UINT32(WINAPI* FCreateObject)(const GUID*, const GUID*, void**);
typedef HRESULT(WINAPI* FGetNumberOfFormats)(UINT32*);
typedef HRESULT(WINAPI* FGetHandlerProperty2)(UInt32, PROPID, PROPVARIANT*);

static HMODULE g_dll;
static FCreateObject g_create;

static GUID FormatClsid(int format)
{
    // 23170F69-40C1-278A-1000-000110xx0000 (contracts/plugin-engine.md P1)
    GUID g = {0x23170F69, 0x40C1, 0x278A, {0x10, 0x00, 0x00, 0x01, 0x10, 0x00, 0x00, 0x00}};
    g.Data4[5] = format == SALARC_FORMAT_RAR ? 0x03 : format == SALARC_FORMAT_RAR5 ? 0xCC : 0x07;
    return g;
}

static bool LoadEngine(const char* dll)
{
    g_dll = LoadLibraryW(ArgW(dll).c_str());
    if (!g_dll)
    {
        printf("cannot load %s (error %lu)\n", dll, GetLastError());
        return false;
    }
    g_create = (FCreateObject)GetProcAddress(g_dll, "CreateObject");
    return g_create != NULL;
}

static int DetectFile(const std::wstring& path)
{
    BYTE head[8] = {0};
    DWORD rd = 0;
    HANDLE h = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
    if (h == INVALID_HANDLE_VALUE)
        return -1;
    ReadFile(h, head, sizeof(head), &rd, NULL);
    CloseHandle(h);
    return SalArcDetectFormat(head, (int)rd);
}

static HRESULT OpenArchive(const std::wstring& path, CMyComPtr<IInArchive>& arc, int* volumes)
{
    int format = DetectFile(path);
    if (format <= 0)
    {
        printf("not a 7z/RAR archive (signature)\n");
        return S_FALSE;
    }
    GUID clsid = FormatClsid(format);
    HRESULT hr = g_create(&clsid, &IID_IInArchive, (void**)&arc);
    if (hr != S_OK || !arc)
    {
        printf("CreateObject failed 0x%08lX\n", (unsigned long)hr);
        return E_FAIL;
    }
    CInFile* f = new CInFile;
    CMyComPtr<IInStream> in = f;
    if (!f->Open(path))
        return E_FAIL;
    COpenCallback* cb = new COpenCallback;
    CMyComPtr<IArchiveOpenCallback> cbKeep = cb;
    cb->Folder = DirOf(path);
    cb->FirstName = NameOf(path);
    const UInt64 scan = 1 << 23;
    hr = arc->Open(in, &scan, cb);
    if (volumes)
        *volumes = cb->VolumesOpened;
    if (hr != S_OK)
        printf("Open failed 0x%08lX\n", (unsigned long)hr);
    return hr;
}

static int CmdFormats()
{
    FGetNumberOfFormats num = (FGetNumberOfFormats)GetProcAddress(g_dll, "GetNumberOfFormats");
    FGetHandlerProperty2 prop = (FGetHandlerProperty2)GetProcAddress(g_dll, "GetHandlerProperty2");
    if (!num || !prop)
        return 2;
    UINT32 n = 0;
    num(&n);
    printf("formats: %u\n", n);
    for (UInt32 i = 0; i < n; i++)
    {
        CProp name;
        prop(i, NArchive::NHandlerPropID::kName, &name.v);
        printf("  %s\n", name.v.vt == VT_BSTR ? W2U8(name.v.bstrVal).c_str() : "?");
    }
    return 0;
}

static int CmdList(const std::wstring& path)
{
    CMyComPtr<IInArchive> arc;
    int vols = 0;
    if (OpenArchive(path, arc, &vols) != S_OK)
        return 1;
    UInt32 n = 0;
    arc->GetNumberOfItems(&n);
    printf("items: %u, extra volumes: %d\n", n, vols);
    for (UInt32 i = 0; i < n; i++)
    {
        CProp p, dir, size, enc, alt;
        arc->GetProperty(i, kpidPath, &p.v);
        arc->GetProperty(i, kpidIsDir, &dir.v);
        arc->GetProperty(i, kpidSize, &size.v);
        arc->GetProperty(i, kpidEncrypted, &enc.v);
        arc->GetProperty(i, kpidIsAltStream, &alt.v);
        std::string raw = W2U8(p.v.vt == VT_BSTR ? p.v.bstrVal : L"");
        char clean[4 * MAX_PATH];
        SalArcCleanItemPath(raw.c_str(), clean, sizeof(clean));
        printf("  %c%c%c %12llu  %s%s%s\n", dir.Bool() ? 'D' : '-', enc.Bool() ? 'E' : '-', alt.Bool() ? 'A' : '-',
               (unsigned long long)size.U64(), raw.c_str(), strcmp(raw.c_str(), clean) ? "  ->  " : "",
               strcmp(raw.c_str(), clean) ? clean : "");
    }
    arc->Close();
    return 0;
}

static int CmdExtract(const std::wstring& path, const std::wstring& outDir)
{
    CMyComPtr<IInArchive> arc;
    if (OpenArchive(path, arc, NULL) != S_OK)
        return 1;
    CExtractCallback* cb = new CExtractCallback;
    CMyComPtr<IArchiveExtractCallback> keep = cb;
    cb->Archive = arc;
    cb->OutDir = outDir;
    if (!outDir.empty())
        CreateDirs(outDir);
    HRESULT hr = arc->Extract(NULL, (UInt32)(Int32)-1, outDir.empty() ? 1 : 0, cb);
    printf("%s: result 0x%08lX, files %d, errors %d, alt streams skipped %d, links skipped %d\n",
           outDir.empty() ? "test" : "extract", (unsigned long)hr, cb->Files, cb->Errors, cb->Skipped, cb->Links);
    arc->Close();
    return (hr == S_OK && cb->Errors == 0) ? 0 : 1;
}

static void AddTree(const std::wstring& root, const std::wstring& rel, std::vector<CNewItem>& items)
{
    WIN32_FIND_DATAW fd;
    HANDLE h = FindFirstFileW((root + (rel.empty() ? L"" : L"\\" + rel) + L"\\*").c_str(), &fd);
    if (h == INVALID_HANDLE_VALUE)
        return;
    do
    {
        if (!wcscmp(fd.cFileName, L".") || !wcscmp(fd.cFileName, L".."))
            continue;
        CNewItem it;
        it.Name = rel.empty() ? fd.cFileName : rel + L"\\" + fd.cFileName;
        it.IsDir = (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
        if (!it.IsDir)
            it.DiskPath = root + L"\\" + it.Name;
        items.push_back(it);
        if (it.IsDir)
            AddTree(root, it.Name, items);
    } while (FindNextFileW(h, &fd));
    FindClose(h);
}

static int Create(const std::wstring& arcPath, CUpdateCallback* cb, bool encryptHeaders, bool solid, int level)
{
    CMyComPtr<IArchiveUpdateCallback> keep = cb;
    GUID clsid = FormatClsid(SALARC_FORMAT_7Z);
    CMyComPtr<IOutArchive> out;
    if (g_create(&clsid, &IID_IOutArchive, (void**)&out) != S_OK || !out)
        return 2;
    CMyComPtr<ISetProperties> sp;
    out->QueryInterface(IID_ISetProperties, (void**)&sp);
    if (sp)
    {
        // the property names the plugin uses (7zclient.cpp)
        const wchar_t* names[] = {L"x", L"s", L"he"};
        PROPVARIANT vals[3];
        for (PROPVARIANT& v : vals)
            PropVariantInit(&v);
        vals[0].vt = VT_UI4;
        vals[0].ulVal = (ULONG)level;
        vals[1].vt = VT_BSTR;
        vals[1].bstrVal = SysAllocString(solid ? L"on" : L"off");
        vals[2].vt = VT_BSTR;
        vals[2].bstrVal = SysAllocString(encryptHeaders ? L"on" : L"off");
        HRESULT hr = sp->SetProperties(names, vals, 3);
        for (PROPVARIANT& v : vals)
            PropVariantClear(&v);
        if (hr != S_OK)
            printf("SetProperties 0x%08lX\n", (unsigned long)hr);
    }
    COutFile* f = new COutFile;
    CMyComPtr<ISequentialOutStream> os = f;
    if (!f->Create(arcPath))
        return 2;
    HRESULT hr = out->UpdateItems(os, (UInt32)cb->Items.size(), cb);
    printf("create: result 0x%08lX, items %u\n", (unsigned long)hr, (unsigned)cb->Items.size());
    return hr == S_OK ? 0 : 1;
}

// props: every compression setting the plug-in's dialog offers (dialogs.cpp tables), in
// exactly the property shape 7zclient.cpp SetCompressionParams builds, must be accepted.
// The 16.04 engine rejected the word size with E_INVALIDARG and the plug-in ignored it.
static VARTYPE g_wordVt = VT_UI4; // -i4: the VT_I4 the 0.1.8 plug-in sent (prop = int)

static int SetPluginProps(const wchar_t* method, const wchar_t* dictName, int dictKB, const wchar_t* wordName,
                          int word, int level, bool solid)
{
    GUID clsid = FormatClsid(SALARC_FORMAT_7Z);
    CMyComPtr<IOutArchive> out;
    if (g_create(&clsid, &IID_IOutArchive, (void**)&out) != S_OK || !out)
        return 2;
    CMyComPtr<ISetProperties> sp;
    if (out->QueryInterface(IID_ISetProperties, (void**)&sp) != S_OK || !sp)
        return 2;
    const wchar_t* names[6] = {L"x", L"s", L"0", dictName, wordName};
    PROPVARIANT vals[6];
    for (PROPVARIANT& v : vals)
        PropVariantInit(&v);
    vals[0].vt = VT_UI4;
    vals[0].ulVal = (ULONG)level;
    vals[1].vt = VT_BSTR;
    vals[1].bstrVal = SysAllocString(solid ? L"2g" : L"off");
    UInt32 n = 2;
    if (method != NULL)
    {
        wchar_t d[32];
        swprintf(d, 32, L"%dB", dictKB * 1024);
        vals[2].vt = VT_BSTR;
        vals[2].bstrVal = SysAllocString(method);
        vals[3].vt = VT_BSTR;
        vals[3].bstrVal = SysAllocString(d);
        vals[4].vt = g_wordVt;
        vals[4].ulVal = (ULONG)word;
        n = 5;
    }
    HRESULT hr = sp->SetProperties(names, vals, n);
    for (PROPVARIANT& v : vals)
        PropVariantClear(&v);
    return hr == S_OK ? 0 : 1;
}

static int CmdProps()
{
    static const int lzmaDict[] = {64, 1024, 2048, 3072, 4096, 6144, 8192, 12288, 16384, 24576, 32768, 49152, 65536};
    static const int lzmaWord[] = {8, 12, 16, 24, 32, 48, 64, 96, 128, 192, 256, 273};
    static const int ppmdDict[] = {1024, 2048, 3072, 4096, 6144, 8192, 12288, 16384, 24576, 32768, 49152,
                                   65536, 98304, 131072, 196608, 262144, 393216, 524288, 786432, 1048576, 1572864};
    static const int ppmdWord[] = {2, 3, 4, 5, 6, 7, 8, 10, 12, 14, 16, 20, 24, 28, 32};
    static const int levels[] = {0, 1, 3, 5, 7, 9};
    int tried = 0, failed = 0;
    for (int level : levels)
        for (int solid = 0; solid < 2; solid++)
        {
            tried++;
            if (SetPluginProps(NULL, NULL, 0, NULL, 0, level, solid != 0) != 0)
            {
                failed++;
                printf("rejected: store-only x=%d s=%d\n", level, solid);
            }
            if (level == 0)
                continue;
            for (int d : lzmaDict)
                for (int w : lzmaWord)
                {
                    tried++;
                    if (SetPluginProps(L"LZMA", L"0d", d, L"0fb", w, level, solid != 0) != 0)
                    {
                        failed++;
                        printf("rejected: LZMA d=%dKB fb=%d x=%d\n", d, w, level);
                    }
                }
            for (int d : ppmdDict)
                for (int w : ppmdWord)
                {
                    tried++;
                    if (SetPluginProps(L"PPMd", L"0mem", d, L"0o", w, level, solid != 0) != 0)
                    {
                        failed++;
                        printf("rejected: PPMd mem=%dKB o=%d x=%d\n", d, w, level);
                    }
                }
        }
    printf("props: %d combinations, %d rejected\n", tried, failed);
    return failed == 0 ? 0 : 1;
}

static int Run(int argc, char** argv);

// -spl=<path>: load the stand-in "7zip.spl" (fakespl.c, task T025) before the
// engine and report afterwards whether every engine thread passed the
// trampoline; any engine thread that did not makes the exit code 1
int main(int argc, char** argv)
{
    HMODULE spl = NULL;
    for (int i = 3; i < argc; i++)
        if (strncmp(argv[i], "-spl=", 5) == 0)
        {
            spl = LoadLibraryW(ArgW(argv[i] + 5).c_str());
            if (spl == NULL)
            {
                printf("cannot load %s (error %lu)\n", argv[i] + 5, GetLastError());
                return 2;
            }
        }
    int rc = Run(argc, argv);
    if (spl != NULL)
    {
        typedef int(__cdecl * FReport)(int*, int*, int*);
        FReport report = (FReport)GetProcAddress(spl, "SplReport");
        int engine = 0, wrapped = 0, system = 0;
        int missing = report != NULL ? report(&engine, &wrapped, &system) : -1;
        printf("threads: engine %d, through the trampoline %d, system %d, engine threads NOT wrapped %d\n",
               engine, wrapped, system, missing);
        if (missing != 0 && rc == 0)
            rc = 1;
    }
    return rc;
}

static int Run(int argc, char** argv)
{
    if (argc < 3)
    {
        printf("usage: see the header of 7zdrive.cpp\n");
        return 2;
    }
    std::string cmd = argv[1];
    if (!LoadEngine(argv[2]))
        return 2;
    bool he = false, solid = true;
    int level = 5;
    std::vector<std::string> pos;
    for (int i = 3; i < argc; i++)
    {
        std::string a = argv[i];
        if (a.rfind("-spl=", 0) == 0)
            continue; // handled in main
        if (a.rfind("-p", 0) == 0)
        {
            g_password = ArgW(a.c_str() + 2);
            g_havePassword = true;
        }
        else if (a == "-i4")
            g_wordVt = VT_I4;
        else if (a == "-mhe")
            he = true;
        else if (a == "-ms=off")
            solid = false;
        else if (a.rfind("-mx=", 0) == 0)
            level = atoi(a.c_str() + 4);
        else if (a.rfind("-mem=", 0) == 0)
            g_memLimit = _strtoui64(a.c_str() + 5, NULL, 10);
        else
            pos.push_back(a);
    }
    if (cmd == "formats")
        return CmdFormats();
    if (cmd == "props")
        return CmdProps();
    if (cmd == "list" && pos.size() == 1)
        return CmdList(ArgW(pos[0].c_str()));
    if (cmd == "test" && pos.size() == 1)
        return CmdExtract(ArgW(pos[0].c_str()), L"");
    if (cmd == "extract" && pos.size() == 2)
        return CmdExtract(ArgW(pos[0].c_str()), ArgW(pos[1].c_str()));
    if (cmd == "create" && pos.size() == 2)
    {
        CUpdateCallback* cb = new CUpdateCallback;
        AddTree(ArgW(pos[1].c_str()), L"", cb->Items);
        return Create(ArgW(pos[0].c_str()), cb, he, solid, level);
    }
    if (cmd == "hostile" && pos.size() == 1)
    {
        CUpdateCallback* cb = new CUpdateCallback;
        const wchar_t* names[] = {L"..\\..\\escape_up.txt", L"a\\..\\..\\escape_mid.txt", L"C:\\escape_drive.txt",
                                  L"\\\\srv\\share\\escape_unc.txt", L"/escape_root.txt", L"stream.txt:hidden",
                                  L"x::$DATA", L"con", L"nul.txt", L"trail.", L"bad<>|?*.txt", L"ok\\normal.txt"};
        for (const wchar_t* n : names)
        {
            CNewItem it;
            it.Name = n;
            it.Data = "087 hostile entry\r\n";
            cb->Items.push_back(it);
        }
        return Create(ArgW(pos[0].c_str()), cb, false, false, 1);
    }
    if (cmd == "bigtree" && pos.size() == 2)
    {
        CUpdateCallback* cb = new CUpdateCallback;
        int n = atoi(pos[1].c_str());
        for (int i = 0; i < n; i++)
        {
            CNewItem it;
            wchar_t buf[64];
            swprintf(buf, 64, L"d%03d\\file%05d.txt", i / 100, i);
            it.Name = buf;
            it.Data = "x";
            cb->Items.push_back(it);
        }
        return Create(ArgW(pos[0].c_str()), cb, false, true, 1);
    }
    printf("bad arguments\n");
    return 2;
}
