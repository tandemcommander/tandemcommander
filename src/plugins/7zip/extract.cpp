// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include "7zip.h"
#include "extract.h"
#include "7zip.rh"
#include "7zip.rh2"
#include "lang\lang.rh"
#include "math.h"
#include "dialogs.h"
#include "7zthreads.h"
#include "7zclient.h"

#include "Common/StringConvert.h"
#include "Windows/WinDefs.h" // feature 087: renamed in 7-Zip 23.01
#include "Windows/PropVariant.h"
#include "Windows/PropVariantConv.h"
#include "7zip/IPassword.h"
#include "../../common/salarcname.h" // feature 087: safe item names, signatures
#include "open.h"                       // feature 087: AnswerArchiveMemoryRequest

using namespace NWindows;
using namespace NFile;

CExtractCallbackImp::CExtractCallbackImp(HWND _hProgWnd, UString& password,
                                         ItemsToExtractMap& itemsToExtract) : Password(password), ItemsToExtract(itemsToExtract)
{
    //  Silent = false; // preparation for skip and skip all

    InitializeCriticalSection(&CSExtract);

    OutFileStreamSpec = NULL;
    TargetDir = NULL;
    // the extracted file's full path is UTF-8 and can be long -> heap buffer
    TargetFileName = (char*)malloc(U8_MAX_PATH);
    if (TargetFileName != NULL)
        TargetFileName[0] = '\0';
    CleanName = (char*)malloc(U8_MAX_PATH); // feature 087: scratch for the cleaned item name
    HaveOutFile = false;
    CurrentIsDir = false;
    WholeFile = TRUE;
    hProgWnd = _hProgWnd;
    FormChooser = NULL;
    OtherPassword = NULL;
    DataErrorTold = false;
    ResetPasses();
}

// feature 093
void CExtractCallbackImp::ResetPasses()
{
    Pass = 1;
    RetryList.clear();
    RetryHadOutput.clear();
    RedoList.clear();
    UnrequestedFailed.clear();
    DeclinedBlocks.clear();
    CurrentIndex = 0;
    CurrentRequested = false;
    CurrentDeclined = false;
    CurrentInfo = NULL;
    Pass1EncOK = 0;
    Pass2OK = 0;
    ProgressBase = 0;
    WipeUString(PreferredForm);
}

bool CExtractCallbackImp::IsEncryptedItem(UINT32 index)
{
    NWindows::NCOM::CPropVariant enc;
    return ArchiveHandler && ArchiveHandler->GetProperty(index, kpidEncrypted, &enc) == S_OK &&
           enc.vt == VT_BOOL && enc.boolVal != VARIANT_FALSE;
}

// the block (solid folder) of an item, or (UINT32)-1
UINT32 CExtractCallbackImp::BlockOf(UINT32 index)
{
    NWindows::NCOM::CPropVariant block;
    if (ArchiveHandler && ArchiveHandler->GetProperty(index, kpidBlock, &block) == S_OK && block.vt == VT_UI4)
        return block.ulVal;
    return (UINT32)-1;
}

// The current item goes on the retry list: what this callback wrote for it is
// deleted without a question (never a file it did not open for this item) and
// the item is asked for again in the second pass. Whether it had output is
// remembered: such an item may be a damaged one (see BeginRedoPass).
bool CExtractCallbackImp::DeferCurrent()
{
    try
    {
        if (CurrentInfo != NULL)
            ItemsToExtract[CurrentIndex] = CurrentInfo; // GetStream took it out
        RetryHadOutput[CurrentIndex] = HaveOutFile;
        RetryList.push_back(CurrentIndex);
    }
    catch (...)
    {
        return false; // no memory: reported as a failed item, as before
    }
    DiscardOutFile();
    return true;
}

static int CompareIndices(const void* a, const void* b)
{
    UINT32 x = *(const UINT32*)a, y = *(const UINT32*)b;
    return x < y ? -1 : (x > y ? 1 : 0);
}

