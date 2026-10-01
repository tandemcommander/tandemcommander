// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"
#include <assert.h>
#include "dbg.h"

#include "Common/MyInitGuid.h"

#include "7zip.h"
#include "7zclient.h"
#include "open.h"
#include "7zthreads.h"
#include "FStreams.h"
#include "../../common/salarcname.h" // feature 087: safe item names, signatures

#include "7zip.rh"
#include "7zip.rh2"
#include "lang\lang.rh"

// ****************************************************************************
//
// C7zClient
//

#ifndef _UNICODE
// feature 087: every supported Windows is NT - CLibrary::Load (the only reader)
// then takes LoadLibraryW, so an install folder outside the code page works
bool g_IsNT = true;
#endif

HINSTANCE g_hInstance;

// {23170F69-40C1-278A-1000-000110070000}

//DEFINE_GUID(CLSID_CFormat7z,
//  0x23170F69, 0x40C1, 0x278A, 0x10, 0x00, 0x00, 0x01, 0x10, 0x07, 0x00, 0x00);
const CLSID CLSID_CFormat7z = {0x23170F69, 0x40C1, 0x278A, {0x10, 0x00, 0x00, 0x01, 0x10, 0x07, 0x00, 0x00}};
// feature 087: the RAR handlers of the 26.03 engine (RarHandler.cpp 0x03, Rar5Handler.cpp 0xCC)
const CLSID CLSID_CFormatRar = {0x23170F69, 0x40C1, 0x278A, {0x10, 0x00, 0x00, 0x01, 0x10, 0x03, 0x00, 0x00}};
const CLSID CLSID_CFormatRar5 = {0x23170F69, 0x40C1, 0x278A, {0x10, 0x00, 0x00, 0x01, 0x10, 0xCC, 0x00, 0x00}};

static const CLSID* FormatClsid(int format)
{
    switch (format)
    {
    case SALARC_FORMAT_RAR: return &CLSID_CFormatRar;
    case SALARC_FORMAT_RAR5: return &CLSID_CFormatRar5;
    default: return &CLSID_CFormat7z;
    }
}
//const CLSID CLSID_CFormatZIP = {0x23170F69, 0x40C1, 0x278A, {0x10, 0x00, 0x00, 0x01, 0x10, 0x01, 0x00, 0x00}};

/*
char *C7zClient::CItemData::GetMethodStr() {
  static char name[64];

  switch (Method) {
    case mUnknown: strcpy(name, "Unknown"); break;
    case mNone:    strcpy(name, "None"); break;
    case mCopy:    strcpy(name, "Copy"); break;
    case mLZMA:    strcpy(name, "LZMA"); break;
    case mBCJ:     strcpy(name, "BJC"); break;
    case mBCJ2:    strcpy(name, "BJC2"); break;
    case mPPMD:    strcpy(name, "PPMD"); break;
    case mDeflate: strcpy(name, "Deflete"); break;
    case mBZip2:   strcpy(name, "BZip2"); break;
    default:       strcpy(name, "Unknown"); break;
  }

  return name;
}
*/

C7zClient::CItemData::CItemData()
{
    Method = NULL;
}

C7zClient::CItemData::~CItemData()
{
    delete[] Method;
}

void C7zClient::CItemData::SetMethod(const char* method)
{
    delete[] Method;
    Method = new char[strlen(method) + 1];
    if (Method == NULL)
        return;
    strcpy(Method, method);
}

///////////////////////////////////////////////////////////////////////////////////////////////////

C7zClient::C7zClient()
{
    ListingIncomplete = FALSE;
}

C7zClient::~C7zClient()
{
}

BOOL C7zClient::CreateObject(const GUID* interfaceID, void** object, int format)
{
    // feature 087: the 26.03 engine's file layer is wide (FString == UString),
    // so the engine is loaded by its wide path - which also works when the
    // installation folder is not representable in the ANSI code page
    WCHAR dllPath[MAX_PATH];
    DWORD len = GetModuleFileNameW(DLLInstance, dllPath, MAX_PATH);
    WCHAR* slash = (len > 0 && len < MAX_PATH) ? wcsrchr(dllPath, L'\\') : NULL;
    if (slash == NULL || (slash - dllPath) + 1 + 7 + 1 > MAX_PATH)
        return FALSE;
    wcscpy(slash + 1, L"7za.dll");

    if (!Load(dllPath))
        return Error(IDS_CANT_LOAD_LIBRARY);

    TCreateObjectFunc createObjectFunc = (TCreateObjectFunc)(void*)GetProcAddress(Get_HMODULE(), "CreateObject");
    if (createObjectFunc == 0)
        return Error(IDS_CANT_GET_CRATEOBJECT);

    if (createObjectFunc(FormatClsid(format), interfaceID, object) != S_OK)
    {
        Free();
        return Error(IDS_CANT_GET_CLASS_OBJECT);
    }

    return TRUE;
}

BOOL C7zClient::OpenArchive(const char* fileName, IInArchive** archive, UString& password, BOOL quiet /* = FALSE*/)
{
    CRetryableInFileStream* fileSpec = new CRetryableInFileStream(NULL);
    CMyComPtr<IInStream> file = fileSpec;

    if (!fileSpec->Open(fileName))
        return Error(IDS_CANT_OPEN_ARCHIVE, quiet, fileName);

    // feature 087: the handler comes from the file's signature (7z, RAR 1.5-4,
    // RAR5); the extension only decided that the plugin was asked. A file whose
    // signature is none of them is reported as an unsupported archive.
    BYTE head[8] = {0};
    UInt32 headLen = 0;
    if (file->Read(head, sizeof(head), &headLen) != S_OK || file->Seek(0, STREAM_SEEK_SET, NULL) != S_OK)
        return Error(IDS_CANT_READ_ARCHIVE, quiet);
    int format = SalArcDetectFormat(head, (int)headLen);
    if (format == SALARC_FORMAT_UNKNOWN)
        return Error(IDS_UNSUPPORTED_ARCHIVE, quiet, fileName);
    OpenedVolumes.Clear();

    CMyComPtr<IInArchive> a;
    if (!CreateObject(&IID_IInArchive, (void**)&a, format))
        return FALSE;

    CArchiveOpenCallbackImp* openCallbackSpec = new CArchiveOpenCallbackImp(password, fileName, &OpenedVolumes);
    CMyComPtr<IArchiveOpenCallback> openCallback(openCallbackSpec);

    HRESULT ret = a->Open(file, 0, openCallback);
    if (E_ABORT == ret)
    {
        // E_ABORT returned on Canceled Password dialog
        return FALSE;
    }
    if (S_OK != ret)
    {
        BOOL hadPassword = !password.IsEmpty();
        // feature 087: forget a password the archive did not open with, so that
        // the next attempt asks again instead of failing with the same one
        WipeUString(password);
        return Error(hadPassword ? IDS_CANT_OPEN_ARCHIVE_PWD : IDS_UNSUPPORTED_ARCHIVE, quiet, fileName);
    }

    *archive = a.Detach();

    return TRUE;
}

