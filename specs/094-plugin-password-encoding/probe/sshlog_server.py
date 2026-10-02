# Feature 094 research probe: a local SSH server that only LOGS the bytes of
# every password it is offered and refuses the login. Nothing but 127.0.0.1.
#
#   python sshlog_server.py <port> <log file> <stop file> [seconds]
#
# One line per attempt: "password user=<hex> bytes=<hex>" (the bytes exactly
# as they came in the SSH_MSG_USERAUTH_REQUEST; paramiko hands over str when
# they are valid UTF-8, bytes otherwise - both are written as hex of the wire
# bytes). Ends when <stop file> exists or after [seconds] (default 600).
# Needs paramiko (installed into a scratch venv for the run). Pure ASCII.
import os
import socket
import sys
import threading
import time

import paramiko

port, log_path, stop_path = int(sys.argv[1]), sys.argv[2], sys.argv[3]
limit = float(sys.argv[4]) if len(sys.argv) > 4 else 600.0
host_key = paramiko.RSAKey.generate(2048)
lock = threading.Lock()


def log(line):
    with lock:
        with open(log_path, 'a', encoding='ascii') as f:
            f.write(line + '\n')


def wire(v):
    return (v.encode('utf-8') if isinstance(v, str) else bytes(v)).hex(' ')


class Srv(paramiko.ServerInterface):
    def get_allowed_auths(self, username):
        return 'password'

    def check_auth_none(self, username):
        return paramiko.AUTH_FAILED

    def check_auth_password(self, username, password):
        kind = 'utf8-valid' if isinstance(password, str) else 'NOT-utf8'
        n = len(password.encode('utf-8')) if isinstance(password, str) else len(password)
        log('password user=%s len=%d %s bytes=%s' % (wire(username), n, kind, wire(password)))
        return paramiko.AUTH_FAILED


def serve(conn):
    t = paramiko.Transport(conn)
    try:
        t.add_server_key(host_key)
        t.start_server(server=Srv())
        end = time.time() + 20
        while t.is_active() and time.time() < end and not os.path.exists(stop_path):
            time.sleep(0.1)
    except Exception as e:
        log('transport error: %s' % type(e).__name__)
    finally:
        t.close()


s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('127.0.0.1', port))
s.listen(5)
s.settimeout(0.3)
log('listening 127.0.0.1:%d paramiko %s' % (port, paramiko.__version__))
t0 = time.time()
while not os.path.exists(stop_path) and time.time() - t0 < limit:
    try:
        c, addr = s.accept()
    except socket.timeout:
        continue
    log('connection')
    threading.Thread(target=serve, args=(c,), daemon=True).start()
s.close()
log('stopped')
