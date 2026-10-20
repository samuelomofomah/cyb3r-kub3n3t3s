import os
import socket

import redis
from flask import Flask, jsonify

app = Flask(__name__)

APP_ENV = os.getenv("APP_ENV", "local")
APP_VERSION = os.getenv("APP_VERSION", "dev")
REDIS_HOST = os.getenv("REDIS_HOST", "redis")


def get_redis():
    return redis.Redis(host=REDIS_HOST, port=6379, socket_connect_timeout=2, decode_responses=True)


@app.get("/healthz")
def healthz():
    return jsonify(status="ok", service="api")


@app.get("/api/visits")
def visits():
    try:
        count = get_redis().incr("visits")
    except redis.exceptions.RedisError:
        return jsonify(error="redis unavailable"), 503
    return jsonify(visits=count, env=APP_ENV, version=APP_VERSION, pod=socket.gethostname())