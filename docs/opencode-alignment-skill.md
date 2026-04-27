# OpenCode Alignment Skill

This document is the execution spec for aligning the ChewCode mobile shell with
upstream OpenCode/TUI behavior for:

- status strip behavior
- execution overlay behavior
- context window usage display
- transcript/message rendering

It exists specifically to stop heuristic UI patching and to force contract-first
alignment.

---

## Goal

Make the local mobile app behave as close as practical to upstream OpenCode/TUI
for runtime state and transcript rendering by aligning the bridge contract,
Dart models, mobile selectors, and rendering rules.

This is **not** a minimal patch plan.
It is the best-alignment plan.

---

## Evidence anchors

This plan is based on the following already-reviewed sources.

### Local anchors

- `services/bridge/src/types.ts`
- `services/bridge/src/mappers.ts`
- `services/bridge/src/server.ts`
- `services/bridge/src/sse.ts`
- `packages/opencode_remote/lib/src/models.dart`
- `packages/opencode_remote/lib/src/bridge_client.dart`
- `apps/mobile/lib/main.dart`

### Local discipline docs

- `docs/execution-discipline.md`
- `docs/state-sync-debugging-lessons.md`

### Upstream OpenCode anchors already established

#### Status / active turn / busy

- TUI/app active turn is message-list driven around pending assistant messages
- busy/idle/retry is session-status driven
- prompt/busy footer behavior uses `status.type !== "idle"`

#### Usage / context window

- usage is derived from the latest assistant message usage
- context limit comes from provider model metadata (`limit.context`)
- percentage is computed from `used / limit`

#### Transcript rendering

- upstream rendering is part-type sensitive
- upstream does not simply render every non-text block raw
- some part types are skipped or hidden by rule (`patch`, `step-start`,
  `step-finish`, etc.)

---

## Evidence vs proposal

The sections below intentionally mix two kinds of content:

- **evidence-backed facts** from the current local repo and previously reviewed
  upstream code
- **proposed redesign decisions** that follow from those facts

Whenever a section prescribes a new contract shape, selector model, or display
taxonomy, treat that as a proposal to implement, not as an already-proven
upstream fact.

---

## Current local mismatch summary

### 1. Transcript contract is still too lossy

Local bridge transcript data is still primarily flattened into:

- `MessageBlock.kind`
- `MessageBlock.text`

This loses the richer part semantics upstream uses to decide what should be
visible, hidden, or collapsed.

### 2. Runtime state is split across multiple derived surfaces

The local app currently mixes:

- message-derived activity
- session status
- context-status execution fields
- local UI heuristics

This makes the strip and overlay easy to drift out of sync.

### 3. Usage display is closer than before, but still depends on a bridge/UI mix

The right-side usage display now reflects window usage semantics correctly, but
the underlying model still mixes:

- latest assistant usage
- context-status fallback

That is acceptable as an interim fallback, but not the best long-term contract.

---

## Required source-of-truth split

Do **not** collapse these into one boolean or one DTO field.

| UI concern | Authority |
|---|---|
| Active turn | `SessionView.messages` pending assistant semantics |
| Busy state | `SessionContextStatus.status` |
| Context usage | latest assistant message `usage` + provider `limit.context` |
| Overlay content | explicit execution state fields from `SessionContextStatus` |
| Transcript visibility | typed `parts[]` display rules |

---

## Best alignment architecture

### Phase 1 - Bridge contract redesign

#### Objective

Stop using flattened `MessageBlock[]` as the primary transcript contract.

#### Required changes

1. In `services/bridge/src/types.ts`
   - keep `ConversationMessage`, but replace the transcript payload shape with:
     - `parts: ConversationPart[]`
     - `usage: UsageMetrics | null`
   - add explicit typed part model. The following list is a **proposal based on
     evidenced upstream/local part usage**, not a proven exhaustive taxonomy:
     - `text`
     - `file`
     - `reasoning`
     - `tool`
     - `patch`
     - `step-start`
     - `step-finish`
     - `subtask`
     - `retry`
     - `meta`
   - preserve enough upstream fields to support display rules without recomputing
     raw semantics in Flutter.

2. In `services/bridge/src/mappers.ts`
   - replace `mapMessageBlocks()/mapMessageBlock()/mapMessagePart()` as the main
     transcript shaping path
   - create a typed-part normalization layer instead
   - preserve upstream `part.type`
   - preserve fields needed for rendering and execution semantics
   - add one bridge-side display classification field if helpful, e.g.
     `display: inline | hidden | collapsed | overlay_only`.
     This `display` field is a **proposed local bridge aid**, not an upstream
     API fact.

3. In `services/bridge/src/server.ts`
   - keep `/view` as the authoritative transcript endpoint
   - keep `/context-status` as the authoritative runtime/execution metadata
   - do not duplicate transcript display logic inside `/context-status`

#### Acceptance

- `/view` carries typed transcript parts, not only flattened blocks
- usage is attached to the assistant message contract directly
- bridge tests prove at least one real upstream payload per important part type

---

### Phase 2 - Dart mirror redesign

#### Objective

Make `packages/opencode_remote` a thin mirror of the bridge contract.

#### Required changes

1. In `packages/opencode_remote/lib/src/models.dart`
   - add `ConversationPart`
   - add `UsageMetrics`
   - update `ConversationMessage` to use typed parts + usage
   - keep `SessionContextStatus` as runtime metadata only

