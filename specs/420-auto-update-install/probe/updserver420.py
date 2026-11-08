#!/usr/bin/env python3
"""Fixture server for the feature 420 probe (automatic update).

Standard library only, plain HTTP on 127.0.0.1 (the Debug seam TC_UPDATECHECK_URL of the
program accepts nothing else). Serves "latest release" records of version 0.2.0 whose
installer asset points at one of the download variants below, the API asset address the
program downloads from, a redirect to the file, and the file. Every request is logged as one
JSON line (method, path, headers).

    python updserver420.py --port 8420 --log requests.log --good <signed 0.2.0 installer>
                           --older <signed 0.1.9 installer> --foreign <exe signed by another
                           publisher> --unsigned <unsigned exe>

    GET /latest/rel-<variant>      the record; its asset id selects the variant
    GET /repos/tandemcommander/tandemcommander/releases/assets/<id>   302 -> /dl/<id>
    GET /dl/<id>                   the file of the variant
    GET /stop                      ends the server

Variants (asset id: what the program gets):
    1  good       the signed 0.2.0 installer, digest and size of it                -> verified
    2  tampered   the good file with one byte changed, digest of the good file     -> refused (hash)
    3  foreign    an exe validly signed by another publisher, its own digest       -> refused (signer)
    4  unsigned   an unsigned exe, its own digest                                  -> refused (unsigned)
    5  older      the signed 0.1.9 installer, its own digest (record says 0.2.0)   -> refused (version)
    6  truncated  Content-Length of the whole file, half of it sent, then closed   -> refused
    7  extra      record size one byte smaller than the file (all bytes sent)     -> refused (size)
    8  foreignrd  302 to https://evil.example/x                                    -> refused (redirect)
    9  portrd     302 to http://127.0.0.1:1/x (another port)                      -> refused (redirect)
    10 slow       the good file at 20 KB per second                                -> (exit-time row)
    11 loop       302 to itself (more redirects than allowed)                      -> refused
Records without download data:
    rel-nodigest  the good asset without "digest"                                  -> notify only
    rel-huge      the good asset with "size" 70 MB                                 -> notify only
"""
import argparse
import copy
import hashlib
import json
import os
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
REAL = os.path.join(HERE, '..', '..', '123-new-version-check', 'probe', 'fixtures', 'real-0.1.8.json')
ASSET_PREFIX = '/repos/tandemcommander/tandemcommander/releases/assets/'

LOG_LOCK = threading.Lock()
LOG_FILE = None
STOP = threading.Event()
FILES = {}
PORT = 0


def log(entry):
    with LOG_LOCK:
        if LOG_FILE:
            with open(LOG_FILE, 'a', encoding='utf-8') as f:
                f.write(json.dumps(entry) + '\n')


