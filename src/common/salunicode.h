// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salunicode.h
//
// UTF-8 <-> UTF-16 conversion and Unicode-aware file-name helpers.
//
// Internal narrow strings that carry file names and paths use UTF-8
// (feature 004-long-paths-unicode, research.md R1/R4). Conversion to
// UTF-16 happens only at OS boundaries (file APIs, GDI, window text,
// registry). Stored names are NEVER normalized or case-folded by these
// helpers; NFC normalization is applied to transient copies used for
// matching and collation only.
//
// Names containing unpaired UTF-16 surrogates (legal on NTFS) are not
// representable in strict UTF-8; since feature 066 the converter pair
// carries them as WTF-8 - a strict superset of UTF-8 encoding each lone
// surrogate as its 3-byte sequence ED A0 80..ED BF BF - so every on-disk
// name round-trips losslessly. For valid Unicode text the encoding is
// byte-identical to UTF-8. Binding contract:
// specs/066-fix-surrogate-filenames/contracts/name-encoding-wtf8.md
//

//*****************************************************************************
//
// SalU8ToW / SalWToU8
//
// Convert between WTF-8 (UTF-8 + lone-surrogate sequences, feature 066)
// and UTF-16. SalWToU8 is total: it succeeds for every input unit
// sequence. SalU8ToW stays strict for everything else: any malformed
// input other than a lone-surrogate sequence fails (returns 0) instead
// of being silently replaced - the "valid UTF-8, else ANSI" transitional
// heuristics (features 004/063) depend on that failure.
//
// Parameters
//   src: source string (need not be null-terminated when srcLen >= 0)
//   srcLen: length of src in bytes/WCHARs, or -1 for null-terminated
//   buf: destination buffer (may be NULL to query the required size)
//   bufSize: destination capacity in WCHARs/bytes
//
// Return Values
//   Number of WCHARs/bytes written including the terminating null
//   (or required size when buf == NULL); 0 on failure.
//
int SalU8ToW(const char* src, int srcLen, WCHAR* buf, int bufSize);
int SalWToU8(const WCHAR* src, int srcLen, char* buf, int bufSize);

// Allocating variants; caller releases with free(). Return NULL on failure.
WCHAR* SalU8ToWAlloc(const char* src, int srcLen = -1);
char* SalWToU8Alloc(const WCHAR* src, int srcLen = -1);

//*****************************************************************************
//
// SalLegacyToU8Alloc
//
// Normalize text of uncertain legacy origin to UTF-8 (feature 052).
//
// Returns a malloc'd copy of src: byte-identical when src already is valid
// UTF-8 (ASCII included), otherwise converted CP_ACP -> UTF-8 - the same
// transitional tolerance the registry facade applies on write
// (SalRegSetValueExW8). Use at intake boundaries whose producers still emit
// ANSI, e.g. plugin-supplied metadata (contract:
// specs/052-fix-plugin-name-encoding/contracts/plugin-metadata-encoding.md).
//
// maxBytes >= 0 clamps the result to at most maxBytes bytes (terminator
// excluded), cutting only at a UTF-8 sequence boundary; -1 = no limit.
//
// Return Values
//   malloc'd string (caller frees); NULL only for NULL input or when
//   allocation/conversion fails.
//
char* SalLegacyToU8Alloc(const char* src, int maxBytes = -1);

//*****************************************************************************
//
// SalU8ToWDisplay
//
// LENIENT UTF-8 -> UTF-16 conversion, for DISPLAY ONLY (feature 041).
//
// Unlike SalU8ToW, malformed input does not fail: each offending byte becomes
// U+FFFD and conversion continues. WTF-8 names (feature 066) decode to their
// true units first, so a lone surrogate paints as the font's notdef glyph,
// exactly like Explorer. Use this only where the result is drawn and
// then discarded.
//
// NEVER use it on a value that will be written back into a name, a path, or
// anything persisted - substituting characters there would corrupt user data,
// which is exactly what the strict variant above exists to prevent.
//
// Rationale: a display surface that composes several fields into one string
// must not let one bad field destroy the others. Strict conversion turns a
// single stray byte into a whole unreadable line; this turns it into a single
// visible replacement character.
//
// Return Values
//   Number of WCHARs written including the terminating null (or the required
//   size when buf == NULL); 0 only when src is NULL or the buffer is too small.
//
int SalU8ToWDisplay(const char* src, int srcLen, WCHAR* buf, int bufSize);

