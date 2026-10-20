"""An SFTP server for the GUI probe of feature 258: a "drop" folder in which the server lets an
account create and write files but refuses to tell anything about them - the model of an
upload-only folder (SFTPGo's "upload" permission without "list", hosted drop boxes). 127.0.0.1
only, password login; every request logged (one line each).

    python dropsftp.py PORT ROOT LOG [USER PASSWORD]

ROOT is a local folder shown as "/". In "/drop" (and below it) the server refuses, with
SSH_FX_PERMISSION_DENIED: stat, lstat, fstat, opendir, rename, posix-rename, remove, setstat,
and an open that would truncate or append to an existing file. Everything else is a plain
file system. A file of "/drop" is created only with CREAT (EXCL honoured).
"/cut": while ROOT/cut/.armed exists, the close of a file written under "/cut" removes .armed,
closes the file and then drops the connection without an answer (the client's request is lost
with its transport) - the model of a connection lost at the end of an upload.
"""
import os
import socket
import sys
import threading
import time

import paramiko
from paramiko import SFTPAttributes, SFTPHandle, SFTPServer, SFTPServerInterface
from paramiko.sftp import SFTP_OK, SFTP_PERMISSION_DENIED, SFTP_NO_SUCH_FILE, SFTP_FAILURE

PORT = int(sys.argv[1])
ROOT = os.path.abspath(sys.argv[2])
LOG = sys.argv[3]
USER = sys.argv[4] if len(sys.argv) > 4 else 'tctest'
PASSWORD = sys.argv[5] if len(sys.argv) > 5 else 'tandem123'
_lock = threading.Lock()


def log(text):
    with _lock:
        with open(LOG, 'a', encoding='utf-8') as f:
            f.write('%.3f %s\n' % (time.time(), text))


def in_drop(path):
    p = '/' + path.strip('/')
    return p == '/drop' or p.startswith('/drop/')


def local(path):
    p = os.path.normpath(os.path.join(ROOT, path.lstrip('/')))
    if not (p == ROOT or p.startswith(ROOT + os.sep)):
        raise PermissionError(path)
    return p


def err(e):
    if isinstance(e, FileNotFoundError):
        return SFTP_NO_SUCH_FILE
    if isinstance(e, PermissionError):
        return SFTP_PERMISSION_DENIED
    return SFTPServer.convert_errno(getattr(e, 'errno', 0) or 0) if getattr(e, 'errno', None) else SFTP_FAILURE


class Handle(SFTPHandle):
    def stat(self):
        if self.drop:
            log('fstat %s DENIED' % self.path)
            return SFTP_PERMISSION_DENIED
        try:
            return SFTPAttributes.from_stat(os.fstat(self.writefile.fileno() if self.writefile else self.readfile.fileno()))
        except OSError as e:
            return err(e)

    def chattr(self, attr):
        if self.drop:
            log('fsetstat %s DENIED' % self.path)
            return SFTP_PERMISSION_DENIED
        return SFTP_OK

    def close(self):
        log('close %s' % self.path)
        armed = os.path.join(ROOT, 'cut', '.armed')
        if self.path.startswith('/cut/') and self.writefile is not None and os.path.exists(armed):
            os.remove(armed)
            super().close()
            log('cut: the connection is dropped at the close of %s' % self.path)
            self.transport.close()
            return SFTP_OK
        return super().close()


