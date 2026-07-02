# Speaker Notes — A Grande Final (F5 + F6) · notas do instrutor

> **Notas do apresentador/facilitador** · Workshop "Living Lab Azure-Native" (FIFA 2026 Tickets) · **A ÚLTIMA aula** — a Grande Final.
> **Guia do aluno (fonte-de-verdade, siga a mesma ordem):** [`docs/runbooks/final-portal-guide.md`](../../runbooks/final-portal-guide.md)
> **Stories:** [3.3](../../stories/3.3.story.md) · [3.4](../../stories/3.4.story.md) · **Arquitetura:** ADE-008 (re-arquitetura da Final, sem orquestração externa) · ADE-009 (X-Gateway-Key)

Estas notas são para **você, instrutor**. Trazem o cronômetro, o que você **diz** para abrir cada bloco, os pontos a **enfatizar**, as **perguntas** para a turma, os **momentos "aha"** e os **erros comuns** a antecipar (puxados das tabelas de troubleshooting do guia). Elas **espelham** o guia do aluno — não divergem dele; complementam com a fala do facilitador.

> **Premissa de fidelidade (Art. IV — No Invention):** todo número, nome de tool, nó e arquivo aqui bate com o guia e com o código real. Se a turma perguntar "onde isso está no código?", você aponta: `FifaTicketTools.cs` (as 7 tools), `gemini.ts` (chatbot), `FlowEventType.cs` / `flowNodes.ts` (os 5 nós). **A Final é:** sem orquestração externa (n8n **removido**), **7 tools read-only**, **`gemini-2.5-flash`**, **5 nós**, notificação pós-compra **inline** na Function Consumer. Não invente APIs, tools nem nós.

---

## Mapa de blocos (sessão contínua ≈ 5–6h)

| Bloco | Tema | Duração sugerida | Acumulado |
|---|---|---|---|
| 0 | Abertura + recap Quartas + o que a Final ADICIONA | 20 min | 0:20 |
| 1 | **F5 — McpServer (7 sentidos) + chatbot Gemini** | 2h30–3h30 | ~3:20 |
| — | **Intervalo** | 15 min | ~3:35 |
| 2 | **F6 — FlowEvents + Flow Visualizer (5 nós)** | 2h–3h | ~6:00 |
| 3 | Entrega + retrospectiva das 4 missões + encerramento | 25 min | ~6:25 |

> Ajuste o intervalo ao seu horário; o que importa é entregar o **clímax do F5 (Fase 5 — a regra de ouro ao vivo)** com a turma ainda com energia, e o **smoke dos 5 nós (Fase 9)** como o grande final visual da tarde.

---

# Bloco 0 — Abertura (20 min)

**Objetivo:** reancorar a turma no fio cumulativo e vender o "porquê" da última aula.

**Como abrir (fala):**
> "Chegamos à **Grande Final**. Nas Oitavas você construiu a **compra**; nas Quartas, o **gateway** e a **identidade**. Hoje, nas duas últimas fases, a aplicação ganha **voz** e **visão**: um chatbot que conversa com o estado real da Copa, e um visualizador que mostra sua compra atravessando o sistema, ao vivo."

**Pontos a enfatizar:**
- A Final **ADICIONA**, não recria. Gateway YARP, identidade CIAM + admin, backend v1 e SQL das Quartas **continuam iguais**. Mostre a tabela "O que muda em relação às Quartas" do guia (Bloco 0).
- **Retro-compatibilidade é regra dura:** nada das Quartas deixa de funcionar. A compra é a mesma; a Final só acrescenta **observação** (chatbot que lê + visualizador que mostra).
- A "regra de ouro da arquitetura": **o Portal cria os recursos vazios; os Actions só publicam código.** Nenhum recurso Azure nasce do workflow.

**Frase âncora no quadro:** *"Voz para perguntar. Visão para enxergar. E segurança por construção — não por roteamento."*

