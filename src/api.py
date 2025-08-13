from __future__ import annotations

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from threading import Event, Thread
from typing import List, Dict, Any

from lan_port_scan import scan_hosts, DEFAULT_PORTS
from discover_hosts import _get_subnet

app = FastAPI()

_scan_thread: Thread | None = None
_stop_event = Event()
_scan_results: List[Dict[str, Any]] = []


class ScanRequest(BaseModel):
    subnet: str | None = None
    ports: List[str] | None = None


def _scan_loop(subnet: str, ports: List[str]) -> None:
    global _scan_results
    while not _stop_event.is_set():
        _scan_results = scan_hosts(subnet, ports)
        # wait a bit before next scan, allowing stop_event to terminate early
        _stop_event.wait(5)


@app.post("/dynamic-scan/start")
def start_scan(req: ScanRequest) -> Dict[str, str]:
    """Start dynamic scanning in background."""
    global _scan_thread
    if _scan_thread and _scan_thread.is_alive():
        raise HTTPException(status_code=400, detail="scan already running")
    subnet = req.subnet or _get_subnet() or "192.168.1.0/24"
    ports = req.ports or DEFAULT_PORTS
    _stop_event.clear()
    _scan_thread = Thread(target=_scan_loop, args=(subnet, ports), daemon=True)
    _scan_thread.start()
    return {"status": "started"}


@app.post("/dynamic-scan/stop")
def stop_scan() -> Dict[str, str]:
    """Stop the running dynamic scan."""
    global _scan_thread
    if not _scan_thread or not _scan_thread.is_alive():
        raise HTTPException(status_code=400, detail="no active scan")
    _stop_event.set()
    _scan_thread.join()
    _scan_thread = None
    return {"status": "stopped"}


@app.get("/dynamic-scan/results")
def get_results() -> Dict[str, Any]:
    """Return current scan results."""
    running = _scan_thread is not None and _scan_thread.is_alive()
    return {"running": running, "results": _scan_results}
