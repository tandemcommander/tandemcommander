// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"
#include "sftputils.h"

char UnixTypeChar(unsigned long mode)
{
    switch (mode & SFTP_S_IFMT)
    {
    case SFTP_S_IFDIR:
        return 'd';
    case SFTP_S_IFLNK:
        return 'l';
    case SFTP_S_IFBLK:
        return 'b';
    case SFTP_S_IFCHR:
        return 'c';
    case SFTP_S_IFIFO:
        return 'p';
    case SFTP_S_IFSOCK:
        return 's';
    case SFTP_S_IFREG:
        return '-';
    default:
        // when the server omits the type bits (mode == permission bits only),
        // fall back to a regular-file dash rather than '?'
        return (mode & SFTP_S_IFMT) == 0 ? '-' : '?';
    }
}

char* FormatUnixRights(unsigned long mode, char* buf)
{
    buf[0] = UnixTypeChar(mode);

    buf[1] = (mode & 0400) ? 'r' : '-';
    buf[2] = (mode & 0200) ? 'w' : '-';
    if (mode & SFTP_S_ISUID)
        buf[3] = (mode & 0100) ? 's' : 'S';
    else
        buf[3] = (mode & 0100) ? 'x' : '-';

    buf[4] = (mode & 0040) ? 'r' : '-';
    buf[5] = (mode & 0020) ? 'w' : '-';
    if (mode & SFTP_S_ISGID)
        buf[6] = (mode & 0010) ? 's' : 'S';
    else
        buf[6] = (mode & 0010) ? 'x' : '-';

    buf[7] = (mode & 0004) ? 'r' : '-';
    buf[8] = (mode & 0002) ? 'w' : '-';
    if (mode & SFTP_S_ISVTX)
        buf[9] = (mode & 0001) ? 't' : 'T';
    else
        buf[9] = (mode & 0001) ? 'x' : '-';

    buf[10] = 0;
    return buf;
}

char* FormatOctalMode(unsigned long mode, char* buf)
{
    unsigned long perm = mode & 07777;
    // always 4 octal digits so special bits are visible (e.g. "0755", "4755")
    _snprintf_s(buf, 8, _TRUNCATE, "%04o", perm);
    return buf;
}

BOOL ParseOctalMode(const char* text, unsigned long* mode)
{
    if (text == NULL)
        return FALSE;
    while (*text == ' ' || *text == '\t')
        text++;
    if (*text == 0)
        return FALSE;

    unsigned long value = 0;
    int digits = 0;
    while (*text >= '0' && *text <= '7')
    {
        value = (value << 3) | (unsigned long)(*text - '0');
        text++;
        digits++;
        if (digits > 5)
            return FALSE; // too long to be a valid mode
    }
    while (*text == ' ' || *text == '\t')
        text++;
    if (*text != 0 || digits == 0)
        return FALSE;

    *mode = value & 07777;
    return TRUE;
}

DWORD SynthesizeWinAttributes(unsigned long mode, const char* name)
{
    DWORD attr = 0;
    if (SFTP_S_ISDIR(mode))
        attr |= FILE_ATTRIBUTE_DIRECTORY;
    if ((mode & 0200) == 0) // owner has no write permission
        attr |= FILE_ATTRIBUTE_READONLY;
    if (name != NULL && name[0] == '.' && !IsDotOrDotDot(name))
        attr |= FILE_ATTRIBUTE_HIDDEN;
    if (attr == 0)
        attr = FILE_ATTRIBUTE_NORMAL;
    return attr;
}

void UnixTimeToFileTime(__int64 unixSeconds, FILETIME* ft)
{
    // FILETIME is 100-ns intervals since 1601-01-01; Unix epoch is 1970-01-01.
    // 11644473600 seconds separate the two epochs.
    __int64 ll = (unixSeconds + 11644473600LL) * 10000000LL;
    ft->dwLowDateTime = (DWORD)(ll & 0xFFFFFFFF);
    ft->dwHighDateTime = (DWORD)(ll >> 32);
}

__int64 FileTimeToUnixTime(const FILETIME* ft)
{
    __int64 ll = ((__int64)ft->dwHighDateTime << 32) | ft->dwLowDateTime;
    return ll / 10000000LL - 11644473600LL;
}

BOOL IsDotOrDotDot(const char* name)
{
    return name != NULL && name[0] == '.' &&
           (name[1] == 0 || (name[1] == '.' && name[2] == 0));
}

