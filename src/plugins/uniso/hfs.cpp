// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"
#include "dbg.h"

#include "uniso.h"
#include "isoimage.h"
#include "hfs.h"

#include "uniso.rh"
#include "uniso.rh2"
#include "lang\lang.rh"

#define BUFFER_SIZE 32768

#pragma runtime_checks("c", off)

// Based on Apple Technical Note TN1150

UInt64 FromM64(UInt64 x)
{
    return (((UInt64)FromM32((UInt32)x)) << 32) | FromM32(x >> 32);
}

static void ConvertHFSDate(FILETIME& ft, UInt32 HFSDate)
{
    SYSTEMTIME st;
    struct tm* gmtm;
    time_t time2;

    time2 = FromM32(HFSDate); // In seconds since midnight January 1, 1904, GMT
    // Convert to 1.1.1970
    time2 -= 365 * 24 * 60 * 60 * (1970 - 1904) + 17 * 24 * 60 * 60 /*leap days*/;
    gmtm = gmtime(&time2);
    if (!gmtm)
    {
        time2 = time(NULL);
        gmtm = gmtime(&time2);
    }
    st.wYear = gmtm->tm_year + 1900;
    st.wMonth = gmtm->tm_mon + 1;
    st.wDay = gmtm->tm_mday;
    st.wHour = gmtm->tm_hour;
    st.wMinute = gmtm->tm_min;
    st.wSecond = gmtm->tm_sec;
    st.wMilliseconds = st.wDayOfWeek = 0;

    SystemTimeToFileTime(&st, &ft);
}

static void FixIllegalFSChars(char* s)
{
    char* s2 = s + strlen(s);

    // Remove trailing spaces
    while ((s2 > s) && (s2[-1] == ' '))
        *--s2 = 0;

    // Just empty path (or consisting of spaces only)?
    if (!*s)
    {
        // Firefox 3.0.7.dmg contains link called " "
        *s = '_';
        s[1] = 0;
        return;
    }
    if ((s2 > s) && (s2[-1] == '/'))
    {
        // HDD_Installer_MacOSX.dmg contains .dmg with "HASP Installation/"
        s2[-1] = 0;
    }

    while (*s)
    {
        if (IsDBCSLeadByte(*s))
        {
            s++; // Skip both the lead and following bytes
            if (!*s)
                break; // Invalid string! Lead byte followed by terminating byte!
        }
        else
        {
            if (((unsigned char)*s < 32) || (*s == '?') || (*s == '\\') || (*s == '*'))
                *s = '_';
        }
        s++;
    }
}

CHFS::CHFS(CISOImage* image) : CUnISOFSAbstract(image)
{
    SectorSize = 0;
    PartStart = 0;
    HFSWrapperOfs = 0;
    pCatalog = NULL;
    nFolders = nAllocedFolders = 0;
    pFolders = NULL;
    bSkipRootParent = false;
    Declared = FALSE;
}

CHFS::~CHFS()
{
    delete pCatalog;
    if (pFolders)
    {
        for (int i = 0; i < nFolders; i++)
            free(pFolders[i]);
        free(pFolders);
    }
}

