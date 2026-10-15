"""A minimal FTP server for the GUI probes (feature 215).

Serves ROOT on 127.0.0.1:PORT (loopback only), any user / password; names on the wire are UTF-8
(FEAT announces UTF8). Every control line received is logged to LOG as one JSON object per line
({"t": seconds, "cmd": the raw line as text}); replies too ({"reply": ...}). A path never leaves ROOT.

    python -I ftpmini.py ROOT PORT LOG
"""
import json
import os
import socket
import socketserver
import sys
import threading
import time

ROOT = os.path.realpath(sys.argv[1])
PORT = int(sys.argv[2])
LOG = sys.argv[3]
_log_lock = threading.Lock()
T0 = time.time()


def log(obj):
    obj['t'] = round(time.time() - T0, 3)
    with _log_lock:
        with open(LOG, 'a', encoding='utf-8') as f:
            f.write(json.dumps(obj, ensure_ascii=True) + '\n')


def month(ts):
    return time.strftime('%b %d %H:%M', time.localtime(ts))


class Session(socketserver.StreamRequestHandler):
    def setup(self):
        super().setup()
        self.cwd = '/'
        self.pasv = None
        self.port_addr = None
        self.rnfr = None
        self.rest = 0

    def reply(self, text):
        log({'reply': text})
        self.wfile.write((text + '\r\n').encode('utf-8', 'surrogateescape'))
        self.wfile.flush()

    # the virtual path of 'arg' (relative to cwd) and its real path inside ROOT, or None
    def resolve(self, arg):
        v = arg if arg.startswith('/') else (self.cwd.rstrip('/') + '/' + arg)
        parts = []
        for p in v.split('/'):
            if p in ('', '.'):
                continue
            if p == '..':
                if parts:
                    parts.pop()
                continue
            parts.append(p)
        virt = '/' + '/'.join(parts)
        real = os.path.join(ROOT, *parts) if parts else ROOT
        realn = os.path.realpath(real)
        if realn != ROOT and not realn.startswith(ROOT + os.sep):
            return virt, None
        return virt, real

    def data_conn(self):
        if self.pasv is not None:
            self.pasv.settimeout(20)
            c, _ = self.pasv.accept()
            self.pasv.close()
            self.pasv = None
            return c
        if self.port_addr is not None:
            c = socket.create_connection(self.port_addr, timeout=20)
            self.port_addr = None
            return c
        return None

    def handle(self):
        log({'event': 'connect'})
        self.reply('220 ftpmini ready')
        while True:
            raw = self.rfile.readline()
            if not raw:
                log({'event': 'closed'})
                return
            line = raw.decode('utf-8', 'surrogateescape').rstrip('\r\n')
            log({'cmd': line})
            if line == '':
                self.reply('500 Empty command')
                continue
            verb, _, arg = line.partition(' ')
            verb = verb.upper()
            try:
                if not self.dispatch(verb, arg):
                    return
            except Exception as e:  # report and go on
                log({'error': repr(e)})
                self.reply('451 Local error: ' + type(e).__name__)

    def dispatch(self, verb, arg):
        if verb == 'USER':
            self.reply('331 Password required')
        elif verb == 'PASS':
            self.reply('230 Logged in')
        elif verb == 'SYST':
            self.reply('215 UNIX Type: L8')
        elif verb == 'FEAT':
            self.wfile.write(b'211-Features:\r\n UTF8\r\n SIZE\r\n MDTM\r\n REST STREAM\r\n211 End\r\n')
            self.wfile.flush()
            log({'reply': '211 features'})
        elif verb in ('OPTS', 'MODE', 'STRU', 'TYPE', 'ALLO', 'SITE', 'NOOP', 'CLNT'):
            self.reply('200 OK')
        elif verb == 'PWD' or verb == 'XPWD':
            self.reply('257 "%s" is the current directory' % self.cwd.replace('"', '""'))
        elif verb in ('CWD', 'XCWD', 'CDUP', 'XCUP'):
            v, r = self.resolve('..' if verb in ('CDUP', 'XCUP') else arg)
            if r is not None and os.path.isdir(r):
                self.cwd = v
                self.reply('250 Directory changed to ' + v)
            else:
                self.reply('550 No such directory')
        elif verb == 'PASV':
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.bind(('127.0.0.1', 0))
            s.listen(1)
            self.pasv = s
            p = s.getsockname()[1]
            self.reply('227 Entering Passive Mode (127,0,0,1,%d,%d)' % (p >> 8, p & 255))
        elif verb == 'EPSV':
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.bind(('127.0.0.1', 0))
            s.listen(1)
            self.pasv = s
            self.reply('229 Entering Extended Passive Mode (|||%d|)' % s.getsockname()[1])
        elif verb == 'PORT':
            n = [int(x) for x in arg.split(',')]
            host = '.'.join(str(x) for x in n[:4])
            if host != '127.0.0.1':
                self.reply('501 Loopback only')
            else:
                self.port_addr = (host, n[4] * 256 + n[5])
                self.reply('200 PORT OK')
        elif verb in ('LIST', 'NLST'):
            target = ' '.join(a for a in arg.split(' ') if a and not a.startswith('-'))
            v, r = self.resolve(target or '.')
            if r is None or not os.path.isdir(r):
                self.reply('550 No such directory')
                return True
            self.reply('150 Here comes the listing')
            c = self.data_conn()
            out = []
            for name in sorted(os.listdir(r)):
                st = os.stat(os.path.join(r, name))
                if verb == 'NLST':
                    out.append(name)
                elif os.path.isdir(os.path.join(r, name)):
                    out.append('drwxr-xr-x 1 owner group %d %s %s' % (0, month(st.st_mtime), name))
                else:
                    out.append('-rw-r--r-- 1 owner group %d %s %s' % (st.st_size, month(st.st_mtime), name))
            c.sendall(''.join(x + '\r\n' for x in out).encode('utf-8', 'surrogateescape'))
            c.close()
            self.reply('226 Listing sent')
        elif verb == 'RETR':
            v, r = self.resolve(arg)
            if r is None or not os.path.isfile(r):
                self.reply('550 No such file')
                return True
            self.reply('150 Sending')
            c = self.data_conn()
            with open(r, 'rb') as f:
                f.seek(self.rest)
                c.sendall(f.read())
            self.rest = 0
            c.close()
            self.reply('226 Sent')
        elif verb in ('STOR', 'APPE'):
            v, r = self.resolve(arg)
            if r is None or not os.path.isdir(os.path.dirname(r)):
                self.reply('553 Cannot store here')
                return True
            self.reply('150 Receiving')
            c = self.data_conn()
            with open(r, 'ab' if verb == 'APPE' else 'wb') as f:
                while True:
                    b = c.recv(65536)
                    if not b:
                        break
                    f.write(b)
            c.close()
            self.reply('226 Stored')
        elif verb == 'SIZE':
            v, r = self.resolve(arg)
            if r is not None and os.path.isfile(r):
                self.reply('213 %d' % os.path.getsize(r))
            else:
                self.reply('550 No such file')
        elif verb == 'MDTM':
            v, r = self.resolve(arg)
            if r is not None and os.path.exists(r):
                self.reply('213 ' + time.strftime('%Y%m%d%H%M%S', time.gmtime(os.path.getmtime(r))))
            else:
                self.reply('550 No such file')
        elif verb == 'REST':
            self.rest = int(arg or '0')
            self.reply('350 Restarting at %d' % self.rest)
        elif verb == 'DELE':
            v, r = self.resolve(arg)
            if r is not None and os.path.isfile(r):
                os.remove(r)
                self.reply('250 Deleted')
            else:
                self.reply('550 No such file')
        elif verb in ('RMD', 'XRMD'):
            v, r = self.resolve(arg)
            if r is not None and r != ROOT and os.path.isdir(r):
                os.rmdir(r)
                self.reply('250 Removed')
            else:
                self.reply('550 Cannot remove')
        elif verb in ('MKD', 'XMKD'):
            v, r = self.resolve(arg)
            if r is not None and not os.path.exists(r) and os.path.isdir(os.path.dirname(r)):
                os.mkdir(r)
                self.reply('257 "%s" created' % v.replace('"', '""'))
            else:
                self.reply('550 Cannot create')
        elif verb == 'RNFR':
            v, r = self.resolve(arg)
            if r is not None and os.path.exists(r):
                self.rnfr = r
                self.reply('350 Ready for RNTO')
            else:
                self.reply('550 No such file')
        elif verb == 'RNTO':
            v, r = self.resolve(arg)
            if self.rnfr is not None and r is not None and not os.path.exists(r):
                os.rename(self.rnfr, r)
                self.rnfr = None
                self.reply('250 Renamed')
            else:
                self.reply('550 Cannot rename')
        elif verb == 'ABOR':
            self.reply('226 Aborted')
        elif verb == 'QUIT':
            self.reply('221 Bye')
            return False
        else:
            self.reply('502 Not implemented')
        return True


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == '__main__':
    log({'event': 'start', 'root': ROOT, 'port': PORT})
    with Server(('127.0.0.1', PORT), Session) as srv:
        srv.serve_forever()
