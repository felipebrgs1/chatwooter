# Roadmap de paridade de produto (UI + comportamento) com o Chatwoot

> Complementa o [`ROTEIRO.md`](./ROTEIRO.md) (produto e decisões) e o
> [`docs/SCHEMA_PARITY.md`](./docs/SCHEMA_PARITY.md) (schema — paridade ✅ concluída).
> Este documento lista **cada tela e funcionalidade do Chatwoot** e o que falta para ficarmos 1:1.
> Inventário feito a partir de `chatwoot/` (v4.18) em 2026-09-27.

## Regras

- **1:1 = mesma tela, mesmo texto (en), mesmo comportamento**, portado do `.vue` indicado. Paths de
  referência relativos a `chatwoot/app/javascript/dashboard/` (`FE/` quando precisar distinguir).
- Cada item só vira ✅ com **teste primeiro** (ver `AGENTS.md` → TDD), `make precommit` verde e
  conferência no browser. Marque o checkbox no mesmo PR.
- Canais: **só WhatsApp Cloud API e Telegram** (decisão travada). Telas de outros canais não entram.
- Status: ✅ feito · 🟡 existe, mas não está 1:1 (estilo antigo ou incompleto) · ⬜ não iniciado.
- Ordem = ordem de execução. **v1** (corte de migração) termina no Marco 7; o resto é pós-v1.

## Estado atual (base)

Medido na stack Go + React em 2026-09-30. Itens que só existiam no app Elixir (removido; código na tag
`elixir-final`) voltaram para ⬜ e servem de referência para o port.

| Área | Status | Observação |
|---|---|---|
| Fundação de UI | ✅ | tokens `n-*`, Inter, Phosphor, `components/next/*`, rota = arquivo |
| Sidebar | ✅ | expandida/recolhida/mobile, perfil + disponibilidade; Folders, Teams, Channels e Labels; faltam contadores |
| Lista de conversas | ✅ | abas, status, ordenação, card, visões, layout expandido; faltam extras (Marco 1.1) |
| Thread, cabeçalho, composer | 🟡 | 1:1 no básico; faltam painel do contato, rich text, canned, anexos, menções |
| Lista e detalhe de contatos | 🟡 | lista, busca, ordenação, detalhe, bloquear, etiquetas, notas, histórico, excluir; faltam criar, filtros, merge, atributos, mídia, nova conversa |
| Empresas | 🟡 | lista, busca, ordenação, paginação, criação, edição/exclusão, avatar, vínculos, histórico/notas e selector inline; faltam atributos personalizados e favicon automático |
| Settings (general, inboxes, agents, profile) | ⬜ | — |
| Telegram, WhatsApp Cloud | ⬜ | só schema |
| API v1 | 🟡 | profile, contas, conversas (+ filtro avançado), mensagens, labels, teams, inboxes e agentes (leitura), custom_filters; o resto ⬜ |
| Webhooks, notificações, busca, relatórios | ⬜ | — |

---

## Marco 1 — Área de conversa (uso diário)

### 1.1 Lista de conversas — extras
Ref.: `components/ChatList.vue`, `components/widgets/conversation/*`
- [x] Rotas de visão: Mentions, Participating, Unattended, por Team, por Label (`routes/dashboard/conversation/conversation.routes.js`) + itens na sidebar — query params de `/app` (`conversation_type`, `team_id`, `label`), como o `inbox_id`
- [x] Filtros avançados + salvar/editar/excluir pasta + visão Folder e seção "Folders" na sidebar (`components-next/filter/ConversationFilter.vue`, `SaveCustomView.vue`, `customviews/DeleteCustomViews.vue`) — backend: `custom_filters`
  - `POST /conversations/filter` (FilterService: atributos padrão, adicionais e personalizados, datas com fuso, erros 422), CRUD de `custom_filters`, `GET /agents`; modal de filtros, salvar/editar/excluir pasta, `/app?folder_id=` e seção Folders. Conferido no browser em 2026-10-03.
  - Filtros aplicados ficam na URL (`?filters=`), não só em memória como no Chatwoot. Atributos personalizados no modal esperam o endpoint de definições (Marco 6.4); campanha aparece sem opções (sem endpoint).
