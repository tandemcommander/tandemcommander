# Contract: the server encoding rule (`src/common/salftpsrvenc.h`)

Internal to the FTP plug-in (header-only, checked by saltests); not part of the plug-in interface.

```text
SALFTPENC_UNKNOWN, SALFTPENC_UTF8, SALFTPENC_LEGACY, SALFTPENC_MIXED

int  SalFtpServerEncState(BOOL sawUtf8, BOOL sawCodePage)
     -> UNKNOWN (no, no), UTF8 (yes, no), LEGACY (no, yes), MIXED (yes, yes)

BOOL SalFtpNameGoesInCodePage(int state, BOOL isCodePageNameOfServer, BOOL isSentUtf8NameOfServer)
     -> TRUE when isCodePageNameOfServer, or state == LEGACY and not isSentUtf8NameOfServer
        (review 2); else FALSE (the caller still sends UTF-8 when the code page cannot hold the
        name exactly, and sends ASCII unchanged)

BOOL SalFtpRememberSentUtf8(int state)
     -> TRUE for UNKNOWN and LEGACY: a name sent in UTF-8 is remembered for the server (its
        listing echo is no UTF-8 evidence)

BOOL SalFtpWToCodePageExact(UINT codePage, const WCHAR* w, char* buf, int bufSize)
     -> TRUE only when every letter has its own byte form (WC_NO_BEST_FIT_CHARS, no default
        character) and the bytes read back are 'w'; FALSE with buf = "" otherwise (also when it
        does not fit - never cut) (review 1)

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
char*          FTPListingFieldToU8(const char* beg, int len, BOOL nameField) // uses the scope; only a name field changes the state
void           FTPFreeServerEncodings()                       // was FTPFreeCodePageNames
```
