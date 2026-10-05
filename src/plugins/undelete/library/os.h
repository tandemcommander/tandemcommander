// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

extern CSalamanderGeneralAbstract* SalamanderGeneral;

// ****************************************************************************
//
//  Types
//

enum VolumeType
{
    VT_DRIVE_UNKNOWN = DRIVE_UNKNOWN,
    VT_DRIVE_NO_ROOT_DIR = DRIVE_NO_ROOT_DIR,
    VT_DRIVE_REMOVABLE = DRIVE_REMOVABLE,
    VT_DRIVE_FIXED = DRIVE_FIXED,
    VT_DRIVE_REMOTE = DRIVE_REMOTE,
    VT_DRIVE_CDROM = DRIVE_CDROM,
    VT_DRIVE_RAMDISK = DRIVE_RAMDISK,
};

// ***************************************************************************
//
//  Global variables
//
extern BOOL IsWindowsNT;
extern BOOL IsWindows2000AndLater;
extern BOOL IsWindows95;
extern BOOL IsWindows95OSR2AndLater;
extern BOOL IsWindowsVistaAndLater;

// ***************************************************************************
//
//  Auxiliary functions
//
template <typename CHAR>
class OS
{
private:
    // feature 114: the volume functions are called on the W layer (os.cpp) - the code-page
    // entry points resolved here before (FindFirstVolumeMountPointA, GetVolumePathNamesForVolumeNameA,
    // ...) took and returned UTF-8 paths as code-page text
    static HMODULE ImageResDLL;

    static BOOL OS_InitShell32Bindings();
    static void OS_ReleaseShell32Bindings();

    static void OS_LoadImageResModule();
    static void OS_FreeImageResModule();

    static HICON OS_GetFileOrPathIconAux(const CHAR* path, BOOL large);

public:
    // module initialization
    static BOOL OS_InitLibraryData();
    static void OS_ReleaseLibraryData();

    // volume mount point query
    static BOOL OS_GetVolumeNameForVolumeMountPointExists();
    static BOOL OS_GetVolumeNameForVolumeMountPoint(const CHAR* VolumeMountPoint,
                                                    CHAR* VolumeName, DWORD BufferLength);

    // volume enumeration
    static BOOL OS_VolumeEnumExists();
    static HANDLE OS_FindFirstVolume(CHAR* VolumeName, DWORD BufferLength);
    static BOOL OS_FindNextVolume(HANDLE FindVolume, CHAR* VolumeName, DWORD BufferLength);
    static BOOL OS_FindVolumeClose(HANDLE FindVolume);

    // volume mount point enumeration
    static BOOL OS_VolumeMountPointEnumExists();
    static HANDLE OS_FindFirstVolumeMountPoint(const CHAR* RootPathName, CHAR* VolumeMountPoint, DWORD BufferLength);
    static BOOL OS_FindNextVolumeMountPoint(HANDLE FindVolumeMountPoint, CHAR* VolumeMountPoint, DWORD BufferLength);
    static BOOL OS_FindVolumeMountPointClose(HANDLE FindVolumeMountPoint);

    // logical drives query
    static BOOL OS_GetLogicalDriveStringsExists();
    static DWORD OS_GetLogicalDriveStrings(size_t bufsize, CHAR* buffer);

    // disk free space query
    static BOOL OS_GetDiskFreeSpaceExExists();
    static BOOL OS_GetDiskFreeSpaceEx(const CHAR* DirectoryName, ULARGE_INTEGER* FreeBytesAvailableToCaller,
                                      ULARGE_INTEGER* TotalNumberOfBytes, ULARGE_INTEGER* TotalNumberOfFreeBytes);

    // disk name (mount location) query
    static BOOL OS_GetVolumePathNamesForVolumeNameExists();
    static BOOL OS_GetVolumePathNamesForVolumeName(const CHAR* VolumeName, CHAR* VolumePathNames,
                                                   DWORD BufferLength, DWORD* ReturnLength);

    // auxiliary disk functions
    static VolumeType OS_GetVolumeType(const CHAR* root);
    static DWORD OS_GetDriveFormFactor(const CHAR* drive);

