// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later
// CommentsTranslationProject: TRANSLATED

#include "precomp.h"

#include "cfgdlg.h"
#include "plugins.h"
#include "zip.h"
#include "pack.h"
#include "salarcmig.h" // feature 084

// custom packers / unpackers
const char* SALAMANDER_CPU_TITLE = "Title";
const char* SALAMANDER_CPU_EXT = "Ext";
const char* SALAMANDER_CPU_TYPE = "Type";
const char* SALAMANDER_CPU_SUPLONG = "Support Long Names";
const char* SALAMANDER_CPU_ANSILIST = "Need ANSI List";
// custom packers only
const char* SALAMANDER_CP_EXECCOPY = "Copy Command";
const char* SALAMANDER_CP_ARGSCOPY = "Copy Arguments";
const char* SALAMANDER_CP_SUPMOVE = "Support Move";
const char* SALAMANDER_CP_EXECMOVE = "Move Command";
const char* SALAMANDER_CP_ARGSMOVE = "Move Arguments";
// custom unpackers only
const char* SALAMANDER_CU_EXECEXTRACT = "Extract Command";
const char* SALAMANDER_CU_ARGSEXTRACT = "Extract Arguments";

// conversion table for translating exe to a variable
struct SPackConvTable
{
    const char* exe;
    const char* variable;
};

SPackConvTable PackConversionTable[] = {
    {"7z", "$(SevenZipExecutable)"},
    {"rar", "$(Rar32bitExecutable)"},
    {NULL, NULL}};

// custom packer table, indexed by the archiver index (PACK7ZIPINDEX, PACKRARINDEX;
// AutoConfig adds entries by that index). Feature 084: of the twelve archivers of
// 0.1.8 only these two remain; the RAR "1.44MB volumes" variant is gone.
SPackCustomPacker CustomPackers[] = {
    // [PACK7ZIPINDEX] 7-Zip console: no default packer (it is offered for unpacking only)
    {{NULL, NULL},
     {NULL, NULL},
     {-1, -1},
     "7z",
     TRUE,
     FALSE,
     "7z"},
    // [PACKRARINDEX] WinRAR console; the list of files is UTF-16 (research R7a)
    {{"a -scul -idq -y \"$(ArchiveFullName)\" @\"$(ListUnicodeFullName)\"", NULL},
     {"m -scul -idq -y \"$(ArchiveFullName)\" @\"$(ListUnicodeFullName)\"", NULL},
     {IDS_DP_RAR_WINRAR, -1},
     "rar",
     TRUE,
     FALSE,
     "rar"},
};

// custom unpacker table, indexed by the archiver index like CustomPackers
SPackCustomUnpacker CustomUnpackers[] = {
    // [PACK7ZIPINDEX] 7-Zip console: the formats no plug-in reads (inventory.md). It extracts
    // into $(TargetPath) - the empty temporary folder PackUniversalUncompress creates - so -y
    // is safe there and the files reach the real target through the ordinary move, which asks
    // before overwriting (without -o, 7-Zip would write into the target itself and -y would
    // overwrite the user's files silently - independent review of feature 084, finding 1)
    {"x -y -sccUTF-8 -scsUTF-16LE \"$(ArchiveFullName)\" -o\"$(TargetPath)\" @\"$(ListUnicodeFullName)\"", IDS_DU_7ZIP, "*.arj;*.lzh;*.lha", TRUE, FALSE, "7z"},
    // [PACKRARINDEX] WinRAR console: no default unpacker (RAR is unpacked by the 7zip plug-in)
    {NULL, -1, "*.rar", TRUE, FALSE, "rar"},
};

//
// ****************************************************************************
// CPackerConfig
//

CPackerConfig::CPackerConfig(/*BOOL disableDefaultValues*/)
    : Packers(30, 10)
{
    PreferedPacker = -1;
    Move = FALSE;
    /*
  if (!disableDefaultValues)
    AddDefault(0);
*/
}

void CPackerConfig::InitializeDefaultValues()
{
    AddDefault(0);
}

