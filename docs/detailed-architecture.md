# ChewCode App - Detailed Architecture

## 1. Architecture summary

The system uses a **thin app + smart bridge + existing OpenCode runtime** model.

```text
Flutter App
    ↓ HTTP / SSE
Bridge (Fastify)
    ↓ HTTP / SSE
opencode serve
    ↓
OpenCode runtime / session engine
```

The app is responsible for presentation and user interaction.
The bridge is responsible for protocol adaptation, normalization, and basic safety shaping.
OpenCode remains the system of record for session execution.

The bridge now also carries the first **multi-project supervisor** responsibility for the single-user public beta.

---

## 2. Why bridge exists

The bridge is needed because the app should not depend directly on raw upstream payload shapes.

Its responsibilities are:

1. normalize upstream responses into app-friendly models
2. expose a smaller stable contract to Flutter
3. turn OpenCode event traffic into app-invalidating SSE events
4. keep V1 independent from OpenCode source modifications
5. supervise multiple per-project OpenCode runtimes on the remote Linux host

This avoids building the app directly against unstable or overly detailed upstream response structures.

---

## 3. Runtime components

## 3.1 Flutter app (`apps/mobile`)

Current responsibilities:

- load and persist bridge URL
- render session list
- render session detail
- render messages
- render todos
- render pending questions and permissions
- render runtime/context panel
- render read-only file preview/search/browse flows
- render project list and project switching UI
- create session
- send prompt
- listen to SSE and refresh data

Current limitations:

- app state is still concentrated in one stateful screen
- refresh strategy is invalidation-driven, not incremental streaming
- background task state is not modeled yet
- selected-session stability under bursty event refresh still needs another pass

---

## 3.2 Shared Dart package (`packages/opencode_remote`)

This package defines the boundary between app and bridge.

Main contents:

- `SessionSummary`
- `SessionView`
- `SessionContextStatus`
- `FilePreview`
- `DirectoryListing`
- `FileSearchResult`
- `ConversationMessage`
- `TodoItem`
- `AttentionState`
- `PendingQuestion`
- `PendingPermission`
- `CreateSessionResult`
- `OpenCodeBridgeClient`

Purpose:

- keep HTTP and SSE parsing out of UI widgets
- centralize bridge contract decoding
- make phase-2 UI work build on stable client models

---

## 3.3 Bridge service (`services/bridge`)

### Layering

- `index.ts`: process startup
- `server.ts`: HTTP route definition and error handling
- `upstream.ts`: low-level calls to `opencode serve`
- `mappers.ts`: payload normalization
- `sse.ts`: event stream forwarding and normalization

### Bridge contract

#### Health

- `GET /health`

Returns minimal readiness information:

```json
{ "ok": true }
```

#### Sessions

- `GET /v1/sessions`
- `POST /v1/sessions`
- `GET /v1/sessions/:id/view`
- `GET /v1/sessions/:id/context-status`
- `POST /v1/sessions/:id/prompts`

#### Projects

- `GET /v1/projects/discover`
- `GET /v1/projects`
- `POST /v1/projects/register`
- `POST /v1/projects/:id/open`
- `POST /v1/projects/:id/close`
- `DELETE /v1/projects/:id`
- `GET /v1/projects/:projectId/sessions`
- `GET /v1/projects/:projectId/sessions/:id/view`
- `GET /v1/projects/:projectId/sessions/:id/context-status`
- `GET /v1/projects/:projectId/sessions/:id/file`
- `GET /v1/projects/:projectId/sessions/:id/files`
- `GET /v1/projects/:projectId/sessions/:id/search`
- `POST /v1/projects/:projectId/sessions/:id/prompts`
- `GET /v1/projects/:projectId/attention`
- `GET /v1/projects/:projectId/events`

#### Files

- `GET /v1/sessions/:id/file`
- `GET /v1/sessions/:id/files`
- `GET /v1/sessions/:id/search`

#### Attention

- `GET /v1/attention`
- `POST /v1/questions/:id/reply`
- `POST /v1/questions/:id/reject`
- `POST /v1/permissions/:id/reply`

#### Events

- `GET /v1/events`

---

## 4. Session creation semantics

Session creation is intentionally a **two-step bridge behavior**:

1. create session upstream
2. optionally send the initial prompt

This is reflected in `CreateSessionResult`:

```json
{
  "session": { ... },
  "started": true,
  "promptError": null
}
```

If step 1 succeeds but step 2 fails:

- request still returns `201`
- `started` becomes `false`
- `promptError` explains the bootstrap failure

This avoids unsafe duplicate retries where the client might accidentally create multiple sessions.

---

## 5. Event model

The bridge does not stream raw upstream frames directly to the UI.
It emits normalized bridge events:

