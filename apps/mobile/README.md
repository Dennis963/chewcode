# ChewCode Mobile

ChewCode (口香糖) is the Flutter client for the OpenCode bridge workspace.

## Getting started

Run the app from this directory with a bridge URL override when needed:

```bash
flutter run --dart-define=BRIDGE_URL=http://127.0.0.1:8080
```

The mobile client preserves the current bridge contract while exposing sessions,
messages, runtime/context state, attention handling, and todos in a touch-friendly shell.