- [x] Menu de contexto do card: lido/não lido, status, snooze, prioridade, etiquetas, agente, time, abrir em nova aba, copiar link, excluir (`contextMenu/Index.vue`)
  - Backend: `DELETE /conversations/:id` (só admin) e `GET /assignable_agents?inbox_ids[]=`. Conferido no browser em 2026-10-03.
  - Desvios: Snooze aparece só visual (no Chatwoot abre o submenu da command bar, Marco 5.3); resolver ainda não pede atributos obrigatórios (Marco 6.4); a exclusão é síncrona (no Chatwoot, `DeleteObjectJob`).
- [x] Ações em massa: seleção, etiquetas, status/snooze, agente, time (`conversationBulkActions/`)
  - Backend: `POST /bulk_actions` (conversas), respeitando as inboxes do agente. Conferido no browser em 2026-10-03.
  - Desvios: roda na requisição (no Chatwoot, `BulkActionsJob`); "None" do time grava nulo (o Chatwoot gravaria `team_id = 0`); Snooze só visual (command bar); resolver ainda não pula as conversas sem atributos obrigatórios (Marco 6.4); o tipo `Contact` entra com as ações em massa de contatos.
- [ ] Etiquetas e selo de SLA no card (`CardLabels.vue`, `SLACardLabel.vue`)
  - Etiquetas prontas. Falta o selo de SLA: depende de políticas de SLA, horário comercial e do job de eventos (recursos Enterprise, sem backend aqui).
- [x] Layout expandido (`ConversationCardExpanded.vue`, `search/SwitchLayout.vue`) — preferência em `ui_settings`
  - Fora: troca automática para expandido em tela pequena (`Dashboard.vue`), que grava `ui_settings` a cada resize; o mobile já alterna lista/conversa.
- [x] Paginação por scroll (25 por página) + "All conversations loaded"
- [x] Atalhos: Alt+J/K (anterior/próxima), Alt+N (abas)
  - J/K clicam o card preservando os filtros, sem dar a volta nos extremos e mesmo com foco no composer; N alterna Mine/Unassigned/All fora de campos editáveis. Testes e browser nos layouts compacto/expandido.
- [x] `TimeAgo` que se atualiza sozinho (hook)
  - Intervalos de minuto/hora/dia conforme `components/ui/TimeAgo.vue`, reinício ao trocar conversa/atividade e limpeza ao desmontar; validado nos cards compacto e expandido.

### 1.2 Cabeçalho da conversa
Ref.: `components/widgets/conversation/ConversationHeader.vue`
- [ ] Avatar com presença, nome, `#id` copiável, nome da inbox, "Snoozed until…"
- [ ] Botão de status: Resolve/Reopen + dropdown Snooze/Pending (`components/buttons/ResolveAction.vue`), Alt+E/Alt+M
- [ ] Snooze: next reply, 1h, amanhã, próxima semana, próximo mês, custom (`CustomSnoozeModal.vue`) — backend: `snoozed_until` + job de reabertura
- [ ] Mais ações: mute/unmute, enviar transcrição por e-mail (`MoreActions.vue`, `EmailTranscriptModal.vue`)
- [ ] Atributos obrigatórios ao resolver (`ConversationResolveAttributesModal.vue`) — depende do Marco 6.4

### 1.3 Thread de mensagens
Ref.: `components/widgets/conversation/MessagesView.vue`, `components-next/message/`
- [ ] Bolhas: texto (markdown), imagem, vídeo, áudio, arquivo, localização, contato, atividade, nota privada, template, erro (`bubbles/*`)
- [ ] Status de entrega sent/delivered/read/failed + retry (`MessageStatus.vue`, `MessageError.vue`)
- [ ] Agrupamento de mensagens consecutivas, meta (hora, remetente)
- [ ] Divisor "N unread messages", carregar antigas no scroll, galeria de imagens (`GalleryView.vue`)
- [ ] Menu da mensagem: responder, copiar, copiar link, criar canned, excluir (`MessageContextMenu.vue`)
- [ ] Reply-to (citação na bolha e no composer)
- [ ] Barra "conversa anterior"/"ir para a mais recente" (`OlderConversationBar.vue`, `ContactConversationLink.vue`)
- [ ] Indicador de digitação (Presence) — WhatsApp/Telegram enviam typing
- [ ] Banners de janela de resposta (24h WhatsApp)