BOOL C7zClient::ListArchive(const char* fileName, CSalamanderDirectoryAbstract* dir, CPluginDataInterface*& pluginData, UString& password)
{
    CMyComPtr<IInArchive> inArchive;

    if (!OpenArchive(fileName, &inArchive, password))
        return FALSE;

    UINT32 numItems = 0;
    inArchive->GetNumberOfItems(&numItems);
    UINT32 i;
    ListingIncomplete = FALSE;
    BOOL reportTooLongPathErr = TRUE;
    // Get the path-less archive file name
    LPCTSTR archiveName = _tcsrchr(fileName, '\\');
    if (archiveName)
        archiveName++;
    else
        archiveName = fileName;
    for (i = 0; i < numItems; i++)
        AddFileDir(inArchive, i, dir, pluginData, &reportTooLongPathErr, archiveName);

    return TRUE;
}

BOOL C7zClient::FillItemData(IInArchive* archive, UINT32 index, C7zClient::CItemData* itemData)
{
    NWindows::NCOM::CPropVariant propVariant;

    // index in the archive
    itemData->Idx = index;

    // whether the file is password protected
    if (archive->GetProperty(index, kpidEncrypted, &propVariant) != S_OK)
        itemData->Encrypted = FALSE;
    else if (propVariant.vt != VT_BOOL)
        itemData->Encrypted = FALSE;
    else
        itemData->Encrypted = VARIANT_BOOLToBool(propVariant.boolVal);

    // size of the compressed file
    if (archive->GetProperty(index, kpidPackSize, &propVariant) != S_OK)
        itemData->PackedSize = 0;
    else if (propVariant.vt == VT_EMPTY)
        itemData->PackedSize = 0;
    else
        ConvertPropVariantToUInt64(propVariant, itemData->PackedSize);

    // method (shown in a panel column -> must be UTF-8)
    if (archive->GetProperty(index, kpidMethod, &propVariant) != S_OK)
        itemData->SetMethod("Unknown");
    else if (propVariant.vt == VT_EMPTY)
        itemData->SetMethod("None");
    else
        itemData->SetMethod(UStringToU8(propVariant.bstrVal));

    /*  // 06F10701 is the ID for 7zAES, i.e. encryption
//  if (strstr(itemData->Method, "06F10701") != NULL)
  if (strstr(itemData->Method, "7zAES") != NULL)
    itemData->Encrypted = TRUE;
  else
    itemData->Encrypted = FALSE;*/

    return TRUE;
}

BOOL C7zClient::AddFileDir(IInArchive* archive, UINT32 idx,
                           CSalamanderDirectoryAbstract* dir, CPluginDataInterface*& pluginData,
                           BOOL* reportTooLongPathErr, const char* archiveName)
{
    NWindows::NCOM::CPropVariant propVariant;

    // feature 087: an NTFS alternate data stream stored as an item (RAR5, 7z)
    // is metadata of another item, never a file of its own - not listed, so it
    // can never be extracted (contracts/plugin-engine.md P6)
    if (archive->GetProperty(idx, kpidIsAltStream, &propVariant) == S_OK &&
        propVariant.vt == VT_BOOL && VARIANT_BOOLToBool(propVariant.boolVal))
        return TRUE;
    propVariant.Clear();

    // path (7za keeps it in UTF-16, the panel/interface wants UTF-8)
    archive->GetProperty(idx, kpidPath, &propVariant);
    AString path = UStringToU8(propVariant.vt == VT_BSTR ? propVariant.bstrVal : L"");

    BOOL ret = FALSE;
    LPTSTR p = NULL;
    C7zClient::CItemData* itemData = NULL;

    if (path.IsEmpty())
    {
        // kpidPath is empty -> take the archive name w/o the last extension
        assert(!idx);
        path = archiveName;
        int dot = path.ReverseFind('.');
        if (dot >= 0)
        {
            path.Delete(dot, path.Len() - dot);
        }
    }

    // feature 087: the name the panel shows - and that extraction later joins
    // to the target folder - is cleaned: no "..", no drive/UNC/absolute
    // prefix, no ':' (streams), no characters or device names Windows forbids
    // (contracts/item-names.md). Before 087 a crafted archive could write
    // outside the target folder or into an alternate data stream.
    {
        int cleanSize = path.Len() * 2 + 8; // '_' per component at most, plus "_" and NUL
        char* clean = (char*)malloc(cleanSize);
        if (clean == NULL)
        {
            Error(IDS_INSUFFICIENT_MEMORY);
            return FALSE;
        }
        SalArcCleanItemPath(path, clean, cleanSize);
        path = clean;
        free(clean);
    }
    try
    {
        p = new TCHAR[path.Len() + 2]; // lengthof('\\' + '\0') == 2
        // The typecast to LPCTSTR tells the compiler to call operator const T*() on the returned AString object
        _stprintf(p, "\\%s", (LPCTSTR)path);

        // name
        LPTSTR fileName = _tcsrchr(p, '\\');
        if (fileName != NULL)
        {
            *fileName = '\0';
            fileName++;
        }
        LPTSTR filePath = p;

        CFileData fd;
        fd.Name = SalamanderGeneral->DupStr(fileName);
        if (fd.Name == NULL)
        {
            Error(IDS_INSUFFICIENT_MEMORY);
            throw FALSE;
        } // if

        fd.NameLen = (unsigned)_tcslen(fd.Name); // 087: the 26.03 headers no longer silence C4267
        LPTSTR s = _tcsrchr(fd.Name, '.');
        if (s != NULL)
            fd.Ext = s + 1; // ".cvspass" is treated as an extension on Windows ...
        else
            fd.Ext = fd.Name + fd.NameLen;

        itemData = new C7zClient::CItemData;
        if (!itemData)
        {
            SalamanderGeneral->Free(fd.Name);
            Error(IDS_INSUFFICIENT_MEMORY);
            throw FALSE;
        }

        if (!FillItemData(archive, idx, itemData))
        {
            SalamanderGeneral->Free(fd.Name);
            delete itemData;
            throw FALSE;
        }
        fd.PluginData = (DWORD_PTR)itemData;

        // Modification Time
        archive->GetProperty(idx, kpidMTime, &propVariant);
        fd.LastWrite = propVariant.filetime;

        fd.DosName = NULL;

        // attributes
        archive->GetProperty(idx, kpidAttrib, &propVariant);
        fd.IsLink = 0;
        fd.Attr = propVariant.ulVal;

        if (fd.Attr & FILE_ATTRIBUTE_UNIX_EXTENSION)
        {
            unsigned short mode = fd.Attr >> 16; // stat.st_mode

            if (S_ISLNK(mode))
            {
                fd.IsLink = TRUE;
            }
            fd.Attr &= 0xFFFF; // Get rid of st_mode
        }

        if (itemData->Encrypted)
            fd.Attr |= FILE_ATTRIBUTE_ENCRYPTED;

        fd.Hidden = (fd.Attr & FILE_ATTRIBUTE_HIDDEN) ? 1 : 0;
        fd.IsOffline = 0;

        // is dir
        archive->GetProperty(idx, kpidIsDir, &propVariant);
        if (VARIANT_BOOLToBool(propVariant.boolVal))
        {
            fd.Size = CQuadWord(0, 0);
            fd.Attr |= FILE_ATTRIBUTE_DIRECTORY;
            fd.IsLink = 0;

            if (!SortByExtDirsAsFiles)
                fd.Ext = fd.Name + fd.NameLen; // directories have no extension

            if (dir && !dir->AddDir(filePath, fd, pluginData))
            {
                SalamanderGeneral->Free(fd.Name);
                delete itemData; // already stored in fd.PluginData
                // dir->Clear(pluginData);  // Petr: no reason to throw the rest away
                if (_tcslen(filePath) > MAX_PATH - 5) // Petr: too-long-path test copied from Salamander
                {
                    if (*reportTooLongPathErr)
                    {
                        Error(IDS_ERRADDDIR_TOOLONG);
                        *reportTooLongPathErr = FALSE; // Petr: prevent repeated too-long-path reports, there can be many
                    }
                }
                else
                    Error(IDS_ERROR);
                ListingIncomplete = TRUE; // feature 087
                throw FALSE;
            }
        }
        else
        {
            // file length
            archive->GetProperty(idx, kpidSize, &propVariant);
            ::ConvertPropVariantToUInt64(propVariant, fd.Size.Value);
            // Which is better? Checking *.lnk/pif/url extensions, Unix flags, or both? We do both.
            fd.IsLink |= SalamanderGeneral->IsFileLink(fd.Ext);

            // file
            if (dir && !dir->AddFile(filePath, fd, pluginData))
            {
                SalamanderGeneral->Free(fd.Name);
                delete itemData; // already stored in fd.PluginData
                // dir->Clear(pluginData);  // Petr: no reason to throw the rest away
                if (_tcslen(filePath) > MAX_PATH - 5) // Petr: too-long-path test copied from Salamander
                {
                    if (*reportTooLongPathErr)
                    {
                        Error(IDS_ERRADDFILE_TOOLONG);
                        *reportTooLongPathErr = FALSE; // Petr: prevent repeated too-long-path reports, there can be many
                    }
                }
                else
                    Error(IDS_ERROR);
                ListingIncomplete = TRUE; // feature 087
                throw FALSE;
            }
        }
    }
    catch (BOOL e)
    {
        ret = e;
    }

    delete[] p;

    return TRUE;
}

