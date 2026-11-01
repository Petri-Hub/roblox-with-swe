# TODO: Headless Roblox asset bridge

Build a small, cloud-only MCP server for Creator Store asset discovery and file delivery. It should expose asset tools to Pepper without exposing a Roblox API key or any Studio connection tools.

## Roblox endpoints and permissions

| Task | Endpoint | API key scope |
|---|---|---|
| Search models, meshes, audio, and other Creator Store assets | `POST https://apis.roblox.com/toolbox-service/v2/assets:search` | `creator-store-product:read` |
| Inspect a result's creator, price, description, and script count | `GET https://apis.roblox.com/toolbox-service/v2/assets/{id}` | `creator-store-product:read` |
| Get an asset thumbnail | `GET https://thumbnails.roblox.com/v1/assets` | None for the public thumbnail endpoint |
| Obtain a model file's download location | `GET https://apis.roblox.com/asset-delivery-api/v1/assetId/{assetId}` | `legacy-asset:manage` |

The current project key returns `403 Scope not authorized` for authenticated Creator Store search and Asset Delivery. `asset:read` is not a substitute for either scope. An unauthenticated `GET` search and the old public Asset Delivery URL worked during this prototype, but Roblox marks the GET search as not recommended and has announced authentication requirements for legacy asset delivery. Do not make those public paths the bridge's contract.