BOOL IsValidUTF8(const char* s, int len)
{
    const unsigned char* p = (const unsigned char*)s;
    int i = 0;
    while (i < len)
    {
        unsigned char c = p[i];
        int extra;
        unsigned long cp;
        if (c < 0x80)
        {
            i++;
            continue;
        }
        else if ((c & 0xE0) == 0xC0)
        {
            extra = 1;
            cp = c & 0x1F;
        }
        else if ((c & 0xF0) == 0xE0)
        {
            extra = 2;
            cp = c & 0x0F;
        }
        else if ((c & 0xF8) == 0xF0)
        {
            extra = 3;
            cp = c & 0x07;
        }
        else
            return FALSE;

        if (i + extra >= len)
            return FALSE;
        for (int k = 1; k <= extra; k++)
        {
            if ((p[i + k] & 0xC0) != 0x80)
                return FALSE;
            cp = (cp << 6) | (p[i + k] & 0x3F);
        }
        // reject overlong encodings and out-of-range code points
        if (extra == 1 && cp < 0x80)
            return FALSE;
        if (extra == 2 && cp < 0x800)
            return FALSE;
        if (extra == 3 && (cp < 0x10000 || cp > 0x10FFFF))
            return FALSE;
        if (cp >= 0xD800 && cp <= 0xDFFF)
            return FALSE; // UTF-16 surrogate halves are not valid scalar values
        i += extra + 1;
    }
    return TRUE;
}

char* SanitizeUTF8(const char* src, char* dst, int dstSize)
{
    if (dstSize <= 0)
        return dst;
    int len = (int)strlen(src);
    if (IsValidUTF8(src, len))
    {
        lstrcpynA(dst, src, dstSize);
        return dst;
    }
    // byte-by-byte copy: keep each byte run that forms one well-formed UTF-8
    // sequence, replace anything else with a single '?' so the name stays
    // visibly distinct but never corrupts the panel
    int si = 0, di = 0;
    while (src[si] != 0 && di < dstSize - 1)
    {
        unsigned char c = (unsigned char)src[si];
        int seq = 0;
        if (c < 0x80)
            seq = 1;
        else if ((c & 0xE0) == 0xC0)
            seq = 2;
        else if ((c & 0xF0) == 0xE0)
            seq = 3;
        else if ((c & 0xF8) == 0xF0)
            seq = 4;

        int remaining = (int)strlen(src + si);
        if (seq >= 1 && seq <= remaining && IsValidUTF8(src + si, seq))
        {
            for (int k = 0; k < seq && di < dstSize - 1; k++)
                dst[di++] = src[si++];
        }
        else
        {
            dst[di++] = '?';
            si++;
        }
    }
    dst[di] = 0;
    return dst;
}

char* PosixPathAppend(const char* dir, const char* name, char* dst, int dstSize)
{
    if (dst == NULL || dstSize <= 0)
        return NULL;
    if (dir == NULL || dir[0] == 0)
        dir = "/";
    if (name == NULL)
        name = "";
    size_t dirLen = strlen(dir);
    size_t nameLen = strlen(name);
    BOOL addSlash = dir[dirLen - 1] != '/';
    // feature 131: a path that does not fit is not cut (the shortened path is another file)
    if (dirLen + (addSlash ? 1 : 0) + nameLen >= (size_t)dstSize)
    {
        dst[0] = 0;
        return NULL;
    }
    memcpy(dst, dir, dirLen);
    if (addSlash)
        dst[dirLen++] = '/';
    memcpy(dst + dirLen, name, nameLen + 1);
    return dst;
}

BOOL LocalPathAppend(const char* dir, const char* name, char* dst, int dstSize)
{
    if (dst == NULL || dstSize <= 0)
        return FALSE;
    if (dir == NULL)
        dir = "";
    if (name == NULL)
        name = "";
    size_t dirLen = strlen(dir);
    size_t nameLen = strlen(name);
    if (dirLen == 0) // no directory: "\\name" would be the root of the current drive
    {
        dst[0] = 0;
        return FALSE;
    }
    BOOL addSep = dir[dirLen - 1] != '\\';
    if (dirLen + (addSep ? 1 : 0) + nameLen >= (size_t)dstSize)
    {
        dst[0] = 0;
        return FALSE;
    }
    memcpy(dst, dir, dirLen);
    if (addSep)
        dst[dirLen++] = '\\';
    memcpy(dst + dirLen, name, nameLen + 1);
    return TRUE;
}

const char* SftpStatusName(unsigned long code)
{
    // SSH_FX_* of the SFTP drafts (version 3 servers send 0 - 8 only)
    static const char* const kNames[] = {
        "OK", "End of file", "No such file", "Permission denied", "Failure",
        "Bad message", "No connection", "Connection lost", "Operation not supported",
        "Invalid handle", "No such path", "File already exists", "Write protected",
        "No media", "No space on the file system", "Quota exceeded", "Unknown principal",
        "Lock conflict", "Directory not empty", "Not a directory", "Invalid file name",
        "Link loop"};
    if (code < sizeof(kNames) / sizeof(kNames[0]))
        return kNames[code];
    return "Unknown status";
}

