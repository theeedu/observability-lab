#!/usr/bin/env bash
# =========================================================================== #
# healthcheck.sh — verifica a saúde de todos os serviços da stack.
# Uso: ./scripts/healthcheck.sh
# Sai com código != 0 se algum serviço essencial estiver fora do ar.
# =========================================================================== #
set -euo pipefail

# Serviço -> URL de health (formato "nome|url")
CHECKS=(
  "API (liveness)|http://localhost:8000/healthz"
  "API (readiness)|http://localhost:8000/readyz"
  "API (metrics)|http://localhost:8000/metrics"
  "Prometheus|http://localhost:9091/-/healthy"
  "Grafana|http://localhost:3000/api/health"
  "Alertmanager|http://localhost:9093/-/healthy"
)

# Loki: verificado via API de consulta (o /ready pode não existir nesta versão).
# Worker: não expõe porta no host (só rede interna); é verificado via Prometheus.

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
fail=0

echo "==> Verificando saúde da stack..."
for entry in "${CHECKS[@]}"; do
  name="${entry%%|*}"
  url="${entry##*|}"
  if curl -fsS --max-time 5 "$url" >/dev/null 2>&1; then
    printf "  [${GREEN}OK${NC}]   %-20s %s\n" "$name" "$url"
  else
    printf "  [${RED}FAIL${NC}] %-20s %s\n" "$name" "$url"
    fail=1
  fi
done

# Loki — testado via API de consulta (retorna 200 quando operante)
loki_url="http://localhost:3100/loki/api/v1/query_range?query=%7Bjob%3D%22docker%22%7D&limit=1"
if curl -fsS --max-time 5 "$loki_url" >/dev/null 2>&1; then
  printf "  [${GREEN}OK${NC}]   %-20s %s\n" "Loki (query API)" "http://localhost:3100"
else
  printf "  [${RED}FAIL${NC}] %-20s %s\n" "Loki (query API)" "http://localhost:3100"
  fail=1
fi

# Worker — não expõe porta no host; verificamos via target do Prometheus
if curl -fsS --max-time 5 "http://localhost:9091/api/v1/targets" 2>/dev/null \
    | grep -q '"job":"worker".*"health":"up"\|"health":"up".*"job":"worker"'; then
  printf "  [${GREEN}OK${NC}]   %-20s %s\n" "Worker (via Prom)" "target up"
else
  # fallback: considera OK se o container está rodando
  if docker ps --filter "name=obs-worker" --filter "status=running" --format '{{.Names}}' 2>/dev/null | grep -q obs-worker; then
    printf "  [${GREEN}OK${NC}]   %-20s %s\n" "Worker (container)" "running"
  else
    printf "  [${RED}FAIL${NC}] %-20s %s\n" "Worker" "não está rodando"
    fail=1
  fi
fi

echo ""
if [[ "$fail" -eq 0 ]]; then
  echo -e "${GREEN}Todos os serviços estão saudáveis.${NC}"
else
  echo -e "${RED}Um ou mais serviços estão indisponíveis.${NC}"
  echo "Dica: a stack pode ainda estar inicializando. Rode 'make ps' e tente de novo."
fi
exit "$fail"