void CPackerConfig::AddDefault(int SalamVersion)
{
    // WARNING: up to version 6 the old 'Type' values were: 0 ZIP, 1 external, 2 TAR, 3 PAK

    // default values
    int index, i;
    // internal ones first to keep it sorted
    switch (SalamVersion)
    {
    case 0: // default config
    case 1: // v1.52 had no packers
        if ((index = AddPacker()) == -1)
            return;
        SetPacker(index, 0, "ZIP (Plugin)", "zip", TRUE);
    case 2:  // added after beta1 (the "PAK (Plugin)" packer was removed with the PAK plugin, feature 007)
    case 3:  // added after beta2
    case 4:  // beta 3 but with old configuration (contains $(SpawnName))
    case 5:; // what is new in beta4?
             //      if ((index = AddPacker()) == -1) return;
             //      SetPacker(index, 2, "TAR (Plugin)", "tgz", TRUE);
    }
    // now external
    switch (SalamVersion)
    {
        // parameters format
        //BOOL SetPacker(int index, int type, const char *title, const char *ext, BOOL old,
        //               BOOL supportLongNames = FALSE, BOOL supportMove = FALSE,
        //               const char *cmdExecCopy = NULL, const char *cmdArgsCopy = NULL,
        //               const char *cmdExecMove = NULL, const char *cmdArgsMove = NULL,
        //               BOOL needANSIListFile = FALSE);

    case 0: // default config
    case 1: // v1.52 had no packers
        // feature 084: the default packers of the supported external archivers
        // (CustomPackers is indexed by the archiver index; 7-Zip has no packer)
        for (i = 0; i < PACK_ARCHIVERS_COUNT; i++)
        {
            if (CustomPackers[i].CopyArgs[0] == NULL)
                continue;
            if ((index = AddPacker()) == -1)
                return;
            SetPacker(index, 1, LoadStrU8(CustomPackers[i].Title[0]), CustomPackers[i].Ext, TRUE,
                      CustomPackers[i].SupLN, TRUE,
                      CustomPackers[i].Exe, CustomPackers[i].CopyArgs[0],
                      CustomPackers[i].Exe, CustomPackers[i].MoveArgs[0],
                      CustomPackers[i].Ansi);
        }
    case 2: // added after beta1 (the remaining 1990s archivers, removed in feature 084)
    case 3: // added after beta2
    case 4: // beta 3 but with old configuration (contains $(SpawnName))
        // in older versions the $(SpawnName) variable might exist, it no longer does - we must remove it
        for (index = 0; index < GetPackersCount(); index++)
            if (GetPackerType(index) == 1)
            {
                const char* cmdC = GetPackerCmdExecCopy(index);
                const char* cmdM = GetPackerCmdExecMove(index);
                if (strncmp(cmdC, "$(SpawnName) ", 13) == 0 ||
                    GetPackerSupMove(index) && strncmp(cmdM, "$(SpawnName) ", 13) == 0)
                {
                    char* copyCmdBuf = (char*)malloc(strlen(cmdC) + 1);
                    if (strncmp(cmdC, "$(SpawnName) ", 13) == 0)
                        strcpy(copyCmdBuf, cmdC + 13);
                    else
                        strcpy(copyCmdBuf, cmdC);
                    char* copyArgBuf = (char*)malloc(strlen(GetPackerCmdArgsCopy(index)) + 1);
                    strcpy(copyArgBuf, GetPackerCmdArgsCopy(index));

                    char *moveCmdBuf, *moveArgBuf;
                    if (GetPackerSupMove(index))
                    {
                        moveCmdBuf = (char*)malloc(strlen(cmdM) + 1);
                        if (strncmp(cmdM, "$(SpawnName) ", 13) == 0)
                            strcpy(moveCmdBuf, cmdM + 13);
                        else
                            strcpy(moveCmdBuf, cmdM);
                        moveArgBuf = (char*)malloc(strlen(GetPackerCmdArgsMove(index)) + 1);
                        strcpy(moveArgBuf, GetPackerCmdArgsMove(index));
                    }
                    else
                        moveCmdBuf = moveArgBuf = NULL;

                    char* TitleBuf = (char*)malloc(strlen(GetPackerTitle(index)) + 1);
                    strcpy(TitleBuf, GetPackerTitle(index));
                    char* ExtBuf = (char*)malloc(strlen(GetPackerExt(index)) + 1);
                    strcpy(ExtBuf, GetPackerExt(index));

                    SetPacker(index, GetPackerType(index), TitleBuf, ExtBuf, TRUE,
                              GetPackerSupLongNames(index), GetPackerSupMove(index),
                              copyCmdBuf, copyArgBuf, moveCmdBuf, moveArgBuf,
                              GetPackerNeedANSIListFile(index));

                    free(copyCmdBuf);
                    free(copyArgBuf);
                    if (moveCmdBuf != NULL)
                        free(moveCmdBuf);
                    if (moveArgBuf != NULL)
                        free(moveArgBuf);
                    free(TitleBuf);
                    free(ExtBuf);
                }
            }
    case 5: // beta 3 but without tar
    case 6: // what is new in beta4?
    case 7: // 1.6b6 - for correct conversion of supported plugin functions (see CPlugins::Load)
    case 8:
        // transition to using variables instead of the direct exe file name
        for (index = 0; index < GetPackersCount(); index++)
            // consider only external packers
            if (((GetPackerOldType(index) && GetPackerType(index) == 1) ||
                 (!GetPackerOldType(index) && GetPackerType(index) == CUSTOMPACKER_EXTERNAL)) &&
                GetPackerCmdExecCopy(index) != NULL && GetPackerCmdExecMove(index) != NULL)
            {
                // take the old commands
                char* cmdC = DupStr(GetPackerCmdExecCopy(index));
                char* cmdM = DupStr(GetPackerCmdExecMove(index));
                i = 0;
                BOOL found = FALSE;
                // and search the table with them
                while (PackConversionTable[i].exe != NULL)
                {
                    // compare with table entries
                    if (!strcmp(cmdC, PackConversionTable[i].exe) || !strcmp(cmdM, PackConversionTable[i].exe))
                    {
                        // if we find it, replace it with the variable
                        if (!strcmp(cmdC, PackConversionTable[i].exe))
                        {
                            free(cmdC);
                            // (the RAR 16-bit special case went with the DOS archivers, feature 084)
                            cmdC = DupStr(PackConversionTable[i].variable);
                        }
                        if (!strcmp(cmdM, PackConversionTable[i].exe))
                        {
                            free(cmdM);
                            // (the RAR 16-bit special case went with the DOS archivers, feature 084)
                            cmdM = DupStr(PackConversionTable[i].variable);
                        }
                        found = TRUE;
                    }
                    i++;
                }
                // strings must be copied somewhere or we delete them before use
                char* title = DupStr(GetPackerTitle(index));
                char* ext = DupStr(GetPackerExt(index));
                char* argsC = DupStr(GetPackerCmdArgsCopy(index));
                char* argsM = DupStr(GetPackerCmdArgsMove(index));

                if (found)
                    SetPacker(index, GetPackerType(index), title, ext, GetPackerOldType(index),
                              GetPackerSupLongNames(index), GetPackerSupMove(index),
                              cmdC, argsC, cmdM, argsM, GetPackerNeedANSIListFile(index));
                free(argsC);
                free(argsM);
                free(title);
                free(ext);
                free(cmdC);
                free(cmdM);
            }
    case 9: // 1.6b6 - due to switching from exe name to variable in custom packers
        // enable ANSI file list for ACE32 and PKZIP25
        for (index = 0; index < GetPackersCount(); index++)
        {
            if ((GetPackerOldType(index) && GetPackerType(index) == 1) ||
                (!GetPackerOldType(index) && GetPackerType(index) == CUSTOMPACKER_EXTERNAL))
            {
                const char* s = GetPackerCmdExecCopy(index);
                if (s != NULL && (strcmp(s, "$(Zip32bitExecutable)") == 0 ||
                                  strcmp(s, "$(Ace32bitExecutable)") == 0))
                {
                    Packers[index]->NeedANSIListFile = TRUE;
                }
            }
        }
        // change "XXX (Internal)" to "XXX (Plugin)"
        // we aggressively overwrite it, because we're changing to shorter text -> simply overwriting is enough
        for (index = 0; index < GetPackersCount(); index++)
        {
            if ((GetPackerOldType(index) && GetPackerType(index) != 1) ||
                (!GetPackerOldType(index) && GetPackerType(index) != CUSTOMPACKER_EXTERNAL))
            { // take only plug-ins (not external packers)
                char* s = Packers[index]->Title;
                char* f;
                if (s != NULL && (f = strstr(s, "(Internal)")) != NULL) // contains (Internal)
                {
                    if (strlen(f) == 10)
                        strcpy(f, "(Plugin)"); // (Internal) is at the end of the string
                }
            }
        }
    case 10: // 1.6b6 - due to renaming "XXX (Internal)" to "XXX (Plugin)" in the Pack and Unpack dialogs
             //         and due to setting the ANSI version of "list of files" for (un)packers ACE32 and PKZIP25
    case 11: // 1.6b7 - added CheckVer plugin - ensure its automatic installation
    case 12: // 2.0 - auto-disable salopen.exe + added PEViewer plugin - ensure its automatic installation
    {
        // LHA gained "-m", we must add it and if archivers-auto-config added LHA a second time
        // because "-m" did not match, remove that new entry
        const char* newLHACopyArgs = "a -m -p -a -l1 -x1 -c $(ArchiveDOSFullName) @$(ListDOSFullName)";
        const char* newLHAMoveArgs = "m -m -p -a -l1 -x1 -c $(ArchiveDOSFullName) @$(ListDOSFullName)";
        BOOL canDelLHA = FALSE;
        for (index = 0; index < GetPackersCount(); index++)
        {
            if ((GetPackerOldType(index) && GetPackerType(index) == 1) ||
                (!GetPackerOldType(index) && GetPackerType(index) == CUSTOMPACKER_EXTERNAL))
            {
                const char* copyEXE = GetPackerCmdExecCopy(index);
                const char* copyArgs = GetPackerCmdArgsCopy(index);
                const char* moveEXE = GetPackerCmdExecMove(index);
                const char* moveArgs = GetPackerCmdArgsMove(index);

                // check whether this is an LHA custom packer
                if (copyEXE != NULL && strcmp(copyEXE, "$(Lha16bitExecutable)") == 0 &&
                    moveEXE != NULL && strcmp(moveEXE, "$(Lha16bitExecutable)") == 0)
                {
                    // test whether this is an old LHA custom packer entry
                    if (copyArgs != NULL &&
                        strcmp(copyArgs, "a -p -a -l1 -x1 -c $(ArchiveDOSFullName) @$(ListDOSFullName)") == 0 &&
                        moveArgs != NULL &&
                        strcmp(moveArgs, "m -p -a -l1 -x1 -c $(ArchiveDOSFullName) @$(ListDOSFullName)") == 0)
                    {
                        if (canDelLHA)
                        {
                            // delete the entry, it is unnecessary (a working LHA entry already exists)
                            DeletePacker(index);
                            index--;
                        }
                        else
                        {
                            canDelLHA = TRUE;
                            // convert to new arguments (added "-m")
                            char* s = DupStr(newLHACopyArgs);
                            if (s != NULL)
                            {
                                free(Packers[index]->CmdArgsCopy); // cannot be NULL (old arguments here)
                                Packers[index]->CmdArgsCopy = s;
                            }
                            s = DupStr(newLHAMoveArgs);
                            if (s != NULL)
                            {
                                free(Packers[index]->CmdArgsMove); // cannot be NULL (old arguments here)
                                Packers[index]->CmdArgsMove = s;
                            }
                        }
                    }
                    else
                    {
                        // test whether this is an entry added by archivers-auto-config for the LHA custom packer
                        if (copyArgs != NULL && strcmp(copyArgs, newLHACopyArgs) == 0 &&
                            moveArgs != NULL && strcmp(moveArgs, newLHAMoveArgs) == 0)
                        {
                            if (canDelLHA)
                            {
                                // delete the added entry, it is unnecessary (a working LHA entry already exists)
                                DeletePacker(index);
                                index--;
                            }
                            else
                                canDelLHA = TRUE;
                        }
                    }
                }
            }
        }
    }
    case 13: // 2.5b1 - added missing configuration conversion for custom packer - reflecting LHA change
    case 14: // 2.5b1 - New Advanced Options in the Find dialog. Switched to CFilterCriteria. Conversion of inverse mask in filters.
    case 15: // 2.5b2 - newer version to ensure plugins are loaded (upgrade registry entries)
    case 16: // 2.5b2 - added coloring of encrypted files and folders (added when loading config and in default config)
    case 17: // 2.5b2 - added *.xml mask to internal viewer settings - "force text mode"
    case 18: // 2.5b3 - for now, only for transferring plugin configuration from version 2.5b2
    case 19: // 2.5b4 - for now, only for transferring plugin configuration from version 2.5b3
    case 20: // 2.5b5 - for now, only for transferring plugin configuration from version 2.5b4
    case 21: // 2.5b6 - for now, only for transferring plugin configuration from version 2.5b5(a)
    case 22: // 2.5b6 - filters in panels -- unified into a single history
    case 23: // 2.5b6 - new panel view (Tiles)
    case 24: // 2.5b7 - for now, only for transferring plugin configuration from version 2.5b6
    case 25: // 2.5b7 - plugins: show in plugin bar -> variable moved into CPluginData
    case 26: // 2.5b8 - for now, only for transferring plugin configuration from version 2.5b7
    case 27: // 2.5b9 - for now, only for transferring plugin configuration from version 2.5b8
    case 28: // 2.5b9 - new color scheme based on the old DOS Navigator -> convert 'scheme'
    case 29: // 2.5b10 - for now, only for transferring plugin configuration from version 2.5b9
    case 30: // 2.5b11 - for now, only for transferring plugin configuration from version 2.5b10
    case 31: // 2.5b11 - introduced a Floppy section in the Drives configuration and need to force icon reading for Removable
    case 32: // 2.5b11 - Find: "Local Settings\Temporary Internet Files" is searched implicitly
    case 33: // 2.5b12 - for now, only for transferring plugin configuration from version 2.5b11
    {
        // PKZIP25 gained "-nozipextension", we must add it
        const char* newPKZIP25CopyArgs = "-add -nozipextension -path -attr \"$(ArchiveFullName)\" @\"$(ListFullName)\"";
        const char* newPKZIP25MoveArgs = "-add -nozipextension -move -path -attr \"$(ArchiveFullName)\" @\"$(ListFullName)\"";
        for (index = 0; index < GetPackersCount(); index++)
        {
            if ((GetPackerOldType(index) && GetPackerType(index) == 1) ||
                (!GetPackerOldType(index) && GetPackerType(index) == CUSTOMPACKER_EXTERNAL))
            {
                const char* copyEXE = GetPackerCmdExecCopy(index);
                const char* copyArgs = GetPackerCmdArgsCopy(index);
                const char* moveEXE = GetPackerCmdExecMove(index);
                const char* moveArgs = GetPackerCmdArgsMove(index);

                // check whether this is a PKZIP25 custom packer
                if (copyEXE != NULL && strcmp(copyEXE, "$(Zip32bitExecutable)") == 0 &&
                    moveEXE != NULL && strcmp(moveEXE, "$(Zip32bitExecutable)") == 0)
                {
                    // test whether this is an old PKZIP25 custom packer entry
                    if (copyArgs != NULL &&
                        strcmp(copyArgs, "-add -path -attr \"$(ArchiveFullName)\" @\"$(ListFullName)\"") == 0 &&
                        moveArgs != NULL &&
                        strcmp(moveArgs, "-add -move -path -attr \"$(ArchiveFullName)\" @\"$(ListFullName)\"") == 0)
                    {
                        // convert to new arguments (added "-nozipextension")
                        char* s = DupStr(newPKZIP25CopyArgs);
                        if (s != NULL)
                        {
                            free(Packers[index]->CmdArgsCopy); // cannot be NULL (old arguments here)
                            Packers[index]->CmdArgsCopy = s;
                        }
                        s = DupStr(newPKZIP25MoveArgs);
                        if (s != NULL)
                        {
                            free(Packers[index]->CmdArgsMove); // cannot be NULL (old arguments here)
                            Packers[index]->CmdArgsMove = s;
                        }
                    }
                }
            }
        }
    }
        // case 34:   // 2.5b12 - adjustment of the external PKZIP25 packer/unpacker (external Win32 version)

    default:
        break;
    }
    if (SalamVersion > 1 && SalamVersion < 81)
    {
        // since RAR 5.0 filelists are ANSI by default instead of OEM, so we must force OEM with a switch
        const char* newRAR5CopyArgs = "a -scol \"$(ArchiveFullName)\" @\"$(ListFullName)\"";
        const char* newRAR5MoveArgs = "m -scol \"$(ArchiveFullName)\" @\"$(ListFullName)\"";
        const char* newRAR5CopyVolArgs = "a -scol -v1440 \"$(ArchiveFullName)\" @\"$(ListFullName)\"";
        const char* newRAR5MoveVolArgs = "m -scol -v1440 \"$(ArchiveFullName)\" @\"$(ListFullName)\"";
        for (index = 0; index < GetPackersCount(); index++)
        {
            if ((GetPackerOldType(index) && GetPackerType(index) == 1) ||
                (!GetPackerOldType(index) && GetPackerType(index) == CUSTOMPACKER_EXTERNAL))
            {
                const char* copyEXE = GetPackerCmdExecCopy(index);
                const char* copyArgs = GetPackerCmdArgsCopy(index);
                const char* moveEXE = GetPackerCmdExecMove(index);
                const char* moveArgs = GetPackerCmdArgsMove(index);

                // check whether this is a RAR Win32 custom packer
                if (copyEXE != NULL && strcmp(copyEXE, "$(Rar32bitExecutable)") == 0 &&
                    moveEXE != NULL && strcmp(moveEXE, "$(Rar32bitExecutable)") == 0)
                {
                    // test whether this is an old RAR Win32 custom packer entry
                    if (copyArgs != NULL &&
                        strcmp(copyArgs, "a \"$(ArchiveFullName)\" @\"$(ListFullName)\"") == 0 &&
                        moveArgs != NULL &&
                        strcmp(moveArgs, "m \"$(ArchiveFullName)\" @\"$(ListFullName)\"") == 0)
                    {
                        // convert to new arguments (added "-scol")
                        free(Packers[index]->CmdArgsCopy); // cannot be NULL (old arguments here)
                        Packers[index]->CmdArgsCopy = DupStr(newRAR5CopyArgs);
                        free(Packers[index]->CmdArgsMove); // cannot be NULL (old arguments here)
                        Packers[index]->CmdArgsMove = DupStr(newRAR5MoveArgs);
                    }
                    if (copyArgs != NULL &&
                        strcmp(copyArgs, "a -v1440 \"$(ArchiveFullName)\" @\"$(ListFullName)\"") == 0 &&
                        moveArgs != NULL &&
                        strcmp(moveArgs, "m -v1440 \"$(ArchiveFullName)\" @\"$(ListFullName)\"") == 0)
                    {
                        // convert to new arguments (added "-scol")
                        free(Packers[index]->CmdArgsCopy); // cannot be NULL (old arguments here)
                        Packers[index]->CmdArgsCopy = DupStr(newRAR5CopyVolArgs);
                        free(Packers[index]->CmdArgsMove); // cannot be NULL (old arguments here)
                        Packers[index]->CmdArgsMove = DupStr(newRAR5MoveVolArgs);
                    }
                }
            }
        }
    }
}

