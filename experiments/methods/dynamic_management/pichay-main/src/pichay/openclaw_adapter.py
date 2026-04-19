from __future__ import annotations

import argparse
import copy
import json
import threading
import time
from datetime import datetime, timezone
from typing import Any, Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn

from pichay.pager import PageStore, compact_messages, compact_conversation


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def normalize_role(role: Any) -> str:
    r = str(role or "user")
    if r in {"system", "user", "assistant", "tool"}:
        return r
    return "user"


def normalize_content(content: Any) -> str | list:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return content
    if isinstance(content, dict):
        return json.dumps(content, ensure_ascii=False)
    return str(content)


def normalize_messages(messages: list[dict[str, Any]]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for msg in messages:
        out.append(
            {
                "role": normalize_role(msg.get("role")),
                "content": normalize_content(msg.get("content", "")),
            }
        )
    return out


class SessionState:
    def __init__(self, task: str):
        self.task = task
        self.messages: list[dict[str, Any]] = []
        self.page_store = PageStore(log_path=None)
        self.created_at = now_iso()
        self.updated_at = self.created_at
        self.memorize_calls = 0
        self.compact_calls = 0


class SessionStore:
    def __init__(self):
        self._lock = threading.Lock()
        self._sessions: dict[str, SessionState] = {}

    def init_session(self, session_id: str, task: str, reset_if_exists: bool) -> SessionState:
        with self._lock:
            if reset_if_exists or session_id not in self._sessions:
                self._sessions[session_id] = SessionState(task=task)
            return self._sessions[session_id]

    def ensure_session(self, session_id: str, task: str) -> SessionState:
        with self._lock:
            if session_id not in self._sessions:
                self._sessions[session_id] = SessionState(task=task)
            return self._sessions[session_id]

    def get_session(self, session_id: str) -> Optional[SessionState]:
        with self._lock:
            return self._sessions.get(session_id)

    def delete_session(self, session_id: str) -> bool:
        with self._lock:
            existed = session_id in self._sessions
            if existed:
                del self._sessions[session_id]
            return existed

    def stats(self) -> dict[str, Any]:
        with self._lock:
            return {
                "sessions": len(self._sessions),
                "session_ids": list(self._sessions.keys())[:200],
            }


class InitReq(BaseModel):
    session_id: str
    task: str = "OpenClaw task"
    reset_if_exists: bool = False


class MemorizeReq(BaseModel):
    session_id: str
    task: str = "OpenClaw task"
    messages: list[dict[str, Any]]


class CompactReq(BaseModel):
    session_id: str
    age_threshold: int = 4
    min_evict_size: int = 500
    preserve_recent: int = 12
    min_text_chars: int = 2000
    max_summary_chars: int = 300
    use_model_summary: bool = False


class ResetReq(BaseModel):
    session_id: str


store = SessionStore()
app = FastAPI(title="Pichay OpenClaw Adapter", version="0.1.0")


@app.get("/health")
def health() -> dict[str, Any]:
    return {"ok": True, "service": "pichay-openclaw-adapter", "ts": now_iso()}


@app.get("/stats")
def stats() -> dict[str, Any]:
    return {"ok": True, **store.stats()}


@app.post("/session/init")
def session_init(req: InitReq) -> dict[str, Any]:
    if not req.session_id.strip():
        raise HTTPException(status_code=400, detail="session_id is required")
    s = store.init_session(req.session_id.strip(), req.task.strip() or "OpenClaw task", req.reset_if_exists)
    return {"ok": True, "session_id": req.session_id, "task": s.task, "created_at": s.created_at}


@app.post("/session/memorize")
def session_memorize(req: MemorizeReq) -> dict[str, Any]:
    session_id = req.session_id.strip()
    if not session_id:
        raise HTTPException(status_code=400, detail="session_id is required")
    s = store.ensure_session(session_id, req.task.strip() or "OpenClaw task")
    normalized = normalize_messages(req.messages)
    if normalized:
        s.messages.extend(normalized)
        s.memorize_calls += 1
        s.updated_at = now_iso()
    return {
        "ok": True,
        "session_id": session_id,
        "memorized_messages": len(normalized),
        "total_messages": len(s.messages),
        "memorize_calls": s.memorize_calls,
    }


@app.post("/session/compact")
def session_compact(req: CompactReq) -> dict[str, Any]:
    session_id = req.session_id.strip()
    if not session_id:
        raise HTTPException(status_code=400, detail="session_id is required")
    s = store.get_session(session_id)
    if s is None:
        raise HTTPException(status_code=404, detail="session not found")

    working = copy.deepcopy(s.messages)
    msg_stats = compact_messages(
        working,
        age_threshold=max(1, req.age_threshold),
        min_size=max(64, req.min_evict_size),
        page_store=s.page_store,
    )
    conv_stats = compact_conversation(
        working,
        preserve_recent=max(2, req.preserve_recent),
        min_text_chars=max(200, req.min_text_chars),
        max_summary_chars=max(100, req.max_summary_chars),
        use_model=req.use_model_summary,
    )

    s.messages = working
    s.compact_calls += 1
    s.updated_at = now_iso()
    return {
        "ok": True,
        "session_id": session_id,
        "messages": s.messages,
        "compact_calls": s.compact_calls,
        "compact_stats": {
            "tool_results_total": msg_stats.total_tool_results,
            "tool_results_evicted": msg_stats.evicted_count,
            "tool_bytes_before": msg_stats.bytes_before,
            "tool_bytes_after": msg_stats.bytes_after,
            "tool_bytes_saved": msg_stats.bytes_saved,
            "conversation_messages_scanned": conv_stats.messages_scanned,
            "conversation_messages_compressed": conv_stats.messages_compressed,
            "conversation_chars_before": conv_stats.chars_before,
            "conversation_chars_after": conv_stats.chars_after,
            "conversation_chars_saved": conv_stats.chars_saved,
            "faults": len(s.page_store.faults),
            "evictions": s.page_store.unique_evictions,
            "gc_count": s.page_store.gc_count,
        },
    }


@app.post("/session/reset")
def session_reset(req: ResetReq) -> dict[str, Any]:
    session_id = req.session_id.strip()
    if not session_id:
        raise HTTPException(status_code=400, detail="session_id is required")
    deleted = store.delete_session(session_id)
    return {"ok": True, "session_id": session_id, "deleted": deleted}


def main() -> None:
    parser = argparse.ArgumentParser(description="Pichay adapter for OpenClaw plugin")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=19012)
    args = parser.parse_args()
    uvicorn.run(app, host=args.host, port=args.port, log_level="warning")


if __name__ == "__main__":
    main()