class Iface(SFTPServerInterface):
    def __init__(self, server, *args, **kwargs):
        super().__init__(server, *args, **kwargs)
        self.transport = server.transport

    def canonicalize(self, path):
        p = '/' + '/'.join(x for x in path.replace('\\', '/').split('/') if x and x != '.')
        parts = []
        for x in p.split('/'):
            if x == '..':
                if parts:
                    parts.pop()
            elif x:
                parts.append(x)
        r = '/' + '/'.join(parts)
        log('realpath %s -> %s' % (path, r))
        return r

    def _stat(self, path, kind):
        if in_drop(path) and path.rstrip('/') != '/drop':
            log('%s %s DENIED' % (kind, path))
            return SFTP_PERMISSION_DENIED
        try:
            st = os.stat(local(path)) if kind == 'stat' else os.lstat(local(path))
            log('%s %s ok' % (kind, path))
            return SFTPAttributes.from_stat(st)
        except OSError as e:
            log('%s %s %r' % (kind, path, e))
            return err(e)

    def stat(self, path):
        return self._stat(path, 'stat')

    def lstat(self, path):
        return self._stat(path, 'lstat')

    def list_folder(self, path):
        if in_drop(path):
            log('opendir %s DENIED' % path)
            return SFTP_PERMISSION_DENIED
        try:
            lp = local(path)
            out = []
            for n in os.listdir(lp):
                a = SFTPAttributes.from_stat(os.lstat(os.path.join(lp, n)))
                a.filename = n
                out.append(a)
            log('opendir %s ok (%d)' % (path, len(out)))
            return out
        except OSError as e:
            return err(e)

    def open(self, path, flags, attr):
        drop = in_drop(path)
        lp = local(path)
        exists = os.path.exists(lp)
        log('open %s flags=0x%x exists=%s' % (path, flags, exists))
        if drop and exists and (flags & (os.O_TRUNC | os.O_APPEND) or not flags & os.O_CREAT or not flags & (os.O_WRONLY | os.O_RDWR)):
            log('open %s DENIED (existing file in drop)' % path)
            return SFTP_PERMISSION_DENIED
        if drop and not flags & (os.O_WRONLY | os.O_RDWR):
            log('open %s DENIED (read in drop)' % path)
            return SFTP_PERMISSION_DENIED
        try:
            fd = os.open(lp, flags | getattr(os, 'O_BINARY', 0), 0o644)
        except OSError as e:
            log('open %s %r' % (path, e))
            return err(e)
        mode = 'r+b' if flags & os.O_RDWR else ('wb' if flags & os.O_WRONLY else 'rb')
        if flags & os.O_WRONLY and flags & os.O_APPEND:
            mode = 'ab'
        f = os.fdopen(fd, mode)
        h = Handle(flags)
        h.transport = self.transport
        h.path = path
        h.drop = drop
        h.filename = lp
        h.readfile = f if 'r' in mode else None
        h.writefile = f if ('w' in mode or 'a' in mode or '+' in mode) else None
        return h

    def remove(self, path):
        if in_drop(path):
            log('remove %s DENIED' % path)
            return SFTP_PERMISSION_DENIED
        try:
            os.remove(local(path))
            log('remove %s ok' % path)
            return SFTP_OK
        except OSError as e:
            return err(e)

    def rename(self, old, new):
        if in_drop(old) or in_drop(new):
            log('rename %s %s DENIED' % (old, new))
            return SFTP_PERMISSION_DENIED
        if os.path.exists(local(new)):
            log('rename %s %s exists' % (old, new))
            return SFTP_FAILURE
        try:
            os.rename(local(old), local(new))
            log('rename %s %s ok' % (old, new))
            return SFTP_OK
        except OSError as e:
            return err(e)

    def posix_rename(self, old, new):
        if in_drop(old) or in_drop(new):
            log('posix-rename %s %s DENIED' % (old, new))
            return SFTP_PERMISSION_DENIED
        try:
            os.replace(local(old), local(new))
            log('posix-rename %s %s ok' % (old, new))
            return SFTP_OK
        except OSError as e:
            return err(e)

    def mkdir(self, path, attr):
        try:
            os.mkdir(local(path))
            log('mkdir %s ok' % path)
            return SFTP_OK
        except OSError as e:
            log('mkdir %s %r' % (path, e))
            return err(e)

    def rmdir(self, path):
        if in_drop(path):
            return SFTP_PERMISSION_DENIED
        try:
            os.rmdir(local(path))
            return SFTP_OK
        except OSError as e:
            return err(e)

    def chattr(self, path, attr):
        if in_drop(path):
            log('setstat %s DENIED' % path)
            return SFTP_PERMISSION_DENIED
        return SFTP_OK


class Server(paramiko.ServerInterface):
    def check_auth_password(self, username, password):
        return paramiko.AUTH_SUCCESSFUL if (username, password) == (USER, PASSWORD) else paramiko.AUTH_FAILED

    def get_allowed_auths(self, username):
        return 'password'

    def check_channel_request(self, kind, chanid):
        return paramiko.OPEN_SUCCEEDED if kind == 'session' else paramiko.OPEN_FAILED_ADMINISTRATIVELY_PROHIBITED


HOSTKEY = paramiko.ECDSAKey.generate(bits=256)


def serve(conn):
    try:
        t = paramiko.Transport(conn)
        t.add_server_key(HOSTKEY)
        t.set_subsystem_handler('sftp', paramiko.SFTPServer, Iface)
        srv = Server()
        srv.transport = t
        t.start_server(server=srv)
        while t.is_active():
            time.sleep(0.5)
    except Exception as e:
        log('session error %r' % e)
    log('disconnected')


if __name__ == '__main__':
    for d in ('drop', 'cut', 'pub'):
        os.makedirs(os.path.join(ROOT, d), exist_ok=True)
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(('127.0.0.1', PORT))
    s.listen(8)
    log('start %d %s' % (PORT, ROOT))
    while True:
        c, _ = s.accept()
        log('connect')
        threading.Thread(target=serve, args=(c,), daemon=True).start()
