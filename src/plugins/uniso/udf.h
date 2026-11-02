// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include "fs.h"
#include "../../common/salisowalk.h" // feature 400: the walk after a folder that cannot be read

#include <set>

// ****************************************************************************
//
// CUDF
//

/* Types */
#define Uint8 BYTE
#define Uint16 WORD
#define Uint32 DWORD
#define Uint64 unsigned __int64

enum
{
    UDF_TAGID_SPARING_TABLE = 0,
    UDF_TAGID_PRI_VOL = 1,
    UDF_TAGID_ANCHOR = 2,
    UDF_TAGID_VOL = 3,
    UDF_TAGID_IMP_VOL = 4,
    UDF_TAGID_PARTITION = 5,
    UDF_TAGID_LOGVOL = 6,
    UDF_TAGID_UNALLOC_SPACE = 7,
    UDF_TAGID_TERM = 8,
    UDF_TAGID_LOGVOL_INTEGRITY = 9,
    UDF_TAGID_FSD = 256,
    UDF_TAGID_FID = 257,
    UDF_TAGID_ALLOCEXTENT = 258,
    UDF_TAGID_INDIRECTENTRY = 259,
    UDF_TAGID_ICB_TERM = 260,
    UDF_TAGID_FENTRY = 261,
    UDF_TAGID_EXTATTR_HDR = 262,
    UDF_TAGID_UNALL_SP_ENTRY = 263,
    UDF_TAGID_SPACE_BITMAP = 264,
    UDF_TAGID_PART_INTEGRETY = 265,
    UDF_TAGID_EXTFENTRY = 266,
    UDF_TAGID_UNKNOWN = 0xFFFF
};

/* short/long/ext extent have flags encoded in length */
#define UDF_EXT_ALLOCATED 0
#define UDF_EXT_FREED 1
#define UDF_EXT_ALLOCATED_BUT_NOT_USED 1
#define UDF_EXT_FREE 2
#define UDF_EXT_REDIRECT 3

typedef Uint16 UDF_TAG_ID;

class CUDF : public CUnISOFSAbstract
{
public:
    struct CTimeStamp
    {
        Uint16 TypeAndTimezone;
        Uint16 Year;
        Uint8 Month;
        Uint8 Day;
        Uint8 Hour;
        Uint8 Minute;
        Uint8 Second;
        Uint8 Centiseconds;
        Uint8 HundredsofMicroseconds;
        Uint8 Microseconds;
    };

protected:
    struct CExtentAd
    {
        DWORD Length;
        DWORD Location;
    };

    ///
    struct CICBTag
    {
        Uint8 FileType;
        Uint16 Flags;
        Uint16 Strategy;
        Uint16 StrategyParametr;
        Uint16 Entries; // Maximum Number of Entries
    };

    ///
    struct CICB
    {
        Uint32 Location;
        Uint16 Partition;
    };

    ///
    struct CAD
    {
        Uint8 Flags;
        Uint32 Location;
        Uint32 Length;
        Uint16 Partition;
        Uint16 Offset; // Offset within sector; Non-zero only for data inlined in tag data
    };

    // feature 364: a folder as the walk reads it - its descriptors (up to 32, SAL_ISO_UDF_FOLDER_MAX_EXTENTS of
    // salisoudfentry.h, as a file's), the leading recorded extents walked and their bytes, the embedded data's
    // offset in the entry's sector (0 for extents), and whether the walked bytes cover the folder's Information
    // Length (false marks the listing incomplete, feature 330)
    struct CUDFFolder
    {
        CAD Ext[32];
        int Count;
        Uint64 Length;
        Uint16 Offset;
        BOOL Whole;
    };

    ///
    struct CPartition
    {
        int Valid;
        char VolumeDesc[128];
        Uint16 Flags;
        Uint16 Number;
        char Contents[32];
        Uint32 AccessType;
        Uint32 Start;
        Uint32 Length;
    };

    struct CCharSpec
    {
        Uint8 CharacterSetType;
        BYTE CharacterSetInfo[63];
    };

    struct CEntityID
    {
        Uint8 Flags;
        char Identifier[23];
        char Suffix[8];
    };

    struct CDescriptorTag
    {
        UDF_TAG_ID ID;
        Uint16 Version;
        Uint8 Checksum;
        BYTE Reserved;
        Uint16 SerialNumber;
        Uint16 CRC;
        Uint16 CRCLength;
        Uint32 TagLocation;
    };

