// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later
// CommentsTranslationProject: TRANSLATED

#include "precomp.h"

#include "cfgdlg.h"
#include "mainwnd.h"
#include "zip.h"
#include "usermenu.h"
#include "execute.h"
#include "plugins.h"
#include "pack.h"
#include "fileswnd.h"

//
// ****************************************************************************
// Types
// ****************************************************************************
//

// Data structure for the parsing function
struct SPackExpData
{
    const char* ArcName;
    const char* SrcDir;
    const char* TgtDir;
    const char* LstName;
    const char* ExtName;
    char Buffer[MAX_PATH];
    // following variables exist because we cannot obtain the DOS name of a non-existent file
    // we handle it by returning a substitute DOS name which will later (after creating the archive) be renamed to the desired long name
    // once the archive is created
    BOOL ArcNameFilePossible; // TRUE until the substitute DOS name is used (we must use one name everywhere)
    BOOL DOSTmpFilePossible;  // TRUE while ArcName can be replaced with the substitute DOS name
    char* DOSTmpFile;         // substitute name for ArcName (non-NULL only if DOSTmpFilePossible is TRUE)
};

class CExecuteWindow : public CWindow
{
protected:
    char* Text;
    HWND HParent;
    HWND HCancel;       // the Cancel button (feature 084)
    int TextAreaHeight; // height of the part with the text; the button is below it

public:
    BOOL Cancelled; // set by the Cancel button (feature 084)

    CExecuteWindow(HWND hParent, int textResID, CObjectOrigin origin = ooAllocated);
    ~CExecuteWindow();

    HWND Create();

protected:
    virtual LRESULT WindowProc(UINT uMsg, WPARAM wParam, LPARAM lParam);
};

//
// ****************************************************************************
// Constants and global variables
// ****************************************************************************
//

// Timeout for opening the packer console in milliseconds
// (if less than one, it is not opened at all)
LONG PackWinTimeout = 15000;

// configuration item names in the registry
//
// predefined packers associations
const char* SALAMANDER_PPA_EXTENSIONS = "Extension List";
const char* SALAMANDER_PPA_PINDEX = "Packer Index";
const char* SALAMANDER_PPA_UINDEX = "Unpacker Index";
const char* SALAMANDER_PPA_USEPACKER = "Packer Supported";
// predefined packers configuration
const char* SALAMANDER_PPC_TITLE = "Packer Title";
const char* SALAMANDER_PPC_PACKEXE = "Packer Executable";
const char* SALAMANDER_PPC_EXESAME = "Use Packer Executable To Unpack";
const char* SALAMANDER_PPC_UID = "Packer UID";
const char* SALAMANDER_PPC_UNPACKEXE = "Unpacker Executable";

// main packer configuration
CPackerFormatConfig PackerFormatConfig /*(FALSE)*/;
CArchiverConfig ArchiverConfig /*(FALSE)*/;

//
// Return code tables for individual supported packers
// error code 0 always means success
//

// RAR (WinRAR console; codes 9-12 exist since RAR 3.x, 255 = user break -
// feature 084)
const TPackErrorTable RARErrors =
    {
        {1, IDS_PACKRET_WARNING},
        {2, IDS_PACKRET_FATAL},
        {3, IDS_PACKRET_CRC},
        {4, IDS_PACKRET_SECURITY},
        {5, IDS_PACKRET_DISK},
        {6, IDS_PACKRET_FOPEN},
        {7, IDS_PACKRET_PARAMS},
        {8, IDS_PACKRET_MEMORY},
        {9, IDS_PACKRET_CREATE},
        {10, IDS_PACKRET_NOFILES},
        {11, IDS_PACKRET_BADPWD},
        {12, IDS_PACKRET_READ},
        {255, IDS_PACKRET_STOPPED},
        {-1, -1}};
// 7-Zip console (feature 084)
const TPackErrorTable SevenZipErrors =
    {
        {1, IDS_PACKRET_WARNING},
        {2, IDS_PACKRET_FATAL},
        {7, IDS_PACKRET_PARAMS},
        {8, IDS_PACKRET_MEMORY},
        {255, IDS_PACKRET_STOPPED},
        {-1, -1}};

// Variables distinguished in the command line and the current directory when
// launching an external program
const char* PACK_ARC_PATH = "ArchivePath";
const char* PACK_ARC_FILE = "ArchiveFileName";
const char* PACK_ARC_NAME = "ArchiveFullName";
const char* PACK_SRC_PATH = "SourcePath";
const char* PACK_TGT_PATH = "TargetPath";
const char* PACK_LST_NAME = "ListFullName";
const char* PACK_EXT_NAME = "ExtractFullName";
const char* PACK_ARC_DOSFILE = "ArchiveDOSFileName";
const char* PACK_ARC_DOSNAME = "ArchiveDOSFullName";
const char* PACK_TGT_DOSPATH = "TargetDOSPath";
const char* PACK_LST_DOSNAME = "ListDOSFullName";
// feature 084: the list of files written in UTF-16LE with a BOM (research R7a);
// a command that uses it decides the list-file encoding by itself
const char* PACK_LST_UNINAME = "ListUnicodeFullName";

// paths of the supported external archivers (feature 084: 7-Zip and WinRAR; the
// variables of the ten removed archivers no longer expand - stored commands
// that used them are removed by the version 106 migration)
const char* PACK_EXE_7ZIP = "SevenZipExecutable";
const char* PACK_EXE_RAR32 = "Rar32bitExecutable";

// Menu in configuration

/* used by the export_mnu.py script that generates salmenu.mnu for the
   Translator; keep synchronized with the array below...
MENU_TEMPLATE_ITEM CmdCustomPackers[] = 
{
  {MNTT_PB, 0
  {MNTT_IT, IDS_PACK_EXE_7ZIP
  {MNTT_IT, IDS_PACK_EXE_RAR
  {MNTT_IT, IDS_PACK_EXE_BROWSE
  {MNTT_PE, 0
};
*/

// Command
CExecuteItem CmdCustomPackers[] =
    {
        {PACK_EXE_7ZIP, IDS_PACK_EXE_7ZIP, EIF_VARIABLE | EIF_REPLACE_ALL},
        {PACK_EXE_RAR32, IDS_PACK_EXE_RAR, EIF_VARIABLE | EIF_REPLACE_ALL},
        {EXECUTE_SEPARATOR, 0, 0},
        {EXECUTE_BROWSE, IDS_PACK_EXE_BROWSE, EIF_REPLACE_ALL},
        {EXECUTE_TERMINATOR, 0, 0},
};

/* used by the export_mnu.py script that generates salmenu.mnu for the
   Translator; keep synchronized with the array below...
MENU_TEMPLATE_ITEM ArgsCustomPackers[] = 
{
  {MNTT_PB, 0
  {MNTT_IT, IDS_PACK_ARC_NAME
  {MNTT_IT, IDS_PACK_ARC_FILE
  {MNTT_IT, IDS_PACK_ARC_PATH
  {MNTT_IT, IDS_PACK_LST_NAME
  {MNTT_IT, IDS_PACK_LST_UNINAME
  {MNTT_PE, 0
};
*/

// Arguments
// Custom packers/unpackers (feature 084: the DOS (8.3) variables are no longer
// offered here, but they still expand in commands that use them - FR-008)
CExecuteItem ArgsCustomPackers[] =
    {
        {PACK_ARC_NAME, IDS_PACK_ARC_NAME, EIF_VARIABLE},
        {PACK_ARC_FILE, IDS_PACK_ARC_FILE, EIF_VARIABLE},
        {PACK_ARC_PATH, IDS_PACK_ARC_PATH, EIF_VARIABLE},
        {PACK_LST_NAME, IDS_PACK_LST_NAME, EIF_VARIABLE},
        {PACK_LST_UNINAME, IDS_PACK_LST_UNINAME, EIF_VARIABLE},
        {EXECUTE_TERMINATOR, 0, 0},
};

//
// ****************************************************************************
// Functions
// ****************************************************************************
//

//
// ****************************************************************************
// Implementation of the configuration object - association of extensions and packers
//

CPackerFormatConfig::CPackerFormatConfig(/*BOOL disableDefaultValues*/)
    : Formats(10, 5)
{
    /*
  if (!disableDefaultValues)
  {
    AddDefault(0);
    if (!BuildArray())
    {
      TRACE_E("Unable to create data for archive detection");
    }
  }
*/
}

void CPackerFormatConfig::InitializeDefaultValues()
{
    AddDefault(0);
    if (!BuildArray())
    {
        TRACE_E("Unable to create data for archive detection");
    }
}