BOOL CHFS::Open(BOOL quiet)
{
    Block0 block0; // 1st sector on Block Devices, something like MBR
    DWORD dwBytesRead;
    Partition partition; // Entry in Partition Map

    CALL_STACK_MESSAGE2("CHFS::Open(%d)", quiet);

    HFSWrapperOfs = Image->GetSectorOffset(0);
    SeekSector(0);

    if (!Read(&block0, sizeof(block0), &dwBytesRead))
        return FALSE;

    if (sizeof(block0) != dwBytesRead)
        return Error(IDS_ERR_HFS_READ, quiet);

    if (block0.sbSig == HFS_DEVICE_SIGNATURE)
    {
        SectorSize = FromM16(block0.sbBlkSize);

        DWORD nPartitions = 1;
        for (DWORD i = 0; i < nPartitions; i++)
        {
            SeekSector(i + 1);

            if (!Read(&partition, sizeof(partition), &dwBytesRead))
                return FALSE;

            if ((sizeof(partition) != dwBytesRead) || (partition.pmSig != HFS_PARTITION_SIGNATURE) || (partition.pmSigPad != 0))
            {
                Declared = DeclaredBehindDamagedMap(); // feature 333 (review 1)
                return Error(IDS_ERR_HFS_INVALID_PARTITION, quiet);
            }

            // Each PM entry contains the same # of items in the entire PM
            if ((i > 0) && (nPartitions != FromM32(partition.pmMapBlkCnt)))
            {
                Declared = DeclaredBehindDamagedMap(); // feature 333 (review 1)
                return Error(IDS_ERR_HFS_INVALID_PARTITION, quiet);
            }

            nPartitions = FromM32(partition.pmMapBlkCnt);
            if (!strcmp(partition.pmParType, "Apple_HFS"))
            {
                PartStart = FromM32(partition.pmPyPartStart);
            }
        }
        if (!PartStart)
        {
            Declared = DeclaredBehindDamagedMap(); // feature 333 (review 1)
            return Error(IDS_ERR_HFS_INVALID_PARTITION, quiet);
        }
    }
    else if (block0.sbSig == 0)
    { // It may be just a HFS+ partition
        PartStart = 0;
        SectorSize = 512;
    }
    else
    {
        return Error(IDS_ERR_HFS_UNRECOGNIZED, quiet); // Can this happen???
    }

    // VolumeHeader is stored at sector 2 & second to last sector (starting 1024 bytes before the end)
    // NOTE: SectorSize might actually be 2048
    SeekSector(PartStart);
    SeekRel(2 * 512);
    if (!Read(&VolHeader, sizeof(VolHeader), &dwBytesRead))
        return FALSE;

    // feature 333: an HFS+ volume is there (or an HFS wrapper holding one) - every failure from here
    // on drops a volume whose files are not listed (the caller marks the listing)
    Declared = SalHfsVolumeHeaderDeclaresHfsPlus((const unsigned char*)&VolHeader, dwBytesRead);

    if (sizeof(VolHeader) != dwBytesRead)
        return Error(IDS_ERR_HFS_READ, quiet);

    if (VolHeader.signature == HFS_PARTITION_HFS_SIGNATURE)
    {
        MDBRecord mdb;

        // It is a HFS, not HFS partition. Look for wrapped HFS+ partition
        SeekRel(-(int)sizeof(VolHeader));
        if (!Read(&mdb, sizeof(mdb), &dwBytesRead))
            return FALSE;

        if (sizeof(mdb) != dwBytesRead)
            return Error(IDS_ERR_HFS_READ, quiet);

        if ((mdb.drSigWord != HFS_PARTITION_HFS_SIGNATURE) || (mdb.drEmbedSigWord != kHFSPlusSigWord))
            return Error(IDS_ERR_HFS_ORIGINAL_HFS, quiet);

        HFSWrapperOfs += 512 * (UInt32)(FromM16(mdb.drAlBlSt) + FromM16(mdb.drEmbedExtent.xdrStABN) * (FromM32(mdb.drAlBlkSiz) / 512));
        SeekSector(PartStart);
        SeekRel(2 * 512);
        if (!Read(&VolHeader, sizeof(VolHeader), &dwBytesRead))
            return FALSE;

        if (sizeof(VolHeader) != dwBytesRead)
            return Error(IDS_ERR_HFS_READ, quiet);
    }

    if ((VolHeader.signature != kHFSPlusSigWord) || (VolHeader.version != FromM16(kHFSPlusVersion)))
        return Error(IDS_ERR_HFS_UNRECOGNIZED, quiet);

    VolHeader.blockSize = FromM32(VolHeader.blockSize);

    pCatalog = new BTree(this, &VolHeader.catalogFile, quiet);
    if (!pCatalog)
        return Error(IDS_INSUFFICIENT_MEMORY, quiet);

    if (!pCatalog->IsOK())
        return FALSE;

    return TRUE;
}

// Feature 333 (review 1): the walk of the Apple partition map in Open failed (an entry it walks is
// damaged, or the entry count ends the walk before the HFS entry) before the volume header was read -
// an intact HFS+ volume was dropped without a mark. Looks at the first 64 blocks of the map (Apple's
// maps hold up to 63 entries) for an intact "Apple_HFS" entry whose volume header declares HFS+; a
// damaged entry is passed over, a read that fails or comes short ends the search. Only decides
// 'Declared'; the volume is not opened (the map stays refused, as before).
BOOL CHFS::DeclaredBehindDamagedMap()
{
    CALL_STACK_MESSAGE1("CHFS::DeclaredBehindDamagedMap()");

    for (int i = 1; i <= 64; i++)
    {
        unsigned char entry[sizeof(Partition)];
        DWORD read = 0;
        if (!SeekSector(i) || !Read(entry, sizeof(entry), &read) || read != sizeof(entry))
            break;
        unsigned start = 0;
        if (!SalHfsApmEntryIsHfs(entry, read, &start) || start == 0 || start > INT_MAX)
            continue;
        unsigned char header[sizeof(HFSPlusVolumeHeader)];
        if (!SeekSector((int)start) || SeekRel(2 * 512) < 0 || !Read(header, sizeof(header), &read))
            continue;
        if (SalHfsVolumeHeaderDeclaresHfsPlus(header, read))
            return TRUE;
    }
    return FALSE;
}

// Seeks on disk (sector is usually 512 or 2048 bytes)
// Returns TRUE on success
BOOL CHFS::SeekSector(int sector)
{
    __int64 newPos = (__int64)sector * SectorSize + HFSWrapperOfs;
    return (newPos == Image->File->Seek(newPos, FILE_BEGIN)) ? TRUE : FALSE;
}

// Seeks on HFS+ partition (block is usually 4096 bytes)
// Returns TRUE on success
BOOL CHFS::SeekBlock(int block)
{
    __int64 newPos = (__int64)PartStart * SectorSize + (__int64)block * VolHeader.blockSize + HFSWrapperOfs;
    return (newPos == Image->File->Seek(newPos, FILE_BEGIN)) ? TRUE : FALSE;
}

// Seeks relatively
// Returns new position
__int64 CHFS::SeekRel(int offset)
{
    return Image->File->Seek(offset, FILE_CURRENT);
}

