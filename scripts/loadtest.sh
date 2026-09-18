#!/usr/bin/env bash
# =========================================================================== #
# loadtest.sh — gera carga sintética contra a API para popular os dashboards.
# O worker já gera tráfego contínuo; este script serve para picos manuais.
#
# Uso:
#   ./scripts/loadtest.sh [TOTAL_REQUESTS] [CONCURRENCY]
# Exemplo:
#   ./scripts/loadtest.sh 500 20
# =========================================================================== #
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"
TOTAL="${1:-300}"
CONCURRENCY="${2:-10}"
ENDPOINTS=("/work" "/error" "/")

echo "==> Disparando ${TOTAL} requisições (concorrência ${CONCURRENCY}) contra ${BASE_URL}"

# Função que faz uma requisição a um endpoint aleatório
hit() {
  local ep="${ENDPOINTS[$((RANDOM % ${#ENDPOINTS[@]}))]}"
  curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${BASE_URL}${ep}" || echo "ERR"
}
export -f hit
export BASE_URL
export ENDPOINTS

# Dispara em paralelo respeitando a concorrência
seq "$TOTAL" | xargs -P "$CONCURRENCY" -I {} bash -c 'hit >/dev/null'

echo "==> Concluído. Veja os resultados em:"
echo "    Grafana    -> http://localhost:3000 (dashboard 'RED Metrics')"
echo "    Prometheus -> http://localhost:9090/graph"