2. In `packages/opencode_remote/lib/src/bridge_client.dart`
   - keep fetch methods mostly unchanged
   - do not add domain logic here

#### Acceptance

- Dart models preserve the bridge transcript/runtime split exactly
- no mobile-only semantics leak into the shared client/model layer

---

### Phase 3 - Mobile selector/state layer

#### Objective

Stop having widgets derive runtime semantics directly from raw DTOs.

#### Required changes

Create one session-scoped selector layer in `apps/mobile/lib/main.dart` or a
small extracted mobile state file that outputs:

- `activeTurn`
- `busyState`
- `latestUsage`
- `overlayModel`
- `visibleTranscript`

#### Rules

- `activeTurn` is based on message semantics (pending assistant)
- `busyState` is based on `SessionContextStatus.status`
- `latestUsage` is based on latest assistant `usage`
- `overlayModel` is based on `SessionContextStatus`
- transcript visibility is based on typed part display rules, not generic
  `kind != text`

#### Acceptance

- remove or retire helpers that guess across sources, including current patterns
  like:
  - `_hasUpstreamActiveTurn`
  - `_latestAssistantUsageMessage`
  - generic non-text block dumping

---

### Phase 4 - Transcript rendering rules aligned to upstream

#### Objective

Show only what OpenCode/TUI effectively shows by default.

#### Required rendering policy

The policy below should be read as **best-fit alignment guidance** derived from
reviewed upstream behavior, not as a verbatim upstream enum table.

1. Strongly evidenced as visible by default:
   - user text
   - assistant text
   - file parts / file chips where appropriate

2. Controlled by explicit visibility rules:
   - reasoning
   - tool details
   - generic tool output

3. Strongly evidenced as hidden/skipped by default unless explicitly needed:
   - `patch`
   - `step-start`
   - `step-finish`
   - synthetic-only helper text
   - raw meta payload dumps

#### Acceptance

- mobile transcript no longer dumps every non-text block raw
- transcript behavior is traceable to explicit part-type rules

---

### Phase 5 - Strip and overlay behavior

#### Objective

Make strip and overlay consume the selector outputs only.

#### Status strip rules

- animation state = derived from `busyState` + active-turn policy
- right-side text = `used/limit · percent`
- no local heuristic fallback that overrides selector truth

#### Overlay rules

- visibility = selector output, not ad-hoc widget logic
- content = execution fields only
- transcript content must not be duplicated into overlay

#### Acceptance

- strip/overlay source-of-truth is explicit and singular per signal

---

## Event model rules

Evidence today supports this narrower statement:

- SSE in the local app is currently treated primarily as an invalidation trigger
- `/view` and `/context-status` are then refreshed from mobile

The refresh priorities below are therefore **target-state guidance**, not a
description of the current fully-implemented behavior.

Use these refresh priorities:

- `message.*` -> refresh `/view` first
- `session.*` -> refresh session list + selected-session state as needed
- `todo.*` -> refresh `/view` + `/context-status`
- `question/permission.*` -> refresh attention

If active turn or busy state is live, selected-session refresh may continue on a
 short interval, but only as a bridge-backed synchronization fallback, not as a
 substitute for the correct state model.

---

## Detailed implementation plan

### Step 1
Add typed transcript part types to bridge `types.ts`.

### Step 2
Replace block-flattening in bridge `mappers.ts` with typed-part normalization.

### Step 3
Attach message-level usage explicitly to assistant messages in `/view`.

### Step 4
Update Dart mirror models in `packages/opencode_remote/lib/src/models.dart`.

### Step 5
Add/adjust bridge mapper tests for:
- typed part preservation
- skipped/hidden part types
- assistant usage on messages

### Step 6
Introduce a mobile selector layer for:
- active turn
- busy state
- latest usage
- overlay model
- visible transcript

### Step 7
Rebuild transcript UI to consume typed parts and visibility rules.

### Step 8
Rebuild strip and overlay to consume selector outputs only.

### Step 9
Verify on device before calling the work complete.

---

## Test requirements

Before calling this alignment done, add tests at these seams:

### Bridge tests
- typed part preservation for evidenced part types
- assistant usage on `/view`
- status source precedence
- visibility classification only for part types with explicit reviewed evidence

### Dart model tests
- typed part parsing
- usage parsing on `ConversationMessage`

### Mobile tests
- transcript only shows allowed default content
- hidden/collapsed parts do not render inline by default
- strip consumes `used/limit · percent`
- overlay visibility follows selector output

### Device verification
Required before declaring success:

- status strip timing matches expected active turn behavior
- overlay appears/disappears at the right time
- token/context values on screen match expected window usage semantics
- transcript no longer shows extra raw meta output

---

## Stop conditions

Do not proceed to UI polish if any of these are still unclear:

- which layer owns transcript truth
- whether a part type should be visible, hidden, or collapsed
- whether a value comes from assistant usage or context-status
- whether active turn is message-driven or status-driven

If unclear, return to source evidence first.

---

## Definition of done

This alignment is complete only when:

1. bridge preserves enough upstream structure to support correct transcript and
   status behavior
2. Dart models mirror that structure without re-interpretation
3. mobile selectors define one authority per signal
4. transcript rendering matches upstream default visibility rules closely
5. strip and overlay no longer depend on ad-hoc local heuristics
6. local tests pass
7. device verification passes
