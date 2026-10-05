// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

class CCRCMD5Thread;
class CCalculateThread;
class CVerifyThread;

#define WM_USER_STARTWORK WM_APP + 555 // start work when dialog is visible (instead of in WM_INITDIALOG)
#define WM_USER_ENDWORK WM_APP + 556   // end work when worker thread ends

class FILELISTITEM
{
public:
    FILELISTITEM()
    {
        IconIndex = 0;
        Name = NULL;
        Size = CQuadWord(0, 0);
        FileExist = FALSE;
        for (int i = 0; i < HT_COUNT; i++)
            Hashes[i] = NULL;
    }

    ~FILELISTITEM()
    {
        if (Name != NULL)
            free(Name);
        for (int i = 0; i < HT_COUNT; i++)
        {
            if (Hashes[i] != NULL)
                free(Hashes[i]);
        }
    }

public:
    int IconIndex;  // no synchronization needed, see CSFVMD5Dialog::SetItemTextAndIcon()
    char* Name;     // unchanged after adding to the array = no synchronized access needed
    CQuadWord Size; // unchanged after adding to the array = no synchronized access needed
    BOOL FileExist; // unchanged after adding to the array = no synchronized access needed

    // the order in this array matches the listview columns (depends on configuration)
    // no synchronization needed, see CSFVMD5Dialog::SetItemTextAndIcon()
    char* Hashes[HT_COUNT];
};

// feature 118 (interface 107): the number of windows that hold work an installer's unattended
// close must not lose (a Calculate window with a hash type not saved); CPluginInterface::Release()
// refuses while it is not zero. Changed with Interlocked* by the dialog threads.
extern volatile LONG WindowsHoldingWork;

class CSFVMD5Dialog : public CDialog
{
public:
    CSFVMD5Dialog(int id, HWND parent, BOOL alwaysOnTop);
    ~CSFVMD5Dialog();

protected:
    void InitList(int columns[], int widths[], int numcols, SHashInfo* pHashInfo = NULL);
    void InitLayout(int id[], int n, int m);
    void RecalcLayout(int cx, int cy, int id[], int n, int m);
    void SaveSizes(int sizes[], int numcols, SHashInfo* pHashInfo = NULL);
    virtual INT_PTR DialogProc(UINT uMsg, WPARAM wParam, LPARAM lParam);
    void ConvertPath(char* str, char from, char to);
    virtual void OnThreadEnd();
    void SetItemTextAndIcon(int row, int col, const char* text = NULL, int icon = -1);
    void GetItemText(int row, int col, char* text, int textMax);
    void IncreaseProgress(const CQuadWord& delta);
    virtual void DeleteItem(int index);
    void ScrollToItem(int i);
    void AddFileListItem(const char* name, CQuadWord size, BOOL fileExist);
    void SetRowsDirty(int firstRow, int lastRow);

    void EnterDataCS() { HANDLES(EnterCriticalSection(&DataCS)); }
    void LeaveDataCS() { HANDLES(LeaveCriticalSection(&DataCS)); }

    // feature 118 (interface 107): TRUE while the window holds something an installer's unattended
    // close must not lose; a Verify window never does (it only reads the files and the list)
    virtual BOOL HoldsWork() { return FALSE; }
    // declares the window to the core (SetWindowClosesUnattended) when it holds nothing, withdraws
    // the declaration when it does, and keeps WindowsHoldingWork in step; call it on the dialog's
    // thread whenever HoldsWork() may have changed
    void UpdateClosesUnattended();
    BOOL CountedAsWork; // counted in WindowsHoldingWork

    HWND hParent;
    HWND hList;
    HIMAGELIST hImg;
    int listX, listY;
    int ctrlX[7], ctrlY[7];
    int minX, minY;

    CRITICAL_SECTION DataCS;  // critical section guarding data shared by the dialog and worker thread
    int ScheduledScrollIndex; // synchronized via DataCS
    int ScrollIndex;
    int DirtyRowMin;
    int DirtyRowMax;
    CQuadWord totalSize;
    CQuadWord CurrentSize;
    CQuadWord ScheduledCurrentSize; // synchronized via DataCS
    BOOL bScrollToItem;
    BOOL bAlwaysOnTop;
    HANDLE hThread;  // handle can be used only in the thread queue (closed automatically when the thread ends)
    DWORD iThreadID; // thread ID of 'hThread'
    BOOL bThreadRunning;
    BOOL bTerminateThread;
    BOOL ReadingDirectories; // directory enumeration is in progress
    BOOL StopReadingDirectories;
    BOOL bDisableNotification;
    TIndirectArray<FILELISTITEM> FileList;

    friend class CCalculateThread;
    friend class CVerifyThread;
    friend class CSFVMD5ListView;
};

class CSFVMD5ListView : public CWindow
{
public:
    CSFVMD5ListView(CSFVMD5Dialog* parent) : CWindow(ooAllocated) { Parent = parent; }

protected:
    virtual LRESULT WindowProc(UINT uMsg, WPARAM wParam, LPARAM lParam)
    {
        if (uMsg == WM_VSCROLL)
            Parent->bScrollToItem = FALSE; // user is scrolling manually -> disable autoscroll
        return CWindow::WindowProc(uMsg, wParam, lParam);
    }

