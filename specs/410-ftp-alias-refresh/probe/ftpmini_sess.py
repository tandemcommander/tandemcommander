"""Feature 410: feature 323's ftpmini_hide.py with a session number in every log line.

Usage: python -I ftpmini_sess.py ROOT PORT LOG [ENC ...] - the arguments of ftpmini_hide.py,
unchanged. Every JSON line the server logs carries "sid": the number of the control connection
(1, 2, ... in the order they were accepted; 0 = the server itself), so a probe can tell the
panel's connection from an operation's worker connections.

Kick (review 1 of 410): a file LOG + '.kick' holding a session number makes the server close that
control connection (as a server ending an idle session does); the file is deleted and the server
logs {"event": "kicked", "kicked": N}.
"""
import os
import sys

here = os.path.dirname(os.path.abspath(__file__))
src_path = os.path.join(here, '..', '..', '323-ftp-upload-cache-args', 'probe', 'ftpmini_hide.py')
if not os.path.exists(src_path):  # a copy outside the repository: the folder is given by FTPMINI_DIR
    src_path = os.path.join(os.environ.get('FTPMINI_DIR', here), 'ftpmini_hide.py')
with open(src_path, encoding='utf-8') as f:
    src = f.read()

KICK = '''_log_lock = threading.Lock()
_SID = threading.local()
_SID_NEXT = [0]
_SOCKS = {}
_KICKER = []


def _kicker():
    kick = LOG + '.kick'
    while True:
        time.sleep(0.2)
        try:
            with open(kick, encoding='ascii') as kf:
                n = int(kf.read().strip() or '0')
            os.remove(kick)
        except (OSError, ValueError):
            continue
        s = _SOCKS.get(n)
        if s is not None:
            try:
                s.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
        log({'event': 'kicked', 'kicked': n})
'''

HANDLE = '''    def handle(self):
        with _log_lock:
            _SID_NEXT[0] += 1
            _SID.v = _SID_NEXT[0]
            _SOCKS[_SID.v] = self.request
            if not _KICKER:
                _KICKER.append(threading.Thread(target=_kicker, daemon=True))
                _KICKER[0].start()
        log({'event': 'connect'})
'''

pairs = [
    ("_log_lock = threading.Lock()\n", KICK),
    ("    obj['t'] = round(time.time() - T0, 3)\n",
     "    obj['t'] = round(time.time() - T0, 3)\n    obj['sid'] = getattr(_SID, 'v', 0)\n"),
    ("    def handle(self):\n        log({'event': 'connect'})\n", HANDLE),
]
for old, new in pairs:
    if src.count(old) != 1:
        sys.exit('ftpmini_hide.py changed: ' + old.strip())
    src = src.replace(old, new)

sys.argv[0] = src_path
exec(compile(src, src_path, 'exec'), {'__name__': '__main__', '__file__': src_path})
