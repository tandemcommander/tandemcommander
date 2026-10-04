// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salfileio.h
//
// Central W-API file-I/O layer (feature 004-long-paths-unicode, R2).
//
// Every function takes UTF-8 display-form paths (no \\?\ prefix),
// converts to UTF-16, normalizes to extended-length form and calls
// the W API - so long paths and full Unicode names work regardless
// of the LongPathsEnabled registry state. GetLastError() is preserved
// from the underlying API call; unconvertible paths fail with
// ERROR_INVALID_NAME.
//
// Handle-returning wrappers register with the HANDLES tracker.
// Close find handles with HANDLES(FindClose(h)), file handles with
// HANDLES(CloseHandle(h)) as usual.
//

// enumeration: u8pattern is a directory pattern like "C:\\dir\\*";
// names come back wide in data->cFileName (transcode via SalWToU8)
HANDLE SalFindFirstFile(const char* u8pattern, WIN32_FIND_DATAW* data);
// plain ::FindNextFileW re-export for call-site symmetry
BOOL SalFindNextFile(HANDLE find, WIN32_FIND_DATAW* data);

// recommended UTF-8 buffer sizes for a single find-data record
#define SAL_FIND_NAME_U8 (3 * MAX_PATH)  // cFileName worst case (3 B per WCHAR)
#define SAL_FIND_DOSNAME_U8 (3 * 14 + 2) // cAlternateFileName (8.3)

// fills the legacy-shaped 'a' view (attributes/times/sizes for helpers that
// take WIN32_FIND_DATA*) + UTF-8 name buffers from wide find data; names
// containing unpaired surrogates convert losslessly as WTF-8 (feature 066),
// so operations address the true on-disk name; a too-small target buffer
// yields an EMPTY string (never a truncated identity);
// a->cFileName/cAlternateFileName are always emptied
void SalConvertFindDataW(const WIN32_FIND_DATAW* w, WIN32_FIND_DATA* a,
                         char* nameU8, int nameU8Size, char* dosNameU8, int dosNameU8Size);

HANDLE SalCreateFile(const char* u8path, DWORD desiredAccess, DWORD shareMode,
                     LPSECURITY_ATTRIBUTES securityAttributes, DWORD creationDisposition,
                     DWORD flagsAndAttributes, HANDLE templateFile);

// NOHANDLES variant for call sites that register the handle with
// HANDLES_ADD later (or never) - no tracker registration happens here
HANDLE SalCreateFileNH(const char* u8path, DWORD desiredAccess, DWORD shareMode,
                       LPSECURITY_ATTRIBUTES securityAttributes, DWORD creationDisposition,
                       DWORD flagsAndAttributes, HANDLE templateFile);

//*****************************************************************************
//
// SalCreateProcess
//
// CreateProcessW with UTF-8 inputs (feature 004, FR-011): the command line and
// the working directory may contain names that the active code page cannot
// represent, so the A variant would launch the wrong (or no) file. 'siA' is the
// caller's STARTUPINFO - its non-string fields are copied; lpDesktop/lpTitle
// are not supported (must be NULL). The returned handles are registered with
// the HANDLES tracker exactly like HANDLES(CreateProcess(...)) did.
//
BOOL SalCreateProcess(const char* u8AppName, const char* u8CmdLine,
                      LPSECURITY_ATTRIBUTES processAttrs, LPSECURITY_ATTRIBUTES threadAttrs,
                      BOOL inheritHandles, DWORD creationFlags, LPVOID environment,
                      const char* u8CurrentDir, STARTUPINFOA* siA, PROCESS_INFORMATION* pi);

// ShellExecuteExW with UTF-8 inputs (feature 004, FR-011). The A structure is
// taken as input; its string fields (lpVerb/lpFile/lpParameters/lpDirectory/
// lpClass) are converted from UTF-8; other fields are copied through and the
// output fields (hInstApp, hProcess, ...) are copied back.
BOOL SalShellExecuteEx(SHELLEXECUTEINFOA* seiA);

BOOL SalDeleteFile(const char* u8path);
BOOL SalRemoveDirectory(const char* u8path);
BOOL SalCreateDirectory(const char* u8path, LPSECURITY_ATTRIBUTES securityAttributes);
BOOL SalMoveFile(const char* u8from, const char* u8to);
BOOL SalMoveFileEx(const char* u8from, const char* u8to, DWORD flags);
BOOL SalCopyFile(const char* u8from, const char* u8to, BOOL failIfExists);