### 1.4 Caixa de resposta
Ref.: `components/widgets/conversation/ReplyBox.vue`, `components/widgets/WootWriter/`
- [ ] Alternar Reply / Private note (Alt+P / Alt+L), editor redimensionável
- [ ] Editor rich text (definir: ProseMirror/TipTap via hook ou markdown simples) 
- [ ] `/` canned responses, `@` menção de agente (só nota), `{{` variáveis, `:` emoji
- [ ] Emoji picker, anexos (arrastar e soltar), gravação de áudio
- [ ] Assinatura (toggle) — `users.message_signature`
- [ ] Templates do WhatsApp (`WhatsappTemplates/Modal.vue`) fora da janela de 24h
- [ ] Rascunho por conversa e modo; tecla de envio Enter vs Cmd+Enter (`ui_settings`)

### 1.5 Painel do contato (direita)
Ref.: `routes/dashboard/conversation/ContactPanel.vue`, `components/widgets/conversation/ConversationSidebar.vue`
- [x] Abrir/fechar (Alt+O), estado em `ui_settings.is_contact_sidebar_open`
  - `SidepanelSwitch`, `ConversationSidebar`/`ContactPanel`, estado em `ui_settings`.
- [ ] Info do contato: edição inline do nome, e-mail, telefone, empresa, localização, redes; ações (nova mensagem, ver conversas, editar, mesclar, excluir) (`contact/ContactInfo.vue`)
  - Leitura pronta (dados, cópia, redes, link para o contato). Falta: edição inline e os modais de nova mensagem, editar, mesclar e excluir (hoje só visuais).
- [ ] Acordeões reordenáveis e recolhíveis, ordem em `ui_settings.conversation_sidebar_items_order`:
  - [x] Conversation actions: agente (+ "assign to me"), time, prioridade, etiquetas (`ConversationAction.vue`) — backend: atribuição, `team_id`, `priority`, labels da conversa (`cached_label_list`)
    - `POST toggle_priority`, `GET/POST conversations/:id/labels`, `team_id` 0 desatribui. Fora: sugestões do Captain, agent bots, "Create new label", mensagens de atividade.
  - [ ] Macros (depende do Marco 5.3)
  - [ ] Conversation info + atributos da conversa
  - [ ] Atributos do contato, notas do contato, arquivos compartilhados
  - [ ] Conversas anteriores, participantes (`ConversationParticipant.vue`)

**DoD Marco 1:** atender uma conversa do começo ao fim (ler, responder, anexar, nota com @menção,
atribuir, etiquetar, resolver/snooze) com a UI idêntica à do Chatwoot.

---

## Marco 2 — Canais (WhatsApp + Telegram completos)

### 2.1 Telegram
- [ ] Receber: `edited_message`, `callback_query`, `channel_post`, voz, áudio, documento, sticker, localização, contato
- [ ] Enviar: `sendPhoto`, `sendDocument`, `sendVoice`/`sendAudio`, reply-to
- [ ] Criar inbox só com Bot Token (nome vem do bot) + página final com QR (`settings/inbox/channels/Telegram.vue`, `FinishSetup.vue`)

### 2.2 WhatsApp Cloud API
- [ ] Adapter atrás do `channels.Channel`: verify token, ingest assíncrono, mídia via storage, sender no River
- [ ] Recibos (sent/delivered/read/failed) refletidos na UI
- [ ] Templates: sincronizar, listar, enviar com variáveis; regra das 24h
- [ ] Criar inbox pelo formulário manual (`channels/CloudWhatsapp.vue`: nome, telefone, phone ID, WABA, API key) — embedded signup fica pós-v1
- [ ] Aba Configuration: webhook URL, verify token, trocar API key, business management token, "Sync templates"
- [ ] Aba Account health (`components/AccountHealth.vue`)
- [ ] Página Settings → Templates (`settings/templates/Index.vue`): filtros, sync, drawer de preview

**DoD Marco 2:** conversa real texto + foto + áudio + documento nos dois sentidos, em menos de 3s,
nos dois canais; template do WhatsApp fora da janela; recibos na UI.

---

## Marco 3 — Settings essenciais (1:1, sem menu interno)