// Allocating variant; caller releases with free(). NULL only when src is NULL
// or the allocation fails - never because the input was malformed.
WCHAR* SalU8ToWDisplayAlloc(const char* src, int srcLen = -1);

//*****************************************************************************
//
// Locale text as UTF-8 (feature 041)
//
// The application's narrow strings are UTF-8. These wrappers close the last
// hole in that rule: text obtained from the user's regional settings. Each
// calls the W variant of the underlying API and converts the result to UTF-8,
// so callers get text in the same encoding as everything else they concatenate
// it with.
//
// Before feature 041 the ANSI variants were called directly, and their output
// - the Czech thousands separator is a non-breaking space, one 0xA0 byte -
// made the composed string invalid UTF-8. Every non-ASCII character in the
// information line was then rendered through the legacy byte path as mojibake.
//
// Return Values
//   Number of BYTES written including the terminating null, or 0 on failure -
//   matching the A functions these replace, so existing "== 0" checks and
//   "- 1" length arithmetic keep working (the value is a byte count in both).
//
int SalGetLocaleInfoU8(LCID locale, LCTYPE lcType, char* u8Buf, int u8BufSize);
int SalGetDateFormatU8(LCID locale, DWORD flags, const SYSTEMTIME* date,
                       const char* u8Format, char* u8Buf, int u8BufSize);
int SalGetTimeFormatU8(LCID locale, DWORD flags, const SYSTEMTIME* time,
                       const char* u8Format, char* u8Buf, int u8BufSize);

//*****************************************************************************
//
// SalWToACPLossless
//
// Convert UTF-16 to the system legacy ANSI code page WITHOUT best-fit
// mapping. Used by the legacy plugin adaptation shim (contract §2):
// a lossy result means the item must be refused, never passed altered.
//
// Return Values
//   TRUE when every character was representable; FALSE otherwise
//   (buf receives nothing usable on FALSE).
//
BOOL SalWToACPLossless(const WCHAR* src, int srcLen, char* buf, int bufSize);

//*****************************************************************************
//
// SalNormalizeNFC
//
// Normalize a UTF-16 string to Unicode Normalization Form C.
// Output is a transient value for matching/collation; never write it
// back into stored names.
//
// Return Values
//   Number of WCHARs written including the terminating null (or the
//   estimated required size when buf == NULL); 0 on failure.
//
int SalNormalizeNFC(const WCHAR* src, int srcLen, WCHAR* buf, int bufSize);
WCHAR* SalNormalizeNFCAlloc(const WCHAR* src, int srcLen = -1); // free() the result

//*****************************************************************************
//
// SalIsASCII
//
// Fast path predicate: TRUE when the buffer contains only bytes < 0x80.
// ASCII-only strings are valid UTF-8 and byte-wise comparable, so
// callers keep the legacy comparators for them (research.md R5).
//
BOOL SalIsASCII(const char* s, int len = -1);

//*****************************************************************************
//
// SalU8Next / SalU8CharCount
//
// Walk and measure UTF-8 by characters (code points). SalU8Next returns the
// pointer behind the character starting at 's' (identity on the terminator).
// SalU8CharCount counts the characters in the first 'len' bytes (-1 =
// null-terminated). Byte-oriented callers that pad or truncate visible text
// use these so a multi-byte character is never split (feature 063).
//
const char* SalU8Next(const char* s);
int SalU8CharCount(const char* s, int len = -1);

