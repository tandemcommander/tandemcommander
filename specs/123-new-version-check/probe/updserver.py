#!/usr/bin/env python3
"""Fixture server for the feature 123 probes (checking for a new version).

Standard library only. Serves "latest release" answers derived from the real
record (fixtures/real-0.1.8.json) and logs every request with all its headers,
so that a probe can prove what the program sends.

    python updserver.py --port 8123 --log requests.log

    GET /latest/<fixture>        one of the fixtures below
    GET /stop                    ends the server (used by probes)

Fixtures (each is the real record with one thing changed, unless noted):

    newer              version 9.9.9, published now-ish        -> "newer"
    newer-0.1.9        version 0.1.9                            -> "newer" for 0.1.8
    same               the real record (0.1.8)                  -> "up to date" for 0.1.8
    older              version 0.0.1                            -> "up to date"
    prerelease         "prerelease": true                       -> unexpected
    draft              "draft": true                            -> unexpected
    noasset            "assets": []                             -> unexpected
    asset-not-uploaded asset "state": "open"                    -> unexpected
    foreign-url        asset address on another host            -> unexpected
    foreign-html-url   "html_url" on another host               -> unexpected
    bad-tag            "tag_name": "latest"                     -> unexpected
    dup-tag            a second "tag_name" member               -> unexpected
    oversized          a valid record padded over 256 KB        -> unexpected
    truncated          the record cut in the middle (Content-Length = cut size)
    short-body         Content-Length larger than what is sent, then close
    html               an HTML page with status 200 (captive portal)
    empty              status 200, empty body
    403, 429, 500, 404 that status with a JSON error body
    redirect           302 to /latest/newer (must NOT be followed)
    auth401            401 with WWW-Authenticate: Negotiate and NTLM (no credentials may follow)
    hang               accepts the request and never answers (until the client leaves)
    slow               sends the valid "newer" record one byte per 50 ms (never done in time)
    slow-ok            sends the valid "newer" record in 4 pieces over ~2 s (must succeed)

Added by the independent tester (updcheck_probe.ps1):

    ver-<x.y.z>        the real record re-pointed consistently at version x.y.z (tag, addresses, asset)
    bad-date           "published_at": "2026-02-30T08:00:00Z" (not a real date)   -> unexpected
    wrong-asset-name   the only asset is tandemcommander-9.9.9-arm64-setup.exe    -> unexpected
    two-assets         a foreign asset first, the right installer second          -> "newer"
    nested-tag-first   an object member holding its own "tag_name" precedes the top-level one -> "newer"
    deep-nesting       a member nested 40 levels deep precedes the rest           -> unexpected
    chunked            the valid "newer" record with Transfer-Encoding: chunked   -> "newer"
    bom                the valid record preceded by a UTF-8 byte order mark       -> (reported, either way)
    array              the valid record wrapped in a JSON array                   -> unexpected
    setcookie          the real record (0.1.8) with a Set-Cookie header (a later request must carry no Cookie)
    dyn                whatever fixture was chosen last with GET /control/set/<fixture> (default: same)

    GET /control/set/<fixture>   chooses the fixture served by /latest/dyn (not a version request)

The server answers plain HTTP on 127.0.0.1 only - the Debug-only seam of the
program (TC_UPDATECHECK_URL) accepts nothing else.
"""
import argparse
import copy
import json
import os
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
REAL = os.path.join(HERE, 'fixtures', 'real-0.1.8.json')

LOG_LOCK = threading.Lock()
LOG_FILE = None
STOP = threading.Event()
DYN = {'name': 'same'}


def real_record():
    with open(REAL, encoding='utf-8') as f:
        return json.load(f)


def with_version(rec, ver, published=None):
    """The record re-pointed at another version: tag, addresses, asset name."""
    r = copy.deepcopy(rec)
    old = r['tag_name'][1:]
    text = json.dumps(r)
    text = text.replace(old, ver)
    r = json.loads(text)
    if published:
        r['published_at'] = published
    return r


