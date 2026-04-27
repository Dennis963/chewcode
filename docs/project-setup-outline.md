# ChewCode App - Project Setup Outline

## 1. Project goal

Build a Flutter-based remote OpenCode client that connects to a lightweight bridge, which in turn talks to `opencode serve`.

The current target is a usable remote control surface for:

- session list
- session detail
- messages
- todos
- question / permission handling
- prompt sending
- new session creation
- live invalidation through SSE
- runtime/context status
- current execution-state summary
- read-only file preview
- filename/text search
- lightweight current-session file browsing
- project registry and project-scoped runtime switching

The current build is a **single-user public beta** with a bearer-protected bridge boundary.

---

## 2. Repository layout

```text
chewcode_app/
├── apps/
│   └── mobile/                # Flutter app
├── packages/
│   └── opencode_remote/       # Shared Dart models + bridge client
├── services/
│   └── bridge/                # Fastify bridge for opencode serve
├── docs/
│   ├── project-setup-outline.md
│   └── detailed-architecture.md
├── README.md
└── melos.yaml
```

---

## 3. Environment prerequisites

Required:

- `opencode` CLI available in PATH
- Node.js 22+
- npm
- Flutter SDK

Recommended for local validation:

- Chrome or another Flutter-supported runtime target
- a clean local port for the bridge, for example `8080` or `8081`

---

## 4. Startup flow

### Step 1: Start OpenCode server

```bash
opencode serve --port 4096 --hostname 127.0.0.1
```

Notes:

- keep OpenCode itself behind the bridge
- public-beta auth is enforced at the bridge boundary, not in OpenCode itself

### Step 2: Start the bridge

```bash
cd services/bridge
npm install
npm run build
HOST=127.0.0.1 PORT=8080 BRIDGE_BEARER_TOKEN=replace-me node dist/index.js
```

Important env vars:

- `HOST`: defaults to `127.0.0.1`
- `PORT`: defaults to `8080`
- `OPENCODE_BASE_URL`: defaults to `http://127.0.0.1:4096`
- `BRIDGE_BEARER_TOKEN`: required bearer token for every bridge request
- `PROJECT_ALLOWED_ROOTS`: path-delimited list of allowed remote project roots
- `PROJECT_REGISTRY_FILE`: optional JSON file path for persisted project registry

### Step 3: Start the Flutter app

```bash
cd apps/mobile
flutter run --dart-define=BRIDGE_URL=http://127.0.0.1:8080
```

The app can also change and persist the bridge URL from inside the UI.
It now also stores an access token used for bridge authentication.

---

## 5. Bridge API outline

### Read APIs

- `GET /health`
- `GET /v1/projects/discover`
- `GET /v1/projects`
- `GET /v1/sessions`
- `GET /v1/sessions/:id/view`
- `GET /v1/sessions/:id/context-status`
- `GET /v1/sessions/:id/file`
- `GET /v1/sessions/:id/files`
- `GET /v1/sessions/:id/search`
- `GET /v1/attention`
- `GET /v1/events`

### Write APIs

- `POST /v1/projects/register`
- `POST /v1/projects/:id/open`
- `POST /v1/sessions`
- `POST /v1/sessions/:id/prompts`
- `POST /v1/questions/:id/reply`
- `POST /v1/questions/:id/reject`
- `POST /v1/permissions/:id/reply`

All read/write routes, `/health`, and SSE at `/v1/events` require `Authorization: Bearer <token>` in the public-beta model.

---

## 6. Validation workflow

### Bridge

```bash
cd services/bridge
npm test
npm run build
```

### Shared Dart package

```bash
cd packages/opencode_remote
flutter analyze
flutter test
```

### Flutter app

```bash
cd apps/mobile
flutter analyze
flutter test
flutter build web
```

### Live smoke checks

Recommended smoke checks:

- bridge `GET /health`
- `GET /v1/sessions`
- create a session through `POST /v1/sessions`
- verify `GET /v1/sessions/:id/view`
- verify `GET /v1/sessions/:id/context-status`
- verify `GET /v1/sessions/:id/file`
- verify `GET /v1/sessions/:id/files`
- verify `GET /v1/sessions/:id/search`
- verify SSE emits normalized events such as `session.created`

---

## 7. Stabilized V1 decisions

These decisions are now part of the stabilized V1 baseline:

- bridge defaults to `127.0.0.1`, not `0.0.0.0`
- health endpoint no longer exposes upstream URL
- bridge requires bearer auth for every route in the public-beta model
- malformed request bodies preserve 4xx behavior instead of being flattened into 500
- session creation with initial prompt is retry-safer via partial-success response
- SSE normalization now extracts nested event type and session ID
- empty/comment SSE frames are ignored
- app reconnects SSE after disconnect
- app has focused widget tests for session list and detail rendering

---

## 8. Deferred items before phase 2

Not part of stabilized V1 yet:

- context/state panel beyond todos + approvals
- background task model
- watch / control mode separation
- replay / snapshot semantics
- true streaming delta rendering in UI

These should be treated as phase-2 or later work, not implicit V1 behavior.

---

## 9. Phase 2 progress

The first phase-2 slice is now implemented.

Included:

- a dedicated context/runtime read model endpoint
- runtime panel rendering in Flutter
- execution-state fields derived from message parts:
  - current step
  - current tool + status
  - current subtask
  - retry attempt + retry error

Not yet included:

- richer context summary/body text
- diff/snapshot/revert visualization
- background job model
- watch/control separation

---

## 10. Recent shell polish

The latest shell pass focused on developer ergonomics rather than new bridge capability.

Delivered:

- ChewCode / 口香糖 naming in practical product and Flutter platform surfaces
- dark-by-default developer-oriented visual theme
- compact mobile session detail with tabbed Messages / Runtime / Todos / Attention access
- denser runtime/context summary and execution-now hierarchy
- clearer todo queue presentation by work state
- event-refresh coalescing to reduce visible flashing

---

## 11. Current next step

The current bridge now supports a **single-user public beta** auth boundary and a read-only file workflow.

Implemented:

- bridge-wide bearer token enforcement
- `/health` protection
- SSE protection on `/v1/events`
- app-side bridge token input and persistence
- read-only file preview
- filename search
- text search
- lightweight directory browsing
- session-root-scoped file boundaries
- project discovery / registration
- project-scoped runtime startup and switching
- project close / delete lifecycle

Still next:

- stronger public-beta deployment guidance
- richer project UX around status/health and lifecycle control
- more precise discover ranking between container directories and real project leaves

## 12. Mobile UI target spec

The currently agreed mobile UI target is:

- main/default view = session conversation content plus bottom input
- top UI limited to two compact rows
- left drawer = projects, nested sessions, account/connection, settings
- right drawer = session detail and files only
- session deletion belongs in the project/session hierarchy with confirmation
- Enter is the send action; redundant send buttons should not remain visible

## 13. Linux host service status

The systemd user service path has been tested with these results:

- `chewcode-opencode.service` can start the fixed host OpenCode runtime
- `chewcode-bridge.service` can start the fixed bridge process
- `8091` can answer bridge health and project list requests

Still unresolved:

- project-specific runtime spawning from inside the bridge supervisor still needs to use the configured absolute OpenCode binary path under systemd

So Linux host services are partially validated, but not yet fully complete for the whole multi-project lifecycle.