    struct CPrimaryVolumeDescriptor
    {
        CDescriptorTag DescriptorTag;
        Uint32 VolumeDescriptorSequenceNumber;
        Uint32 PrimaryVolumeDescriptorNumber;
        char VolumeIdentifier[32];
        Uint16 VolumeSequenceNumber;
        Uint16 MaximumVolumeSequenceNumber;
        Uint16 InterchangeLevel;
        Uint16 MaximumInterchangeLevel;
        Uint32 CharacterSetList;
        Uint32 MaximumCharacterSetList;
        char VolumeSetIdentifier[128];
        CCharSpec DescriptorCharacterSet;
        CCharSpec ExplanatoryCharacterSet;
        CExtentAd VolumeAbstract;
        CExtentAd VolumeCopyrightNotice;
        CEntityID ApplicationIdentifier;
        CTimeStamp RecordingDateandTime;
        CEntityID ImplementationIdentifier;
        BYTE ImplementationUse[64];
        Uint32 PredecessorVolumeDescriptorSequenceLocation;
        Uint16 Flags;
        BYTE Reserved[22];
    };

    // Anchor Volume Descriptor Pointer
    struct CAVDP
    {
        CExtentAd MVDS;
        CExtentAd RVDS;
    };

    // Partition Descriptor
    struct CPD
    {
        Uint16 Flags;
        Uint16 PartitionNumber;
        Uint32 Start;
        Uint32 Length;
    };

    // Logical Volume Descriptor
    struct CLVD
    {
        Uint32 VDSN; // Volume Descriptor Sequence Number
        Uint32 LogicalBlockSize;
        CAD FSD; // File Set Descriptor
        BYTE LogicalVolumeIdentifier[128];
    };

    enum EPartitionMapping
    {
        mapPhysical,
        mapVirtual,
        mapSparable,
        mapMetadata
    };

    // Partition Map
    struct CPartitionMap
    {
        EPartitionMapping Type;
        WORD VolumeSequenceNumber;
        WORD PartitionNumber;
        // feature 377: mapMetadata only - the metadata file's block (minus ExtentOffset); its entry is read
        // in ReadSupportingTables, once the whole descriptor sequence (also a later partition descriptor) is read
        Uint32 MetadataFileLocation;
        // feature 377 (review 1): TRUE only for a map recognised as "*UDF Metadata Partition" - Type is not set
        // for an unknown map, so the read in ReadSupportingTables goes by this, not by Type alone
        BOOL HasMetadataFile;
    };

    struct CPartitionMapping
    {
        EPartitionMapping Type;
        Uint64 Entries;
        Uint32 Length;
        Uint32* Translation;
        BYTE* VAT;
        CAD MetadataICBs[32];
        int nMetadataICBs; // # of used entries in MetadataICBs
    };

    struct CFileEntry
    {
        CICBTag ICBTag;
        CTimeStamp mtime;
        Uint64 InformationLength;
        Uint32 L_EA;
        Uint32 L_AD;
    };

    CPrimaryVolumeDescriptor PVD;

    CAVDP AVDP;
    CPD PD;
    CLVD LVD;

    DWORD ExtentOffset;

    int TrackTryingToOpen;

    TIndirectArray<CPartitionMap> PartitionMaps;
    CPartitionMapping PartitionMapping;

public:
    // feature 358: Open found a UDF volume (its descriptors were read) whose virtual partition's VAT is
    // missing or unreadable - the volume does not open; a UDF + ISO 9660 hybrid marks its listing incomplete
    // from this (the anchor at 256, 330's sign of a UDF part, may be missing on a sequential medium)
    BOOL VatMissing;
    // feature 378: Open found the volume's logical volume descriptor and refused it - its partition maps do not
    // fit the sector or the map table; read like VatMissing (review 1: without the anchor at 256 a hybrid's
    // listing was not marked and a whole unpack deleted the image)
    BOOL MapsRefused;
    // feature 400: the listing walk - later folders are descended after a folder that cannot be read
    // (only out of memory stops it), its error box is shown once, and each folder (its ICB) is walked
    // once - a crafted image can point a folder back to itself or an ancestor (as CISO9660, 328)
    SalIsoWalk Walk;
    std::set<unsigned long long>* Visited;