const char* PosixBaseName(const char* path)
{
    const char* slash = strrchr(path, '/');
    return slash != NULL ? slash + 1 : path;
}

CSftpReadDirStep SftpReadDirStep(int rc)
{
    return rc > 0 ? rdsEntry : rc == 0 ? rdsEnd : rdsError;
}

char* SftpFormatMsgAlloc(const char* fmt, const char* a, const char* b)
{
    if (fmt == NULL)
        return NULL;
    if (a == NULL)
        a = "";
    if (b == NULL)
        b = "";
    size_t size = strlen(fmt) + strlen(a) + strlen(b) + 1; // each "%s" is two bytes shorter than nothing
    char* msg = (char*)malloc(size);
    if (msg == NULL)
        return NULL;
    if (_snprintf_s(msg, size, _TRUNCATE, fmt, a, b) < 0)
        msg[size - 1] = 0; // cannot happen with "%s" inserts only; never unterminated
    return msg;
}

BOOL SftpMoveMayRemove(BOOL transferred, BOOL localSizeKnown, unsigned __int64 localSize,
                       BOOL remoteSizeKnown, unsigned __int64 remoteSize)
{
    return transferred && localSizeKnown && remoteSizeKnown && localSize == remoteSize;
}

BOOL SftpTempPath(const char* targetPath, unsigned long random, char* buf, int bufSize)
{
    if (buf == NULL || bufSize <= 0)
        return FALSE;
    buf[0] = 0;
    if (targetPath == NULL)
        return FALSE;
    const char* slash = strrchr(targetPath, '/');
    size_t dirLen = slash != NULL ? (size_t)(slash - targetPath) + 1 : 0; // with the slash
    const size_t nameLen = 16;                                            // ".tcpart-" + 8 hex digits
    if (dirLen + nameLen >= (size_t)bufSize)
        return FALSE; // never a cut path
    memcpy(buf, targetPath, dirLen);
    static const char kHex[] = "0123456789abcdef";
    char* p = buf + dirLen;
    memcpy(p, ".tcpart-", 8);
    p += 8;
    for (int shift = 28; shift >= 0; shift -= 4)
        *p++ = kHex[(random >> shift) & 0xF];
    *p = 0;
    return TRUE;
}

BOOL SftpUploadConfirmed(BOOL remoteSizeKnown, unsigned __int64 remoteSize, unsigned __int64 bytesSent,
                         unsigned __int64 localSize)
{
    return remoteSizeKnown && remoteSize == bytesSent && bytesSent == localSize;
}

CSftpUploadConfirm SftpUploadConfirmation(BOOL remoteSizeKnown, unsigned __int64 remoteSize, BOOL sizeRefused,
                                          unsigned __int64 bytesSent, unsigned __int64 localSize)
{
    if (remoteSizeKnown)
        return SftpUploadConfirmed(TRUE, remoteSize, bytesSent, localSize) ? ucBySize : ucNo;
    return sizeRefused && bytesSent == localSize ? ucByAcks : ucNo;
}

BOOL SftpTargetStatRefused(BOOL connected, unsigned long status)
{
    return connected && SftpStatusIsPermission(status);
}

BOOL SftpUnconfirmedDir(BOOL mkdirConnected, unsigned long mkdirStatus, BOOL statConnected, unsigned long statStatus)
{
    BOOL mayExist = mkdirStatus == 4 || mkdirStatus == 11; // SSH_FX_FAILURE, SSH_FX_FILE_ALREADY_EXISTS
    return mkdirConnected && mayExist && SftpTargetStatRefused(statConnected, statStatus);
}

BOOL SftpEndsUnconfirmedDir(BOOL connected, unsigned long status, int confirmed)
{
    return confirmed == 0 && connected && SftpStatusIsNotFound(status);
}

CSftpUnconfirmedDirVerdict SftpUnconfirmedDirVerdict(int confirmed, BOOL noFolder)
{
    if (noFolder)
        return udNotThere;
    return confirmed > 0 ? udConfirmed : udNothingConfirmed;
}

BOOL SftpIsUploadTempPath(const char* path)
{
    if (path == NULL)
        return FALSE;
    const char* name = PosixBaseName(path);
    if (strncmp(name, ".tcpart-", 8) != 0)
        return FALSE;
    for (int i = 8; i < 16; i++)
    {
        char c = name[i];
        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')))
            return FALSE;
    }
    return name[16] == 0;
}