void CPackerFormatConfig::AddDefault(int SalamVersion)
{
    int index;

    switch (SalamVersion)
    {
    case 0: // default
    case 1: // version 1.52 had no packers
        if ((index = AddFormat()) == -1)
            return;
        SetFormat(index, "zip", TRUE, -1, -1, TRUE);
        // feature 084: RAR keeps archiver index 1 (packing by WinRAR; browsing is
        // taken over by the 7zip plug-in), the formats no plug-in reads go to the
        // 7-Zip console (index 0, unpacking only); "j", "uc2", "ace" and the ARJ
        // volumes "a##" are no longer claimed (see specs/084-archiver-cleanup/inventory.md)
        if ((index = AddFormat()) == -1)
            return;
        SetFormat(index, "rar;r##", TRUE, PACKRARINDEX, PACKRARINDEX, TRUE);
        if ((index = AddFormat()) == -1)
            return;
        SetFormat(index, "arj", FALSE, -1, PACK7ZIPINDEX, TRUE);
        if ((index = AddFormat()) == -1)
            return;
        SetFormat(index, "lzh;lha", FALSE, -1, PACK7ZIPINDEX, TRUE);

    case 2: // what was added after beta1
        // workaround to add the PK3 extension to ZIP
        for (index = 0; index < Formats.Count; index++)
            if (!stricmp(Formats[index]->Ext, "zip"))
            {
                char* ptr = (char*)malloc(strlen(Formats[index]->Ext) + 5);
                if (ptr != NULL)
                {
                    strcpy(ptr, Formats[index]->Ext);
                    strcat(ptr, ";pk3");
                    free(Formats[index]->Ext);
                    Formats[index]->Ext = ptr;
                }
                break;
            }
        // (the "pak" format was removed with the PAK plugin, feature 007)

    case 3: // what was added after beta2
    case 4: // beta3 but with old configuration (contains $(SpawnName))
        // (the "c##" extension of ACE was added here; ACE was removed in feature 084)

    case 5: // what's new in beta4?
        if ((index = AddFormat()) == -1)
            return;
        SetFormat(index, "tgz;tbz;taz;tar;gz;bz;bz2;z;rpm;cpio", FALSE, 0, -2, TRUE);
        // workaround to add the JAR extension to ZIP
        for (index = 0; index < Formats.Count; index++)
            if (!stricmp(Formats[index]->Ext, "zip;pk3"))
            {
                char* ptr = (char*)malloc(strlen(Formats[index]->Ext) + 5);
                if (ptr != NULL)
                {
                    strcpy(ptr, Formats[index]->Ext);
                    strcat(ptr, ";jar");
                    free(Formats[index]->Ext);
                    Formats[index]->Ext = ptr;
                }
                break;
            }
    }
}

BOOL CPackerFormatConfig::BuildArray(int* line, int* column)
{
    BOOL ret = TRUE;
    char buffer[501];
    buffer[500] = '\0';

    // clear the existing array
    int i;
    for (i = 0; i < 256; i++)
        Extensions[i].DestroyMembers();
    // and fill it again
    CExtItem item;
    for (i = 0; i < Formats.Count; i++)
    {
        // feature 084 (FR-017): a record whose external unpacker is not installed,
        // or cannot browse at all (RAR - the 7zip plug-in browses it), is left out:
        // its extensions are then ordinary files. The record itself stays stored,
        // so installing the program and running Autoconfiguration brings it back.
        int unpacker = GetUnpackerIndex(i);
        if (unpacker >= 0 && !ArchiverConfig.CanBrowse(unpacker))
            continue;
        strncpy(buffer, GetExt(i), 500);
        char* ptr = strtok(buffer, ";");
        while (ptr != NULL)
        {
            int len = (int)strlen(ptr);
            char* ext = (char*)malloc(len + 1);
            int last = len - 1;
            len -= 2;
            int idx = 0;
            while (len >= 0)
            {
                ext[idx++] = LowerCase[ptr[len--]];
            }
            ext[idx++] = '.';
            ext[idx] = '\0';
            item.Set(ext, i);
            if (!Extensions[LowerCase[ptr[last]]].SIns(item))
            {
                free(ext);
                if (ret)
                {
                    if (line != NULL)
                        *line = i;
                    if (column != NULL)
                        *column = (int)(ptr - buffer);
                    ret = FALSE;
                }
            }
            ptr = strtok(NULL, ";");
        }
    }
    item.Set(NULL, 0);
    return ret;
}

int CPackerFormatConfig::AddFormat()
{
    CPackerFormatConfigData* data = new CPackerFormatConfigData;
    if (data == NULL)
        return -1;
    int index = Formats.Add(data);
    if (!Formats.IsGood())
    {
        Formats.ResetState();
        return -1;
    }
    return index;
}

BOOL CPackerFormatConfig::SetFormat(int index, const char* ext, BOOL usePacker,
                                    const int packerIndex, const int unpackerIndex, BOOL old)

{
    CPackerFormatConfigData* data = Formats[index];
    data->Destroy();

    data->Ext = DupStr(ext);
    data->UsePacker = usePacker;
    if (usePacker)
        data->PackerIndex = packerIndex;
    else
        data->PackerIndex = -1;
    data->UnpackerIndex = unpackerIndex;
    data->OldType = old;

    if (data->IsValid())
        return TRUE;
    else
    {
        TRACE_E("invalid data");
        Formats.Delete(index);
        return FALSE;
    }
}

// returns the format table index + 1 or FALSE (0) when it's not an archive
int CPackerFormatConfig::PackIsArchive(const char* archiveName, int archiveNameLen)
{
    // j.r. I disabled the macro because PackIsArchive is heavily called from CFilesWindow::CommonRefresh()
    CALL_STACK_MESSAGE_NONE
    //  CALL_STACK_MESSAGE2("PackIsArchive(%s)", archiveName);
    if (archiveName[0] == 0)
        return 0; // not found
    int idx;
    if (archiveNameLen == -1)
        idx = (int)strlen(archiveName) - 1;
    else
        idx = archiveNameLen - 1;
    // encoding-check: allow acp-byte-table-on-name - a hash bucket: BuildArray files each extension under the same fold of its last byte, so the two sides agree (feature 092: deferred pair, research T4/T6)
    CStringArray* array = &Extensions[LowerCase[archiveName[idx]]];
    // take the last character as it is
    int i;
    for (i = 0; i < array->Count; i++)
    {
        char* ptr = array->At(i).GetExt();
        const char* name = &archiveName[idx - 1];
        while (*ptr != '\0' && name >= archiveName &&
               ((*ptr == LowerCase[*name] && *ptr != '#') ||
                (*ptr == '#' && *name >= '0' && *name <= '9')))
        {
            ptr++;
            name--;
        }
        if (*ptr == '\0')
            return array->At(i).GetIndex() + 1;
    }
    // if the last character is a digit
    if (archiveName[idx] >= '0' && archiveName[idx] <= '9')
    {
        array = &Extensions['#'];
        for (i = 0; i < array->Count; i++)
        {
            char* ptr = array->At(i).GetExt();
            const char* name = &archiveName[idx - 1];
            while (*ptr != '\0' && name >= archiveName &&
                   ((*ptr == LowerCase[*name] && *ptr != '#') ||
                    (*ptr == '#' && *name >= '0' && *name <= '9')))
            {
                ptr++;
                name--;
            }
            if (*ptr == '\0')
                return array->At(i).GetIndex() + 1;
        }
    }
    // not found
    return 0;
}

BOOL CPackerFormatConfig::CanPack(int index)
{
    if (!Formats[index]->UsePacker)
        return FALSE;
    int packer = Formats[index]->PackerIndex;
    return packer < 0 || ArchiverConfig.IsArchiverAvailable(packer);
}

BOOL CPackerFormatConfig::Load(CPackerFormatConfig& src)
{
    DeleteAllFormats();
    int i;
    for (i = 0; i < src.GetFormatsCount(); i++)
    {
        int index = AddFormat();
        if (index == -1)
            return FALSE;
        if (!SetFormat(index, src.GetExt(i), src.GetUsePacker(i),
                       src.GetPackerIndex(i), src.GetUnpackerIndex(i), src.GetOldType(i)))
            return FALSE;
    }
    return TRUE;
}

BOOL CPackerFormatConfig::Save(int index, HKEY hKey)
{
    DWORD d;
    BOOL ret = TRUE;
    if (ret)
        ret &= SetValue(hKey, SALAMANDER_PPA_EXTENSIONS, REG_SZ, GetExt(index), -1);
    d = GetUsePacker(index);
    if (ret)
        ret &= SetValue(hKey, SALAMANDER_PPA_USEPACKER, REG_DWORD, &d, sizeof(d));
    d = GetPackerIndex(index);
    if (ret)
        ret &= SetValue(hKey, SALAMANDER_PPA_PINDEX, REG_DWORD, &d, sizeof(d));
    d = GetUnpackerIndex(index);
    if (ret)
        ret &= SetValue(hKey, SALAMANDER_PPA_UINDEX, REG_DWORD, &d, sizeof(d));
    return ret;
}

BOOL CPackerFormatConfig::Load(HKEY hKey)
{
    int max = MAX_PATH + 2;

    char ext[MAX_PATH + 2];
    ext[0] = 0;
    DWORD packerIndex, unpackerIndex, usePacker;

    BOOL ret = TRUE;
    if (ret)
        ret &= GetValue(hKey, SALAMANDER_PPA_EXTENSIONS, REG_SZ, ext, max);
    if (ret)
        ret &= GetValue(hKey, SALAMANDER_PPA_USEPACKER, REG_DWORD, &usePacker, sizeof(DWORD));
    if (ret)
        ret &= GetValue(hKey, SALAMANDER_PPA_PINDEX, REG_DWORD, &packerIndex, sizeof(DWORD));
    if (ret)
        ret &= GetValue(hKey, SALAMANDER_PPA_UINDEX, REG_DWORD, &unpackerIndex, sizeof(DWORD));

    if (ret)
    {
        int index;
        if ((index = AddFormat()) == -1)
            return FALSE;
        if (Configuration.ConfigVersion < 44) // convert extensions to lowercase
        {
            char extAux[MAX_PATH + 2];
            lstrcpyn(extAux, ext, MAX_PATH + 2);
            StrICpy(ext, extAux);
        }
        ret &= SetFormat(index, ext, usePacker, packerIndex, unpackerIndex,
                         Configuration.ConfigVersion < 6);
    }

    return ret;
}