Ref.: `routes/dashboard/settings/*`. Cada página é uma rota própria (convenção rota = arquivo).
- [ ] **Account (General):** nome, idioma, ID da conta com cópia, build info (`settings/account/Index.vue`)
- [ ] **Profile:** foto, nome, display name, e-mail, idioma da interface, tamanho da fonte, assinatura, tecla de envio, troca de senha, alertas sonoros, preferências de notificação, access token (`settings/profile/Index.vue`)
- [ ] **Agents:** lista (avatar + status, papel, verificado), convidar, editar (nome, papel, disponibilidade, reset de senha), excluir (`settings/agents/Index.vue`)
- [ ] **Teams:** lista, assistente criar → adicionar agentes → concluir, edição (`settings/teams/`)
- [ ] **Inboxes:** lista, assistente Canal → Inbox → Agentes → Concluir (só WA/TG), abas Settings / Collaborators / Business hours / CSAT / Configuration (`settings/inbox/Settings.vue`)
  - [ ] Collaborators: agentes da inbox, auto-assignment, limite máximo
  - [ ] Business hours: fuso, dias e horários, mensagem fora do horário (`WeeklyAvailability.vue`)
  - [ ] CSAT: tipo (emoji/estrela), mensagem, regra por etiqueta; template WhatsApp
  - [ ] Greeting, lock to single conversation
- [ ] **Labels:** tabela + modal (nome, descrição, cor, mostrar na sidebar)
- [ ] **Custom attributes:** abas Conversation/Contact, tipos (texto, número, link, data, lista, checkbox), regex
- [ ] **Canned responses:** tabela + modal (short code, conteúdo)

**DoD Marco 3:** um admin configura a conta do zero (inbox WA/TG, time, agentes, etiquetas, canned)
só pelas telas, que batem com o Chatwoot.

---

## Marco 4 — Contatos e empresas 1:1

Ref.: `components-next/Contacts/`, `components-next/Companies/`, `routes/dashboard/contacts|companies`
- [ ] Lista de contatos com a paleta `n-*`: cards, busca, ordenação, filtros avançados
  - Feitos: cards, busca (Load more), ordenação em `ui_settings`, paginação. Faltam filtros avançados e seleção em massa.
  - [x] Seta do card expande a edição rápida (dados e redes sociais), atualização pela API e exclusão com confirmação para administradores.
- [ ] Rotas Active, Segments (filtro salvo) e "Tagged with" (etiqueta) + sidebar
  - "Tagged with" pronto e conferido no browser: seção na sidebar e `/app/contacts?label=` (lista filtrada, título `#etiqueta`). A busca ignora a etiqueta, como o `contacts#search` do Chatwoot. Faltam Active e Segments.
- [ ] Criar contato (`CreateNewContactDialog.vue`), import/export CSV (`ContactImportDialog.vue`, `ContactExportDialog.vue`)
- [ ] Detalhe do contato: "Send message" (nova conversa — `NewConversation/ComposeConversation.vue`)
- [ ] Detalhe do contato: avatar (upload/excluir)
- [ ] Empresas: lista e detalhe 1:1, `CompanySelector` com criação inline
  - [x] Lista com cards, busca por nome/domínio (debounce 300ms), paginação de 25, ordenação em `ui_settings`, criação e rotas na sidebar; API Go index/search/create/show escopada pela conta.
  - [x] Detalhe com edição de nome/domínio/descrição, validação, atualização e exclusão com confirmação para administradores; API PUT/PATCH/DELETE por conta. Renomear sincroniza o nome nos contatos; excluir desvincula sem apagar contatos.
  - [x] Avatar com upload PNG/JPEG/GIF/WebP, leitura autenticada, substituição e exclusão; catálogo ActiveStorage e arquivos locais em `UPLOADS_DIR` (volume persistente em produção).
  - [x] Painel de contatos paginado com busca, confirmação de vínculo/reassociação, remoção e navegação ao contato; contagens e nomes sincronizados por conta.
  - [x] Histórico (20 conversas, respeitando inboxes do agente) e notas (20 mais recentes) agregados dos contatos vinculados, com navegação para conversa/contato.
  - [x] `CompanySelector` no formulário de contato, com busca, criação inline pelo diálogo, seleção e desvinculação salvas em `company_id`.
  - Faltam atributos personalizados de empresas (definições e editor) e favicon automático; marco completo ainda não concluído.
  - Desvio v1: sincronização de nomes e exclusão são transações locais síncronas; avatar usa arquivos locais com catálogo ActiveStorage; callbacks externos ainda não portados.
  - Desvio v1: empresas disponíveis em todas as contas; gate `feature_flags` da conta ainda não portado. Favicon automático aguarda jobs River de avatar.
- [ ] Nova conversa a partir da sidebar (botão de compose)

---

## Marco 5 — Tempo real, notificações e produtividade