//
// ****************************************************************************
// SalU8TrimIncompleteTail
//
// Drops a trailing INCOMPLETE UTF-8 sequence, in place.  A byte-count clamp
// (lstrcpyn, _snprintf_s, a fixed-size field) can cut a multi-byte character in
// half; the torn tail then makes every strict probe fail, and the whole string
// is re-read through the legacy code page - one torn character turns the entire
// text into mojibake.  A COMPLETE character at the end is left alone, so this
// is safe to call unconditionally on any UTF-8 buffer (feature 069).

void SalU8TrimIncompleteTail(char* buf);

//
// ****************************************************************************
// SalWToU8Truncate (feature 093, contract D4)
//
// SalWToU8 for a null-terminated text and a buffer that may be too short: when
// the UTF-8 form does not fit, stores as many WHOLE characters as fit (never a
// torn sequence) instead of failing.  Always terminates 'buf'.  Returns the
// bytes written including the terminator (>= 1); 0 only for a NULL argument,
// bufSize <= 0 or lack of memory ('buf' is then empty when it exists).

int SalWToU8Truncate(const WCHAR* src, char* buf, int bufSize);

//
// ****************************************************************************
// SalMnemonicMatchW (feature 093)
//
// TRUE when the UTF-16 unit 'typed' (WM_CHAR / WM_SYSCHAR of a wide message
// loop) is the mnemonic of 'text' - the character after the first single '&'
// ("&&" is a literal ampersand).  'text' is UTF-8 (legacy code-page text is
// accepted); letter case is ignored.  A mnemonic outside the BMP never matches.
// SalACPCharToW converts a code-page WM_CHAR byte for the same comparison
// (0 when the byte is not a character of the code page by itself).  The byte
// of a code-page message loop is in the code page of the active KEYBOARD
// LAYOUT; this takes it to be the system code page, so with a layout of
// another code page an accented mnemonic does not match (it never matched
// before feature 093 either).  A wide loop has no such limit.

BOOL SalMnemonicMatchW(const char* text, WCHAR typed);
WCHAR SalACPCharToW(char c);

//
// ****************************************************************************
// SalU8ToOEM / SalOEMToU8
//
// The console (OEM) code page boundary of the external-archiver subsystem: a
// list file handed to RAR/ARJ/LHA/UC2/ACE, and the names parsed back out of the
// archiver's console output.  These are NOT general-purpose converters - use
// them only where an external console program is on the other side.
//
// The pair must always be used together.  Before feature 069 the two directions
// were CharToOem(<UTF-8>) and OemToCharBuff(<OEM> -> <UTF-8 field>): both wrong,
// but wrong in opposite directions, so an ACP-representable name survived a pack
// -> list -> extract round trip by accident while a pack of that name failed
// outright.  Converting only one direction would have broken the round trip.
//
// Both return the number of bytes written including the terminator, or 0 on
// failure (and then leave 'buf' empty); a character the OEM code page cannot
// represent makes SalU8ToOEM fail rather than silently substituting '?', because
// the result is used to name a file the archiver must find.

// Converts UTF-8 back to the active code page, for a boundary that is ANSI by
// contract and must keep receiving exactly the bytes it received before: an
// ANSI common dialog's OPENFILENAME, or a value handed to a plugin under the
// frozen ANSI plugin contract.  Returns the bytes written including the
// terminator, 0 on failure (and then leaves 'buf' empty).  Lossy by nature -
// a character the code page cannot express becomes the API's default - which
// is exactly the pre-existing behaviour of those boundaries (feature 069).
int SalU8ToACP(const char* u8, char* buf, int bufSize);

int SalU8ToOEM(const char* u8, char* buf, int bufSize);
int SalOEMToU8(const char* oem, char* u8Buf, int u8BufSize);

//*****************************************************************************
//
// SalNameEquivalent
//
// TRUE when two UTF-8 names are canonically equivalent (their NFC
// forms are binary-identical). Case-SENSITIVE. Byte-identical names
// are always equivalent (fast path, no conversion).
//
BOOL SalNameEquivalent(const char* u8a, const char* u8b);