/*
BOOL
CPackerFormatConfig::SwapFormats(int index1, int index2)
{
  BYTE buff[sizeof(CPackerFormatConfigData)];
  memcpy(buff, Formats[index1], sizeof(CPackerFormatConfigData));
  memcpy(Formats[index1], Formats[index2], sizeof(CPackerFormatConfigData));
  memcpy(Formats[index2], buff, sizeof(CPackerFormatConfigData));
  return TRUE;
}
*/

BOOL CPackerFormatConfig::MoveFormat(int srcIndex, int dstIndex)
{
    BYTE buff[sizeof(CPackerFormatConfigData)];
    memcpy(buff, Formats[srcIndex], sizeof(CPackerFormatConfigData));
    if (srcIndex < dstIndex)
    {
        int i;
        for (i = srcIndex; i < dstIndex; i++)
            memcpy(Formats[i], Formats[i + 1], sizeof(CPackerFormatConfigData));
    }
    else
    {
        int i;
        for (i = srcIndex; i > dstIndex; i--)
            memcpy(Formats[i], Formats[i - 1], sizeof(CPackerFormatConfigData));
    }
    memcpy(Formats[dstIndex], buff, sizeof(CPackerFormatConfigData));
    return TRUE;
}

void CPackerFormatConfig::DeleteFormat(int index)
{
    Formats.Delete(index);
}

//
// ****************************************************************************
// Implementation of the configuration class - predefined packers
//

// constructor
CArchiverConfig::CArchiverConfig(/*BOOL disableDefaultValues*/)
    : Archivers(20, 10)
{
    /*
  // set default values if it is not disabled
  if (!disableDefaultValues)
    AddDefault(0);
*/
}

void CArchiverConfig::InitializeDefaultValues()
{
    // set default values if it is not disabled
    AddDefault(0);
}

// sets default values
void CArchiverConfig::AddDefault(int SalamVersion)
{
    int index;

    // BOOL SetArchiver(int index, DWORD uid, const char *title, EPackExeType type, BOOL exesAreSame,
    //                  const char *packerVariable, const char *unpackerVariable,
    //                  const char *packerExecutable, const char *unpackerExecutable,
    //                  const char *packExeFile, const char *unpackExeFile)

    // feature 084: only the archivers that still exist and run on 64-bit Windows;
    // the row order is the archiver index (PACK7ZIPINDEX, PACKRARINDEX)
    switch (SalamVersion)
    {
    case 0: // default
    case 1: // version 1.52 had no packers
        if ((index = AddArchiver()) == -1)
            return;
        SetArchiver(index, ARC_UID_7ZIP, LoadStr(IDS_EXT_7ZIP), EXE_32BIT, TRUE, PACK_EXE_7ZIP, NULL,
                    "7z", NULL, "7z", NULL);
        if ((index = AddArchiver()) == -1)
            return;
        SetArchiver(index, ARC_UID_RAR32, LoadStr(IDS_EXT_RAR), EXE_32BIT, TRUE, PACK_EXE_RAR32, NULL,
                    "rar", NULL, "rar", NULL);
    }
}

// feature 084 (FR-017): the configured program of every archiver is looked up
// once here, never per file (PackIsArchive is on the panel refresh path)
void CArchiverConfig::RefreshAvailability()
{
    CALL_STACK_MESSAGE1("CArchiverConfig::RefreshAvailability()");
    int i;
    for (i = 0; i < Archivers.Count; i++)
    {
        CArchiverConfigData* data = Archivers[i];
        data->Available = FALSE;
        const char* exe = data->PackExeFile;
        if (exe == NULL || exe[0] == 0)
            continue;
        // the same expansion PackExpExeName() applies before the program is started
        char expanded[MAX_PATH];
        if (!ExpandCommand(NULL, exe, expanded, MAX_PATH, FALSE))
            lstrcpyn(expanded, exe, MAX_PATH);
        char* s = expanded;
        int len = (int)strlen(s);
        if (len >= 2 && s[0] == '"' && s[len - 1] == '"')
        {
            s[len - 1] = 0;
            s++;
        }
        if ((s[0] == '\\' && s[1] == '\\') || (s[0] == '/' && s[1] == '/'))
        {
            // a program on a network share: not probed here (this runs at every
            // start, and an unreachable server would stall it); it is offered and
            // a failed start names it (independent review of feature 084)
            data->Available = TRUE;
        }
        else if (strchr(s, '\\') != NULL || strchr(s, '/') != NULL || strchr(s, ':') != NULL)
        {
            DWORD attrs = SalGetFileAttributes(s);
            data->Available = attrs != INVALID_FILE_ATTRIBUTES && (attrs & FILE_ATTRIBUTE_DIRECTORY) == 0;
        }
        else
        {
            // a bare program name ("7z", the default before Autoconfiguration ran)
            // works when Windows finds it on the PATH - CreateProcess searches the same way
            WCHAR* nameW = SalU8ToWAlloc(s);
            if (nameW != NULL)
            {
                WCHAR found[MAX_PATH];
                data->Available = SearchPathW(NULL, nameW, L".exe", MAX_PATH, found, NULL) != 0;
                free(nameW);
            }
        }
    }
}

BOOL CArchiverConfig::IsArchiverAvailable(int index)
{
    return index >= 0 && index < Archivers.Count && Archivers[index]->Available;
}

BOOL CArchiverConfig::CanBrowse(int index)
{
    return IsArchiverAvailable(index) && index < PACK_ARCHIVERS_COUNT &&
           PackBrowseTable[index].ListCommand != NULL;
}

BOOL CArchiverConfig::NeverBrowses(int index)
{
    return index >= 0 && index < PACK_ARCHIVERS_COUNT && PackBrowseTable[index].ListCommand == NULL;
}

// initializes the configuration based on another configuration
BOOL CArchiverConfig::Load(CArchiverConfig& src)
{
    // clear what we have (if we have anything)
    DeleteAllArchivers();
    // and add what we received
    int i;
    for (i = 0; i < src.GetArchiversCount(); i++)
    {
        int index = AddArchiver();
        if (index == -1)
            return FALSE;
        if (!SetArchiver(index, src.GetArchiverUID(i), src.GetArchiverTitle(i), src.GetArchiverType(i),
                         src.ArchiverExesAreSame(i),
                         src.GetPackerVariable(i), src.GetUnpackerVariable(i),
                         src.GetPackerExecutable(i), src.GetUnpackerExecutable(i),
                         src.GetPackerExeFile(i), src.GetUnpackerExeFile(i)))
            return FALSE;
    }
    return TRUE;
}

// creates a new empty archiver at the end of the array
int CArchiverConfig::AddArchiver()
{
    CArchiverConfigData* data = new CArchiverConfigData;
    if (data == NULL)
        return -1;
    int index = Archivers.Add(data);
    if (!Archivers.IsGood())
    {
        Archivers.ResetState();
        delete data;
        return -1;
    }
    return index;
}

// sets the archiver at the given index to the requested values
BOOL CArchiverConfig::SetArchiver(int index, DWORD uid, const char* title, EPackExeType type, BOOL exesAreSame,
                                  const char* packerVariable, const char* unpackerVariable,
                                  const char* packerExecutable, const char* unpackerExecutable,
                                  const char* packExeFile, const char* unpackExeFile)
{
    // clear old data, if we have any
    CArchiverConfigData* data = Archivers[index];
    data->Destroy();

    data->UID = uid;
    data->Title = DupStr(title);
    data->Type = type;
    data->ExesAreSame = exesAreSame;
    // the variable and executable name are constant strings from Salamander's code; a shallow copy is enough
    data->PackerVariable = packerVariable;
    data->PackerExecutable = packerExecutable;
    // the path to the executable is allocated, make a copy
    data->PackExeFile = DupStr(packExeFile);
    if (!data->ExesAreSame)
    {
        // if the unpacker differs, initialize it as well
        data->UnpackerVariable = unpackerVariable;
        data->UnpackerExecutable = unpackerExecutable;
        data->UnpackExeFile = DupStr(unpackExeFile);
    }
    else
    {
        // if the packer is the same, the work is easier
        data->UnpackerVariable = NULL;
        data->UnpackerExecutable = NULL;
        data->UnpackExeFile = DupStr(packExeFile);
    }

    // are the values meaningful?
    if (data->IsValid())
        return TRUE;
    else
    {
        TRACE_E("invalid data");
        Archivers.Delete(index);
        return FALSE;
    }
}

// sets the packer path for the packer at the given index
// (called from the transfer when closing the auto-configuration dialog)
void CArchiverConfig::SetPackerExeFile(int index, const char* filename)
{
    CArchiverConfigData* data = Archivers[index];
    if (data->PackExeFile)
        free(data->PackExeFile);
    // if we get NULL (not found by auto-configuration), use the default executable name
    data->PackExeFile = DupStr(filename != NULL ? filename : data->PackerExecutable);
}

// sets the packer path for the unpacker at the given index
// (called from the transfer when closing the auto-configuration dialog)
void CArchiverConfig::SetUnpackerExeFile(int index, const char* filename)
{
    CArchiverConfigData* data = Archivers[index];
    if (data->UnpackExeFile)
        free(data->UnpackExeFile);
    // if we get NULL (not found by auto-configuration), use the default executable name
    data->UnpackExeFile = DupStr(filename != NULL ? filename : data->UnpackerExecutable);
}

