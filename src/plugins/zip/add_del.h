// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

class CSalPackCreatedFiles; // feature 119, src/common/salpackvol.h

//action flags

#define AF_ADD 0       //add file and delete it if moving files to zip
#define AF_DEL 1       //don't add file, but delete it if moving files to zip \
                       //does matter only on directories
#define AF_NOADD 2     //don't add file and don't delete it if moving files to zip
#define AF_OVERWRITE 3 //for unix files when ovewriting, same as AF_ADD

struct CAddInfo
{
    char* Name;
    int NameLen;
    bool IsDir;
    CQuadWord Size;
    __UINT16 InterAttr,
        Flag;
    int Method;
    DWORD FileAttr;
    FILETIME LastWrite;
    __UINT64 CompSize;
    unsigned Crc;
    __UINT64 LocHeaderOffs;
    unsigned StartDisk;
    int Action;        //flag, see above
    int InternalFlags; // IF_xxx
    int Replaced;      // feature 110: members put on the delete list for this file (MatchFiles)

    CAddInfo()
    {
        Name = NULL;
        Replaced = 0;
    }
    ~CAddInfo()
    {
        if (Name)
            free(Name);
    }
};

// feature 113: a member MatchFiles put on the delete list (DelFiles) for an added file - which
// file replaces it, and its central directory record as it was. A member is deleted only if the
// file replacing it is stored: when that file is not (its source cannot be opened or read and
// the answer is Skip / Skip all), the member is copied back (temporary-copy mode, PackFiles ->
// RestoreReplaced) or never deleted (in-place mode, DeleteReplacedAfterPack).
struct CReplacedMember
{
    CFileInfo* Member;      // in DelFiles; NULL once put back or dropped from DelFiles
    CAddInfo* Owner;        // in AddFiles
    unsigned char* Central; // the member's central directory record (CFileHeader + name + extra + comment)
    unsigned CentralLen;

    CReplacedMember()
    {
        Member = NULL;
        Owner = NULL;
        Central = NULL;
        CentralLen = 0;
    }
    ~CReplacedMember()
    {
        if (Central)
            free(Central);
    }
};

// feature 113: CFileInfo::InternalFlags of a DelFiles entry - its replacing file was not stored,
// the member stays (in-place mode, DeleteReplacedAfterPack)
#define IF_KEEP_MEMBER 0x100

#define FPR_NORMAL 0
#define FPR_SFXRESERVE 1
#define FPR_SFXEND 2
#define FPR_WRITE 3

typedef TIndirectArray2<char> TIndirectArray2_char_;

enum CSfxSettingsComments
{
    SFX_COMMENT_HEAD,
    SFX_COMMENT_VERSION,
    SFX_COMMENT_TARGDIR,
    SFX_COMMENT_ALLOWCHANGE,
    SFX_COMMENT_REMOVE,
    SFX_COMMENT_AUTO,
    SFX_COMMENT_SUMMARY,
    SFX_COMMENT_HIDE,
    SFX_COMMENT_OVERWRITE,
    SFX_COMMENT_AUTODIR,
    SFX_COMMENT_COMMAND,
    SFX_COMMENT_PACKAGE,
    SFX_COMMENT_MBUT,
    SFX_COMMENT_MICO,
    SFX_COMMENT_MBOX,
    SFX_COMMENT_TEXT,
    SFX_COMMENT_TITLE,
    SFX_COMMENT_BUTTON,
    SFX_COMMENT_VENDOR,
    SFX_COMMENT_WWW,
    SFX_COMMENT_ICOFILE,
    SFX_COMMENT_ICOINDEX,
    SFX_COMMENT_WAITFOR,
    SFX_COMMENT_REQUIRESADMIN
};