static int
compare(const void* arg1, const void* arg2)
{
    return *(UINT32*)arg1 - *(UINT32*)arg2;
}

int C7zClient::Decompress(CSalamanderForOperationsAbstract* salamander, const char* archiveName, const char* outDir,
                          TIndirectArray<CArchiveItemInfo>* itemList, UString& password, BOOL silentDelete /* = FALSE*/)
{
    CMyComPtr<IInArchive> inArchive;

    if (!OpenArchive(archiveName, &inArchive, password))
        return OPER_CANCEL;

    UINT32* fileIndex = NULL;
    int ret = OPER_OK;

    try
    {
        if (inArchive == NULL)
        { // Is this test really needed?
            Error(IDS_ERROR);
            throw OPER_CANCEL;
        }

        fileIndex = new UINT32[itemList->Count];
        if (fileIndex == NULL)
        {
            Error(IDS_INSUFFICIENT_MEMORY);
            throw OPER_CANCEL;
        }

        // create an array of indices for extraction
        int count = 0;
        ItemsToExtractMap itemsToExtract;
        int i;
        for (i = 0; i < itemList->Count; i++)
        {
            CArchiveItemInfo* aii = (*itemList)[i];
            if (aii == NULL)
                continue;
            const CFileData* fd = aii->FileData;
            if (fd == NULL)
                continue;
            CItemData* id = (CItemData*)fd->PluginData;
            if (id != NULL)
            {
                try
                {
                    itemsToExtract[id->Idx] = aii;
                    fileIndex[count++] = id->Idx;
                }
                catch (const std::bad_alloc&)
                {
                    Error(IDS_INSUFFICIENT_MEMORY);
                    throw OPER_CANCEL;
                }
            }
            else
                TRACE_I("C7zClient::Decompress(): PluginData == NULL (this should not happen!)");
        }

        // setup callback
        CExtractCallbackImp* extractCallbackSpec = new CExtractCallbackImp(salamander->ProgressGetHWND(), password, itemsToExtract /*, fileIndex, count*/);
        if (extractCallbackSpec == NULL)
        {
            Error(IDS_INSUFFICIENT_MEMORY);
            return OPER_CANCEL;
        }
        CMyComPtr<IArchiveExtractCallback> extractCallback(extractCallbackSpec);

        FILETIME ft;
        extractCallbackSpec->Init(inArchive, outDir /*,&archiveItems*/, ft, 0, silentDelete);
        qsort(fileIndex, count, sizeof(fileIndex[0]), compare);

        // start extraction in a thread
        // this craziness is here because 7za.dll is multi-threaded and could not display our message boxes
        CDecompressParamObject dpo;
        dpo.Archive = inArchive;
        dpo.FileIndex = fileIndex;
        dpo.Count = count;
        dpo.Test = FALSE;
        dpo.Callback = extractCallback;

        HRESULT result = DoDecompress(salamander, &dpo);

        // feature 087: a per-item error (wrong password, data or CRC error) is a
        // failed extraction even when Extract() itself returns S_OK - which the
        // 26.03 engine does (the 16.04 engine's local "JRY FIX" made Extract()
        // return the error instead). Without this, "unpack and delete" could
        // delete the archive after a failed item. Same rule as TestArchive. A skipped
        // link entry (P6b) is not unpacked either, so it makes the result incomplete
        // too; the callers report success only for OPER_OK.
        ret = (result == E_ABORT) ? OPER_CANCEL
                                  : ((result == S_OK && extractCallbackSpec->NumErrors == 0 &&
                                      extractCallbackSpec->LinksSkipped == 0)
                                         ? OPER_OK
                                         : OPER_CONTINUE);

        // check the thread's return code
        if (ret == OPER_CANCEL)
            extractCallbackSpec->Cleanup();

        // feature 087: after an error in an operation that used a password, the
        // remembered password is forgotten - it may be the wrong one (7z reports a
        // wrong password as a plain data error), and without this every later
        // operation in the archive would fail the same way without asking
        if (extractCallbackSpec->NumErrors > 0 && !password.IsEmpty())
            WipeUString(password);

        // feature 087: tell the user that link entries were left out (P6b)
        if (ret != OPER_CANCEL && extractCallbackSpec->LinksSkipped > 0)
        {
            // a count after a colon, not a plural form: the text is machine-translated
            char msg[1024];
            _snprintf_s(msg, _TRUNCATE, LoadStr(IDS_LINKS_SKIPPED), extractCallbackSpec->LinksSkipped);
            SalamanderGeneral->SalMessageBox(SalamanderGeneral->GetMsgBoxParent(), msg, LoadStr(IDS_PLUGINNAME),
                                             MB_OK | MB_ICONINFORMATION);
        }
    }
    catch (int e)
    {
        ret = e;
    }

    delete[] fileIndex;

    return ret;
} /* C7zClient::Decompress */