// saves the configuration of a single entry into the registry
BOOL CArchiverConfig::Save(int index, HKEY hKey)
{
    DWORD d;
    BOOL ret = TRUE;
    // save UID
    d = GetArchiverUID(index);
    if (ret)
        ret &= SetValue(hKey, SALAMANDER_PPC_UID, REG_DWORD, &d, sizeof(d));
    // (saves the title) - because it is translated it can no longer be used for identification
    //   of the archiver (UID is now used instead), there is no point in storing it
    //  if (ret) ret &= SetValue(hKey, SALAMANDER_PPC_TITLE, REG_SZ, GetArchiverTitle(index), -1);
    // save the executable path
    if (ret)
        ret &= SetValue(hKey, SALAMANDER_PPC_PACKEXE, REG_SZ, GetPackerExeFile(index), -1);
    // save whether packer and unpacker are the same
    d = ArchiverExesAreSame(index);
    if (ret)
        ret &= SetValue(hKey, SALAMANDER_PPC_EXESAME, REG_DWORD, &d, sizeof(d));

    // and if not, also store the path to the unpacker
    if (!ArchiverExesAreSame(index))
        if (ret)
            ret &= SetValue(hKey, SALAMANDER_PPC_UNPACKEXE, REG_SZ, GetUnpackerExeFile(index), -1);
    return ret;
}

// loads configuration of a single entry from the registry

// j.r. I reworked configuration loading -- it searches the default list and if a
//      registry item is found in this default list, its values are used, otherwise it is ignored.
//      The old method caused problems because users manually deleted the key
//      contents and there was no path (from the dialog) to restore the original list.
//      It also crashed Salamander, see bug CCfgPageExternalArchivers::DialogProc(0x111

BOOL CArchiverConfig::Load(HKEY hKey)
{
    int max = MAX_PATH + 2;
    char title[MAX_PATH + 2];
    title[0] = 0;
    char packExe[MAX_PATH + 2];
    packExe[0] = 0;
    char unpackExe[MAX_PATH + 2];
    unpackExe[0] = 0;
    DWORD exesAreSame;
    DWORD uid = -1;

    BOOL ret = TRUE;
    // loads the title
    if (ret && Configuration.ConfigVersion <= 64)
        ret &= GetValue(hKey, SALAMANDER_PPC_TITLE, REG_SZ, title, max);
    // loads the packing executable
    if (ret)
        ret &= GetValue(hKey, SALAMANDER_PPC_PACKEXE, REG_SZ, packExe, max);
    // determine whether the unpacker is the same
    if (ret)
        ret &= GetValue(hKey, SALAMANDER_PPC_EXESAME, REG_DWORD, &exesAreSame, sizeof(DWORD));
    // UID of the archiver (Title was previously used instead, but it is translated now and it can no longer be used)
    if (ret && Configuration.ConfigVersion > 64)
        ret &= GetValue(hKey, SALAMANDER_PPC_UID, REG_DWORD, &uid, sizeof(DWORD));
    // load the unpacker executable, if it is different from the packer
    if (!exesAreSame)
        if (ret)
            ret &= GetValue(hKey, SALAMANDER_PPC_UNPACKEXE, REG_SZ, unpackExe, max);

    if (ret)
    {
        int i;
        for (i = 0; i < Archivers.Count; i++)
        {
            CArchiverConfigData* arch = Archivers[i];
            // for keys that are complete and whose title matches the default value, take over their paths
            if (Configuration.ConfigVersion <= 64 && stricmp(title, arch->Title) == 0 || // Title is now translated and cannot be used anymore
                Configuration.ConfigVersion > 64 && uid == arch->UID)                    // thus we introduced a standard UID
            {
                SetPackerExeFile(i, packExe);
                SetUnpackerExeFile(i, exesAreSame ? packExe : unpackExe);
                break;
            }
        }
    }
    return ret;
}

//
// ****************************************************************************
// Parsing functions for replacing variables with their values
//

const char* WINAPI PackExpArcPath(HWND msgParent, void* param)
{
    SPackExpData* data = (SPackExpData*)param;
    const char* s = strrchr(data->ArcName, '\\');
    if (s == NULL)
    {
        TRACE_E("Unexpected value in PackExpArcPath().");
        return NULL;
    }
    strncpy(data->Buffer, data->ArcName, s - data->ArcName + 1);
    data->Buffer[s - data->ArcName + 1] = '\0';
    return data->Buffer;
}

const char* WINAPI PackExpArcName(HWND msgParent, void* param)
{
    SPackExpData* data = (SPackExpData*)param;
    if (!data->ArcNameFilePossible)
    {
        TRACE_E("It is not possible to combine DOS and long archive file name (ArchiveFileName and ArchiveFullName) in PackExpArcName().");
        return NULL;
    }
    data->DOSTmpFilePossible = FALSE; // from now on only ArcName

    return data->ArcName;
}

const char* WINAPI PackExpArcFile(HWND msgParent, void* param)
{
    SPackExpData* data = (SPackExpData*)param;

    if (!data->ArcNameFilePossible)
    {
        TRACE_E("It is not possible to combine DOS and long archive file name (ArchiveFileName and ArchiveFullName) in PackExpArcFile().");
        return NULL;
    }
    data->DOSTmpFilePossible = FALSE; // from now on only ArcName

    const char* s = strrchr(data->ArcName, '\\');
    if (s == NULL)
    {
        TRACE_E("Unexpected value in PackExpArcFile().");
        return NULL;
    }
    strcpy(data->Buffer, s + 1);
    return data->Buffer;
}

const char* WINAPI PackExpArcDosName(HWND msgParent, void* param)
{
    char buff2[MAX_PATH];
    SPackExpData* data = (SPackExpData*)param;

    if (data->ArcNameFilePossible)
    {
        if (!SalGetShortPathName(data->ArcName, buff2, MAX_PATH))
        {
            if (!data->DOSTmpFilePossible)
            {
                TRACE_E("Error (1) in SalGetShortPathName() in PackExpArcDosName().");
                return NULL;
            }
            data->ArcNameFilePossible = FALSE; // from now on only DOSTmpName
        }
        else
            data->DOSTmpFilePossible = FALSE; // from now on only ArcName
    }
    else
    {
        if (!data->DOSTmpFilePossible)
        {
            TRACE_E("Unable to return DOS nor long archive file name.");
            return NULL;
        }
    }

    if (data->DOSTmpFilePossible) // use a substitute name
    {
        if (data->DOSTmpFile[0] == 0) // it needs to be generated
        {
            char path[MAX_PATH + 50];
            strcpy(path, data->ArcName);
            if (CutDirectory(path))
            {
                char* s = path + strlen(path);
                if (s > path && *(s - 1) != '\\')
                    *s++ = '\\';
                strcpy(s, "PACK");
                s += 4;
                DWORD randNum = (GetTickCount() & 0xFFF);
                while (1)
                {
                    sprintf(s, "%X.*", randNum);
                    WIN32_FIND_DATAW findDataW; // feature 069 (F-P1-06)
                    // feature 069 (F-P1-06): 'path' comes from SalGetTempFileName (UTF-8)
                    HANDLE find = SalFindFirstFile(path, &findDataW); // registers with HANDLES itself
                    if (find != INVALID_HANDLE_VALUE)
                        HANDLES(FindClose(find)); // this name already exists with some extension, searching again
                    else
                    {
                        sprintf(s, "%X", randNum);
                        s += strlen(s);
                        const char* ext = data->ArcName + strlen(data->ArcName);
                        //            while (--ext > data->ArcName && *ext != '\\' && *ext != '.');
                        while (--ext >= data->ArcName && *ext != '\\' && *ext != '.')
                            ;
                        //            if (ext > data->ArcName && *ext == '.' && *(ext - 1) != '\\')  // copy the archive extension (used by multi-volume archivers: ARJ->A01,A02,...); ".cvspass" in Windows is an extension ...
                        if (ext >= data->ArcName && *ext == '.') // copy the archive extension (used by multi-volume archivers: ARJ->A01,A02,...)
                        {
                            int count = 4; // copy '.' plus at most 3 allowed extension characters (of the 8.3 format)
                            while (count-- && *ext < 128 && *ext != '[' && *ext != ']' &&
                                   *ext != ';' && *ext != '=' && *ext != ',' && *ext != ' ')
                            {
                                *s++ = *ext++;
                            }
                            *s = 0;
                        }
                        break; // we can use this name (it does not exist with any extension yet)
                    }
                    randNum++;
                }

                // feature 069 (F-P1-06): 'path' comes from SalGetTempFileName
                HANDLE h = SalCreateFile(path, GENERIC_WRITE, 0, NULL, CREATE_NEW,
                                         FILE_ATTRIBUTE_NORMAL, NULL);
                if (h != INVALID_HANDLE_VALUE)
                {
                    HANDLES(CloseHandle(h));
                    strcpy(data->DOSTmpFile, path);
                    BOOL ok = SalGetShortPathName(data->DOSTmpFile, buff2, MAX_PATH);
                    SalDeleteFile(data->DOSTmpFile); // we no longer need the file (let the archiver create it)
                    if (!ok)
                    {
                        TRACE_E("Error (2) in SalGetShortPathName() in PackExpArcDosName().");
                        return NULL;
                    }
                    strcpy(data->DOSTmpFile, buff2); // we obtained a substitute name
                }
                else
                {
                    DWORD err = GetLastError();
                    TRACE_E("Unable to create file with DOS-name in PackExpArcDosName(), error=" << err);
                    return NULL;
                }
            }
            else
            {
                TRACE_E("Unexpected situation in PackExpArcDosName().");
                return NULL;
            }
        }
        strcpy(buff2, data->DOSTmpFile);
    }

    strcpy(data->Buffer, buff2);
    return data->Buffer;
}

