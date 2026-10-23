// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#define SizeOf(x) (sizeof(x) / sizeof(x[0]))

// Salamander's general interface - valid from startup until the plugin shuts down
extern CSalamanderGeneralAbstract* SalamanderGeneral;

// interface providing customized Windows controls used in Salamander
extern CSalamanderGUIAbstract* SalamanderGUI;

// ZLIB compression/decompression interface
extern CSalamanderZLIBAbstract* SalZLIB;

// BZIP2 compression/decompression interface
extern CSalamanderBZIP2Abstract* SalBZIP2;

// interface for comfortable work with files
extern CSalamanderSafeFileAbstract* SalamanderSafeFile;

// current value of Salamander's configuration variable SALCFG_SORTBYEXTDIRSASFILES
extern int SortByExtDirsAsFiles;

class CISOImage;

// ****************************************************************************
//
// CPluginInterface
//

class CPluginInterfaceForViewer : public CPluginInterfaceForViewerAbstract
{
public:
    virtual BOOL WINAPI ViewFile(const char* name, int left, int top, int width, int height,
                                 UINT showCmd, BOOL alwaysOnTop, BOOL returnLock, HANDLE* lock,
                                 BOOL* lockOwner, CSalamanderPluginViewerData* viewerData,
                                 int enumFilesSourceUID, int enumFilesCurrentIndex);
    virtual BOOL WINAPI CanViewFile(const char* name);
};

class CPluginInterfaceForArchiver : public CPluginInterfaceForArchiverAbstract
{
protected:
public:
    CPluginInterfaceForArchiver();

    virtual BOOL WINAPI ListArchive(CSalamanderForOperationsAbstract* salamander, const char* fileName,
                                    CSalamanderDirectoryAbstract* dir,
                                    CPluginDataInterfaceAbstract*& pluginData);
    virtual BOOL WINAPI UnpackArchive(CSalamanderForOperationsAbstract* salamander, const char* fileName,
                                      CPluginDataInterfaceAbstract* pluginData, const char* targetDir,
                                      const char* archiveRoot, SalEnumSelection next, void* nextParam);
    virtual BOOL WINAPI UnpackOneFile(CSalamanderForOperationsAbstract* salamander, const char* fileName,
                                      CPluginDataInterfaceAbstract* pluginData, const char* nameInArchive,
                                      const CFileData* fileData, const char* targetDir,
                                      const char* newFileName, BOOL* renamingNotSupported);
    virtual BOOL WINAPI PackToArchive(CSalamanderForOperationsAbstract* salamander, const char* fileName,
                                      const char* archiveRoot, BOOL move, const char* sourcePath,
                                      SalEnumSelection2 next, void* nextParam) { return FALSE; }
    virtual BOOL WINAPI DeleteFromArchive(CSalamanderForOperationsAbstract* salamander, const char* fileName,
                                          CPluginDataInterfaceAbstract* pluginData, const char* archiveRoot,
                                          SalEnumSelection next, void* nextParam) { return FALSE; }
    virtual BOOL WINAPI UnpackWholeArchive(CSalamanderForOperationsAbstract* salamander, const char* fileName,
                                           const char* mask, const char* targetDir, BOOL delArchiveWhenDone,
                                           CDynamicString* archiveVolumes);
    virtual BOOL WINAPI CanCloseArchive(CSalamanderForOperationsAbstract* salamander, const char* fileName,
                                        BOOL force, int panel);
    virtual BOOL WINAPI GetCacheInfo(char* tempPath, BOOL* ownDelete, BOOL* cacheCopies) { return FALSE; }
    virtual void WINAPI DeleteTmpCopy(const char* fileName, BOOL firstFile) {}
    virtual BOOL WINAPI PrematureDeleteTmpCopy(HWND parent, int copiesCount) { return FALSE; }

    // plugin's own methods
public:
    BOOL Init();
};

class CPluginInterface : public CPluginInterfaceAbstract
{
public:
    virtual void WINAPI About(HWND parent);

    virtual BOOL WINAPI Release(HWND parent, BOOL force);

    virtual void WINAPI LoadConfiguration(HWND parent, HKEY regKey, CSalamanderRegistryAbstract* registry);
    virtual void WINAPI SaveConfiguration(HWND parent, HKEY regKey, CSalamanderRegistryAbstract* registry);
    virtual void WINAPI Configuration(HWND parent);

