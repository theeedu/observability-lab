"""Testes da API de exemplo."""
from fastapi.testclient import TestClient

from app import app

client = TestClient(app)


def test_root():
    resp = client.get("/")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


def test_healthz():
    resp = client.get("/healthz")
    assert resp.status_code == 200
    assert resp.json() == {"status": "alive"}


def test_readyz():
    resp = client.get("/readyz")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ready"}


def test_metrics_exposes_prometheus():
    resp = client.get("/metrics")
    assert resp.status_code == 200
    # A métrica só aparece após ao menos uma requisição contabilizada
    assert "http_requests_total" in resp.text


def test_work_returns_latency():
    resp = client.get("/work")
    assert resp.status_code == 200
    assert "latency_ms" in resp.json()