Sources: [Creator Store API](https://create.roblox.com/docs/cloud/reference/features/creator-store), [Open Cloud scopes](https://create.roblox.com/docs/cloud/reference/scopes), [asset delivery change](https://devforum.roblox.com/t/creator-action-required-new-asset-delivery-api-endpoints-for-community-tools/3574403), [thumbnails API](https://create.roblox.com/docs/cloud/reference/features/thumbnails).

## MCP tools

- `search_assets(query, category, page_token, free_only)`: return a short list with asset IDs, names, creators, prices, script counts, and the next page token.
- `get_asset_details(asset_id)`: return the listing details and thumbnail URL for review.
- `prepare_asset_download(asset_id)`: use a separate key with `legacy-asset:manage` and return Roblox's temporary HTTPS CDN `location`, plus its expiry when available. Do not return a path on the MCP server's filesystem.

Keep the tools limited to this asset workflow: no Studio bridge, arbitrary URL fetch, or generic Open Cloud request. Keep both Roblox keys in the MCP service, outside Pepper's Modal sandbox; give the search key only `creator-store-product:read`. The download location is a temporary download capability, so avoid printing or committing its full URL.

## Why Pepper can use the CDN URL without the API key

1. The MCP server uses its `legacy-asset:manage` key to call Roblox's [Asset Delivery API](https://create.roblox.com/docs/cloud/reference/features/assets) for one asset ID. Roblox responds with a `location` URL on its CDN; it does not send the model bytes in this response.
2. The MCP tool returns that URL to Pepper. Its query parameters include a token and expiry, so the URL itself temporarily authorizes that one download. Pepper does not need the Roblox API key for the CDN request. Treat the full URL as a temporary secret: do not print it in logs or commit it.
3. Pepper's terminal makes the second HTTPS request from inside Modal and saves the returned bytes in its checkout. That is how the asset crosses the Hermes-to-Modal filesystem boundary. The URL must be fetched before it expires.

Roblox describes the [two-request `location` flow](https://devforum.roblox.com/t/creator-action-required-new-asset-delivery-api-endpoints-for-community-tools/3574403?page=4). We verified a no-key CDN fetch for the free Forest Pack using the public legacy metadata endpoint; the scoped Open Cloud first request and Pepper's actual Modal handoff still need testing after the key gains `legacy-asset:manage`.

## Hermes-to-Modal file handoff

Pepper's MCP tools run with Hermes in the homelab, while her terminal and repository checkout run in a disposable Modal Sandbox. A file written by an MCP tool to a homelab path is therefore not in Pepper's checkout. This is consistent with the earlier FAM PDF path problem; confirm its exact cause when testing this bridge.

Preferred flow: Hermes calls `prepare_asset_download`, then Pepper's terminal fetches the returned Roblox CDN URL **inside the active Modal Sandbox** and writes the model into its checkout. Modal Sandboxes allow outbound HTTPS by default. This avoids passing a large binary through a text tool result or assuming the two machines share a filesystem. Fetch promptly because the URL expires. Once selected and checked, commit the model to Git so the asset survives the sandbox.

If the CDN URL cannot be fetched from the sandbox, investigate copying the bytes into that specific live sandbox with Modal's [Sandbox Filesystem API](https://modal.com/docs/guide/sandbox-files). A shared path alone is not a transfer mechanism; large base64 tool results are a poor fit for Pepper's current file-tool limit. See [Pepper's Modal setup](https://github.com/Petri-Hub/pepper/blob/main/profiles/pepper/CONFIG.md) and [Modal networking](https://modal.com/docs/guide/sandbox-networking).

## Done when

- Pepper can search and inspect a free model through the MCP server without any Studio connection or Roblox key in the sandbox.
- Pepper can download a selected model into a Modal checkout, handle any compression in the response, verify its actual `.rbxm` or `.rbxmx` contents, build it with Rojo, and commit it.
- A real Hermes-to-Modal test confirms the downloaded file exists in the sandbox, not only on the homelab host; OCALE verifies any asset used by the game.


---

# Backlog: Lemon — desenvolvimento colaborativo via Discord

> Levantamento de requisitos em 2026-11-01. São propostas e pontos a validar, não funcionalidades confirmadas. Preservar a seção anterior sobre o bridge de assets do Pepper.

## Fase 1 — Auditoria do ambiente existente (prioridade imediata)
- [ ] Inventariar containers/imagens Docker, processos, portas, SSH, credenciais/permissões, volumes, serviços de Rojo e túneis zrok no homelab.
- [ ] Revisar integrações Lemon ↔ Discord ↔ GitHub ↔ Rojo ↔ zrok ↔ Roblox, ciclo de vida, logs, limpeza e isolamento.
- [ ] Identificar o que já funciona, o que está manual, riscos de segurança e pontos frágeis antes de ampliar o sistema.

**Por quê:** o setup foi construído em várias etapas; precisamos de uma base confiável e documentada antes de adicionar automações.

## Fase 2 — Contrato operacional do Lemon
- [ ] Definir SOUL.md/instruções de identidade, escopo, autonomia, limites e comunicação; separar princípios de procedimentos verificáveis.
- [ ] Exigir worktree e branch próprias por thread/tarefa do Discord; provisionar, reutilizar e limpar worktrees com segurança.
- [ ] Definir skill de setup: pré-requisitos, inicialização, Rojo serve, zrok, compartilhamento da URL, diagnóstico e encerramento.
- [ ] Definir skill de implementação: descoberta de requisitos, plano curto, alterações incrementais, revisão, testes, entrega e recuperação de falhas.
- [ ] Especificar quando continuar com commits na mesma branch, quando abrir PR e quando fazer merge; evitar PRs/execuções de cloud desnecessários.
- [ ] Definir regras para criar GitHub Issues (backlog, débitos técnicos, melhorias futuras), evitando registrar toda ideia passageira.
- [ ] Criar glossário e linguagem acessível a não programadores (ex.: PR como “pacote de mudanças”), com detalhe técnico sob demanda.

**Por quê:** hoje o agente não conhece nem o fluxo de worktrees; comportamento consistente não deve depender de improvisação ou apenas da memória do modelo.

## Proteção e governança de branches
- [ ] Configurar rulesets/branch protection para `development` e `staging`: alterações somente via PR, checks obrigatórios, bloqueio de force push e exclusão; revisar bypass de administradores e bots.
- [ ] Verificar se `development` existe e qual é o fluxo real de promoção entre branches antes de aplicar regras.
- [ ] Ajustar permissões do Lemon e validar que ele não consegue contornar a política.

**Por quê:** impedir alterações diretas ou não validadas em branches compartilhadas. **Ainda não configurado.**

## Testes e entrega Roblox
- [ ] Validar em dois Studios a interação de Rojo + Team Create + Team Test: quais mudanças de código entram no estado compartilhado, drafts/commits, início, entrada tardia e encerramento.
- [ ] Documentar teste multiplayer manual: uma sessão Team Test ativa por experiência; aceitar inicialmente essa limitação, sem criar pool de experiências.
- [ ] Levantar testes viáveis sem Roblox Studio headless, checks em CI/cloud, limites/custos e critérios de aceite.
- [ ] Definir política de PR, monitoramento dos checks, correção de falhas, merge e release/publicação, distinguindo teste no Studio de versão publicada.

**Por quê:** Rojo sincroniza código, mas não é um servidor multiplayer; evitar prometer validação automática que a infraestrutura não executa.

## Assets e ferramentas determinísticas
- [ ] Criar fluxo de busca de Creator Store por termo/categoria, com paginação “próxima/anterior”, seleção de um ou mais assets e estado por thread.
- [ ] Gerar imagens de prévia com overlay legível de nome/ID (e, se útil, índice), pois a apresentação de imagens no Discord não atende ao fluxo de escolha.
- [ ] Integrar seleção, inspeção de metadados/licenças/segurança de scripts, download/importação e rastreabilidade dos assets.
- [ ] Reconciliar este fluxo com o bridge MCP de assets já descrito acima; separar skill de orientação das ferramentas de paginação/composição de imagens.

**Por quê:** pessoas não técnicas precisam escolher visualmente assets sem decorar IDs; ferramentas previsíveis economizam tokens.

## Conhecimento, MCP e Game Design
- [ ] Criar skills reutilizáveis de construção de blocos/mecânicas comuns, com exemplos e convenções do projeto.
- [ ] Avaliar documentação estruturada/cache/Context7 para reduzir parsing repetitivo de HTML e gasto de tokens; verificar cobertura real de APIs Roblox.
- [ ] Avaliar integração MCP e possível uso de Tripwire (confirmar produto/escopo pretendido) para governança das ferramentas.
- [ ] Criar skill consultiva de Game Design: core loop, game feel, progressão, balanceamento, feedback, rejogabilidade e diversão; explicar termos sem excesso de jargão.
- [ ] Manter decisões criativas com os participantes: Lemon sugere alternativas e trade-offs, não impõe direção de design.

**Por quê:** Lemon deve ser um colega de equipe que ajuda a conceber, construir e explicar experiências jogáveis, sem transformar toda conversa em aula.

## Próximo passo de planejamento
- [ ] Mapear uma jornada ponta a ponta: pedido no Discord → worktree → implementação → teste → revisão/PR → entrega.
- [ ] Classificar cada requisito em instrução geral, skill, ferramenta determinística, infraestrutura ou política de GitHub.
- [ ] Priorizar um MVP operacional após a auditoria e testar com duas pessoas em uma thread antes de expandir.

**Critério geral:** simplicidade primeiro; automatizar apenas o que foi validado manualmente e medir confiabilidade, custo e experiência de uso.
