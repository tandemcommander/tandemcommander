// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

// ************************************************************************************************
//
// C7zClient
//
// 7za.dll library sandbox
//

#include "7za/CPP/Common/StringConvert.h"
#include "7za/CPP/7zip/Common/FileStreams.h"
#include "7za/CPP/7zip/Archive/IArchive.h"
#include "7za/CPP/Windows/PropVariant.h"
#include "7za/CPP/Windows/PropVariantConv.h"
#include "7za/CPP/Windows/DLL.h"
#include "7za/CPP/Windows/WinDefs.h" // feature 087: Windows/Defs.h was renamed in 7-Zip 23.01

#include "extract.h"
#include "update.h"

#include "structs.h"

#ifndef FILE_ATTRIBUTE_UNIX_EXTENSION
// Transfered from p7zip (portable 7zip)
#define FILE_ATTRIBUTE_UNIX_EXTENSION 0x8000 /* trick for Unix */
#endif

#ifndef S_ISLNK
// Transfered from sys/stat.h on Mac (and other Unix systems)
#define S_ISLNK(m) (((m) & 0170000) == 0120000) /* symbolic link */
#endif

// three error states.
// there are situations where TRUE/FALSE is not enough. we have an operation that can encounter an error. sometimes we can
// and want to continue the operation, other times we cannot. if we can continue, we return OPER_CONTINUE,
// if continuing is not possible (out of memory, etc.) -> OPER_CANCEL. if everything is OK -> OPER_OK
#define OPER_OK 0
#define OPER_CONTINUE 1
#define OPER_CANCEL 2

#define E_STOPEXTRACTION (HRESULT)0x8000FEDC

#define MAX_PATH_LEN 1024

typedef UINT32(WINAPI* TCreateObjectFunc)(const GUID* clsID, const GUID* interfaceID, void** outObject);

// used to pass the items that will be extracted
struct CArchiveItemInfo
{
    CSysString NameInArchive; // in the archive (i.e. including the path)
    const CFileData* FileData;
    bool IsDir;

    // feature 087: 'name' as const char* - AString's constructor from char* is
    // explicit since 7-Zip 23.01
    CArchiveItemInfo(const char* name, const CFileData* fd, bool isDir)
    {
        NameInArchive = name;
        FileData = fd;
        IsDir = isDir;
    }
};

// ************************************************************************************************
//
// C7zClient
//

// feature 093: results of a password test against an archive's content
#define PWDTEST_OK 1       // an encrypted item decodes with it
#define PWDTEST_REFUSED 0  // it does not
#define PWDTEST_UNKNOWN -1 // nothing to test it on (no encrypted item, archive not readable)
#define PWDTEST_CANCEL -2  // the user cancelled
#define PWDTEST_BLOCKS 3   // at most this many blocks are asked when both forms are refused

class C7zClient : public NWindows::NDLL::CLibrary, public CPasswordFormChooser
{
public:
    struct CItemData
    {
        UINT32 Idx;
        BOOL Encrypted;
        UINT64 PackedSize;
        char* Method;

        CItemData();
        ~CItemData();
        void SetMethod(const char* method);
    };

protected:
    // feature 087: 'format' = SALARC_FORMAT_7Z / _RAR / _RAR5 (salarcname.h)
    // feature 093: 'keepLoaded' - an object of the engine is alive (or the engine
    // is running on this thread's stack): the library must not be reloaded, which
    // Load() does by freeing it first
    BOOL CreateObject(const GUID* interfaceID, void** object, int format = 1 /* SALARC_FORMAT_7Z */,
                      BOOL keepLoaded = FALSE);

public:
    C7zClient();
    ~C7zClient();

    // feature 087: the other parts of the last archive opened (multi-part RAR),
    // full UTF-8 paths - "unpack and delete" deletes them with the first part
    CObjectVector<AString> OpenedVolumes;
    // feature 087: ListArchive could not add every item to the listing (a path
    // or name too long for the panel) - what is unpacked from it is not the
    // whole archive, so the archive must not be deleted afterwards
    BOOL ListingIncomplete;

