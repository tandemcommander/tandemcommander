// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

// menu ID definitions
#define MID_COMPAREFILES 1

#define CURRENT_CONFIG_VERSION_PRESEPARATEOPTIONS 6
#define CURRENT_CONFIG_VERSION_NORECOMPAREBUTTON 7
#define CURRENT_CONFIG_VERSION 8

// plugin interface object whose methods are invoked by Salamander
class CPluginInterface;
extern CPluginInterface PluginInterface;
extern BOOL AlwaysOnTop;

extern BOOL LoadOnStart;

// ****************************************************************************
//
// Plugin interface
//

class CPluginInterface : public CPluginInterfaceAbstract
{
public:
    virtual void WINAPI About(HWND parent);

    virtual BOOL WINAPI Release(HWND parent, BOOL force);

    virtual void WINAPI LoadConfiguration(HWND parent, HKEY regKey, CSalamanderRegistryAbstract* registry);
    virtual void WINAPI SaveConfiguration(HWND parent, HKEY regKey, CSalamanderRegistryAbstract* registry);
    virtual void WINAPI Configuration(HWND parent);

    virtual void WINAPI Connect(HWND parent, CSalamanderConnectAbstract* salamander);

    virtual void WINAPI ReleasePluginDataInterface(CPluginDataInterfaceAbstract* pluginData) { return; }

    virtual CPluginInterfaceForArchiverAbstract* WINAPI GetInterfaceForArchiver() { return NULL; };
    virtual CPluginInterfaceForViewerAbstract* WINAPI GetInterfaceForViewer() { return NULL; }
    virtual CPluginInterfaceForMenuExtAbstract* WINAPI GetInterfaceForMenuExt();
    virtual CPluginInterfaceForFSAbstract* WINAPI GetInterfaceForFS() { return NULL; }
    virtual CPluginInterfaceForThumbLoaderAbstract* WINAPI GetInterfaceForThumbLoader() { return NULL; }
    virtual void WINAPI Event(int event, DWORD param);
    virtual void WINAPI ClearHistory(HWND parent);
    virtual void WINAPI AcceptChangeOnPathNotification(const char* path, BOOL includingSubdirs) {}
    virtual void WINAPI PasswordManagerEvent(HWND parent, int event) {}
};

class CPluginInterfaceForMenu : public CPluginInterfaceForMenuExtAbstract
{
public:
    // returns the state of the menu item with the identifier 'id'; the return value is a
    // combination of flags (see MENU_ITEM_STATE_XXX); 'eventMask' corresponds to
    // CSalamanderConnectAbstract::AddMenuItem
    virtual DWORD WINAPI GetMenuItemState(int id, DWORD eventMask) { return 0; }

    // executes the menu command identified by 'id'; see
    // CSalamanderConnectAbstract::AddMenuItem for the meaning of 'eventMask'; 'salamander'
    // exposes helper methods for performing operations; 'parent' is the owner for message
    // boxes; returns TRUE if the panel selection should be cleared (Cancel was not used but
    // Skip might have been), otherwise FALSE (leave the selection as is);
    // NOTE: If the command modifies any path (disk or FS), it should call
    //       CSalamanderGeneralAbstract::PostChangeOnPathNotification to notify panels
    //       without automatic refresh and any open FS windows (both active and detached)
    virtual BOOL WINAPI ExecuteMenuItem(CSalamanderForOperationsAbstract* salamander, HWND parent,
                                        int id, DWORD eventMask);
    virtual BOOL WINAPI HelpForMenuItem(HWND parent, int id);
    virtual void WINAPI BuildMenu(HWND parent, CSalamanderBuildMenuAbstract* salamander) {}
};

// ****************************************************************************
//
// CFileCompThread
//

// feature 102: every buffer holding a file name (UTF-8, WTF-8 for a lone surrogate) has
// FC_NAME_SIZE bytes - the whole range of a Windows path (32,767 UTF-16 units, at most
// 3 bytes each); before, 260 bytes held about 86 Chinese characters.  Such buffers live on
// the heap.
#define FC_NAME_SIZE SAL_MAX_PATH_UTF8

class CFilecompThread : public CThread
{
public:
    // feature 102: FC_NAME_SIZE heap buffers (NULL on low memory, Body() reports it); the
    // comparator window of this thread works in them (CMainWindow::Path1/Path2)
    char* Path1;
    char* Path2;
    BOOL DontConfirmSelection;
    char ReleaseEvent[20];

    CFilecompThread(const char* file1, const char* file2, BOOL dontConfirmSelection,
                    const char* releaseEvent) : CThread("Filecomp Thread")
    {
        Path1 = (char*)malloc(FC_NAME_SIZE);
        Path2 = (char*)malloc(FC_NAME_SIZE);
        if (Path1 != NULL)
            lstrcpynA(Path1, file1, FC_NAME_SIZE);
        if (Path2 != NULL)
            lstrcpynA(Path2, file2, FC_NAME_SIZE);
        DontConfirmSelection = dontConfirmSelection;
        lstrcpynA(ReleaseEvent, releaseEvent, _countof(ReleaseEvent));
    }
    virtual ~CFilecompThread()
    {
        free(Path1);
        free(Path2);
    }

    virtual unsigned Body();
};

// feature 102: texts that embed file names are composed in UTF-8 from UTF-8 templates.
// The plug-in's LoadStr returns the code-page form of a string, so a template with accented
// letters (cs, de, fr, hu, sk) plus a UTF-8 name made an invalid mix that was shown garbled.

// the UTF-8 form of the plug-in's string 'resID' (from SG->LoadStrW, cached for the life of
// the plug-in, thread safe); never NULL
const char* LoadStrU8(int resID);
// frees the LoadStrU8 cache (plug-in unload)
void ReleaseLoadStrU8();
// vsprintf/sprintf into a malloc'ed buffer of the exact size; NULL on low memory
char* VSprintfAlloc(const char* format, va_list args);
char* SprintfAlloc(const char* format, ...);
// returns 'text' (malloc'ed, UTF-8) with the system's text for 'error' (UTF-8, from
// FormatMessageW) appended; 'text' is freed or reused; NULL on low memory
char* AppendSystemErrorU8(char* text, DWORD error);
// copies at most dstSize - 1 bytes of the UTF-8 'src' to 'dst', never ending in the middle
// of a character; returns FALSE when 'src' had to be shortened
BOOL CopyU8Truncated(char* dst, size_t dstSize, const char* src);
// a label that may be code-page text (a conversion table name from convert.cfg) as UTF-8
void LabelToU8(const char* label, char* buf, int bufSize);
// the Error() of lukas for a template with one %s that receives a UTF-8 file name
BOOL ErrorU8(HWND parent, int resID, const char* name, DWORD lastError = ERROR_SUCCESS);
// sets the window title from UTF-8 text (also on this plug-in's code-page windows)
void SetWindowTitleU8(HWND hWnd, const char* text);

extern CWindowQueue MainWindowQueue; // list of all FileComp windows
extern CThreadQueue ThreadQueue;     // list of all FileComp windows, workers, and the remote control