    static void OS_GetDisplayNameFromSystem(const CHAR* root, CHAR* volumeName, int volumeNameBufSize);
    static void OS_GetVolumeName(const CHAR* root, CHAR* volumeName);
    static BOOL OS_GetVolumeInfo(const CHAR* rootPathName, CHAR* volumeNameBuffer,
                                 DWORD volumeNameSize, DWORD* volumeSerialNumber,
                                 DWORD* maximumComponentLength, DWORD* fileSystemFlags,
                                 CHAR* fileSystemNameBuffer, DWORD fileSystemNameSize);
    static HICON OS_GetDriveIcon(const CHAR* root, UINT type, BOOL accessible, BOOL large);
    static HICON OS_GetEmptyRecycleBinIcon(BOOL large);
    static HANDLE OS_CreateFile(const CHAR* fileName, DWORD desiredAccess, DWORD shareMode,
                                SECURITY_ATTRIBUTES* securityAttributes, DWORD creationDisposition,
                                DWORD flagsAndAttributes, HANDLE templateFile);
};

// ***************************************************************************
//
//  Template methods implementation
//
BOOL OS_InitOSVersion();

template <typename CHAR>
BOOL OS<CHAR>::OS_InitLibraryData()
{
    if (!OS_InitOSVersion())
        return FALSE;
    if (!OS_InitShell32Bindings())
        return FALSE;
    OS_LoadImageResModule();

    if (!String<char>::InitStr())
        return FALSE;
    if (!String<wchar_t>::InitStr())
        return FALSE;

    return TRUE;
}

template <typename CHAR>
void OS<CHAR>::OS_ReleaseLibraryData()
{
    String<char>::ReleaseStr();
    String<wchar_t>::ReleaseStr();
    OS_FreeImageResModule();
    OS<CHAR>::OS_ReleaseShell32Bindings();
}

template <typename CHAR>
void OS<CHAR>::OS_LoadImageResModule()
{
    if (IsWindowsVistaAndLater)
        ImageResDLL = LoadLibraryExA("imageres.dll", NULL, LOAD_LIBRARY_AS_DATAFILE);
}

template <typename CHAR>
void OS<CHAR>::OS_FreeImageResModule()
{
    if (ImageResDLL != NULL)
    {
        FreeLibrary(ImageResDLL);
        ImageResDLL = NULL;
    }
}

// feature 114: the volume wrappers exist for CHAR = char only, in UTF-8, on the W functions
// (os.cpp). Paths are converted plainly (no "\?\" prefix: the volume functions take mount
// points and volume GUID paths as they are); a result that does not fit the caller's buffer is
// refused, never cut.
template <>
BOOL OS<char>::OS_GetVolumeNameForVolumeMountPoint(const char* VolumeMountPoint, char* VolumeName, DWORD BufferLength);
template <>
HANDLE OS<char>::OS_FindFirstVolume(char* VolumeName, DWORD BufferLength);
template <>
BOOL OS<char>::OS_FindNextVolume(HANDLE FindVolume, char* VolumeName, DWORD BufferLength);
template <>
BOOL OS<char>::OS_FindVolumeClose(HANDLE FindVolume);
template <>
HANDLE OS<char>::OS_FindFirstVolumeMountPoint(const char* RootPathName, char* VolumeMountPoint, DWORD BufferLength);
template <>
BOOL OS<char>::OS_FindNextVolumeMountPoint(HANDLE FindVolumeMountPoint, char* VolumeMountPoint, DWORD BufferLength);
template <>
BOOL OS<char>::OS_FindVolumeMountPointClose(HANDLE FindVolumeMountPoint);
template <>
DWORD OS<char>::OS_GetLogicalDriveStrings(size_t bufsize, char* buffer);
template <>
BOOL OS<char>::OS_GetDiskFreeSpaceEx(const char* DirectoryName, ULARGE_INTEGER* FreeBytesAvailableToCaller,
                                     ULARGE_INTEGER* TotalNumberOfBytes, ULARGE_INTEGER* TotalNumberOfFreeBytes);
template <>
BOOL OS<char>::OS_GetVolumePathNamesForVolumeName(const char* VolumeName, char* VolumePathNames,
                                                  DWORD BufferLength, DWORD* ReturnLength);

// feature 114: GetVolumePathName for a UTF-8 path (the W function); FALSE when the result does
// not fit 'rootSize' bytes. The A function read a UTF-8 path in the code page: a path through a
// mount folder named outside ASCII "did not exist", and the volume of its nearest existing parent
// came back - another volume than the one the path is on.
BOOL UndGetVolumePathNameU8(const char* path, char* root, DWORD rootSize);

