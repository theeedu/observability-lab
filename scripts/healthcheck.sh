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
  "Prometheus|http://localhost:9090/-/healthy"
  "Grafana|http://localhost:3000/api/health"
  "Alertmanager|http://localhost:9093/-/healthy"
  "Loki|http://localhost:3100/ready"
  "Worker (metrics)|http://localhost:9100/metrics"
)

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

echo ""
if [[ "$fail" -eq 0 ]]; then
  echo -e "${GREEN}Todos os serviços estão saudáveis.${NC}"
else
  echo -e "${RED}Um ou mais serviços estão indisponíveis.${NC}"
  echo "Dica: a stack pode ainda estar inicializando. Rode 'make ps' e tente de novo."
fi
exit "$fail"
