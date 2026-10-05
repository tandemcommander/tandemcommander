"""Feature 116 probe helper (from feature 104's): a minimal FTP server on 127.0.0.1 that logs
the BYTES of every USER, PASS and ACCT command it receives (hex, one line each, flushed), marks
each new connection with a CONN line, and refuses every login (530) - so the FTP plug-in shows
its login-error dialog after every attempt. Standard library only.
Usage: python ftplog_server.py <port> <logfile>
"""
import socket
import sys
import threading

COUNTER = [0]


def serve(conn, log, lock):
    try:
        with lock:
            COUNTER[0] += 1
            log.write('CONN %d\n' % COUNTER[0])
            log.flush()
        conn.sendall(b'220 tc116 log server\r\n')
        buf = b''
        while True:
            data = conn.recv(4096)
            if not data:
                return
            buf += data
            while b'\r\n' in buf:
                line, buf = buf.split(b'\r\n', 1)
                cmd = line.split(b' ', 1)[0].upper()
                arg = line[len(cmd) + 1:] if b' ' in line else b''
                if cmd in (b'USER', b'PASS', b'ACCT'):
                    with lock:
                        log.write('%s len=%d hex=%s\n' % (cmd.decode(), len(arg), arg.hex()))
                        log.flush()
                    conn.sendall(b'331 password required\r\n' if cmd == b'USER' else b'530 login incorrect\r\n')
                elif cmd == b'QUIT':
                    conn.sendall(b'221 bye\r\n')
                    return
                else:
                    conn.sendall(b'502 not implemented\r\n')
    except OSError:
        pass
    finally:
        conn.close()


def main():
    port = int(sys.argv[1])
    log = open(sys.argv[2], 'a', encoding='ascii')
    lock = threading.Lock()
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(('127.0.0.1', port))
    srv.listen(5)
    while True:
        conn, _ = srv.accept()
        threading.Thread(target=serve, args=(conn, log, lock), daemon=True).start()


if __name__ == '__main__':
    main()
