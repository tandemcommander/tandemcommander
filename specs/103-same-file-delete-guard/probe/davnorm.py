# Feature 103 test tool: a minimal WebDAV server (Python standard library only)
# whose name lookup folds like a macOS server: two names are the same entry when
# their NFC forms are equal without case (e.g. "cafe" + U+0301 and "caf" + U+00E9,
# or "Caf" + U+00E9). Windows (NTFS, CompareStringOrdinal) treats such names as
# different, so a rename onto "another spelling of the same file" is answered
# with 412 Precondition Failed (Overwrite: F), which the Windows WebDAV
# redirector reports as ERROR_ALREADY_EXISTS - the situation of
# specs/103-same-file-delete-guard. A plain case change of the same entry is
# allowed (as real servers do), and a rename onto the identical name is a no-op.
#
# Usage: python davnorm.py <backing folder> [port] [log file]
# UNC path: \\localhost@<port>\dav\...  (and \\127.0.0.1@<port>\dav\... - the
# same files under a second server name). Never use it outside a test.
import http.server, os, sys, shutil, unicodedata, urllib.parse, email.utils, time, datetime, uuid

ROOT = os.path.abspath(sys.argv[1])
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 18103
PREFIX = '/dav'
LOG = open(sys.argv[3] if len(sys.argv) > 3 else os.path.join(os.path.dirname(ROOT), 'davnorm.log'), 'a', encoding='ascii', errors='backslashreplace')

def key(n):
    return unicodedata.normalize('NFC', n).casefold()

def log(*a):
    LOG.write(time.strftime('%H:%M:%S ') + ' '.join(str(x) for x in a) + '\n'); LOG.flush()

def resolve(urlpath):
    """returns (fs path, exists): the entry the name folds to, else the path as given"""
    p = urllib.parse.unquote(urllib.parse.urlsplit(urlpath).path)
    if not p.startswith(PREFIX):
        return None, False
    segs = [s for s in p[len(PREFIX):].split('/') if s]
    cur = ROOT
    for i, s in enumerate(segs):
        found = None
        if os.path.isdir(cur):
            try:
                for e in os.listdir(cur):
                    if e == s:
                        found = e; break
                if found is None:
                    for e in os.listdir(cur):
                        if key(e) == key(s):
                            found = e; break
            except OSError:
                pass
        if found is None:
            return os.path.join(cur, *segs[i:]), False
        cur = os.path.join(cur, found)
    return cur, True

def httpdate(t):
    return email.utils.formatdate(t, usegmt=True)