    // feature 093 (contract P1): called by the extract callback right after the
    // password was typed; for a 7z archive and a password with a legacy form it
    // tests an encrypted item with the typed text, then with the legacy form:
    // 'password' becomes the PREFERRED form, PasswordOther the other one
    virtual BOOL ChoosePasswordForm(UString& password, HWND progressWnd);

    // feature 093: the other form of the session password of the archive this
    // client serves (empty: the password has one form, or there is none). An
    // item the session password does not open is tried once with it.
    UString PasswordOther;

    BOOL ListArchive(const char* fileName, CSalamanderDirectoryAbstract* dir, CPluginDataInterface*& pluginData, UString& password);

    int Decompress(CSalamanderForOperationsAbstract* salamander, const char* archiveName, const char* outDir,
                   TIndirectArray<CArchiveItemInfo>* itemList, UString& password, BOOL silentDelete = FALSE);

    int TestArchive(CSalamanderForOperationsAbstract* salamander, const char* fileName);

    int Update(CSalamanderForOperationsAbstract* salamander, const char* archiveName, const char* srcPath, BOOL isNewArchive,
               TIndirectArray<CFileItem>* fileList, CCompressParams* compressParams, bool passwordIsDefined, UString password);

    int Delete(CSalamanderForOperationsAbstract* salamander, const char* archiveName,
               TIndirectArray<CArchiveItemInfo>* archiveList, bool passwordIsDefined, UString& password);

protected:
    // feature 093: 'freshPassword' - 'password' was typed for this operation
    // and never checked against the archive (a session password is not fresh)
    BOOL OpenArchive(const char* fileName, IInArchive** archive, UString& password, BOOL quiet = FALSE,
                     BOOL freshPassword = FALSE);

    // feature 093: the last archive OpenArchive opened
    AString OpenedName;      // full UTF-8 path
    int OpenedFormat;        // SALARC_FORMAT_*
    BOOL OpenAskedPassword;  // the engine needed the password to open it (encrypted headers)

    // tests 'password' on the cheapest encrypted item of the 7z archive
    // 'fileName', through a handler of its own (no file is written, nothing is
    // shown); PWDTEST_*. Cancel is polled through 'salamander' (calling thread)
    // or 'progressWnd' (worker thread); both may be NULL.
    // 'which': 0 = the cheapest block's item, 1 = the next one, ... (PWDTEST_UNKNOWN when there is none)
    int TestPassword(const char* fileName, const UString& password, int which, HWND progressWnd,
                     CSalamanderForOperationsAbstract* salamander);
    // typed text first, legacy form second; 'password' = the preferred form, 'other' = the other one
    int ChooseForm(const char* fileName, UString& password, UString& other, HWND progressWnd,
                   CSalamanderForOperationsAbstract* salamander);

    BOOL FillItemData(IInArchive* archive, UINT32 index, C7zClient::CItemData* itemData);
    BOOL AddFileDir(IInArchive* archive, UINT32 idx,
                    CSalamanderDirectoryAbstract* dir, CPluginDataInterface*& pluginData,
                    BOOL* reportTooLongPathErr, const char* archiveName);

    int GetArchiveItemList(IInArchive* archive, TIndirectArray<CArchiveItem>** archiveItems, UINT32* numItems);

    int UpdateMakeUpdateList(TIndirectArray<CFileItem>* fileList, TIndirectArray<CArchiveItem>* archiveItems,
                             TIndirectArray<CUpdateInfo>* updateList);
    int DeleteMakeUpdateList(TIndirectArray<CArchiveItem>* archiveItems, TIndirectArray<CArchiveItemInfo>* deleteList,
                             TIndirectArray<CUpdateInfo>* updateList);

    HRESULT SetCompressionParams(IOutArchive* outArchive, CCompressParams* compressParams);
};