template <typename CHAR>
void OS<CHAR>::OS_GetVolumeName(const CHAR* root, CHAR* volumeName)
{
    CALL_STACK_MESSAGE1("GetVolumeName(, )");
    volumeName[0] = 0;
    switch (OS_GetVolumeType(root))
    {
    case VT_DRIVE_REMOVABLE: // floppy disks, we will detect 3.5", 5.25", 8", or unknown
    {
        DWORD medium = OS_GetDriveFormFactor(root);
        switch (medium)
        {
        case 350:
            String<CHAR>::StrCpy(volumeName, String<CHAR>::LoadStr(IDS_FLOPPY350));
            break;
        case 525:
            String<CHAR>::StrCpy(volumeName, String<CHAR>::LoadStr(IDS_FLOPPY525));
            break;
        case 800:
            String<CHAR>::StrCpy(volumeName, String<CHAR>::LoadStr(IDS_FLOPPY800));
            break;
        default:
        {
            OS_GetDisplayNameFromSystem(root, volumeName, MAX_PATH);
            if (volumeName[0] == 0)
                String<CHAR>::StrCpy(volumeName, String<CHAR>::LoadStr(IDS_REMOVABLE_DISK));
            else
                SalamanderGeneral->DuplicateAmpersands(volumeName, MAX_PATH);
            break;
        }
        }
        break;
    }

    case VT_DRIVE_FIXED:
    case VT_DRIVE_RAMDISK:
    {
        DWORD dummy;
        CHAR fsName[MAX_PATH];
        if (OS_GetVolumeInfo(root, volumeName, MAX_PATH, NULL, &dummy,
                             &dummy, fsName, MAX_PATH))
        {
            // escape '&', so it doesn't display as underline
            SalamanderGeneral->DuplicateAmpersands(volumeName, MAX_PATH);
            if (volumeName[0] == 0)
                String<CHAR>::StrCpy(volumeName, String<CHAR>::LoadStr(IDS_LOCAL_DISK));
        }
        else
        {
            volumeName[0] = 0;
        }
        break;
    }

    case VT_DRIVE_CDROM:
    {
        DWORD dummy;
        CHAR fileSystem[11];
        if (!OS_GetVolumeInfo(root, volumeName, MAX_PATH, NULL, &dummy, &dummy, fileSystem, 10))
            volumeName[0] = 0; // error GetVolumeInformation
        if (volumeName[0] == 0)
            OS_GetDisplayNameFromSystem(root, volumeName, MAX_PATH);
        if (volumeName[0] == 0)
            String<CHAR>::StrCpy(volumeName, String<CHAR>::LoadStr(IDS_COMPACT_DISK));
    }
    }
}

template <typename CHAR>
HICON OS<CHAR>::OS_GetDriveIcon(const CHAR* root, UINT type, BOOL accessible, BOOL large)
{
    CALL_STACK_MESSAGE5("GetDriveIcon(%s, %u, %d, %d)", root, type, accessible, large);
    int id;
    if (IsWindowsVistaAndLater && ImageResDLL != NULL)
    {
        switch (type)
        {
        case DRIVE_REMOVABLE: // icons 3.5, 5.25
        {
            HICON i = OS_GetFileOrPathIconAux(root, large);
            if (i != NULL)
                return i;
            id = 28; // 3 1/2 " drive
            break;
        }

        case DRIVE_REMOTE:
            id = (accessible ? 33 : 31);
            break;
        case DRIVE_CDROM:
            id = 30;
            break;
        case DRIVE_RAMDISK:
            id = 34;
            break;

        default:
        {
            id = 32;
            if (type == DRIVE_FIXED && root[1] == TEXT(':'))
            {
                char win[MAX_PATH];
                if (GetWindowsDirectoryA(win, MAX_PATH) && win[1] == ':' && CHAR(win[0]) == root[0])
                    id = 36;
            }
            break;
        }
        }
        return (HICON)LoadImage(ImageResDLL,
                                MAKEINTRESOURCE(id), IMAGE_ICON,
                                large ? 32 : 16, //ICON_CX,
                                large ? 32 : 16, //ICON_CY,
                                SalamanderGeneral->GetIconLRFlags());
    }
    else
    {
        switch (type)
        {
        case DRIVE_REMOVABLE: // icons 3.5, 5.25
        {
            HICON i = OS_GetFileOrPathIconAux(root, large);
            if (i != NULL)
                return i;
            id = 7; // 3 1/2 " drive
            break;
        }

        case DRIVE_REMOTE:
            id = (accessible ? 10 : 11);
            break;
        case DRIVE_CDROM:
            id = 12;
            break;
        case DRIVE_RAMDISK:
            id = 13;
            break;
        default:
            id = 9;
            break;
        }
        return (HICON)LoadImage(GetModuleHandle(TEXT("shell32.dll")),
                                MAKEINTRESOURCE(id), IMAGE_ICON,
                                large ? 32 : 16, //ICON_CX,
                                large ? 32 : 16, //ICON_CY,
                                SalamanderGeneral->GetIconLRFlags());
    }
}

