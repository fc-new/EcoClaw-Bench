#!/usr/bin/env python3
import argparse
import asyncio
import json
import os
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Dict, List, Optional


def _load_memobrain():
    try:
        from memobrain import MemoBrain as _MemoBrain
        return _MemoBrain
    except ImportError:
        repo_root = Path(__file__).resolve().parents[1]
        src_path = repo_root / "src"
        if str(src_path) not in sys.path:
            sys.path.insert(0, str(src_path))
        from memobrain import MemoBrain as _MemoBrain
        return _MemoBrain


MemoBrain = _load_memobrain()


def _now() -> float:
    return time.time()


def _normalize_content(content: Any) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts: List[str] = []
        for block in content:
            if isinstance(block, dict):
                if isinstance(block.get("text"), str):
                    parts.append(block["text"])
                elif isinstance(block.get("content"), str):
                    parts.append(block["content"])
                elif block.get("arguments") is not None:
                    parts.append(json.dumps(block["arguments"], ensure_ascii=False))
                else:
                    parts.append(json.dumps(block, ensure_ascii=False))
            else:
                parts.append(str(block))
        return "\n".join(parts).strip()
    return str(content)


def _normalize_messages(messages: List[Dict[str, Any]]) -> List[Dict[str, str]]:
    out: List[Dict[str, str]] = []
    for msg in messages:
        role = str(msg.get("role", "user"))
        if role not in {"system", "user", "assistant"}:
            role = "user"
        out.append({"role": role, "content": _normalize_content(msg.get("content", ""))})
    return out


class SessionStore:
    def __init__(self, api_key: str, base_url: str, model_name: str):
        self.api_key = api_key
        self.base_url = base_url
        self.model_name = model_name
        self._lock = threading.Lock()
        self._sessions: Dict[str, Dict[str, Any]] = {}

    def _new_memory(self):
        return MemoBrain(
            api_key=self.api_key,
            base_url=self.base_url,
            model_name=self.model_name,
        )

    def ensure_session(self, session_id: str, task: str = "Auto-created session") -> Dict[str, Any]:
        with self._lock:
            if session_id not in self._sessions:
                mem = self._new_memory()
                mem.init_memory(task)
                self._sessions[session_id] = {
                    "memory": mem,
                    "created_at": _now(),
                    "updated_at": _now(),
                    "task": task,
                    "memorize_calls": 0,
                    "recall_calls": 0,
                }
            return self._sessions[session_id]

    def init_session(self, session_id: str, task: str, reset_if_exists: bool) -> Dict[str, Any]:
        with self._lock:
            if reset_if_exists or session_id not in self._sessions:
                mem = self._new_memory()
                mem.init_memory(task)
                self._sessions[session_id] = {
                    "memory": mem,
                    "created_at": _now(),
                    "updated_at": _now(),
                    "task": task,
                    "memorize_calls": 0,
                    "recall_calls": 0,
                }
            return self._sessions[session_id]

    def get_session(self, session_id: str) -> Optional[Dict[str, Any]]:
        with self._lock:
            return self._sessions.get(session_id)

    def delete_session(self, session_id: str) -> bool:
        with self._lock:
            existed = session_id in self._sessions
            if existed:
                del self._sessions[session_id]
            return existed

    def stats(self) -> Dict[str, Any]:
        with self._lock:
            return {
                "sessions": len(self._sessions),
                "session_ids": list(self._sessions.keys())[:200],
                "model_name": self.model_name,
                "base_url": self.base_url,
            }


def run_async(coro):
    return asyncio.run(coro)


