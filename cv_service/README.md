# CV Service (`cv_service`)

CPU-only deterministic palm line analyzer built with FastAPI + OpenCV.

## Endpoint
- `POST /analyze`
- `GET /health`

## Analyze Request
```json
{
  "local_path": "/data/palms/uploads/2026/02/11/hand.jpg",
  "handedness_hint": "left",
  "correlation_id": "d2f9fd0a-1964-4712-8f7f-56dd13f45f08"
}
```

## Run Locally
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8001
```

## Environment Variables
- `CV_HOST=0.0.0.0`
- `CV_PORT=8001`
- `CV_MAX_IMAGE_SIDE=1600`
- `CV_ROI_SIZE=512`
- `CV_TIMEOUT_MS=8000`
- `CV_NUM_THREADS=1`
- `PYTHONHASHSEED=0`
- `LOG_LEVEL=INFO`

## Determinism Notes
- Fixed seeds for `random` and `numpy`.
- OpenCV threads forced to 1 and OpenCL disabled.
- Signature hash computed from canonical JSON of quantized buckets.