template <typename CHAR>
HICON OS<CHAR>::OS_GetEmptyRecycleBinIcon(BOOL large)
{
    CALL_STACK_MESSAGE2("GetEmptyRecycleBinIcon(%d)", large);
    if (IsWindowsVistaAndLater && ImageResDLL != NULL)
    {
        return (HICON)LoadImage(ImageResDLL,
                                MAKEINTRESOURCE(55), IMAGE_ICON,
                                large ? 32 : 16, //ICON_CX,
                                large ? 32 : 16, //ICON_CY,
                                SalamanderGeneral->GetIconLRFlags());
    }
    else
    {
        return (HICON)LoadImage(GetModuleHandle(TEXT("shell32.dll")),
                                MAKEINTRESOURCE(32), IMAGE_ICON,
                                large ? 32 : 16, //ICON_CX,
                                large ? 32 : 16, //ICON_CY,
                                SalamanderGeneral->GetIconLRFlags());
    }
}

// ****************************************************************************
//
// Fragment from Microsoft Knowledge Base, detecting information about floppy drive
// media type (3.5", 5.25", 8")
//

//  Define from <vwin32.h> header file - part of the Windows 95 DDK.

#define VWIN32_DIOC_DOS_IOCTL 1
#define VWIN32_DIOC_DOS_INT25 2
#define VWIN32_DIOC_DOS_INT26 3
#define VWIN32_DIOC_DOS_DRIVEINFO 6

typedef struct _DIOC_REGISTERS
{
    DWORD reg_EBX;
    DWORD reg_EDX;
    DWORD reg_ECX;
    DWORD reg_EAX;
    DWORD reg_EDI;
    DWORD reg_ESI;
    DWORD reg_Flags;
} DIOC_REGISTERS, *PDIOC_REGISTERS;

// Intel x86 processor status flags
#define CARRY_FLAG 0x1

#pragma pack(1)
typedef struct _DOSDPB
{
    BYTE specialFunc;    //
    BYTE devType;        //
    WORD devAttr;        //
    WORD cCyl;           // number of cylinders
    BYTE mediaType;      //
    WORD cbSec;          // Bytes per sector
    BYTE secPerClus;     // Sectors per cluster
    WORD cSecRes;        // Reserved sectors
    BYTE cFAT;           // FATs
    WORD cDir;           // Root Directory Entries
    WORD cSec;           // Total number of sectors in image
    BYTE bMedia;         // Media descriptor
    WORD secPerFAT;      // Sectors per FAT
    WORD secPerTrack;    // Sectors per track
    WORD cHead;          // Heads
    DWORD cSecHidden;    // Hidden sectors
    DWORD cTotalSectors; // Total sectors, if cbSec is zero
    BYTE reserved[6];    //
} DOSDPB, *PDOSDPB;
#pragma pack()

//  GetDriveFormFactor returns the drive form factor.
//
//  It returns 350 if the drive is a 3.5" floppy drive.
//  It returns 525 if the drive is a 5.25" floppy drive.
//  It returns 800 if the drive is a 8" floppy drive.
//  It returns   0 on error.
//
//  drive is C:\, D:\, \\?\Volume{GUID} (win2k and above only) etc.