// Called after a first pass that ended normally. Settles the items the first
// pass could not judge and starts the second pass when there is a retry list.
bool CExtractCallbackImp::BeginRetryPass()
{
    if (Pass != 1)
        return false;

    // Items the operation did not ask for that failed in the first pass (the
    // engine reports every item of a block up to the last requested one, the
    // others in skip mode - 7zExtract.cpp, CFolderOutStream::OpenFile). When a
    // requested item of the same block goes to the second pass (or would, had
    // the user not skipped it), the block was only read with the wrong form:
    // that says nothing and is no error. In any
    // other block it is what it always was: a failed item, counted, a CRC
    // error with its message.
    for (size_t u = 0; u < UnrequestedFailed.size(); u++)
    {
        UINT32 block = BlockOf(UnrequestedFailed[u].first);
        bool retried = false;
        for (size_t r = 0; block != (UINT32)-1 && r < RetryList.size() && !retried; r++)
            retried = BlockOf(RetryList[r]) == block;
        // ... or a requested item of the block failed the same way but is not
        // retried because the user skipped it: the block was mis-keyed all the same
        for (size_t k = 0; block != (UINT32)-1 && k < DeclinedBlocks.size() && !retried; k++)
            retried = DeclinedBlocks[k] == block;
        if (!retried)
        {
            NumErrors++;
            if (UnrequestedFailed[u].second == NArchive::NExtract::NOperationResult::kCRCError)
                Error(IDS_CRC_FAILED);
        }
    }
    UnrequestedFailed.clear();
    DeclinedBlocks.clear();

    if (RetryList.empty())
        return false;
    if (OtherPassword == NULL || OtherPassword->IsEmpty() || Password.IsEmpty())
    {
        NumErrors += (int)RetryList.size(); // cannot be retried: failed items, never a silent success
        return false;
    }
    qsort(&RetryList[0], RetryList.size(), sizeof(UINT32), CompareIndices);
    Pass = 2;
    PreferredForm = Password;
    Password = *OtherPassword; // 'Password' is the session password: decided again in EndRetryPass
    PasswordIsDefined = true;
    ProgressBase = Total.Value;
    return true;
}

// Called after a second pass that ended normally. An item that HAD output in
// the first pass and failed in the second one at once (no output at all) is
// not a matter of the password's form: it is damaged. It is extracted a third
// and last time with the form of the first pass through the ordinary path, so
// the user gets the keep-or-delete question and the partial file, as always.
bool CExtractCallbackImp::BeginRedoPass()
{
    if (Pass != 2 || RedoList.empty())
        return false;
    qsort(&RedoList[0], RedoList.size(), sizeof(UINT32), CompareIndices);
    Pass = 3;
    Password = PreferredForm;
    PasswordIsDefined = true;
    ProgressBase = Total.Value;
    return true;
}

// Which form the session keeps (called once, after the last pass that ran)
void CExtractCallbackImp::EndRetryPass()
{
    if (Pass != 2 && Pass != 3)
        return;
    if (Password.IsEmpty())
    {
        // forgotten by the handling of a failure: the next operation asks
        if (OtherPassword != NULL)
            WipeUString(*OtherPassword);
    }
    else if (Pass1EncOK == 0 && Pass2OK > 0 && OtherPassword != NULL && !OtherPassword->IsEmpty())
    {
        // everything that could be opened was opened by the other form: it is
        // this archive's password from now on, the former one the alternative
        UString other(*OtherPassword);
        *OtherPassword = PreferredForm;
        WipeUString(Password);
        Password = other;
        WipeUString(other);
    }
    else
    {
        WipeUString(Password);
        Password = PreferredForm; // a minority of items does not change the session password
    }
    WipeUString(PreferredForm);
    Pass = 4; // no further pass
}

CExtractCallbackImp::~CExtractCallbackImp()
{
    WipeUString(PreferredForm);
    free(TargetFileName);
    free(CleanName);
    DeleteCriticalSection(&CSExtract);
}

// silent - if TRUE and a DataError occurs during extraction (usually because of an incorrect password), the file is deleted
// automatically and the user is not prompted (used when extracting a single file for viewing - F3)
BOOL CExtractCallbackImp::Init(IInArchive* archive, const char* outDir,
                               const FILETIME& utcLastWriteTimeDefault, DWORD attributesDefault, BOOL silentDelete /* = FALSE*/)
{
    NumErrors = 0;
    LinksSkipped = 0; // feature 087
    SkipCurrent = false;
    DataErrorTold = false;
    ResetPasses();

    UTCLastWriteTimeDefault = utcLastWriteTimeDefault;
    AttributesDefault = attributesDefault;
    ArchiveHandler = archive;
    TargetDir = outDir;

    //  ItemsToExtract = itemsToExtract;

    PasswordIsDefined = !Password.IsEmpty();

    if (TargetFileName != NULL)
        TargetFileName[0] = '\0';

    // initialize variables for interacting with the user
    SilentDelete = silentDelete;
    if (silentDelete)
    {
        DataErrorMode = Delete;
        DataErrorSilent = TRUE;
        DataErrorDeleteSilent = TRUE;
    }
    else
    {
        DataErrorSilent = FALSE;
        DataErrorMode = Ask;
        DataErrorDeleteSilent = FALSE;
    }

    //
    //  OverwriteMode = Ask;
    //  OverwriteSilent = FALSE;
    OverwriteSilent = 0;
    OverwriteSkip = FALSE;
    OverwriteCancel = FALSE;
    HaveOutFile = false;

    return TargetFileName != NULL && CleanName != NULL; // FALSE when the constructor could not allocate the buffers
}

