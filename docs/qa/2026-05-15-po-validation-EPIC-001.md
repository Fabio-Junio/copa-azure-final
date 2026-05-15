# @po Validation — EPIC-001 (VM→PaaS Workshop) — Freshness Audit

> **Validator:** Pax (@po) · **Date:** 2026-05-15 · **Trigger:** ativação do EPIC-001 (2026-05-15)
> **Scope:** stories 1.1, 1.2, 1.3, 1.4 vs estado atual do app pós-lote 2026-05-08 (Story 0.10)

---

## Veredito: 🔴 NO-GO pendente fixes (defeito sistêmico de dados stale)

Estrutura mecânica **íntegra** — todos os 10 artefatos referenciados existem e são válidos. Mas as stories foram rascunhadas em 2026-05-07 (estado do bacpac antigo) e **hardcodam contagens de dados que mudaram** no lote de 05-08. Rodar o dry-run hoje **falharia o SC-2** (smoke test: login + listar jogos + comprar) por asserções de contagem erradas.

### Checklist 10 pontos (resumo)

| # | Critério | Resultado |
|---|---|---|
| 1 | Story bem formada (As a/I want/So that) | ✅ 4/4 |
| 2 | ACs verificáveis | ⚠️ verificáveis mas com **valores stale** |
| 3 | Tasks executáveis | ✅ |
| 4 | Artefatos referenciados existem | ✅ 10/10 (ver anexo) |
| 5 | Dependências entre stories corretas | ✅ S1→S2→S3→S4 |
| 6 | Smoke test definido | ⚠️ definido mas com **números errados** |
| 7 | Rollback presente | ✅ 4/4 |
| 8 | Custo estimado | ✅ ($90 VMs → $18 PaaS) |
| 9 | Sem invenção (Art. IV) | ✅ |
| 10 | Pronto para dry-run | 🔴 **NÃO** — bloqueado pelos itens abaixo |

---

## Artefatos referenciados — todos OK (10/10)

`DEPLOY_IIS_SIMPLIFICADO.md`, `fifa2026-api/.env.example`, `fifa2026-api/database/schema.sql`, `DEPLOY.md`, `infra/main.bicep`, `infra/modules/sql-database.bicep`, `infra/provision.sh`, `.github/workflows/deploy-backend.yml`, `.github/workflows/deploy-frontend.yml`, `scripts/set-backend-url.mjs`.

---

## Defeitos bloqueantes (fix obrigatório antes do dry-run)

### D1 — Contagens de dados stale (CRÍTICO, sistêmico)

Valores cravados nas stories vs realidade verificada em prod (2026-05-15):

| Entidade | Stories dizem | Real (prod / bacpac regenerado) |
|---|---|---|
| matches | **12** | **104** |
| stadiums | **9** | **17** |
| teams/seleções | **16** | **49** |
| users | **10** | **≈10.000** (seed 05-08) |
| purchases | **18** | **≈100.000** (seed 05-08) |
| ticket_categories | **84** | por-jogo — confirmar via query no bacpac regenerado |

**Ocorrências (corrigidas nesta sessão):**
- `1.1.story.md:95` "12 jogos do bacpac" · `:139` `.matches.Count # 12`
- `1.3.story.md:97` "12 jogos" · `:143` `# 12`
- `1.4.story.md:40` (AC-3 lista completa) · `:120` "16/9/12/84/10/18" · `:197` `# 12` · `:208` `total_matches:12,total_stadiums:9`

### D2 — Credencial admin não confirmada (CRÍTICO, dependência externa)

Todas as 4 stories usam `admin@fifa2026.com / admin123` no smoke. O seed de 05-08 (`6ae6b9f` 10k users, `7fa8b48` status convention) **pode** ter alterado/recriado a conta admin. **Não verificável sem acesso ao DB** (credencial fora do contexto do agente por política de secrets). → **Gate:** o owner confirma esse login durante o passo de export do bacpac (quando tem acesso ao DB) e reporta. Se mudou, atualizar as 4 stories + seed doc.

### D3 — Bacpac stale (CRÍTICO, em resolução)

`FIFA2026Tickets.bacpac` (12 KB, 2026-05-07) não reflete o seed/migrations de 05-08. **Em resolução:** decisão do owner = regenerar do Azure SQL live (runbook entregue; SqlPackage já instalado; passos com credencial são do owner).

---

## Defeitos não-bloqueantes

### D4 — ~~Inconsistência de naming de Resource Group~~ → RETIRADO (não é defeito)

**Reavaliado 2026-05-15:** falso positivo. O esquema de RG nas 4 stories é **intencional e internamente consistente**:

- `fifa2026-vm-rg` — as 3 VMs (criado em 1.1; `az group delete` em bloco na 1.4 → cleanup limpo)
- `fifa2026-paas-rg` — recursos PaaS (web apps + Azure SQL, criados em 1.2/1.3/1.4)

A comparação original era inválida: `fifa2026-rg` é o RG da prod **real** (EPIC-000); o workshop é o aluno construindo o **próprio** ambiente do zero — ele nunca toca o `fifa2026-rg`. Forçar `fifa2026-rg` nas stories seria **errado** (conflataria o sandbox do aluno com a prod real e quebraria a didática VM-RG vs PaaS-RG). Nenhuma ação — esquema mantido como está.

---

## Decisão & próximos passos

1. **Fixes D1 aplicados nesta sessão** (12→104, 9→17, 16→49, listas de validação reescritas referenciando o bacpac regenerado). Volumes voláteis (users/purchases/categories) expressos como "confirmar via validação pós-import" — fonte da verdade = bacpac regenerado.
2. **D2:** owner verifica credencial admin no passo de export → reporta. **Gate para GO.**
3. **D3:** owner regenera bacpac (runbook entregue). Após isso: validar contagens reais e fixar os volumes voláteis nas stories.
4. **Re-validação @po** após D2+D3 → se GO, agendar **dry-run cronometrado** (SC-1: 4 stories no tempo do evento).