**Pergunta para a turma (gancho):** "Se você pudesse **perguntar** para o sistema 'quando o Brasil joga?' em vez de navegar telas — o que precisaria existir para a resposta ser **verdadeira**, e não inventada?" → puxa para o F5 (o LLM raciocina, o McpServer tem os fatos).

**Erro comum a antecipar já aqui:** aluno querer "começar pelo fork". **Corrija na hora:** o fork + Actions é o **último** passo (Bloco 3). Primeiro a infra dos dois serviços novos é criada **à mão** no Portal.

---

# Bloco 1 — F5: McpServer (7 sentidos) + chatbot Gemini (2h30–3h30)

**Objetivo do bloco (fala):**
> "Vamos implantar um **McpServer** atrás do gateway — sete ferramentas, todas de **leitura** — e um **chatbot Gemini** que decide qual delas chamar. No fim, você vai **ver ao vivo** que o chatbot não consegue executar nenhuma ação. Não porque bloqueamos: porque **a ferramenta de escrita simplesmente não existe**."

**Frase âncora:** *"O LLM raciocina; o McpServer tem os fatos. E o McpServer só tem sentidos."*

## Fase 1 — Deploy do McpServer (Container App, ingress INTERNO) [~50 min]

**O que dizer para abrir:** "Este serviço **nunca** é chamado pelo browser. Ele vive **atrás** do gateway, com ingress **interno** — só o gateway, dentro do mesmo Container Apps Environment, fala com ele."

**Pontos a enfatizar (o coração da segurança do bloco):**
- **Ingress = "Limited to Container Apps Environment"** (interno). Este é *o* ponto de segurança da fase: o McpServer não tem endereço público.
- **Target port = 8080**, sempre. É o que o `Dockerfile` expõe (`EXPOSE 8080` + `ASPNETCORE_URLS=http://+:8080`). Qualquer outra porta = **502**.
- **Três App Settings** no McpServer (Fase 1.3): `SqlConnectionString` (as 7 tools fazem `SELECT` parametrizado via Dapper), `GEMINI_API_KEY` (injetada pelo **proxy** server-side), `GATEWAY_SHARED_SECRET` (a trava `X-Gateway-Key`).
- **O mesmo segredo das Quartas:** o `Gateway__AdminSharedSecret` que a turma gerou nas Quartas é **reusado** aqui. Um único segredo protege todos os hops confiáveis. Se ninguém anotou, gere um novo (`openssl rand -hex 24`) e reaplique em **todos** os serviços confiáveis.

**O "P0" a explicar (momento aha de segurança) — Fase 1.4/1.6:**
> "Por que **rebuildar o gateway**? Porque só a partir do hardening (ADE-009) o gateway passou a injetar `X-Gateway-Key` **também** no cluster `mcp-server`. A imagem das Quartas ainda não tinha o McpServer no conjunto confiável. Sem esse rebuild, o segredo não chega ao McpServer e você toma **401** mesmo com um Bearer válido."

**Perguntas para a turma:**
- "Se o McpServer é interno e o browser nunca o alcança, **quem** injeta a identidade do usuário nele?" → o gateway, via header `X-Entra-OID`.
- "E se alguém fizer `curl` direto no McpServer forjando `X-Entra-OID`?" → **401**: falta o `X-Gateway-Key`, que só o gateway tem.

**Erros comuns a antecipar (tabela Apêndice C do guia):**
- **`tools/list` retorna 8 e não 7** → a branch não parte do estado pós-Story 3.1 (McpServer só-sentidos). Deve haver exatamente **7** `[McpServerTool(..., ReadOnly = true)]`.
- **401 no `POST /mcp` com Bearer válido** → `Gateway__AdminSharedSecret` (gateway) ≠ `GATEWAY_SHARED_SECRET` (McpServer), **ou** o gateway não foi rebuildado. Mesmo segredo nos dois + `acao=gateway`.
- **502 em `/mcp`** → `McpServerUrl` errado no gateway, ou target port ≠ 8080.
- **McpServer responde por URL pública** → ingress criado como External. Recriar como interno.

