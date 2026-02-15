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
                # Keep this moderate to reduce false negatives on real palm photos.
                min_detection_confidence=0.70,
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

        landmarks = result.multi_hand_landmarks[0]
        pts = np.array(
            [(lm.x * image_w, lm.y * image_h) for lm in landmarks.landmark],
            dtype=np.float32,
        )
        if pts.shape[0] < 21:
            raise HandNotDetectedError("hand_not_detected_missing_landmarks")

        # Use the tight landmark bbox for heuristics (expanded crop bbox is computed later).
        x0 = float(np.min(pts[:, 0]))
        y0 = float(np.min(pts[:, 1]))
        x1 = float(np.max(pts[:, 0]))
        y1 = float(np.max(pts[:, 1]))

        bbox_w_tight = float(max(1.0, x1 - x0))
        bbox_h_tight = float(max(1.0, y1 - y0))
        bbox_area_px = float(bbox_w_tight * bbox_h_tight)

        image_area = float(image_w * image_h)
        if image_area > 0:
            frac = bbox_area_px / image_area
            # Too small: likely a false positive.
            if frac < 0.04:
                raise HandNotDetectedError("hand_not_detected_bad_bbox_area")

        hull = cv2.convexHull(pts)
        hull_area = float(cv2.contourArea(hull))
        fill_ratio = hull_area / bbox_area_px
        if fill_ratio < 0.08:
            raise HandNotDetectedError("hand_not_detected_low_landmark_fill")

        wrist = pts[0]
        tip_indices = [4, 8, 12, 16, 20]
        max_tip_dist = float(max(np.linalg.norm(pts[i] - wrist) for i in tip_indices))
        if max_tip_dist < (0.22 * max(bbox_w_tight, bbox_h_tight)):
            raise HandNotDetectedError("hand_not_detected_short_finger_span")

        # Prefer a palm-focused crop for line extraction.
        # Using all landmarks (including fingertips) makes y-position heuristics
        # unstable and increases background noise.
        palm_indices = [0, 1, 2, 5, 9, 13, 17]  # wrist + palm base joints
        palm_pts = pts[palm_indices, :]

        px0 = float(np.min(palm_pts[:, 0]))
        py0 = float(np.min(palm_pts[:, 1]))
        px1 = float(np.max(palm_pts[:, 0]))
        py1 = float(np.max(palm_pts[:, 1]))

        bbox_w_palm = float(max(1.0, px1 - px0))
        bbox_h_palm = float(max(1.0, py1 - py0))

        # If the palm bbox degenerates (rare), fall back to full-hand bbox.
        use_palm_crop = (bbox_w_palm >= 0.35 * bbox_w_tight) and (bbox_h_palm >= 0.35 * bbox_h_tight)
        if use_palm_crop:
            warnings.append("roi_crop:palm")
            # Expanded palm crop bbox (padding relative to palm bbox size).
            pad_x = 0.26 * bbox_w_palm
            pad_y_top = 0.34 * bbox_h_palm
            pad_y_bottom = 0.26 * bbox_h_palm

            x_min = max(int(px0 - pad_x), 0)
            y_min = max(int(py0 - pad_y_top), 0)
            x_max = min(int(px1 + pad_x), image_w)
            y_max = min(int(py1 + pad_y_bottom), image_h)
        else:
            warnings.append("roi_crop:hand")
            # Expanded crop bbox (padding relative to tight landmark bbox size).
            pad_x = 0.18 * bbox_w_tight
            pad_y_top = 0.20 * bbox_h_tight
            pad_y_bottom = 0.22 * bbox_h_tight

            x_min = max(int(x0 - pad_x), 0)
            y_min = max(int(y0 - pad_y_top), 0)
            x_max = min(int(x1 + pad_x), image_w)
            y_max = min(int(y1 + pad_y_bottom), image_h)

        if x_max <= x_min or y_max <= y_min:
            raise HandNotDetectedError("hand_not_detected_invalid_bbox")

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
