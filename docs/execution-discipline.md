# ChewCode Execution Discipline

This file exists to prevent repeated execution failures during development.

## Core rule

Do **not** treat partial progress as completion.

A task is only **completed** when all of the following are true:

1. the requested behavior is implemented in code
2. relevant tests and builds pass
3. user-visible behavior has been verified at runtime when possible

If any of the above is missing, the task must be reported as either:

- **unfinished**
- **blocked**

Never report it as done.

---

## Execution rules

### 1. User-specified structure wins

When the user gives an explicit UI or flow structure, execute it literally.

Do not replace it with:

- a "close enough" version
- a more convenient internal design
- a gradual approximation presented as final

### 2. Finish the current batch before expanding scope

Do not move to the next feature batch while the current one still has:

- known regressions
- failing tests
- unresolved runtime issues
- known mismatch against the user's stated design

### 3. Avoid repetitive summary noise

Do not keep repeating:

- old completed work
- previously explained causes
- background context the user already knows

Once the user reports a fresh bug, focus only on:

1. the exact current symptom
2. the root cause
3. the fix
4. what the user should test next

### 4. Bridge/runtime process claims require proof

Never say the bridge or OpenCode is "running" unless verified by:

- listening port check
- health check / route check
- process confirmation

If the process may have been replaced, terminated, or is stale, say so explicitly.

### 5. Testing standards

For user-facing changes, completion requires:

- `flutter analyze` clean
- relevant tests passing
- build succeeding
- if applicable, install/run verification

### 6. APK delivery standard

For mobile acceptance, do not say "latest APK is ready" unless:

1. APK was rebuilt after the latest relevant code changes
2. install succeeded or the exact blocking reason is known
3. the user has the exact URL/token/runtime values needed to test

### 7. State/sync debugging discipline

For status bars, overlays, realtime token displays, SSE-driven UX, or any other
runtime sync feature:

- **never** fix the UI first and hope the state model is close enough
- identify **one authoritative source** for each signal before editing widgets
- do not mix message-derived state, session status, context-status, and local
  heuristics into one "best guess" boolean
- if the bridge flattens or drops upstream structure, fix the contract before
  tweaking the app
- if upstream behavior is involved, read upstream code/docs first
- passing local widget tests is **not** evidence of a real-device fix
- when device behavior disagrees with local tests, treat the feature as
  **unfinished**, not "mostly fixed"

Required order of work:

1. identify the exact source of truth per signal
2. verify the bridge/client contract preserves it
3. add a failing contract or end-to-end test where possible
4. only then update the UI
5. verify on the real runtime/device path before calling it fixed

---

## Known failure modes in this project

### A. Repeated summaries instead of direct fixes

Bad pattern:
- restating already-known history after a new bug report

Required correction:
- answer the current bug directly

### B. Premature "done" statements

Bad pattern:
- saying a feature is finished when tests, runtime verification, or the exact requested UX are still incomplete

Required correction:
- mark it unfinished until all three completion conditions pass

### C. Bridge startup confusion

Bad pattern:
- assuming a service restart succeeded without proving the live port/process changed

Required correction:
- verify port, process, and route responses before handing it back to the user

### D. Design drift through approximation

Bad pattern:
- implementing something close to the user's layout while leaving old structures or redundant entry points in place

Required correction:
- remove conflicting old UI and match the user's chosen structure directly

### E. Heuristic runtime fixes without contract proof

Bad pattern:
- trying multiple local UI/state heuristics for status or token behavior before
  confirming what the upstream/bridge contract actually provides

Required correction:
- determine source-of-truth first
- confirm no required field is lost between upstream -> bridge -> Dart -> UI
- do not continue patching presentation logic until the contract is proven

---

## Mandatory self-check before saying "done"

Use this checklist every time:

- [ ] Did I implement exactly what the user explicitly asked for?
- [ ] Did I remove conflicting old UI/flows instead of layering on top?
- [ ] Are there any known regressions left?
- [ ] Did `analyze` pass?
- [ ] Did tests pass?
- [ ] Did build pass?
- [ ] If runtime matters, did I verify the actual runtime behavior?
- [ ] If I say a service is running, did I prove it with a port/health check?
- [ ] If this is a mobile handoff, is the APK definitely rebuilt after the latest code changes?
- [ ] Am I about to repeat old summary content instead of addressing the current issue?
- [ ] For status/sync/token bugs, have I identified a single source of truth per signal?
- [ ] Have I checked whether bridge/model mapping is dropping the field I need?
- [ ] If device behavior is still wrong, am I explicitly treating the feature as unfinished?

If any answer is "no", do not say the work is complete.
