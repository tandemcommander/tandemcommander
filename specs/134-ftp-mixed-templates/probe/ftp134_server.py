"""Feature 134 probe helper: a small FTP server on 127.0.0.1 (standard library only).

Usage: python ftp134_server.py <port> <logfile>

It serves a fixed tree with accented names (listed as UTF-8), logs every received command
line as hex (one "RECV <hex>" line each - the probe compares these bytes before and after
the feature), and refuses chosen commands with a reply whose text and encoding depend on the
directory the client is in:

  /enc-utf8   MKD, DELE, RMD, RNFR, CWD of an unknown name: "550 <name>: <reason>" with the
              name as UTF-8 bytes
  /enc-cp     the same with the name in code page 1250
  /enc-ascii  "550 Requested action not taken." (no name)
  elsewhere   as /enc-utf8

A file whose name starts with "slow" is sent 2 KB at a time with a pause (the operation window
of the client stays open for about 40 seconds). Anonymous and any other login are accepted.
"""
import socket
import socketserver
import sys
import threading
import time

ACCENT_DIR = 'Žluťoučký kůň'
ACCENT_FILE = 'příliš žluťoučký.txt'
SLOW_FILE = 'slow žluťoučký kůň.bin'

TREE = {
    '/': {'dirs': [ACCENT_DIR, 'enc-utf8', 'enc-cp', 'enc-ascii', 'plain'],
          'files': {ACCENT_FILE: 3000, 'readme.txt': 1200}},
    '/' + ACCENT_DIR: {'dirs': [], 'files': {'soubor č. 1.txt': 500, SLOW_FILE: 400000}},
    '/enc-utf8': {'dirs': [], 'files': {'existující.txt': 10}},
    '/enc-cp': {'dirs': [], 'files': {'existující.txt': 10}},
    '/enc-ascii': {'dirs': [], 'files': {'existing.txt': 10}},
    '/plain': {'dirs': [], 'files': {'plain.txt': 2000, 'slow plain.bin': 400000}},
}

LOG_LOCK = threading.Lock()
LOG = None


def log(kind, data):
    with LOG_LOCK:
        LOG.write('%s %s\n' % (kind, data.hex() if isinstance(data, bytes) else data))
        LOG.flush()


def join(cwd, name):
    if name.startswith('/'):
        p = name
    else:
        p = cwd.rstrip('/') + '/' + name
    parts = []
    for part in p.split('/'):
        if part in ('', '.'):
            continue
        if part == '..':
            if parts:
                parts.pop()
            continue
        parts.append(part)
    return '/' + '/'.join(parts)


