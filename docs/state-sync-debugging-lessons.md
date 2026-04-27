# State/Sync Debugging Lessons

This note exists to prevent repeated failure when working on status strips,
runtime overlays, realtime token displays, and other sync-heavy UI.

## What went wrong

The repeated failure pattern was:

1. identify a plausible symptom-level cause
2. patch local mobile UI logic
3. get local tests passing
4. assume the device behavior should now be correct

That approach failed because the real problem was split across multiple layers:

- upstream semantics
- bridge mapping
- Dart model preservation
- mobile state selection
- device/runtime verification

## Main root causes

### 1. Wrong source-of-truth selection

Status behavior was repeatedly treated as if one local boolean could represent:

- active turn
- busy state
- overlay visibility
- token freshness

But upstream behavior is split. Different signals come from different sources.

### 2. Lossy bridge/model contracts

When upstream structure is flattened or reduced too early, the mobile UI cannot
reconstruct the intended runtime behavior later.

### 3. Local tests validated snapshots, not live truth

Fake clients and canned widget objects can confirm rendering, but they cannot
prove the app matches real streamed bridge/upstream behavior.

### 4. Device mismatch was not treated as hard failure soon enough

When the phone still behaved incorrectly, the feature should have been treated
as unfinished immediately, not as “almost fixed”.

## Rules for future work

### Rule 1: One authority per signal

Before changing UI, write down:

- active turn source
- busy state source
- token source
- context percentage source
- overlay visibility source

If more than one source is involved, define precedence explicitly.

### Rule 2: Contract first, UI second

If the required upstream field is not preserved in the bridge or Dart models,
fix that before touching widgets.

### Rule 3: Read upstream before porting semantics

For any behavior borrowed from OpenCode/TUI/app:

- inspect upstream selectors/stores/reducers/components
- confirm what actually drives the behavior
- do not approximate from memory

### Rule 4: Device disagreement beats local confidence

If local tests pass but the connected phone still behaves wrong:

- trust the device report
- reopen the feature
- stop saying the issue is fixed

### Rule 5: Add the missing test at the failing seam

Do not just add more widget assertions.
Add tests at the layer that actually failed:

- bridge contract tests
- mapper tests
- SSE parsing tests
- end-to-end sync tests

## Practical checklist for future state/sync bugs

- [ ] What is the exact upstream source of truth?
- [ ] Does the bridge preserve it without flattening away needed structure?
- [ ] Does the Dart model still carry it?
- [ ] Does the mobile UI read the correct source, or a fallback/guess?
- [ ] Is there a real-device/runtime verification path?
- [ ] Are local tests only validating fake snapshots?

If any answer is unclear, stop patching the UI and keep investigating.
