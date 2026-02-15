import os
import time
from typing import Any, Dict, Literal

import cv2
import numpy as np

from app.pipeline.features import compute_features
from app.pipeline.hand_detector_mediapipe import MediaPipeHandDetector
from app.pipeline.line_selector_heuristic import HeuristicLineSelector
from app.pipeline.polyline import simplify_and_map_lines
from app.pipeline.preprocess import PalmPreprocessor
from app.pipeline.quantizer import quantize_features
from app.pipeline.signature import compute_hand_signature_hash
from app.pipeline.skeleton_graph import extract_candidate_paths
from app.pipeline.exceptions import PalmLinesNotDetectedError

Handedness = Literal["left", "right", "unknown"]


class PalmAnalysisOrchestrator:
    def __init__(self, max_image_side: int, roi_size: int) -> None:
        self.max_image_side = max_image_side
        self.roi_size = roi_size
        self.detector = MediaPipeHandDetector()
        self.preprocessor = PalmPreprocessor()
        self.selector = HeuristicLineSelector()

    def validate(self, local_path: str, handedness_hint: Handedness = "unknown") -> Dict[str, Any]:
        started = time.perf_counter()

        if not os.path.exists(local_path):
            raise FileNotFoundError(f"Image path not found: {local_path}")

        image_bgr = self._read_image_bgr(local_path)

        image_bgr = self._resize_if_needed(image_bgr)

        roi_result = self.detector.detect(image_bgr, self.roi_size, handedness_hint)
        binary = self.preprocessor.run(roi_result.roi)
        candidates = extract_candidate_paths(binary, self.roi_size)
        selected_lines = self.selector.select(candidates, self.roi_size)
        mapped_lines = simplify_and_map_lines(selected_lines, roi_result.roi_meta)

        detected_lines = sum(
            1
            for line in mapped_lines
            if not bool(line.get("missing", False)) and isinstance(line.get("points"), list) and len(line["points"]) >= 2
        )

        # Guardrail: If we can't extract at least a couple of lines, generating a "reading" is misleading.
        if detected_lines < 2:
            raise PalmLinesNotDetectedError("palm_lines_not_detected")

        warnings = list(roi_result.warnings)
        missing_count = sum(1 for line in mapped_lines if bool(line.get("missing", False)))
        if missing_count > 0:
            warnings.append(f"missing_lines:{missing_count}")

        processing_ms = int((time.perf_counter() - started) * 1000)

        return {
            "handedness": roi_result.handedness,
            "roi_meta": roi_result.roi_meta,
            "detected_lines": detected_lines,
            "processing_ms": processing_ms,
            "warnings": warnings,
        }

    def analyze(self, local_path: str, handedness_hint: Handedness = "unknown") -> Dict[str, Any]:
        started = time.perf_counter()

        if not os.path.exists(local_path):
            raise FileNotFoundError(f"Image path not found: {local_path}")

        image_bgr = self._read_image_bgr(local_path)

        image_bgr = self._resize_if_needed(image_bgr)

        roi_result = self.detector.detect(image_bgr, self.roi_size, handedness_hint)
        binary = self.preprocessor.run(roi_result.roi)
        candidates = extract_candidate_paths(binary, self.roi_size)
        selected_lines = self.selector.select(candidates, self.roi_size)

        mapped_lines = simplify_and_map_lines(selected_lines, roi_result.roi_meta)

        image_w = float(roi_result.roi_meta.get("image_w", image_bgr.shape[1]))
        image_h = float(roi_result.roi_meta.get("image_h", image_bgr.shape[0]))

        features = compute_features(mapped_lines, image_w=image_w, image_h=image_h)

        try:
            detected_lines = int(((features.get("global") or {}).get("detected_lines") or 0))
        except Exception:
            detected_lines = 0

        # Guardrail: If we can't extract at least a couple of lines, generating a "reading" is misleading.
        if detected_lines < 2:
            raise PalmLinesNotDetectedError("palm_lines_not_detected")

        quantized = quantize_features(features)
        signature_hash = compute_hand_signature_hash(quantized)

        warnings = list(roi_result.warnings)
        missing_count = sum(1 for line in mapped_lines if bool(line.get("missing", False)))
        if missing_count > 0:
            warnings.append(f"missing_lines:{missing_count}")

        processing_ms = int((time.perf_counter() - started) * 1000)

        return {
            "handedness": roi_result.handedness,
            "roi_meta": roi_result.roi_meta,
            "lines": mapped_lines,
            "features": features,
            "quantized_buckets": quantized,
            "hand_signature_hash": signature_hash,
            "processing_ms": processing_ms,
            "warnings": warnings,
        }

    def _resize_if_needed(self, image_bgr):
        h, w = image_bgr.shape[:2]
        long_side = max(h, w)
        if long_side <= self.max_image_side:
            return image_bgr

        scale = self.max_image_side / long_side
        new_w = max(1, int(w * scale))
        new_h = max(1, int(h * scale))
        return cv2.resize(image_bgr, (new_w, new_h), interpolation=cv2.INTER_AREA)

    def _read_image_bgr(self, local_path: str) -> np.ndarray:
        """
        OpenCV does not honor EXIF orientation. Most mobile camera images rely on EXIF
        rotation, so we transpose using Pillow when available.
        """
        try:
            from PIL import Image, ImageOps  # type: ignore

            with Image.open(local_path) as im:
                im = ImageOps.exif_transpose(im)
                im = im.convert("RGB")
                arr = np.asarray(im)
                bgr = cv2.cvtColor(arr, cv2.COLOR_RGB2BGR)
                return bgr
        except Exception:
            image_bgr = cv2.imread(local_path)
            if image_bgr is None:
                raise ValueError("Failed to read image.")  # noqa: B904
            return image_bgr