BOOL CExtractCallbackImp::InitTest(IInArchive* archive)
{
    ArchiveHandler = archive; // feature 087: item names for messages
    DataErrorTold = false;
    ResetPasses();
    NumErrors = 0;
    LinksSkipped = 0; // feature 087
    SkipCurrent = false;
    if (TargetFileName != NULL)
        TargetFileName[0] = '\0';

    OverwriteCancel = FALSE;
    HaveOutFile = false;
    PasswordIsDefined = !Password.IsEmpty();

    return TargetFileName != NULL && CleanName != NULL; // FALSE when the constructor could not allocate the buffers
}

// feature 087: kpidSymLink / kpidHardLink carry the link target for link
// entries (RAR5, 7z with -snl/-snh); empty or absent for ordinary items.
// RAR4 and 7z archives made on Unix have no such property: their symbolic
// links are files whose data is the target text, marked only by the Unix
// mode in the attributes (upper 16 bits, FILE_ATTRIBUTE_UNIX_EXTENSION).
bool CExtractCallbackImp::IsLinkItem(UINT32 index)
{
    if (!ArchiveHandler)
        return false;
    const PROPID ids[] = {kpidSymLink, kpidHardLink};
    for (PROPID id : ids)
    {
        NWindows::NCOM::CPropVariant prop;
        if (ArchiveHandler->GetProperty(index, id, &prop) == S_OK && prop.vt == VT_BSTR &&
            prop.bstrVal != NULL && prop.bstrVal[0] != 0)
            return true;
    }
    NWindows::NCOM::CPropVariant attr;
    if (ArchiveHandler->GetProperty(index, kpidAttrib, &attr) == S_OK && attr.vt == VT_UI4 &&
        (attr.ulVal & FILE_ATTRIBUTE_UNIX_EXTENSION) != 0 && S_ISLNK(attr.ulVal >> 16))
        return true;
    NWindows::NCOM::CPropVariant posix;
    if (ArchiveHandler->GetProperty(index, kpidPosixAttrib, &posix) == S_OK && posix.vt == VT_UI4 &&
        S_ISLNK(posix.ulVal))
        return true;
    return false;
}

// feature 087: overwrites the session password so that the next operation asks
// again (WipeUString cannot be optimised away, unlike a plain memset)
void CExtractCallbackImp::ForgetPassword()
{
    WipeUString(Password);
    PasswordIsDefined = false;
}

// feature 087: closes and deletes the output file of the current item, if this
// callback opened one
void CExtractCallbackImp::DiscardOutFile()
{
    OutFileStream.Release();
    if (HaveOutFile)
    {
        BOOL silent = TRUE;
        SafeDeleteFile(UStringToU8(ProcessedFileInfo.FileName), silent);
        HaveOutFile = false;
    }
}

// feature 087: deletes the file that was being written when the operation was
// cancelled. Only a file this callback opened for the CURRENT item counts
// (HaveOutFile): the old test "a stream object was ever created" also matched
// an item the user chose to Skip at the overwrite prompt, or an unselected item
// of a solid archive, and then deleted the user's existing file or the last
// completely unpacked one.
void CExtractCallbackImp::Cleanup()
{
    if (!WholeFile && HaveOutFile)
    {
        //    TRACE_I("Cleanup File: " << UStringToU8(ProcessedFileInfo.FileName));

        OutFileStream.Release();

        BOOL silent = FALSE;
        SafeDeleteFile(UStringToU8(ProcessedFileInfo.FileName), silent);
        HaveOutFile = false;
    }
}

Z7_COM7F_IMF(CExtractCallbackImp::SetTotal(UINT64 size))
{
    //  TRACE_I("CExtractCallbackImp::SetTotal: size=" << (DWORD)size);

    // feature 093: the second pass continues the bar behind the first one
    Total.Value = (Pass >= 2 ? ProgressBase : 0) + size;
    SendMessage(hProgWnd, WM_7ZIP, WM_7ZIP_SETTOTAL, (LPARAM)&Total);

    return S_OK;
}

Z7_COM7F_IMF(CExtractCallbackImp::SetCompleted(const UINT64* completeValue))
{
    //  TRACE_I("CExtractCallbackImp::SetCompleted: completeValue=" << (DWORD)(*completeValue));

    if (completeValue != NULL)
    {
        Completed.Value = (Pass >= 2 ? ProgressBase : 0) + *completeValue;

        return (HRESULT)SendMessage(hProgWnd, WM_7ZIP, WM_7ZIP_PROGRESS, (LPARAM)&Completed);
    }

    return S_OK;
}

