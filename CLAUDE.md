# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter app for **Grupo Solsumed** — sales and customer-visit management for salespeople (vendedores) and admins. Dart SDK `^3.10.4`, Material 3, targets Android / iOS / Web / Linux / macOS / Windows.

## Commands

```bash
flutter pub get                           # install deps
flutter run                               # run on default device
flutter run -d <device-id>                # run on specific device (flutter devices to list)
flutter analyze                           # static analysis (flutter_lints)
dart format .                             # format
flutter test                              # all tests
flutter test test/widget_test.dart        # single test file
flutter test --name "<pattern>"           # filter by test name
flutter build apk                         # Android APK
flutter build appbundle                   # Android AAB
flutter build ios / web / linux / macos / windows
dart run flutter_launcher_icons           # regenerate launcher icons from assets/logo.png
```

API base URL is **hardcoded** in `lib/core/env.dart` (`Env.apiBaseUrl`). Change there when pointing at a different backend — there is no `.env` loader.

## Architecture

### Offline-first dual-store

App is built around **SQLite as primary store**, with the REST API as a sync source. The split:

- **Local-only entities** (clientes, visitas, encuestas, respuestas, usuarios): live in SQLite via `sqflite`. Mutations write locally first; sync to API happens via `SyncService`.
- **Online entities** (productos, imágenes, dólar BCV, dashboard): fetched directly from API.

Auth has two layers:
1. **Local login** (`AuthService.login`) — validates against the `usuarios` SQLite table. Works offline. Master user is inserted on app startup in `main.dart` via `DatabaseHelper.insertarUsuarioMaestro`.
2. **Online JWT** (`SyncService.authenticateOnline` → `POST /auth/login`) — obtains a bearer token stored on `AuthService.onlineToken`, used by `GenericRepository` for API calls.

Sessions persist via `shared_preferences` (`_userDataKey`, `_isLoggedInKey`); `AuthService.tryAutoLogin` rehydrates from SQLite on launch.

### GenericRepository routing

`lib/repositories/generic_repository.dart` is the single I/O hub. Its dispatch rule on `getList` / `getById`:
- `path` arg → HTTP (`getListOnline` / `getByIdOnline`), uses `Env.apiBaseUrl` + bearer token from `AuthService`.
- `table` arg → SQLite (`getListLocal` / `getByIdLocal`).
- `insert` / `update` / `delete` always go local — sync to remote is `SyncService`'s job.

When adding a new entity:
- Local-only: add migration in `DatabaseHelper._createTables` + `onUpgrade`, then a thin repo in `lib/repositories/` calling `GenericRepository.instance` local methods.
- Online: extend the repo with API-specific endpoints (see `cliente_repository.dart` for the `fetchClientesFromApi` + `sincronizarClientes` pattern that bulk-inserts into SQLite).

API response shape handled: top-level list, `{data: [...]}`, `{data: {items|customers|records: [...]}}`, or `{customers|items: [...]}`. `nestedKey` overrides the default `data` key.

### SQLite migrations

`DatabaseHelper._initDatabase` uses `version: 4` with an `onUpgrade` that DROPs+recreates on `oldVersion < 3` and `ALTER`s columns on `< 4` / `< 5`. **Bump `version` whenever you add an `onUpgrade` branch** — the existing `if (oldVersion < 5)` block will not fire until version is bumped to ≥5. All `ALTER TABLE`s are wrapped in try/catch because SQLite has no `IF NOT EXISTS` for columns.

### UI: atomic design

`lib/` is split by Brad Frost's atomic design:
- `atoms/` — primitives (`app_button`, `app_text_field`, `status_badge`, `offline_banner`).
- `molecules/` — composed widgets (`stat_card`, `dolar_indicator`, charts).
- `organisms/` — page sections (`app_drawer`, `dashboard_content`, `connection_wrapper`).
- `pages/` — full screens routed from `main.dart` (entry: `LoginPage`).

`core/` holds theme/colors/env. `models/` are pure data classes with `fromJson` / `toJson`. Role gating in UI checks `AuthService.instance.isAdmin` / `isVendedor`.

### Singletons

All services and repositories are singletons (`SomeClass.instance`, private constructor). No DI container. State is held on these singletons (e.g. `AuthService._currentUser`, `AuthService._onlineToken`) — there is no Provider/Riverpod/Bloc.

## Notes

- `print` is used liberally for runtime tracing (emoji-prefixed). Don't strip these without checking — they are the debug-time observability surface.
- `connectivity_wrapper.dart` + `ConnectivityService` drive the offline banner; check `isConnected()` before invoking API paths.
- HTTP timeout convention: 30s on all `GenericRepository` calls.
- Asset list in `pubspec.yaml` must be updated when adding files to `assets/`; only `assets/logo.png` is currently declared.