def isodate(t):
    return datetime.datetime.fromtimestamp(t, datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

def propxml(href, fs):
    st = os.stat(fs)
    isdir = os.path.isdir(fs)
    rt = '<D:resourcetype><D:collection/></D:resourcetype>' if isdir else '<D:resourcetype/>'
    ln = '' if isdir else '<D:getcontentlength>%d</D:getcontentlength>' % st.st_size
    return ('<D:response><D:href>%s</D:href><D:propstat><D:prop>%s%s'
            '<D:getlastmodified>%s</D:getlastmodified><D:creationdate>%s</D:creationdate>'
            '<D:displayname>%s</D:displayname><D:getetag>"%x-%x"</D:getetag>'
            '<D:supportedlock><D:lockentry><D:lockscope><D:exclusive/></D:lockscope><D:locktype><D:write/></D:locktype></D:lockentry></D:supportedlock>'
            '</D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat></D:response>') % (
        href, rt, ln, httpdate(st.st_mtime), isodate(st.st_ctime),
        xmlesc(os.path.basename(fs)), int(st.st_mtime * 1000), st.st_size)

def xmlesc(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')

class H(http.server.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, fmt, *args):
        pass

    def body(self):
        n = int(self.headers.get('Content-Length') or 0)
        return self.rfile.read(n) if n else b''

    def reply(self, code, data=b'', ctype='text/xml; charset="utf-8"', extra=None):
        self.send_response(code)
        self.send_header('Content-Length', str(len(data)))
        if data:
            self.send_header('Content-Type', ctype)
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        if data and self.command != 'HEAD':
            self.wfile.write(data)
        log(self.command, urllib.parse.unquote(self.path), '->', code)

    def do_OPTIONS(self):
        self.body()
        self.reply(200, extra={'DAV': '1,2', 'MS-Author-Via': 'DAV',
                               'Allow': 'OPTIONS, GET, HEAD, PUT, DELETE, PROPFIND, PROPPATCH, MKCOL, MOVE, COPY, LOCK, UNLOCK'})

    def do_PROPFIND(self):
        self.body()
        # feature 107: the server root "/" is a collection holding "dav" - the WebDAV redirector
        # checks it for the \\host@port\DavWWWRoot\dav\... form of the share
        if urllib.parse.unquote(urllib.parse.urlsplit(self.path).path).strip('/') == '':
            out = ['<?xml version="1.0" encoding="utf-8"?><D:multistatus xmlns:D="DAV:">', propxml('/', ROOT)]
            if self.headers.get('Depth', '1') != '0':
                out.append(propxml(PREFIX + '/', ROOT))
            out.append('</D:multistatus>')
            return self.reply(207, ''.join(out).encode('utf-8'))
        fs, ex = resolve(self.path)
        if fs is None or not ex:
            return self.reply(404)
        depth = self.headers.get('Depth', '1')
        req = urllib.parse.urlsplit(self.path).path
        out = ['<?xml version="1.0" encoding="utf-8"?><D:multistatus xmlns:D="DAV:">', propxml(xmlesc(req), fs)]
        if depth != '0' and os.path.isdir(fs):
            base = req if req.endswith('/') else req + '/'
            for e in os.listdir(fs):
                out.append(propxml(xmlesc(base + urllib.parse.quote(e)), os.path.join(fs, e)))
        out.append('</D:multistatus>')
        self.reply(207, ''.join(out).encode('utf-8'))

    def do_PROPPATCH(self):
        b = self.body()
        fs, ex = resolve(self.path)
        if not ex:
            return self.reply(404)
        req = xmlesc(urllib.parse.urlsplit(self.path).path)
        self.reply(207, ('<?xml version="1.0" encoding="utf-8"?><D:multistatus xmlns:D="DAV:"><D:response><D:href>%s</D:href>'
                         '<D:propstat><D:prop/><D:status>HTTP/1.1 200 OK</D:status></D:propstat></D:response></D:multistatus>' % req).encode())

    def do_GET(self):
        fs, ex = resolve(self.path)
        if not ex or os.path.isdir(fs):
            return self.reply(404 if not ex else 200, b'' if not ex else b'dir', 'text/plain')
        with open(fs, 'rb') as f:
            d = f.read()
        st = os.stat(fs)
        self.reply(200, d, 'application/octet-stream', {'Last-Modified': httpdate(st.st_mtime)})

    do_HEAD = do_GET

    def do_PUT(self):
        d = self.body()
        fs, ex = resolve(self.path)
        if fs is None:
            return self.reply(403)
        with open(fs, 'wb') as f:
            f.write(d)
        self.reply(204 if ex else 201)

    def do_DELETE(self):
        self.body()
        fs, ex = resolve(self.path)
        if not ex:
            return self.reply(404)
        log('  DELETE removes', fs)
        if os.path.isdir(fs):
            shutil.rmtree(fs)
        else:
            os.remove(fs)
        self.reply(204)

    def do_MKCOL(self):
        self.body()
        fs, ex = resolve(self.path)
        if ex:
            return self.reply(405)
        os.mkdir(fs)
        self.reply(201)

    def _dest(self):
        d = self.headers.get('Destination', '')
        return resolve(urllib.parse.urlsplit(d).path)

    def do_MOVE(self):
        self.body()
        fs, ex = resolve(self.path)
        dfs, dex = self._dest()
        ow = self.headers.get('Overwrite', 'T').upper() != 'F'
        log('  MOVE', fs, '->', dfs, 'dst exists' if dex else '', 'overwrite' if ow else 'no-overwrite')
        if not ex:
            return self.reply(404)
        newname = urllib.parse.unquote(urllib.parse.urlsplit(self.headers.get('Destination', '')).path).rstrip('/').split('/')[-1]
        same = dex and os.path.normcase(dfs) == os.path.normcase(fs)
        if same:
            actual = os.path.basename(fs)
            if newname == actual:
                return self.reply(204)  # rename onto the identical name: nothing to do
            if newname.casefold() == actual.casefold():
                os.rename(fs, os.path.join(os.path.dirname(fs), newname))  # a plain case change is allowed
                return self.reply(201)
            # another spelling (normalisation) of the same entry: "already exists" unless overwrite
        if dex and not ow:
            return self.reply(412)
        if dex and not same:
            if os.path.isdir(dfs):
                shutil.rmtree(dfs)
            else:
                os.remove(dfs)
        # a rename onto another spelling of the same entry: store the new spelling
        target = os.path.join(os.path.dirname(dfs), newname)
        os.rename(fs, target)
        self.reply(204 if dex else 201)

    def do_COPY(self):
        self.body()
        fs, ex = resolve(self.path)
        dfs, dex = self._dest()
        ow = self.headers.get('Overwrite', 'T').upper() != 'F'
        if not ex:
            return self.reply(404)
        if dex and not ow:
            return self.reply(412)
        if os.path.isdir(fs):
            shutil.copytree(fs, dfs, dirs_exist_ok=True)
        else:
            shutil.copy2(fs, dfs)
        self.reply(204 if dex else 201)

    def do_LOCK(self):
        self.body()
        fs, ex = resolve(self.path)
        if fs is None:
            return self.reply(403)
        if not ex:
            open(fs, 'wb').close()
        tok = 'opaquelocktoken:' + str(uuid.uuid4())
        x = ('<?xml version="1.0" encoding="utf-8"?><D:prop xmlns:D="DAV:"><D:lockdiscovery><D:activelock>'
             '<D:locktype><D:write/></D:locktype><D:lockscope><D:exclusive/></D:lockscope><D:depth>0</D:depth>'
             '<D:timeout>Second-3600</D:timeout><D:locktoken><D:href>%s</D:href></D:locktoken>'
             '</D:activelock></D:lockdiscovery></D:prop>') % tok
        self.reply(200 if ex else 201, x.encode(), extra={'Lock-Token': '<%s>' % tok})

    def do_UNLOCK(self):
        self.body()
        self.reply(204)

if __name__ == '__main__':
    os.makedirs(ROOT, exist_ok=True)
    s = http.server.ThreadingHTTPServer(('127.0.0.1', PORT), H)
    log('serving', ROOT, PORT)
    s.serve_forever()