BOOL CPackerConfig::Load(CPackerConfig& src)
{
    CALL_STACK_MESSAGE1("CPackerConfig::Load()");
    Move = src.Move;
    PreferedPacker = src.PreferedPacker;

    DeleteAllPackers();
    int i;
    for (i = 0; i < src.GetPackersCount(); i++)
    {
        int index = AddPacker();
        if (index == -1)
            return FALSE;
        if (!SetPacker(index, src.GetPackerType(i), src.GetPackerTitle(i), src.GetPackerExt(i), FALSE,
                       src.GetPackerSupLongNames(i), src.GetPackerSupMove(i),
                       src.GetPackerCmdExecCopy(i), src.GetPackerCmdArgsCopy(i),
                       src.GetPackerCmdExecMove(i), src.GetPackerCmdArgsMove(i),
                       src.GetPackerNeedANSIListFile(i)))
            return FALSE;
    }
    return TRUE;
}

int CPackerConfig::AddPacker(BOOL toFirstIndex)
{
    CALL_STACK_MESSAGE2("CPackerConfig::AddPacker(%d)", toFirstIndex);
    CPackerConfigData* data = new CPackerConfigData;
    if (data == NULL)
        return -1;
    int index;
    if (toFirstIndex)
    {
        Packers.Insert(0, data);
        index = 0;
        if (PreferedPacker != -1)
            PreferedPacker++;
    }
    else
        index = Packers.Add(data);
    if (!Packers.IsGood())
    {
        delete data;
        Packers.ResetState();
        return -1;
    }
    return index;
}

/*
BOOL
CPackerConfig::SwapPackers(int index1, int index2)
{
  BYTE buff[sizeof(CPackerConfigData)];
  memcpy(buff, Packers[index1], sizeof(CPackerConfigData));
  memcpy(Packers[index1], Packers[index2], sizeof(CPackerConfigData));
  memcpy(Packers[index2], buff, sizeof(CPackerConfigData));
  return TRUE;
}
*/

BOOL CPackerConfig::MovePacker(int srcIndex, int dstIndex)
{
    BYTE buff[sizeof(CPackerConfigData)];
    memcpy(buff, Packers[srcIndex], sizeof(CPackerConfigData));
    if (srcIndex < dstIndex)
    {
        int i;
        for (i = srcIndex; i < dstIndex; i++)
            memcpy(Packers[i], Packers[i + 1], sizeof(CPackerConfigData));
    }
    else
    {
        int i;
        for (i = srcIndex; i > dstIndex; i--)
            memcpy(Packers[i], Packers[i - 1], sizeof(CPackerConfigData));
    }
    memcpy(Packers[dstIndex], buff, sizeof(CPackerConfigData));
    return TRUE;
}

void CPackerConfig::DeletePacker(int index)
{
    if (PreferedPacker >= 0 && PreferedPacker < Packers.Count)
    {
        if (index < PreferedPacker)
            PreferedPacker--; // adjust index to represent the same item
        else
        {
            if (index == PreferedPacker)
                PreferedPacker = -1; // we lost the selected item
        }
    }
    Packers.Delete(index);
}

