"""Feature 085 probe for privacy defect F2 (mdview remote-image requests).

Starts a local HTTP server on 127.0.0.1 that logs every request's headers,
runs fetch_probe.exe (fetch_main.cpp + src/plugins/mdview/remotefetch.cpp)
against it, and checks:

  F2-UA      every request identifies as "TandemCommander-mdview"
  F2-COOKIE  the server sets a cookie on the first answer; no later request
             carries a Cookie header
  F2-STATUS  a 404 (HTML body) and a 500 count as failures; 200 counts as
             success with the image's exact size
  F2-AUTH    a 401 Negotiate/NTLM challenge is not answered with credentials
             (no Authorization header ever arrives) and the fetch fails
  F2-REDIR   a 302 to an image is followed (unchanged WinHTTP default); a
             cookie set on the redirect is not sent with the follow-up request
             (the case where the old code really did send one: WinHTTP keeps a
             cookie jar per session, and each fetch is its own session)

Usage:  python fetch_server.py <path-to-fetch_probe.exe>
Exit code 0 = all checks passed.
"""

import http.server
import subprocess
import sys
import threading

PNG = bytes.fromhex(
    "89504e470d0a1a0a0000000d4948445200000001000000010806000000"
    "1f15c4890000000d49444154789c6360000002000154a24f5d0000000049454e44ae426082"
)

LOG = []


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):  # keep the console clean
        pass

    def _send(self, code, body, ctype, extra=None):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        for k, v in (extra or []):
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        LOG.append((self.path, dict(self.headers.items())))
        if self.path == "/first.png":
            self._send(200, PNG, "image/png", [("Set-Cookie", "tc085=tracked; Path=/")])
        elif self.path == "/second.png":
            self._send(200, PNG, "image/png")
        elif self.path == "/missing.png":
            self._send(404, b"<html><body>Not Found</body></html>", "text/html")
        elif self.path == "/broken.png":
            self._send(500, b"<html><body>Server Error</body></html>", "text/html")
        elif self.path == "/auth.png":
            self._send(401, b"<html>auth</html>", "text/html",
                       [("WWW-Authenticate", "Negotiate"), ("WWW-Authenticate", "NTLM")])
        elif self.path == "/redirect.png":
            self._send(302, b"", "text/html", [("Location", "/second.png")])
        elif self.path == "/cookie-redirect.png":
            # one request, one WinHTTP session: a cookie set on the redirect
            # would come back on the follow-up request unless cookies are off
            self._send(302, b"", "text/html",
                       [("Location", "/after-cookie.png"), ("Set-Cookie", "tc085r=tracked; Path=/")])
        elif self.path == "/after-cookie.png":
            self._send(200, PNG, "image/png")
        else:
            self._send(404, b"", "text/plain")


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    exe = sys.argv[1]
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    port = srv.server_address[1]
    threading.Thread(target=srv.serve_forever, daemon=True).start()

    paths = ["/first.png", "/second.png", "/missing.png", "/broken.png", "/auth.png", "/redirect.png",
             "/cookie-redirect.png"]
    # two rounds: the cookie set in round 1 must not come back in round 2 either
    res = subprocess.run([exe, "http://127.0.0.1:%d" % port] + paths + paths,
                         capture_output=True, text=True, timeout=120)
    srv.shutdown()
    print(res.stdout.strip())
    if res.returncode != 0:
        print("FAIL probe exit code", res.returncode, res.stderr)
        return 1

    results = [line.split() for line in res.stdout.strip().splitlines()]
    expected = {
        "/first.png": ("ok", len(PNG)),
        "/second.png": ("ok", len(PNG)),
        "/missing.png": ("fail", 0),
        "/broken.png": ("fail", 0),
        "/auth.png": ("fail", 0),
        "/redirect.png": ("ok", len(PNG)),
        "/cookie-redirect.png": ("ok", len(PNG)),
    }
    failures = 0

    def check(name, cond, detail=""):
        nonlocal failures
        print(("PASS " if cond else "FAIL ") + name + (" - " + detail if detail else ""))
        if not cond:
            failures += 1

    check("results-count", len(results) == 2 * len(paths), "%d lines" % len(results))
    for path, verdict, size in results:
        exp = expected[path]
        ok = verdict == exp[0] and (verdict == "fail" or int(size) == exp[1])
        name = {"/missing.png": "F2-STATUS 404", "/broken.png": "F2-STATUS 500",
                "/auth.png": "F2-AUTH 401", "/redirect.png": "F2-REDIR 302",
                "/cookie-redirect.png": "F2-REDIR 302 with cookie"}.get(path, "F2-STATUS 200 " + path)
        check(name, ok, "%s %s" % (verdict, size))

    agents = {h.get("User-Agent") for _, h in LOG}
    check("F2-UA", agents == {"TandemCommander-mdview"}, repr(agents))
    cookies = [p for p, h in LOG if "Cookie" in h]
    check("F2-COOKIE", not cookies, "requests with a Cookie header: %r" % cookies)
    auth = [p for p, h in LOG if "Authorization" in h]
    check("F2-AUTH no credentials", not auth, "requests with Authorization: %r" % auth)
    check("server saw requests", len(LOG) >= 2 * len(paths), "%d requests" % len(LOG))

    print("fetch probe: %d failed" % failures)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
