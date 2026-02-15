from typing import List

import cv2
import numpy as np

from app.pipeline.exceptions import HandNotDetectedError
from app.pipeline.interfaces import Handedness, RoiResult

try:
    import mediapipe as mp
except Exception:  # pragma: no cover - import safety for minimal environments
    mp = None


class MediaPipeHandDetector:
    def __init__(self) -> None:
        self._hands = None
        if mp is not None:
            self._hands = mp.solutions.hands.Hands(
                static_image_mode=True,
                max_num_hands=1,
                model_complexity=1,
                min_detection_confidence=0.75,
            )

    def detect(self, image_bgr: np.ndarray, roi_size: int, handedness_hint: Handedness) -> RoiResult:
        warnings: List[str] = []

        if self._hands is None:
            raise RuntimeError("mediapipe_unavailable")

        image_h, image_w = image_bgr.shape[:2]
        rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
        result = self._hands.process(rgb)

        if not result.multi_hand_landmarks:
            raise HandNotDetectedError("hand_not_detected")

        detected_handedness: Handedness = "unknown"
        handedness_score = 0.0
        if result.multi_handedness:
            cls = result.multi_handedness[0].classification[0]
            label = (cls.label or "").lower()
            if label in ("left", "right"):
                detected_handedness = label  # type: ignore[assignment]
            handedness_score = float(getattr(cls, "score", 0.0) or 0.0)

        # Guardrail: if MediaPipe is unsure, treat it as "no hand" rather than generating junk.
        if handedness_score > 0 and handedness_score < 0.65:
            raise HandNotDetectedError("hand_not_detected_low_confidence")

        landmarks = result.multi_hand_landmarks[0]
        xs = [lm.x for lm in landmarks.landmark]
        ys = [lm.y for lm in landmarks.landmark]

        x_min = max(int((min(xs) - 0.18) * image_w), 0)
        y_min = max(int((min(ys) - 0.20) * image_h), 0)
        x_max = min(int((max(xs) + 0.18) * image_w), image_w)
        y_max = min(int((max(ys) + 0.22) * image_h), image_h)

        if x_max <= x_min or y_max <= y_min:
            raise HandNotDetectedError("hand_not_detected_invalid_bbox")

        bbox_area = float((x_max - x_min) * (y_max - y_min))
        image_area = float(image_w * image_h)
        if image_area > 0:
            frac = bbox_area / image_area
            # Too small: likely a false positive. Too large: likely a bad crop.
            if frac < 0.08 or frac > 0.98:
                raise HandNotDetectedError("hand_not_detected_bad_bbox_area")

        crop = image_bgr[y_min:y_max, x_min:x_max]
        roi = cv2.resize(crop, (roi_size, roi_size), interpolation=cv2.INTER_AREA)

        final_handedness: Handedness = detected_handedness
        if handedness_hint in ("left", "right"):
            final_handedness = handedness_hint

        meta = {
            "image_w": float(image_w),
            "image_h": float(image_h),
            "crop_x": float(x_min),
            "crop_y": float(y_min),
            "crop_w": float(crop.shape[1]),
            "crop_h": float(crop.shape[0]),
            "roi_size": float(roi_size),
            "rotation_deg": 0.0,
            "hand_score": handedness_score,
        }

        return RoiResult(roi=roi, roi_meta=meta, handedness=final_handedness, warnings=warnings)
