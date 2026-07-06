---
title: "Implementation Profile — Flutter"
project: "Digital Systems Engineering Pipeline"
tier: implementation
platform: flutter
created: "2026-06-29"
last_updated: "2026-06-29"
---

# Implementation Profile: Flutter

> This document governs feature implementation on Flutter only.
> Read alongside `.pipeline/constitution.md` (functional layer).

## Platform & Stack
- Framework: Flutter SDK 3.44.0 (stable channel)
- Language: Dart 3.12.0
- Forbidden dependencies: None explicitly prohibited. Evaluate each dependency for maintenance status and license compatibility.
- Required dependencies: `sqflite_common_ffi` (desktop SQLite), `firebase_core` + `cloud_firestore` (when targeting Firebase), `path_provider`, `http` (REST transport).

## Coding Standards
- Type safety: Use strict null safety. All variables must have explicit types; avoid `var` in public API signatures. Use `final` for immutable declarations.
- Naming conventions: Files — `snake_case.dart`. Directories — `snake_case`. Classes — `PascalCase`. Constants — `camelCase` with `const` keyword. Private members prefixed with `_`.
- Architecture pattern: MVVM (Model-View-ViewModel). Views are stateless widgets that consume ViewModels via dependency injection. ViewModels hold business logic and state. Models are data classes with serialization support.
- State management: Use `ChangeNotifier` + `ListenableBuilder` or `ValueListenableBuilder`. Avoid global state libraries unless justified by cross-cutting concerns.
- Dependency injection: Use constructor injection. Repository and DataSource instances are resolved at bootstrap via `RepositoryResolver`.

## Testing Mandates
- Unit tests: Required for all ViewModels, domain models, and data source adapters. Command: `flutter test`. Framework: `flutter_test`.
- Integration tests: Required for all user flows. Command: `flutter test -d macos integration_test/`. Framework: `integration_test` package.
- Widget tests: Required for custom widgets with non-trivial rendering logic.
- Benchmark thresholds: <10% regression against baseline for all performance metrics.
- TDD enforcement: Test-first approach required for all data layer and domain logic. UI tests may follow implementation.

## Build & Deployment
- Build command: `cd app_flutter && flutter build <platform>` where `<platform>` is `macos`, `linux`, `windows`, `web`, `android`, or `ios`.
- Lint command: `cd app_flutter && flutter analyze` (must pass with zero errors and zero warnings).
- CI/CD: Configured per repository settings. All pushes to integration branches trigger lint + unit test + integration test pipeline.
- Deployment target: Desktop (macOS, Linux, Windows) via direct bundle. Mobile (Android, iOS) via respective app stores when configured.

## Security & Ops
- API key management: API keys and secrets MUST NOT be committed to the repository. Use platform-specific secure storage (e.g., macOS Keychain, Android Keystore) or environment variables resolved at build time via `--dart-define`.
- Auth provider: Authentication is injected at the DataSource layer. The abstract `DataSource` interface does not prescribe an auth mechanism. Concrete implementations may use token-based, certificate-based, or unauthenticated access as appropriate.
- Data protection: All database files stored in the platform's application support directory. No sensitive data stored without encryption. Transport security (TLS) enforced for all remote data source connections.
- Logging: Structured logging via `dart:developer` in debug builds only. No personally identifiable information (PII) may be logged.
