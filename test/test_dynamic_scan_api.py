import time
from threading import Event

from fastapi.testclient import TestClient

import src.api as api


def setup_function():
    api._scan_thread = None
    api._stop_event = Event()
    api._scan_results = []


def test_start_and_results(monkeypatch):
    def fake_scan(subnet, ports):
        api._stop_event.set()
        return [{"ip": "192.168.0.2", "ports": [80]}]

    monkeypatch.setattr(api, "scan_hosts", fake_scan)
    monkeypatch.setattr(api, "_get_subnet", lambda: "192.168.0.0/24")
    client = TestClient(api.app)

    res = client.post("/dynamic-scan/start", json={})
    assert res.status_code == 200

    api._scan_thread.join(timeout=1)

    res = client.get("/dynamic-scan/results")
    assert res.status_code == 200
    assert res.json() == {
        "running": False,
        "results": [{"ip": "192.168.0.2", "ports": [80]}],
    }


def test_start_twice_errors(monkeypatch):
    def long_scan(subnet, ports):
        time.sleep(0.2)
        return []

    monkeypatch.setattr(api, "scan_hosts", long_scan)
    monkeypatch.setattr(api, "_get_subnet", lambda: "192.168.0.0/24")
    client = TestClient(api.app)

    client.post("/dynamic-scan/start", json={})
    res = client.post("/dynamic-scan/start", json={})
    assert res.status_code == 400

    client.post("/dynamic-scan/stop")


def test_stop_without_running():
    client = TestClient(api.app)
    res = client.post("/dynamic-scan/stop")
    assert res.status_code == 400


def test_stop(monkeypatch):
    def long_scan(subnet, ports):
        time.sleep(0.2)
        return []

    monkeypatch.setattr(api, "scan_hosts", long_scan)
    monkeypatch.setattr(api, "_get_subnet", lambda: "192.168.0.0/24")
    client = TestClient(api.app)

    client.post("/dynamic-scan/start", json={})
    res = client.post("/dynamic-scan/stop")
    assert res.status_code == 200
    assert res.json()["status"] == "stopped"
