import os
import socket

import requests
from flask import Flask, jsonify, render_template_string

app = Flask(__name__)

APP_ENV = os.getenv("APP_ENV", "local")
APP_VERSION = os.getenv("APP_VERSION", "dev")
API_URL = os.getenv("API_URL", "http://api:5000")

PAGE = """
<!doctype html>
<html>
<head>
  <title>cyb3r-kub3n3t3s</title>
  <style>
    body { font-family: sans-serif; margin: 0; background: #0f172a; color: #e2e8f0; }
    .banner { padding: 16px; font-weight: bold; text-align: center;
      background: {{ 'darkorange' if env == 'staging' else 'seagreen' if env == 'production' else 'slategray' }}; }
    .card { max-width: 560px; margin: 40px auto; padding: 24px; background: #1e293b; border-radius: 12px; }
  </style>
</head>
<body>
  <div class="banner">ENVIRONMENT: {{ env | upper }}</div>
  <div class="card">
    <h1>cyb3r-kub3n3t3s</h1>
    <p>Shipped by the cyb3r platform team.</p>
    <p>Web version: <b>{{ version }}</b> &middot; web pod <code>{{ pod }}</code></p>
    <p>Visits: <b>{{ api.get('visits', 'unavailable') }}</b>
       &middot; api version <b>{{ api.get('version', '?') }}</b>
       &middot; api pod <code>{{ api.get('pod', '?') }}</code></p>
  </div>
</body>
</html>
"""


@app.get("/")
def home():
    try:
        resp = requests.get(f"{API_URL}/api/visits", timeout=3)
        resp.raise_for_status()
        api_data = resp.json()
    except requests.RequestException:
        api_data = {}
    return render_template_string(
        PAGE, env=APP_ENV, version=APP_VERSION, pod=socket.gethostname(), api=api_data
    )


@app.get("/healthz")
def healthz():
    return jsonify(status="ok", service="web")