BOOL CHFS::Read(LPVOID buf, DWORD dwBytesToRead, DWORD* dwBytesRead)
{
    // Error (when returning FALSE) handled by Read
    // However, dwBytesRead may be less than dwBytesToRead even when returning TRUE
    return Image->File->Read(buf, dwBytesToRead, dwBytesRead, Image->FileName, SalamanderGeneral->GetMainWindowHWND());
}

BOOL CHFS::DumpInfo(FILE* outStream)
{
    return FALSE;
}

BOOL CHFS::GetRootName(char* rootName, int maxlen)
{
    CALL_STACK_MESSAGE3("CHFS::GetRootName(%s, %i)", rootName, maxlen);
    int nRecords = pCatalog->GetNumRecords();

    for (int i = 0; i < min(5, nRecords); i++)
    {
        size_t avail;
        HFSPlusCatalogKey* pKey = (HFSPlusCatalogKey*)pCatalog->GetRecord(i, &avail);
        SalHfsCatalogKey key;
        // feature 322: the key and its name must lie inside the record's node
        if (!SalHfsCatalogKeyView((const unsigned char*)pKey, avail, &key))
            continue;
        int keyLen = (int)key.KeyLength;
        int nameLen = (int)key.NameLength;
        wchar_t fileNameW[256];

        // feature 223: the length is read from the image - over the 255 units of HFSUniStr255 it
        // overran 'fileNameW[256]' (a crafted image wrote past the stack buffer)
        if ((keyLen <= 6) || (nameLen == 0) || (nameLen > 255) || (pKey->parentID != FromM32(kHFSRootParentID)))
            continue; // skip threads
        for (int j = 0; j < nameLen; j++)
            fileNameW[j] = FromM16(pKey->nodeName.unicode[j]);
        fileNameW[nameLen] = 0;
        // format boundary (interface 104): HFS+ names are UTF-16 (big endian, canonically
        // decomposed) -> UTF-8. WC_COMPOSITECHECK is gone: it is not allowed with CP_UTF8,
        // and UTF-8 carries the decomposed form as-is - which is what the OS must see too
        // (name bytes are passed through unchanged, see doc\plugin-vnext-migration.md).
        if (WideCharToMultiByte(CP_UTF8, 0, fileNameW, nameLen + 1, rootName, maxlen, NULL, NULL) > 0)
        {
            rootName[maxlen - 1] = 0;
            bSkipRootParent = TRUE;
            return TRUE;
        }
    }
    return FALSE;
}

BOOL CHFS::ListDirectory(char* rootPath, int session,
                         CSalamanderDirectoryAbstract* dir, CPluginDataInterfaceAbstract*& pluginData)
{
    // feature 332: the record sizes SalHfsCatalogRecordClass checks
    static_assert(sizeof(HFSPlusCatalogFolder) == SAL_HFSCAT_FOLDER_REC_SIZE, "HFSPlusCatalogFolder size");
    static_assert(sizeof(HFSPlusCatalogFile) == SAL_HFSCAT_FILE_REC_SIZE, "HFSPlusCatalogFile size");
    CALL_STACK_MESSAGE5("CHFS::ListDirectory(%s, %i, %p, %p)", rootPath, session, dir, pluginData);
    int nRecords = pCatalog->GetNumRecords();
    // feature 329: the catalog IDs (as stored) of the folders left out - their contents are left out with
    // them (a record whose parent is not in pFolders is listed at the HFS+ root)
    CSalLeftOutIds leftOutFolders;

    // feature 349: the catalog is sorted by parent ID; a folder made first and moved (on a Mac) into a
    // newer folder keeps its lower ID, so the records inside it come before its own record - they were
    // listed at the HFS+ root (also the contents of a folder then left out). The folder records the
    // listing lists are collected first; before a record is taken, the folders above it not taken yet
    // are taken (listed, left out or skipped by the code of their own record), outermost first.
    CSalHfsFolderOrder order;
    for (int i = 0; i < nRecords; i++)
    {
        size_t avail;
        HFSPlusCatalogKey* pKey = (HFSPlusCatalogKey*)pCatalog->GetRecord(i, &avail);
        SalHfsCatalogKey key;
        if (SalHfsCatalogRecordClass((const unsigned char*)pKey, avail, bSkipRootParent, &key) != SAL_HFSREC_FOLDER)
            continue;
        HFSPlusCatalogFolder* folder = (HFSPlusCatalogFolder*)((char*)pKey + key.BodyOffset);
        if (!order.Add(folder->folderID, pKey->parentID, (size_t)i))
        {
            Image->ListingLeftOut.SetIncomplete();
            return Error(IDS_INSUFFICIENT_MEMORY, FALSE);
        }
    }
    if (!order.Seal())
    {
        Image->ListingLeftOut.SetIncomplete();
        return Error(IDS_INSUFFICIENT_MEMORY, FALSE);
    }

    for (int i = 0; i < nRecords; i++)
    {
        if (order.IsTaken(i))
            continue; // feature 349: a folder taken before its place, with a record below it
        size_t avail;
        HFSPlusCatalogKey* pKey = (HFSPlusCatalogKey*)pCatalog->GetRecord(i, &avail);
        SalHfsCatalogKey key;
        // feature 332: what the record is (salhfscatalog.h) - the key, its name and the record must lie
        // inside the record's node (322), a name of up to 255 units (223), a folder / file record its
        // whole structure (322). A record that may hold an entry but cannot be listed was skipped without
        // a mark and a whole unpack with "Delete archive after unpacking" deleted the image - now the
        // listing is marked incomplete (the unpack fails, the image is kept). Thread records, the volume
        // label and HFS+ metadata are not entries.
        int kind = SalHfsCatalogRecordClass((const unsigned char*)pKey, avail, bSkipRootParent, &key);
        if (kind == SAL_HFSREC_NOT_ENTRY)
            continue; // threads, the root folder already used as the volume label, metadata
        if (kind == SAL_HFSREC_DAMAGED)
        {
            TRACE_E("CHFS::ListDirectory(): a damaged catalog record, skipped");
            Image->ListingLeftOut.SetIncomplete();
            continue;
        }
        // feature 349: the folders above it first (none in an ordered catalog); in a loop of parents the
        // record may be one of the folders left out
        if (!TakePending(pKey->parentID, rootPath, dir, pluginData, leftOutFolders, order))
            return FALSE;
        if (order.IsTaken(i))
            continue;
        order.Take(i);
        if (kind == SAL_HFSREC_UNKNOWN)
        {
            // as before, the HFS+ listing ends here - now marked incomplete; inside a folder left out by
            // 329 it is skipped with that folder, as before (review 1)
            Image->ListingLeftOut.SetIncomplete();
            if (leftOutFolders.Under(pKey->parentID, false, 0) == SAL_ISO_UNDER_SKIPPED)
                continue;
            TRACE_E("CHFS::ListDirectory(): a catalog record of a type not handled, the listing ends");
            return FALSE;
        }
        if (!ListRecord(i, pKey, key, rootPath, dir, pluginData, leftOutFolders))
            return FALSE;
    }
    return TRUE;
}

