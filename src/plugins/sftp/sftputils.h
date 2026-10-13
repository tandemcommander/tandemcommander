// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

// ****************************************************************************
// sftputils - protocol-agnostic helpers: Unix mode formatting, path handling,
// UTF-8 sanitation. Kept free of libssh2 dependencies so the pure-logic parts
// can be exercised by the dev test harness (test\harness.cpp).
// ****************************************************************************

// POSIX mode bit masks (independent of the host <sys/stat.h>, which is not
// available in a pure-WinAPI build).
#define SFTP_S_IFMT 0170000
#define SFTP_S_IFSOCK 0140000
#define SFTP_S_IFLNK 0120000
#define SFTP_S_IFREG 0100000
#define SFTP_S_IFBLK 0060000
#define SFTP_S_IFDIR 0040000
#define SFTP_S_IFCHR 0020000
#define SFTP_S_IFIFO 0010000
#define SFTP_S_ISUID 0004000
#define SFTP_S_ISGID 0002000
#define SFTP_S_ISVTX 0001000

#define SFTP_S_ISDIR(m) (((m) & SFTP_S_IFMT) == SFTP_S_IFDIR)
#define SFTP_S_ISLNK(m) (((m) & SFTP_S_IFMT) == SFTP_S_IFLNK)
#define SFTP_S_ISREG(m) (((m) & SFTP_S_IFMT) == SFTP_S_IFREG)

// Formats a Unix mode into the classic symbolic 10-character string, e.g.
// "drwxr-xr-x", "-rwsr-xr-t". 'buf' must hold at least 11 bytes. Returns 'buf'.
char* FormatUnixRights(unsigned long mode, char* buf);

// Formats the permission bits (low 12 bits incl. setuid/setgid/sticky) as an
// octal string, e.g. "0755", "4755". 'buf' must hold at least 8 bytes.
char* FormatOctalMode(unsigned long mode, char* buf);

// Parses an octal string ("755", "0644", "4755") into permission bits. Returns
// TRUE and stores the value (only the low 12 bits) in *mode on success.
BOOL ParseOctalMode(const char* text, unsigned long* mode);

// Returns the entry-type character for a Unix mode ('-', 'd', 'l', 'b', 'c',
// 'p', 's', '?').
char UnixTypeChar(unsigned long mode);

// Synthesizes Windows FILE_ATTRIBUTE_* flags from a Unix mode and name so the
// classic Attributes column and hidden-file handling stay meaningful:
//   READONLY when the owner has no write bit, HIDDEN for dotfiles,
//   DIRECTORY for directory modes.
DWORD SynthesizeWinAttributes(unsigned long mode, const char* name);

// Converts a Unix mtime (seconds since 1970-01-01 UTC) to a FILETIME (UTC).
void UnixTimeToFileTime(__int64 unixSeconds, FILETIME* ft);

// Converts a FILETIME (UTC) to a Unix mtime (seconds since 1970-01-01 UTC).
__int64 FileTimeToUnixTime(const FILETIME* ft);

// Returns TRUE if 'name' is "." or "..".
BOOL IsDotOrDotDot(const char* name);

// Validates that a byte string is well-formed UTF-8. Returns TRUE if valid.
BOOL IsValidUTF8(const char* s, int len);

// Copies 'src' into 'dst' (size 'dstSize'), replacing bytes that break UTF-8
// well-formedness with '?', so an invalid remote name never corrupts the panel
// yet stays visibly distinct. Returns 'dst'.
char* SanitizeUTF8(const char* src, char* dst, int dstSize);

// Joins a POSIX directory and a name into 'dst' (size 'dstSize') using '/'.
// Handles the root ("/") and missing trailing slash. Returns 'dst'.
// feature 131: a result that does not fit is NOT cut - 'dst' is then empty and the
// function returns NULL; the caller refuses the operation (a shortened path names
// another file or directory). Every caller checks the result (feature 131).
char* PosixPathAppend(const char* dir, const char* name, char* dst, int dstSize);

// feature 131: joins a Windows directory and a name (or a "*" mask) into 'dst' using
// '\\' (none is added when 'dir' already ends with one). Returns FALSE and leaves
// 'dst' empty when the result does not fit - never a cut path.
BOOL LocalPathAppend(const char* dir, const char* name, char* dst, int dstSize);

// feature 131: the English name of an SFTP status code (SSH_FX_*, what
// libssh2_sftp_last_error returns) for the "SFTP error %d: %s" reason; ASCII, never NULL.
const char* SftpStatusName(unsigned long code);

// feature 133: what the result of one libssh2_sftp_readdir_ex call means for a listing.
// Only "end" completes it: an error in the middle (a name that does not fit the buffer, a
// broken connection, a status of the server) used to be taken for the end of the directory,
// and a part of the directory was then shown, copied and counted as the whole of it.
enum CSftpReadDirStep
{
    rdsEntry, // rc > 0: a name of rc bytes
    rdsEnd,   // rc == 0: the server said "no more entries"
    rdsError, // rc < 0: the listing is NOT complete
};
CSftpReadDirStep SftpReadDirStep(int rc);

// feature 133: a message made of a template with one or two "%s" and its texts, in a buffer of
// exactly the size needed (malloc; NULL = low memory). The messages were composed in 1,200
// bytes: with a long path the path was cut and the reason behind it was lost. 'b' may be
// NULL (taken as ""); a template with one "%s" ignores it.
char* SftpFormatMsgAlloc(const char* fmt, const char* a, const char* b);

// Returns a pointer to the last path component of a POSIX path.
const char* PosixBaseName(const char* path);
