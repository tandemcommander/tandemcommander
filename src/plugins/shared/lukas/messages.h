// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

// aby byly struktury nezavisle na nastavenem zarovnavani
#pragma pack(push, 4)

struct CMessage
{
    int Size;
    int SenderID; // doplni message center pri odeslani
};

#pragma pack(pop)

class CMessageListener
{
public:
    // feature 102: 'size' = the message's Size as checked against the buffer (read it, not
    // message->Size, which another process may change meanwhile); 'message' points into the
    // shared buffer
    virtual void RecieveMessage(const CMessage* message, int size) = 0;
};

class CMessageCenter
{
public:
    CMessageCenter(const char* name, BOOL sender);
    ~CMessageCenter();

    BOOL IsGood() { return Good; }

    BOOL SendMessage(CMessage* message, BOOL bufferTimeout);
    BOOL RecieveMessages(CMessageListener* listener);
    BOOL WaitForMessage(BOOL& windowMessage);
    BOOL WaitForMessage(BOOL& success, DWORD timeout);
    BOOL WaitForMessage(BOOL& success, DWORD timeout, HANDLE cancel,
                        BOOL& canceled);
    const char* GetName() { return Name; }
    int GetSenderID() { return SenderID; }
    DWORD GetRecieverPid() { return RecieverPid; }
    BOOL Init();
    void Release();

private:
    struct CBuffer
    {
        DWORD Pid;
        int UniqueCounter;
        int WritePos;
    };

public:
    // feature 102 (File Comparator channel version 2): room for one message with two names
    // of 32,767 UTF-16 units (131,116 bytes, see filecomp's remotmsg.h); was 4,094.  The
    // buffer is named after Version, so both sides of a version always agree on its size.
    enum
    {
        BufferSize = 135168
    };
    enum
    {
        MaxMessage = BufferSize - sizeof(CBuffer)
    };

private:
    static const char* Version;
    BOOL Good;
    char* Name;
    BOOL Sender;
    HANDLE StartupMutex;
    HANDLE DataMutex;
    HANDLE BufferFree;
    HANDLE HaveMessage;
    HANDLE FileMapping;
    CBuffer* Buffer;
    HANDLE Reciever;   // jen pro odesilatele, handle ciloveho procesu
    DWORD RecieverPid; // jen pro odesilatele, id ciloveho procesu
    int SenderID;      // unikatni identifikator odesilatele
};
