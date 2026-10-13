// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include "session.h"

// ****************************************************************************
// CPluginInterfaceForFS - FS factory + Change-Drive / Enter handling.
// ****************************************************************************

class CPluginFSInterface;

class CPluginInterfaceForFS : public CPluginInterfaceForFSAbstract
{
protected:
    int ActiveFSCount;

public:
    CPluginInterfaceForFS() { ActiveFSCount = 0; }
    int GetActiveFSCount() { return ActiveFSCount; }

    virtual CPluginFSInterfaceAbstract* WINAPI OpenFS(const char* fsName, int fsNameIndex);
    virtual void WINAPI CloseFS(CPluginFSInterfaceAbstract* fs);

    virtual void WINAPI ExecuteChangeDriveMenuItem(int panel);
    virtual BOOL WINAPI ChangeDriveMenuItemContextMenu(HWND parent, int panel, int x, int y,
                                                       CPluginFSInterfaceAbstract* pluginFS,
                                                       const char* pluginFSName, int pluginFSNameIndex,
                                                       BOOL isDetachedFS, BOOL& refreshMenu,
                                                       BOOL& closeMenu, int& postCmd, void*& postCmdParam);
    virtual void WINAPI ExecuteChangeDrivePostCommand(int panel, int postCmd, void* postCmdParam);
    virtual void WINAPI ExecuteOnFS(int panel, CPluginFSInterfaceAbstract* pluginFS,
                                    const char* pluginFSName, int pluginFSNameIndex,
                                    CFileData& file, int isDir);
    virtual BOOL WINAPI DisconnectFS(HWND parent, BOOL isInPanel, int panel,
                                     CPluginFSInterfaceAbstract* pluginFS,
                                     const char* pluginFSName, int pluginFSNameIndex);
    virtual void WINAPI ConvertPathToInternal(const char* fsName, int fsNameIndex, char* fsUserPart);
    virtual void WINAPI ConvertPathToExternal(const char* fsName, int fsNameIndex, char* fsUserPart);
    virtual void WINAPI EnsureShareExistsOnServer(int panel, const char* server, const char* share) {}
};

// ****************************************************************************
// CPluginFSInterface - one live SFTP connection bound to a panel.
// The FS user-part has the form "user@host:port/remote/path".
// ****************************************************************************

class CPluginFSInterface : public CPluginFSInterfaceAbstract
{
protected:
    char Host[256];
    int Port;
    char User[256];
    char Path[3072];               // current remote absolute path (POSIX, UTF-8)
    char LastFailedListPath[3072]; // last path ListCurrentPath could not list
                                   // (loop-breaker: ChangePath shortens it)

    CSFTPSession Session;
    CSFTPConnectParams Params;
    BOOL HasParams;    // Params filled from a bookmark/quick-connect
    BOOL FatalError;   // last connect attempt failed (no usable session)
    BOOL WasConnected; // feature 051 (U7): a session existed and was lost -> reconnect
    int LogUID;

public:
    CPluginFSInterface();
    virtual ~CPluginFSInterface();

    // sets the connection parameters (decrypted secrets) before the first
    // ChangePath; used by the connect flow
    void SetConnectParams(const CSFTPConnectParams* params);

    // builds "user@host:port/path" into 'buf'; feature 131: returns FALSE and leaves
    // 'buf' empty when it does not fit - a path is never cut, the caller refuses
    BOOL MakeUserPart(const char* path, char* buf, int bufSize);
    // like GetCurrentPath but honors the real buffer size; internal navigation
    // must not truncate a long remote path to MAX_PATH (CF-7)
    BOOL GetCurrentPathFull(char* buf, int bufSize);
    // parses a user-part into host/port/user/path; returns FALSE on syntax error
    // (feature 131: also when the path does not fit 'pathSize' - it was cut)
    static BOOL ParseUserPart(const char* userPart, char* host, int* port, char* user,
                              char* path, int pathSize);

    BOOL EnsureConnected(HWND parent);
    // feature 140: ChangePath found the session lost - connects again, once per call
    BOOL ReconnectLostInChangePath(BOOL* reconnected);