int C7zClient::TestArchive(CSalamanderForOperationsAbstract* salamander, const char* fileName)
{
    CMyComPtr<IInArchive> inArchive;
    UString Password;

    if (!OpenArchive(fileName, &inArchive, Password, FALSE))
        return OPER_CANCEL;

    int ret = OPER_CONTINUE;

    try
    {

        // setup callback
        ItemsToExtractMap itemsToExtract; // Can stay empty because testing decompresses everything
        CExtractCallbackImp* extractCallbackSpec = new CExtractCallbackImp(salamander->ProgressGetHWND(), Password, itemsToExtract);
        if (extractCallbackSpec == NULL)
        {
            Error(IDS_INSUFFICIENT_MEMORY);
            throw OPER_CANCEL;
        }
        CMyComPtr<IArchiveExtractCallback> extractCallback(extractCallbackSpec);

        extractCallbackSpec->InitTest(inArchive);

        // start extraction in a thread
        // this craziness is here because 7za.dll is multi-threaded and could not display our message boxes
        CDecompressParamObject dpo;
        dpo.Archive = inArchive;
        dpo.FileIndex = NULL;
        dpo.Count = 0xFFFFFFFF /*this will extract entire archive*/;
        dpo.Test = TRUE;
        dpo.Callback = extractCallback;

        HRESULT result = DoDecompress(salamander, &dpo);

        ret = (extractCallbackSpec->NumErrors > 0) ? OPER_CONTINUE : ((result == E_ABORT) ? OPER_CANCEL : ((result == S_OK) ? OPER_OK : OPER_CONTINUE));
    }
    catch (BOOL e)
    {
        ret = e;
    }

    return ret;
} /* C7zClient::TestArchive */

int C7zClient::GetArchiveItemList(IInArchive* archive, TIndirectArray<CArchiveItem>** archiveItems, UINT32* numItems)
{
    UINT32 itemCount = 0;
    archive->GetNumberOfItems(&itemCount);

    TIndirectArray<CArchiveItem>* items = new TIndirectArray<CArchiveItem>(itemCount, 20, dtDelete);
    if (items == NULL)
    {
        Error(IDS_INSUFFICIENT_MEMORY);
        return OPER_CANCEL;
    }

    int i;
    for (i = 0; i < (signed)itemCount; i++)
    {
        NWindows::NCOM::CPropVariant propVariant;
        // path
        archive->GetProperty(i, kpidPath, &propVariant);
        UString path;
        if (propVariant.vt == VT_BSTR && propVariant.bstrVal != NULL)
            path = propVariant.bstrVal;
        // feature 089: the name files are matched against when the archive is updated is the
        // name the panel shows - the cleaned one (feature 087, salarcname.h). With the stored
        // name, a file added into a folder whose name had to be cleaned ("a:b" shown as "a_b")
        // found no match and became a second item. Items that stay are copied by index and
        // deleting matches by index, so only the matching uses this name.
        bool nameIsStoredName = true;
        if (!path.IsEmpty()) // an empty path (a nameless stream) is left alone, as in the listing
        {
            AString raw = UStringToU8(path);
            int cleanSize = (int)raw.Len() * 2 + 8;
            char* clean = (char*)malloc(cleanSize);
            if (clean != NULL)
            {
                if (SalArcCleanItemPath(raw, clean, cleanSize) && strcmp(clean, raw) != 0)
                {
                    path = U8ToUString(clean);
                    nameIsStoredName = false;
                }
                free(clean);
            }
        }

        // Modification Time
        archive->GetProperty(i, kpidMTime, &propVariant);
        FILETIME lastWrite = propVariant.filetime;

        // attributes
        archive->GetProperty(i, kpidAttrib, &propVariant);
        DWORD attr = propVariant.ulVal;

        // is dir
        archive->GetProperty(i, kpidIsDir, &propVariant);
        bool isDir = VARIANT_BOOLToBool(propVariant.boolVal);

        archive->GetProperty(i, kpidSize, &propVariant);
        UINT64 size;
        ::ConvertPropVariantToUInt64(propVariant, size);

        CArchiveItem* ai = new CArchiveItem(i, path, size, attr, lastWrite, isDir, nameIsStoredName);
        if (ai == NULL)
        {
            Error(IDS_INSUFFICIENT_MEMORY);
            return OPER_CANCEL;
        }
        items->Add(ai);
    }

    *numItems = itemCount;
    *archiveItems = items;

    return OPER_OK;
} /* C7zClient::GetArchiveItemList */

