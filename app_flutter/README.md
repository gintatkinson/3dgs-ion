# Platform Console (Flutter)

Generic UI shell that renders object types discovered at runtime.
No domain knowledge is compiled into the application.

## Run

```bash
flutter run -d macos
```

## Test

```bash
flutter test
flutter test -d macos integration_test/
```

## Data Source

Select backend at runtime:
- `flutter run` — SQLite (default)
- `flutter run --dart-define=DATA_SOURCE=firebase` — Firebase

## Dependencies

- `provider` — state management
- `sqflite_common_ffi` — SQLite
- `firebase_core` + `cloud_firestore` — Firebase
- `flex_color_scheme` — theming

## Performance Profiling Audit Loop

To execute the automated closed-loop performance and memory profiling audit:

```bash
python scripts/run_profile_audit.py
```

This script:
1. Runs the node iteration stress test on the macOS desktop target.
2. Traces frame times, garbage collection, and heap memory leak status.
3. Automatically creates a GitHub issue if frame build times exceed 16.6ms, memory growth (RSS delta) exceeds 25MB, or any VM-level memory leak/failures are detected.
