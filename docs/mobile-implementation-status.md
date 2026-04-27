# Mobile Implementation Status

This document records the current implementation state of the ChewCode mobile shell after the recent bugfix and UX alignment work.

It is intentionally split into **implemented**, **verified in local automation**, and **still requiring device/real-service confirmation** so we do not confuse code changes with confirmed user-visible outcomes.

## Implemented

### Session isolation

- Session view loading is scoped by `projectId + sessionId`
- Session context-status loading is scoped by `projectId + sessionId`
- Attention loading now guards against stale project switches
- Active-session stale async results are ignored when the selected project/session changes

### Download behavior

- Non-project session download route exists in the bridge
- Dart client download URI builder supports both project-scoped and non-project routes
- Mobile download action no longer hard-requires `projectId`
- Binary/non-previewable files now expose a download action in the file preview header

### Compact command support

- Typed `/compact` and `/summarize` no longer go through plain prompt send
- Mobile routes compact through a dedicated summarize API path
- A quick-action entry exists beside the composer for compacting context

### Token and context display

- Session context status exposes token metrics and context percentage
- Context percentage is derived by joining the latest assistant message `provider/model` to upstream provider catalog `limit.context`
- Mobile status display shows token count and context percentage

### Mobile status UI

- Removed the synthetic `等待下一步 / Waiting for the next step` fallback
- Added a bottom status strip above the composer
- Added a transient execution overlay for active-turn detail
- Status activation logic was revised toward upstream lifecycle semantics:
  - pending assistant message
  - or non-idle session status with the last message being a user turn

### Conversation behavior

- Sending a prompt inserts a local optimistic user message into the mobile conversation immediately

## Local automation verified

The following completed successfully in the current environment:

- `packages/opencode_remote/flutter test`
- `apps/mobile/flutter analyze`
- `apps/mobile/flutter test`
- Android release APK build

Latest release artifact path:

- `apps/mobile/build/app/outputs/flutter-apk/app-release.apk`

## Still requiring real-device / real-service confirmation

These areas have code changes and local test coverage, but should still be treated as requiring live confirmation against the connected phone and actual bridge/upstream runtime:

- Session progress strip timing
- Transient overlay visibility timing
- Realtime token freshness during active assistant output
- Binary file download UX for APK and other non-previewable files
- Exact alignment with upstream TUI feel during active generation

## Known environment limitations during this work

- Bridge Node tests were not executable here because `npm` is unavailable in the environment
- TypeScript LSP diagnostics were not available because `typescript-language-server` is not installed in the environment

## Important interpretation note

For active-turn state and token freshness, upstream OpenCode behavior is message-driven and status-driven, not purely context-status-driven.

That means:

- a turn is considered active when there is a pending assistant message, or the session status is non-idle while the last message is a user turn
- token metrics become freshest on assistant message updates / step-finish usage updates, not from arbitrary text-delta polling alone

Any future fixes in this area should keep following upstream lifecycle semantics instead of relying on ad-hoc local heuristics.