//
// archiveItems - items in the archive
// deleteItems - items that will be removed from the archive
// updateList - the resulting list of items that will remain in the archive
//
int C7zClient::DeleteMakeUpdateList(TIndirectArray<CArchiveItem>* archiveItems, TIndirectArray<CArchiveItemInfo>* deleteList,
                                    TIndirectArray<CUpdateInfo>* updateList)
{
    // produce updateList from archiveItems and deleteList, which is the list of items that will remain in the archive
    int archIdx;
    for (archIdx = 0; archIdx < archiveItems->Count; archIdx++)
    {
        // obtain the index of an item in the archive
        int archItemIdx = (*archiveItems)[archIdx]->Idx;
        bool bToBeDeleted = false;

        int delIdx;
        for (delIdx = 0; delIdx < deleteList->Count; delIdx++)
        {
            CArchiveItemInfo* aii = (*deleteList)[delIdx];
            if (aii != NULL)
            {
                const CFileData* fd = aii->FileData;
                if (fd != NULL)
                {
                    CItemData* id = (CItemData*)fd->PluginData;
                    if (id != NULL)
                    {
                        if ((UINT32)archItemIdx == id->Idx)
                        {
                            bToBeDeleted = true;
                            deleteList->Delete(delIdx);
                            break;
                        }
                    }
                }
            }
        }
        if (!bToBeDeleted)
        {
            CUpdateInfo* ui = new CUpdateInfo;
            if (ui == NULL)
            {
                Error(IDS_INSUFFICIENT_MEMORY);
                return OPER_CANCEL;
            }
            ui->ExistsInArchive = 1;
            ui->ArchiveItemIndex = archItemIdx;
            ui->ExistsOnDisk = 1;
            ui->FileItemIndex = -1;
            ui->IsAnti = false;
            ui->NewData = ui->NewProperties = false;
            updateList->Add(ui);
        }
    }

    _ASSERTE(deleteList->Count == 0);
    return OPER_OK;
} /* C7zClient::DeleteMakeUpdateList */

int C7zClient::Delete(CSalamanderForOperationsAbstract* salamander, const char* archiveName,
                      TIndirectArray<CArchiveItemInfo>* deleteList, bool passwordIsDefined, UString& password)
{
    DWORD err;

    // UTF-8 long paths do not fit into MAX_PATH -> keep both buffers on the heap
    char* tmpName = (char*)malloc(U8_MAX_PATH);
    char* srcPath = (char*)malloc(U8_MAX_PATH);
    if (tmpName == NULL || srcPath == NULL)
    {
        free(tmpName);
        free(srcPath);
        Error(IDS_INSUFFICIENT_MEMORY);
        return OPER_CANCEL;
    }

    strcpy(srcPath, archiveName);
    char* rbackslash = strrchr(srcPath, '\\');
    if (rbackslash != NULL)
        *rbackslash = '\0';

    if (!SalamanderGeneral->SalGetTempFileName(srcPath, "sal", tmpName, TRUE, &err))
    {
        free(tmpName);
        free(srcPath);
        SysError(IDS_CANT_CREATE_TMPFILE, err, FALSE);
        return OPER_CANCEL;
    }
    //  TRACE_I("TempName: " << tmpName);

    CMyComPtr<IInArchive> inArchive;

    if (!OpenArchive(archiveName, &inArchive, password))
    {
        free(tmpName);
        free(srcPath);
        return OPER_CANCEL;
    }

    int ret = OPER_CANCEL;
    TIndirectArray<CArchiveItem>* archiveItems = NULL;

    try
    {
        //    HRESULT result;
        IOutArchive* outArchive;

        CMyComPtr<IInArchive> archive2 = inArchive;
        if (archive2.QueryInterface(IID_IOutArchive, &outArchive) != S_OK)
        {
            Error(IDS_UPDATE_NOT_SUPPORTED);
            throw OPER_CANCEL;
        }

        //
        CRetryableOutFileStream* outStreamSpec = new CRetryableOutFileStream(salamander->ProgressGetHWND());
        if (outStreamSpec == NULL)
        {
            Error(IDS_INSUFFICIENT_MEMORY);
            throw OPER_CANCEL;
        }
        CMyComPtr<IOutStream> outStream(outStreamSpec);

        if (!outStreamSpec->Open(tmpName, OPEN_EXISTING))
        {
            Error(IDS_CANT_CREATE_ARCHIVE);
            throw OPER_CANCEL;
        }

        // list the archive contents
        UINT32 numItems = 0;
        if (GetArchiveItemList(inArchive, &archiveItems, &numItems) == OPER_CANCEL)
            throw OPER_CANCEL;

        TIndirectArray<CUpdateInfo> updateList(numItems, 20, dtDelete);
        if (DeleteMakeUpdateList(archiveItems, deleteList, &updateList) == OPER_CANCEL)
            throw OPER_CANCEL;

        CArchiveUpdateCallback* updateCallbackSpec = new CArchiveUpdateCallback(salamander->ProgressGetHWND());
        if (updateCallbackSpec == NULL)
        {
            Error(IDS_INSUFFICIENT_MEMORY);
            throw OPER_CANCEL;
        }
        CMyComPtr<IArchiveUpdateCallback> updateCallback(updateCallbackSpec);

        //    updateCallbackSpec->Init(NULL, archiveItems, &updateList, passwordIsDefined, password);
        updateCallbackSpec->FileItems = NULL;
        updateCallbackSpec->ArchiveItems = archiveItems;
        updateCallbackSpec->UpdateList = &updateList;

        updateCallbackSpec->PasswordIsDefined = passwordIsDefined;
        updateCallbackSpec->Password = password;
        updateCallbackSpec->AskPassword = passwordIsDefined;

        // TODO: what about delete? Can the compression parameters be loaded, and do they need to be set at all?
        //    SetCompressionParams(outArchive, compr);

        // start update in a thread
        // this craziness is here because 7za.dll is multi-threaded and could not display our message boxes
        CUpdateParamObject upo;
        upo.Archive = outArchive;
        upo.Stream = outStream;
        upo.Count = updateList.Count;
        upo.Callback = updateCallback;

        HRESULT result = DoUpdate(salamander, &upo);

        ret = (result == E_ABORT) ? OPER_CANCEL : ((result == S_OK) ? OPER_OK : OPER_CONTINUE);

        outArchive->Release();
        outStream.Release();

        //    if (result == E_ABORT) throw OPER_CANCEL;
        if (ret == S_OK)
        {
            // close the open archive
            inArchive->Close();
            // delete it
            if (DeleteFileU8(archiveName))
            {
                DWORD err2;
                // rename the tmp file to the archive
                if (!SalamanderGeneral->SalMoveFile(tmpName, archiveName, &err2))
                {
                    SysError(IDS_CANT_MOVE_TMPARCHIVE, err2, FALSE, tmpName);
                    throw OPER_CANCEL;
                }
            }
            else
            {
                Error(IDS_CANT_UPDATE_ARCHIVE, FALSE, archiveName);
                throw OPER_CANCEL;
            }
        }
        else
        {
            if (ret == OPER_CANCEL)
                throw OPER_CANCEL;

            NWindows::NCOM::CPropVariant propVariant;
            inArchive->GetArchiveProperty(kpidSolid, &propVariant);
            // report the error and make it clear it is not our fault
            Error(VARIANT_BOOLToBool(propVariant.boolVal) ? IDS_7Z_SOLID_DELETE_UNSUP : IDS_7Z_UPDATE_ERROR);
            /*
      // delete the temp file
      if (!::DeleteFile(tmpName))
      {
        DWORD err = ::GetLastError();
        // report the error
        SysError(IDS_CANT_DELETE_TMPARCHIVE, err, FALSE, tmpName);
        throw OPER_CANCEL;
      }
*/
        }

        //    ret = (result == S_OK) ? OPER_OK : OPER_CONTINUE;
    }
    catch (int e)
    {
        ret = e;
    }

    delete archiveItems;
    DeleteFileU8(tmpName);

    free(tmpName);
    free(srcPath);

    return ret;
} /* C7zClient::Delete */