def data_of(variant):
    good = FILES['good']
    if variant == 2:
        b = bytearray(good)
        b[len(b) // 2] ^= 0x01
        return bytes(b)
    if variant == 3:
        return FILES['foreign']
    if variant == 4:
        return FILES['unsigned']
    if variant == 5:
        return FILES['older']
    return good


def digest_and_size(variant):
    """What the record announces for a variant."""
    good = FILES['good']
    if variant in (2, 6, 10):
        return hashlib.sha256(good).hexdigest(), len(good)
    if variant == 7:
        return hashlib.sha256(good).hexdigest(), len(good) - 1
    d = data_of(variant)
    return hashlib.sha256(d).hexdigest(), len(d)


def record(name):
    with open(REAL, encoding='utf-8') as f:
        rec = json.load(f)
    text = json.dumps(rec).replace(rec['tag_name'][1:], '0.2.0')
    rec = json.loads(text)
    rec['published_at'] = '2026-10-25T17:35:47Z'
    variant = name[4:]
    ids = {'good': 1, 'tampered': 2, 'foreign': 3, 'unsigned': 4, 'older': 5, 'truncated': 6, 'extra': 7,
           'foreignrd': 8, 'portrd': 9, 'slow': 10, 'loop': 11, 'nodigest': 1, 'huge': 1}
    vid = ids.get(variant)
    if vid is None:
        return None
    a = rec['assets'][0]
    dg, size = digest_and_size(vid)
    a['id'] = vid
    a['url'] = 'https://api.github.com' + ASSET_PREFIX + str(vid)
    a['size'] = size
    a['digest'] = 'sha256:' + dg
    if variant == 'nodigest':
        del a['digest']
    if variant == 'huge':
        a['size'] = 70 * 1024 * 1024
    return rec


class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, fmt, *args):
        pass

    def send_plain(self, status, body=b'', headers=None):
        self.send_response(status)
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        if body:
            self.wfile.write(body)

    def do_GET(self):
        log({'method': 'GET', 'path': self.path, 'headers': [[k, v] for k, v in self.headers.items()],
             'time': time.time()})
        p = self.path
        if p == '/stop':
            self.send_plain(200, b'bye')
            STOP.set()
            return
        if p.startswith('/latest/'):
            rec = record(p[len('/latest/'):])
            if rec is None:
                self.send_plain(404, b'{}')
                return
            body = json.dumps(rec, indent=2).encode('utf-8')
            self.send_plain(200, body, {'Content-Type': 'application/json; charset=utf-8'})
            return
        if p.startswith(ASSET_PREFIX):
            try:
                vid = int(p[len(ASSET_PREFIX):])
            except ValueError:
                self.send_plain(404)
                return
            if vid == 8:
                loc = 'https://evil.example/x'
            elif vid == 9:
                loc = 'http://127.0.0.1:1/x'
            elif vid == 11:
                loc = 'http://127.0.0.1:%d%s%d' % (PORT, ASSET_PREFIX, vid)
            else:
                loc = 'http://127.0.0.1:%d/dl/%d' % (PORT, vid)
            self.send_plain(302, b'', {'Location': loc})
            return
        if p.startswith('/dl/'):
            try:
                vid = int(p[4:])
            except ValueError:
                self.send_plain(404)
                return
            d = data_of(vid)
            if vid == 6:
                self.send_response(200)
                self.send_header('Content-Type', 'application/octet-stream')
                self.send_header('Content-Length', str(len(d)))
                self.end_headers()
                self.wfile.write(d[:len(d) // 2])
                self.wfile.flush()
                self.close_connection = True
                return
            self.send_response(200)
            self.send_header('Content-Type', 'application/octet-stream')
            self.send_header('Content-Length', str(len(d)))
            self.end_headers()
            if vid == 10:
                try:
                    for i in range(0, len(d), 2048):
                        if STOP.is_set():
                            break
                        self.wfile.write(d[i:i + 2048])
                        self.wfile.flush()
                        time.sleep(0.1)
                except (ConnectionError, OSError):
                    log({'method': 'END', 'path': p, 'note': 'client left'})
                return
            self.wfile.write(d)
            return
        self.send_plain(404)


def main():
    global LOG_FILE, PORT
    ap = argparse.ArgumentParser()
    ap.add_argument('--port', type=int, required=True)
    ap.add_argument('--log', required=True)
    ap.add_argument('--good', required=True)
    ap.add_argument('--older', required=True)
    ap.add_argument('--foreign', required=True)
    ap.add_argument('--unsigned', required=True)
    a = ap.parse_args()
    LOG_FILE = a.log
    PORT = a.port
    for k in ('good', 'older', 'foreign', 'unsigned'):
        with open(getattr(a, k), 'rb') as f:
            FILES[k] = f.read()
    srv = ThreadingHTTPServer(('127.0.0.1', a.port), Handler)
    srv.daemon_threads = True
    t = threading.Thread(target=srv.serve_forever, daemon=True)
    t.start()
    STOP.wait()
    srv.shutdown()
    return 0


if __name__ == '__main__':
    sys.exit(main())
