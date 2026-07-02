# Guia do Aluno — A Grande Final (F5/F6: Chatbot MCP + Flow Visualizer) do zero

> **O que você vai construir nesta aula:** as duas últimas fases do FIFA 2026 Tickets, numa **única sessão** de 4 blocos:
> - **Bloco 1 (F5):** um **McpServer** (7 ferramentas read-only) atrás do gateway YARP + um **chatbot Gemini** que consulta o estado REAL da Copa por conversa natural. A regra de ouro — "o chatbot nunca escreve no banco" — passa a valer **por construção**, não por roteamento.
> - **Bloco 2 (F6):** o serviço **FlowEvents** (SignalR + Log Analytics) + o **Flow Visualizer** do frontend, onde uma compra real acende **5 nós** animados, rastreados de ponta a ponta por `correlationId`.
>
> **Importante (leia antes de começar):**
> - Este lab **assume que você já concluiu as Quartas de Final** (gateway YARP no ar, identidade CIAM + admin workforce, backend v1, SQL). A Final **ADICIONA** dois microsserviços novos ao mesmo ambiente — **não** recria o gateway nem a identidade.
> - **Cada aluno cria TUDO no próprio Azure / GitHub**: seus recursos, com **seus próprios nomes**. Os valores deste guia são **genéricos** (`<sufixo>`, `<seu-rg>`, `<gateway-fqdn>`) — preencha os seus.
> - **O fork NÃO é o passo zero.** A infra dos serviços novos é criada **à mão** no Portal; o **fork + GitHub Actions é o ÚLTIMO passo de deploy** ([Bloco 3](#bloco-3--entrega-retrospectiva-e-encerramento)).

> ⚠️ **A regra de ouro do dia:** no F5 o chatbot só tem **sentidos** (7 tools de leitura). Ele **não consegue** executar nenhuma ação — não existe uma ferramenta de escrita para o LLM chamar. Você vai **ver isso ao vivo** na [Fase 5](#fase-5--a-regra-de-ouro-ao-vivo-o-momento-central-do-bloco).

> **Referências:** Story [3.3](../stories/3.3.story.md) · [3.4](../stories/3.4.story.md) · [ADE-008 (re-arquitetura da Final)](../architecture/) · [ADE-004 (gateway issuer-agnóstico)](../architecture/) · Guia das Quartas [`quartas-f2-portal-guide.md`](./quartas-f2-portal-guide.md) · Workflow `lab-a-final.yml`

---

# Bloco 0 — Abertura

## O que muda em relação às Quartas

| | **Quartas (F2/F3)** | **A Final (F5/F6)** |
|---|---|---|
| Gateway YARP | você criou | **reusado sem mudança de infra** (só rebuild do código para pegar o hardening) |
| Identidade CIAM + admin | você criou | reusada |
| Backend v1 / SQL | reusado | reusado |
| **McpServer** (7 tools read-only) | — | **NOVO** — Container App **interno**, atrás do gateway |
| **Chatbot Gemini** | — | **NOVO** — no frontend, chave no **proxy server-side** |
| **FlowEvents** (SignalR + Kusto) | — | **NOVO** — Container App + Azure SignalR + Managed Identity |
| **Flow Visualizer** (`/flow`) | — | **NOVO** — 5 nós animados por `correlationId` |

> 🟢 **Retro-compatibilidade:** nada das Quartas deixa de funcionar. A compra continua a mesma; a Final só **acrescenta** observação (chatbot que lê + visualizador que mostra). A notificação pós-compra passou a ser **inline** (dentro da Function Consumer), sem orquestração externa.

## Como as peças se encaixam

```
        VOCÊ (Portal Azure — à mão)                       SEU FORK (GitHub Actions)
        ───────────────────────────                       ─────────────────────────
  ┌──────────────────────────────────────────────┐
  │  Reusa das Quartas:                           │
  │    ACR · Container Apps Environment (CAE)      │
  │    Gateway YARP · SQL · Frontend Web App       │
  │                                                │
  │  CRIA novo para a Final:                       │
  │    F5 → Container App McpServer (INTERNO)       │ ──┐  (você cria vazio)
  │    F6 → Container App FlowEvents (externo)      │   │
  │         + Azure SignalR (Free) + Managed Ident.│   │
  │  + App Settings novas no gateway               │   │
  └──────────────────────────────────────────────┘   │
                                                       ▼
                     ┌───────────────────────────────────────────────┐
                     │  Workflow ÚNICO "Lab A Final" (lab-a-final.yml) │
                     │  input `acao`:                                 │
                     │    mcp-server → build+deploy do McpServer       │
                     │    flow-events→ build+deploy do FlowEvents       │
                     │    gateway    → rebuild do gateway (hardening)   │
                     │    frontend   → chatbot + /flow embutidos        │
                     │    tudo       → tudo acima, em ordem             │
                     └───────────────────────────────────────────────┘
```

**Fluxo em runtime (F5):** front → `POST {gateway}/mcp` (Bearer CIAM) → gateway injeta `X-Entra-OID` + `X-Gateway-Key` → **McpServer** (`tools/list`, `tools/call`) → `SELECT` no SQL. A chave Gemini fica no **proxy** (`{gateway}/llm/gemini/...`), nunca no browser.

**Fluxo em runtime (F6):** compra atravessa Gateway YARP → Function Entry → Service Bus → Function Consumer → SQL; cada hop emite um trace com `correlationId`; o **FlowEvents** lê os traces (Kusto) e empurra por **SignalR** para a rota `/flow`, acendendo os 5 nós.

> A regra de ouro da arquitetura: **o Portal cria os recursos vazios; os Actions só publicam código.** Nenhum recurso Azure é criado pelo workflow.

## Convenção de nomes (preencha a SUA)

Reuse os recursos das Quartas e crie os **novos** da Final. Anote os **seus** valores — todas as fases referenciam estes placeholders.

| Recurso | Convenção sugerida | Seu valor |
|---|---|---|
| Resource Group | `<seu-rg>` (reuse das Quartas) | ____________ |
| Container Registry (ACR) | `cr<sufixo>.azurecr.io` (reuse) | ____________ |
| Container Apps Environment | `cae-<sufixo>` (reuse) | ____________ |
| Container App (gateway) | `ca-gateway-<sufixo>` (reuse) | ____________ |
| FQDN do gateway | `<gateway-fqdn>` (das Quartas) | ____________ |
| Frontend Web App | `<seu-frontend>` → `https://<seu-frontend>.azurewebsites.net` (reuse) | ____________ |
| SQL Server / DB | `<seu-sql-server>` / `FIFA2026Tickets` (reuse) | ____________ |
| **Container App (McpServer)** | `ca-mcp-<sufixo>` — **NOVO, ingress interno** | ____________ |
| FQDN interno do McpServer | `<mcp-fqdn>` (gerado; termina em `.internal.<domínio-do-cae>`) | ____________ |
| **Container App (FlowEvents)** | `ca-flow-<sufixo>` — **NOVO** | ____________ |
| FQDN do FlowEvents | `<flow-fqdn>` (gerado) | ____________ |
| **Azure SignalR** | `signalr-<sufixo>` — **NOVO, tier Free** | ____________ |
| **Log Analytics Workspace** | reuse o das fases anteriores (App Insights) | ____________ |
| Workspace ID (GUID) do Log Analytics | `<workspace-id>` | ____________ |

> 💡 **Um único segredo de gateway (`X-Gateway-Key`):** você já gerou um `Gateway__AdminSharedSecret` nas Quartas. **Reuse exatamente o mesmo valor** aqui — ele agora também protege o hop gateway→McpServer (ver [Fase 1.4](#14-app-settings-do-gateway-mcpserverurl--trava-x-gateway-key)). Se não tiver anotado, gere um novo (`openssl rand -hex 24`) e reaplique em TODOS os serviços confiáveis.

## Pré-requisitos (checklist de entrada)

- [ ] Ambiente das **Quartas no ar**: gateway YARP responde `GET /health` = 200; login CIAM funciona; compra v2 grava em `purchases`.
- [ ] ACR (`cr<sufixo>`) e o Container Apps Environment (`cae-<sufixo>`) existentes.
- [ ] **Chave Gemini** pronta (`GEMINI_API_KEY`) — se ainda não tem, faça o [Apêndice A](#apêndice-a--chave-gemini-aistudio). Modelo do lab: **`gemini-2.5-flash`** (ver [Apêndice B](#apêndice-b--modelo-gemini-real-vs-comentário)).
- [ ] O valor do `Gateway__AdminSharedSecret` das Quartas anotado (ou um novo gerado).
- [ ] Fork NOVO do repo do evento com **TODAS as branches** (a branch do lab é `lab-a-final`; ver [Bloco 3](#bloco-3--entrega-retrospectiva-e-encerramento)).

---

# Bloco 1 — F5: McpServer (7 sentidos) + chatbot Gemini

> **Objetivo do bloco:** implantar o McpServer atrás do gateway, plugar o chatbot Gemini via proxy server-side, provar que só existem 7 ferramentas de **leitura**, e demonstrar ao vivo que **não há ferramenta de ação**.

## Fase 1 — Deploy do McpServer (Container App, ingress INTERNO)

O McpServer é um microsserviço .NET 8 que expõe o endpoint **`/mcp`** (Streamable HTTP, JSON-RPC 2.0 pelo SDK oficial). Ele fica **atrás do gateway** — o browser **nunca** o chama direto. O gateway valida o Bearer Entra, injeta `X-Entra-OID` (identidade) e `X-Gateway-Key` (prova de origem), e roteia `/mcp` e `/llm/**` para ele.

### 1.1 Criar o Container App do McpServer (imagem placeholder)

Tudo no **[portal.azure.com](https://portal.azure.com)**, na `<sua-subscription>` / `<seu-rg>`.

1. Busca do topo → **Container Apps → `+ Create`**.
2. **Basics:** **Container app name** `ca-mcp-<sufixo>` · **Environment** `cae-<sufixo>` (o MESMO do gateway) → **Next: Container**.
3. **Container:** mantenha **Use quickstart image** (o ACR real vem pelo Actions) · CPU/memória no menor preset → **Next: Ingress**.
4. **Ingress:** **Enabled** · **Ingress traffic** = **`Limited to Container Apps Environment`** (⚠️ **INTERNO** — só o gateway, dentro do mesmo CAE, alcança) · **Target port** = **`8080`**.
5. **Review + create → Create → Go to resource**.
6. Na **Overview**, copie a **Application Url** — é o seu `<mcp-fqdn>` (um host `*.internal.<região>.azurecontainerapps.io`). É o valor da App Setting `McpServerUrl` do gateway (Fase 1.4).

> ⚠️ **Ingress INTERNO é o ponto de segurança do bloco:** o McpServer não tem endereço público. Só o gateway (mesmo CAE) fala com ele — e só com o `X-Gateway-Key` correto. **Target port = 8080** é obrigatório (`Dockerfile`: `EXPOSE 8080` + `ASPNETCORE_URLS=http://+:8080`); qualquer outra porta = 502.

### 1.2 Conectar o ACR

1. No Container App `ca-mcp-<sufixo>` → **Settings → Registries → `+ Add`** → **Registry** = `cr<sufixo>.azurecr.io` → **Authentication** = **Admin Credentials** → **Save**.

### 1.3 App Settings do McpServer

O McpServer precisa da connection string do SQL, da chave Gemini (que o **proxy** injeta server-side) e do segredo do gateway. No Container App: **Application → Containers → `Edit and deploy`** → selecione o container → aba **Environment variables** → adicione (Source = **Manual entry**, ou **Reference a secret** para os sensíveis) → **Save → Create**:

| App Setting | Valor | Papel |
|---|---|---|
| `SqlConnectionString` | connection string ADO.NET do `FIFA2026Tickets` | as 7 tools fazem `SELECT` parametrizado (Dapper) |
| `GEMINI_API_KEY` | sua chave Gemini | injetada pelo **proxy** (`/llm/gemini/...`) — NUNCA no bundle |
| `GATEWAY_SHARED_SECRET` | **mesmo** valor do `Gateway__AdminSharedSecret` das Quartas | trava `X-Gateway-Key`: só aceita requests que passaram pelo gateway. **Aqui = manual**; alternativamente o job `mcp-server` do `lab-a-final.yml` o aplica como *secretref* (Secret `GATEWAY_SHARED_SECRET` da [Fase 8](#fase-8--variables--secrets-consolidados-fork)) — use **um** dos dois caminhos |

> 🔒 **Chave Gemini no server-side:** o frontend só conhece a URL do **proxy** (`VITE_LLM_PROXY_URL` = o gateway). O McpServer expõe `/llm/{provider}/{*path}`, injeta a `GEMINI_API_KEY` como header e encaminha ao endpoint oficial. Assim a key **nunca** vai para o browser — o próprio workflow tem um guard que falha se qualquer key vazar no bundle.
> 🟢 **Opcionais (fallback/portabilidade):** se quiser oferecer outros provedores, o McpServer também lê `GROQ_API_KEY` e `MISTRAL_API_KEY`. Para o lab, só a Gemini basta.

### 1.4 App Settings do gateway (`McpServerUrl` + trava `X-Gateway-Key`)

O gateway já roteia para o McpServer — o `McpServerDestinationConfigFilter` **já existe** no `Program.cs` (Story 2.5, reusado sem mudança). Você só precisa dar a URL real e garantir o segredo. No Container App do **gateway** (`ca-gateway-<sufixo>`) → **Environment variables**:

| App Setting | Valor | Papel |
|---|---|---|
| `McpServerUrl` | `https://<mcp-fqdn>` (Application Url da Fase 1.1) | o filtro sobrescreve a destination do cluster `mcp-server` |
| `Gateway__AdminSharedSecret` | **mesmo** valor da Fase 1.3 (já configurado nas Quartas) | injetado como `X-Gateway-Key` nos clusters confiáveis (`backend-v1`, `functions-f1`, **`mcp-server`**) |

> 🔒 **O P0 que a Final fecha:** a partir do hardening (Story 4.2 / ADE-009), o gateway injeta `X-Gateway-Key` também no cluster `mcp-server`. Um `curl` forjando `X-Entra-OID` direto no McpServer **não tem** o segredo e é rejeitado (401); via gateway, a request carrega o segredo real. Por isso é preciso **rebuildar o gateway** a partir da branch `lab-a-final` (Fase 1.6, `acao=gateway`) — a imagem das Quartas ainda não tinha o `mcp-server` no conjunto confiável.
> 🔒 **Duplo underscore:** `Gateway:AdminSharedSecret` na config .NET vira `Gateway__AdminSharedSecret` em env var. Vazio no repo = injeção desligada (retro-compat com labs sem gateway).

### 1.5 Variables/Secrets do frontend para o chatbot

No **seu fork** → **Settings → Secrets and variables → Actions**, garanta (nomes fixos; valores seus):

| Nome | Tipo | Valor | Papel |
|---|---|---|---|
| `VITE_GATEWAY_V2_URL` | Variable | `https://<gateway-fqdn>` | base do gateway (rotas `/mcp`, `/llm`) |
| `VITE_LLM_PROXY_URL` | Variable | `https://<gateway-fqdn>` | base do proxy de LLM (= o gateway) |
| `VITE_LLM_PROVIDER` | Variable | `gemini` (default) | provider ativo do chatbot |
| `VITE_GEMINI_MODEL` *(opcional)* | Variable | `gemini-2.5-flash` | override do modelo; default do código já é `gemini-2.5-flash` |

> 📌 **Modelo real:** o runtime do `gemini.ts` usa **`gemini-2.5-flash`** (o comentário de cabeçalho do arquivo ainda cita `2.0-flash` — inconsistência conhecida e inofensiva; ver [Apêndice B](#apêndice-b--modelo-gemini-real-vs-comentário)). Não precisa mexer no código.

### 1.6 Deploy via GitHub Actions

Em **Actions → "Lab A Final" → Run workflow → branch `main`** (após o merge do PR do lab — ver [Bloco 3](#bloco-3--entrega-retrospectiva-e-encerramento)), variando o `acao`:

1. **`acao = mcp-server`** — `dotnet build/test` do McpServer, build & push da imagem no ACR (`cr<sufixo>.azurecr.io/mcp-server:<sha>`), `az containerapp update --image` (troca o placeholder) e aplica os App Settings sensíveis como secrets (`SqlConnectionString`, `GEMINI_API_KEY`, `GATEWAY_SHARED_SECRET`). Smoke `/health`.
2. **`acao = gateway`** — **rebuild do gateway** a partir de `lab-a-final` para pegar o hardening (`X-Gateway-Key` no cluster `mcp-server`). Troca a imagem do gateway; suas App Settings da Fase 1.4 permanecem.
3. **`acao = frontend`** — `npm ci` + `vite build` (com `VITE_LLM_PROXY_URL`, `VITE_LLM_PROVIDER`) + deploy. O job tem um **guard** que falha se alguma key de LLM aparecer no bundle.

> 🖱️ **Disparo manual apenas:** o workflow só tem `workflow_dispatch`. Antes do `frontend`, garanta **SCM Basic Auth `On`** no Web App do front e capture o publish profile **depois** disso.
> **Nota @devops:** confirmar/criar `lab-a-final.yml` antes da entrega, com os blocos `acao = mcp-server | flow-events | gateway | frontend | tudo`. Origem de cada bloco no repo atual: **`mcp-server`** ← `deploy-phase-05.yml`; **`flow-events`** ← `deploy-phase-06.yml`; **`gateway`** ← `deploy-phase-02.yml` (é lá que vive o deploy do gateway YARP — `deploy-phase-05/06.yml` **não** deployam o gateway nem têm input `acao`); e o **padrão de seletor `acao`** (`tudo`/por-etapa) ← `lab-quartas-de-final.yml`. Os nomes exatos das Variables/Secrets abaixo são a referência dos workflows atuais e podem ser normalizados no `lab-a-final.yml`.

### 1.7 Smoke do McpServer (via gateway)

```bash
GW="<gateway-fqdn>"
TOKEN="<access-token-CIAM>"   # cole um Bearer CIAM válido (login no front → DevTools)

# tools/list via gateway → tem de listar EXATAMENTE 7 tools, todas readOnly
curl -s -X POST "https://${GW}/mcp" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' \
  -i | tee mcp-tools.txt
# Espere: 7 tools em result.tools[]; NENHUM cabeçalho X-Cache: HIT (POST /mcp não é cacheado)
```

As **7 tools** que devem aparecer (todas read-only):

| Tool | O que consulta |
|---|---|
| `consultar_disponibilidade` | disponibilidade e preços de ingressos de uma partida |
| `verificar_ingresso` | se um ingresso/ID é válido + dados da compra |
| `consultar_bracket` | jogos de uma fase do mata-mata (oitavas…final) |
| `consultar_partidas` | partidas com filtros (time, fase, estádio, grupo, data) |
| `consultar_classificacao` | tabela de pontos de um grupo |
| `consultar_time` | dados de uma seleção (grupo, ranking FIFA, código) |
| `consultar_estadio` | dados de um estádio/sede (cidade, capacidade) |

✅ **Checkpoint (AC-2/AC-8):** `tools/list` = **7 tools, todas `readOnly: true`**; `POST /mcp` sem `X-Cache: HIT`; McpServer com ingress **interno** (não responde por URL pública).

## Fase 2 — Chatbot Gemini: conversando com o estado real da Copa

Com o McpServer no ar e o frontend deployado, abra o portal e o **chatbot**. Ele descobre as 7 tools via `tools/list` e deixa o **Gemini** decidir qual chamar (function calling, modo `AUTO`).

Faça pelo menos **3** perguntas em linguagem natural e observe a tool escolhida:

| Você pergunta | Tool que o Gemini chama | Dado real retornado |
|---|---|---|
| *"Quando o Brasil joga?"* | `consultar_partidas` | jogos do Brasil (com placar se já disputado) |
| *"Como está o grupo A?"* | `consultar_classificacao` | tabela de pontos do grupo A |
| *"Me fala do Maracanã"* | `consultar_estadio` | cidade, capacidade, descrição do estádio |

> 🔎 Cada resposta vem do **SQL real** (via `FifaQueryRepository`, só `SELECT`). O chatbot não inventa: ele lê o banco através das tools.

✅ **Checkpoint (AC-3):** ≥3 das 7 tools demonstradas em conversa natural, com dados reais do SQL.

## Fase 3 — (referência) Roteamento e cache

Nada a configurar aqui — é entendimento. O gateway roteia:
- `/mcp` → cluster `mcp-server` (o endpoint MCP);
- `/llm/{**}` → cluster `mcp-server` (o proxy de LLM que injeta a chave).

Requisições `POST` **não são cacheadas** (o fix de cache do gateway separou o cache de `GET` das chamadas MCP/LLM). O cache de borda (30s) roda **pós-autenticação** (hardening da Story 4.4): um HIT só é servido depois que o JWT é validado.

## Fase 4 — (referência) Identidade propagada

O gateway extrai o claim `oid` do token CIAM e injeta `X-Entra-OID` na request ao McpServer. As tools **leem** esse header apenas para **logging mascarado** — **nunca** revalidam o JWT (o gateway é o guardião único). É por isso que o McpServer pode ficar atrás do gateway sem reimplementar autenticação.

## Fase 5 — A regra de ouro AO VIVO (o momento central do bloco)

Este é o clímax didático do F5. O facilitador pede à turma que tente uma pergunta de **AÇÃO**:

> *"Cria um alerta pra mim quando abrir ingresso VIP."*

E a turma observa, junto: **o chatbot não tem essa ferramenta.** O `tools/list` só expõe 7 tools de **leitura** — não existe nenhuma tool de escrita para o Gemini chamar. Não há vetor de escrita **por construção**.

Pontos a reforçar em sala:
- A "mão" de ação (uma antiga tool de criar alerta) **foi removida** — o McpServer é só "sentidos".
- Não é preciso explicar roteamento por fila/webhook para provar a segurança: **basta olhar a lista de ferramentas**. O que não existe não pode ser chamado.
- ⚠️ **Nuance honesta:** o LLM pode até *responder em texto* algo como "ok, criei o alerta". Isso é **alucinação de texto**, não uma tool call real — **nenhuma escrita ocorre** no banco. Deixe isso explícito: a "promessa" no texto não é uma ação; o único jeito de escrever seria uma tool call, e ela não existe.

✅ **Checkpoint (AC-4/AC-9):** a turma vê que o chatbot não executa ações; o material não menciona nenhuma "mão"/tool de escrita.

---

# Bloco 2 — F6: FlowEvents + Flow Visualizer (5 nós)

> **Objetivo do bloco:** implantar o serviço FlowEvents (SignalR + consulta ao App Insights via Kusto) e o Flow Visualizer do frontend, e ver uma compra real atravessar **5 nós** animados, rastreados por `correlationId`.

## Fase 6 — Azure SignalR + Managed Identity

### 6.1 Criar o Azure SignalR (tier Free, modo Default)

1. Portal → **SignalR → `+ Create`**.
2. **Resource name** `signalr-<sufixo>` · **Region** a mesma do CAE · **Pricing tier** = **Free** (Free_F1, 20 conexões simultâneas — suficiente para o workshop).
3. **Review + create → Create → Go to resource**.
4. Em **Settings → Service Mode**, confirme **`Default`** (⚠️ **NÃO** `Serverless`) — o `FlowHub` é hospedado pelo próprio serviço FlowEvents (.NET, `AddAzureSignalR`), que exige o modo Default.
5. Em **Settings → CORS**, garanta que o **origin do frontend** (`https://<seu-frontend>.azurewebsites.net`) está permitido (o WebSocket do SignalR usa credentials — não pode ser `*`).
6. Em **Keys**, copie a **Connection String** — vira o segredo `PHASE06_SIGNALR_CONNECTION_STRING` do fork (Fase 8).

> 💡 IaC de referência (não obrigatório aplicar): [`infra/phase-06/signalr.bicep`](../../infra/phase-06/signalr.bicep) declara exatamente esse recurso (Free_F1, ServiceMode=Default, CORS restrito).

### 6.2 Criar o Container App do FlowEvents

1. Portal → **Container Apps → `+ Create`** → **Basics:** name `ca-flow-<sufixo>` · **Environment** `cae-<sufixo>` (o MESMO) → **Next: Container**.
2. **Container:** quickstart image (a real vem pelo Actions) → **Next: Ingress**.
3. **Ingress:** **Enabled** · **Ingress traffic** = **`Accepting traffic from anywhere`** · **Transport** = **`Auto`** (habilita WebSocket para o SignalR) · **Target port** = **`8080`**.
4. **Review + create → Create → Go to resource**. Anote a **Application Url** = `<flow-fqdn>`.
5. **Conectar o ACR:** **Settings → Registries → `+ Add`** → `cr<sufixo>.azurecr.io` → **Admin Credentials** → **Save**.

> 💡 IaC de referência: [`infra/phase-06/flow-events-containerapp.yaml`](../../infra/phase-06/flow-events-containerapp.yaml) (ingress external, transport auto, target port 8080, Managed Identity SystemAssigned, scale 0→2).

### 6.3 Managed Identity + role Log Analytics Reader

O FlowEvents consulta os traces via Kusto usando uma **Managed Identity**.

1. No `ca-flow-<sufixo>` → **Settings → Identity → System assigned** → **Status = On** → **Save**.
2. Vá ao **Log Analytics Workspace** (o que recebe a telemetria do App Insights) → **Access control (IAM) → `+ Add → Add role assignment`**.
3. **Role** = **`Log Analytics Reader`** · **Assign access to** = **Managed identity** → selecione a identidade do `ca-flow-<sufixo>` → **Review + assign**.
4. Anote o **Workspace ID** (GUID) do Log Analytics (Overview do workspace) → vira `PHASE06_LOG_ANALYTICS_WORKSPACE_ID` (Fase 8).

> ⚠️ Sem o papel **Log Analytics Reader**, o `LogsQueryClient` recebe **403** e os nós nunca acendem.

### 6.4 App Settings do FlowEvents

No `ca-flow-<sufixo>` → **Environment variables**:

| App Setting | Valor | Papel |
|---|---|---|
| `AzureSignalRConnectionString` | connection string do SignalR (Fase 6.1) | hospeda o FlowHub (secretref) |
| `LogAnalyticsWorkspaceId` | `<workspace-id>` (Fase 6.3) | qual workspace consultar (Kusto) |
| `FrontendOrigin` | `https://<seu-frontend>.azurewebsites.net` | CORS do SignalR (credentials → não pode ser `*`) |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` *(opcional)* | connection string do App Insights | telemetria de borda (no-op se ausente) |

> 🔒 **Nota de escopo (não confundir com o F5):** o cluster `flow-events` **NÃO** recebe o `X-Gateway-Key` (fica fora do escopo da ADE-009 Inv 1). Portanto **não** configure `GATEWAY_SHARED_SECRET` no FlowEvents — diferente do McpServer, que precisa dele.

## Fase 7 — Gateway (`FlowEventsUrl`) + frontend (`/flow`)

### 7.1 App Setting do gateway

O gateway já roteia FlowEvents — o `FlowEventsDestinationConfigFilter` **já existe** (Story 2.6, reusado). Só falta a URL real. No gateway `ca-gateway-<sufixo>` → **Environment variables**:

| App Setting | Valor | Papel |
|---|---|---|
| `FlowEventsUrl` | `https://<flow-fqdn>` (Fase 6.2) | o filtro sobrescreve a destination do cluster `flow-events` |

O gateway expõe duas rotas para o front:
- `/flow-events/api/{**}` → API do FlowEvents (`/api/flow/recent`, `/{id}`, `/{id}/replay`);
- `/flow-events/hubs/{**}` → o Hub SignalR (WebSocket).

O gateway continua o **NÓ ZERO**: injeta `X-Correlation-ID` (transform global) também nas requests ao FlowEvents.

### 7.2 Variable do frontend

No fork → **Variables**:

| Nome | Valor | Papel |
|---|---|---|
| `VITE_FLOW_EVENTS_BASE_URL` | `https://<gateway-fqdn>/flow-events` | base das rotas FlowEvents via gateway |

A rota **`/flow`** do frontend (lazy) monta o `FlowDiagram` (5 nós, `framer-motion`) e conecta ao Hub SignalR.

### 7.3 Deploy via Actions

Em **Actions → "Lab A Final" → Run workflow**:

1. **`acao = flow-events`** — `dotnet build/test` do FlowEvents, build & push da imagem (`cr<sufixo>.azurecr.io/flow-events:<sha>`), `az containerapp update --image` + aplica `AzureSignalRConnectionString` (secretref), `LogAnalyticsWorkspaceId`, `FrontendOrigin`. Smoke `/health`.
2. **`acao = gateway`** — se ainda não rebuildou no Bloco 1, faça agora (garante `FlowEventsUrl` sendo lido pela imagem atual).
3. **`acao = frontend`** — rebuild com `VITE_FLOW_EVENTS_BASE_URL` embutido → a rota `/flow` passa a conectar.

## Fase 8 — Variables + Secrets consolidados (fork)

Nomes **fixos**; valores **seus**. (Referência: `deploy-phase-05.yml` + `deploy-phase-06.yml`; o `lab-a-final.yml` pode normalizar — **Nota @devops**.)

### Variables

| Nome | Valor | Bloco |
|---|---|---|
| `ACR_LOGIN_SERVER` | `cr<sufixo>.azurecr.io` | F5 + F6 |
| `PHASE02_RESOURCE_GROUP` | `<seu-rg>` | F5 + F6 |
| `PHASE05_MCP_APP_NAME` | `ca-mcp-<sufixo>` | F5 |
| `PHASE06_FLOW_APP_NAME` | `ca-flow-<sufixo>` | F6 |
| `PHASE06_LOG_ANALYTICS_WORKSPACE_ID` | `<workspace-id>` | F6 |
| `PHASE06_FRONTEND_ORIGIN` | `https://<seu-frontend>.azurewebsites.net` | F6 |
| `FRONTEND_APP_NAME` | `<seu-frontend>` | F5 + F6 (frontend) |
| `VITE_GATEWAY_V2_URL` | `https://<gateway-fqdn>` | frontend |
| `VITE_LLM_PROXY_URL` | `https://<gateway-fqdn>` | frontend (chatbot) |
| `VITE_LLM_PROVIDER` | `gemini` | frontend (chatbot) |
| `VITE_GEMINI_MODEL` *(opcional)* | `gemini-2.5-flash` | frontend (chatbot) |
| `VITE_FLOW_EVENTS_BASE_URL` | `https://<gateway-fqdn>/flow-events` | frontend (`/flow`) |

### Secrets

| Nome | Conteúdo | Bloco |
|---|---|---|
| `AZURE_CREDENTIALS` | JSON do Service Principal com acesso ao RG | F5 + F6 |
| `PHASE05_SQL_CONNECTION_STRING` | connection string ADO.NET do `FIFA2026Tickets` | F5 (McpServer) |
| `GEMINI_API_KEY` | sua chave Gemini | F5 (proxy server-side) |
| `GROQ_API_KEY` / `MISTRAL_API_KEY` *(opcionais)* | chaves de fallback | F5 |
| `PHASE06_SIGNALR_CONNECTION_STRING` | connection string do Azure SignalR | F6 |
| `AZURE_FRONTEND_PUBLISH_PROFILE` | publish profile do `<seu-frontend>` (SCM Basic Auth On antes de capturar) | frontend |
| `GATEWAY_SHARED_SECRET` | **mesmo** valor do `Gateway__AdminSharedSecret` (gateway + McpServer) — o job `mcp-server` do `lab-a-final.yml` aplica como *secretref* no McpServer (equivale ao App Setting manual da [Fase 1.3](#13-app-settings-do-mcpserver)) | F5 (trava X-Gateway-Key) |

## Fase 9 — Smoke central: a bolinha atravessa 5 nós

1. Faça uma **compra v2** no portal (login CIAM → comprar um ingresso).
2. Navegue para **`/flow`**.
3. Observe a "bolinha" atravessar **exatamente 5 nós, em < 30s**, com o **mesmo `correlationId`** em cada hop:

| # | Nó | O que acontece |
|---|---|---|
| 0 | **Gateway YARP** | recebe a request, injeta `X-Correlation-ID` (nó zero do tracing) |
| 1 | **Function Entry** | `PurchaseEntryFunction` valida e publica no Service Bus |
| 2 | **Service Bus** | fila `tickets-purchase` (desacopla entrada e processamento) |
| 3 | **Function Consumer** | `PurchaseConsumerFunction` grava no SQL (idempotente) **e emite a notificação pós-compra INLINE** |
| 4 | **SQL** | linha gravada em `purchases.correlation_id` — fim do fluxo |

4. Abra o **Sheet de inspeção** de cada nó e confira o payload / `correlationId`.

### O trade-off didático (a notificação "invisível")

No nó **Function Consumer** (nó 3), inspecione o payload e localize a **notificação pós-compra**: ela acontece **inline** (log estruturado correlacionado), **dentro** desse nó — **não tem nó próprio**.

Por que 5 nós e não 6? A re-arquitetura da Final **removeu a orquestração externa** de pós-compra: a notificação virou uma etapa **inline** da própria Function Consumer. Ganhamos simplicidade (menos peças, menos falhas, menos custo) ao preço de uma perda visual — a notificação não aparece como uma "bolinha" separada. É um trade-off consciente: a observabilidade da notificação vive no log correlacionado do nó Consumer.

✅ **Checkpoint (AC-4/AC-5/AC-8):** 5 nós exatos, `correlationId` ponta-a-ponta em < 30s; a notificação é encontrada **dentro** do nó Function Consumer; **zero** referência a um 6º nó ou a orquestração externa.

---

# Bloco 3 — Entrega, retrospectiva e encerramento

## Entrega via GitHub Actions (fluxo 100% web, padrão Quartas)

A branch do lab no repositório do evento (org **TFTEC**) chama-se **`lab-a-final`** — traz o workflow `lab-a-final.yml` + o código do F5/F6 (McpServer só-sentidos, FlowEvents 5 nós).

1. **Fork NOVO** do repo do evento, **com TODAS as branches** — na tela de fork, **desmarque** *Copy the `main` branch only* → **Create fork**. (⚠️ **Não reuse** o fork das Quartas: **Sync fork** só atualiza a `main` e **não traz branches novas**.)
2. **Habilite o workflow na `main` do seu fork:** abra um **Pull Request `lab-a-final` → `main`** (base = `main`, compare = `lab-a-final`) **no próprio fork** e faça o **merge**. Esse PR é o "exercício" da aula — ele faz o `lab-a-final.yml` aparecer no Actions. (Você nunca dá PR no repo da TFTEC.)
3. Rode os `acao` na ordem: **`mcp-server` → `gateway` → `flow-events` → `frontend`** (ou **`tudo`**).

> **Nota @devops:** confirmar o nome final do workflow (`lab-a-final.yml`), o slot da branch curada `lab-a-final` no upstream TFTEC (a partir do estado pós-Story 3.1/3.2) e a lista definitiva de `acao`.

## Retrospectiva — o que você construiu (e por quê)

| Missão | O que provou |
|---|---|
| **Voz** (F5, McpServer) | uma IA pode consultar dados reais com segurança — a regra de ouro vale **por construção** (só 7 sentidos, zero escrita) |
| **Visão** (F6, Flow Visualizer) | observabilidade distribuída: uma compra rastreável ponta-a-ponta por `correlationId`, animada em 5 nós |
| **Blindar** (hardening) | o gateway é o guardião único: `X-Gateway-Key` fecha o bypass direto ao McpServer; cache pós-auth; chave Gemini nunca no bundle |
| **Simplificar** (re-arquitetura) | menos peças (notificação inline), menos custo, mesma funcionalidade — retro-compatível com Oitavas/Quartas |

## Perguntas para fechar (discussão em turma)

- Por que o McpServer tem **ingress interno** e o FlowEvents **externo**? (guardião único vs. serviço de leitura de telemetria consumido pelo front via gateway)
- Se alguém tentar `curl` direto no McpServer forjando `X-Entra-OID`, o que acontece? (401 — falta o `X-Gateway-Key`)
- Onde está a chave do Gemini? (no proxy server-side; o front só conhece a URL do proxy)
- Por que a notificação pós-compra não tem nó próprio? (trade-off da re-arquitetura: inline no Consumer)

---

## Apêndice A — Chave Gemini (AI Studio)

1. Crie/abra uma conta **Gmail exclusiva do lab** (janela anônima).
2. Acesse **https://aistudio.google.com/apikey** logado nessa conta → aceite os termos.
3. **Create API key → Create API key in new project** → copie e guarde como o Secret `GEMINI_API_KEY` (nunca no código).
4. Modelo do lab: **`gemini-2.5-flash`**.

## Apêndice B — Modelo Gemini: real vs. comentário

- O **runtime** do `gemini.ts` usa `import.meta.env.VITE_GEMINI_MODEL ?? 'gemini-2.5-flash'` — ou seja, **`gemini-2.5-flash`** por default (sobrescrevível pela Variable `VITE_GEMINI_MODEL`).
- O **comentário de cabeçalho** do arquivo ainda menciona `models/gemini-2.0-flash` (o `2.0-flash` saiu do free tier). É uma **inconsistência de documentação pré-existente**, **inofensiva** e **fora do escopo** deste lab corrigir. Para o aluno, o que vale é o modelo real: **`gemini-2.5-flash`**.

## Apêndice C — Troubleshooting F5 (McpServer + chatbot)

| Sintoma | Causa provável | Mitigação |
|---|---|---|
| `tools/list` retorna **8** (não 7) | branch não parte do estado pós-Story 3.1 (McpServer só-sentidos) | confirme que `lab-a-final` está baseada em pós-3.1; deve haver **7** `[McpServerTool(..., ReadOnly = true)]` |
| **401** no `POST /mcp` mesmo com Bearer válido | `Gateway__AdminSharedSecret` (gateway) ≠ `GATEWAY_SHARED_SECRET` (McpServer), ou gateway não rebuildado | use o **mesmo** segredo nos dois e rode `acao=gateway` (o `mcp-server` só entrou no conjunto confiável no hardening) |
| **502** em `/mcp` | `McpServerUrl` ausente/errado no gateway, ou target port do McpServer ≠ 8080 | `McpServerUrl = https://<mcp-fqdn>` (Fase 1.4); ingress target port = **8080** |
| McpServer responde por **URL pública** | ingress criado como **External** (deveria ser interno) | recriar/ajustar ingress = **Limited to Container Apps Environment** (Fase 1.1) |
| Chatbot diz "chat indisponível" | `VITE_LLM_PROXY_URL` não setado no build | definir a Variable (= gateway) e re-rodar `acao=frontend` |
| Chatbot **inventa** uma resposta de ação | alucinação de texto do LLM (function calling não é 100% infalível) | reforçar: a "promessa" no texto **não** é uma tool call; nenhuma escrita ocorre — não há tool de escrita |
| `POST /mcp` retorna `X-Cache: HIT` | regressão do fix de cache do gateway | confirmar que a branch inclui o fix (POST não é cacheado) |
| Build do frontend falha no **guard de key** | uma key de LLM apareceu no bundle | a key deve ficar **só** no proxy server-side; remover qualquer uso direto no front |
| Chatbot responde mas sem dados reais | `SqlConnectionString` ausente/errada no McpServer | conferir o App Setting (Fase 1.3) |

## Apêndice D — Troubleshooting F6 (FlowEvents + Flow Visualizer)

| Sintoma | Causa provável | Mitigação |
|---|---|---|
| Diagrama mostra **6 nós** ou falta o "Gateway YARP" | branch não parte do estado pós-Story 3.1 (5 nós) | confirmar `flowNodes.ts` com **5** entradas; reconstruir `lab-a-final` do commit correto |
| Nós **nunca acendem** / erro 403 nos traces | Managed Identity sem **Log Analytics Reader** | conceder o papel à MI do `ca-flow-<sufixo>` no workspace (Fase 6.3) |
| Bolinha **para no nó 2** (Service Bus) | Consumer com backlog ou atraso de ingestão do Kusto (segundos) | aguardar; confirmar Function Consumer rodando |
| `correlationId` não aparece em nenhum nó | SignalR desconectado ou `VITE_FLOW_EVENTS_BASE_URL` incorreto | conferir a Variable (= `{gateway}/flow-events`) e a rota `/flow` conectando ao Hub |
| SignalR não conecta (WebSocket) | ingress do FlowEvents sem transport **Auto**, ou CORS sem o origin do front | ingress transport = **Auto** (Fase 6.2); CORS do SignalR + `FrontendOrigin` com o origin exato |
| **502** em `/flow-events/**` | `FlowEventsUrl` ausente no gateway | definir `FlowEventsUrl = https://<flow-fqdn>` (Fase 7.1) |
| SignalR recusa por tier | recurso criado em modo **Serverless** | recriar SignalR em **Service Mode Default** (Fase 6.1) |
| Aluno procura um **nó de notificação** dedicado | trade-off aceito (5 nós, notificação inline no Consumer) | reforçar didaticamente (Fase 9): a notificação está **dentro** do nó Function Consumer |

---

## Resumo do que você criou nesta aula

| Camada | Recursos / artefatos |
|---|---|
| F5 — Voz | Container App **McpServer** (ingress interno, 7 tools read-only) + chatbot Gemini (chave no proxy server-side) |
| F5 — Gateway | App Settings `McpServerUrl` + `Gateway__AdminSharedSecret` (X-Gateway-Key no cluster `mcp-server`) |
| F6 — Visão | Container App **FlowEvents** + **Azure SignalR** (Free/Default) + **Managed Identity** (Log Analytics Reader) |
| F6 — Gateway/Front | App Setting `FlowEventsUrl` + rota `/flow` (`VITE_FLOW_EVENTS_BASE_URL`) |
| Automação | Fork: Variables + Secrets + workflow único **Lab A Final** (`mcp-server`/`flow-events`/`gateway`/`frontend`/`tudo`) |
| Segurança | McpServer só-leitura por construção · chave Gemini nunca no bundle · X-Gateway-Key fecha o bypass · cache pós-auth |
</content>
</invoke>