struct CSortItem
{
    const UString* String;
    int Index;
};

static int __cdecl CompareStrings(const void* a1, const void* a2)
{
    const UString& s1 = *((CSortItem*)a1)->String;
    const UString& s2 = *((CSortItem*)a2)->String;
    return MyStringCompareNoCase(s1, s2);
}

static void
IndirectSort(UStringVector& strings, CIntVector& indexes)
{
    indexes.Clear();
    if (strings.IsEmpty())
        return;
    int numItems = strings.Size();
    //CPointerVector pointers;
    //pointers.Reserve(numItems);
    indexes.Reserve(numItems);
    TDirectArray<CSortItem> pointers(numItems, 1);
    int i;
    for (i = 0; i < numItems; i++)
    {
        CSortItem si;
        si.String = &strings[i];
        si.Index = i;
        pointers.Add(si);
    }
    qsort(&pointers[0], numItems, sizeof(CSortItem), CompareStrings);
    for (i = 0; i < numItems; i++)
    {
        indexes.Add(pointers[i].Index);
    }
}

static int
AddFileUpdateInfo(TIndirectArray<CUpdateInfo>* updateList, int fileIdx)
{
    CUpdateInfo* ui = new CUpdateInfo;
    if (ui == NULL)
    {
        Error(IDS_INSUFFICIENT_MEMORY);
        return OPER_CANCEL;
    }

    ui->NewData = true;
    ui->NewProperties = true;
    ui->ExistsInArchive = false;
    ui->FileItemIndex = fileIdx;
    ui->ExistsOnDisk = true;
    ui->IsAnti = false;
    ui->ExistsInArchive = false;
    updateList->Add(ui);

    return OPER_OK;
}

static int
AddArchiveUpdateInfo(TIndirectArray<CUpdateInfo>* updateList, int archiveIdx)
{
    CUpdateInfo* ui = new CUpdateInfo;
    if (ui == NULL)
    {
        Error(IDS_INSUFFICIENT_MEMORY);
        return OPER_CANCEL;
    }
    ui->ExistsInArchive = true;
    ui->ArchiveItemIndex = archiveIdx;
    ui->ExistsOnDisk = true;
    ui->FileItemIndex = -1;
    ui->IsAnti = false;
    ui->NewData = ui->NewProperties = false;
    updateList->Add(ui);

    return OPER_OK;
}

int C7zClient::UpdateMakeUpdateList(TIndirectArray<CFileItem>* fileList, TIndirectArray<CArchiveItem>* archiveItems,
                                    TIndirectArray<CUpdateInfo>* updateList)
{
    int i;

    // variables for the overwrite dialog
    BOOL overwriteSilent = FALSE;
    enum EOperationMode
    {
        Ask,
        Overwrite,
        Skip
    } overwriteMode = Ask;

    // logically sort fileList
    CIntVector fileIndexes;
    UStringVector fileNames;
    int fileItemCount = fileList->Count;
    for (i = 0; i < fileItemCount; i++)
        fileNames.Add((*fileList)[i]->Name);
    IndirectSort(fileNames, fileIndexes);

    // logically sort archiveList
    CIntVector archiveIndexes;
    UStringVector archiveNames;
    int archiveItemCount = archiveItems->Count;
    for (i = 0; i < archiveItemCount; i++)
        archiveNames.Add((*archiveItems)[i]->Name);
    IndirectSort(archiveNames, archiveIndexes);

    int fileIterIndex = 0;
    int archiveIterIndex = 0;
    while (fileIterIndex < fileItemCount && archiveIterIndex < archiveItemCount)
    {
        int fileIdx = fileIndexes[fileIterIndex];
        int archiveIdx = archiveIndexes[archiveIterIndex];

        CFileItem* fi = (*fileList)[fileIdx];
        const CArchiveItem* ai = (*archiveItems)[archiveIdx];
        int cmpRes = MyStringCompareNoCase(fi->Name, ai->Name);

        if (cmpRes < 0)
        {
            if (AddFileUpdateInfo(updateList, fileIdx) == OPER_CANCEL)
                return OPER_CANCEL;
            fileIterIndex++;
        }
        else if (cmpRes > 0)
        {
            if (AddArchiveUpdateInfo(updateList, archiveIdx) == OPER_CANCEL)
                return OPER_CANCEL;
            archiveIterIndex++;
        }
        else // cmpRes == 0
        {
            // feature 089: since the archive side uses cleaned names, several items can share
            // one name ("a:b.txt" and "a_b.txt" are both "a_b.txt"; names differing only in case
            // always could). The file replaces the item that is really stored under that name
            // when there is one, else the first; the others stay in the archive.
            int runEnd = archiveIterIndex + 1;
            while (runEnd < archiveItemCount &&
                   MyStringCompareNoCase(fi->Name, (*archiveItems)[archiveIndexes[runEnd]]->Name) == 0)
                runEnd++;
            int target = archiveIterIndex;
            int k;
            for (k = archiveIterIndex; k < runEnd; k++)
            {
                if ((*archiveItems)[archiveIndexes[k]]->NameIsStoredName)
                {
                    target = k;
                    break;
                }
            }
            for (k = archiveIterIndex; k < runEnd; k++)
            {
                if (k != target && AddArchiveUpdateInfo(updateList, archiveIndexes[k]) == OPER_CANCEL)
                    return OPER_CANCEL;
            }
            archiveIdx = archiveIndexes[target];
            ai = (*archiveItems)[archiveIdx];

            if (ai->IsDir)
            {
                // feature 089: the archive's directory item stays. Until now neither side was
                // put on the list, so adding a folder that already existed dropped its item
                // (an empty folder vanished, its time and attributes were lost), and a FILE
                // added under the name of a stored folder removed the folder item.
                if (AddArchiveUpdateInfo(updateList, archiveIdx) == OPER_CANCEL)
                    return OPER_CANCEL;
                if (!fi->IsDir)
                    fi->CanDelete = FALSE; // not packed: the name belongs to a folder
            }
            else
            {
                // overwriting only matters for files
                EOperationMode mode = overwriteMode;

                if (mode == Ask)
                {
                    char fifd[1024], aifd[1024];
                    GetInfo(fifd, &fi->LastWriteTime, fi->Size);
                    GetInfo(aifd, &ai->LastWrite, ai->Size);

                    // Salamander's overwrite dialog expects UTF-8 names
                    int userAct = SalamanderGeneral->DialogOverwrite(SalamanderGeneral->GetMsgBoxParent(), BUTTONS_YESALLSKIPCANCEL,
                                                                     UStringToU8(ai->Name), aifd, UStringToU8(fi->FullPath), fifd);

                    switch (userAct)
                    {
                    case DIALOG_YES:
                        mode = Overwrite;
                        break;
                    case DIALOG_ALL:
                        mode = Overwrite;
                        overwriteSilent = TRUE;
                        break;
                    case DIALOG_SKIP:
                        mode = Skip;
                        break;
                    case DIALOG_SKIPALL:
                        mode = Skip;
                        overwriteSilent = TRUE;
                        break;
                    case DIALOG_CANCEL:
                        return OPER_CANCEL;
                    }

                    if (overwriteSilent)
                        overwriteMode = mode;
                }

                switch (mode)
                {
                case Overwrite:
                    if (AddFileUpdateInfo(updateList, fileIdx) == OPER_CANCEL)
                        return OPER_CANCEL;
                    fi->CanDelete = TRUE;
                    break;

                case Skip:
                    if (AddArchiveUpdateInfo(updateList, archiveIdx) == OPER_CANCEL)
                        return OPER_CANCEL;
                    fi->CanDelete = FALSE;
                    break;
                } // switch
            }

            fileIterIndex++;
            archiveIterIndex = runEnd;
        }
    }
    // finish building the list
    for (; fileIterIndex < fileItemCount; fileIterIndex++)
    {
        if (AddFileUpdateInfo(updateList, fileIndexes[fileIterIndex]) == OPER_CANCEL)
            return OPER_CANCEL;
    }

    for (; archiveIterIndex < archiveItemCount; archiveIterIndex++)
    {
        if (AddArchiveUpdateInfo(updateList, archiveIndexes[archiveIterIndex]) == OPER_CANCEL)
            return OPER_CANCEL;
    }

    return OPER_OK;
} /* C7zClient::UpdateMakeUpdateList */