class Handler(BaseHTTPRequestHandler):
    store: Optional[SessionStore] = None

    def _send(self, code: int, body: Dict[str, Any]) -> None:
        data = json.dumps(body, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _read_json(self) -> Dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length > 0 else b"{}"
        if not raw:
            return {}
        return json.loads(raw.decode("utf-8"))

    def do_GET(self):
        if self.path == "/health":
            self._send(200, {"ok": True, "service": "memobrain-adapter", "ts": _now()})
            return
        if self.path == "/stats":
            stats = self.store.stats() if self.store else {}
            self._send(200, {"ok": True, **stats})
            return
        self._send(404, {"ok": False, "error": "Not found"})

    def do_POST(self):
        try:
            if self.path == "/session/init":
                data = self._read_json()
                session_id = str(data.get("session_id", "")).strip()
                task = str(data.get("task", "OpenClaw task")).strip()
                reset_if_exists = bool(data.get("reset_if_exists", False))
                if not session_id:
                    self._send(400, {"ok": False, "error": "session_id is required"})
                    return
                if not self.store:
                    self._send(500, {"ok": False, "error": "store not initialized"})
                    return
                s = self.store.init_session(session_id, task, reset_if_exists)
                self._send(200, {
                    "ok": True,
                    "session_id": session_id,
                    "task": s["task"],
                    "created_at": s["created_at"],
                })
                return

            if self.path == "/session/memorize":
                data = self._read_json()
                session_id = str(data.get("session_id", "")).strip()
                task = str(data.get("task", "Auto-created session")).strip()
                messages = data.get("messages", [])
                if not session_id:
                    self._send(400, {"ok": False, "error": "session_id is required"})
                    return
                if not isinstance(messages, list):
                    self._send(400, {"ok": False, "error": "messages must be list"})
                    return
                if not self.store:
                    self._send(500, {"ok": False, "error": "store not initialized"})
                    return
                s = self.store.ensure_session(session_id, task)
                normalized = _normalize_messages(messages)
                if normalized:
                    run_async(s["memory"].memorize(normalized))
                    s["memorize_calls"] += 1
                    s["updated_at"] = _now()
                self._send(200, {
                    "ok": True,
                    "session_id": session_id,
                    "memorized_messages": len(normalized),
                    "memorize_calls": s["memorize_calls"],
                })
                return

            if self.path == "/session/recall":
                data = self._read_json()
                session_id = str(data.get("session_id", "")).strip()
                if not session_id:
                    self._send(400, {"ok": False, "error": "session_id is required"})
                    return
                if not self.store:
                    self._send(500, {"ok": False, "error": "store not initialized"})
                    return
                s = self.store.get_session(session_id)
                if not s:
                    self._send(404, {"ok": False, "error": "session not found"})
                    return
                recalled = run_async(s["memory"].recall())
                s["recall_calls"] += 1
                s["updated_at"] = _now()
                self._send(200, {
                    "ok": True,
                    "session_id": session_id,
                    "messages": _normalize_messages(recalled),
                    "recall_calls": s["recall_calls"],
                })
                return

            if self.path == "/session/reset":
                data = self._read_json()
                session_id = str(data.get("session_id", "")).strip()
                if not session_id:
                    self._send(400, {"ok": False, "error": "session_id is required"})
                    return
                if not self.store:
                    self._send(500, {"ok": False, "error": "store not initialized"})
                    return
                deleted = self.store.delete_session(session_id)
                self._send(200, {"ok": True, "session_id": session_id, "deleted": deleted})
                return

            self._send(404, {"ok": False, "error": "Not found"})
        except Exception as e:
            self._send(500, {"ok": False, "error": str(e)})

    def log_message(self, format, *args):
        return


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default=os.getenv("MEMOBRAIN_ADAPTER_HOST", "127.0.0.1"))
    parser.add_argument("--port", type=int, default=int(os.getenv("MEMOBRAIN_ADAPTER_PORT", "19002")))
    parser.add_argument("--api-key", default=os.getenv("MEMOBRAIN_API_KEY", "empty"))
    parser.add_argument("--base-url", default=os.getenv("MEMOBRAIN_BASE_URL", "http://localhost:8002/v1"))
    parser.add_argument("--model-name", default=os.getenv("MEMOBRAIN_MODEL_NAME", "TommyChien/MemoBrain-14B"))
    args = parser.parse_args()

    Handler.store = SessionStore(
        api_key=args.api_key,
        base_url=args.base_url,
        model_name=args.model_name,
    )
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"MemoBrain adapter listening on http://{args.host}:{args.port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