**Checkpoint da fase (diga em voz alta o critério):** "`tools/list` via gateway tem de listar **exatamente 7 tools, todas `readOnly: true`**; `POST /mcp` **sem** `X-Cache: HIT`; e o McpServer **não** responde por URL pública."

**As 7 tools (todas de leitura)** — tenha a lista à mão para quando a turma perguntar:
`consultar_disponibilidade` · `verificar_ingresso` · `consultar_bracket` · `consultar_partidas` · `consultar_classificacao` · `consultar_time` · `consultar_estadio`.

## Fase 2 — Chatbot conversando com o estado real da Copa [~30 min]

**O que dizer:** "Agora o chatbot descobre as 7 tools via `tools/list` e deixa o **Gemini** decidir qual chamar — function calling, modo `AUTO`. Repare: ele não inventa, ele **lê o banco** através das tools."

**Demonstre ao vivo (mín. 3 perguntas):**
- *"Quando o Brasil joga?"* → `consultar_partidas`.
- *"Como está o grupo A?"* → `consultar_classificacao`.
- *"Me fala do Maracanã"* → `consultar_estadio`.

**Momento aha:** mostre, no painel do chatbot, **qual tool** foi escolhida a cada pergunta. "Você fez uma pergunta em português; o Gemini traduziu para uma chamada de ferramenta; o dado veio do **SQL real**."

**Erro comum:** "Chatbot diz 'chat indisponível'" → `VITE_LLM_PROXY_URL` não foi setado no build; definir (= o gateway) e re-rodar `acao=frontend`. "Responde mas sem dados reais" → `SqlConnectionString` ausente/errada no McpServer.

**Sobre o modelo (se perguntarem):** o runtime usa **`gemini-2.5-flash`** (o comentário de cabeçalho do `gemini.ts` ainda cita `2.0-flash` — inconsistência **conhecida e inofensiva**; não precisa mexer no código).

## Fases 3 e 4 — Roteamento, cache e identidade (referência, sem configurar) [~15 min]

Nada a configurar; é **entendimento**. Enfatize:
- O gateway roteia `/mcp` e `/llm/**` para o cluster `mcp-server`. **`POST` não é cacheado** (o fix separou o cache de `GET` das chamadas MCP/LLM).
- O cache de borda (30s) roda **pós-autenticação** (hardening 4.4): um HIT só é servido **depois** que o JWT é validado.
- O McpServer **lê** `X-Entra-OID` só para **logging mascarado** — **nunca** revalida o JWT. O gateway é o **guardião único**. É por isso que o McpServer pode ficar atrás do gateway sem reimplementar autenticação.

**Onde falar da chave Gemini (momento de segurança):** "A chave **nunca** vai para o browser. O front só conhece a URL do **proxy** (`VITE_LLM_PROXY_URL` = o gateway). O McpServer expõe `/llm/{provider}/{*path}`, injeta a `GEMINI_API_KEY` como header e encaminha ao endpoint oficial. E o workflow tem um **guard** que **falha o build** se qualquer key vazar no bundle."

## Fase 5 — A REGRA DE OURO AO VIVO (o clímax do bloco) [~20 min]

> ⭐ **Este é o momento central da aula inteira. Não corra por ele.**

**Roteiro detalhado da fala:**

1. **Prepare o palco.** "Até agora o chatbot só leu dados. Vamos testar o limite: peça a ele uma **ação**." Peça a um aluno (ou você) que digite no chatbot:
   > *"Cria um alerta pra mim quando abrir ingresso VIP."*

2. **Deixe a turma observar junto.** O chatbot **não tem essa ferramenta**. O `tools/list` só expõe **7 tools de leitura** — não existe nenhuma tool de **escrita** para o Gemini chamar.

3. **Diga a frase-chave:**
   > "Repare no que acabou de acontecer. Eu não **bloqueei** a ação com uma regra, um IF, um roteamento. A ação simplesmente **não pode acontecer** porque **a ferramenta não existe**. Isso é **segurança por construção, não por roteamento**. O que não existe não pode ser chamado."