Z7_COM7F_IMF(CExtractCallbackImp::GetStream(UINT32 index, ISequentialOutStream** outStream, INT32 askExtractMode))
{
    HRESULT ret = S_OK;

    // we already pressed cancel and yet the callback was invoked again (caused by the 7za.dll implementation)
    if (OverwriteCancel)
        return E_ABORT;

    EnterCriticalSection(&CSExtract);

    try
    {
        /*    char u[1024];
    sprintf(u, "CExtractCallbackImp::GetStream: index: %d, askExtractMode: %d", index, askExtractMode);
    TRACE_I(u);
*/
        //    TRACE_I("CExtractCallbackImp::GetStream: index=" << index << ", askExtractMode=" << askExtractMode);

        *outStream = NULL;
        OutFileStream.Release();
        SkipCurrent = false;
        HaveOutFile = false;
        CurrentIsDir = false;

        // feature 093: which item the coming result belongs to, and whether the
        // operation asked for it (a test asks for every item)
        // CurrentDeclined: the item was asked for, but this callback gives the
        // engine no stream for it (the user's Skip at the overwrite question, a
        // file that could not be created, a name that could not be built). The
        // 7z handler then treats the item as skipped: PrepareOperation gets
        // kSkip, so ExtractMode is false for it (7zExtract.cpp,
        // CFolderOutStream::OpenFile: "askMode == kExtract && !realOutStream").
        CurrentIndex = index;
        CurrentInfo = NULL;
        CurrentDeclined = false;
        CurrentRequested = (TargetDir == NULL) || ItemsToExtract.find(index) != ItemsToExtract.end();

        // feature 087: the item's name for a message about it - also when testing
        // and for an item that gets no output file
        CurrentItemName.Empty();
        if (ArchiveHandler)
        {
            NWindows::NCOM::CPropVariant path;
            if (ArchiveHandler->GetProperty(index, kpidPath, &path) == S_OK && path.vt == VT_BSTR && path.bstrVal != NULL)
                CurrentItemName = UStringToU8(path.bstrVal);
        }

        // if we are extracting a file
        if (askExtractMode == NArchive::NExtract::NAskMode::kExtract)
        {
            if (TargetFileName == NULL)
            {
                Error(IDS_INSUFFICIENT_MEMORY);
                throw E_ABORT;
            }

            // feature 087: find(), not operator[] - the callback is throw() since 26.03,
            // and operator[] would insert (allocate) for an index that is not selected
            ItemsToExtractMap::const_iterator it = ItemsToExtract.find(index);
            const CArchiveItemInfo* aii = (it != ItemsToExtract.end()) ? it->second : NULL;
            if (!aii)
            {
                // Already extracted? Not selected for extraction?
                throw S_OK;
            }
            CurrentInfo = it->second; // feature 093: put back if the item goes to the second pass
            ItemsToExtract.erase(index);

            // feature 087 (contracts/plugin-engine.md P6b): a symbolic or hard link
            // entry is never extracted - the plugin creates no links, a hard link
            // has no data of its own (the engine answers "unsupported") and a
            // symbolic link's data is only its target text. Counted and reported.
            if (IsLinkItem(index))
            {
                LinksSkipped++;
                SkipCurrent = true;
                throw S_OK;
            }
            const CFileData* fd = aii->FileData;
            // fd is certainly not NULL

            // Because we passed a list of CArchiveItem objects with all the information we need, we can extract directly.
            // However, we need reverse mapping (a hash function) to tell us which item index to use,
            // because this function receives the index within the archive.
            //
            // We could save memory and retrieve the properties we need via ArchiveHandler->GetProperty,
            // but names are a problem: GetProperty returns path+filename relative to the archive root, and if we extract
            // from a different root, we would have to strip the path.

            ProcessedFileInfo.Attributes = fd->Attr;
            ProcessedFileInfo.AttributesAreDefined = true;

            ProcessedFileInfo.IsDirectory = aii->IsDir;
            ProcessedFileInfo.LastWrite = fd->LastWrite;
            ProcessedFileInfo.Size = fd->Size.Value;
            ProcessedFileInfo.Name = aii->NameInArchive;

            // TODO: check for free space

            // TargetDir and NameInArchive are UTF-8 (interface 104)
            strcpy(TargetFileName, TargetDir);
            // feature 087 (defence in depth): the name was cleaned when the archive
            // was listed (7zclient.cpp AddFileDir); clean it again right where it
            // is joined to the target, so no path can ever leave the target folder
            // or address an alternate data stream (contracts/item-names.md)
            if (SalArcCleanItemPath(aii->NameInArchive, CleanName, U8_MAX_PATH) &&
                SalamanderGeneral->SalPathAppend(TargetFileName, CleanName, U8_MAX_PATH))
            {
                ProcessedFileInfo.FileName = U8ToUString(TargetFileName);

                // Show file name in the progress dialog
                SendMessage(hProgWnd, WM_7ZIP, WM_7ZIP_ADDTEXT, (LPARAM)GetName());

                if (ProcessedFileInfo.IsDirectory)
                {
                    // create the directory if it does not already exist
                    SalamanderGeneral->CheckAndCreateDirectory(TargetFileName);
                    CurrentIsDir = true;
                    throw S_OK;
                }
                else
                {
                    // WARNING! This performs the overwrite test
                    CCreateFileParams cfp;
                    char fileInfo[100];

                    FILETIME ftLW(GetLastWrite());
                    GetInfo(fileInfo, &ftLW, GetSize());
                    cfp.FileInfo = fileInfo;
                    cfp.FileName = GetFileName();
                    cfp.Name = GetName();
                    cfp.pSilent = GetOverwriteSilent();
                    cfp.pSkip = GetOverwriteSkip();

                    if (SendMessage(hProgWnd, WM_7ZIP, WM_7ZIP_CREATEFILE, (LPARAM)&cfp))
                    {
                        if (!*GetOverwriteSkip())
                            SetOverwriteCancel();
                    }

                    *outStream = NULL;
                    if (OverwriteSkip)
                    {
                        CurrentDeclined = true; // feature 093: the user's own file stays, the item is never retried
                        throw S_OK;
                    }
                    // the overall operation cannot continue (cancel)
                    if (OverwriteCancel)
                        throw E_ABORT;

                    // open the stream for extraction
                    // at this point there is an empty file with FILE_ATTRIBUTES_NORMAL
                    // it is the result of the overwrite test - see above

                    // if the path we are extracting to does not exist -> create it
                    // ('\\' cannot occur inside a UTF-8 multibyte sequence)
                    char* lastComp = strrchr(TargetFileName, '\\');
                    if (lastComp != NULL)
                    {
                        *lastComp = '\0';
                        SalamanderGeneral->CheckAndCreateDirectory(TargetFileName);
                    } // if

                    OutFileStreamSpec = new CRetryableOutFileStream(hProgWnd);
                    CMyComPtr<ISequentialOutStream> outStreamLoc(OutFileStreamSpec);
                    if (!OutFileStreamSpec->Open(UStringToU8(ProcessedFileInfo.FileName), OPEN_ALWAYS))
                    {
                        SysError(IDS_ERROR, ::GetLastError());
                        NumErrors++;
                        CurrentDeclined = true; // feature 093: reported and counted here
                        throw S_OK;
                    }
                    OutFileStream = outStreamLoc;
                    // from here the file is this item's: a cancel before its result (e.g. at
                    // the password prompt, which RAR5 shows after this call) deletes it
                    HaveOutFile = true;
                    WholeFile = FALSE;
                    *outStream = outStreamLoc.Detach();
                }
            }
            else
            {
                *outStream = NULL;
                NumErrors++; // feature 087: the item is not unpacked - the operation is not a success
                CurrentDeclined = true; // feature 093: reported and counted here

                char errText[1000];
                _snprintf_s(errText, _TRUNCATE, LoadStr(IDS_NAMEISTOOLONG), (const char*)(aii->NameInArchive), TargetFileName);
                SalamanderGeneral->ShowMessageBox(errText, LoadStr(IDS_PLUGINNAME), MSGBOX_ERROR);
            }
        }
        else
        {
            *outStream = NULL;
        }
    }
    catch (HRESULT e)
    {
        ret = e;
    }
    catch (...) // feature 087: e.g. std::bad_alloc must not leave a throw() method
    {
        ret = E_OUTOFMEMORY;
    }

    LeaveCriticalSection(&CSExtract);

    return ret;
}

