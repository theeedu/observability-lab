# syntax=docker/dockerfile:1
# --------------------------------------------------------------------------- #
# API (FastAPI) — imagem multi-stage, non-root, enxuta
# --------------------------------------------------------------------------- #
FROM python:3.12-slim AS base

# Boas práticas: não gerar .pyc, saída sem buffer, sem cache do pip
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# Usuário sem privilégios
RUN useradd --create-home --uid 10001 appuser
USER appuser

EXPOSE 8000

# Healthcheck nativo do container
HEALTHCHECK --interval=15s --timeout=3s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://localhost:8000/healthz').status==200 else 1)"

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
