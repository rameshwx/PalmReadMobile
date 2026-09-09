# Flutter App (`flutter_app`)

Mobile client for PalmRead v1.

## Features
- Login/Register (email + password).
- Capture from camera or gallery.
- Quality gates: brightness and blur check before upload.
- Preview with handedness override.
- Upload progress + polling.
- Result screen with line overlay (`CustomPainter`) and deterministic IDs.
- History list and feedback form.

## Run
```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://api.example.invalid
```

## Dart Defines
- `API_BASE_URL`
- `POLL_INTERVAL_SECONDS`
- `UPLOAD_TIMEOUT_SECONDS`

The API endpoint must be supplied at build or run time. The `.invalid` URL above is
deliberately non-routable and is only a safe placeholder.

Example with explicit polling and timeout:
```bash
flutter run \
  --dart-define=API_BASE_URL=https://api.example.invalid \
  --dart-define=POLL_INTERVAL_SECONDS=2 \
  --dart-define=UPLOAD_TIMEOUT_SECONDS=30
```