4. **A nuance honesta (não pule — é o que separa uma boa aula de uma aula ingênua):**
   > "Atenção a uma sutileza: o LLM **pode** responder em texto algo como 'pronto, criei o alerta'. Isso é **alucinação de texto** — não é uma tool call. **Nenhuma escrita ocorre** no banco. A 'promessa' no texto **não é uma ação**. O único jeito de escrever seria uma tool call de escrita — e ela **não existe**. A segurança não depende de o LLM 'se comportar'; depende de o vetor de escrita **não existir**."

**Ponto a reforçar:** a "mão" de ação (uma antiga ferramenta de criar alerta) **foi removida** — o McpServer é só **sentidos**. Você **não precisa** explicar filas, webhooks ou roteamento para provar a segurança: **basta olhar a lista de ferramentas**.

**Pergunta para fechar o momento:** "Qual é a auditoria de segurança mais simples que existe aqui?" → **Ler o `tools/list`.** Sete verbos, todos de leitura. Fim.

**Erro comum (tabela do guia):** aluno vê o LLM "prometer" a ação e conclui que houve escrita. **Corrija na hora:** peça para checar o banco / o `tools/list`. Texto não é tool call.

**Checkpoint (diga o critério):** "A turma **viu** que o chatbot não executa ações; e o material **não menciona** nenhuma 'mão' ou tool de escrita."

---

# Bloco 2 — F6: FlowEvents + Flow Visualizer (5 nós) (2h–3h)

**Objetivo do bloco (fala):**
> "No F5 a aplicação ganhou **voz**. Agora ela ganha **visão**: um serviço que lê os rastros de uma compra real e um visualizador onde uma 'bolinha' atravessa **cinco nós** animados — a mesma compra, rastreável de ponta a ponta pelo `correlationId`."

**Frase âncora:** *"Uma compra, um `correlationId`, cinco nós. Observabilidade distribuída que você consegue ver."*

## Fase 6 — Azure SignalR + Managed Identity [~50 min]

**Pontos a enfatizar:**
- **SignalR tier Free (Free_F1)**, **Service Mode = `Default`** (⚠️ **NÃO** `Serverless`). O `FlowHub` é hospedado pelo próprio FlowEvents (`AddAzureSignalR`), que **exige** o modo Default. Erro clássico: criar em Serverless → SignalR recusa por tier.
- **CORS do SignalR** precisa do **origin exato** do frontend (`https://<seu-frontend>.azurewebsites.net`). O WebSocket usa credentials → **não pode ser `*`**.
- **Container App do FlowEvents é EXTERNO** (diferente do McpServer!): "Accepting traffic from anywhere", **Transport = `Auto`** (habilita WebSocket), **Target port = 8080**.
- **Managed Identity + role `Log Analytics Reader`** no workspace. Este é o ponto que mais trava: **sem esse papel, o `LogsQueryClient` toma 403 e os nós NUNCA acendem.**

**Pergunta para a turma (contraste de arquitetura — momento aha):** "Por que o McpServer é **interno** e o FlowEvents é **externo**?" → o McpServer é o guardião de dados sensíveis atrás do gateway (só o gateway fala com ele); o FlowEvents é um serviço de **leitura de telemetria** que o front consome via gateway e por WebSocket.

**Erros comuns a antecipar (Apêndice D):**
- **Nós nunca acendem / 403** → Managed Identity sem `Log Analytics Reader`. Conceder no workspace.
- **SignalR não conecta (WebSocket)** → ingress sem transport `Auto`, ou CORS sem o origin do front.
- **SignalR recusa por tier** → criado em Serverless. Recriar em Default.

## Fase 7 — Gateway (`FlowEventsUrl`) + frontend (`/flow`) [~25 min]

**Pontos a enfatizar:**
- O gateway **já** roteia FlowEvents (`FlowEventsDestinationConfigFilter` existe desde a Story 2.6, reusado). Só falta dar a **URL real** (`FlowEventsUrl`).
- Duas rotas: `/flow-events/api/{**}` (API: recent / {id} / replay) e `/flow-events/hubs/{**}` (o Hub SignalR, WebSocket).
- O gateway continua o **NÓ ZERO**: injeta `X-Correlation-ID` (transform global) também nas requests ao FlowEvents.
- **Escopo importante (não confundir com o F5):** o cluster `flow-events` **NÃO** recebe `X-Gateway-Key` (fora do escopo da ADE-009). **Não** configure `GATEWAY_SHARED_SECRET` no FlowEvents — diferente do McpServer.

