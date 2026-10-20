import redis

import app as api


class FakeRedis:
    def __init__(self):
        self.count = 0

    def incr(self, key):
        self.count += 1
        return self.count


def test_healthz():
    resp = api.app.test_client().get("/healthz")
    assert resp.status_code == 200
    assert resp.get_json()["service"] == "api"


def test_visits_count_up(monkeypatch):
    fake = FakeRedis()
    monkeypatch.setattr(api, "get_redis", lambda: fake)
    client = api.app.test_client()
    assert client.get("/api/visits").get_json()["visits"] == 1
    assert client.get("/api/visits").get_json()["visits"] == 2


def test_visits_when_redis_is_down(monkeypatch):
    class BrokenRedis:
        def incr(self, key):
            raise redis.exceptions.ConnectionError("down")

    monkeypatch.setattr(api, "get_redis", lambda: BrokenRedis())
    resp = api.app.test_client().get("/api/visits")
    assert resp.status_code == 503