// Feature 349: takes the folders above a record under 'parentID' that are not taken yet, outermost first
// (CSalHfsFolderOrder::Pending), each by the code of its own record (ListRecord). A loop of parents (a
// damaged catalog: none of its folders reaches the root): its folders are left out with everything in
// them and the listing is marked incomplete (a whole unpack fails, the image is kept), no message - as
// 332's damaged records. FALSE = the HFS+ listing ends (out of memory, ListRecord's FALSE).
BOOL CHFS::TakePending(UInt32 parentID, char* rootPath, CSalamanderDirectoryAbstract* dir,
                       CPluginDataInterfaceAbstract*& pluginData, CSalLeftOutIds& leftOutFolders,
                       CSalHfsFolderOrder& order)
{
    std::vector<size_t> pending;
    int res = order.Pending(parentID, pending);
    if (res == SAL_HFS_PENDING_NO_MEMORY)
    {
        Image->ListingLeftOut.SetIncomplete();
        return Error(IDS_INSUFFICIENT_MEMORY, FALSE);
    }
    if (res == SAL_HFS_PENDING_LOOP)
    {
        TRACE_E("CHFS::TakePending(): the catalog's folders form a loop of parents, left out");
        Image->ListingLeftOut.SetIncomplete();
    }
    for (size_t r : pending)
    {
        order.Take(r);
        size_t avail;
        HFSPlusCatalogKey* pKey = (HFSPlusCatalogKey*)pCatalog->GetRecord((int)r, &avail);
        SalHfsCatalogKey key;
        // the first pass took only folder records of this class
        if (SalHfsCatalogRecordClass((const unsigned char*)pKey, avail, bSkipRootParent, &key) != SAL_HFSREC_FOLDER)
            continue;
        if (res == SAL_HFS_PENDING_LOOP)
        {
            HFSPlusCatalogFolder* folder = (HFSPlusCatalogFolder*)((char*)pKey + key.BodyOffset);
            if (!leftOutFolders.Add(folder->folderID))
                return Error(IDS_INSUFFICIENT_MEMORY, FALSE); // its contents could land at the root
            continue;
        }
        if (!ListRecord((int)r, pKey, key, rootPath, dir, pluginData, leftOutFolders))
            return FALSE;
    }
    return TRUE;
}