const char* WINAPI PackExpArcDosFile(HWND msgParent, void* param)
{
    char* s = (char*)PackExpArcDosName(msgParent, param);
    if (s == NULL)
    {
        TRACE_E("Previous TRACE_E belongs to PackExpArcDosFile().");
        return NULL;
    }

    char buff2[MAX_PATH];
    SPackExpData* data = (SPackExpData*)param;
    strcpy(buff2, s);

    s = strrchr(buff2, '\\');
    if (s == NULL)
    {
        TRACE_E("Unexpected value in PackExpArcDosFile().");
        return NULL;
    }
    strcpy(data->Buffer, s + 1);
    return data->Buffer;
}

const char* WINAPI PackExpSrcPath(HWND msgParent, void* param)
{
    if (((SPackExpData*)param)->SrcDir == NULL)
    {
        TRACE_E("Unexpected call to PackExpSrcPath().");
        return NULL;
    }
    return ((SPackExpData*)param)->SrcDir;
}

const char* WINAPI PackExpTgtPath(HWND msgParent, void* param)
{
    if (((SPackExpData*)param)->TgtDir == NULL)
    {
        TRACE_E("Unexpected call to PackExpTgtPath().");
        return NULL;
    }
    return ((SPackExpData*)param)->TgtDir;
}

const char* WINAPI PackExpTgtDosPath(HWND msgParent, void* param)
{
    SPackExpData* data = (SPackExpData*)param;
    if (data->TgtDir == NULL)
    {
        TRACE_E("Unexpected call to PackExpTgtDosPath().");
        return NULL;
    }
    if (!SalGetShortPathName(data->TgtDir, data->Buffer, MAX_PATH))
    {
        TRACE_E("Error in SalGetShortPathName() in PackExpTgtDosPath().");
        return NULL;
    }
    return data->Buffer;
}

const char* WINAPI PackExpLstName(HWND msgParent, void* param)
{
    if (((SPackExpData*)param)->LstName == NULL)
    {
        TRACE_E("Unexpected call to PackExpLstName().");
        return NULL;
    }
    return ((SPackExpData*)param)->LstName;
}

const char* WINAPI PackExpLstDosName(HWND msgParent, void* param)
{
    SPackExpData* data = (SPackExpData*)param;
    if (data->LstName == NULL)
    {
        TRACE_E("Unexpected call to PackExpLstDosName().");
        return NULL;
    }
    if (!SalGetShortPathName(data->LstName, data->Buffer, MAX_PATH))
    {
        TRACE_E("Error in SalGetShortPathName() in PackExpLstDosName().");
        return NULL;
    }
    return data->Buffer;
}

const char* WINAPI PackExpExtName(HWND msgParent, void* param)
{
    if (((SPackExpData*)param)->ExtName == NULL)
    {
        TRACE_E("Unexpected call to PackExpExtName().");
        return NULL;
    }
    return ((SPackExpData*)param)->ExtName;
}

const char* WINAPI
PackExpExeName(unsigned int index, BOOL unpacker = FALSE)
{
    // buffer for shortening the program name
    static char PackExpExeName[MAX_PATH];
    char buff[MAX_PATH];
    const char* exe;
    if (!unpacker)
        exe = ArchiverConfig.GetPackerExeFile(index);
    else
        exe = ArchiverConfig.GetUnpackerExeFile(index);
    // if the packer is not configured it should not be used, but
    // it's not excluded, so use the program name without the path
    if (exe == NULL)
        if (!unpacker)
            exe = ArchiverConfig.GetPackerExecutable(index);
        else
            exe = ArchiverConfig.GetUnpackerExecutable(index);
    // feature 084: the program is always given by its long name in quotes. The 8.3
    // short name was used for MS-DOS archivers, which could not take a long one;
    // on a volume without 8.3 names the "short" name IS the long one and went
    // into the command line unquoted - "D:\Program Files\7-Zip\7z.exe" then
    // started "D:\Program.exe" (independent review of feature 084, finding 4)
    unsigned long src = 0, dst = 0;
    if (exe[src] != '"')
        buff[dst++] = '"';
    while (exe[src] != '\0' && dst < MAX_PATH - 2)
        buff[dst++] = exe[src++];
    if (src == 0 || exe[src - 1] != '"')
        buff[dst++] = '"';
    buff[dst] = '\0';
    if (!ExpandCommand(NULL, buff, PackExpExeName, MAX_PATH, FALSE))
        strcpy(PackExpExeName, buff);
    return PackExpExeName;
}

const char* WINAPI PackExp7ZipExeName(HWND msgParent, void* param)
{
    return PackExpExeName(PACK7ZIPINDEX);
}

const char* WINAPI PackExpRar32ExeName(HWND msgParent, void* param)
{
    return PackExpExeName(PACKRARINDEX);
}

//
// ****************************************************************************
// Constants
// ****************************************************************************
//

// ****************************************************************************
// tables assigning individual evaluation functions to specific variables
//

// command line table
CSalamanderVarStrEntry PackCmdLineExpArray[] =
    {
        {PACK_ARC_PATH, PackExpArcPath},
        {PACK_ARC_FILE, PackExpArcFile},
        {PACK_ARC_DOSFILE, PackExpArcDosFile},
        {PACK_ARC_NAME, PackExpArcName},
        {PACK_ARC_DOSNAME, PackExpArcDosName},
        {PACK_TGT_PATH, PackExpTgtPath},
        {PACK_TGT_DOSPATH, PackExpTgtDosPath},
        {PACK_LST_NAME, PackExpLstName},
        {PACK_LST_DOSNAME, PackExpLstDosName},
        {PACK_LST_UNINAME, PackExpLstName}, // same file, only its encoding differs (feature 084)
        {PACK_EXT_NAME, PackExpExtName},
        {PACK_EXE_7ZIP, PackExp7ZipExeName},
        {PACK_EXE_RAR32, PackExpRar32ExeName},
        // sentinel
        {NULL, NULL}};

// current directory table
CSalamanderVarStrEntry PackInitDirExpArray[] =
    {
        {PACK_ARC_PATH, PackExpArcPath},
        {PACK_SRC_PATH, PackExpSrcPath},
        {PACK_TGT_PATH, PackExpTgtPath},
        {PACK_TGT_DOSPATH, PackExpTgtDosPath},
        {NULL, NULL}};

//
// ****************************************************************************
// Functions
// ****************************************************************************
//

//
// ****************************************************************************
// Functions for variable expansion
//

//
// ****************************************************************************
// BOOL PackExpandCmdLine(const char *archiveName, const char *tgtDir, const char *lstName,
//                        const char *extName, const char *exeName, const char *varText,
//                        char *buffer, const int bufferLen, char *DOSTmpName)
//
//   Expands variables in the command line
//
//   RET:  TRUE on success, FALSE on error
//   IN:   archiveName is the name of the archive we work with
//         tgtDir is the target directory name for the operation or NULL
//         lstName is the name of the file listing processed items or NULL
//         extName is the name of the extracted file or NULL
//         varText is the command line with variables
//         bufferLen is the size of the buffer parameter
//         DOSTmpName is NULL if a long name cannot be replaced by a substitute DOS name,
//           otherwise it points to a buffer at least MAX_PATH long
//   OUT:  buffer is the command line with variables expanded
//         DOSTmpName is the name of the temporary file (or an empty string if no replacement was made)

BOOL PackExpandCmdLine(const char* archiveName, const char* tgtDir, const char* lstName,
                       const char* extName, const char* varText, char* buffer,
                       const int bufferLen, char* DOSTmpName)
{
    CALL_STACK_MESSAGE7("PackExpandCmdLine(%s, %s, %s, %s, %s, , %d,)",
                        archiveName, tgtDir, lstName, extName, varText, bufferLen);
    SPackExpData data;
    data.ArcName = archiveName;
    data.SrcDir = NULL;
    data.TgtDir = tgtDir;
    data.LstName = lstName;
    data.ExtName = extName;
    data.ArcNameFilePossible = TRUE;
    data.DOSTmpFilePossible = DOSTmpName != NULL;
    if (DOSTmpName != NULL)
        DOSTmpName[0] = 0;
    data.DOSTmpFile = DOSTmpName;
    return ExpandVarString(MainWindow->HWindow, varText, buffer, bufferLen, PackCmdLineExpArray, &data);
}

//
// ****************************************************************************
// BOOL PackExpandInitDir(const char *archiveName, const char *srcDir, const char *tgtDir,
//                        const char *varText, char *buffer, const int bufferLen)
//
//   Expands variables in the string specifying the current directory for the launched program
//
//   RET:  TRUE on success, FALSE on error
//   IN:   archiveName is the archive name we work with
//         srcDir is the source directory for the operation or NULL
//         tgtDir is the target directory for the operation or NULL
//         varText is the command line with variables
//         bufferLen is the size of the buffer parameter
//   OUT:  buffer is the command line with variables expanded

BOOL PackExpandInitDir(const char* archiveName, const char* srcDir, const char* tgtDir,
                       const char* varText, char* buffer, const int bufferLen)
{
    CALL_STACK_MESSAGE6("PackExpandInitDir(%s, %s, %s, %s, , %d)",
                        archiveName, srcDir, tgtDir, varText, bufferLen);
    SPackExpData data;
    data.ArcName = archiveName;
    data.SrcDir = srcDir;
    data.TgtDir = tgtDir;
    data.LstName = NULL;
    data.ExtName = NULL;
    data.ArcNameFilePossible = TRUE;
    data.DOSTmpFilePossible = FALSE;
    data.DOSTmpFile = NULL;
    return ExpandVarString(MainWindow->HWindow, varText, buffer, bufferLen, PackInitDirExpArray, &data);
}

//
// ****************************************************************************
// General functions
//

