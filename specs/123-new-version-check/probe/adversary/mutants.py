#!/usr/bin/env python3
"""Mutation test of the adversarial suite itself.

Each mutant is the header with ONE deliberate defect of the kind the suite claims to look for.
The suite must notice ("kill") it; a mutant that survives is a hole in the suite, and the claim
"no finding" would mean nothing there. The header under src/ is never touched - mutated copies
live in out/mutants/<name>/.

    python mutants.py            all mutants
    python mutants.py name ...   chosen ones
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
HEADER = os.path.join(HERE, "..", "..", "..", "..", "src", "common", "salupdcheck.h")

# (name, what it breaks, old text, new text) - 'old' must occur exactly once
M = [
    ("depth_33", "nesting limit off by one", "#define SALUPD_MAX_DEPTH 32 ", "#define SALUPD_MAX_DEPTH 33 "),
    ("depth_asset_elem", "a non-object asset element counted one level too shallow", "return r.SkipValue(3); // not an object", "return r.SkipValue(2); // not an object"),
    ("depth_asset_member", "an asset member counted one level too shallow", "else if (!r.SkipValue(4))", "else if (!r.SkipValue(3))"),
    ("depth_top_member", "a top-level member counted one level too shallow", "            else if (!r.SkipValue(2))\n                return FALSE;\n\n", "            else if (!r.SkipValue(1))\n                return FALSE;\n\n"),
    ("fit_off_by_one", "string buffer overflow by the terminator", "if (o + n >= outSize)", "if (o + n > outSize)"),
    ("name_prefix", "asset name compared as a prefix", "nameOk = isString && !bad && strcmp(value, wantName) == 0;", "nameOk = isString && !bad && strncmp(value, wantName, strlen(wantName)) == 0;"),
    ("url_prefix", "installer address compared as a prefix", "urlOk = isString && !bad && strcmp(value, wantUrl) == 0;", "urlOk = isString && !bad && strncmp(value, wantUrl, strlen(wantUrl)) == 0;"),
    ("url_bad_ignored", "a 'bad' address (escaped NUL / too long) compared anyway", "urlOk = isString && !bad && strcmp(value, wantUrl) == 0;", "urlOk = isString && strcmp(value, wantUrl) == 0;"),
    ("asset_dups_ok", "duplicate members inside an asset allowed", "*matches = names == 1 && states == 1 && urls == 1 && nameOk", "*matches = nameOk"),
    ("tag_dup_ok", "a second tag_name not reported", "                if (top->HasTag)\n                    *duplicate = TRUE;\n", ""),
    ("assets_dup_ok", "a second assets member not reported", "    if (assetsSeen > 1)\n        *duplicate = TRUE;\n", ""),
    ("trailing_ok", "bytes after the object allowed", "if (r.IsFailed() || !r.AtEnd())", "if (r.IsFailed())"),
    ("draft_null_ok", "draft null accepted", "if (top.Draft != 0)", "if (top.Draft > 0)"),
    ("prerelease_any", "prerelease of another type accepted", "if (top.Prerelease != 0)", "if (top.Prerelease == 1)"),
    ("control_ok", "raw control characters in strings", "if (c < 0x20)\n                return Fail();", "if (c < 0x09)\n                return Fail();"),
    ("leap_100", "century years are leap years", "st.wYear % 100 != 0 || st.wYear % 400 == 0", "st.wYear % 100 != 0 || st.wYear % 200 == 0"),
    ("second_60", "second 60 accepted", "st.wMinute > 59 || st.wSecond > 59", "st.wMinute > 59 || st.wSecond > 60"),
    ("hour_24", "hour 24 accepted", "st.wHour > 23", "st.wHour > 24"),
    ("escaped_nul_ok", "an escaped NUL cuts the string silently", "                    else if (cp == 0)\n                        isBad = TRUE;\n", ""),
    ("lone_low_ok", "a lone low surrogate is not 'bad'", "else if (cp >= 0xDC00 && cp <= 0xDFFF)\n                    {\n                        isBad = TRUE;", "else if (cp >= 0xDC00 && cp <= 0xDFFF)\n                    {\n                        isBad = FALSE;"),
    ("pair_low_range", "a high surrogate pairs with another high one", "if (lo >= 0xDC00 && lo <= 0xDFFF)", "if (lo >= 0xD800 && lo <= 0xDFFF)"),
    ("digits_6", "6 digits in a version part", "#define SALUPD_MAX_VERSION_DIGITS 5 ", "#define SALUPD_MAX_VERSION_DIGITS 6 "),
    ("number_leading_zero", "numbers with leading zeros", "        if (*P == '0')\n            P++;\n        else if (*P >= '1' && *P <= '9')", "        if (*P == 'x')\n            P++;\n        else if (*P >= '0' && *P <= '9')"),
    ("number_no_frac_digit", "'1.' accepted", "            if (P >= End || *P < '0' || *P > '9')\n                return Fail();\n            while (P < End && *P >= '0' && *P <= '9')\n                P++;\n        }\n        if (P < End && (*P == 'e'", "            while (P < End && *P >= '0' && *P <= '9')\n                P++;\n        }\n        if (P < End && (*P == 'e'"),
    ("state_any", "any asset state", "stateOk = isString && !bad && strcmp(value, \"uploaded\") == 0;", "stateOk = isString;"),
    ("notes_unchecked", "html_url not compared", "if (top.HtmlUrlBad || strcmp(top.HtmlUrl, wantNotes) != 0)", "if (top.HtmlUrlBad)"),
    ("port_65536", "port 65536", "value > 65535", "value > 65536"),
    ("loop_hash_ok", "'#' in the loopback path", " || p[n] == L'#'", ""),
    ("loop_space_ok", "a space in the loopback path", "if (p[n] <= 0x20 ||", "if (p[n] < 0x20 ||"),
    ("loop_size", "loopback path buffer overflow by the terminator", "if (n >= pathSize)", "if (n > pathSize)"),
    ("append_number_size", "number printed into a buffer one byte too small", "if (p == NULL || end - p <= n)", "if (p == NULL || end - p < n)"),
    ("append_text_size", "text printed into a buffer one byte too small", "if ((size_t)(end - p) <= n)", "if ((size_t)(end - p) < n)"),
    ("formfeed_space", "form feed is white space", "*P == '\\n' || *P == '\\r'))", "*P == '\\n' || *P == '\\r' || *P == '\\f'))"),
    ("literal_prefix", "'tru' + any byte is true (and reads past the end)", "if (left >= 4 && memcmp(P, \"true\", 4) == 0)", "if (left >= 3 && memcmp(P, \"tru\", 3) == 0)"),
    ("hex_g", "'G' is a hex digit", "else if (c >= 'A' && c <= 'F')", "else if (c >= 'A' && c <= 'G')"),
    ("hex_overread", "\\u escape read past the end", "if (End - P < 4)\n            return Fail();", "if (End - P < 1)\n            return Fail();"),
    ("last_asset_wins", "only the last asset counts", "                            if (matches && installerFound != NULL)\n                                *installerFound = TRUE;", "                            if (installerFound != NULL)\n                                *installerFound = matches;"),
    ("tag_v_optional", "the v of a tag is optional", "        if (len < 1 || s[0] != 'v')\n            return FALSE;\n        i = 1;", "        if (len >= 1 && s[0] == 'v')\n            i = 1;"),
    ("version_trailing", "text after the version allowed", "    if (i != len)\n        return FALSE;\n    v->Major = parts[0];", "    v->Major = parts[0];"),
    ("due_strict", "due one tick late", "return now - lastAttempt >= interval;", "return now - lastAttempt > interval;"),
    ("due_future", "a time in the future blocks checks", "if (!hasLastAttempt || lastAttempt > now)", "if (!hasLastAttempt)"),
    ("strip_ddd", "the short weekday name stays", "if (run < 3) //", "if (run < 4) //"),
    ("no_escaped_slash", "\\/ refused", "                case '/':\n                    cp = '/';\n                    break;\n", ""),
    ("status_403", "403 is not 'refused'", "(status == 403 || status == 429)", "(status == 429)"),
    ("time_text_len", "time shorter than 20 bytes accepted", "    if (len != 20)\n        return FALSE;\n    static const char pattern", "    if (len > 20)\n        return FALSE;\n    static const char pattern"),
    ("compare_minor", "minor compared the wrong way", "return a.Minor < b.Minor ? -1 : 1;", "return a.Minor > b.Minor ? -1 : 1;"),
    ("key_no_bad", "a too long or 'bad' member name is compared by what was stored", "if (isBad)\n                out[0] = 0;\n            else\n                out[o] = 0;", "out[o] = 0;"),
    ("empty_asset_array_skip", "assets not examined when it starts with white space", "if (top != NULL || r.Peek() != '[')", "if (top != NULL || r.Peek() != '[' || len > 100000)"),
    ("size_limit", "answers over 256 KB accepted", "len == 0 || len > SALUPD_MAX_ANSWER", "len == 0"),
]


def run(args, **kw):
    return subprocess.run(args, capture_output=True, text=True, **kw)


def main():
    src = open(HEADER, encoding="utf-8-sig").read()
    chosen = sys.argv[1:]
    results = []
    for name, what, old, new in M:
        if chosen and name not in chosen:
            continue
        if src.count(old) != 1:
            print("%-22s SKIPPED: the text to mutate occurs %d times" % (name, src.count(old)))
            results.append((name, what, "NOT APPLIED"))
            continue
        d = os.path.join(HERE, "out", "mutants", name)
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, "salupdcheck.h"), "w", encoding="utf-8", newline="") as f:
            f.write(src.replace(old, new))
        p = run(["cmd", "/c", os.path.join(HERE, "build_mutant.cmd"), d])
        if p.returncode != 0:
            print("%-22s BUILD FAILED (see %s\\build.log)" % (name, d))
            results.append((name, what, "BUILD FAILED"))
            continue
        asan, o2 = os.path.join(d, "adv_asan.exe"), os.path.join(d, "adv_o2.exe")
        killed = None
        stages = [
            ("unit", [asan, "unit"]),
            ("hand+random", [sys.executable, os.path.join(HERE, "adv.py"), "--seed", "1", "--count", os.environ.get("ADV_MUTANT_COUNT", "1500"), "--exe", asan]),
            ("exhaustive", [sys.executable, os.path.join(HERE, "adv.py"), "--exh", "--exe", o2]),
            ("perf", [o2, "perf"]),
        ]
        for stage, args in stages:
            p = run(args)
            if p.returncode != 0:
                first = [l for l in (p.stdout + p.stderr).split("\n") if ("FAILED" in l or "disagreements" in l and ", 0 dis" not in l or
                                                                           "STRIP" in l or "ERROR" in l or "HARNESS" in l)]
                killed = "%s: %s" % (stage, (first[0].strip()[:150] if first else "exit %d" % p.returncode))
                break
        print("%-22s %s" % (name, "killed by " + killed if killed else "SURVIVED  <-- a hole in the suite (%s)" % what))
        results.append((name, what, killed or "SURVIVED"))
    n = len(results)
    k = sum(1 for r in results if r[2] not in ("SURVIVED", "NOT APPLIED", "BUILD FAILED"))
    print("mutants: %d, killed %d, survived %d, not applied %d" %
          (n, k, sum(1 for r in results if r[2] == "SURVIVED"), sum(1 for r in results if r[2] in ("NOT APPLIED", "BUILD FAILED"))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