// One catalog record that may be listed (a folder or a file record with its whole structure, 332): listed
// under its parent's path, left out by the listing rule (329) or skipped inside a left-out folder. TRUE =
// go on, FALSE = the HFS+ listing ends. (The body of ListDirectory's loop before feature 349.)
BOOL CHFS::ListRecord(int i, HFSPlusCatalogKey* pKey, const SalHfsCatalogKey& key, char* rootPath,
                      CSalamanderDirectoryAbstract* dir, CPluginDataInterfaceAbstract*& pluginData,
                      CSalLeftOutIds& leftOutFolders)
{
    int nameLen = (int)key.NameLength;
    wchar_t fileNameW[256];
    char fileName[256 * 3 + 1]; // UTF-8 needs up to 3 bytes per UTF-16 unit (interface 104)
    CFileData fd;
    char* path = rootPath;
    union
    {
        SInt16* type;
        HFSPlusCatalogFolder* dir;
        HFSPlusCatalogFile* file;
    } rec;

    // a folder / file record with its whole structure, a name of 1..255 units (feature 223: never past
    // 'fileNameW[256]') that does not start with U+0000
    rec.type = (SInt16*)((char*)pKey + key.BodyOffset);
    // (a failed conversion is not expected: the buffer takes 255 units, CP_UTF8 without flags replaces
    // a lone surrogate - marked anyway, fail closed)
    for (int j = 0; j < nameLen; j++)
        fileNameW[j] = FromM16(pKey->nodeName.unicode[j]);
    fileNameW[nameLen] = 0;
    // format boundary (interface 104): HFS+ names are UTF-16 -> UTF-8 (see GetRootName)
    if ((WideCharToMultiByte(CP_UTF8, 0, fileNameW, nameLen + 1, fileName, sizeof(fileName), NULL, NULL) <= 0) || !fileName[0])
    {
        // feature 332: an entry whose name does not convert - skipped, the listing incomplete
        TRACE_E("CHFS::ListDirectory(): a catalog name that does not convert, skipped");
        Image->ListingLeftOut.SetIncomplete();
        return TRUE;
    }

    FixIllegalFSChars(fileName);
    // feature 327: and then the rule of every name of the image (':' '/' '<' '>' '"' '|', a
    // trailing dot, a device name - HFS+ allows them all); listed and descended with
    MakeSafeName(fileName, sizeof(fileName));
    // feature 329: inside a left-out folder - left out with it (the folder is the one reported)
    bool isFolder = *rec.type == kHFSFolderRecord;
    int under = leftOutFolders.Under(pKey->parentID, isFolder, isFolder ? rec.dir->folderID : 0);
    if (under == SAL_ISO_UNDER_NO_MEMORY)
    {
        // its contents could land at the root - the HFS+ listing ends
        Image->ListingLeftOut.SetIncomplete();
        return Error(IDS_INSUFFICIENT_MEMORY, FALSE);
    }
    if (under == SAL_ISO_UNDER_SKIPPED)
        return TRUE;
    memset(&fd, 0, sizeof(CFileData));
    // File Name
    fd.Name = SalamanderGeneral->DupStr(fileName);
    if (!fd.Name)
    {
        Image->ListingLeftOut.SetIncomplete(); // feature 329: a whole unpack then fails
        return Error(IDS_INSUFFICIENT_MEMORY, FALSE);
    }
    fd.NameLen = strlen(fd.Name);
    // Extension
    char* ext = strrchr(fd.Name, '.');
    if (ext != NULL)
        fd.Ext = ext + 1; // ".cvspass" is extension in Windows
    else
        fd.Ext = fd.Name + fd.NameLen;

    CISOImage::CFilePos* filePos = new CISOImage::CFilePos;
    if (!filePos)
    {
        SalamanderGeneral->Free(fd.Name);
        Image->ListingLeftOut.SetIncomplete();
        return Error(IDS_INSUFFICIENT_MEMORY, FALSE);
    }
    filePos->Partition = 0; // Not initialized by ctor
    filePos->Extent = i;    // # of record in catalog file
    filePos->Type = FS_TYPE_HFS;
    fd.PluginData = (DWORD_PTR)filePos;

    if (fileName[0] == '.')
    {
        // Files and folders starting with dot are hidden
        fd.Attr |= FILE_ATTRIBUTE_HIDDEN;
        fd.Hidden = 1;
    }
    // Find the parent: a listed folder, else the HFS+ root. Feature 349: the catalog is sorted by
    // parent ID, but a folder moved into a newer folder has its contents before its own record -
    // ListDirectory has taken every folder above this record first (CSalHfsFolderOrder), so a folder
    // record of the catalog is listed (or left out) here already.
    for (int j = 0; j < nFolders; j++)
    {
        if (pFolders[j]->id == pKey->parentID)
        {
            path = pFolders[j]->name;
            break;
        }
    }
    if (path == rootPath)
    {
        path = rootPath;
    }
    if (*rec.type == kHFSFolderRecord)
    {
        ConvertHFSDate(fd.LastWrite, rec.dir->contentModDate ? rec.dir->contentModDate : rec.dir->createDate);

        // feature 329: the panel listing's own rule first (sallistingname.h, CSalamanderDirectory::
        // AddDir) - a refused folder is left out with its contents and named in the report
        // (ListArchive, 328); it showed "too long path" and ended the HFS+ listing
        if (!SalListingAcceptsDirU8(path, strlen(path), fd.NameLen))
        {
            Image->ListingLeftOut.Add(path, fileName);
            SalamanderGeneral->Free(fd.Name);
            delete filePos;
            if (!leftOutFolders.Add(rec.dir->folderID))
            {
                Image->ListingLeftOut.SetIncomplete();
                return Error(IDS_INSUFFICIENT_MEMORY, FALSE);
            }
            return TRUE;
        }

        size_t strElements = strlen(path) + 1 + strlen(fileName) + 1;
        FolderInfo* fi = (FolderInfo*)malloc(sizeof(FolderInfo) + strElements - 1); // one character is already part of the FolderInfo structure
        if (fi)
        {
            fi->id = rec.dir->folderID;
            strcpy_s(fi->name, strElements, path); // due to the FolderInfo structure, the destination buffer size checking via the strcpy_s templates fails
            strcat_s(fi->name, strElements, "\\");
            strcat_s(fi->name, strElements, fileName);

            if (nFolders >= nAllocedFolders)
            {
                FolderInfo** tmp = (FolderInfo**)realloc(pFolders, (nAllocedFolders + 32) * sizeof(void*));
                if (!tmp)
                {
                    // No more memory to remember more paths
                    free(fi);
                    SalamanderGeneral->Free(fd.Name);
                    delete filePos;
                    Image->ListingLeftOut.SetIncomplete();
                    return Error(IDS_INSUFFICIENT_MEMORY, FALSE);
                }
                pFolders = tmp;
                nAllocedFolders += 32;
            }
            if (!SortByExtDirsAsFiles)
                fd.Ext = fd.Name + fd.NameLen; // directories do not have an extension
            if (dir->AddDir(path, fd, pluginData))
            {
                pFolders[nFolders++] = fi;
                return TRUE;
            }
            // feature 329: refused although the rule took it (out of memory) - the listing is kept,
            // only marked incomplete (a whole unpack fails), the folder left out with its contents
            free(fi);
            SalamanderGeneral->Free(fd.Name);
            delete filePos;
            Image->ListingLeftOut.SetIncomplete();
            Error(IDS_ERROR, FALSE);
            if (!leftOutFolders.Add(rec.dir->folderID))
                return FALSE;
            return TRUE;
        }
        else
        {
            Image->ListingLeftOut.SetIncomplete();
            Error(IDS_INSUFFICIENT_MEMORY, FALSE);
        }
    }
    else if (*rec.type == kHFSFileRecord)
    {

        if ((rec.file->userInfo.fdCreator == kSymLinkCreator) && (rec.file->userInfo.fdType == kSymLinkFileType))
        {
            // Symbolic links. The data fork contains UTF8-encoded path to target
            fd.IsLink = true;
            //        SalamanderGeneral->Free(fd.Name);
            //        delete filePos;
            //        continue;
        }
        ConvertHFSDate(fd.LastWrite, rec.file->contentModDate ? rec.file->contentModDate : rec.file->createDate);
        fd.Size.Value = FromM64(rec.file->dataFork.logicalSize);
        if (rec.file->flags & FromM16(kHFSFileLockedMask))
            fd.Attr |= FILE_ATTRIBUTE_READONLY;

        if (!fd.IsLink)
            fd.IsLink = SalamanderGeneral->IsFileLink(fd.Ext);
        // feature 329: as a folder above - a refused file is left out alone and named in the report
        if (!SalListingAcceptsFileU8(path, strlen(path), fd.Name, fd.NameLen))
            Image->ListingLeftOut.Add(path, fileName);
        else
        {
            if (dir->AddFile(path, fd, pluginData))
                return TRUE;
            Image->ListingLeftOut.SetIncomplete(); // refused although the rule took it (out of memory)
            Error(IDS_ERROR, FALSE);
        }
        SalamanderGeneral->Free(fd.Name);
        delete filePos;
        return TRUE;
    }
    SalamanderGeneral->Free(fd.Name);
    delete filePos;
    return FALSE;
}