## Fase 9 — SMOKE CENTRAL: a bolinha atravessa 5 nós [~30 min]

> ⭐ **O grande final visual da aula. Faça uma compra real e conduza a turma ao vivo.**

**Roteiro da fala:**

1. "Vamos fazer uma **compra v2 de verdade**: login CIAM, comprar um ingresso."
2. "Agora navegue para **`/flow`** e **olhem juntos**." A bolinha deve atravessar **exatamente 5 nós, em menos de 30 segundos**, com o **mesmo `correlationId`** em cada hop.

**Os 5 nós (tenha à mão; é isto que a turma vê):**

| # | Nó | O que acontece |
|---|---|---|
| 0 | **Gateway YARP** | recebe a request, injeta `X-Correlation-ID` (nó zero do tracing) |
| 1 | **Function Entry** | `PurchaseEntryFunction` valida e publica no Service Bus |
| 2 | **Service Bus** | fila `tickets-purchase` (desacopla entrada e processamento) |
| 3 | **Function Consumer** | `PurchaseConsumerFunction` grava no SQL (idempotente) **e emite a notificação pós-compra INLINE** |
| 4 | **SQL** | linha gravada em `purchases.correlation_id` — fim do fluxo |

3. "Abram o **Sheet de inspeção** de cada nó e confiram o payload e o `correlationId` — é o **mesmo** do começo ao fim."

### O momento "onde foi o n8n?" (OBRIGATÓRIO — não pule)

> **Este slide/momento fecha a missão "Simplificar". Conduza com cuidado de linguagem.**

**Roteiro da fala:**
> "Quem acompanhou o desenho original talvez esperasse um **sexto** nó — a orquestração da notificação pós-compra. Ele **não existe mais**. Nós **removemos a orquestração externa**. A notificação virou uma etapa **inline** dentro da própria **Function Consumer** — o nó 3. É a **Function que orquestra o pós-compra**, no mesmo processo em que grava a compra."

**Peça a inspeção (momento aha):** "Abram o payload do **nó 3, Function Consumer**, e **procurem a notificação**. Ela está **ali dentro** — um log estruturado correlacionado. Ela **não tem bolinha própria**."

**O trade-off, dito honestamente:**
> "Ganhamos **simplicidade**: menos peças, **menos pontos de falha**, **menos custo**. Pagamos com uma perda **visual**: a notificação não aparece como um nó separado. É um trade-off **consciente** — a observabilidade da notificação vive no **log correlacionado** do nó Consumer. Cinco nós, não seis."

> ⚠️ **Cuidado de linguagem (para você, instrutor):** diga **"a Function orquestra o pós-compra"**. **NUNCA** diga "automação no-code" nem cite orquestração externa como algo presente. Na Final ela **não existe**.

**Pergunta para a turma:** "Se um aluno procurar o 'nó de notificação' e não achar, o que você responde?" → é o trade-off aceito: **5 nós, notificação inline no Consumer**. Não é bug; é design.

**Erros comuns (Apêndice D):**
- **Diagrama mostra 6 nós / falta o Gateway YARP** → branch não parte do pós-Story 3.1. Confirmar `flowNodes.ts` com **5** entradas.
- **Bolinha para no nó 2 (Service Bus)** → Consumer com backlog ou atraso de ingestão do Kusto (segundos). Aguardar; confirmar o Consumer rodando.
- **`correlationId` não aparece em nenhum nó** → SignalR desconectado ou `VITE_FLOW_EVENTS_BASE_URL` incorreto (deve ser `{gateway}/flow-events`).
- **502 em `/flow-events/**`** → `FlowEventsUrl` ausente no gateway.

