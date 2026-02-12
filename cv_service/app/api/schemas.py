from typing import Any, Dict, List, Literal, Optional

from pydantic import BaseModel, Field


class AnalyzeRequest(BaseModel):
    local_path: str = Field(..., description="Absolute local path to image file")
    handedness_hint: Optional[Literal["left", "right", "unknown"]] = "unknown"
    correlation_id: Optional[str] = None


class Point(BaseModel):
    x: float
    y: float


class LineOverlay(BaseModel):
    key: Literal["life", "head", "heart", "fate", "sun"]
    confidence: float
    points: List[Point]
    missing: bool = False


class AnalyzeResponse(BaseModel):
    handedness: Literal["left", "right", "unknown"]
    roi_meta: Dict[str, Any]
    lines: List[LineOverlay]
    features: Dict[str, Any]
    quantized_buckets: Dict[str, Any]
    hand_signature_hash: str
    processing_ms: int
    warnings: List[str] = []
