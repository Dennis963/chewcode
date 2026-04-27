# ChewCode Control Shell Skill

## Purpose

This file captures the current product/architecture intent of ChewCode so the project does not rely on chat history for its core direction.

ChewCode is a **mobile-first remote OpenCode control shell**, not a light IDE.

## Product stance

### What ChewCode is

- a remote control shell for OpenCode
- optimized for mobile-first monitoring and intervention
- public-beta oriented with a single-user trust boundary
- read-only for files

### What ChewCode is not

- not a full IDE
- not a file editor
- not a multi-user team platform yet
- not a local-only prototype anymore

## Current architectural rules

### Trust model

- bridge is the public entry point
- OpenCode stays behind the bridge
- every bridge route requires a shared bearer token in the current public beta
- `/health` and `/v1/events` are also protected

### State model

- **authoritative status first**
- runtime panel should prioritize fields that come directly from official OpenCode surfaces
- execution hints derived from message/event payloads must be visually demoted as advisory

### File model

- file access is read-only
- file preview/search/browse must stay inside the current session workspace root
- no fake cross-workspace access
- no editing or save operations

## Current capabilities

- session list / detail
- prompt sending
- question / permission handling
- runtime / attention / todo panels
- read-only file preview
- filename search
- text search
- lightweight current-session browsing
- session-root-scoped file access
- multi-project discovery / registration / opening
- project-scoped session and file access
- project close / delete lifecycle

## Current gaps

- stronger deployment and token rotation guidance
- richer runtime/state surfaces if OpenCode exposes them later
- project discovery quality still needs refinement when container directories and real project leaves overlap
- systemd host integration still needs the final supervisor runtime-spawn path fix

## Current architecture-level direction

The first **multi-project supervision** milestone is now implemented.

### Target experience

1. user opens ChewCode on mobile
2. user chooses a remote project/workspace
3. a supervisor on the Linux host starts or reuses the corresponding `opencode serve`
4. ChewCode shows that project's sessions
5. user switches projects from a drawer of opened workspaces
6. user can close or delete projects from the registry UI

### Constraints for that next step

- the mobile app is only a remote client, not the runtime host
- project directories live on the remote Linux host
- supervisor should validate which projects are allowed to open
- initial public-beta target is single-user, not multi-user

## Design guardrails

- do not drift toward a general-purpose IDE
- do not present heuristic execution state as authoritative truth
- do not expand file capabilities beyond read-only without an explicit product decision
- do not weaken session-root isolation for convenience

## Execution discipline

This project also follows the rules in `docs/execution-discipline.md`.

The most important operational constraints are:

- user-specified UI structure must be implemented literally
- partial progress must never be reported as completed work
- bridge/runtime status claims require process and route verification
- repetitive historical summaries should not replace direct bug fixing
