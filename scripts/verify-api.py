#!/usr/bin/env python3
"""Exercise the actual Swift URLSession client with a local DeepSeek-shaped fixture.
Uses a dummy key only. No external services, user preferences, or Keychain writes.
"""
import json
import pathlib
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

root = pathlib.Path(__file__).resolve().parents[1]
binary = pathlib.Path(subprocess.check_output(["swift", "build", "--show-bin-path"], cwd=root, text=True).strip()) / "FlowTranslate"
counts = {}

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        assert body["model"] == "deepseek-v4-pro"
        assert body["thinking"] == {"type": "disabled"}
        assert body["stream"] is True
        assert self.headers["Authorization"] == "Bearer fixture-key"
        text = body["messages"][-1]["content"]
        counts[text] = counts.get(text, 0) + 1
        if self.path.startswith("/unauthorized"):
            self.send_response(401)
            self.end_headers()
            return
        if self.path.startswith("/redirect"):
            self.send_response(307)
            self.send_header("Location", "/unexpected-secret-forwarding")
            self.end_headers()
            return
        assert "unexpected-secret" not in self.path
        if self.path.startswith("/json"):
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"choices": [{"message": {"content": "你好"}, "finish_reason": "stop"}]}, ensure_ascii=False).encode())
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.end_headers()
        if text == "slow":
            time.sleep(0.6)
        try:
            if body.get("response_format") == {"type": "json_object"}:
                value = json.dumps({"word": "bank", "meaning": "河岸", "language": "en"}, ensure_ascii=False)
                tokens = [value[i:i+3] for i in range(0, len(value), 3)]
            else:
                tokens = ["新的", "翻译"] if text == "new" else ["你", "好"]
            self.wfile.write(b": heartbeat\r\n\r\n")
            # Thinking and usage frames must not leak into the translated text.
            frames = [{"choices": [{"delta": {"reasoning_content": "DO NOT SHOW"}, "finish_reason": None}]}]
            frames += [{"choices": [{"delta": {"content": token}, "finish_reason": None}]} for token in tokens]
            if text != "truncated":
                frames += [{"choices": [{"delta": {}, "finish_reason": "stop"}]}, {"choices": [], "usage": {"total_tokens": 5}}]
            for frame in frames:
                self.wfile.write(("data: " + json.dumps(frame, ensure_ascii=False) + "\r\n\r\n").encode())
                self.wfile.flush()
                time.sleep(0.015)
            if text != "truncated":
                self.wfile.write(b"data: [DONE]\r\n\r\n")
        except (BrokenPipeError, ConnectionResetError):
            pass

server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
base = f"http://127.0.0.1:{server.server_port}"
try:
    for route, successful in [("/v1", True), ("/json", True), ("/unauthorized", False), ("/redirect", False)]:
        result = subprocess.run([str(binary), "--api-smoke-test", base + route], capture_output=True, text=True, timeout=12)
        assert (result.returncode == 0) == successful, (route, result.stdout, result.stderr)
        if successful:
            assert "API PASS: 你好" in result.stdout
            assert "DO NOT SHOW" not in result.stdout
        print(f"PASS: {route}")
    result = subprocess.run([str(binary), "--model-smoke-test", base + "/v1"], capture_output=True, text=True, timeout=20)
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert counts.get("new") == 1, counts
    assert counts.get("truncated") == 2, counts
    print(result.stdout.strip())
    result = subprocess.run([str(binary), "--dictionary-smoke-test", base + "/v1"], capture_output=True, text=True, timeout=12)
    assert result.returncode == 0, (result.stdout, result.stderr)
    print(result.stdout.strip())
finally:
    server.shutdown()