    virtual void WINAPI Connect(HWND parent, CSalamanderConnectAbstract* salamander);

    virtual void WINAPI ReleasePluginDataInterface(CPluginDataInterfaceAbstract* pluginData);

    virtual CPluginInterfaceForArchiverAbstract* WINAPI GetInterfaceForArchiver();
    virtual CPluginInterfaceForViewerAbstract* WINAPI GetInterfaceForViewer();
    virtual CPluginInterfaceForMenuExtAbstract* WINAPI GetInterfaceForMenuExt() { return NULL; }
    virtual CPluginInterfaceForFSAbstract* WINAPI GetInterfaceForFS() { return NULL; }
    virtual CPluginInterfaceForThumbLoaderAbstract* WINAPI GetInterfaceForThumbLoader() { return NULL; }

    virtual void WINAPI Event(int event, DWORD param);
    virtual void WINAPI ClearHistory(HWND parent) {}
    virtual void WINAPI AcceptChangeOnPathNotification(const char* path, BOOL includingSubdirs) {}

    virtual void WINAPI PasswordManagerEvent(HWND parent, int event) {}
};

class CPluginDataInterface : public CPluginDataInterfaceAbstract
{
public:
    CPluginDataInterface();
    ~CPluginDataInterface();

    virtual BOOL WINAPI CallReleaseForFiles() { return TRUE; }
    virtual BOOL WINAPI CallReleaseForDirs() { return TRUE; }
    virtual void WINAPI ReleasePluginData(CFileData& file, BOOL isDir);

    virtual void WINAPI GetFileDataForUpDir(const char* archivePath, CFileData& upDir) {}
    virtual BOOL WINAPI GetFileDataForNewDir(const char* dirName, CFileData& dir) { return TRUE; }

    virtual HIMAGELIST WINAPI GetSimplePluginIcons(int iconSize) { return NULL; }
    virtual BOOL WINAPI HasSimplePluginIcon(CFileData& file, BOOL isDir) { return FALSE; }
    virtual HICON WINAPI GetPluginIcon(const CFileData* file, int iconSize, BOOL& destroyIcon) { return NULL; }
    virtual int WINAPI CompareFilesFromFS(const CFileData* file1, const CFileData* file2) { return 0; }

    virtual void WINAPI SetupView(BOOL leftPanel, CSalamanderViewAbstract* view, const char* archivePath,
                                  const CFileData* upperDir) {}
    virtual void WINAPI ColumnFixedWidthShouldChange(BOOL leftPanel, const CColumn* column, int newFixedWidth) {}
    virtual void WINAPI ColumnWidthWasChanged(BOOL leftPanel, const CColumn* column, int newWidth) {}
    virtual BOOL WINAPI GetInfoLineContent(int panel, const CFileData* file, BOOL isDir, int selectedFiles,
                                           int selectedDirs, BOOL displaySize, const CQuadWord& selectedSize,
                                           char* buffer, DWORD* hotTexts, int& hotTextsCount) { return FALSE; }

    virtual BOOL WINAPI CanBeCopiedToClipboard() { return TRUE; }

    virtual BOOL WINAPI GetByteSize(const CFileData* file, BOOL isDir, CQuadWord* size) { return FALSE; }
    virtual BOOL WINAPI GetLastWriteDate(const CFileData* file, BOOL isDir, SYSTEMTIME* date) { return FALSE; }
    virtual BOOL WINAPI GetLastWriteTime(const CFileData* file, BOOL isDir, SYSTEMTIME* time) { return FALSE; }

    BOOL DisplayMissingCCDWarning;
    // feature 328: the listing behind this data left entries out (UnpackWholeArchive then fails)
    BOOL ListingLeftOut;
};

extern HINSTANCE DLLInstance; // handle to the SPL - language-independent resources
extern HINSTANCE HLanguage;   // handle to the SLG - language-dependent resources

//extern DWORD Options;// configuration
struct COptions
{
    BOOL ClearReadOnly;      // Clear read-only attribute when copying from archive
    BOOL SessionAsDirectory; // Show session as directory (allow access to all sessions)
    BOOL BootImageAsFile;    // Show boot image disk as file
};