    virtual BOOL WINAPI GetCurrentPath(char* userPart);
    virtual BOOL WINAPI GetFullName(CFileData& file, int isDir, char* buf, int bufSize);
    virtual BOOL WINAPI GetFullFSPath(HWND parent, const char* fsName, char* path, int pathSize, BOOL& success);
    virtual BOOL WINAPI GetRootPath(char* userPart);
    virtual BOOL WINAPI IsCurrentPath(int currentFSNameIndex, int fsNameIndex, const char* userPart);
    virtual BOOL WINAPI IsOurPath(int currentFSNameIndex, int fsNameIndex, const char* userPart);
    virtual BOOL WINAPI ChangePath(int currentFSNameIndex, char* fsName, int fsNameIndex,
                                   const char* userPart, char* cutFileName, BOOL* pathWasCut,
                                   BOOL forceRefresh, int mode);
    virtual BOOL WINAPI ListCurrentPath(CSalamanderDirectoryAbstract* dir,
                                        CPluginDataInterfaceAbstract*& pluginData,
                                        int& iconsType, BOOL forceRefresh);
    virtual BOOL WINAPI TryCloseOrDetach(BOOL forceClose, BOOL canDetach, BOOL& detach, int reason);
    virtual void WINAPI Event(int event, DWORD param);
    virtual void WINAPI ReleaseObject(HWND parent);
    virtual DWORD WINAPI GetSupportedServices();
    virtual BOOL WINAPI GetChangeDriveOrDisconnectItem(const char* fsName, char*& title, HICON& icon, BOOL& destroyIcon);
    virtual HICON WINAPI GetFSIcon(BOOL& destroyIcon);
    virtual void WINAPI GetDropEffect(const char* srcFSPath, const char* tgtFSPath,
                                      DWORD allowedEffects, DWORD keyState, DWORD* dropEffect);
    virtual void WINAPI GetFSFreeSpace(CQuadWord* retValue);
    virtual BOOL WINAPI GetNextDirectoryLineHotPath(const char* text, int pathLen, int& offset);
    virtual void WINAPI CompleteDirectoryLineHotPath(char* path, int pathBufSize);
    virtual BOOL WINAPI GetPathForMainWindowTitle(const char* fsName, int mode, char* buf, int bufSize);
    virtual void WINAPI ShowInfoDialog(const char* fsName, HWND parent);
    virtual BOOL WINAPI ExecuteCommandLine(HWND parent, char* command, int& selFrom, int& selTo);
    virtual BOOL WINAPI QuickRename(const char* fsName, int mode, HWND parent, CFileData& file,
                                    BOOL isDir, char* newName, BOOL& cancel);
    virtual void WINAPI AcceptChangeOnPathNotification(const char* fsName, const char* path, BOOL includingSubdirs);
    virtual BOOL WINAPI CreateDir(const char* fsName, int mode, HWND parent, char* newName, BOOL& cancel);
    virtual void WINAPI ViewFile(const char* fsName, HWND parent,
                                 CSalamanderForViewFileOnFSAbstract* salamander, CFileData& file);
    virtual BOOL WINAPI Delete(const char* fsName, int mode, HWND parent, int panel,
                               int selectedFiles, int selectedDirs, BOOL& cancelOrError);
    virtual BOOL WINAPI CopyOrMoveFromFS(BOOL copy, int mode, const char* fsName, HWND parent,
                                         int panel, int selectedFiles, int selectedDirs,
                                         char* targetPath, BOOL& operationMask,
                                         BOOL& cancelOrHandlePath, HWND dropTarget);
    virtual BOOL WINAPI CopyOrMoveFromDiskToFS(BOOL copy, int mode, const char* fsName, HWND parent,
                                               const char* sourcePath, SalEnumSelection2 next,
                                               void* nextParam, int sourceFiles, int sourceDirs,
                                               char* targetPath, BOOL* invalidPathOrCancel);
    virtual BOOL WINAPI ChangeAttributes(const char* fsName, HWND parent, int panel,
                                         int selectedFiles, int selectedDirs);
    virtual void WINAPI ShowProperties(const char* fsName, HWND parent, int panel, int selectedFiles, int selectedDirs) {}
    virtual void WINAPI ContextMenu(const char* fsName, HWND parent, int menuX, int menuY, int type,
                                    int panel, int selectedFiles, int selectedDirs);
    virtual BOOL WINAPI HandleMenuMsg(UINT uMsg, WPARAM wParam, LPARAM lParam, LRESULT* plResult) { return FALSE; }
    virtual BOOL WINAPI OpenFindDialog(const char* fsName, int panel) { return FALSE; }
    virtual void WINAPI OpenActiveFolder(const char* fsName, HWND parent) {}
    virtual void WINAPI GetAllowedDropEffects(int mode, const char* tgtFSPath, DWORD* allowedEffects);
    virtual BOOL WINAPI GetNoItemsInPanelText(char* textBuf, int textBufSize) { return FALSE; }
    virtual void WINAPI ShowSecurityInfo(HWND parent) {}
};

extern CPluginInterfaceForFS InterfaceForFS;

// launches the Connect dialog and opens the chosen server in 'panel'
void ConnectSFTPServer(HWND parent, int panel);

// performs a path change queued by ExecuteCommandLine (runs from ExecuteMenuItem,
// outside any FS-interface method, where ChangePanelPathToPluginFS is legal)
void ExecuteDeferredCd();