### 5.1 Tempo real
- [ ] Eventos equivalentes ao ActionCable (`FE/helper/actionCable.js`): message.created/updated, conversation.created/updated/status_changed/read/typing_on/off/mentioned, assignee.changed, contact.updated/deleted, presence.update, notification.created/updated/deleted
- [ ] Presence de agentes (online/busy/offline) e auto-offline
- [ ] Contadores de não lidas na sidebar (inbox, etiqueta, time, pastas)

### 5.2 Notificações
- [ ] Tela Inbox (`routes/dashboard/inbox/`): lista, conversa inline, ordenação, lidas/snoozed, marcar tudo lido, excluir
- [ ] Tipos: criação, atribuição, nova mensagem (atribuída/participando), menção, SLA
- [ ] Alertas sonoros (tons, eventos, condições), badge no favicon
- [ ] Web push (depende do PWA: manifest + service worker + VAPID)

### 5.3 Produtividade
- [ ] Busca global (`modules/search/`): conversas, mensagens, contatos; buscas recentes (`/app/search`, ILIKE como o `SearchService` CE)
  - [ ] Filtros (remetente, inbox, período) — no Chatwoot só em Enterprise/Cloud com `advanced_search`
  - [ ] Chips de anexo/transcrição e "Read more" nos resultados de mensagem; abrir a conversa rolando até a mensagem (`messageId`)
  - [ ] Restringir resultados às inboxes do agente (`assigned_inboxes`) quando houver controle de acesso por inbox
- [ ] Command bar Cmd+K (`routes/dashboard/commands/commandbar.vue`) e modal de atalhos
- [ ] **Macros:** lista, editor de ações ordenáveis, visibilidade (`settings/macros/`)
- [ ] **Automation:** regras instantâneas e com espera, condições e ações (`settings/automation/`)
- [ ] **Conversation workflow:** auto-resolve (tempo, mensagem, etiqueta) e atributos obrigatórios
- [ ] **Agent bots:** cadastro, webhook, token; vínculo na inbox

---

## Marco 6 — Plataforma e compatibilidade de integração

- [ ] API v1 no formato do Chatwoot (paths e JSON), Bearer por `access_tokens`: conversations (+ messages, assignments, labels), contacts (+ notes, labels, contact_inboxes), inboxes, agents, teams, labels, canned, custom attributes, webhooks
- [ ] Webhooks de saída com os mesmos eventos (`app/models/webhook.rb`): conversation_created/updated/status_changed, message_created/updated, contact_created/updated, inbox_created/updated, typing on/off + HMAC
- [ ] Settings → Integrations: Webhooks (URL, eventos, secret) e Dashboard apps (iframe na conversa)
- [ ] Testes de contrato com fixtures reais do Chatwoot

## Marco 7 — Importador e cutover (fecha o v1)

Ver `ROTEIRO.md` §8 (importação preservando `display_id` e `source_id`, dry-run, relatório de
canais não suportados, guia de cutover).
**DoD v1:** conta real do Chatwoot (WA + TG) migrada abre, conversa e responde, com a UI 1:1 dos Marcos 1–6.

---

## Pós-v1

### 8. Relatórios
Ref.: `routes/dashboard/settings/reports/`
- [ ] Overview ao vivo (abertas, sem atendimento, sem agente, pendentes; status dos agentes; heatmaps)
- [ ] Conversations (métricas + gráficos + drill-down), Agents / Inboxes / Labels / Teams (resumo + detalhe)
- [ ] CSAT (métricas, distribuição, respostas), SLA, Bot; filtros de período/agrupamento/horário comercial; exportar CSV

### 9. Módulos adicionais
- [ ] SLA (políticas, badges, relatório) · Assignment policies (round-robin, capacidade)
- [ ] Campanhas WhatsApp (template, audiência por etiqueta, agendamento, analytics)
- [ ] Help center (portais, artigos, categorias, idiomas, página pública)
- [ ] Segurança: MFA/2FA, sessões ativas, audit logs, custom roles, SAML
- [ ] Data import (Intercom/Freshdesk), onboarding de conta, super admin
- [ ] Aparência (claro/escuro/sistema) e i18n pt-BR + demais locales
- [ ] Integrações: Slack, Linear, Notion, Shopify, Dialogflow/OpenAI
- [ ] Captain (IA) e Copilot

### Fora do plano
Outros canais (web widget, e-mail, Facebook, Instagram, SMS, Line, TikTok, Twilio), chamadas de voz,
billing do Chatwoot Cloud e embedded signup da Meta — o importador reporta, não implementa
(decisão do `ROTEIRO.md`).