//
// ****************************************************************************
// BOOL EmptyErrorHandler(HWND parent, const WORD err, ...)
//
//   Empty error function - to handle errors correctly, replace this function
//   in PackErrorHandlerPtr pointer with your own function that processes the error as needed.
//   It is used not only to report errors that occurred (IDS_PACKERR_*) but also
//   to resolve unexpected situations by asking the user (IDS_PACKQRY_*).
//
//   RET:  TRUE to continue, FALSE to abort
//   IN:   parent is the parent window of message boxes
//         err is the error number that occurred
//         remaining parameters further specify the error depending on its code

BOOL EmptyErrorHandler(HWND parent, const WORD err, ...)
{
    TRACE_E("Pack Empty Error Handler: error code " << err);
    return FALSE;
}

//
// ****************************************************************************
// void PackSetErrorHandler(BOOL (*handler)(HWND parent, const WORD errNum, ...))
//
//   Sets the error handling function
//
//   RET:
//   IN:   handler is the new function for error processing

void PackSetErrorHandler(BOOL (*handler)(HWND parent, const WORD errNum, ...))
{
    if (handler == NULL)
        PackErrorHandlerPtr = EmptyErrorHandler;
    else
        PackErrorHandlerPtr = handler;
}

// feature 097: see pack.h
BOOL PackArchiveNameFitsHandler(HWND parent, const char* archiveFileName, int builtForVersion)
{
    if (SalArchiveNameFitsHandler(builtForVersion, strlen(archiveFileName)))
        return TRUE;
    if (parent == NULL && MainWindow != NULL)
        parent = MainWindow->HWindow;
    SalMessageBox(parent, LoadStr(IDS_TOOLONGPATH), LoadStr(IDS_PACKERR_TITLE), MB_OK | MB_ICONEXCLAMATION);
    return FALSE;
}

// feature 097: see pack.h
int PackGetUnpackerVersion(const char* archiveFileName, BOOL* isArchive)
{
    *isArchive = FALSE;
    int format = PackerFormatConfig.PackIsArchive(archiveFileName);
    if (format == 0)
        return 0;
    int index = PackerFormatConfig.GetUnpackerIndex(format - 1);
    if (index >= 0)
    {
        *isArchive = TRUE;
        return SAL_ARCHIVE_HANDLER_EXTERNAL;
    }
    CPluginData* plugin = Plugins.Get(-index - 1);
    if (plugin == NULL || !plugin->SupportPanelView)
        return 0;
    *isArchive = TRUE;
    if (!plugin->InitDLL(MainWindow->HWindow)) // BuiltForVersion is valid only while the plug-in is loaded
        return 0;
    return plugin->BuiltForVersion;
}

//
// ****************************************************************************
// Running external archivers (feature 084, contract
// specs/084-archiver-cleanup/contracts/archiver-launch.md)
//
// Until feature 084 every archiver was started through utils\salspawn.exe, a
// helper that no build ever produced - so every external archiver failed with
// "Unable to execute new process ...\utils\salspawn.exe". The archiver is now
// the process we create; a job object stops it (and whatever it started) on
// Cancel and when Tandem Commander ends.

BOOL PackLastRunCancelled = FALSE;

BOOL CPackOutput::Append(const char* data, size_t len)
{
    if (len == 0)
        return TRUE;
    if (len > PACK_OUTPUT_MAXLEN || Len > PACK_OUTPUT_MAXLEN - len)
        return FALSE;
    if (Len + len + 1 > Cap)
    {
        size_t newCap = Cap == 0 ? 64 * 1024 : Cap;
        while (newCap < Len + len + 1)
            newCap *= 2;
        char* p = (char*)realloc(Data, newCap);
        if (p == NULL)
            return FALSE;
        Data = p;
        Cap = newCap;
    }
    memcpy(Data + Len, data, len);
    Len += len;
    Data[Len] = 0;
    return TRUE;
}

static void PackNormalizeProgramQuotes(const char* cmdLine, char* out, size_t outSize);

void PackGetProgramName(const char* cmdLineIn, char* program, int programSize)
{
    char cmdLine[PACK_CMDLINE_MAXLEN];
    PackNormalizeProgramQuotes(cmdLineIn, cmdLine, sizeof(cmdLine)); // ""path"" -> "path"
    int i = 0, j = 0;
    // skip leading whitespace
    while (cmdLine[i] == ' ' || cmdLine[i] == '\t')
        i++;
    // read the program name
    if (cmdLine[i] == '"')
    {
        i++;
        while (j < programSize - 1 && cmdLine[i] != 0 && cmdLine[i] != '"')
            program[j++] = cmdLine[i++];
    }
    else
    {
        while (j < programSize - 1 && cmdLine[i] != 0 && cmdLine[i] != ' ' && cmdLine[i] != '\t' &&
               cmdLine[i] != '"')
            program[j++] = cmdLine[i++];
    }
    program[j] = 0;
    SalU8TrimIncompleteTail(program); // a cut name must not end in half a character
}

BOOL PackReportExitCode(HWND parent, const char* cmdLine, DWORD exitCode, TPackErrorTable* const errorTable)
{
    char program[MAX_PATH];
    PackGetProgramName(cmdLine, program, MAX_PATH);
    // if errorTable == NULL, no translation is done (table doesn't exist)
    if (errorTable == NULL)
    {
        char buffer[1000];
        sprintf(buffer, LoadStr(IDS_PACKRET_GENERAL), exitCode);
        return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_RETURN, program, buffer);
    }
    // find the corresponding text in the table
    int i;
    for (i = 0; (*errorTable)[i][0] != -1 && (*errorTable)[i][0] != (int)exitCode; i++)
        ;
    if ((*errorTable)[i][0] == -1)
        return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_RETURN, program, LoadStr(IDS_PACKRET_UNKNOWN));
    return (*PackErrorHandlerPtr)(parent, IDS_PACKERR_RETURN, program, LoadStr((*errorTable)[i][1]));
}

EPackListEncoding PackGetListEncoding(const char* command, BOOL needANSIListFile)
{
    // variables are matched without regard to case, like ExpandVarString() does
    static const char token[] = "$(ListUnicodeFullName)";
    const int tokenLen = (int)sizeof(token) - 1;
    if (command != NULL)
    {
        const char* s;
        for (s = command; *s != 0; s++)
        {
            if (*s == '$' && _strnicmp(s, token, tokenLen) == 0)
                return PACKLIST_UNICODE;
        }
    }
    return needANSIListFile ? PACKLIST_ANSI : PACKLIST_OEM;
}

BOOL PackWriteListLineW(FILE* file, const char* a, const char* b, const char* c)
{
    const char* parts[3] = {a, b, c};
    int i;
    for (i = 0; i < 3; i++)
    {
        if (parts[i] == NULL || parts[i][0] == 0)
            continue;
        // WTF-8 -> UTF-16: a name with an unpaired surrogate (feature 066) keeps it
        WCHAR* w = SalU8ToWAlloc(parts[i]);
        if (w == NULL)
            return FALSE;
        size_t len = wcslen(w);
        BOOL ok = fwrite(w, sizeof(WCHAR), len, file) == len;
        free(w);
        if (!ok)
            return FALSE;
    }
    return fwrite(L"\r\n", sizeof(WCHAR), 2, file) == 2;
}

// reads whatever the archiver has written so far without ever blocking; FALSE
// when the output is too large or memory ran out
static BOOL PackDrainPipe(HANDLE pipe, CPackOutput* output, BOOL* broken)
{
    char buffer[16384];
    while (1)
    {
        DWORD avail = 0;
        if (!PeekNamedPipe(pipe, NULL, 0, NULL, &avail, NULL))
        {
            *broken = TRUE; // the archiver closed its end (and nobody else holds it)
            return TRUE;
        }
        if (avail == 0)
            return TRUE;
        DWORD read = 0;
        if (!ReadFile(pipe, buffer, avail < sizeof(buffer) ? avail : sizeof(buffer), &read, NULL))
        {
            *broken = TRUE;
            return TRUE;
        }
        if (read == 0)
            return TRUE;
        if (!output->Append(buffer, read))
            return FALSE;
    }
}

// shows the archiver's console window (it starts minimized) so the user can see
// a question it asks
static void PackRestoreConsoleWindow(DWORD processID)
{
    HWND win = NULL;
    while ((win = FindWindowEx(NULL, win, "ConsoleWindowClass", NULL)) != NULL)
    {
        DWORD pid;
        GetWindowThreadProcessId(win, &pid);
        if (pid == processID)
        {
            ShowWindow(win, SW_RESTORE);
            break;
        }
    }
}

// A command that quotes the archiver variable itself - "$(Rar32bitExecutable)" -
// expands to ""C:\...\Rar.exe"" since feature 084 quotes the path in the variable
// (until then an unquoted 8.3 name made such commands work). The doubled quotes
// around the program are reduced to single ones so these entries keep working
// (FR-008; independent re-review of feature 084, finding 1).
static void PackNormalizeProgramQuotes(const char* cmdLine, char* out, size_t outSize)
{
    lstrcpyn(out, cmdLine, (int)outSize);
    char* s = out;
    while (*s == ' ' || *s == '\t')
        s++;
    if (s[0] != '"' || s[1] != '"' || s[2] == '"' || s[2] == 0)
        return;
    char* end = strstr(s + 2, "\"\"");
    if (end == NULL || memchr(s + 2, '"', end - (s + 2)) != NULL)
        return;
    memmove(end, end + 1, strlen(end + 1) + 1); // the closing ""  -> "
    memmove(s, s + 1, strlen(s + 1) + 1);       // the opening ""  -> "
}