BOOL CPackerConfig::SetPacker(int index, int type, const char* title, const char* ext, BOOL old,
                              BOOL supportLongNames, BOOL supportMove,
                              const char* cmdExecCopy, const char* cmdArgsCopy,
                              const char* cmdExecMove, const char* cmdArgsMove,
                              BOOL needANSIListFile)
{
    CALL_STACK_MESSAGE13("CPackerConfig::SetPacker(%d, %d, %s, %s, %d, %d, %d, %s, %s, %s, %s, %d)",
                         index, type, title, ext, old, supportLongNames, supportMove,
                         cmdExecCopy, cmdArgsCopy, cmdExecMove, cmdArgsMove, needANSIListFile);
    CPackerConfigData* data = Packers[index];
    data->Destroy();
    data->Type = type;
    data->OldType = old;
    // feature 069 (F-P4-03): 'Title' is UTF-8.  Its consumers already are -
    // the archiver combos use SalComboAddStringU8 (dialogs3.cpp) and the
    // Options list edits it through SalSetWindowTextU8/SalGetWindowTextU8
    // (edtlbwnd.cpp) - so a user-edited title was stored as UTF-8 while a
    // seeded one carried the bytes of the ANSI LoadStr: on a Hungarian UI over
    // a Western code page the seed lost the characters the ACP cannot express
    // ("kulso" for "kulso" with the double acute) and persisted the loss.
    data->Title = DupStr(title);
    data->Ext = DupStr(ext);
    if (old && data->Type == 1 ||
        !old && data->Type == CUSTOMPACKER_EXTERNAL)
    {
        data->CmdExecCopy = DupStr(cmdExecCopy);
        data->CmdArgsCopy = DupStr(cmdArgsCopy);
        data->SupportMove = supportMove;

        if (data->SupportMove)
        {
            data->CmdExecMove = DupStr(cmdExecMove);
            data->CmdArgsMove = DupStr(cmdArgsMove);
        }
        data->SupportLongNames = supportLongNames;
        data->NeedANSIListFile = needANSIListFile;
    }

    if (data->IsValid())
    {
        if (PreferedPacker == -1)
            PreferedPacker = Packers.Count - 1;
        return TRUE;
    }
    else
    {
        Packers.Delete(index);
        return FALSE;
    }
}

BOOL CPackerConfig::SetPackerTitle(int index, const char* title)
{
    CPackerConfigData* data = Packers[index];
    if (data->Title != NULL)
        free(data->Title);
    data->Title = DupStr(title);
    return data->Title != NULL;
}

//
// ****************************************************************************
// Configuration version 106 (feature 084, contract
// specs/084-archiver-cleanup/contracts/config-migration-106.md)
//
// Runs once, on a configuration stored by a version older than 106, after the
// four "Packers & Unpackers" sections were loaded and before CPlugins::CheckData.
// The decisions are pure (src/common/salarcmig.*, covered by saltests).

// the extensions the 7-Zip console takes over when no record claims them (M3),
// one association record per group - the same groups the defaults have
static const char* const SevenZipDefaultExtGroups[] = {"arj", "lzh;lha"};

void PackMigrateArchiversTo106()
{
    CALL_STACK_MESSAGE1("PackMigrateArchiversTo106()");
    int i;

    // M1: custom packers - entries calling a removed archiver or creating floppy
    // volumes go; the untouched 0.1.8 RAR default becomes the new RAR default
    for (i = PackerConfig.GetPackersCount() - 1; i >= 0; i--)
    {
        switch (SalArcMigPacker(PackerConfig.GetPackerType(i) == CUSTOMPACKER_EXTERNAL,
                                PackerConfig.GetPackerCmdExecCopy(i), PackerConfig.GetPackerCmdArgsCopy(i),
                                PackerConfig.GetPackerCmdExecMove(i), PackerConfig.GetPackerCmdArgsMove(i)))
        {
        case sameDelete:
            TRACE_I("Archivers 106: removing custom packer " << PackerConfig.GetPackerTitle(i));
            PackerConfig.DeletePacker(i);
            break;

        case sameRarDefault:
        {
            TRACE_I("Archivers 106: updating the default RAR packer " << PackerConfig.GetPackerTitle(i));
            const SPackCustomPacker* rar = &CustomPackers[PACKRARINDEX];
            char variable[100];
            _snprintf_s(variable, _TRUNCATE, "$(%s)", ArchiverConfig.GetPackerVariable(PACKRARINDEX));
            PackerConfig.SetPacker(i, CUSTOMPACKER_EXTERNAL, LoadStrU8(rar->Title[0]), rar->Ext, FALSE,
                                   rar->SupLN, TRUE, variable, rar->CopyArgs[0], variable, rar->MoveArgs[0],
                                   rar->Ansi);
            break;
        }

        default:
            break;
        }
    }

    // M1: custom unpackers
    BOOL has7Zip = FALSE;
    char sevenZipVariable[100];
    _snprintf_s(sevenZipVariable, _TRUNCATE, "$(%s)", ArchiverConfig.GetPackerVariable(PACK7ZIPINDEX));
    for (i = UnpackerConfig.GetUnpackersCount() - 1; i >= 0; i--)
    {
        if (SalArcMigUnpacker(UnpackerConfig.GetUnpackerType(i) == CUSTOMUNPACKER_EXTERNAL,
                              UnpackerConfig.GetUnpackerCmdExecExtract(i),
                              UnpackerConfig.GetUnpackerCmdArgsExtract(i)) == sameDelete)
        {
            TRACE_I("Archivers 106: removing custom unpacker " << UnpackerConfig.GetUnpackerTitle(i));
            UnpackerConfig.DeleteUnpacker(i);
        }
        else
        {
            const char* cmd = UnpackerConfig.GetUnpackerCmdExecExtract(i);
            if (UnpackerConfig.GetUnpackerType(i) == CUSTOMUNPACKER_EXTERNAL && cmd != NULL &&
                StrICmp(cmd, sevenZipVariable) == 0)
            {
                has7Zip = TRUE;
            }
        }
    }
    // the new 7-Zip default unpacker (an upgraded configuration has none)
    if (!has7Zip)
    {
        const SPackCustomUnpacker* sz = &CustomUnpackers[PACK7ZIPINDEX];
        int index = UnpackerConfig.AddUnpacker();
        if (index != -1)
        {
            UnpackerConfig.SetUnpacker(index, CUSTOMUNPACKER_EXTERNAL, LoadStrU8(sz->Title), sz->Ext, FALSE,
                                       sz->SupLN, sevenZipVariable, sz->Args, sz->Ansi);
        }
    }

    // M2: associations - a removed archiver as the viewer deletes the record, as the
    // packer it switches packing off; plug-ins and RAR (index 1) stay
    for (i = PackerFormatConfig.GetFormatsCount() - 1; i >= 0; i--)
    {
        int unpacker, packer;
        BOOL usePacker;
        if (!SalArcMigAssociation(PackerFormatConfig.GetUnpackerIndex(i), PackerFormatConfig.GetPackerIndex(i),
                                  PackerFormatConfig.GetUsePacker(i), &unpacker, &packer, &usePacker))
        {
            TRACE_I("Archivers 106: removing association " << PackerFormatConfig.GetExt(i));
            PackerFormatConfig.DeleteFormat(i);
            continue;
        }
        PackerFormatConfig.SetUnpackerIndex(i, unpacker);
        PackerFormatConfig.SetUsePacker(i, usePacker);
        if (usePacker)
            PackerFormatConfig.SetPackerIndex(i, packer);
    }

    // M3: the 7-Zip console takes the extensions nobody claims
    int g;
    for (g = 0; g < _countof(SevenZipDefaultExtGroups); g++)
    {
        char missing[100];
        missing[0] = 0;
        char group[100];
        lstrcpyn(group, SevenZipDefaultExtGroups[g], _countof(group));
        char* next = NULL;
        char* ext = strtok_s(group, ";", &next);
        while (ext != NULL)
        {
            BOOL claimed = FALSE;
            for (i = 0; !claimed && i < PackerFormatConfig.GetFormatsCount(); i++)
                claimed = SalArcMigListHasExt(PackerFormatConfig.GetExt(i), ext);
            if (!claimed)
            {
                if (missing[0] != 0)
                    strcat_s(missing, ";");
                strcat_s(missing, ext);
            }
            ext = strtok_s(NULL, ";", &next);
        }
        if (missing[0] != 0)
        {
            TRACE_I("Archivers 106: adding association " << missing << " for 7-Zip");
            int index = PackerFormatConfig.AddFormat();
            if (index != -1)
                PackerFormatConfig.SetFormat(index, missing, FALSE, -1, PACK7ZIPINDEX, FALSE);
        }
    }
}

