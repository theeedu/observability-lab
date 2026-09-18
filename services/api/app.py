"""
Observability Lab — API de exemplo (FastAPI).

Serviço web propositalmente instrumentado para demonstrar observabilidade:
- Métricas no formato Prometheus em /metrics (RED: Rate, Errors, Duration)
- Logs estruturados em JSON (consumidos pelo Loki via Promtail)
- Endpoints de saúde (/healthz, /readyz) para probes
- Endpoints que geram carga/erros de propósito para popular dashboards e alertas
"""
import logging
import random
import sys
import time

from fastapi import FastAPI, HTTPException, Response
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Histogram,
    generate_latest,
)
from pythonjsonlogger import jsonlogger

# --------------------------------------------------------------------------- #
# Logging estruturado (JSON) — pronto para ingestão por Loki/Promtail
# --------------------------------------------------------------------------- #
logger = logging.getLogger("observability-lab.api")
logger.setLevel(logging.INFO)
_handler = logging.StreamHandler(sys.stdout)
_handler.setFormatter(
    jsonlogger.JsonFormatter(
        "%(asctime)s %(levelname)s %(name)s %(message)s",
        rename_fields={"asctime": "timestamp", "levelname": "level"},
    )
)
logger.handlers = [_handler]
logger.propagate = False

# --------------------------------------------------------------------------- #
# Métricas Prometheus (padrão RED)
# --------------------------------------------------------------------------- #
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total de requisições HTTP",
    ["method", "endpoint", "status"],
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "Latência das requisições HTTP em segundos",
    ["method", "endpoint"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0),
)

app = FastAPI(
    title="Observability Lab API",
    description="API de exemplo instrumentada para o Observability & DevOps Lab.",
    version="1.0.0",
)


@app.middleware("http")
async def observe_requests(request, call_next):
    """Middleware que registra métricas RED e log estruturado por requisição."""
    start = time.perf_counter()
    endpoint = request.url.path
    method = request.method
    try:
        response = await call_next(request)
        status = response.status_code
    except Exception:  # pragma: no cover - salvaguarda
        status = 500
        logger.exception("unhandled_error", extra={"endpoint": endpoint})
        raise
    finally:
        elapsed = time.perf_counter() - start
        REQUEST_LATENCY.labels(method=method, endpoint=endpoint).observe(elapsed)

    REQUEST_COUNT.labels(method=method, endpoint=endpoint, status=status).inc()
    logger.info(
        "request_handled",
        extra={
            "method": method,
            "endpoint": endpoint,
            "status": status,
            "duration_ms": round(elapsed * 1000, 2),
        },
    )
    return response


@app.get("/")
def root():
    return {"service": "observability-lab-api", "status": "ok"}


@app.get("/healthz")
def healthz():
    """Liveness probe — o processo está vivo."""
    return {"status": "alive"}


@app.get("/readyz")
def readyz():
    """Readiness probe — o serviço está pronto para receber tráfego."""
    return {"status": "ready"}


@app.get("/metrics")
def metrics():
    """Exposição das métricas no formato Prometheus."""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/work")
def work():
    """Simula processamento com latência variável (popula o histograma)."""
    delay = random.uniform(0.01, 0.4)
    time.sleep(delay)
    return {"work": "done", "latency_ms": round(delay * 1000, 2)}


@app.get("/error")
def error():
    """Falha de propósito ~30% das vezes (alimenta a métrica de erros/alertas)."""
    if random.random() < 0.3:
        logger.warning("simulated_error", extra={"endpoint": "/error"})
        raise HTTPException(status_code=500, detail="Erro simulado para o lab")
    return {"status": "ok"}