int CHFS::UnpackFile(CSalamanderForOperationsAbstract* salamander, const char* srcPath, const char* path,
                     const char* nameInArc, const CFileData* fileData, DWORD& silent, BOOL& toSkip)
{
    CALL_STACK_MESSAGE4("CHFS::UnpackFile(, %s, %s, %s,,,)", srcPath, path, nameInArc);
    BOOL ret = UNPACK_OK;
    CISOImage::CFilePos* filePos = (CISOImage::CFilePos*)fileData->PluginData;
    size_t avail;
    HFSPlusCatalogKey* pKey = (HFSPlusCatalogKey*)pCatalog->GetRecord(filePos->Extent, &avail);
    SalHfsCatalogKey key;
    union
    {
        SInt16* type;
        HFSPlusCatalogFolder* dir;
        HFSPlusCatalogFile* file;
    } rec;

    // feature 322: the listing took only records that fit their node; checked again before the
    // file record's forks are read
    if (!SalHfsCatalogKeyView((const unsigned char*)pKey, avail, &key))
    {
        Error(IDS_ERR_HFS_BTREE_DAMAGED, FALSE);
        return UNPACK_ERROR;
    }
    rec.type = (SInt16*)((char*)pKey + key.BodyOffset);
    if (*rec.type == kHFSFileRecord && key.BodyAvail < sizeof(HFSPlusCatalogFile))
    {
        Error(IDS_ERR_HFS_BTREE_DAMAGED, FALSE);
        return UNPACK_ERROR;
    }
    // feature 338: a listed file whose record is not a file record is not extracted (it returned
    // UNPACK_OK with nothing written, so a whole unpack deleted the image)
    if (*rec.type != kHFSFileRecord)
    {
        Error(IDS_ERR_HFS_BTREE_DAMAGED, FALSE);
        return UNPACK_ERROR;
    }
    // feature 339: a file whose content is not in its data fork (HFS+ compressed, or only in its resource
    // fork) was written as an empty file counted as extracted - a whole unpack then deleted the image.
    // It is not extracted (nothing created) and counts as not extracted (SalHfsFileContentKind).
    int contentKind = SalHfsFileContentKind((const unsigned char*)rec.file, key.BodyAvail);
    if (contentKind != SAL_HFSFILE_DATA)
    {
        if (silent == 0)
        {
            int textID = contentKind == SAL_HFSFILE_RESOURCE_ONLY ? IDS_ERR_HFS_FILE_RSRC_ONLY : IDS_ERR_HFS_FILE_COMPRESSED;
            int userAction = SalamanderGeneral->DialogError(SalamanderGeneral->GetMsgBoxParent(), BUTTONS_SKIPCANCEL,
                                                            fileData->Name, LoadStrU8(textID), LoadStr(IDS_ERROR));
            if (userAction == DIALOG_CANCEL)
                return UNPACK_CANCEL;
            if (userAction == DIALOG_SKIPALL)
                silent = 1;
        }
        return UNPACK_ERROR;
    }
    if (*rec.type == kHFSFileRecord)
    {
        HFSPlusForkData* fork = &rec.file->dataFork;
        UInt64 size = fileData->Size.Value;
        DWORD attrs = fileData->Attr;
        HANDLE hFile;
        // the target path is UTF-8 and may be long (interface 104) -> heap buffer
        CU8PathBuf name;
        char fileInfo[100];
        FILETIME ft;
        BOOL bFileComplete = TRUE;
        CQuadWord qwSize;

        if (!name.IsOk())
        {
            Error(IDS_INSUFFICIENT_MEMORY);
            return UNPACK_ERROR; // this function reports errors by returning, not by throwing
        }
        lstrcpyn(name, path, U8_MAX_PATH);
        if (!AppendSafeName(name, fileData->Name, U8_MAX_PATH)) // feature 327: made safe again
        {
            Error(IDS_ERR_TOO_LONG_NAME, FALSE);
            return UNPACK_ERROR;
        }

        DWORD tmp = 0;
        for (int i = 0; i < 8; i++)
            tmp += FromM32(fork->extents[i].blockCount);

        if (tmp < FromM32(fork->totalBlocks))
        {
            // File fragmented, not supported yet
            Error(IDS_ERR_HFS_FILE_FRAGMENTED, FALSE, fileData->Name);
            return UNPACK_ERROR;
        }
        char* buffer = (char*)malloc((size_t)(min(BUFFER_SIZE, fileData->Size.Value)));
        if (!buffer)
        {
            Error(IDS_INSUFFICIENT_MEMORY, FALSE);
            return UNPACK_ERROR;
        }

        qwSize.Value = size;
        ft = fileData->LastWrite;
        GetInfo(fileInfo, &ft, fileData->Size);
        hFile = SalamanderSafeFile->SafeFileCreate(name, GENERIC_WRITE, FILE_SHARE_READ, attrs, FALSE,
                                                   SalamanderGeneral->GetMainWindowHWND(), nameInArc, fileInfo,
                                                   &silent, TRUE, &toSkip, NULL, 0, &qwSize, NULL);

        // Continue, but skip this file
        if (toSkip)
            return UNPACK_ERROR;

        // Full Cancel
        if (hFile == INVALID_HANDLE_VALUE)
            return UNPACK_CANCEL;

        CBufferedFile file(hFile, GENERIC_WRITE);
        // Set file time
        file.SetFileTime(&ft, &ft, &ft);

        for (int extInd = 0; (extInd < 8) && (size > 0) && bFileComplete; extInd++)
        {
            UInt64 extSize = VolHeader.blockSize * (UInt64)FromM32(fork->extents[extInd].blockCount);

            if (!SeekBlock(FromM32(fork->extents[extInd].startBlock)))
            {
                Error(IDS_ERR_HFS_SEEK_BLOCK_EXTR, FALSE /*quiet*/, FromM32(fork->extents[extInd].startBlock), fileData->Name);
                ret = UNPACK_CANCEL;
                bFileComplete = FALSE;
                break;
            }
            while ((size > 0) && (extSize > 0))
            {
                DWORD nbytes = (DWORD)min(BUFFER_SIZE, extSize);
                DWORD dwBytesRead;

                if (nbytes > size)
                    nbytes = (DWORD)size;

                if (!Read(buffer, nbytes, &dwBytesRead))
                {
                    ret = UNPACK_CANCEL;
                    bFileComplete = FALSE;
                    break;
                }
                if (nbytes != dwBytesRead)
                {
                    ret = UNPACK_CANCEL;
                    bFileComplete = FALSE;
                    break;
                }
                // delayedPaint==TRUE, to avoid slow-downs
                if (!salamander->ProgressAddSize(nbytes, TRUE))
                {
                    salamander->ProgressDialogAddText(LoadStr(IDS_CANCELING_OPERATION), FALSE);
                    salamander->ProgressEnableCancel(FALSE);

                    ret = UNPACK_CANCEL;
                    bFileComplete = FALSE;
                    break;
                }
                if (!file.Write(buffer, nbytes, &dwBytesRead, name, NULL))
                {
                    // Error message was already displayed by SafeWriteFile()
                    ret = UNPACK_CANCEL;
                    bFileComplete = FALSE;
                    break;
                }
                extSize -= nbytes;
                size -= nbytes;
            }
        }
        free(buffer);
        // feature 338: the eight extents ended before the file's size - the file was cut (it was kept
        // as complete); it is removed as after a read error
        if (bFileComplete && size > 0)
            bFileComplete = FALSE;

        if (!file.Close(name, NULL))
        {
            // Flushing cache may fail
            ret = UNPACK_CANCEL;
            bFileComplete = FALSE;
        }
        if (!bFileComplete)
        {
            // because it was created with the read-only attribute, we must clear
            // the R attribute so the file can be deleted
            attrs &= ~FILE_ATTRIBUTE_READONLY;
            if (!SetFileAttributesU8(name, attrs))
                Error(LoadStrU8(IDS_CANT_SET_ATTRS), GetLastError());

            // the user cancelled the operation
            // delete the incomplete file afterwards
            if (!DeleteFileU8(name))
                Error(LoadStrU8(IDS_CANT_DELETE_TEMP_FILE), GetLastError());
        }
        else
        {
            SetFileAttrs(name, attrs);
        }
        ret = SalIsoFileUnpackResult(ret, bFileComplete); // feature 338
    }
    return ret;
}

