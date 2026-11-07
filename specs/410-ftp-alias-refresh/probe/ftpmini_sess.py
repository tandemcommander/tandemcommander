"""Feature 410: feature 323's ftpmini_hide.py with a session number in every log line.

Usage: python -I ftpmini_sess.py ROOT PORT LOG [ENC ...] - the arguments of ftpmini_hide.py,
unchanged. Every JSON line the server logs carries "sid": the number of the control connection
(1, 2, ... in the order they were accepted; 0 = the server itself), so a probe can tell the
panel's connection from an operation's worker connections.
"""
import os
import sys

here = os.path.dirname(os.path.abspath(__file__))
src_path = os.path.join(here, '..', '..', '323-ftp-upload-cache-args', 'probe', 'ftpmini_hide.py')
if not os.path.exists(src_path):  # a copy outside the repository: the folder is given by FTPMINI_DIR
    src_path = os.path.join(os.environ.get('FTPMINI_DIR', here), 'ftpmini_hide.py')
with open(src_path, encoding='utf-8') as f:
    src = f.read()

pairs = [
    ("_log_lock = threading.Lock()\n",
     "_log_lock = threading.Lock()\n_SID = threading.local()\n_SID_NEXT = [0]\n"),
    ("    obj['t'] = round(time.time() - T0, 3)\n",
     "    obj['t'] = round(time.time() - T0, 3)\n    obj['sid'] = getattr(_SID, 'v', 0)\n"),
    ("    def handle(self):\n        log({'event': 'connect'})\n",
     "    def handle(self):\n        with _log_lock:\n            _SID_NEXT[0] += 1\n            _SID.v = _SID_NEXT[0]\n"
     "        log({'event': 'connect'})\n"),
]
for old, new in pairs:
    if src.count(old) != 1:
        sys.exit('ftpmini_hide.py changed: ' + old.strip())
    src = src.replace(old, new)

sys.argv[0] = src_path
exec(compile(src, src_path, 'exec'), {'__name__': '__main__', '__file__': src_path})
