// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salurlpwd.h
//
// Removing passwords from history entries (feature 085, privacy defect F1).
//
// A user may type an address with the password in it -
// "ftp://alice:secret@host/pub" - into Change Directory, a Copy/Move target,
// the command line or FTP Quick Connect. The operation needs the whole text;
// the HISTORY of the field must not keep the password, because histories are
// saved to the registry as plain text (and land in an exported configuration).
// These functions clean the copy kept for history; the value handed to the
// operation is never passed through them.
//
// Pure: no core or plugin globals. Compiled into salamand, saltests and the
// FTP plugin. Contract: specs/085-privacy-defect-fixes/contracts/history-password-strip.md
//
// Text is compared as bytes; every delimiter is ASCII, so UTF-8 is safe. The
// rule errs towards removing more: a history entry may lose a little more than
// the password, it must never keep any of it.
//
//*****************************************************************************

// C1: 'p' points at the start of an address part "[user[:password]@]host...".
// The part ends at '/' or the end of the string; with 'commandLine' also at a
// character <= ' ', '"', '\'', '<' and '>' (a command line separates words by
// them). Within the part, everything from the FIRST ':' (or "%3A") up to - not
// including - the LAST '@' (or "%40") is removed in place, so a password that
// itself contains '@', ' ', quotes or escapes leaves nothing behind. Nothing
// changes when the part has no '@', or no ':' before it ("host:2121" keeps its
// port). Returns TRUE when something was removed.
BOOL SalStripAuthorityPassword(char* p, BOOL commandLine);

// C2: one typed VALUE - a path or address (Change Directory, Copy/Move target,
// Find's Look in). The address part starts after each "scheme://" (scheme of
// 2+ characters - one letter is a drive), after a leading "name:" not followed
// by "//" ("ftp:user:pw@host"), and after a leading "//"; it ends only at '/'.
// Returns TRUE when anything was removed.
BOOL SalStripUrlPasswords(char* text);

// C2': a COMMAND LINE. Every "scheme://" anywhere (and the leading forms of C2)
// is cleaned; the address part ends at white space and quotes too, except that
// a URL right after a quote ends at the matching quote (or '/').
BOOL SalStripCommandLinePasswords(char* text);

// C2'': an ADDRESS field (FTP Quick Connect: "alice:pw@host" is an address
// there, while C2 would read "alice:" as a file-system name). Skips white
// space, then "name://", or one of the 'fsNames' (case-insensitive) followed by
// ':' and an optional "//", or a bare "//", and applies C1 (single value) to the
// rest. 'fsNames' may contain NULL or empty entries.
BOOL SalStripAddressPassword(char* address, const char* const* fsNames, int fsNameCount);

// C3: cleans a most-recent-first history array of malloc'ed strings: 'strip'
// is applied to every entry, an entry equal to an earlier one is freed, and
// the rest move up so that no NULL precedes an entry. Returns TRUE when the
// array changed. Call it from the module that allocated the strings.
BOOL SalStripHistoryPasswords(char** history, int count, BOOL (*strip)(char* text));