Z7_COM7F_IMF(CExtractCallbackImp::PrepareOperation(INT32 askExtractMode))
{
    /*  char u[1024];
  sprintf(u, "CExtractCallbackImp::PrepareOperation: askExtractMode: %d", askExtractMode);
  TRACE_I(u);
*/
    WholeFile = FALSE;
    ExtractMode = false;
    switch (askExtractMode)
    {
    case NArchive::NExtract::NAskMode::kExtract:
        ExtractMode = true;
        //      TRACE_I("CExtractCallbackImp::PrepareOperation: Extract!");
        break;

    case NArchive::NExtract::NAskMode::kTest:
        //      TRACE_I("CExtractCallbackImp::PrepareOperation: Test!");
        break;

    case NArchive::NExtract::NAskMode::kSkip:
        //      TRACE_I("CExtractCallbackImp::PrepareOperation: Skip!");
        break;
    }

    return S_OK;
}

//
// Let the user choose whether to keep or delete the damaged file
//
// TRUE if we continue
// FALSE if canceled
BOOL CExtractCallbackImp::OnDataError()
{
    EOperationMode mode = DataErrorMode;

    if (DataErrorMode == Ask)
    {
        TCHAR btnBuffer[1024];
        /* used by the export_mnu.py script that generates salmenu.mnu for Translator
           we let the message box buttons resolve hotkey collisions by simulating a menu
MENU_TEMPLATE_ITEM MsgBoxButtons[] =
{
  {MNTT_PB, 0
  {MNTT_IT, IDS_BTN_DELETE
  {MNTT_IT, IDS_BTN_KEEP
  {MNTT_PE, 0
};
*/
        _stprintf(btnBuffer, _T("%d\t%s\t%d\t%s"),
                  DIALOG_YES, LoadStr(IDS_BTN_DELETE),
                  //      DIALOG_ALL, LoadStr(IDS_BTN_DELETE_ALL),
                  DIALOG_NO, LoadStr(IDS_BTN_KEEP)
                  //      DIALOG_SKIPALL, LoadStr(IDS_BTN_KEEP_ALL)
                  //  DIALOG_CANCEL, LoadStr(IDS_BTN_)
        );
        //buffer: "1\t&Start\t2\tE&xit"

        TCHAR msg[1024];
        // ProcessedFileInfo.Name is already UTF-8 (it comes from the interface)
        _stprintf(msg, LoadStr(PasswordIsDefined ? IDS_ERROR_PROCESSING_FILE_PWD : IDS_ERROR_PROCESSING_FILE),
                  (const char*)ProcessedFileInfo.Name);

        MSGBOXEX_PARAMS mbep;
        ZeroMemory(&mbep, sizeof(mbep));
        mbep.HParent = hProgWnd;
        mbep.Caption = LoadStr(IDS_PLUGINNAME);
        mbep.Text = msg;
        mbep.Flags = MSGBOXEX_ICONEXCLAMATION | MSGBOXEX_YESNOCANCEL;
        mbep.AliasBtnNames = btnBuffer;

        int mbRet = (int)SendMessage(hProgWnd, WM_7ZIP, WM_7ZIP_SHOWMBOXEX, (LPARAM)&mbep);

        switch (mbRet)
        {
        case DIALOG_YES:
            mode = Delete;
            break;
        case DIALOG_NO:
            mode = Keep;
            break;
            /*
      case DIALOG_YES: mode = Delete; break;
      case DIALOG_ALL: mode = Delete; DataErrorSilent = TRUE; break;
      case DIALOG_SKIP: mode = Keep; break;
      case DIALOG_SKIPALL: mode = Keep; DataErrorSilent = TRUE; break;
*/
        case DIALOG_CANCEL:
            mode = Cancel;
            break;
        }
    }

    // release OutStream so the file can be deleted if needed
    if (OutFileStream != NULL)
        OutFileStreamSpec->SetMTime(&ProcessedFileInfo.LastWrite);
    OutFileStream.Release();

    switch (mode)
    {
    case Cancel:
        SafeDeleteFile(UStringToU8(ProcessedFileInfo.FileName), DataErrorDeleteSilent);
        return FALSE;

    case Delete:
        // if cancel, bail out
        if (!SafeDeleteFile(UStringToU8(ProcessedFileInfo.FileName), DataErrorDeleteSilent))
            return FALSE;
        break;

    case Keep:
        // keep the file, so set its attributes
        if (ExtractMode && ProcessedFileInfo.AttributesAreDefined)
            SetFileAttributesU8(UStringToU8(ProcessedFileInfo.FileName), ProcessedFileInfo.Attributes);
        break;
    }

    // we will not ask again, so set the mode to the chosen operation
    if (DataErrorSilent)
        DataErrorMode = mode;

    return TRUE;
}

