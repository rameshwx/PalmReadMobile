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
flutter run --dart-define=API_BASE_URL=http://51.255.201.31:8080
```

## Dart Defines
- `API_BASE_URL`
- `POLL_INTERVAL_SECONDS`
- `UPLOAD_TIMEOUT_SECONDS`

Current deployed API endpoint:
- `http://51.255.201.31:8080`

Example with explicit polling and timeout:
```bash
flutter run \
  --dart-define=API_BASE_URL=http://51.255.201.31:8080 \
  --dart-define=POLL_INTERVAL_SECONDS=2 \
  --dart-define=UPLOAD_TIMEOUT_SECONDS=30
```
