# Arquitetura

## Visão geral

O lab é composto por duas camadas: a **aplicação** (que é observada) e a **plataforma de observabilidade** (que observa). Tudo roda em containers na mesma rede Docker e é orquestrado pelo Docker Compose.

## Componentes

| Componente | Papel | Tecnologia |
|-----------|-------|-----------|
| **API** | Serviço web instrumentado, expõe métricas e logs | FastAPI (Python) |
| **Worker** | Gera carga contínua contra a API e expõe suas próprias métricas | Go |
| **Prometheus** | Coleta (scrape) métricas e avalia regras de alerta | Prometheus |
| **Alertmanager** | Recebe e roteia alertas disparados pelo Prometheus | Alertmanager |
| **Loki** | Armazena e indexa logs | Loki |
| **Promtail** | Descobre containers e envia seus logs ao Loki | Promtail |
| **Grafana** | Visualiza métricas e logs em dashboards | Grafana |

## Fluxo de dados

1. O **Worker** faz requisições HTTP periódicas à **API** (a cada 3s por padrão), gerando tráfego realista — inclusive erros propositais.
2. A **API** registra cada requisição em **métricas RED** (expostas em `/metrics`) e emite **logs estruturados em JSON** no stdout.
3. O **Prometheus** faz *scrape* das métricas da API e do Worker a cada 5s e avalia as **regras de alerta**.
4. Quando uma regra dispara, o **Prometheus** envia o alerta ao **Alertmanager**.
5. O **Promtail** lê os logs dos containers (via socket do Docker) e os envia ao **Loki**.
6. O **Grafana** consulta Prometheus (métricas) e Loki (logs) e os apresenta em dashboards provisionados.

## Decisões de arquitetura

- **Zero dependência externa:** todo armazenamento (Prometheus TSDB, Loki filesystem, Grafana) é local. Nada de S3, nuvem ou serviços pagos — o lab roda offline.
- **Provisionamento como código:** datasources e dashboards do Grafana são versionados e carregados automaticamente. Nenhuma configuração manual pela UI.
- **Separação IaC × orquestração:** o Terraform (`infra/`) modela a camada de infraestrutura (rede + volumes) declarativamente; o Compose cuida do ciclo de vida dos containers. É uma escolha didática para demonstrar Terraform sem duplicar a orquestração.
- **Método RED:** a instrumentação segue Rate/Errors/Duration, padrão para serviços de request/response — simples de entender e suficiente para SLOs de disponibilidade e latência.
- **Segurança de container:** imagens multi-stage, execução com usuário non-root e healthchecks nativos.

## Portas expostas

| Porta | Serviço |
|-------|---------|
| 8000 | API |
| 9100 | Worker (métricas) |
| 9091 → 9090 | Prometheus (host → container) |
| 9093 | Alertmanager |
| 3100 | Loki |
| 3000 | Grafana |
