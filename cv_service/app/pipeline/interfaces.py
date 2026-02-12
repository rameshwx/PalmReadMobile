from dataclasses import dataclass
from typing import Dict, List, Literal, Protocol, Tuple

import numpy as np

Handedness = Literal["left", "right", "unknown"]


@dataclass
class RoiResult:
    roi: np.ndarray
    roi_meta: Dict[str, float]
    handedness: Handedness
    warnings: List[str]


@dataclass
class LineCandidate:
    key: Literal["life", "head", "heart", "fate", "sun"]
    confidence: float
    points_roi: List[Tuple[float, float]]


class HandDetector(Protocol):
    def detect(self, image_bgr: np.ndarray, roi_size: int, handedness_hint: Handedness) -> RoiResult:
        ...


class Preprocessor(Protocol):
    def run(self, roi_bgr: np.ndarray) -> np.ndarray:
        ...


class LineSelector(Protocol):
    def select(self, candidates: List[np.ndarray], roi_size: int) -> List[LineCandidate]:
        ...
