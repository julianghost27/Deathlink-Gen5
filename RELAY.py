"""relay.py -- run on ONE pc: python relay.py   (Python 3, no extra packages)
Both BizHawk scripts talk to this. Restart it when you start a new run,
because it remembers all faints so a restarted script can catch up."""
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

PORT = 8080
events = []            # (id, sender, number)
lock = threading.Lock()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _reply(self, text, code=200):
        data = text.encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        url = urlparse(self.path)
        query = parse_qs(url.query)
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode().strip()
        if url.path == "/event" and body.isdigit():
            with lock:
                events.append((len(events) + 1, query.get("from", ["?"])[0], body))
                print("faint:", events[-1])
            self._reply("ok")
        else:
            self._reply("bad request", 400)

    def do_GET(self):
        url = urlparse(self.path)
        query = parse_qs(url.query)
        if url.path == "/poll":
            me = query.get("player", [""])[0]
            since = int(query.get("since", ["0"])[0])
            with lock:
                lines = [f"{i} {s} {n}" for i, s, n in events if i > since and s != me]
            self._reply("\n".join(lines))
        else:
            self._reply("not found", 404)


if __name__ == "__main__":
    print(f"relay listening on port {PORT}")
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()