LRESULT CExtractCallbackImp::Error(int resID, ...)
{
    MSGBOXEX_PARAMS mbep;
    char msg[1024];
    va_list arglist;

    va_start(arglist, resID);
    _vsnprintf_s(msg, _TRUNCATE, LoadStr(resID), arglist); // feature 087: bounded (long names)
    va_end(arglist);

    ZeroMemory(&mbep, sizeof(mbep));
    mbep.HParent = hProgWnd;
    mbep.Caption = LoadStr(IDS_PLUGINNAME);
    mbep.Text = msg;
    mbep.Flags = MSGBOXEX_ICONHAND | MSGBOXEX_OK;

    return SendMessage(hProgWnd, WM_7ZIP, WM_7ZIP_SHOWMBOXEX, (LPARAM)&mbep);
}

Z7_COM7F_IMF(CExtractCallbackImp::SetOperationResult(INT32 resultEOperationResult))
{
    //  TRACE_I("CExtractCallbackImp::SetOperationResult: result = " << resultEOperationResult);

    WholeFile = TRUE;

    // feature 087: a skipped link has no data to judge (a hard link reports
    // "unsupported method") - its result is not an error of this extraction
    if (SkipCurrent)
    {
        SkipCurrent = false;
        if (TargetDir && !ItemsToExtract.size())
            return E_STOPEXTRACTION;
        return S_OK;
    }

    switch (resultEOperationResult)
    {
    case NArchive::NExtract::NOperationResult::kOK:
        // feature 093: which form opens this archive's items (EndRetryPass)
        if (CurrentRequested && PasswordIsDefined && IsEncryptedItem(CurrentIndex))
        {
            if (Pass == 1)
                Pass1EncOK++;
            else if (Pass == 2)
                Pass2OK++;
        }
        break;

    default:
        // feature 093 (contract P1). While the password has a second form, a
        // failure of the kind a wrong password gives (data / CRC error, "wrong
        // password") on an encrypted item is not a verdict yet in the FIRST pass:
        //  - an item the operation did not ask for (the engine reports every
        //    item of a block up to the last requested one, the others in skip
        //    mode): noted, settled in BeginRetryPass;
        //  - an item this callback gave no stream for (CurrentDeclined: the
        //    user's Skip, or a file that could not be created - reported and
        //    counted in GetStream): nothing of it was to be written, so nothing
        //    failed; it is never extracted again;
        //  - any other item: on the retry list, extracted again with the other
        //    form (its partial output, if any, is deleted without a question).
        // In the SECOND pass an item that had output in the first pass and now
        // fails without any (reported in test mode: the block is undecodable
        // with this form) goes to the third pass - see BeginRedoPass.
        {
            bool pwdLike = resultEOperationResult == NArchive::NExtract::NOperationResult::kDataError ||
                           resultEOperationResult == NArchive::NExtract::NOperationResult::kCRCError ||
                           resultEOperationResult == NArchive::NExtract::NOperationResult::kWrongPassword;
            bool twoForms = PasswordIsDefined && OtherPassword != NULL && !OtherPassword->IsEmpty();
            bool handled = false;
            if (Pass == 1 && twoForms && pwdLike && IsEncryptedItem(CurrentIndex))
            {
                if (!CurrentRequested)
                {
                    try
                    {
                        UnrequestedFailed.push_back(std::make_pair(CurrentIndex, (int)resultEOperationResult));
                        handled = true;
                    }
                    catch (...)
                    {
                    }
                }
                else if (CurrentDeclined)
                {
                    // its block was read with the wrong form: the failures of the
                    // block's unrequested items say nothing either (BeginRetryPass)
                    try
                    {
                        DeclinedBlocks.push_back(BlockOf(CurrentIndex));
                    }
                    catch (...)
                    {
                    }
                    handled = true;
                }
                else
                    handled = DeferCurrent();
            }
            else if (Pass == 2 && pwdLike && CurrentRequested && !CurrentDeclined && !ExtractMode && TargetDir != NULL)
            {
                std::map<UINT32, bool>::const_iterator had = RetryHadOutput.find(CurrentIndex);
                if (had != RetryHadOutput.end() && had->second)
                {
                    try
                    {
                        RedoList.push_back(CurrentIndex);
                        handled = true;
                    }
                    catch (...)
                    {
                    }
                }
            }
            if (handled)
            {
                OutFileStream.Release();
                HaveOutFile = false;
                CurrentIsDir = false;
                return S_OK;
            }
        }

        NumErrors++;

        // feature 087: the 26.03 engine says so when the password is wrong (RAR5
        // checks it after the output file was created). The file is deleted, the
        // remembered password forgotten so that the next operation asks again,
        // and the operation stops - one message, not one per file.
        if (resultEOperationResult == NArchive::NExtract::NOperationResult::kWrongPassword)
        {
            DiscardOutFile();
            Error(IDS_DATA_ERROR_PWD, (LPCTSTR)CurrentItemName);
            ForgetPassword();
            return E_ABORT;
        }

        if (ExtractMode && !HaveOutFile)
            break; // no file of this item was opened (skipped, or already reported): nothing to keep or delete

        if (ExtractMode && resultEOperationResult == NArchive::NExtract::NOperationResult::kUnsupportedMethod)
        {
            // nothing usable was written
            Error(IDS_UNSUPPORTED_METHOD);
            DiscardOutFile();
            break;
        }

        if (ExtractMode)
        {
            // feature 087: every other failed result (data or CRC error, unexpected
            // end, damaged headers, ...) leaves a damaged file: the user decides
            // whether to keep it; 0.1.8 did so for a data error only and kept the
            // file silently otherwise
            BOOL goOn = OnDataError();
            HaveOutFile = false;
            if (!goOn)
                return E_ABORT;
            // an error occurred during extraction; delete the file (handled by the function above) and finish
            if (SilentDelete)
            {
                Error(PasswordIsDefined ? IDS_DATA_ERROR_PWD : IDS_DATA_ERROR, (LPCTSTR)ProcessedFileInfo.Name);
                if (PasswordIsDefined)
                    ForgetPassword(); // Allow entering another password
                return E_ABORT;
            }
            return S_OK;
        }

        // testing
        switch (resultEOperationResult)
        {
        case NArchive::NExtract::NOperationResult::kUnsupportedMethod:
            Error(IDS_UNSUPPORTED_METHOD);
            break;

        case NArchive::NExtract::NOperationResult::kCRCError:
            Error(IDS_CRC_FAILED);
            break;

        case NArchive::NExtract::NOperationResult::kDataError:
            // feature 093: when UNPACKING, the 7z handler reports the items of a
            // block it could not decode in test mode (no output file). A wrong
            // password ends here for every item, and nothing told the user: the
            // operation produced no file and no message. Told once per
            // operation; the other blocks are still unpacked (an archive may
            // hold items under another password), the result is not OPER_OK and
            // Decompress forgets the password.
            if (TargetDir != NULL && CurrentRequested && !CurrentDeclined && !DataErrorTold)
            {
                DataErrorTold = true;
                Error(PasswordIsDefined ? IDS_DATA_ERROR_PWD : IDS_DATA_ERROR, (LPCTSTR)CurrentItemName);
            }
            break; // when testing: reported by the caller (TestArchive)

        default:
            Error(IDS_UNKNOWN_ERROR);
            break;
        }

        break;
    }

    if (OutFileStream != NULL)
        OutFileStreamSpec->SetMTime(&ProcessedFileInfo.LastWrite);
    OutFileStream.Release();

    // feature 087: only for a file this item wrote or a directory it created (the
    // name of a skipped item is the user's own existing file)
    if (ExtractMode && (HaveOutFile || CurrentIsDir) && ProcessedFileInfo.AttributesAreDefined)
        SetFileAttributesU8(UStringToU8(ProcessedFileInfo.FileName), ProcessedFileInfo.Attributes);
    HaveOutFile = false;
    CurrentIsDir = false;

    if (TargetDir && !ItemsToExtract.size())
    {
        // NULL TargetDir means testing the archive
        // A partial extraction was requested, and everything has been extracted. The archive appears to be solid.
        return E_STOPEXTRACTION;
    }

    return S_OK;
}