EPackRunResult PackRunArchiver(HWND parent, const char* cmdLineIn, const char* currentDir,
                               CPackOutput* output, DWORD* exitCode)
{
    CALL_STACK_MESSAGE3("PackRunArchiver(, %s, %s, ,)", cmdLineIn, currentDir);
    BOOL listing = output != NULL;
    *exitCode = 0;
    char cmdLine[PACK_CMDLINE_MAXLEN];
    PackNormalizeProgramQuotes(cmdLineIn, cmdLine, sizeof(cmdLine));

    char program[MAX_PATH];
    PackGetProgramName(cmdLine, program, MAX_PATH);
    if (program[0] == 0)
    {
        (*PackErrorHandlerPtr)(parent, IDS_PACKERR_CMDLNERR);
        return PACKRUN_FAILED;
    }

    // set everything needed to create the process
    SECURITY_ATTRIBUTES sa;
    sa.nLength = sizeof(SECURITY_ATTRIBUTES);
    sa.lpSecurityDescriptor = NULL;
    sa.bInheritHandle = TRUE;
    HANDLE outRd = NULL, outWr = NULL, errWr = NULL;
    HANDLE inNul = INVALID_HANDLE_VALUE;
    STARTUPINFO si;
    memset(&si, 0, sizeof(STARTUPINFO));
    si.cb = sizeof(STARTUPINFO);
    // a new process group: Ctrl+C in a console never reaches the archiver (what the
    // old helper ensured); Cancel stops it through the job instead
    DWORD flags = CREATE_NEW_PROCESS_GROUP | CREATE_DEFAULT_ERROR_MODE | NORMAL_PRIORITY_CLASS | CREATE_SUSPENDED;
    if (listing)
    {
        if (!HANDLES(CreatePipe(&outRd, &outWr, &sa, 0)))
        {
            char buffer[1000];
            strcpy(buffer, "CreatePipe: ");
            strcat(buffer, GetErrorText(GetLastError()));
            (*PackErrorHandlerPtr)(parent, IDS_PACKERR_GENERAL, buffer);
            return PACKRUN_FAILED;
        }
        SetHandleInformation(outRd, HANDLE_FLAG_INHERIT, 0); // our end must not leak into the archiver
        // so that we can use it as stderr as well
        if (!HANDLES(DuplicateHandle(GetCurrentProcess(), outWr, GetCurrentProcess(), &errWr,
                                     0, TRUE, DUPLICATE_SAME_ACCESS)))
        {
            char buffer[1000];
            strcpy(buffer, "DuplicateHandle: ");
            strcat(buffer, GetErrorText(GetLastError()));
            HANDLES(CloseHandle(outRd));
            HANDLES(CloseHandle(outWr));
            (*PackErrorHandlerPtr)(parent, IDS_PACKERR_GENERAL, buffer);
            return PACKRUN_FAILED;
        }
        // an archiver that asks a question while listing reads end-of-file and
        // fails instead of waiting forever for an answer nobody can give
        inNul = NOHANDLES(CreateFileW(L"NUL", GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, &sa,
                                      OPEN_EXISTING, 0, NULL));
        flags |= CREATE_NEW_CONSOLE;
        si.dwFlags = STARTF_USESHOWWINDOW | STARTF_USESTDHANDLES;
        si.wShowWindow = SW_HIDE;
        si.hStdInput = inNul != INVALID_HANDLE_VALUE ? inNul : NULL;
        si.hStdOutput = outWr;
        si.hStdError = errWr;
    }
    else if (PackWinTimeout != 0)
    {
        si.dwFlags = STARTF_USESHOWWINDOW;
        POINT p;
        if (MultiMonGetDefaultWindowPos(MainWindow->HWindow, &p))
        {
            // if the main window is on another monitor we should open the new window there
            // preferably at the default position (as on the primary monitor)
            si.dwFlags |= STARTF_USEPOSITION;
            si.dwX = p.x;
            si.dwY = p.y;
        }
        si.wShowWindow = SW_MINIMIZE;
    }

    // the job that stops the archiver and everything it starts
    HANDLE job = NOHANDLES(CreateJobObjectW(NULL, NULL));
    if (job != NULL)
    {
        JOBOBJECT_EXTENDED_LIMIT_INFORMATION li;
        memset(&li, 0, sizeof(li));
        li.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation, &li, sizeof(li)))
        {
            TRACE_E("PackRunArchiver(): SetInformationJobObject failed, error " << GetLastError());
            NOHANDLES(CloseHandle(job));
            job = NULL;
        }
    }
    else
        TRACE_E("PackRunArchiver(): CreateJobObject failed, error " << GetLastError());

    // launch the archiver itself
    PROCESS_INFORMATION pi;
    BOOL started = SalCreateProcess(NULL, cmdLine, NULL, NULL, TRUE, flags, NULL, currentDir, &si, &pi);
    DWORD err = started ? 0 : GetLastError();
    // the child's ends are not needed any more (the archiver has its own copies)
    if (outWr != NULL)
        HANDLES(CloseHandle(outWr));
    if (errWr != NULL)
        HANDLES(CloseHandle(errWr));
    if (inNul != INVALID_HANDLE_VALUE)
        NOHANDLES(CloseHandle(inNul));
    if (!started)
    {
        if (outRd != NULL)
            HANDLES(CloseHandle(outRd));
        if (job != NULL)
            NOHANDLES(CloseHandle(job));
        // name the program actually involved; point to the configuration only
        // where it can help - when the program is not there at all (FR-005)
        if (err == ERROR_FILE_NOT_FOUND || err == ERROR_PATH_NOT_FOUND)
            (*PackErrorHandlerPtr)(parent, IDS_PACKERR_EXEMISSING, program);
        else
            (*PackErrorHandlerPtr)(parent, IDS_PACKERR_STARTFAIL, program, GetErrorText(err));
        return PACKRUN_FAILED;
    }
    if (job != NULL && !AssignProcessToJobObject(job, pi.hProcess))
    {
        TRACE_E("PackRunArchiver(): AssignProcessToJobObject failed, error " << GetLastError());
        NOHANDLES(CloseHandle(job));
        job = NULL; // Cancel then stops at least the archiver itself
    }
    ResumeThread(pi.hThread);

    // the wait window with Cancel - for a run that executes the archiver; a listing
    // shows none of its own: its callers already show "Reading list of files ...
    // please wait" (CreateSafeWaitWindow) and a second window would cover it.
    // Esc cancels both kinds (UserWantsToCancelSafeWaitWindow: Esc while this
    // program is active, or that window's Close button).
    HWND hFocusedWnd = GetFocus();
    HWND main = parent == NULL ? MainWindow->HWindow : parent;
    CExecuteWindow waitWindow(main, IDS_PACK_EXECUTING, ooStatic);
    BOOL waitShown = FALSE;
    HWND oldPluginMsgBoxParent = PluginMsgBoxParent;
    EnableWindow(main, FALSE);
    // activate the hourglass cursor
    HCURSOR prevCrsr = SetCursor(LoadCursor(NULL, IDC_WAIT));
    if (!listing)
    {
        waitWindow.Create();
        waitShown = TRUE;
        // plugin timers may be invoked (happens with an FS plugin, e.g. FTP, open in the other panel) -> set parent for message boxes
        PluginMsgBoxParent = waitWindow.HWindow;
    }

    GetAsyncKeyState(VK_ESCAPE); // forget an Esc pressed before the run started
    EPackRunResult result = PACKRUN_EXITED;
    BOOL consoleRestored = listing || PackWinTimeout <= 0;
    BOOL pipeBroken = FALSE;
    BOOL overflow = FALSE;
    DWORD waitError = 0;
    DWORD start = GetTickCount();
    while (1)
    {
        if (listing && !pipeBroken && !PackDrainPipe(outRd, output, &pipeBroken))
        {
            overflow = TRUE;
            break;
        }
        DWORD elapsed = GetTickCount() - start;
        // a listing keeps the pipe drained so the archiver never blocks on a full pipe;
        // both kinds wake up regularly to notice Esc
        DWORD timeout = listing ? 50 : 100;
        if (!consoleRestored && elapsed < (DWORD)PackWinTimeout && (DWORD)PackWinTimeout - elapsed < timeout)
            timeout = (DWORD)PackWinTimeout - elapsed;
        // Petr: pumping only WM_PAINT leads to blocking all other instances of Salamander
        // (even newly started ones) and other software (at least during Paste), if a file
        // or directory is on the clipboard: OLE talks to this process, which then does
        // not answer - so all messages are pumped
        DWORD ret = MsgWaitForMultipleObjects(1, &pi.hProcess, FALSE, timeout, QS_ALLINPUT);
        if (ret == WAIT_OBJECT_0)
            break; // the archiver has ended
        if (ret == WAIT_FAILED)
        {
            waitError = GetLastError();
            break;
        }
        if (ret == WAIT_OBJECT_0 + 1)
        {
            MSG msg;
            while (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE))
            {
                TranslateMessage(&msg);
                DispatchMessage(&msg);
            }
        }
        if ((waitShown && waitWindow.Cancelled) || UserWantsToCancelSafeWaitWindow())
        {
            result = PACKRUN_CANCELLED;
            break;
        }
        elapsed = GetTickCount() - start;
        if (!consoleRestored && elapsed >= (DWORD)PackWinTimeout)
        {
            PackRestoreConsoleWindow(pi.dwProcessId);
            consoleRestored = TRUE;
        }
    }

    if (result == PACKRUN_CANCELLED || overflow || waitError != 0)
    {
        // stop the archiver and everything it has started
        if (job != NULL)
            TerminateJobObject(job, 255);
        else
            TerminateProcess(pi.hProcess, 255);
        WaitForSingleObject(pi.hProcess, 10000);
    }
    else if (listing)
    {
        // the archiver has ended: take the rest of its output (stop when nothing more
        // comes - a process it started could still hold the pipe open)
        while (!pipeBroken)
        {
            size_t before = output->Len;
            if (!PackDrainPipe(outRd, output, &pipeBroken))
            {
                overflow = TRUE;
                break;
            }
            if (output->Len == before)
                break;
        }
    }

    EnableWindow(main, TRUE);
    PluginMsgBoxParent = oldPluginMsgBoxParent;
    if (waitShown)
        DestroyWindow(waitWindow.HWindow);
    // if Salamander is active, call SetFocus on the stored window (SetFocus does
    // not work when the main window is disabled - after deactivation/activation
    // of the disabled main window, the active panel has no focus)
    HWND hwnd = GetForegroundWindow();
    while (hwnd != NULL && hwnd != main)
        hwnd = GetParent(hwnd);
    if (hwnd == main)
        SetFocus(hFocusedWnd);
    // remove the hourglass cursor
    SetCursor(prevCrsr);
    UpdateWindow(main);

    DWORD exitCodeError = 0;
    if (result == PACKRUN_EXITED && !overflow && waitError == 0 && !GetExitCodeProcess(pi.hProcess, exitCode))
        exitCodeError = GetLastError();

    // release the handles; closing the job ends anything the archiver left running
    HANDLES(CloseHandle(pi.hProcess));
    HANDLES(CloseHandle(pi.hThread));
    if (outRd != NULL)
        HANDLES(CloseHandle(outRd));
    if (job != NULL)
        NOHANDLES(CloseHandle(job));

    if (waitError != 0 || exitCodeError != 0)
    {
        char buffer[1000];
        strcpy(buffer, waitError != 0 ? "WaitForSingleObject: " : "GetExitCodeProcess: ");
        strcat(buffer, GetErrorText(waitError != 0 ? waitError : exitCodeError));
        (*PackErrorHandlerPtr)(parent, IDS_PACKERR_GENERAL, buffer);
        return PACKRUN_FAILED;
    }
    if (overflow)
    {
        (*PackErrorHandlerPtr)(parent, IDS_PACKERR_NOMEM);
        return PACKRUN_FAILED;
    }
    return result;
}