BOOL SftpStatusIsNotFound(unsigned long status)
{
    return status == 2 || status == 10; // SSH_FX_NO_SUCH_FILE, SSH_FX_NO_SUCH_PATH
}

BOOL SftpStatusIsPermission(unsigned long status)
{
    return status == 3 || status == 12; // SSH_FX_PERMISSION_DENIED, SSH_FX_WRITE_PROTECT
}

CSftpTempOpenNext SftpTempOpenFailureNext(BOOL connected, unsigned long status)
{
    if (!connected)
        return tonFail;
    switch (status)
    {
    case 3:  // SSH_FX_PERMISSION_DENIED
    case 12: // SSH_FX_WRITE_PROTECT
    case 8:  // SSH_FX_OP_UNSUPPORTED
        return tonInPlace;
    case 4:  // SSH_FX_FAILURE (what OpenSSH answers for a name that exists)
    case 11: // SSH_FX_FILE_ALREADY_EXISTS
        return tonRetryName;
    }
    return tonFail; // 0 = no status at all (timeout, transport), quota, no space, ...
}

BOOL SftpOwnerDiffers(BOOL oldKnown, unsigned long oldUid, unsigned long oldGid,
                      BOOL newKnown, unsigned long newUid, unsigned long newGid)
{
    return oldKnown && newKnown && (oldUid != newUid || oldGid != newGid);
}

BOOL SftpModeDiffers(BOOL oldKnown, unsigned long oldMode, BOOL newKnown, unsigned long newMode)
{
    return oldKnown && (!newKnown || (oldMode & 07777) != (newMode & 07777));
}

BOOL SftpRcIsDeadTransport(int rc)
{
    if (rc >= 0)
        return FALSE; // success, a length, or one of the library's positive SSH_FX_* answers
    switch (rc)
    {
    case -31: // LIBSSH2_ERROR_SFTP_PROTOCOL: the server answered - with a refusal
    case -38: // LIBSSH2_ERROR_BUFFER_TOO_SMALL: the answer was read whole, it does not fit the caller's buffer
    case -39: // LIBSSH2_ERROR_BAD_USE: wrong arguments - nothing was sent
        return FALSE;
    }
    // Everything else, also what the library may add later. Not excepted on purpose:
    // LIBSSH2_ERROR_ALLOC (-6) - it is also what the packet reader returns for an SFTP packet
    // of an impossible size (sftp.c, sftp_packet_read: "Invalid SFTP packet size"), i.e. a
    // stream that is out of step; LIBSSH2_ERROR_EAGAIN (-37) - out of a blocking call it means
    // a half-done request; the codes of a failed key re-exchange (-5, -8, -10, -11, -14, -49),
    // which the wait for an answer hands out from its keepalive while the request stays "sent".
    return TRUE;
}

BOOL SftpErrnoIsDeadTransport(int code)
{
    switch (code)
    {
    case -9:  // LIBSSH2_ERROR_TIMEOUT
    case -30: // LIBSSH2_ERROR_SOCKET_TIMEOUT
    case -7:  // LIBSSH2_ERROR_SOCKET_SEND
    case -43: // LIBSSH2_ERROR_SOCKET_RECV
    case -13: // LIBSSH2_ERROR_SOCKET_DISCONNECT
        return TRUE;
    }
    return FALSE; // (also LIBSSH2_ERROR_EAGAIN: it stays recorded after a read that succeeded)
}

CSftpDownloadKind SftpDownloadKind(BOOL hasMode, unsigned long mode)
{
    if (!hasMode)
        return sdkUnknown;
    switch (mode & SFTP_S_IFMT)
    {
    case SFTP_S_IFREG:
        return sdkRegular;
    case SFTP_S_IFDIR:
        return sdkDirectory;
    case SFTP_S_IFLNK:
        return sdkLink;
    case SFTP_S_IFCHR:
    case SFTP_S_IFBLK:
    case SFTP_S_IFIFO:
    case SFTP_S_IFSOCK:
        return sdkSpecial;
    }
    return sdkUnknown; // no type bits (a server that sends permissions only), or a type not known here
}

BOOL SftpLocalDirIsLink(DWORD attributes, DWORD reparseTag)
{
    if (attributes == INVALID_FILE_ATTRIBUTES || (attributes & FILE_ATTRIBUTE_REPARSE_POINT) == 0)
        return FALSE;
    return (reparseTag & 0x20000000) != 0; // the name-surrogate bit (IsReparseTagNameSurrogate)
}
