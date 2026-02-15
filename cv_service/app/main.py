import logging
from typing import Optional

from fastapi import FastAPI, Header, HTTPException

from app.api.schemas import AnalyzeRequest, AnalyzeResponse
from app.core.config import get_settings
from app.core.logging import CorrelationLoggerAdapter, configure_logging
from app.pipeline.determinism import configure_determinism
from app.pipeline.exceptions import HandNotDetectedError, PalmLinesNotDetectedError
from app.pipeline.orchestrator import PalmAnalysisOrchestrator

settings = get_settings()
configure_logging(settings.log_level)
configure_determinism(settings.cv_num_threads)

logger = logging.getLogger("cv_service")
orchestrator = PalmAnalysisOrchestrator(
    max_image_side=settings.cv_max_image_side,
    roi_size=settings.cv_roi_size,
)

app = FastAPI(title="PalmRead CV Service", version="1.0.0")


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "service": "cv_service"}


@app.post("/analyze", response_model=AnalyzeResponse)
def analyze(payload: AnalyzeRequest, x_correlation_id: Optional[str] = Header(default=None)) -> AnalyzeResponse:
    correlation_id = payload.correlation_id or x_correlation_id or "none"
    log = CorrelationLoggerAdapter(logger, {"correlation_id": correlation_id})

    try:
        handedness_hint = payload.handedness_hint or "unknown"
        result = orchestrator.analyze(payload.local_path, handedness_hint=handedness_hint)
        log.info("Analysis complete", extra={"processing_ms": result["processing_ms"]})
        return AnalyzeResponse(**result)
    except (HandNotDetectedError, PalmLinesNotDetectedError) as exc:
        log.info("Rejected input", extra={"reason": str(exc)})
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except FileNotFoundError as exc:
        log.warning("Analyze failed file not found: %s", exc)
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:  # pragma: no cover - runtime safety
        log.exception("Analyze failed")
        raise HTTPException(status_code=500, detail=f"analysis_failed: {exc}") from exc
