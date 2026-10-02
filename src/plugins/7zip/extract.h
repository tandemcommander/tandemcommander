// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <map>
#include <vector>

#include "7za/CPP/Common/MyCom.h"
#include "7za/CPP/Common/MyString.h"

#include "7za/CPP/7zip/IPassword.h"

//#include "7za/Common/String.h"
//#include "7za/Common/StdOutStream.h"


//#include "7za/7zip/IPassword.h"

#include "7za/CPP/7zip/Archive/IArchive.h"
//#include "../Common/ZipRegistry.h"
//#include "include/7zip/Archive/IFolder.h"

#include "structs.h"
#include "FStreams.h"

struct CArchiveItemInfo;

typedef std::map<UINT32, CArchiveItemInfo*> ItemsToExtractMap;

// feature 093 (contract P1): decides which form of a just typed password an
// existing archive was encrypted with - the typed text, or the form versions
// up to 0.1.8 derived from it (src/common/salarcpwd.h)
class CPasswordFormChooser
{
public:
    // in: the typed text; out: the form to use. Shows nothing, writes nothing.
    // Returns FALSE when the user cancelled the operation meanwhile.
    virtual BOOL ChoosePasswordForm(UString& password, HWND progressWnd) = 0;
};

// feature 087: 7-Zip 26.03 interface macros (Z7_*, every method throw())
class CExtractCallbackImp Z7_final : public IArchiveExtractCallback,
                                     public ICryptoGetTextPassword,
                                     public IArchiveRequestMemoryUseCallback,
                                     public CMyUnknownImp
{
    Z7_COM_UNKNOWN_IMP_2(ICryptoGetTextPassword, IArchiveRequestMemoryUseCallback)
    Z7_IFACE_COM7_IMP(IProgress)
    Z7_IFACE_COM7_IMP(IArchiveExtractCallback)
    Z7_IFACE_COM7_IMP(ICryptoGetTextPassword)
    Z7_IFACE_COM7_IMP(IArchiveRequestMemoryUseCallback) // feature 087 (P5)

private:
    CQuadWord Total;
    CQuadWord Completed;

    CMyComPtr<IInArchive> ArchiveHandler;
    ItemsToExtractMap& ItemsToExtract;

    const char* TargetDir;
    char* TargetFileName; // UTF-8 full path, U8_MAX_PATH bytes (allocated in the constructor)

    bool ExtractMode;
    struct CProcessedFileInfo
    {
        FILETIME LastWrite;
        bool IsDirectory;
        bool AttributesAreDefined;
        UINT32 Attributes;
        UINT64 Size;
        UString FileName;
        CSysString Name;
    } ProcessedFileInfo;

    CRetryableOutFileStream* OutFileStreamSpec;
    CMyComPtr<ISequentialOutStream> OutFileStream;

    FILETIME UTCLastWriteTimeDefault;
    DWORD AttributesDefault;

    bool PasswordIsDefined;
    UString& Password;
    //  bool Silent;  // Silent is for skip, which is not implemented in 7za.dll

    // synchronization for calls
    CRITICAL_SECTION CSExtract;

    enum EOperationMode
    {
        Ask,
        Keep,
        Delete,
        Overwrite,
        Skip,
        Cancel
    };
    // behavior of the callback when a data error occurs
    BOOL DataErrorSilent; // whether to prompt for Keep or Delete
    EOperationMode DataErrorMode;
    BOOL DataErrorDeleteSilent; // report an error when deleting
    BOOL SilentDelete;

    //  EOperationMode OverwriteMode;
    //  BOOL OverwriteSilent;   // whether to ask about Overwrite or Skip
    DWORD OverwriteSilent;
    BOOL OverwriteSkip;
    BOOL OverwriteCancel;

    BOOL WholeFile;

    HWND hProgWnd;

public:
    CExtractCallbackImp(HWND _hProgWnd, UString& password, ItemsToExtractMap& itemsToExtract);
    ~CExtractCallbackImp();

    BOOL Init(IInArchive* archive, const char* outDir,
              const FILETIME& utcLastWriteTimeDefault, DWORD attributesDefault,
              BOOL silentDelete = FALSE);
    BOOL InitTest(IInArchive* archive);

    int NumErrors;
    int LinksSkipped; // feature 087: link entries not extracted (reported after the operation)
    CPasswordFormChooser* FormChooser; // feature 093: asked once per typed password; may be NULL

    // feature 093 (contract P1): the other form of the password (owned by the
    // client; NULL or empty = one form only, no second pass). In the first pass
    // an encrypted item that fails with a wrong-password / data / CRC result is
    // not reported: it is put on the retry list and extracted again, with the
    // other form, by a second Extract() over exactly that list.
    UString* OtherPassword;
    bool BeginRetryPass();                          // after pass 1; FALSE: no second pass
    UINT32* RetryIndices() { return &RetryList[0]; } // sorted; valid after BeginRetryPass() == true
    UINT32 RetryCount() { return (UINT32)RetryList.size(); }
    bool BeginRedoPass();                           // after pass 2; FALSE: no third pass
    UINT32* RedoIndices() { return &RedoList[0]; }
    UINT32 RedoCount() { return (UINT32)RedoList.size(); }
    void EndRetryPass();                            // after the last pass: which form the session keeps

    const char* GetFileName() { return TargetFileName; }
    FILETIME GetLastWrite() { return ProcessedFileInfo.LastWrite; }
    DWORD GetAttr() { return ProcessedFileInfo.Attributes; }
    UINT64 GetSize() { return ProcessedFileInfo.Size; }
    const char* GetName() { return ProcessedFileInfo.Name; }

    BOOL* GetOverwriteSkip() { return &OverwriteSkip; }
    DWORD* GetOverwriteSilent() { return &OverwriteSilent; }

    void SetOverwriteCancel(BOOL state = TRUE) { OverwriteCancel = state; }

    void Cleanup();

    CQuadWord& GetTotalSize() { return Total; }
    CQuadWord& GetCompletedSize() { return Completed; }

private:
    bool SkipCurrent; // feature 087: the current item is a skipped link
    bool DataErrorTold; // feature 093: the "data error" of an undecodable block was shown
    // feature 093: the two passes
    int Pass;                       // 1; 2: the retry list with the other form; 3: the redo list with the first form
    std::vector<UINT32> RetryList;  // items the first pass could not decode (never one the user skipped)
    std::map<UINT32, bool> RetryHadOutput; // ... and whether the first pass had written output for them
    std::vector<UINT32> RedoList;   // damaged items: failed in pass 2 without output after output in pass 1
    std::vector<std::pair<UINT32, int> > UnrequestedFailed; // pass 1: items not asked for, with their result
    std::vector<UINT32> DeclinedBlocks; // pass 1: blocks of declined items that failed the wrong-form way
    UINT32 CurrentIndex;            // the item between GetStream and SetOperationResult
    bool CurrentRequested;          // ... is one the operation was asked for
    bool CurrentDeclined;           // ... was asked for, but GetStream gave the engine no stream for it
    CArchiveItemInfo* CurrentInfo;  // ... its entry taken out of ItemsToExtract (extraction)
    int Pass1EncOK;                 // encrypted items the preferred form opened
    int Pass2OK;                    // items only the other form opened
    UString PreferredForm;          // the session password while passes 2 and 3 run
    UINT64 ProgressBase;            // progress: a later pass goes on behind the earlier ones
    bool IsEncryptedItem(UINT32 index);
    UINT32 BlockOf(UINT32 index);
    bool DeferCurrent();
    void ResetPasses();
    bool HaveOutFile; // feature 087: this callback opened an output file for the current item
    AString CurrentItemName; // feature 087: the current item's path in the archive (UTF-8), for messages
    bool CurrentIsDir; // feature 087: the current item is a directory this callback created
    char* CleanName;  // feature 087: cleaned item name, U8_MAX_PATH bytes (allocated in the constructor)
    bool IsLinkItem(UINT32 index);
    void ForgetPassword();
    void DiscardOutFile();
    BOOL OnDataError();
    LRESULT Error(int resID, ...);
};