// feature 084 (FR-017): the index of the supported external archiver a command
// calls - exactly "$(SevenZipExecutable)" or "$(Rar32bitExecutable)", as the
// default entries and Archivers Autoconfiguration write it - or -1 (a plug-in,
// a program given by its own path, anything else)
static int PackCommandArchiverIndex(const char* cmd)
{
    if (cmd == NULL)
        return -1;
    int i;
    for (i = 0; i < ArchiverConfig.GetArchiversCount(); i++)
    {
        char variable[100];
        _snprintf_s(variable, _TRUNCATE, "$(%s)", ArchiverConfig.GetPackerVariable(i));
        if (StrICmp(cmd, variable) == 0)
            return i;
    }
    return -1;
}

BOOL CPackerConfig::IsPackerOffered(int index)
{
    if (index < 0 || index >= GetPackersCount() || GetPackerType(index) != CUSTOMPACKER_EXTERNAL)
        return index >= 0 && index < GetPackersCount();
    int archiver = PackCommandArchiverIndex(GetPackerCmdExecCopy(index));
    return archiver < 0 || ArchiverConfig.IsArchiverAvailable(archiver);
}

int CPackerConfig::GetOfferedPreferedPacker()
{
    int pref = GetPreferedPacker();
    if (pref >= 0 && IsPackerOffered(pref))
        return pref;
    int i;
    for (i = 0; i < GetPackersCount(); i++)
    {
        if (IsPackerOffered(i))
            return i;
    }
    return -1;
}

BOOL CUnpackerConfig::IsUnpackerOffered(int index)
{
    if (index < 0 || index >= GetUnpackersCount() || GetUnpackerType(index) != CUSTOMUNPACKER_EXTERNAL)
        return index >= 0 && index < GetUnpackersCount();
    int archiver = PackCommandArchiverIndex(GetUnpackerCmdExecExtract(index));
    return archiver < 0 || ArchiverConfig.IsArchiverAvailable(archiver);
}

int CUnpackerConfig::GetOfferedPreferedUnpacker()
{
    int pref = GetPreferedUnpacker();
    if (pref >= 0 && IsUnpackerOffered(pref))
        return pref;
    int i;
    for (i = 0; i < GetUnpackersCount(); i++)
    {
        if (IsUnpackerOffered(i))
            return i;
    }
    return -1;
}

BOOL CPackerConfig::ExecutePacker(CFilesWindow* panel, const char* zipFile, BOOL move,
                                  const char* sourcePath, SalEnumSelection2 next, void* param)
{
    CALL_STACK_MESSAGE4("CPackerConfig::ExecutePacker(, %s, %d, %s, , ,)",
                        zipFile, move, sourcePath);
    if (PreferedPacker >= 0 && PreferedPacker < Packers.Count)
    {
        CPackerConfigData* data = Packers[PreferedPacker];
        if (data->Type == CUSTOMPACKER_EXTERNAL)
        {
            char* command;
            if (move)
            {
                if (!data->SupportMove)
                {
                    TRACE_E("Using \"Move to archive\" with packer, which does not support it !!!");
                    return FALSE;
                }
                command = (char*)malloc(strlen(data->CmdExecMove) +
                                        strlen(data->CmdArgsMove) + 2);
                if (command == NULL)
                {
                    TRACE_E(LOW_MEMORY);
                    return FALSE;
                }
                sprintf(command, "%s %s", data->CmdExecMove, data->CmdArgsMove);
            }
            else
            {
                command = (char*)malloc(strlen(data->CmdExecCopy) +
                                        strlen(data->CmdArgsCopy) + 2);
                if (command == NULL)
                {
                    TRACE_E(LOW_MEMORY);
                    return FALSE;
                }
                sprintf(command, "%s %s", data->CmdExecCopy, data->CmdArgsCopy);
            }
            BOOL ret = PackUniversalCompress(NULL, command, NULL, sourcePath, FALSE,
                                             data->SupportLongNames, zipFile, sourcePath, NULL,
                                             next, param, data->NeedANSIListFile);
            free(command);
            return ret;
        }
        else
        {
            CPluginData* plugin = Plugins.Get(-data->Type - 1);
            if (plugin != NULL && plugin->SupportCustomPack)
            {
                return plugin->PackToArchive(panel, zipFile, "", move, sourcePath, next, param);
            }
            else
                TRACE_E("Unexpected situation in CPackerConfig::ExecutePacker().");
        }
    }
    return FALSE;
}

BOOL CPackerConfig::Save(int index, HKEY hKey)
{
    DWORD d;
    BOOL ret = TRUE;
    int type = GetPackerType(index);
    d = type;
    if (ret)
        ret &= SetValue(hKey, SALAMANDER_CPU_TYPE, REG_DWORD, &d, sizeof(d));
    if (ret)
        ret &= SetValue(hKey, SALAMANDER_CPU_TITLE, REG_SZ, GetPackerTitle(index), -1);
    if (ret)
        ret &= SetValue(hKey, SALAMANDER_CPU_EXT, REG_SZ, GetPackerExt(index), -1);
    if (ret && type == CUSTOMPACKER_EXTERNAL)
    {
        d = GetPackerSupLongNames(index);
        if (ret)
            ret &= SetValue(hKey, SALAMANDER_CPU_SUPLONG, REG_DWORD, &d, sizeof(d));
        d = GetPackerNeedANSIListFile(index);
        if (ret)
            ret &= SetValue(hKey, SALAMANDER_CPU_ANSILIST, REG_DWORD, &d, sizeof(d));
        if (ret)
            ret &= SetValue(hKey, SALAMANDER_CP_EXECCOPY, REG_SZ, GetPackerCmdExecCopy(index), -1);
        if (ret)
            ret &= SetValue(hKey, SALAMANDER_CP_ARGSCOPY, REG_SZ, GetPackerCmdArgsCopy(index), -1);
        d = GetPackerSupMove(index);
        if (ret)
            ret &= SetValue(hKey, SALAMANDER_CP_SUPMOVE, REG_DWORD, &d, sizeof(d));
        if (ret && d == TRUE)
        {
            if (ret)
                ret &= SetValue(hKey, SALAMANDER_CP_EXECMOVE, REG_SZ, GetPackerCmdExecMove(index), -1);
            if (ret)
                ret &= SetValue(hKey, SALAMANDER_CP_ARGSMOVE, REG_SZ, GetPackerCmdArgsMove(index), -1);
        }
    }
    return ret;
}

BOOL CPackerConfig::Load(HKEY hKey)
{
    int max = MAX_PATH + 2;

    char title[MAX_PATH + 2];
    title[0] = 0;
    char ext[MAX_PATH + 2];
    DWORD type;
    DWORD suplong = FALSE;
    DWORD needANSI = FALSE;
    char execcopy[MAX_PATH + 2];
    execcopy[0] = 0;
    char argscopy[MAX_PATH + 2];
    argscopy[0] = 0;
    DWORD supmove = FALSE;
    char execmove[MAX_PATH + 2];
    execmove[0] = 0;
    char argsmove[MAX_PATH + 2];
    argsmove[0] = 0;

    BOOL ret = TRUE;
    if (ret)
        ret &= GetValue(hKey, SALAMANDER_CPU_TYPE, REG_DWORD, &type, sizeof(DWORD));
    if (ret)
        ret &= GetValue(hKey, SALAMANDER_CPU_TITLE, REG_SZ, title, max);
    if (ret)
        ret &= GetValue(hKey, SALAMANDER_CPU_EXT, REG_SZ, ext, max);
    if (ret && (Configuration.ConfigVersion < 6 && type == 1 ||
                Configuration.ConfigVersion >= 6 && type == CUSTOMPACKER_EXTERNAL))
    {
        if (ret)
            ret &= GetValue(hKey, SALAMANDER_CPU_SUPLONG, REG_DWORD, &suplong, sizeof(DWORD));
        if (ret)
        {
            if (!GetValue(hKey, SALAMANDER_CPU_ANSILIST, REG_DWORD, &needANSI, sizeof(DWORD)))
                needANSI = FALSE; // in older versions it wasn't present, assumed FALSE
        }

        if (ret)
            ret &= GetValue(hKey, SALAMANDER_CP_EXECCOPY, REG_SZ, execcopy, max);
        if (ret)
            ret &= GetValue(hKey, SALAMANDER_CP_ARGSCOPY, REG_SZ, argscopy, max);
        if (ret)
            ret &= GetValue(hKey, SALAMANDER_CP_SUPMOVE, REG_DWORD, &supmove, sizeof(DWORD));
        if (ret && supmove == TRUE)
        {
            if (ret)
                ret &= GetValue(hKey, SALAMANDER_CP_EXECMOVE, REG_SZ, execmove, max);
            if (ret)
                ret &= GetValue(hKey, SALAMANDER_CP_ARGSMOVE, REG_SZ, argsmove, max);
        }
    }

    if (ret)
    {
        int index;
        if ((index = AddPacker()) == -1)
            return FALSE;
        if (Configuration.ConfigVersion < 44) // convert extension to lowercase
        {
            char extAux[MAX_PATH + 2];
            lstrcpyn(extAux, ext, MAX_PATH + 2);
            StrICpy(ext, extAux);
        }
        ret &= SetPacker(index, (int)type, title, ext, Configuration.ConfigVersion < 6,
                         (BOOL)suplong, BOOL(supmove),
                         execcopy, argscopy,
                         execmove, argsmove, needANSI);
    }

    return ret;
}