// set compression parameters according to the plugin configuration
HRESULT
C7zClient::SetCompressionParams(IOutArchive* outArchive, CCompressParams* compressParams)
{
    CMyComPtr<ISetProperties> setProperties;
    if (outArchive->QueryInterface(IID_ISetProperties, (void**)&setProperties) == S_OK)
    {
        std::vector<NWindows::NCOM::CPropVariant> values;
        CRecordVector<const wchar_t*> names;

        // compression level
        names.Add(L"x");
        values.push_back(NWindows::NCOM::CPropVariant((UINT32)compressParams->CompressLevel));

        // solid archive
        names.Add(L"s");
        values.push_back(NWindows::NCOM::CPropVariant(compressParams->SolidArchive ? L"2g" : L"off"));

        // TODO: multi volume options

        // set compression parameters only if we are really compressing
        // set them as the last step
        if (compressParams->CompressLevel != COMPRESS_LEVEL_STORE)
        {
            char dictSizeStr[32];
            NWindows::NCOM::CPropVariant prop;
            switch (compressParams->Method)
            {
            case CCompressParams::LZMA:
                // set method
                names.Add(L"0");
                values.push_back(NWindows::NCOM::CPropVariant(L"LZMA"));

                // set dictionary size
                names.Add(L"0d");
                sprintf(dictSizeStr, "%dB", compressParams->DictSize * 1024); // DictSize is in KB
                values.push_back(NWindows::NCOM::CPropVariant(GetUnicodeString(dictSizeStr).Ptr()));

                // set word size
                names.Add(L"0fb");
                prop = (UInt32)compressParams->WordSize; // 087: CPropVariant has no operator=(int)
                values.push_back(prop);
                break;

            case CCompressParams::LZMA2:
                // set method
                names.Add(L"0");
                values.push_back(NWindows::NCOM::CPropVariant(L"LZMA2"));

                // set dictionary size
                names.Add(L"0d");
                sprintf(dictSizeStr, "%dB", compressParams->DictSize * 1024); // DictSize is provided in KB
                values.push_back(NWindows::NCOM::CPropVariant(GetUnicodeString(dictSizeStr).Ptr()));

                // set word size
                names.Add(L"0fb");
                prop = (UInt32)compressParams->WordSize; // 087: CPropVariant has no operator=(int)
                values.push_back(prop);
                break;

            case CCompressParams::PPMd:
                // set method
                names.Add(L"0");
                values.push_back(NWindows::NCOM::CPropVariant(L"PPMd"));

                // set dictionary size
                names.Add(L"0mem");
                sprintf(dictSizeStr, "%dB", compressParams->DictSize * 1024); // DictSize is provided in KB
                values.push_back(NWindows::NCOM::CPropVariant(GetUnicodeString(dictSizeStr).Ptr()));

                // set word size
                names.Add(L"0o");
                prop = (UInt32)compressParams->WordSize; // 087: CPropVariant has no operator=(int)
                values.push_back(prop);
                break;
            } // switch
        }

        RINOK(setProperties->SetProperties(&names[0], &values.front(), names.Size()));
    }

    return S_OK;
}

