# Runbook de Operação

Guia prático para operar o lab e responder a incidentes simulados.

## Operação básica

| Ação | Comando |
|------|---------|
| Subir a stack | `make up` |
| Derrubar (mantém dados) | `make down` |
| Derrubar e limpar dados | `make clean` |
| Ver estado dos serviços | `make ps` |
| Seguir logs | `make logs` |
| Checar saúde | `make health` |
| Gerar carga | `make load` |

## Verificação pós-deploy

Depois de `make up`, aguarde ~15s e rode:

```bash
make health
```

Todos os serviços devem reportar `[OK]`. Se algum estiver `[FAIL]`, a stack pode ainda estar inicializando — aguarde e repita.

---

## Playbooks de incidente

### 🔴 Alerta: `TargetDown`

**Sintoma:** Prometheus não consegue coletar métricas de um alvo (`up == 0`).

**Diagnóstico:**
```bash
make ps                         # o container do serviço está de pé?
docker compose logs <serviço>   # há erro no startup?
curl http://localhost:9090/targets   # estado dos targets no Prometheus
```

**Resolução:**
- Se o container caiu: `docker compose up -d <serviço>`.
- Se está de pé mas inacessível: verifique a porta/rede e o endpoint `/metrics` do serviço.

---

### 🟡 Alerta: `HighErrorRate` (taxa de 5xx > 5%)

**Sintoma:** a API está retornando muitos erros 5xx.

**Diagnóstico:**
```bash
# Logs de erro da API (via Loki, no Grafana → Explore):
{container="obs-api"} | json | level="warning"
```
No dashboard **RED Metrics**, observe o painel *Errors* e correlacione com o horário.

**Contexto do lab:** o endpoint `/error` falha ~30% das vezes de propósito — este alerta é esperado ao gerar carga. Em um cenário real, investigaria dependências, deploy recente e saturação de recursos.

---

### 🟡 Alerta: `HighLatencyP95` (p95 > 500ms)

**Sintoma:** as requisições estão lentas.

**Diagnóstico:**
- Painel *Duration* no dashboard: veja se p95/p99 subiram juntos (degradação geral) ou só p99 (cauda).
- Verifique carga (`worker_jobs_total`) e recursos dos containers (`docker stats`).

**Contexto do lab:** o endpoint `/work` tem latência artificial de 10–400ms. Picos de carga (`make load`) elevam o p95 naturalmente.

---

## Troubleshooting comum

**Grafana não mostra dados**
- Confirme os datasources em http://localhost:3000/connections/datasources (Prometheus e Loki devem estar "OK").
- Confirme que o Prometheus está coletando: http://localhost:9090/targets.

**Loki sem logs**
- O Promtail precisa de acesso ao socket do Docker (`/var/run/docker.sock`) — já mapeado no compose.
- Só containers com a label `logging=promtail` são coletados (API e Worker).

**Porta já em uso**
- Ajuste o mapeamento de portas no `docker-compose.yml` se 3000/8000/9090 já estiverem ocupadas na sua máquina.

**Resetar tudo do zero**
```bash
make clean && make up
```