template <typename CHAR>
DWORD OS<CHAR>::OS_GetDriveFormFactor(const CHAR* drive)
{
    CALL_STACK_MESSAGE2("GetDriveFormFactor(%s)", drive);
    HANDLE h;
    DWORD dwRc = 0;

    if (GetVersion() >= 0x80000000) // Windows 9x, ME
    {
        // On Windows 95, use the technique described in
        // the Knowledge Base article Q125712 and in MSDN under
        // "Windows 95 Guide to Programming", "Using Windows 95
        // features", "Using VWIN32 to Carry Out MS-DOS Functions".

        int iDrive;
        char letter = (char)drive[0];
        if (letter >= 'a' && letter <= 'z')
            iDrive = letter - 'a' + 1;
        else if (letter >= 'A' && letter <= 'Z')
            iDrive = letter - 'A' + 1;

        h = CreateFileA("\\\\.\\VWIN32", 0, 0, 0, 0, FILE_FLAG_DELETE_ON_CLOSE, 0);

        if (h != INVALID_HANDLE_VALUE)
        {
            DWORD cb;
            DIOC_REGISTERS reg;
            DOSDPB dpb;

            dpb.specialFunc = 0; // return default type; do not hit disk

            reg.reg_EBX = iDrive;                 // BL = drive number (1-based)
            reg.reg_EDX = (DWORD)(DWORD_PTR)&dpb; // DS:EDX -> DPB // cast is OK, we will not run this on x64
            reg.reg_ECX = 0x0860;                 // CX = Get DPB
            reg.reg_EAX = 0x440D;                 // AX = Ioctl
            reg.reg_Flags = CARRY_FLAG;           // assume failure

            // Make sure both DeviceIoControl and Int 21h succeeded.
            if (DeviceIoControl(h, VWIN32_DIOC_DOS_IOCTL, &reg, sizeof(reg), &reg, sizeof(reg), &cb, 0) &&
                !(reg.reg_Flags & CARRY_FLAG))
            {
                switch (dpb.devType)
                {
                case 0: // 5.25 360K floppy
                case 1: // 5.25 1.2MB floppy
                    dwRc = 525;
                    break;

                case 2: // 3.5  720K floppy
                case 7: // 3.5  1.44MB floppy
                case 9: // 3.5  2.88MB floppy
                    dwRc = 350;
                    break;

                case 3: // 8" low-density floppy
                case 4: // 8" high-density floppy
                    dwRc = 800;
                    break;
                }
            }

            NOHANDLES(CloseHandle(h));
        }
    }
    else
    {
        // On Windows NT, use the technique described in the Knowledge
        // Base article Q115828 and in the "FLOPPY" SDK sample.
        if ((char)(drive[1]) == ':' && (char)(drive[2]) == '\\')
        {
            char tsz[8];
            sprintf(tsz, "\\\\.\\%c:", (char)(drive[0]));
            h = HANDLES_Q(CreateFileA(tsz, 0, FILE_SHARE_WRITE, 0, OPEN_EXISTING, 0, 0));
        }
        else
        {
            // feature 114: an unused copy of 'drive' into CHAR[100] is gone - a volume GUID path
            // fits, but a mount folder's path of 100+ bytes overran the stack
            h = OS_CreateFile(const_cast<CHAR*>(drive), 0, FILE_SHARE_WRITE, 0, OPEN_EXISTING, 0, 0);
        }

        if (h != INVALID_HANDLE_VALUE)
        {
            DISK_GEOMETRY Geom[20];
            DWORD cb;

            if (DeviceIoControl(h, IOCTL_DISK_GET_MEDIA_TYPES, 0, 0, Geom, sizeof(Geom), &cb, 0) && cb > 0)
            {
                switch (Geom[0].MediaType)
                {
                case F5_1Pt2_512: // 5.25 1.2MB floppy
                case F5_360_512:  // 5.25 360K  floppy
                case F5_320_512:  // 5.25 320K  floppy
                case F5_320_1024: // 5.25 320K  floppy
                case F5_180_512:  // 5.25 180K  floppy
                case F5_160_512:  // 5.25 160K  floppy
                    dwRc = 525;
                    break;

                case F3_1Pt44_512: // 3.5 1.44MB floppy
                case F3_2Pt88_512: // 3.5 2.88MB floppy
                case F3_20Pt8_512: // 3.5 20.8MB floppy
                case F3_720_512:   // 3.5 720K   floppy
                    dwRc = 350;
                    break;
                }
            }
            HANDLES(CloseHandle(h));
        }
    }
    return dwRc;
}
