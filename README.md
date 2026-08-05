# ZapMoney Flutter

Migrated from React Native `zap-money-frontend/master` (feature-by-feature).

## Phase 1 (current)

- Clean Architecture scaffold
- Dio + `token` header + API lock + guest/refresh tokens
- Splash → Onboarding → Login → OTP → ScreenStatus resume
- Biometrics resume for stored sessions
- Placeholder routes for later funnel screens

See [docs/MIGRATION_REPORT.md](docs/MIGRATION_REPORT.md).

## Run

```bash
fvm use 3.44.2
fvm flutter pub get
fvm dart run build_runner build
fvm flutter test
# Prefer release when judging performance:
fvm flutter run --release --dart-define=FLAVOR=dev --dart-define=BASE_URL=https://your-api
```

Heavy Lottie/PNG files used by the old RN app live under `assets/_unused_heavy/` and are **not** bundled. Splash uses a small Lottie; onboarding uses ~70KB PNGs.

Use `.env.example` as a checklist for dart-defines. Do not commit secrets.
