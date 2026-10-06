# Review 2 raw socket server (feature 123): behaviours updserver.py does not have.
#   python rawsrv.py <port>
# Paths:
#   /hdrdrip      status line and headers one byte per 400 ms (never complete within the deadline)
#   /bodydrip     complete headers with Content-Length, then one body byte per 400 ms
#   /nocl         valid record, no Content-Length, Connection: close, complete
#   /nocl-cut     the same, cut in the middle, then close
#   /chunkcut     chunked, connection closed in the middle of a chunk
#   /chunkcut2    chunked, closed after a complete chunk but before the terminating 0 chunk
#   /clhuge       Content-Length: 5000000000, the valid record, then close
#   /clshort      Content-Length smaller than the record that is sent (rest follows on the wire)
#   /clzero       Content-Length: 0 and then the valid record anyway
#   /noread       accept and never read or answer
#   /100          "100 Continue" interim answer first, then the valid record
import os
import socket
import sys
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
import updserver  # noqa: E402


def record():
    status, ctype, body, mode = updserver.build('newer') if hasattr(updserver, 'build') else (None, None, None, None)
    return body


def find_builder():
    for name in ('body_for', 'fixture', 'build', 'make_fixture', 'get_fixture', 'response_for'):
        if hasattr(updserver, name):
            return getattr(updserver, name)
    raise SystemExit('no fixture builder found in updserver.py: ' + ', '.join(n for n in dir(updserver) if not n.startswith('_')))


def body_newer():
    r = find_builder()('newer')
    for part in r:
        if isinstance(part, (bytes, bytearray)) and len(part) > 1000:
            return bytes(part)
    raise SystemExit('unexpected fixture shape: %r' % (r,))


BODY = None


def handle(conn):
    try:
        conn.settimeout(30)
        data = b''
        while b'\r\n\r\n' not in data:
            chunk = conn.recv(4096)
            if not chunk:
                return
            data += chunk
        path = data.split(b' ')[1].decode('ascii', 'replace')
        t0 = time.time()
        print('%s request %s' % (time.strftime('%H:%M:%S'), path), flush=True)
        hdr = b'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n'
        if path.startswith('http://') or data.startswith(b'CONNECT'):
            # used as a PROXY: challenge for sign-in and record whether credentials come back
            low = data.lower()
            print('   PROXY request, Proxy-Authorization present: %s' % (b'proxy-authorization:' in low), flush=True)
            print('   ' + data.decode('latin-1').replace('\r\n', ' | ')[:400], flush=True)
            conn.sendall(b'HTTP/1.1 407 Proxy Authentication Required\r\nProxy-Authenticate: Negotiate\r\n'
                         b'Proxy-Authenticate: NTLM\r\nProxy-Authenticate: Basic realm="r2"\r\nContent-Length: 0\r\n'
                         b'Proxy-Connection: keep-alive\r\nConnection: keep-alive\r\n\r\n')
            conn.settimeout(3)  # NTLM is per connection: a client that signs in sends a second request here
            try:
                more = conn.recv(8192)
                if more:
                    print('   SECOND request on the proxy connection, Proxy-Authorization present: %s'
                          % (b'proxy-authorization:' in more.lower()), flush=True)
                    print('   ' + more.decode('latin-1').replace('\r\n', ' | ')[:400], flush=True)
                else:
                    print('   the client closed the proxy connection, no second request', flush=True)
            except Exception:
                print('   no second request on the proxy connection', flush=True)
            return
        if path == '/noread':
            time.sleep(40)
        elif path == '/hdrdrip':
            full = hdr + b'Content-Length: %d\r\n\r\n' % len(BODY) + BODY
            for i in range(len(full)):
                conn.sendall(full[i:i + 1])
                time.sleep(0.4)
        elif path == '/bodydrip':
            conn.sendall(hdr + b'Content-Length: %d\r\n\r\n' % len(BODY))
            for i in range(len(BODY)):
                conn.sendall(BODY[i:i + 1])
                time.sleep(0.4)
        elif path == '/nocl':
            conn.sendall(hdr + b'Connection: close\r\n\r\n' + BODY)
        elif path == '/nocl-cut':
            conn.sendall(hdr + b'Connection: close\r\n\r\n' + BODY[:len(BODY) // 2])
        elif path == '/chunkcut':
            conn.sendall(hdr + b'Transfer-Encoding: chunked\r\n\r\n' + b'%x\r\n' % len(BODY) + BODY[:len(BODY) // 2])
        elif path == '/chunkcut2':
            conn.sendall(hdr + b'Transfer-Encoding: chunked\r\n\r\n' + b'%x\r\n' % len(BODY) + BODY + b'\r\n')
        elif path == '/clhuge':
            conn.sendall(hdr + b'Content-Length: 5000000000\r\n\r\n' + BODY)
        elif path == '/clshort':
            conn.sendall(hdr + b'Content-Length: %d\r\n\r\n' % (len(BODY) - 100) + BODY)
        elif path == '/clzero':
            conn.sendall(hdr + b'Content-Length: 0\r\n\r\n' + BODY)
        elif path == '/100':
            conn.sendall(b'HTTP/1.1 100 Continue\r\n\r\n')
            time.sleep(0.2)
            conn.sendall(hdr + b'Content-Length: %d\r\n\r\n' % len(BODY) + BODY)
            time.sleep(0.5)
        else:
            conn.sendall(b'HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n')
        print('%s done    %s after %.1f s' % (time.strftime('%H:%M:%S'), path, time.time() - t0), flush=True)
    except Exception as e:  # the client left
        print('%s ended   %s' % (time.strftime('%H:%M:%S'), e), flush=True)
    finally:
        try:
            conn.close()
        except Exception:
            pass


def main():
    global BODY
    BODY = body_newer()
    port = int(sys.argv[1])
    s = socket.socket()
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(('127.0.0.1', port))
    s.listen(16)
    print('rawsrv on %d, record %d bytes' % (port, len(BODY)), flush=True)
    while True:
        conn, _ = s.accept()
        threading.Thread(target=handle, args=(conn,), daemon=True).start()


if __name__ == '__main__':
    main()
