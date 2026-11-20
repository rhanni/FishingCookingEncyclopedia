"""Local dev server for addon art.

Serves tools/art/ and accepts POST /save/<name> to write a rendered texture
into the addon's Media/ folder. Only plain .tga/.png filenames are accepted,
and it only listens on 127.0.0.1.

Usage: python -I tools/art/art_server.py [port]
"""
import http.server, pathlib, re, sys

ART_DIR = pathlib.Path(__file__).resolve().parent
MEDIA_DIR = ART_DIR.parent.parent / "Media"
NAME_RE = re.compile(r"^[A-Za-z0-9_-]+\.(tga|png)$")


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ART_DIR), **kwargs)

    def do_POST(self):
        name = self.path.removeprefix("/save/")
        if not self.path.startswith("/save/") or not NAME_RE.match(name):
            self.send_error(400, "Bad file name")
            return
        length = int(self.headers.get("Content-Length", 0))
        if length <= 0 or length > 4 * 1024 * 1024:
            self.send_error(400, "Bad size")
            return
        data = self.rfile.read(length)
        MEDIA_DIR.mkdir(exist_ok=True)
        (MEDIA_DIR / name).write_bytes(data)
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(f"saved Media/{name} ({len(data)} bytes)".encode())


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8766
    http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