//
// ****************************************************************************
// CUnpackerConfig
//

CUnpackerConfig::CUnpackerConfig(/*BOOL disableDefaultValues*/)
    : Unpackers(20, 10)
{
    PreferedUnpacker = -1;
    /*
  if (!disableDefaultValues)
    AddDefault(0);
*/
}

void CUnpackerConfig::InitializeDefaultValues()
{
    AddDefault(0);
}

void CUnpackerConfig::AddDefault(int SalamVersion)
{
    // WARNING: up to version 6 the old 'Type' values were: 0 ZIP, 1 external, 2 TAR, 3 PAK

    // convert loaded values from 1.6b1 - extensions were not masks ("EXT" -> "*.EXT")
    if (SalamVersion == 2)
    {
        int i;
        for (i = 0; i < Unpackers.Count; i++)
        {
            int count = 1;
            char* ptr = Unpackers[i]->Ext;
            if (ptr == NULL || *ptr == '\0')
                continue;
            while (*ptr != '\0')
            {
                if (*ptr++ == ';')
                    count++;
            }
            char* nptr = (char*)malloc(strlen(Unpackers[i]->Ext) + count * 2 + 1);
            ptr = Unpackers[i]->Ext;
            int pos = 0;
            nptr[pos++] = '*';
            nptr[pos++] = '.';
            while (*ptr != '\0')
            {
                nptr[pos++] = *ptr;
                if (*ptr++ == ';')
                {
                    nptr[pos++] = '*';
                    nptr[pos++] = '.';
                }
            }
            nptr[pos] = '\0';
            free(Unpackers[i]->Ext);
            Unpackers[i]->Ext = nptr;
        }
    }

    // default values
    int index, i;
    // internal ones first to keep it sorted
    switch (SalamVersion)
    {
    case 0: // default config
    case 1: // v1.52 had no packers
        if ((index = AddUnpacker()) == -1)
            return;
        SetUnpacker(index, 0, "ZIP (Plugin)", "*.zip", TRUE);
    case 2: // added after beta1
        // hack to add the pk3 extension to zip
        for (i = 0; i < Unpackers.Count; i++)
            if (!strnicmp(Unpackers[i]->Ext, "*.zip", 5))
            {
                char* ptr = (char*)malloc(strlen(Unpackers[i]->Ext) + 13);
                if (ptr != NULL)
                {
                    strcpy(ptr, Unpackers[i]->Ext);
                    strcat(ptr, ";*.pk3;*.jar");
                    free(Unpackers[i]->Ext);
                    Unpackers[i]->Ext = ptr;
                }
                break;
            }
        // (the "PAK (Plugin)" unpacker was removed with the PAK plugin, feature 007)
    case 3: // what was added after beta2
    case 4: // beta 3 but without the $(SpawnName) variable
    case 5: // what is new in beta4?
        if ((index = AddUnpacker()) == -1)
            return;
        SetUnpacker(index, 2, "TAR (Plugin)", "*.TAR;*.TGZ;*.TBZ;*.TAZ;"
                                              "*.TAR.GZ;*.TAR.BZ;*.TAR.BZ2;*.TAR.Z;"
                                              "*_TAR.GZ;*_TAR.BZ;*_TAR.BZ2;*_TAR.Z;"
                                              "*_TAR_GZ;*_TAR_BZ;*_TAR_BZ2;*_TAR_Z;"
                                              "*.TAR_GZ;*.TAR_BZ;*.TAR_BZ2;*.TAR_Z;"
                                              "*.GZ;*.BZ;*.BZ2;*.Z;"
                                              "*.RPM;*.CPIO",
                    TRUE);
    }
    // now external
    switch (SalamVersion)
    {
        // parameters
        //BOOL SetUnpacker(int index, int type, const char *title, const char *ext, BOOL old,
        //                 BOOL supportLongNames = FALSE,
        //                 const char *cmdExecExtract = NULL, const char *cmdArgsExtract = NULL,
        //                 BOOL needANSIListFile = FALSE);

    case 0: // default config
    case 1: // v1.52 had no packers
        // feature 084: the default unpackers of the supported external archivers
        // (CustomUnpackers is indexed by the archiver index; RAR has no unpacker)
        for (i = 0; i < PACK_ARCHIVERS_COUNT; i++)
        {
            if (CustomUnpackers[i].Args == NULL)
                continue;
            if ((index = AddUnpacker()) == -1)
                return;
            SetUnpacker(index, 1, LoadStrU8(CustomUnpackers[i].Title), CustomUnpackers[i].Ext, TRUE,
                        CustomUnpackers[i].SupLN, CustomUnpackers[i].Exe,
                        CustomUnpackers[i].Args, CustomUnpackers[i].Ansi);
        }
    case 2: // what was added after beta1 (the remaining 1990s archivers, removed in feature 084)
    case 3: // what was added after beta2
    case 4: // beta 3 but without the $(SpawnName) variable
        // in older versions the $(SpawnName) variable might exist, it no longer does - we must remove it
        for (index = 0; index < GetUnpackersCount(); index++)
            if (GetUnpackerType(index) == 1)
            {
                const char* cmd = GetUnpackerCmdExecExtract(index);
                if (strncmp(cmd, "$(SpawnName) ", 13) == 0)
                {
                    char* extractCmdBuf = (char*)malloc(strlen(cmd) + 1 - 13);
                    strcpy(extractCmdBuf, cmd + 13);
                    char* extractArgBuf = (char*)malloc(strlen(GetUnpackerCmdArgsExtract(index)) + 1);
                    strcpy(extractArgBuf, GetUnpackerCmdArgsExtract(index));
                    char* TitleBuf = (char*)malloc(strlen(GetUnpackerTitle(index)) + 1);
                    strcpy(TitleBuf, GetUnpackerTitle(index));
                    char* ExtBuf = (char*)malloc(strlen(GetUnpackerExt(index)) + 1);
                    strcpy(ExtBuf, GetUnpackerExt(index));

                    SetUnpacker(index, GetUnpackerType(index), TitleBuf, ExtBuf, TRUE,
                                GetUnpackerSupLongNames(index), extractCmdBuf, extractArgBuf,
                                GetUnpackerNeedANSIListFile(index));
                    free(extractCmdBuf);
                    free(extractArgBuf);
                    free(TitleBuf);
                    free(ExtBuf);
                }
            }
    case 5: // beta 3 but without tar
    case 6: // what is new in beta4?
    case 7: // 1.6b6 - for correct conversion of supported plugin functions (see CPlugins::Load)
    case 8:
        // transition to using variables instead of the direct exe file name
        for (index = 0; index < GetUnpackersCount(); index++)
            // consider only external packers
            if (((GetUnpackerOldType(index) && GetUnpackerType(index) == 1) ||
                 (!GetUnpackerOldType(index) && GetUnpackerType(index) == CUSTOMUNPACKER_EXTERNAL)) &&
                GetUnpackerCmdExecExtract(index) != NULL)
            {
                // take the old commands
                char* cmd = DupStr(GetUnpackerCmdExecExtract(index));
                i = 0;
                BOOL found = FALSE;
                // and search the table with it
                while (PackConversionTable[i].exe != NULL)
                {
                    // compare with table entries
                    if (!strcmp(cmd, PackConversionTable[i].exe))
                    {
                        free(cmd);
                        // (the RAR 16-bit special case went with the DOS archivers, feature 084)
                        cmd = DupStr(PackConversionTable[i].variable);
                        found = TRUE;
                    }
                    i++;
                }
                // strings must be copied somewhere or we delete them before use
                char* title = DupStr(GetUnpackerTitle(index));
                char* ext = DupStr(GetUnpackerExt(index));
                char* args = DupStr(GetUnpackerCmdArgsExtract(index));

                if (found)
                    SetUnpacker(index, GetUnpackerType(index), title, ext, GetUnpackerOldType(index),
                                GetUnpackerSupLongNames(index), cmd, args,
                                GetUnpackerNeedANSIListFile(index));
                free(args);
                free(title);
                free(ext);
                free(cmd);
            }
    case 9: // 1.6b6 - due to switching from exe name to variable in custom packers
        // enable ANSI file list for ACE32 and PKZIP25
        for (index = 0; index < GetUnpackersCount(); index++)
        {
            if ((GetUnpackerOldType(index) && GetUnpackerType(index) == 1) ||
                (!GetUnpackerOldType(index) && GetUnpackerType(index) == CUSTOMUNPACKER_EXTERNAL))
            {
                const char* s = GetUnpackerCmdExecExtract(index);
                if (s != NULL && (strcmp(s, "$(Zip32bitExecutable)") == 0 ||
                                  strcmp(s, "$(Ace32bitExecutable)") == 0))
                {
                    Unpackers[index]->NeedANSIListFile = TRUE;
                }
            }
        }
        // change "XXX (Internal)" to "XXX (Plugin)"
        // we’re doing a brutal overwrite because we’re replacing it with a shorter text -> simple overwrite is enough
        for (index = 0; index < GetUnpackersCount(); index++)
        {
            if ((GetUnpackerOldType(index) && GetUnpackerType(index) != 1) ||
                (!GetUnpackerOldType(index) && GetUnpackerType(index) != CUSTOMUNPACKER_EXTERNAL))
            { // take only plug-ins (not external unpackers)
                char* s = Unpackers[index]->Title;
                char* f;
                if (s != NULL && (f = strstr(s, "(Internal)")) != NULL) // contains (Internal)
                {
                    if (strlen(f) == 10)
                        strcpy(f, "(Plugin)"); // (Internal) is at the end of the string
                }
            }
        }
    case 10: // 1.6b6 - due to renaming "XXX (Internal)" to "XXX (Plugin)" in the Pack and Unpack dialogs
    case 11: // 1.6b7 - added CheckVer plugin - ensure its automatic installation
    case 12: // 2.0 - auto-disable salopen.exe + added PEViewer plugin - ensure its automatic installation
    case 13: // 2.5b1 - added missing configuration conversion for custom unpacker - reflecting LHA change
    case 14: // 2.5b1 - New Advanced Options in the Find dialog. Switched to CFilterCriteria. Converted the inverse filter mask.
    case 15: // 2.5b2 - newer version so plugins load (upgrade registry entries)
    case 16: // 2.5b2 - added coloring of encrypted files and folders (added when loading config and in default config)
    case 17: // 2.5b2 - added *.xml mask to internal viewer settings - "force text mode"
    case 18: // 2.5b3 - for now, only to transfer plugin configuration from 2.5b2
    case 19: // 2.5b4 - for now, only to transfer plugin configuration from 2.5b3
    case 20: // 2.5b5 - for now, only to transfer plugin configuration from 2.5b4
    case 21: // 2.5b6 - for now, only to transfer plugin configuration from 2.5b5(a)
    case 22: // 2.5b6 - filters in panels -- unified into a single history
    case 23: // 2.5b6 - new panel view (Tiles)
    case 24: // 2.5b7 - for now, only to transfer plugin configuration from 2.5b6
    case 25: // 2.5b7 - plugins: show in plugin bar -> variable moved to CPluginData
    case 26: // 2.5b8 - for now, only to transfer plugin configuration from 2.5b7
    case 27: // 2.5b9 - for now, only to transfer plugin configuration from 2.5b8
    case 28: // 2.5b9 - new color scheme based on the old DOS Navigator -> convert 'scheme'
    case 29: // 2.5b10 - for now, only to transfer plugin configuration from 2.5b9
    case 30: // 2.5b11 - for now, only to transfer plugin configuration from 2.5b10
    case 31: // 2.5b11 - added a Floppy section in the Drives configuration and need to force icon reading for Removable drives
    case 32: // 2.5b11 - Find: "Local Settings\Temporary Internet Files" is searched implicitly
    case 33: // 2.5b12 - only to transfer plugin configuration from version 2.5b11
    {
        // PKZIP25 gained "-nozipextension -directories" and "*.pk3;*.jar", we must add it
        const char* newPKZIP25Args = "-ext -nozipextension -directories -path \"$(ArchiveFullName)\" @\"$(ListFullName)\"";
        const char* newPKZIP25Ext = "*.zip;*.pk3;*.jar";
        for (index = 0; index < GetUnpackersCount(); index++)
        {
            if ((GetUnpackerOldType(index) && GetUnpackerType(index) == 1) ||
                (!GetUnpackerOldType(index) && GetUnpackerType(index) == CUSTOMPACKER_EXTERNAL))
            {
                const char* extrEXE = GetUnpackerCmdExecExtract(index);
                const char* extrArgs = GetUnpackerCmdArgsExtract(index);
                const char* ext = GetUnpackerExt(index);

                // check whether this is a PKZIP25 custom unpacker
                if (extrEXE != NULL && strcmp(extrEXE, "$(Zip32bitExecutable)") == 0)
                {
                    // test whether this is an old PKZIP25 custom unpacker entry
                    if (extrArgs != NULL &&
                        strcmp(extrArgs, "-ext -path \"$(ArchiveFullName)\" @\"$(ListFullName)\"") == 0 &&
                        strcmp(ext, "*.zip") == 0)
                    {
                        // convert to new arguments (added "-nozipextension" + "*.pk3;*.jar")
                        char* s = DupStr(newPKZIP25Args);
                        if (s != NULL)
                        {
                            free(Unpackers[index]->CmdArgsExtract); // cannot be NULL (old arguments here)
                            Unpackers[index]->CmdArgsExtract = s;
                        }
                        s = DupStr(newPKZIP25Ext);
                        if (s != NULL)
                        {
                            free(Unpackers[index]->Ext); // cannot be NULL (old arguments here)
                            Unpackers[index]->Ext = s;
                        }
                    }
                }
            }
        }
    }
        // case 34:   // 2.5b12 - adjustment of the external PKZIP25 packer/unpacker (external Win32 version)

    default:
        break;
    }
    if (SalamVersion > 1 && SalamVersion < 81)
    {
        // since RAR 5.0 filelists are ANSI by default instead of OEM, so we must force OEM with a switch
        const char* newRAR5Args = "x -scol \"$(ArchiveFullName)\" @\"$(ListFullName)\"";
        for (index = 0; index < GetUnpackersCount(); index++)
        {
            if ((GetUnpackerOldType(index) && GetUnpackerType(index) == 1) ||
                (!GetUnpackerOldType(index) && GetUnpackerType(index) == CUSTOMPACKER_EXTERNAL))
            {
                const char* extrEXE = GetUnpackerCmdExecExtract(index);
                const char* extrArgs = GetUnpackerCmdArgsExtract(index);
                const char* ext = GetUnpackerExt(index);

                // check whether this is a RAR Win32 custom unpacker
                if (extrEXE != NULL && strcmp(extrEXE, "$(Rar32bitExecutable)") == 0)
                {
                    // test whether this is an old RAR Win32 custom unpacker entry
                    if (extrArgs != NULL &&
                        strcmp(extrArgs, "x \"$(ArchiveFullName)\" @\"$(ListFullName)\"") == 0)
                    {
                        // convert to new arguments (added "-scol")
                        free(Unpackers[index]->CmdArgsExtract); // cannot be NULL (old arguments here)
                        Unpackers[index]->CmdArgsExtract = DupStr(newRAR5Args);
                    }
                }
            }
        }
    }
}