//*****************************************************************************
//
// SalCompareNamesUTF8
//
// Locale collation of two UTF-8 names for panel sorting (FR-009).
// Canonically equivalent names compare equal here; callers tie-break
// with a binary comparison to keep the order deterministic.
// ASCII fast path is NOT applied here - callers decide (sort.cpp
// keeps its byte-wise comparators when both names are ASCII).
//
// Return Values
//   < 0, 0, > 0  (strcmp convention); on conversion failure falls back
//   to strcmp so sorting never loses items.
//
int SalCompareNamesUTF8(const char* u8a, int aLen, const char* u8b, int bLen, BOOL ignoreCase);

//*****************************************************************************
//
// SalNameEqualCI
//
// Case-insensitive, canonical-equivalence-insensitive equality of two
// UTF-8 names (quick search, Find, mask matching - FR-008).
//
BOOL SalNameEqualCI(const char* u8a, int aLen, const char* u8b, int bLen);
//*****************************************************************************
//
// Name identity (feature 092, encoding cluster B-2)
//
// "Are these two names the same name?" - answered the way the file system
// answers it: case-insensitive, character by character, with NO other
// equivalences (no normalization, no linguistic rules, no ignorable
// characters). In Windows terms: ordinal, ignore case - what NTFS does with
// its upper-case table.
//
// This is NOT SalNameEqualCI. That one is linguistic (and NFC-insensitive):
// it calls "strasse" and "straße" equal, and a name with a soft hyphen equal
// to the name without it - right for SEARCHING, wrong for deciding whether two
// names are the same file. And it is not StrICmp, which folds the BYTES of
// UTF-8 with the system code page table: "Č.txt" != "č.txt", yet on a Central
// European system "ĥ" == "Ĺ".
//
// How two strings compare:
//   - the leading ASCII characters by an ASCII fold to UPPER case;
//   - from the first non-ASCII byte on ("the tail"): two valid WTF-8 tails as
//     UTF-16 by CompareStringOrdinal(..., TRUE); two tails that are not WTF-8
//     (a legacy plug-in's text) by the legacy byte fold (CharLowerA per byte),
//     so their EQUALITY is exactly StrICmpEx's; a valid tail sorts before an
//     invalid one and never equals it.
// For valid WTF-8 that is CompareStringOrdinal on the whole strings, and it is
// a total order over all byte strings - a sorted list may hold any mix.
//
// Contract: specs/092-name-identity-unicode/contracts/name-identity.md
//

// three-way comparison; 'aLen'/'bLen' are byte counts or -1 (null-terminated);
// NULL counts as an empty string. Use it on BOTH sides of a sorted list (the
// sort and the search), never together with StrICmp.
int SalNameCompareOrdinalCI(const char* a, int aLen, const char* b, int bLen);

// the same relation as a yes/no answer (byte-equal fast path)
BOOL SalNameEqualOrdinalCI(const char* a, int aLen, const char* b, int bLen);

// two paths are the same place: IsTheSamePath's rules (one leading and one
// trailing backslash on either side do not matter) with the identity above
BOOL SalPathEqualOrdinalCI(const char* path1, const char* path2);

// TRUE when 'path' starts with a string equal to the first 'prefixLen' bytes
// of 'prefix' (-1 = the whole of it). On TRUE '*pathBytes' (may be NULL) is
// the number of bytes of 'path' the prefix covers - look at path[*pathBytes]
// (a backslash or the end), never at path[prefixLen]: equal characters need
// not have equal UTF-8 lengths. A prefix that would end inside a character of
// 'path' is not a prefix. Replaces StrNICmp(path, prefix, prefixLen) == 0.
BOOL SalPathHasPrefixOrdinalCI(const char* path, const char* prefix, int prefixLen, int* pathBytes);