Z7_COM7F_IMF(CExtractCallbackImp::RequestMemoryUse(UInt32 /*flags*/, UInt32 /*indexType*/, UInt32 /*index*/,
                                                   const wchar_t* /*path*/, UInt64 requiredSize,
                                                   UInt64* allowedSize, UInt32* answerFlags))
{
    return AnswerArchiveMemoryRequest(requiredSize, allowedSize, answerFlags); // open.cpp (P5)
}

Z7_COM7F_IMF(CExtractCallbackImp::CryptoGetTextPassword(BSTR* password))
{
    if (!PasswordIsDefined /*&& !Silent*/) // Silent is for skip, which is not implemented in 7za.dll
    {
        WCHAR pwd[PASSWORD_LEN];

        pwd[0] = 0;
        switch (SendMessage(hProgWnd, WM_7ZIP, WM_7ZIP_PASSWORD, (LPARAM)pwd))
        {
        case IDOK:
            PasswordIsDefined = true;
            // feature 093: the dialog hands over the typed text as UTF-16; the
            // engine gets it unchanged
            Password = pwd;
            SecureZeroMemory(pwd, sizeof(pwd));
            // an archive made by a version up to 0.1.8 may be encrypted with the
            // form that version derived from the same text (contract P1): decided
            // here, once, by a test of one item on a second handler - before the
            // engine gets any password for this extraction
            if (FormChooser != NULL && !FormChooser->ChoosePasswordForm(Password, hProgWnd))
            {
                ForgetPassword();
                return E_ABORT;
            }
            break;

        case IDCANCEL:
            return E_ABORT;
            /*
      // prepared for skip and skip all (hopefully it will be completed in the next version)
      case DIALOG_SKIP:
        PasswordIsDefined = false;
        Silent = false;
        return S_OK;

      case DIALOG_SKIPALL:
        PasswordIsDefined = false;
        Silent = true;
        return S_FALSE;
*/
        }
    }
    return StringToBstr(Password, password); // E_OUTOFMEMORY when the BSTR cannot be allocated
}
