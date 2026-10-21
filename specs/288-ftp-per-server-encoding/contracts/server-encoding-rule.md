# Contract: the server encoding rule (`src/common/salftpsrvenc.h`)

Internal to the FTP plug-in (header-only, checked by saltests); not part of the plug-in interface.

```text
SALFTPENC_UNKNOWN, SALFTPENC_UTF8, SALFTPENC_LEGACY, SALFTPENC_MIXED

int  SalFtpServerEncState(BOOL sawUtf8, BOOL sawCodePage)
     -> UNKNOWN (no, no), UTF8 (yes, no), LEGACY (no, yes), MIXED (yes, yes)

BOOL SalFtpNameGoesInCodePage(int state, BOOL isCodePageNameOfServer)
     -> TRUE when isCodePageNameOfServer, or state == LEGACY; else FALSE
        (the caller still sends UTF-8 when the code page cannot hold the name, and sends
        ASCII unchanged)

BOOL SalFtpSameServerUser(const char* a, const char* b)
     -> NULL, "" and "anonymous" are one user; otherwise byte-for-byte equal

BOOL SalFtpSameServerHost(const char* a, const char* b)
     -> equal ignoring ASCII case only (bytes >= 0x80 compared as they are); NULL never equal

BOOL SalFtpSameServer(hostA, portA, userA, hostB, portB, userB)
     -> SameServerHost && portA == portB && SameServerUser
```

## Plug-in internal signatures that change (ftputils.h, ctrlcon.h)

```text
CFTPServerEnc* FTPGetServerEnc(const char* host, unsigned short port, const char* user)
               NULL host, low memory or past 1,000 servers -> NULL (treated as unknown)
const char*    FTPU8NameToServer(const char* u8, char* buf, int bufSize, CFTPServerEnc* srv)
BOOL           FTPGetDirectoryFromReply(const char* reply, int replySize, char* dirBuf, int dirBufSize,
                                        CFTPServerEnc* srv)
BOOL           PrepareFTPCommand(CFTPServerEnc* srv, char* buf, int bufSize, char* logBuf,
                                 int logBufSize, CFtpCmdCode ftpCmd, int* cmdLen, ...)
class CFTPListingServerScope   // sets the server of the listing parsed on this thread; nests
char*          FTPListingFieldToU8(const char* beg, int len)   // unchanged; uses the scope
void           FTPFreeServerEncodings()                       // was FTPFreeCodePageNames
```
