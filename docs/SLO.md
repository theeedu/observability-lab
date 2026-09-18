# SLIs, SLOs e Alertas

Este documento define os indicadores e objetivos de nível de serviço da API do lab e como os alertas se relacionam a eles.

## Conceitos

- **SLI (Service Level Indicator):** uma métrica que mede um aspecto da qualidade do serviço.
- **SLO (Service Level Objective):** a meta para um SLI ao longo de uma janela de tempo.
- **Error budget:** o quanto o serviço pode falhar sem violar o SLO (`100% − SLO`).

## SLIs e SLOs definidos

| SLI | Definição | SLO |
|-----|-----------|-----|
| **Disponibilidade** | % de requisições sem erro 5xx | ≥ 99% (janela de 30 dias) |
| **Latência** | % de requisições com p95 abaixo de 500ms | ≥ 95% |
| **Health dos targets** | Alvos de scrape acessíveis | 100% |

### Error budget

Com SLO de disponibilidade de **99%**, o error budget é de **1%** das requisições. Se o consumo do budget acelerar (muitos 5xx em pouco tempo), o alerta `HighErrorRate` dispara antes que o SLO mensal seja comprometido.

## Alertas (definidos em `stack/prometheus/rules.yml`)

| Alerta | Condição | Severidade | Relação com SLO |
|--------|----------|-----------|-----------------|
| **HighErrorRate** | Taxa de 5xx > 5% por 2min | warning | Protege o SLO de disponibilidade |
| **HighLatencyP95** | p95 > 500ms por 5min | warning | Protege o SLO de latência |
| **TargetDown** | `up == 0` por 1min | critical | Sem coleta = sem visibilidade |

## Consultas (PromQL) de referência

**Disponibilidade (taxa de sucesso, últimos 5min):**
```promql
sum(rate(http_requests_total{service="api",status!~"5.."}[5m]))
/
sum(rate(http_requests_total{service="api"}[5m]))
```

**Latência p95:**
```promql
histogram_quantile(
  0.95,
  sum(rate(http_request_duration_seconds_bucket{service="api"}[5m])) by (le)
)
```

**Taxa de erro:**
```promql
sum(rate(http_requests_total{service="api",status=~"5.."}[5m]))
/
sum(rate(http_requests_total{service="api"}[5m]))
```

## Como observar na prática

1. Suba a stack (`make up`) e gere carga (`make load`).
2. No Grafana, abra o dashboard **RED Metrics** para ver os SLIs em tempo real.
3. O endpoint `/error` da API falha ~30% das vezes de propósito — o suficiente para o `HighErrorRate` disparar. Verifique em http://localhost:9093 (Alertmanager) e http://localhost:9091/alerts (Prometheus).
