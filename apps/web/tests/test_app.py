import requests

import app as web


def test_healthz():
    resp = web.app.test_client().get("/healthz")
    assert resp.status_code == 200
    assert resp.get_json()["service"] == "web"


def test_home_survives_api_outage(monkeypatch):
    def broken_get(*args, **kwargs):
        raise requests.ConnectionError("api down")

    monkeypatch.setattr(web.requests, "get", broken_get)
    resp = web.app.test_client().get("/")
    assert resp.status_code == 200
    assert b"cyb3r-kub3n3t3s" in resp.data