def body_for(name):
    """Returns (status, headers, body-bytes, mode) for a fixture; mode is None or a special behaviour."""
    rec = real_record()
    newer = with_version(rec, '9.9.9', '2026-10-14T08:00:00Z')
    js = {'Content-Type': 'application/json; charset=utf-8'}

    def dumps(o):
        return json.dumps(o, indent=2, ensure_ascii=False).encode('utf-8')

    if name == 'dyn':
        name = DYN['name']
    if name.startswith('ver-'):
        return 200, js, dumps(with_version(rec, name[4:], '2026-10-14T08:00:00Z')), None
    if name == 'zero-tag':
        # round 2: a tag with leading zeros while every address is the canonical 0.1.9 one -> unexpected
        r = with_version(rec, '0.1.9', '2026-10-14T08:00:00Z')
        r['tag_name'] = 'v00.01.009'
        return 200, js, dumps(r), None
    if name == 'bad-date':
        newer['published_at'] = '2026-02-30T08:00:00Z'
        return 200, js, dumps(newer), None
    if name == 'wrong-asset-name':
        a = newer['assets'][0]
        a['name'] = a['name'].replace('x64', 'arm64')
        a['browser_download_url'] = a['browser_download_url'].replace('x64', 'arm64')
        return 200, js, dumps(newer), None
    if name == 'two-assets':
        other = copy.deepcopy(newer['assets'][0])
        other['name'] = 'tandemcommander-9.9.9-source.zip'
        other['browser_download_url'] = 'https://evil.example/tandemcommander-9.9.9-source.zip'
        newer['assets'] = [other, newer['assets'][0]]
        return 200, js, dumps(newer), None
    if name == 'nested-tag-first':
        text = dumps(newer).decode('utf-8')
        text = text.replace('{', '{\n  "author_note": {"tag_name": "v1.2.3", "draft": true, "prerelease": true},', 1)
        return 200, js, text.encode('utf-8'), None
    if name == 'deep-nesting':
        text = dumps(newer).decode('utf-8')
        text = text.replace('{', '{\n  "deep": ' + '[' * 40 + ']' * 40 + ',', 1)
        return 200, js, text.encode('utf-8'), None
    if name == 'chunked':
        return 200, js, dumps(newer), 'chunked'
    if name == 'bom':
        return 200, js, b'\xef\xbb\xbf' + dumps(newer), None
    if name == 'array':
        return 200, js, b'[' + dumps(newer) + b']', None
    if name == 'setcookie':
        h = dict(js)
        h['Set-Cookie'] = 'tc123probe=1; Path=/'
        return 200, h, dumps(rec), None
    if name == 'newer':
        return 200, js, dumps(newer), None
    if name == 'newer-0.1.9':
        return 200, js, dumps(with_version(rec, '0.1.9', '2026-10-14T08:00:00Z')), None
    if name == 'same':
        return 200, js, dumps(rec), None
    if name == 'older':
        return 200, js, dumps(with_version(rec, '0.0.1')), None
    if name == 'prerelease':
        newer['prerelease'] = True
        return 200, js, dumps(newer), None
    if name == 'draft':
        newer['draft'] = True
        return 200, js, dumps(newer), None
    if name == 'noasset':
        newer['assets'] = []
        return 200, js, dumps(newer), None
    if name == 'asset-not-uploaded':
        newer['assets'][0]['state'] = 'open'
        return 200, js, dumps(newer), None
    if name == 'foreign-url':
        newer['assets'][0]['browser_download_url'] = 'https://evil.example/tandemcommander-9.9.9-x64-setup.exe'
        return 200, js, dumps(newer), None
    if name == 'foreign-html-url':
        newer['html_url'] = 'https://evil.example/tandemcommander/tandemcommander/releases/tag/v9.9.9'
        return 200, js, dumps(newer), None
    if name == 'bad-tag':
        newer['tag_name'] = 'latest'
        return 200, js, dumps(newer), None
    if name == 'dup-tag':
        text = dumps(newer).decode('utf-8')
        text = text.replace('{', '{\n  "tag_name": "v9.9.9",', 1)
        return 200, js, text.encode('utf-8'), None
    if name == 'oversized':
        newer['body'] = 'x' * (300 * 1024)
        return 200, js, dumps(newer), None
    if name == 'truncated':
        b = dumps(newer)
        return 200, js, b[:len(b) // 2], None
    if name == 'short-body':
        return 200, js, dumps(newer), 'short'
    if name == 'html':
        return 200, {'Content-Type': 'text/html'}, b'<html><body><h1>Sign in to the hotel network</h1></body></html>', None
    if name == 'empty':
        return 200, js, b'', None
    if name in ('403', '429', '500', '404'):
        return int(name), js, b'{"message":"API rate limit exceeded","documentation_url":"https://docs.github.com/"}', None
    if name == 'redirect':
        return 302, {'Location': '/latest/newer'}, b'', None
    if name == 'auth401':
        return 401, {'WWW-Authenticate': ['Negotiate', 'NTLM']}, b'{"message":"Requires authentication"}', None
    if name == 'hang':
        return 200, js, dumps(newer), 'hang'
    if name == 'slow':
        return 200, js, dumps(newer), 'slow'
    if name == 'slow-ok':
        return 200, js, dumps(newer), 'slow-ok'
    return 404, js, b'{"message":"no such fixture"}', None


class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    server_version = 'updserver/123'

    def log_message(self, fmt, *args):  # quiet console
        pass

    def log_request_full(self):
        with LOG_LOCK:
            line = {
                'time': time.strftime('%Y-%m-%dT%H:%M:%S'),
                'method': self.command,
                'path': self.path,
                'version': self.request_version,
                'headers': [[k, v] for k, v in self.headers.items()],
            }
            if LOG_FILE:
                with open(LOG_FILE, 'a', encoding='utf-8') as f:
                    f.write(json.dumps(line) + '\n')

    def do_GET(self):
        # the tester's addition: one more log line when the exchange is over, with how long the
        # connection lasted (path "/end/<fixture>", so that it is not counted as a request)
        t0 = time.time()
        try:
            self.serve_one()
        finally:
            if self.path.startswith('/latest/') and LOG_FILE:
                with LOG_LOCK:
                    with open(LOG_FILE, 'a', encoding='utf-8') as f:
                        f.write(json.dumps({'time': time.strftime('%Y-%m-%dT%H:%M:%S'), 'method': 'END',
                                            'path': '/end/' + self.path[len('/latest/'):],
                                            'seconds': round(time.time() - t0, 2), 'headers': []}) + chr(10))

    def serve_one(self):
        self.log_request_full()
        if self.path == '/stop':
            self.send_response(200)
            self.send_header('Content-Length', '0')
            self.send_header('Connection', 'close')
            self.end_headers()
            STOP.set()
            return
        if self.path.startswith('/control/set/'):
            DYN['name'] = self.path[len('/control/set/'):]
            self.send_response(200)
            self.send_header('Content-Length', '0')
            self.send_header('Connection', 'close')
            self.end_headers()
            return
        if not self.path.startswith('/latest/'):
            self.send_response(404)
            self.send_header('Content-Length', '0')
            self.end_headers()
            return
        name = self.path[len('/latest/'):].split('?')[0]
        status, headers, body, mode = body_for(name)
        try:
            if mode == 'hang':
                # never answer; leave when the client does or the server stops
                while not STOP.is_set():
                    time.sleep(0.1)
                    try:
                        self.connection.settimeout(0.01)
                        if self.connection.recv(1, 0x2) == b'':  # MSG_PEEK: closed by the client
                            break
                    except (BlockingIOError, TimeoutError, OSError) as e:
                        if isinstance(e, ConnectionError):
                            break
                return
            self.send_response(status)
            for k, v in headers.items():
                for one in (v if isinstance(v, list) else [v]):
                    self.send_header(k, one)
            if mode == 'short':
                self.send_header('Content-Length', str(len(body) + 1000))
                self.send_header('Connection', 'close')
                self.end_headers()
                self.wfile.write(body)
                self.wfile.flush()
                self.close_connection = True
                return
            if mode == 'chunked':
                self.send_header('Transfer-Encoding', 'chunked')
                self.send_header('Connection', 'close')
                self.end_headers()
                step = len(body) // 3 + 1
                for i in range(0, len(body), step):
                    piece = body[i:i + step]
                    self.wfile.write(('%x\r\n' % len(piece)).encode('ascii') + piece + b'\r\n')
                self.wfile.write(b'0\r\n\r\n')
                self.wfile.flush()
                self.close_connection = True
                return
            self.send_header('Content-Length', str(len(body)))
            self.send_header('Connection', 'close')
            self.end_headers()
            if mode == 'slow':
                for i in range(len(body)):
                    if STOP.is_set():
                        break
                    self.wfile.write(body[i:i + 1])
                    self.wfile.flush()
                    time.sleep(0.05)
            elif mode == 'slow-ok':
                step = len(body) // 4 + 1
                for i in range(0, len(body), step):
                    self.wfile.write(body[i:i + step])
                    self.wfile.flush()
                    time.sleep(0.5)
            else:
                self.wfile.write(body)
            self.close_connection = True
        except (ConnectionError, OSError):
            pass  # the client went away (a cancel, a timeout): expected in several rows


def main():
    global LOG_FILE
    ap = argparse.ArgumentParser()
    ap.add_argument('--port', type=int, default=8123)
    ap.add_argument('--log', default=None, help='file that receives one JSON line per request')
    ap.add_argument('--selftest', action='store_true', help='print every fixture\'s status and size and exit')
    args = ap.parse_args()
    if args.selftest:
        for n in ['newer', 'newer-0.1.9', 'same', 'older', 'prerelease', 'draft', 'noasset', 'asset-not-uploaded',
                  'foreign-url', 'foreign-html-url', 'bad-tag', 'dup-tag', 'oversized', 'truncated', 'short-body',
                  'html', 'empty', '403', '429', '500', '404', 'redirect', 'auth401', 'hang', 'slow', 'slow-ok',
                  'ver-0.1.10', 'ver-0.01.9', 'ver-0.1.100000', 'ver-99999.99999.99999', 'bad-date',
                  'wrong-asset-name', 'two-assets', 'nested-tag-first', 'deep-nesting', 'chunked', 'bom',
                  'array', 'setcookie', 'dyn']:
            status, headers, body, mode = body_for(n)
            print('%-20s %3d %7d bytes %s' % (n, status, len(body), mode or ''))
        return 0
    LOG_FILE = args.log
    srv = ThreadingHTTPServer(('127.0.0.1', args.port), Handler)
    srv.daemon_threads = True
    t = threading.Thread(target=srv.serve_forever, daemon=True)
    t.start()
    print('updserver: listening on http://127.0.0.1:%d' % args.port, flush=True)
    try:
        while not STOP.is_set():
            time.sleep(0.2)
    except KeyboardInterrupt:
        pass
    srv.shutdown()
    return 0


if __name__ == '__main__':
    sys.exit(main())