    CUDF(CISOImage* image, DWORD extent, int trackno);
    virtual ~CUDF();
    // methods

    virtual BOOL Open(BOOL quiet);
    virtual BOOL DumpInfo(FILE* outStream);
    virtual BOOL ListDirectory(char* path, int session,
                               CSalamanderDirectoryAbstract* dir, CPluginDataInterfaceAbstract*& pluginData);
    virtual int UnpackFile(CSalamanderForOperationsAbstract* salamander, const char* srcPath, const char* path,
                           const char* nameInArc, const CFileData* fileData, DWORD& silent, BOOL& toSkip);

protected:
    BOOL ReadBlockPhys(Uint32 lbNumber, size_t blocks, unsigned char* data);
    BOOL ReadBlockLog(Uint32 lbNumber, size_t blocks, unsigned char* data);

    // feature 329: AddFileDir results - as CISO9660's (328): listed, left out (refused by the listing:
    // noted on the image, the walk goes on), failed (the directory ends)
    enum
    {
        ADD_FAILED = 0,
        ADD_LISTED = 1,
        ADD_LEFT_OUT = 2
    };
    int AddFileDir(const char* path, char* fileName, BYTE fileChar, CAD* icb,
                   CSalamanderDirectoryAbstract* dir, CPluginDataInterfaceAbstract*& pluginData);

    int FindPartition(int partnum, CUDF::CPartition* part);

    int ScanDir(const CUDFFolder& folder, char* path,
                CSalamanderDirectoryAbstract* dir, CPluginDataInterfaceAbstract*& pluginData);
    BOOL ReadFolderWindow(const CUDFFolder& folder, Uint32 block, Uint8* window, Uint32& lbNum);
    void WalkOutOfMemory();          // feature 400
    int VisitFolder(const CAD& icb); // feature 400: 1 first time, 0 met again, -1 out of memory

    void ReadExtentAd(BYTE sector[], CExtentAd* extent);
    void ReadEntityID(BYTE sector[], CEntityID* entityID);
    void ReadAVDP(BYTE sector[], CAVDP* avdp);
    void ReadPD(BYTE sector[], CPD* pd);
    BOOL ReadLVD(BYTE sector[], CLVD* lvd); // feature 378: FALSE = the partition maps do not fit
    void ReadDescriptorTag(BYTE sector[], CDescriptorTag* tag);
    int ReadPartitionMap(BYTE data[]);
    int ShortAD(Uint8* data, CUDF::CAD* ad, WORD partNumber);
    int LongAD(Uint8* data, CUDF::CAD* ad);
    int ExtAD(Uint8* data, CUDF::CAD* ad);

    void ReadICBTag(BYTE data[], CICBTag* icb);
    int MapICB(CUDF::CAD icb, CICBTag* icbTag, CUDFFolder* folder);
    int MapICB(CUDF::CAD icb, CFileEntry* fe);
    // the descriptors of a file entry: their count, -1 for embedded data, UDF_FE_REFUSED for an entry refused by
    // salisoudfentry.h (feature 361: a reserved descriptor type hung the walk, a large L_EA / L_AD read past the
    // sector)
    enum
    {
        UDF_FE_REFUSED = -2
    };
    int ReadFileEntry(Uint8* data, bool bEFE, Uint16 part, CICBTag* icbTag, CUDF::CAD* ad, int maxAds);
    int ReadFileIdentifier(Uint8* sector, unsigned int held, Uint8* fileChar, char* fileName, CAD* fileICB);

    void ReadStrategy(BYTE data[], Uint16* entries, Uint16* strategy, Uint16* strategyParam);

    BOOL ReadSupportingTables(BOOL quiet);
    int CheckForVAT(BYTE sector[], bool bEFE, CPartitionMapping* pm, BOOL quiet);

    void ReadFileEntry(BYTE sector[], bool bEFE, CFileEntry* fe);
    int ReadAllocDesc(BYTE data[], DWORD avail, CFileEntry* fe, BYTE* vat, DWORD vatLength, DWORD* o);

    int ReadVAT(BYTE fileEntry[], bool bEFE, BYTE** vat, DWORD* length, BOOL quiet);
    Uint32 LogSector(Uint32 lbNum, Uint16 part);

    friend class CUDFISO;
};