BOOL CUnpackerConfig::Load(CUnpackerConfig& src)
{
    PreferedUnpacker = src.PreferedUnpacker;

    DeleteAllUnpackers();
    int i;
    for (i = 0; i < src.GetUnpackersCount(); i++)
    {
        int index = AddUnpacker();
        if (index == -1)
            return FALSE;
        if (!SetUnpacker(index, src.GetUnpackerType(i), src.GetUnpackerTitle(i), src.GetUnpackerExt(i),
                         FALSE, src.GetUnpackerSupLongNames(i),
                         src.GetUnpackerCmdExecExtract(i), src.GetUnpackerCmdArgsExtract(i),
                         src.GetUnpackerNeedANSIListFile(i)))
            return FALSE;
    }
    return TRUE;
}

int CUnpackerConfig::AddUnpacker(BOOL toFirstIndex)
{
    CALL_STACK_MESSAGE2("CUnpackerConfig::AddUnpacker(%d)", toFirstIndex);
    CUnpackerConfigData* data = new CUnpackerConfigData;
    if (data == NULL)
        return -1;
    int index;
    if (toFirstIndex)
    {
        Unpackers.Insert(0, data);
        index = 0;
        if (PreferedUnpacker != -1)
            PreferedUnpacker++;
    }
    else
        index = Unpackers.Add(data);
    if (!Unpackers.IsGood())
    {
        Unpackers.ResetState();
        return -1;
    }
    return index;
}

/*
BOOL
CUnpackerConfig::SwapUnpackers(int index1, int index2)
{
  BYTE buff[sizeof(CUnpackerConfigData)];
  memcpy(buff, Unpackers[index1], sizeof(CUnpackerConfigData));
  memcpy(Unpackers[index1], Unpackers[index2], sizeof(CUnpackerConfigData));
  memcpy(Unpackers[index2], buff, sizeof(CUnpackerConfigData));
  return TRUE;
}
*/