    CSFVMD5Dialog* Parent;
};

class CCRCMD5Thread : public CThread
{
public:
    CCRCMD5Thread(BOOL* terminate) : CThread("Hash Worker Thread")
    {
        Terminate = terminate;
    };
    virtual unsigned Body() = 0;
    BOOL* Terminate; // the BOOL itself lives in the dialog so it can be toggled from there (thread object auto-deallocates)
};

typedef struct _SEEDFILEINFO
{
    CQuadWord Size;
    bool bDir;
    DWORD Attr;
    char Name[1];
} SEEDFILEINFO;

typedef TIndirectArray<SEEDFILEINFO> TSeedFileList;

class CCalculateDialog : public CSFVMD5Dialog
{
public:
    CCalculateDialog(HWND parent, BOOL alwaysOnTop, TSeedFileList* pFileList, const char* sourcePath);

protected:
    BOOL AddDir(char (&path)[3 * MAX_PATH], size_t root, BOOL* ignoreAll);
    BOOL GetFileList();
    virtual void OnThreadEnd();
    void EnableButtons(BOOL bEnable);
    virtual void DeleteItem(int index);
    BOOL GetSaveFileName(char* buffer, int bufferSize, const char* title = NULL);
    void SaveHashes();
    virtual INT_PTR DialogProc(UINT uMsg, WPARAM wParam, LPARAM lParam);
    void OnContextMenu(int x, int y, eHASH_TYPE forceCopyHash = HT_COUNT);
    void RefreshUI();
    // feature 118: the list is being made, or it holds hashes that were not saved
    virtual BOOL HoldsWork();
    // feature 118: bits (1 << eHASH_TYPE) of the hash types this window calculates
    DWORD CalculatedTypes();
    // feature 118: forgets the saved types whose list file is the file 'f' was opened on (it has
    // just been truncated) - all of them when the file cannot be identified
    void ForgetSavesOfFile(FILE* f);

    BOOL WorkEnded; // feature 118: reading the folders and calculating has ended (OnThreadEnd)
    // feature 118: bits (1 << eHASH_TYPE) of the hash types whose column was saved completely and
    // not changed since, with the identity of the file each went to (a later save truncating
    // that file forgets it)
    DWORD SavedTypes;
    struct CSavedFileId
    {
        DWORD Volume, IndexHigh, IndexLow;
    } SavedFile[HT_COUNT];
    TSeedFileList* pSeedFileList;
    const char* SourcePath;
    SHashInfo HashInfo[HT_COUNT];
    DWORD RefreshCounter;

    friend class CCalculateThread;
};

#define DIGEST_MAX_SIZE 64
#define HASH_MAX_SIZE (2 * DIGEST_MAX_SIZE + 1)

struct FILEINFO
{
    // nothing in this structure changes after it is added to the array = no synchronized access needed
    char fileName[3 * MAX_PATH]; // UTF-8 (up to 3 bytes per character)
    char digest[DIGEST_MAX_SIZE];
    CQuadWord size;
    BOOL bFileExist;
};

class CVerifyDialog : public CSFVMD5Dialog
{
public:
    CVerifyDialog(HWND parent, BOOL alwaysOnTop, char* path, char* file);

protected:
    void LTrimStr(char* str);
    //char* GetLine(FILE* f, char* buffer, int max);
    char* LoadFile(char* name);
    BOOL AnalyzeSourceFile();
    BOOL LoadSourceFile();
    virtual void OnThreadEnd();
    virtual INT_PTR DialogProc(UINT uMsg, WPARAM wParam, LPARAM lParam);

    TIndirectArray<FILEINFO> fileList;
    char* sourcePath;
    char* sourceFile;
    SHashInfo* pHashInfo;
    BOOL bCanceled;
    int nCorrupt, nMissing, nSkipped;

    friend class CVerifyThread;
};

BOOL OpenCalculateDialog(HWND parent);
BOOL OpenVerifyDialog(HWND parent);

extern CWindowQueue ModelessQueue; // list of all modeless windows
extern CThreadQueue ThreadQueue;   // list of all dialog and worker threads

//****************************************************************************
//
// CCommonDialog
//
// Dialog centered to parent
//

class CCommonDialog : public CDialog
{
public:
    CCommonDialog(HINSTANCE hInstance, int resID, HWND hParent, CObjectOrigin origin = ooStandard);
    CCommonDialog(HINSTANCE hInstance, int resID, int helpID, HWND hParent, CObjectOrigin origin = ooStandard);

protected:
    INT_PTR DialogProc(UINT uMsg, WPARAM wParam, LPARAM lParam);
};

//****************************************************************************
//
// CConfigurationDialog
//

class CConfigurationDialog : public CCommonDialog
{
private:
public:
    CConfigurationDialog(HWND hParent);

    virtual void Transfer(CTransferInfo& ti);

    /*  protected:
    INT_PTR DialogProc(UINT uMsg, WPARAM wParam, LPARAM lParam);*/
};
