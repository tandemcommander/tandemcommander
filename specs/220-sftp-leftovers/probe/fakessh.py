"""A fake SSH server for the GUI probes of features 217 and 220: every connection fails the SSH handshake
in the way MODE says. 127.0.0.1 only; every connection logged (one line per event).

    python -I fakessh.py PORT MODE LOG

MODE: close   - accept and close at once (no banner)
      banner  - send an SSH-2.0 banner, read the client's banner, close (the key exchange fails)
      garbage - send the banner, then bytes that are no SSH packet, close
      kexdrop - send the banner and read the client's KEXINIT, then close (the server ends the
                exchange - as the real server's "disconnect before authentication")
      silent  - accept, never send anything (the client's timeout), close after 60 s
      flipsig - a proxy to the real test server that flips the last byte of the server's
                SSH_MSG_KEX_ECDH_REPLY (its signature): the client's key exchange fails AFTER it
                has made the server's host key object, before NEWKEYS (the window of the leak)
      stallT  - a proxy to the real test server that stops passing the server's bytes T seconds
                after the connection was made (the connection stays open): a request after that
                waits out the client's timeout (feature 220)
      cutN    - a proxy to the real test server (127.0.0.1:2222): the connection is cut once the
                server has sent N bytes (N=1200: during the key exchange; larger: later steps)
"""
import socket
import socketserver
import sys
import threading
import time

PORT = int(sys.argv[1])
MODE = sys.argv[2]
LOG = sys.argv[3]
_lock = threading.Lock()


def log(text):
    with _lock:
        with open(LOG, 'a', encoding='ascii') as f:
            f.write('%.3f %s\n' % (time.time(), text))


class Handler(socketserver.BaseRequestHandler):
    def handle(self):
        s = self.request
        s.settimeout(30)
        log('connect ' + MODE)
        if MODE.startswith('cut'):
            self.proxy(s, int(MODE[3:]))
            return
        if MODE.startswith('stall'):
            self.proxy(s, 1 << 40, stall_after=float(MODE[5:]))
            return
        if MODE == 'flipsig':
            self.proxy(s, 1 << 40, flip=True)
            return
        try:
            if MODE == 'close':
                return
            if MODE == 'silent':
                time.sleep(60)
                return
            s.sendall(b'SSH-2.0-FakeSSH_217\r\n')
            got = s.recv(256)
            log('client banner %r' % got[:64])
            if MODE == 'garbage':
                s.sendall(b'\x00\x00\x00\x0cTHIS-IS-NOT-SSH\r\n' * 4)
            elif MODE == 'kexdrop':
                more = s.recv(4096)
                log('client sent %d bytes' % len(more))
        except Exception as e:
            log('error ' + repr(e))
        finally:
            try:
                s.close()
            except Exception:
                pass
            log('closed')


    def proxy(self, c, limit, flip=False, stall_after=None):
        up = socket.create_connection(('127.0.0.1', 2222), timeout=300)
        c.settimeout(300)
        sent = [0]
        done = threading.Event()
        t0 = time.time()

        def pump(src, dst, count):
            try:
                while not done.is_set():
                    b = src.recv(4096)
                    if not b:
                        break
                    if count and stall_after is not None and time.time() - t0 > stall_after:
                        if sent[0] >= 0:
                            log('stalled after %.1f s (%d server bytes passed)' % (stall_after, sent[0]))
                            sent[0] = -1 - sent[0]
                        continue  # the server's bytes are dropped; the connection stays
                    if count:
                        room = limit - sent[0]
                        if len(b) >= room:
                            dst.sendall(b[:room])
                            sent[0] = limit
                            log('cut after %d server bytes' % limit)
                            break
                        sent[0] += len(b)
                    dst.sendall(b)
            except Exception as e:
                log('pump ' + repr(e))
            finally:
                done.set()

        def pump_flip(src, dst):
            # the server's stream: the banner line, then plaintext binary packets until NEWKEYS
            buf = b''
            state = 'banner'
            try:
                while not done.is_set():
                    b = src.recv(4096)
                    if not b:
                        break
                    if state == 'raw':
                        dst.sendall(b)
                        continue
                    buf += b
                    out = b''
                    while True:
                        if state == 'banner':
                            i = buf.find(b'\n')
                            if i < 0:
                                break
                            out += buf[:i + 1]
                            if buf.startswith(b'SSH-'):
                                state = 'packets'
                            buf = buf[i + 1:]
                            continue
                        if len(buf) < 4:
                            break
                        n = int.from_bytes(buf[:4], 'big')
                        if len(buf) < 4 + n:
                            break
                        pkt = bytearray(buf[:4 + n])
                        buf = buf[4 + n:]
                        pad = pkt[4]
                        msg = pkt[5]
                        if msg == 31:  # SSH_MSG_KEX_ECDH_REPLY: its last field is the signature
                            pkt[4 + n - pad - 1] ^= 0x01
                            log('flipped a byte of the KEX_ECDH_REPLY signature')
                        out += bytes(pkt)
                        if msg == 21:  # NEWKEYS: encrypted from here on
                            state = 'raw'
                            out += buf
                            buf = b''
                            break
                    if out:
                        dst.sendall(out)
            except Exception as e:
                log('pump_flip ' + repr(e))
            finally:
                done.set()

        t = threading.Thread(target=pump, args=(c, up, False), daemon=True)
        t.start()
        if flip:
            pump_flip(up, c)
        else:
            pump(up, c, True)
        for x in (c, up):
            try:
                x.close()
            except Exception:
                pass
        log('closed (server sent %d)' % sent[0])


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == '__main__':
    log('start ' + MODE)
    with Server(('127.0.0.1', PORT), Handler) as srv:
        srv.serve_forever()