CHFS::BTree::BTree(CHFS* hfs, CHFS::HFSPlusForkData* fork, BOOL quiet)
{
    CALL_STACK_MESSAGE1("BTree::BTree(,,)");
    size_t treeSize = (size_t)FromM64(fork->logicalSize);

    pRecords = NULL;
    nRecords = 0;
    bOK = false;
    pBTreeData = NULL;

    // feature 322: the size comes from the image - an empty catalog, or one larger than its blocks
    // (the load below would fail on it anyway), is refused before it is allocated
    if (treeSize == 0 || (UInt64)FromM32(fork->totalBlocks) * hfs->VolHeader.blockSize < treeSize)
    {
        Error(IDS_ERR_HFS_BTREE_DAMAGED, quiet);
        return;
    }
    size_t loadedSize = treeSize;

    char* data = pBTreeData = (char*)malloc(treeSize);
    if (!pBTreeData)
    {
        Error(IDS_INSUFFICIENT_MEMORY, quiet);
        return;
    }

    int blocks = FromM32(fork->totalBlocks);
    int blockSize = hfs->VolHeader.blockSize;

    for (int i = 0; i < 8; i++)
    {
        DWORD dwBytesRead, extSize;
        int cnt = FromM32(fork->extents[i].blockCount);

        if (cnt > blocks)
            cnt = blocks; // safety
        if (!hfs->SeekBlock(FromM32(fork->extents[i].startBlock)))
        {
            Error(IDS_ERR_HFS_SEEK, quiet, FromM32(fork->extents[i].startBlock));
            return;
        }
        extSize = cnt * blockSize;
        if (treeSize < extSize)
            extSize = (DWORD)treeSize;
        if (!hfs->Read(data, extSize, &dwBytesRead))
            return;
        if (extSize != dwBytesRead)
        {
            Error(IDS_READERROR, quiet);
            return;
        }
        data += extSize;
        treeSize -= extSize;
        blocks -= cnt;
        if (!blocks)
            break;
    }
    if (blocks || treeSize)
    {
        Error(IDS_ERR_HFS_BTREE_FRAGMENTED, quiet);
        return;
    }

    // We require full tree with header node. Feature 322: the node size, the first leaf node, the
    // links, the record counts and the record offsets come from the image - they were used
    // unchecked (reads outside the catalog; a link back made the walk endless). The walk now
    // checks each against the loaded bytes (salhfscatalog.h). The header's leafRecords is not
    // used: buggy MagicISO 5.2 stores # of nodes and not records there, the walk counts them.
    SalHfsCatalogRecordRef* refs = NULL;
    int count = 0;
    switch (SalHfsCatalogWalk((const unsigned char*)pBTreeData, loadedSize, &refs, &count))
    {
    case SAL_HFSCAT_OK:
        break;
    case SAL_HFSCAT_NOT_HEADER:
        Error(IDS_ERR_HFS_BTREE_NODETYPE, quiet);
        return;
    case SAL_HFSCAT_NOMEM:
        Error(IDS_INSUFFICIENT_MEMORY, quiet);
        return;
    default:
        TRACE_E("CHFS::BTree::BTree(): the catalog B-tree does not fit the loaded catalog, refused");
        Error(IDS_ERR_HFS_BTREE_DAMAGED, quiet);
        return;
    }
    pRecords = refs;
    nRecords = count;

    bOK = true;
}

CHFS::BTree::~BTree()
{
    if (pBTreeData)
        free(pBTreeData);
    if (pRecords)
        free(pRecords);
}

void* CHFS::BTree::GetRecord(int ind, size_t* avail)
{
    if (ind >= 0 && ind < nRecords)
    {
        *avail = pRecords[ind].Avail;
        return pBTreeData + pRecords[ind].Offset;
    }
    *avail = 0;
    return NULL;
}