```json
{
  "type": "session.created",
  "sessionId": "ses_xxx",
  "timestamp": "2026-04-15T06:00:33.469Z",
  "rawType": null,
  "payload": { ... }
}
```

### Current event normalization behavior

- emits `bridge.ready` on connect
- ignores empty/comment SSE frames
- extracts nested upstream event type from `payload.type`
- extracts session ID from nested `payload.properties.sessionID`

### Current app invalidation policy

The app only refetches on these event families:

- `session.*`
- `message.*`
- `todo.*`
- `question.*`
- `permission.*`

This is still invalidation-based, not delta-rendered.

---

## 6. Error handling design

### Bridge

Bridge differentiates between:

1. **Upstream errors** → `502 upstream_error`
2. **Fastify/framework request errors** → preserve original 4xx
3. **Unknown internal errors** → `500 internal_error`

This was added during stabilization because malformed JSON requests were previously being flattened into 500s.

For files, the bridge now treats OpenCode as the authority for session/workspace identity, but uses the local filesystem for read-only preview bytes when official upstream file-content responses are incomplete. Session-root validation remains enforced before reading from disk.

### App

App currently uses simple string error display through the connection banner and request-specific state flags.
This is sufficient for V1 but not yet ideal for structured UX.

---

## 7. Security and trust model

Current public-beta assumptions:

- bridge binds to `127.0.0.1` by default
- bridge uses one shared bearer token for all routes
- the product is single-user, not multi-user
- project directories live on the remote Linux host and must stay inside configured allowed roots

Implication:

This is now a **single-user internet-facing beta** rather than a trusted-local-only shell.

If the product later requires wider or multi-user exposure, the architecture must add:

- user/account auth and authorization
- secure endpoint trust model
- deployment guidance for TLS / tunnel / gateway setup

---

## 8. Stabilization fixes applied

The following issues were found during real review and fixed:

1. stale bridge build output caused runtime route mismatch
2. app had no SSE reconnect path
3. real upstream message payloads were mapped incorrectly
4. malformed request bodies returned incorrect 500 responses
5. session creation with initial prompt was retry-unsafe
6. SSE event normalization lost nested event type and session ID
7. bridge default host was too open for trusted-local V1
8. app-side test coverage was improved beyond shell-only render
9. bridge-wide bearer auth boundary was added for the single-user public beta
10. read-only file workflow was added with session-root-scoped preview/search/browse
11. bridge gained a first multi-project supervisor / project registry layer
12. project lifecycle controls were added for close/delete

---

## 9. Remaining known gaps

These are intentionally not solved in stabilized V1:

### Product/runtime gaps

- richer context summary/body text
- diff / snapshot / revert panel
- background job model
- control vs watch mode
- replay/snapshot semantics

### UX gaps

- incremental streaming message rendering
- richer loading/error states
- finer-grained refresh strategy
- stronger guarantees that a selected session remains visually stable during burst refreshes

### Architecture gaps

- app state still concentrated in one large widget
- bridge still lacks a multi-user authz model
- richer end-to-end app tests still desirable before major expansion
- project lifecycle UX is still minimal compared with the new supervisor backend
- project discovery ranking still prefers a permissive candidate list over a precise project-leaf list
- systemd host integration is still incomplete for project runtime spawning

---

## 10. Mobile shell target spec

The mobile shell should now be interpreted with these explicit rules:

- main/default view = session conversation content plus bottom input
- top UI limited to two compact rows
- left drawer = projects, nested sessions, account/connection, settings
- right drawer = session detail and files only
- no redundant session navigation affordances outside this structure
- session deletion belongs in the project/session hierarchy and requires confirmation
- Enter is the primary send action; no redundant send button should remain visible

This is a product requirement, not a best-effort styling preference.

## 11. Phase-2 entry recommendations

Phase 2 has already started with a first slice:

1. runtime/context status panel
2. current execution-state extraction from message parts

Recommended next order from here:

1. refine project discovery quality (container directories vs real project leaves)
2. strengthen project lifecycle UX and validation feedback
3. strengthen public-beta deployment/ops guidance
4. add project health and runtime diagnostics
5. only later consider multi-user expansion

This keeps phase 2 aligned with the original goal: a real remote OpenCode control surface, not just a chat shell.

## 12. Systemd host status

The Linux host systemd integration has been validated only partially.

### Confirmed working

- fixed host OpenCode runtime can be started by systemd
- fixed bridge process can be started by systemd
- `8091` can serve `/health` and `/v1/projects`

### Remaining failing area

- the bridge supervisor still needs to start per-project runtimes using the configured absolute OpenCode binary path

### Implication

The current systemd setup is sufficient for standing up the fixed host services, but it should not yet be treated as fully complete for the entire multi-project lifecycle.
