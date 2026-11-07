"""Reproduce: lock update / release while another process holds the lock file open."""
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

REPO = Path(sys.argv[1])
TOOL = REPO / "tools" / "backlog" / "backlog.py"
d = Path(tempfile.mkdtemp())
lock = d / "tandem-backlog-run.lock"


def tool(*a):
    r = subprocess.run([sys.executable, str(TOOL), "--root", str(REPO), "--lock-dir", str(d), "lock", *a],
                       capture_output=True, text=True)
    return r.returncode, (r.stdout + r.stderr).strip().splitlines()[-1:] if (r.stdout + r.stderr).strip() else []


def holder(seconds):
    # a reader like Python's open(): no FILE_SHARE_DELETE
    return subprocess.Popen([sys.executable, "-c",
                             f"import time; f=open(r'{lock}', 'rb'); print('open', flush=True); time.sleep({seconds})"],
                            stdout=subprocess.PIPE, text=True)


print("acquire", tool("acquire", "--slug", "x"))
p = holder(5)
p.stdout.readline()
print("update while held (5 s)", tool("update", "--slug", "x", "--branch", "b"))
p.wait()
p = holder(5)
p.stdout.readline()
print("release while held (5 s)", tool("release", "--slug", "x"))
p.wait()
print("exists after", lock.exists())
p = holder(0.5)
p.stdout.readline()
t = time.time()
print("update while held (0.5 s)", tool("update", "--slug", "x", "--branch", "b2"), round(time.time() - t, 2))
p.wait()
p = holder(0.5)
p.stdout.readline()
t = time.time()
print("release while held (0.5 s)", tool("release", "--slug", "x"), round(time.time() - t, 2))
p.wait()
print("exists after", lock.exists())
shutil.rmtree(d, ignore_errors=True)
