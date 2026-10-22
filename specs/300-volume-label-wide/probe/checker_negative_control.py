# Feature 300 negative control: the checker's ansi-api-on-utf8-path rule run over a scratch tree
# holding only src/dialogs3.cpp, once as it is (expected: no SetVolumeLabel hit) and once with the
# old code-page call put back (expected: one hit). Run from the repository root:
#   python specs/300-volume-label-wide/probe/checker_negative_control.py
import pathlib
import shutil
import sys
import tempfile

repo = pathlib.Path(__file__).resolve().parents[3]
checker = (repo / "tools" / "check_encoding.py").read_text(encoding="utf-8-sig")
fixed = (repo / "src" / "dialogs3.cpp").read_text(encoding="utf-8-sig")
new_call = "res = SetVolumeLabelW(pathW, nameW);"
old_call = "res = SetVolumeLabel(volumePathWithBackslash, newName);"
if new_call not in fixed:
    sys.exit("the fixed call was not found in src/dialogs3.cpp")


def scan(text):
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="tc300_neg_"))
    try:
        (tmp / "src").mkdir()
        (tmp / "src" / "dialogs3.cpp").write_text(text, encoding="utf-8-sig")
        g = {"__name__": "check_encoding_neg", "__file__": str(repo / "tools" / "check_encoding.py")}
        exec(compile(checker, "check_encoding.py", "exec"), g)
        g["SRC"] = tmp / "src"
        hits = [f for f in g["scan_draft"]("ansi-api-on-utf8-path") if "SetVolumeLabel" in f.text]
        return [str(f) for f in hits]
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


now = scan(fixed)
old = scan(fixed.replace(new_call, old_call))
print("fixed source  : %d SetVolumeLabel hit(s) %s" % (len(now), now))
print("old call back : %d SetVolumeLabel hit(s) %s" % (len(old), old))
ok = len(now) == 0 and len(old) == 1
print("negative control: %s" % ("PASS" if ok else "FAIL"))
sys.exit(0 if ok else 1)