class Handler(socketserver.BaseRequestHandler):
    def send(self, raw):
        if isinstance(raw, str):
            raw = raw.encode('utf-8')
        self.request.sendall(raw + b'\r\n')

    def refusal(self, name_bytes, reason):
        """550 with the name in the encoding this directory stands for"""
        if self.cwd.startswith('/enc-ascii'):
            return b'550 Requested action not taken.'
        try:
            name = name_bytes.decode('utf-8')
        except UnicodeDecodeError:
            name = name_bytes.decode('cp1250', 'replace')
        enc = 'cp1250' if self.cwd.startswith('/enc-cp') else 'utf-8'
        return b'550 ' + name.encode(enc, 'replace') + b': ' + reason.encode('ascii')

    def data_conn(self):
        if self.pasv is not None:
            self.pasv.settimeout(15)
            conn, _ = self.pasv.accept()
            self.pasv.close()
            self.pasv = None
            return conn
        if self.port_addr is not None:
            conn = socket.create_connection(self.port_addr, timeout=15)
            self.port_addr = None
            return conn
        return None

    def decode_name(self, arg):
        try:
            return arg.decode('utf-8')
        except UnicodeDecodeError:
            return arg.decode('cp1250', 'replace')

    def handle(self):
        self.cwd = '/'
        self.pasv = None
        self.port_addr = None
        self.request.settimeout(600)
        log('CONN', 'new')
        try:
            self.send('220 tc134 test server')
            buf = b''
            while True:
                data = self.request.recv(4096)
                if not data:
                    return
                buf += data
                while b'\r\n' in buf:
                    line, buf = buf.split(b'\r\n', 1)
                    log('RECV', line)
                    if not self.command(line):
                        return
        except OSError:
            pass
        finally:
            if self.pasv is not None:
                self.pasv.close()

    def command(self, line):
        cmd = line.split(b' ', 1)[0].upper().decode('ascii', 'replace')
        arg = line[len(cmd) + 1:] if b' ' in line else b''
        name = self.decode_name(arg)
        if cmd == 'USER':
            self.send('331 Password required.')
        elif cmd == 'PASS':
            self.send('230 Logged in.')
        elif cmd == 'SYST':
            self.send('215 UNIX Type: L8')
        elif cmd == 'FEAT':
            self.send(b'211-Features:\r\n UTF8\r\n PASV\r\n211 End')
        elif cmd == 'OPTS':
            self.send('200 OK')
        elif cmd in ('TYPE', 'MODE', 'STRU', 'NOOP', 'ALLO'):
            self.send('200 OK')
        elif cmd == 'PWD':
            self.send(('257 "%s" is the current directory.' % self.cwd).encode('utf-8'))
        elif cmd == 'CDUP':
            self.cwd = join(self.cwd, '..')
            self.send('250 OK')
        elif cmd == 'CWD':
            target = join(self.cwd, name)
            if target in TREE:
                self.cwd = target
                self.send('250 OK')
            else:
                self.send(self.refusal(arg, 'No such file or directory.'))
        elif cmd == 'PASV':
            if self.pasv is not None:
                self.pasv.close()
            self.pasv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.pasv.bind(('127.0.0.1', 0))
            self.pasv.listen(1)
            port = self.pasv.getsockname()[1]
            self.send('227 Entering Passive Mode (127,0,0,1,%d,%d)' % (port >> 8, port & 255))
        elif cmd == 'PORT':
            try:
                n = [int(x) for x in arg.decode('ascii').split(',')]
                self.port_addr = ('%d.%d.%d.%d' % tuple(n[:4]), n[4] * 256 + n[5])
                self.send('200 OK')
            except (ValueError, IndexError):
                self.send('501 Bad PORT')
        elif cmd in ('LIST', 'NLST'):
            node = TREE.get(self.cwd, {'dirs': [], 'files': {}})
            rows = []
            for d in node['dirs']:
                rows.append('drwxr-xr-x 2 ftp ftp 4096 Oct 13 12:00 ' + d)
            for f, size in node['files'].items():
                rows.append('-rw-r--r-- 1 ftp ftp %d Oct 13 12:00 %s' % (size, f))
            self.send('150 Here comes the directory listing.')
            conn = self.data_conn()
            if conn is None:
                self.send('425 No data connection.')
                return True
            try:
                conn.sendall(('\r\n'.join(rows) + ('\r\n' if rows else '')).encode('utf-8'))
            finally:
                conn.close()
            self.send('226 Directory send OK.')
        elif cmd == 'SIZE':
            node = TREE.get(self.cwd, {'files': {}})
            if name in node['files']:
                self.send('213 %d' % node['files'][name])
            else:
                self.send(self.refusal(arg, 'No such file.'))
        elif cmd == 'MDTM':
            self.send('213 20261013120000')
        elif cmd == 'REST':
            self.send('350 OK')
        elif cmd == 'RETR':
            node = TREE.get(self.cwd, {'files': {}})
            base = name.rsplit('/', 1)[-1]
            if base not in node['files']:
                self.send(self.refusal(arg, 'No such file.'))
                return True
            size = node['files'][base]
            self.send('150 Opening data connection.')
            conn = self.data_conn()
            if conn is None:
                self.send('425 No data connection.')
                return True
            ok = True
            try:
                slow = base.startswith('slow')
                sent = 0
                while sent < size:
                    n = min(2048 if slow else 65536, size - sent)
                    conn.sendall(b'x' * n)
                    sent += n
                    if slow:
                        time.sleep(0.2)
            except OSError:
                ok = False
            finally:
                conn.close()
            self.send('226 Transfer complete.' if ok else '426 Transfer aborted.')
        elif cmd == 'STOR':
            self.send('150 OK to send data.')
            conn = self.data_conn()
            if conn is not None:
                try:
                    while conn.recv(65536):
                        pass
                except OSError:
                    pass
                conn.close()
            self.send('226 Transfer complete.')
        elif cmd in ('MKD', 'XMKD'):
            self.send(self.refusal(arg, 'File exists.'))
        elif cmd in ('DELE', 'RMD', 'XRMD', 'RNFR', 'SITE'):
            self.send(self.refusal(arg, 'Permission denied.'))
        elif cmd == 'ABOR':
            self.send('226 Abort OK.')
        elif cmd == 'QUIT':
            self.send('221 Goodbye.')
            return False
        else:
            self.send('502 Command not implemented.')
        return True


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


def main():
    global LOG
    port = int(sys.argv[1])
    LOG = open(sys.argv[2], 'a', encoding='ascii')
    with Server(('127.0.0.1', port), Handler) as srv:
        srv.serve_forever()


if __name__ == '__main__':
    main()