// W-backed GetShortPathName with UTF-8 in/out; returns FALSE when the
// short name does not exist or does not fit into bufSize
BOOL SalGetShortPathName(const char* u8path, char* buf, int bufSize);

DWORD SalGetFileAttributes(const char* u8path);
BOOL SalSetFileAttributes(const char* u8path, DWORD attributes);
BOOL SalGetFileAttributesEx(const char* u8path, WIN32_FILE_ATTRIBUTE_DATA* data);

// Get/SetNamedSecurityInfoW with a UTF-8 path (feature 027): the ANSI
// variants fail on long/Unicode paths, silently dropping ACL/owner during
// copy/move with "preserve permissions". Return a Win32 error code (as the
// *NamedSecurityInfo APIs do), ERROR_INVALID_NAME for an unconvertible path.
DWORD SalGetNamedSecurityInfo(const char* u8path, SECURITY_INFORMATION si,
                              PSID* owner, PSID* group, PACL* dacl, PACL* sacl,
                              PSECURITY_DESCRIPTOR* sd);
DWORD SalSetNamedSecurityInfo(const char* u8path, SECURITY_INFORMATION si,
                              PSID owner, PSID group, PACL dacl, PACL sacl);

// EncryptFileW/DecryptFileW with a UTF-8 path (feature 027). The extended-
// length \\?\ prefix is accepted by these APIs. Return the same BOOL as the
// underlying API; on an unconvertible path they fail with ERROR_INVALID_NAME.
BOOL SalEncryptFile(const char* u8path);
BOOL SalDecryptFile(const char* u8path);

//*****************************************************************************
//
// feature 103: is an existing target the source itself? (rules in salsamefile.h)
//

#include "salsamefile.h"

// the identity of a file or directory named by a UTF-8 path (SalGetFileIdentityW through
// the \\?\ form); FALSE when nothing could be read ('id' is then cleared)
// 'volumeTraits' (feature 107): also SnapshotTag and WeakIds (the folder checks)
BOOL SalGetFileIdentity(const char* u8path, BOOL linkItself, CSalFileIdentity* id, BOOL volumeTraits = FALSE);

// feature 107: one directory entry or two (SalSameDirEntry: the identities of the two holding
// folders, read through links, and the two names as stored in them)? sseYes / sseNo / sseUnknown
int SalSameDirEntryU8(const char* u8src, const char* u8tgt);

// feature 107: one name up to case and Unicode normalization (NFC) - "the same name" for a server
// that gives no file ids (a WebDAV alias keeps the folder's name in some spelling)
BOOL SalNamesLooselyEqualU8(const char* u8a, const char* u8b);

// feature 107: "the same folder" for a server that gives no file ids (WebDAV). Both paths are
// resolved first (SalGetFinalPathU8Alloc: a mapped or SUBST drive letter becomes the UNC path, a
// link its target), then compared below the server name (SalCanonicalBelowServerU8Alloc), one path
// up to case and Unicode normalization: a second name of the server (IP, localhost, @SSL, @port), a
// mapped drive, the "DavWWWRoot" form or another spelling keep that path, a backup in another folder
// does not. A side that cannot be resolved falls back to the folder names (a "maybe" - fail closed).
BOOL SalPathsBelowServerLooselyEqualU8(const char* u8a, const char* u8b);

// feature 107, pure: the canonical form of a RESOLVED path below its server name - a UNC path
// "\\server\share\a" (the server with any @SSL / @port) -> "\\share\a", "\\server\DavWWWRoot\share\a"
// -> "\\share\a"; a drive path stays as it is; a trailing backslash dropped; NULL for anything else
// (also NULL in). malloc'ed.
char* SalCanonicalBelowServerU8Alloc(const char* path);

// feature 107: the path the file system resolves 'u8path' to (GetFinalPathNameByHandle,
// normalized, DOS volume name; links and SUBST letters resolved), without the \\?\ prefix
// (\\?\UNC\ becomes \\); malloc'ed UTF-8, NULL when it cannot be read
char* SalGetFinalPathU8Alloc(const char* u8path);

// SalRenameViaTempName through SalMoveFile: u8src -> "sal###" beside it -> u8tgt; the
// temporary path is written to 'tmpName' (strlen(u8src) + 8 bytes suffice) - for
// svtLeftAtTemp it is where the source now is
CSalViaTempResult SalRenameViaTempNameU8(const char* u8src, const char* u8tgt,
                                         char* tmpName, int tmpNameSize, DWORD* err);