**Checkpoint (diga o critério):** "**5 nós exatos**, `correlationId` ponta-a-ponta em **< 30s**; a notificação encontrada **dentro** do nó Function Consumer; **zero** referência a um 6º nó ou a orquestração externa."

---

# Bloco 3 — Entrega, retrospectiva e encerramento (25 min)

## Entrega (fluxo 100% web, padrão Quartas) [~10 min]

**O que dizer:** "Agora sim o fork. Lembrem: **o Portal criou os recursos vazios; o Actions só publica código.**"

**Pontos a enfatizar (erros clássicos do fork):**
- **Fork NOVO, com TODAS as branches** — na tela de fork, **desmarque** *Copy the `main` branch only*. **Não reusem** o fork das Quartas: **Sync fork só atualiza a `main` e não traz branches novas.**
- **Habilitar o workflow:** abrir um **PR `lab-a-final` → `main` no próprio fork** e fazer o merge. Esse PR é o "exercício" — é o que faz o `lab-a-final.yml` aparecer no Actions. **Nunca** se dá PR no repo da TFTEC.
- Rodar os `acao` na ordem: **`mcp-server` → `gateway` → `flow-events` → `frontend`** (ou **`tudo`**).

## Retrospectiva — as 4 missões (fala celebrativa) [~10 min]

> **Feche amarrando tudo. Use a mesma tabela do guia.**

| Missão | O que a turma provou |
|---|---|
| **Voz** (F5, McpServer) | uma IA pode consultar dados reais **com segurança** — a regra de ouro vale **por construção** (só 7 sentidos, zero escrita) |
| **Visão** (F6, Flow Visualizer) | observabilidade distribuída: uma compra rastreável ponta-a-ponta por `correlationId`, animada em **5 nós** |
| **Blindar** (hardening) | o gateway é o **guardião único**: `X-Gateway-Key` fecha o bypass direto ao McpServer; cache pós-auth; chave Gemini nunca no bundle |
| **Simplificar** (re-arquitetura) | **menos peças** (notificação inline), menos custo, mesma funcionalidade — retro-compatível com Oitavas/Quartas |

**Perguntas de discussão para fechar (as mesmas do guia):**
- Por que o McpServer tem ingress **interno** e o FlowEvents **externo**?
- Se alguém der `curl` direto no McpServer forjando `X-Entra-OID`, o que acontece? (**401** — falta o `X-Gateway-Key`.)
- Onde está a chave do Gemini? (no **proxy server-side**; o front só conhece a URL do proxy.)
- Por que a notificação pós-compra não tem nó próprio? (**trade-off** da re-arquitetura: inline no Consumer.)

## Encerramento (tom celebrativo) [~5 min]

**Fala de fechamento:**
> "Vocês começaram com uma compra de ingresso e terminaram com um sistema **Azure-native** completo: assíncrono, com gateway, identidade federada, um chatbot que conversa com os dados **sem nunca poder alterá-los**, e uma tela onde a própria arquitetura se **acende** diante dos seus olhos. Isso é uma **Grande Final**. Parabéns — vocês construíram tudo, do zero, com as próprias mãos."

**Deixe no ar (gancho de continuidade):** a mesma disciplina — guardião único, segurança por construção, observabilidade correlacionada, simplicidade deliberada — é o que se leva para **qualquer** sistema em produção depois do workshop.

---

## Apêndices úteis para o instrutor (referência rápida)

- **Chave Gemini** (se alguém não tiver): Apêndice A do guia — conta Gmail exclusiva → https://aistudio.google.com/apikey → *Create API key in new project*. Modelo do lab: **`gemini-2.5-flash`**.
- **Modelo real vs. comentário:** Apêndice B — runtime é `gemini-2.5-flash`; o comentário de cabeçalho do `gemini.ts` ainda cita `2.0-flash` (inofensivo, fora de escopo corrigir).
- **Troubleshooting F5:** Apêndice C do guia (401/502/8 tools/guard de key).
- **Troubleshooting F6:** Apêndice D do guia (6 nós/403/WebSocket/tier/nó de notificação).