//
// ****************************************************************************
// BOOL PackExecute(HWND parent, char *cmdLine, const char *currentDir, TPackErrorTable *const errorTable)
//
//   Runs the external program given (including parameters) in cmdLine string
//
//   RET: returns TRUE on success, FALSE on error or when the user cancelled it
//        (PackLastRunCancelled then says which); an error is reported through
//        the callback *PackErrorHandlerPtr, a cancel is not
//   IN:  parent is the parent window for message boxes
//        cmdLine is the command line to execute
//        currentDir is the full current directory for the launched program or NULL if it doesn't matter
//        errorTable is a pointer to the return code table (if NULL, no table)

BOOL PackExecute(HWND parent, char* cmdLine, const char* currentDir, TPackErrorTable* const errorTable)
{
    CALL_STACK_MESSAGE3("PackExecute(, %s, %s, ,)", cmdLine, currentDir);
    PackLastRunCancelled = FALSE;
    DWORD exitCode;
    switch (PackRunArchiver(parent, cmdLine, currentDir, NULL, &exitCode))
    {
    case PACKRUN_FAILED:
        return FALSE; // already reported
    case PACKRUN_CANCELLED:
        PackLastRunCancelled = TRUE;
        return FALSE;
    }
    // and find out how it ended - hopefully they all return 0 as success
    if (exitCode != 0)
        return PackReportExitCode(parent, cmdLine, exitCode, errorTable);
    return TRUE;
}

//****************************************************************************
//
// CExecuteWindow
//

CExecuteWindow::CExecuteWindow(HWND hParent, int textResID, CObjectOrigin origin)
    : CWindow(origin)
{
    CALL_STACK_MESSAGE2("CExecuteWindow::CExecuteWindow(, %d, )", textResID);
    HParent = hParent;
    HCancel = NULL;
    TextAreaHeight = 0;
    Cancelled = FALSE;
    char* t = LoadStr(textResID);
    int len = (int)strlen(t);
    Text = new char[len + 1];
    if (Text == NULL)
        TRACE_E(LOW_MEMORY);
    else
        strcpy(Text, t);
}

CExecuteWindow::~CExecuteWindow()
{
    CALL_STACK_MESSAGE1("CExecuteWindow::~CExecuteWindow()");
    if (Text != NULL)
        delete[] Text;
}

#define EXECUTEWINDOW_HMARGIN 25
#define EXECUTEWINDOW_VMARGIN 18

HWND CExecuteWindow::Create()
{
    CALL_STACK_MESSAGE1("CExecuteWindow::Create()");
    // compute text size => window size
    SIZE s;
    s.cx = 300;
    s.cy = 30;
    SIZE b; // the Cancel button caption (feature 084)
    b.cx = 50;
    b.cy = 13;
    const WCHAR* cancelText = LoadStrW(IDS_BUTTON_CANCEL);
    HDC dc = HANDLES(GetDC(NULL));
    if (dc != NULL)
    {
        HFONT old = (HFONT)SelectObject(dc, EnvFont);
        GetTextExtentPoint32(dc, Text, (int)strlen(Text), &s);
        GetTextExtentPoint32W(dc, cancelText, (int)wcslen(cancelText), &b);
        SelectObject(dc, old);
        HANDLES(ReleaseDC(NULL, dc));
    }

    int buttonW = b.cx + 2 * b.cy;
    if (buttonW < 5 * b.cy)
        buttonW = 5 * b.cy;
    int buttonH = b.cy + b.cy / 2 + 6;
    TextAreaHeight = s.cy + 2 * EXECUTEWINDOW_VMARGIN;
    int width = (s.cx > buttonW ? s.cx : buttonW) + 2 * EXECUTEWINDOW_HMARGIN;
    int height = TextAreaHeight + buttonH + EXECUTEWINDOW_VMARGIN;
    int x;
    int y;

    RECT r2;
    GetWindowRect(MainWindow->HWindow, &r2);
    x = (r2.right + r2.left - width) / 2;
    GetWindowRect(MainWindow->LeftPanel->HWindow, &r2);
    y = (r2.bottom + r2.top - height) / 2;

    CreateEx(WS_EX_DLGMODALFRAME,
             SAVEBITS_CLASSNAME,
             "",
             WS_BORDER | WS_POPUP,
             x, y, width, height,
             HParent,
             NULL,
             HInstance,
             this);

    if (HWindow != NULL)
    {
        // feature 084: the archiver can be stopped (the main window is disabled
        // meanwhile, this window is not)
        RECT cr;
        GetClientRect(HWindow, &cr);
        HCancel = CreateWindowExW(0, L"BUTTON", cancelText,
                                  WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
                                  (cr.right - buttonW) / 2, TextAreaHeight, buttonW, buttonH,
                                  HWindow, (HMENU)IDCANCEL, HInstance, NULL);
        if (HCancel != NULL)
            SendMessage(HCancel, WM_SETFONT, (WPARAM)EnvFont, TRUE);
        ThemeApplyToWindowTree(HWindow);
    }

    ShowWindow(HWindow, SW_SHOWNA);
    return HWindow;
}

LRESULT
CExecuteWindow::WindowProc(UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    switch (uMsg)
    {
    case WM_COMMAND:
    {
        if (LOWORD(wParam) == IDCANCEL && HIWORD(wParam) == BN_CLICKED)
        {
            Cancelled = TRUE; // PackRunArchiver() stops the archiver
            if (HCancel != NULL)
                EnableWindow(HCancel, FALSE);
            return 0;
        }
        break;
    }

    case WM_ERASEBKGND:
    {
        LRESULT ret = CWindow::WindowProc(uMsg, wParam, lParam);
        HDC dc = (HDC)wParam;
        RECT r;
        GetClientRect(HWindow, &r);
        if (IsDarkThemeActive())
        {
            // the shared SAVEBITS window class keeps its light system brush;
            // without this fill the near-white text below lands on the light
            // background - unreadable (feature 049, defect C5; the
            // CWaitWindow precedent)
            FillRect(dc, &r, ThemeSysColorBrush(COLOR_BTNFACE));
            ret = TRUE;
        }
        if (Text != NULL)
        {
            if (TextAreaHeight > 0 && TextAreaHeight < r.bottom)
                r.bottom = TextAreaHeight; // the Cancel button is below the text
            HFONT hOldFont = (HFONT)SelectObject(dc, EnvFont);
            int prevBkMode = SetBkMode(dc, TRANSPARENT);
            SetTextColor(dc, ThemeSysColor(COLOR_BTNTEXT));
            DrawText(dc, Text, (int)strlen(Text), &r, DT_CENTER | DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
            SetBkMode(dc, prevBkMode);
            SelectObject(dc, hOldFont);
        }
        return ret;
    }

    case WM_SETCURSOR:
    {
        // the hourglass everywhere except over the Cancel button
        if ((HWND)wParam == HCancel && HCancel != NULL)
        {
            SetCursor(LoadCursor(NULL, IDC_ARROW));
            return TRUE;
        }
        LRESULT ret = CWindow::WindowProc(uMsg, wParam, lParam);
        SetCursor(LoadCursor(NULL, IDC_WAIT));
        return TRUE;
    }
    }
    return CWindow::WindowProc(uMsg, wParam, lParam);
}
