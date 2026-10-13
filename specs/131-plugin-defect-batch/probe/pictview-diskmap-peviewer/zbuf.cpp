// feature 131 measurement: CZStringBuffer::AppendAt of DiskMap (Utils.CZString.h), the code as it
// was (OLD) and as changed (NEW). Debug CRT: _CrtCheckMemory() reports a write past a heap block.
#include <windows.h>
#include <tchar.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <crtdbg.h>

class COld
{
public:
    TCHAR* _s;
    size_t _l;
    size_t _c;
    explicit COld(size_t size)
    {
        _l = 0;
        _c = size;
        _s = (TCHAR*)malloc(_c * sizeof(TCHAR));
        *_s = 0;
    }
    ~COld() { free(_s); }
    COld* AppendAt(TCHAR const* s, size_t len, size_t pos)
    {
        int p = (int)min(pos, this->_l);
        if (len + p > this->_c)
            return this; //TODO!
        _tcscpy(&this->_s[p], s);
        this->_l = len + p;
        this->_s[this->_l] = TEXT('\0');
        return this;
    }
    COld* AppendAt(TCHAR c, size_t pos)
    {
        size_t p = min(pos, this->_l);
        if (p >= this->_c)
            return this; //TODO!
        this->_s[p] = c;
        this->_l = p + 1;
        this->_s[this->_l] = TEXT('\0');
        return this;
    }
};

class CNew
{
public:
    TCHAR* _s;
    size_t _l;
    size_t _c;
    explicit CNew(size_t size)
    {
        _l = 0;
        _c = size;
        _s = (TCHAR*)malloc(_c * sizeof(TCHAR));
        *_s = 0;
    }
    ~CNew() { free(_s); }
    BOOL CanAppendAt(size_t len, size_t pos) const
    {
        size_t p = min(pos, this->_l);
        return p < this->_c && len < this->_c - p;
    }
    CNew* AppendAt(TCHAR const* s, size_t len, size_t pos)
    {
        size_t p = min(pos, this->_l);
        if (!this->CanAppendAt(len, pos))
            return this;
        memcpy(&this->_s[p], s, len * sizeof(TCHAR));
        this->_l = len + p;
        this->_s[this->_l] = TEXT('\0');
        return this;
    }
    CNew* AppendAt(TCHAR c, size_t pos)
    {
        size_t p = min(pos, this->_l);
        if (!this->CanAppendAt(1, pos))
            return this;
        this->_s[p] = c;
        this->_l = p + 1;
        this->_s[this->_l] = TEXT('\0');
        return this;
    }
};

static int Check(const char* what)
{
    int ok = _CrtCheckMemory();
    printf("  %-58s heap %s\n", what, ok ? "intact" : "DAMAGED (write past the block)");
    return ok;
}

template <class T>
static void Run(const char* title)
{
    printf("%s\n", title);
    char text[600];
    {
        // 1. a text that fills the buffer exactly (264 = MAX_PATH + 4, the directory line's buffer)
        T* b = new T(MAX_PATH + 4);
        memset(text, 'a', 264);
        text[264] = 0;
        b->AppendAt(text, 264, 0);
        printf("  1. 264 bytes into 264: length %u\n", (unsigned)b->_l);
        Check("after the append");
        delete b;
    }
    {
        // 2. 263 bytes, then the backslash of SetSubPath
        T* b = new T(MAX_PATH + 4);
        memset(text, 'a', 263);
        text[263] = 0;
        b->AppendAt(text, 263, 0);
        b->AppendAt('\\', 263);
        printf("  2. 263 bytes + one character: length %u\n", (unsigned)b->_l);
        Check("after the character");
        delete b;
    }
    {
        // 3. a text that does not fit: dropped, the old content stays
        T* b = new T(MAX_PATH + 4);
        b->AppendAt("C:\\old", 6, 0);
        memset(text, 'b', 300);
        text[300] = 0;
        b->AppendAt(text, 300, 0);
        printf("  3. 300 bytes into 264 after \"C:\\old\": content \"%.20s\" length %u\n", b->_s, (unsigned)b->_l);
        Check("after the append");
        delete b;
    }
    {
        // 4. a length shorter than the text: only 'len' characters may be taken
        T* b = new T(8);
        b->AppendAt("0123456789ABCDEF", 4, 0);
        printf("  4. len 4 of a 16-byte text into 8: content \"%s\" length %u\n", b->_s, (unsigned)b->_l);
        Check("after the append");
        delete b;
    }
}

int main()
{
    _CrtSetReportMode(_CRT_WARN, _CRTDBG_MODE_FILE);
    _CrtSetReportFile(_CRT_WARN, _CRTDBG_FILE_STDOUT);
    _CrtSetReportMode(_CRT_ERROR, _CRTDBG_MODE_FILE);
    _CrtSetReportFile(_CRT_ERROR, _CRTDBG_FILE_STDOUT);
    Run<CNew>("NEW");
    Run<COld>("OLD");
    return 0;
}