class CZipPack : public CZipCommon
{
public:
    //int                 ErrorID;
    TIndirectArray2<CFileInfo> DelFiles; //file header of files to be extracted
    // feature 113: every DelFiles entry of a pack with the file that replaces it (see CReplacedMember)
    TIndirectArray2<CReplacedMember> Replacements;
    // feature 113: temporary-copy mode - the replaced members were left out of the new archive
    // before packing (DeleteFiles); a file not stored gets its members copied back
    bool ReplacedDeletedFirst;
    // feature 113: in-place mode - DeleteFiles runs after PackFiles: the region it moves last holds
    // the added files (their offsets move too), and it is not interrupted (everything is stored)
    bool DeleteAfterPack;
    //unsigned            AssumedDelProgress;
    CEOCentrDirRecordEx EONewCentrDir; //end of central directory record
    QWORD NewCentrDirSize;
    QWORD NewCentrDirOffs;
    char* NewCentrDir;
    DWORD ZipAttr;
    CFile* TempFile;
    char* TempName; //UTF-8, U8_MAX_PATH bytes (heap - long paths)
    //bool                Backup;
    CQuadWord AddTotalSize;
    int SizeToAdd;
    const char* SourcePath;
    int SourceLen;
    TIndirectArray2<CAddInfo> AddFiles;
    bool SkipAllIOErrors;
    CFile* SourFile;
    __UINT32 Crc;
    bool Move;
    bool Pack; //flag indicating pack operation
    bool NothingToDo;
    __UINT32 Keys[3]; //decryption keys
    //bool                NoFreeDirs;
    CExtendedOptions Options;
    // feature 094: the byte form new items are keyed with, derived once from
    // Options.Password (GetPackPassword), wiped in the destructor
    char PackPassword[SALZIPPWD_FORM_BUF];
    bool PackPasswordReady;
    const char* GetPackPassword();
    bool RecoverOK;
    FILETIME NewestFileTime;

    //multi-volume archives
    bool OverwriteAll;
    bool IgnoreAllFreeSp;
    QWORD DiskSize;
    // feature 106: TempName names the volume this operation created (or confirmed overwriting) -
    // only then may a failure delete it; a declined or refused name is the user's file
    bool TempNameOurs;
    // feature 119: every volume this multi-volume pack created (PackMultiVol owns the list;
    // NULL elsewhere) - a failed or cancelled pack deletes them, not only the current one
    CSalPackCreatedFiles* CreatedVolumes;

    //self-extracting archives
    unsigned ArchiveHeaderOffs;
    QWORD ArchiveDataOffs;
    BOOL SeccondPass;

    //delete from archive

    CZipPack(const char* zipName, const char* zipRoot,
             CSalamanderForOperationsAbstract* salamander);

    ~CZipPack();