extern COptions Options; // configuration

char* LoadStr(int resID);
const char* LoadStrU8(int resID); // UTF-8, valid until the plug-in unloads (feature 130)
void GetInfo(char* buffer, FILETIME* lastWrite, unsigned size);
BOOL Error(int resID, BOOL quiet = FALSE, ...);
BOOL Error(const char* msg, DWORD err, BOOL quiet = FALSE);
BOOL SysError(int title, int error, ...);

BOOL Warning(int resID, BOOL quiet, ...);

// buffer able to hold any long path in UTF-8 (interface 104: 3 bytes per
// UTF-16 unit, see splunicode.h); always allocate these on the heap
#define U8_MAX_PATH (3 * 32767 + 1)

// a single name component is at most 255 UTF-16 units -> up to 765 UTF-8 bytes
#define U8_MAX_NAME (3 * 256 + 1)

// interface 104: paths crossing the plugin interface are UTF-8, so file APIs must
// be called through their W variants with the \\?\ prefix (see splunicode.h)
HANDLE CreateFileU8(const char* name, DWORD access, DWORD share, DWORD disposition, DWORD flags);
BOOL DeleteFileU8(const char* name);
BOOL SetFileAttributesU8(const char* name, DWORD attrs);

// heap buffer for a full UTF-8 path built from interface strings - a target path is no
// longer bounded by MAX_PATH (interface 104) and U8_MAX_PATH is far too big for the
// stack. RAII, so it is also released by the throw/catch the UnpackFile()
// implementations use. Converts to char*, so it drops into the old 'char name[]' spots.
class CU8PathBuf
{
public:
    char* Buf;

    CU8PathBuf()
    {
        Buf = (char*)malloc(U8_MAX_PATH);
        if (Buf != NULL)
            *Buf = 0;
    }
    ~CU8PathBuf() { free(Buf); }
    operator char*() const { return Buf; }
    BOOL IsOk() const { return Buf != NULL; }

private:
    CU8PathBuf(const CU8PathBuf&);
    CU8PathBuf& operator=(const CU8PathBuf&);
};

// format boundary (interface 104): the plain ISO9660 / XDVDFS name fields hold plain
// bytes with no encoding tag. Bytes that already are valid UTF-8 are kept verbatim,
// anything else is decoded from the system ANSI code page. Converts 'name' in place
// when it fits into 'bufSize'; the Joliet/UDF/HFS+ paths do not need this - their
// names come from real Unicode fields and are converted directly (SplWToU8).
void EnsureU8Name(char* name, int bufSize);

// feature 327: a name read from the image (an ISO 9660 / Joliet / UDF / HFS+ / Xbox entry, a volume
// label folder) made safe for Windows in place, before it is listed - feature 087's rule for one
// name (SalArcCleanItemName, salarcname.h): no '\' '/' ':' and the like, no trailing dot, no device
// name; never cut, never dropped. 'name' is UTF-8 (after EnsureU8Name), terminated in 'bufSize'.
void MakeSafeName(char* name, int bufSize);

// feature 327: 'target' (a folder, UTF-8, in a buffer of 'targetSize') + '\' + the listed 'name' made
// safe once more (names are cleaned at listing and again at extraction, feature 087); FALSE when the
// result does not fit (or no memory) - the caller reports the name as too long
BOOL AppendSafeName(char* target, const char* name, int targetSize);

// Helpers
#define LOWDWORD(x) (DWORD)(x)
#define HIDWORD(x) (DWORD)((x) >> 32)

#define DUMP_MEM_OBJECTS

#if defined(DUMP_MEM_OBJECTS) && defined(_DEBUG)
#define CRT_MEM_CHECKPOINT \
    _CrtMemState ___CrtMemState; \
    _CrtMemCheckpoint(&___CrtMemState);
#define CRT_MEM_DUMP_ALL_OBJECTS_SINCE _CrtMemDumpAllObjectsSince(&___CrtMemState);

#else //DUMP_MEM_OBJECTS
#define CRT_MEM_CHECKPOINT ;
#define CRT_MEM_DUMP_ALL_OBJECTS_SINCE ;

#endif //DUMP_MEM_OBJECTS