int C7zClient::Update(CSalamanderForOperationsAbstract* salamander, const char* archiveName,
                      const char* srcPath, BOOL isNewArchive, TIndirectArray<CFileItem>* fileList,
                      CCompressParams* compressParams, bool passwordIsDefined, UString password)
{
    // UTF-8 long paths do not fit into MAX_PATH -> keep the buffer on the heap
    char* tmpName = (char*)malloc(U8_MAX_PATH);
    if (tmpName == NULL)
    {
        Error(IDS_INSUFFICIENT_MEMORY);
        return OPER_CANCEL;
    }

    // strip the filename from archiveName, leaving the target path where we will extract
    strcpy(tmpName, archiveName);
    SalamanderGeneral->CutDirectory(tmpName, NULL);
    DWORD err;
    if (!SalamanderGeneral->SalGetTempFileName(tmpName, "sal", tmpName, TRUE, &err))
    {
        free(tmpName);
        SysError(IDS_CANT_CREATE_TMPFILE, err, FALSE);
        return OPER_CANCEL;
    }

    TIndirectArray<CArchiveItem>* archiveItems = NULL;
    TIndirectArray<CUpdateInfo>* updateList = NULL;
    int ret = OPER_CANCEL;
    CMyComPtr<IInArchive> inArchive;

    try
    {
        CMyComPtr<IOutArchive> outArchive;
        UINT32 numItems = 0;
        if (isNewArchive)
        {
            // new
            if (!CreateObject(&IID_IOutArchive, (void**)&outArchive))
                throw OPER_CANCEL;

            // create an empty array
            archiveItems = new TIndirectArray<CArchiveItem>(1, 20, dtDelete);
            if (archiveItems == NULL)
            {
                Error(IDS_INSUFFICIENT_MEMORY);
                throw OPER_CANCEL;
            }
        }
        else
        {
            // adding items to an existing archive
            if (!OpenArchive(archiveName, &inArchive, password))
                throw OPER_CANCEL;

            // update
            CMyComPtr<IInArchive> archive2 = inArchive;
            if (archive2.QueryInterface(IID_IOutArchive, &outArchive) != S_OK)
            {
                Error(IDS_UPDATE_NOT_SUPPORTED);
                throw OPER_CANCEL;
            }

            // list the archive contents
            if (GetArchiveItemList(inArchive, &archiveItems, &numItems) == OPER_CANCEL)
                throw OPER_CANCEL;
        }

        // output stream
        CRetryableOutFileStream* outStreamSpec = new CRetryableOutFileStream(salamander->ProgressGetHWND());
        if (outStreamSpec == NULL)
        {
            Error(IDS_INSUFFICIENT_MEMORY);
            throw OPER_CANCEL;
        }
        CMyComPtr<IOutStream> outStream(outStreamSpec);

        if (!outStreamSpec->Open(tmpName, OPEN_EXISTING))
        {
            Error(IDS_CANT_CREATE_ARCHIVE);
            throw OPER_CANCEL;
        }

        // size is the number of items in the archive + the number of items being added
        updateList = new TIndirectArray<CUpdateInfo>(numItems + fileList->Count, 20, dtDelete);
        if (updateList == NULL)
        {
            Error(IDS_INSUFFICIENT_MEMORY);
            throw OPER_CANCEL;
        }

        // prepare a 'batch' for processing
        if (UpdateMakeUpdateList(fileList, archiveItems, updateList) == OPER_CANCEL)
            throw OPER_CANCEL;

        // process it
        CArchiveUpdateCallback* updateCallbackSpec = new CArchiveUpdateCallback(salamander->ProgressGetHWND());
        if (updateCallbackSpec == NULL)
        {
            Error(IDS_INSUFFICIENT_MEMORY);
            throw OPER_CANCEL;
        }
        CMyComPtr<IArchiveUpdateCallback> updateCallback(updateCallbackSpec);

        //    updateCallbackSpec->Init(fileList, archiveItems, updateList, passwordIsDefined, password);
        updateCallbackSpec->FileItems = fileList;
        updateCallbackSpec->ArchiveItems = archiveItems;
        updateCallbackSpec->UpdateList = updateList;

        updateCallbackSpec->PasswordIsDefined = passwordIsDefined;
        updateCallbackSpec->Password = password;
        updateCallbackSpec->AskPassword = passwordIsDefined;

        // feature 087: the result is checked now - 0.1.8 sent the word size as VT_I4,
        // which the engine rejected, and the ignored error left the level's default
        // in effect; every value the dialog offers is accepted (probe "props")
        if (SetCompressionParams(outArchive, compressParams) != S_OK)
        {
            TRACE_E("7zip: the engine rejected the compression parameters");
            Error(IDS_ERROR);
            throw OPER_CANCEL;
        }

        // start update in a thread
        // this craziness is here because 7za.dll is multi-threaded and could not display our message boxes
        CUpdateParamObject upo;
        upo.Archive = outArchive;
        upo.Stream = outStream;
        upo.Count = updateList->Count;
        upo.Callback = updateCallback;

        HRESULT result = DoUpdate(salamander, &upo);

        ret = (result == E_ABORT) ? OPER_CANCEL : ((result == S_OK) ? OPER_OK : OPER_CONTINUE);

        outStream.Release();
        outArchive.Release();

        if (ret == OPER_OK)
        {
            // finally rename the tmp file
            if (!isNewArchive)
            {
                // close the open archive
                inArchive->Close();
                // delete it
                if (!DeleteFileU8(archiveName))
                {
                    Error(IDS_CANT_UPDATE_ARCHIVE, FALSE, archiveName);
                    throw OPER_CANCEL;
                }
            }

            DWORD err2;
            // rename the tmp file to the archive
            if (!SalamanderGeneral->SalMoveFile(tmpName, archiveName, &err2))
            {
                SysError(IDS_CANT_MOVE_TMPARCHIVE, err2, FALSE, tmpName);
                throw OPER_CANCEL;
            }
        }
        else
        {
            if (ret == OPER_CANCEL)
                throw OPER_CANCEL;

            //      if (updateCallback.SystemError != 0) {
            //      }
            //      else {
            if (FAILED(result) && ((FACILITY_WIN32 << 16) == (result & 0x7FFF0000)))
            {
                // LastError encoded as HRESULT
                // Oddly, E_OUTOFMEMORY as 0x8007000EL prints as "Not enough storage is available to complete this operation"
                // even without truncating to 16 bits, while 0x80000002L prints as "Ran out of memory"
                SysError(IDS_7Z_FATAL_ERROR, (result == E_OUTOFMEMORY) ? 0x80000002L : (result & 0xFFFF), FALSE);
            }
            else
            {
                int id;

                if (inArchive)
                {
                    // Updating solid archives is supported since some 9.0x version
                    /*          NWindows::NCOM::CPropVariant propVariant;

          inArchive->GetArchiveProperty(kpidSolid, &propVariant);
          id = VARIANT_BOOLToBool(propVariant.boolVal) ? IDS_7Z_SOLID_UPDATE_UNSUP : IDS_7Z_UPDATE_UNKNOWN_ERROR;*/
                    id = IDS_7Z_UPDATE_UNKNOWN_ERROR;
                }
                else
                {
                    id = IDS_7Z_CREATE_UNKNOWN_ERROR;
                }
                Error(id, FALSE, result);
            }
            //      }
            /*
      // delete the temp file
      if (!::DeleteFile(tmpName))
      {
        SysError(IDS_CANT_DELETE_TMPARCHIVE, ::GetLastError(), FALSE, tmpName);
        throw OPER_CANCEL;
      }
*/
        }
    }
    catch (int e)
    {
        ret = e;
    }

    delete archiveItems;
    delete updateList;

    DeleteFileU8(tmpName);
    free(tmpName);

    return ret;
} /* C7zClient::Update */