BOOL CUnpackerConfig::MoveUnpacker(int srcIndex, int dstIndex)
{
    BYTE buff[sizeof(CUnpackerConfigData)];
    memcpy(buff, Unpackers[srcIndex], sizeof(CUnpackerConfigData));
    if (srcIndex < dstIndex)
    {
        int i;
        for (i = srcIndex; i < dstIndex; i++)
            memcpy(Unpackers[i], Unpackers[i + 1], sizeof(CUnpackerConfigData));
    }
    else
    {
        int i;
        for (i = srcIndex; i > dstIndex; i--)
            memcpy(Unpackers[i], Unpackers[i - 1], sizeof(CUnpackerConfigData));
    }
    memcpy(Unpackers[dstIndex], buff, sizeof(CUnpackerConfigData));
    return TRUE;
}

void CUnpackerConfig::DeleteUnpacker(int index)
{
    if (PreferedUnpacker >= 0 && PreferedUnpacker < Unpackers.Count)
    {
        if (index < PreferedUnpacker)
            PreferedUnpacker--; // adjust index to represent the same item
        else
        {
            if (index == PreferedUnpacker)
                PreferedUnpacker = -1; // we lost the selected item
        }
    }
    Unpackers.Delete(index);
}

BOOL CUnpackerConfig::SetUnpacker(int index, int type, const char* title, const char* ext, BOOL old,
                                  BOOL supportLongNames,
                                  const char* cmdExecExtract, const char* cmdArgsExtract,
                                  BOOL needANSIListFile)
{
    CALL_STACK_MESSAGE10("CUnpackerConfig::SetUnpacker(%d, %d, %s, %s, %d, %d, %s, %s, %d)",
                         index, type, title, ext, old, supportLongNames, cmdExecExtract, cmdArgsExtract,
                         needANSIListFile);
    CUnpackerConfigData* data = Unpackers[index];
    data->Destroy();
    data->Type = type;
    data->OldType = old;
    data->Title = DupStr(title);
    data->Ext = DupStr(ext);
    if (old && data->Type == 1 ||
        !old && data->Type == CUSTOMUNPACKER_EXTERNAL)
    {
        data->CmdExecExtract = DupStr(cmdExecExtract);
        data->CmdArgsExtract = DupStr(cmdArgsExtract);
        data->SupportLongNames = supportLongNames;
        data->NeedANSIListFile = needANSIListFile;
    }

    if (data->IsValid())
    {
        if (PreferedUnpacker == -1)
            PreferedUnpacker = Unpackers.Count - 1;
        return TRUE;
    }
    else
    {
        Unpackers.Delete(index);
        return FALSE;
    }
}

BOOL CUnpackerConfig::SetUnpackerTitle(int index, const char* title)
{
    CUnpackerConfigData* data = Unpackers[index];
    if (data->Title != NULL)
        free(data->Title);
    data->Title = DupStr(title);
    return data->Title != NULL;
}

BOOL CUnpackerConfig::ExecuteUnpacker(HWND parent, CFilesWindow* panel, const char* zipFile, const char* mask,
                                      const char* targetDir, BOOL delArchiveWhenDone, CDynamicString* archiveVolumes)
{
    CALL_STACK_MESSAGE5("CUnpackerConfig::ExecuteUnpacker(, %s, %s, %s, %d, )",
                        zipFile, mask, targetDir, delArchiveWhenDone);
    if (PreferedUnpacker != -1 && PreferedUnpacker < Unpackers.Count)
    {
        CUnpackerConfigData* data = Unpackers[PreferedUnpacker];
        if (data->Type == CUSTOMUNPACKER_EXTERNAL)
        {
            if (delArchiveWhenDone)
                TRACE_E("CUnpackerConfig::ExecuteUnpacker(): delArchiveWhenDone is TRUE for external archiver (unsupported, ignoring)");

            char* tmpMask = DupStr(mask);
            char* command = (char*)malloc(strlen(data->CmdExecExtract) +
                                          strlen(data->CmdArgsExtract) + 2);
            if (tmpMask == NULL || command == NULL)
            {
                TRACE_E(LOW_MEMORY);
                return FALSE;
            }
            sprintf(command, "%s %s", data->CmdExecExtract, data->CmdArgsExtract);

            // we must store the pointer for deallocation; it will be destroyed
            char* tmpMask2 = tmpMask;
            BOOL ret = PackUniversalUncompress(parent, command, NULL, targetDir, FALSE, panel,
                                               data->SupportLongNames, zipFile, targetDir,
                                               NULL, PackEnumMask, &tmpMask, data->NeedANSIListFile);
            free(tmpMask2);
            free(command);
            return ret;
        }
        else
        {
            CPluginData* plugin = Plugins.Get(-data->Type - 1);
            if (plugin != NULL && plugin->SupportCustomUnpack)
            {
                return plugin->UnpackWholeArchive(panel, zipFile, mask, targetDir, delArchiveWhenDone, archiveVolumes);
            }
            else
                TRACE_E("Unexpected situation in CUnpackerConfig::ExecuteUnpacker().");
        }
    }
    return FALSE;
}

BOOL CUnpackerConfig::Save(int index, HKEY hKey)
{
    DWORD d;
    BOOL ret = TRUE;
    int type = GetUnpackerType(index);
    d = type;
    if (ret)
        ret &= SetValue(hKey, SALAMANDER_CPU_TYPE, REG_DWORD, &d, sizeof(d));
    if (ret)
        ret &= SetValue(hKey, SALAMANDER_CPU_TITLE, REG_SZ, GetUnpackerTitle(index), -1);
    if (ret)
        ret &= SetValue(hKey, SALAMANDER_CPU_EXT, REG_SZ, GetUnpackerExt(index), -1);
    if (ret && type == CUSTOMUNPACKER_EXTERNAL)
    {
        d = GetUnpackerSupLongNames(index);
        if (ret)
            ret &= SetValue(hKey, SALAMANDER_CPU_SUPLONG, REG_DWORD, &d, sizeof(d));
        d = GetUnpackerNeedANSIListFile(index);
        if (ret)
            ret &= SetValue(hKey, SALAMANDER_CPU_ANSILIST, REG_DWORD, &d, sizeof(d));
        if (ret)
            ret &= SetValue(hKey, SALAMANDER_CU_EXECEXTRACT, REG_SZ, GetUnpackerCmdExecExtract(index), -1);
        if (ret)
            ret &= SetValue(hKey, SALAMANDER_CU_ARGSEXTRACT, REG_SZ, GetUnpackerCmdArgsExtract(index), -1);
    }
    return ret;
}

BOOL CUnpackerConfig::Load(HKEY hKey)
{
    int max = MAX_PATH + 2;

    char title[MAX_PATH + 2];
    char ext[MAX_PATH + 2];
    DWORD type;
    DWORD suplong = FALSE;
    DWORD needANSI = FALSE;
    char execcopy[MAX_PATH + 2];
    execcopy[0] = 0;
    char argscopy[MAX_PATH + 2];
    argscopy[0] = 0;

    BOOL ret = TRUE;
    if (ret)
        ret &= GetValue(hKey, SALAMANDER_CPU_TYPE, REG_DWORD, &type, sizeof(DWORD));
    if (ret)
        ret &= GetValue(hKey, SALAMANDER_CPU_TITLE, REG_SZ, title, max);
    if (ret)
        ret &= GetValue(hKey, SALAMANDER_CPU_EXT, REG_SZ, ext, max);
    if (ret && (Configuration.ConfigVersion < 6 && type == 1 ||
                Configuration.ConfigVersion >= 6 && type == CUSTOMUNPACKER_EXTERNAL))
    {
        if (ret)
        {
            if (!GetValue(hKey, SALAMANDER_CPU_ANSILIST, REG_DWORD, &needANSI, sizeof(DWORD)))
                needANSI = FALSE; // in older versions it wasn't present, assumed FALSE
        }

        if (ret)
            ret &= GetValue(hKey, SALAMANDER_CPU_SUPLONG, REG_DWORD, &suplong, sizeof(DWORD));
        if (ret)
            ret &= GetValue(hKey, SALAMANDER_CU_EXECEXTRACT, REG_SZ, execcopy, max);
        if (ret)
            ret &= GetValue(hKey, SALAMANDER_CU_ARGSEXTRACT, REG_SZ, argscopy, max);
    }

    if (ret)
    {
        int index;
        if ((index = AddUnpacker()) == -1)
            return FALSE;
        if (Configuration.ConfigVersion < 44) // convert extensions to lowercase
        {
            char extAux[MAX_PATH + 2];
            lstrcpyn(extAux, ext, MAX_PATH + 2);
            StrICpy(ext, extAux);
        }
        ret &= SetUnpacker(index, (int)type, title, ext, Configuration.ConfigVersion < 6,
                           (BOOL)suplong,
                           execcopy, argscopy, needANSI);
    }

    return ret;
}