    int DeleteFromArchive(SalEnumSelection next, void* param);
    int PackToArchive(BOOL move, const char* sourcePath,
                      SalEnumSelection2 next, void* param);
    int PackNormal(SalEnumSelection2 next, void* param);
    int PackMultiVol(SalEnumSelection2 next, void* param);
    int PackSelfExtract(SalEnumSelection2 next, void* param);
    int CountFilesInRoot(int* filesInRoot, bool* rootExist);
    // dataEnd: where the data after the last deleted member ends (the central directory; with
    // DeleteAfterPack the end of the added files)
    int DeleteFiles(int* deletedFiles, QWORD dataEnd);
    int MoveData(QWORD writePos, QWORD readPos, QWORD moveSize, char* buffer);
    void UpdateCentrDir(CFileInfo* curFile, CFileInfo* nextFile, QWORD delta);
    // feature 113: DeleteAfterPack - the added files in the moved region get their new offsets
    void UpdateAddedOffsets(CFileInfo* curFile, CFileInfo* nextFile, QWORD delta);
    // feature 113: temporary-copy mode - 'owner' was not stored; its replaced members are copied
    // back from the original archive to *writePos (which moves past them)
    int RestoreReplaced(CAddInfo* owner, __UINT64* writePos);
    // feature 113: in-place mode, after PackFiles - deletes the replaced members whose file was stored
    int DeleteReplacedAfterPack();
    int WriteCentrDir();
    void AddAESExtraField(CFileInfo* fileInfo, CAESExtraField* extraAES, __UINT16* pExtraLen);
    int ExportLocalHeader(CFileInfo* fileInfo, char* buffer);
    int WriteLocalHeader(CFileInfo* fileInfo, char* buffer);
    int WriteDataDecriptor(CFileInfo* fileInfo);
    int WriteCentralHeader(CFileInfo* fileInfo, char* buffer, BOOL first, int reason);
    int WriteEOCentrDirRecord();
    int ExportName(char* destName, CFileInfo* fileInfo, BOOL* isUTF8);
    int CreateTempFile();
    void NTFSCompressFile(HANDLE file);
    int EnumFiles2(SalEnumSelection2 next, void* param);
    int LoadCentralDirectory();
    int MatchFiles(int& count); // count is the expected number of files after the operation
    int BackupZip();
    int PackFiles();
    int FinishPack(int reason = FPR_NORMAL);
    // feature 113: withAdded - the added files are in the archive (DeleteReplacedAfterPack failed):
    // their entries are written too
    void Recover(bool withAdded = false);
    int GetDirInfo(const char* name, DWORD* attr, FILETIME* lastWrite);
    int IsDirectoryEmpty(const char* name);
    int InsertDir(char* dir, TIndirectArray2<TIndirectArray2_char_>& table);
    int CleanUpSource();
    int LoadExPackOptions(unsigned flags);
    int Store(__UINT64* size);
    int CreateNextFile(bool firstSfxDisk = false);
    // feature 106: is the existing file 'nameU8' one of the files this operation packs (AddFiles)?
    BOOL IsPackedSource(const char* nameU8);
    // feature 106: tells the user that 'nameU8' is one of the files being packed; IDS_NODISPLAY
    int RefusePackedSource(const char* nameU8);
    // feature 119: a multi-volume pack ended without a complete archive - deletes the volumes it
    // created ('all': a fixed disk) or, on removable media, the most recent one while it is still
    // being written (TempNameOurs) and its name on the disk in the drive still holds it -
    // SalPackVolCleanupScope, SalPackCreatedMayDelete, salpackvol.h; TempFile must be closed
    void DeleteCreatedVolumes(BOOL all);
    // feature 119: one recorded volume, if SalPackCreatedMayDelete allows; TRUE when deleted
    BOOL DeleteCreatedVolume(int i);
    // feature 119: records the size on disk of the volume being closed (TempNameOurs only)
    void NoteVolumeSize();
    int NextDisk();
    int MatchAll();
    int WriteSfxExecutable(const char* sfxFile, const char* sfxPackage, BOOL preview, int progressMode);
    BOOL WriteSFXHeader(const char* archName, QWORD eoCentrDirOffs, DWORD archSize);
    /*
    bool ChangeSfxIcon(const char * sfxFile);
    int LoadIcons(const char * iconFile, DWORD index, CIcon **icons, int * count);
    void DestroyIcons(CIcon * icons, int count);
    CIcon * LoadIconsFromDirectory(HINSTANCE module, LPICONDIR directory, bool isIco);
    LPICONDIR LoadIconDirectoryByResName(HINSTANCE module, LPTSTR lpszName);
    LPICONDIR LoadIconDirectoryFromEXE(HINSTANCE module, DWORD index);
    LPVOID LoadIconDataFromEXE(HINSTANCE module, DWORD id);
    LPICONDIR LoadIconDirectoryFromICO(CFile * icoFile);
    LPVOID LoadIconDataFromICO(CFile * icoFile, DWORD offset, DWORD size);
    //void LoadIDsList(HINSTANCE module, CDynamicArray * IDsArray);
    */
    BOOL LoadDefaults();
    int CreateSFX();
    int CheckArchiveForSFXCompatibility();
    int CommentArchive();
    int SaveComment();
    BOOL ExportLongString(CFile* outFile, const char* string);
    BOOL WriteSFXComment(CFile* outFile, CSfxSettingsComments comment);
    BOOL ExportSFXSettings(CFile* outFile, CSfxSettings* settings);
    int FindNewestFile();
    int WriteSFXECRec(QWORD offset);
    int WriteSFXCentralDir();
};
