from typing import List, Tuple

import cv2
import numpy as np


class PalmPreprocessor:
    def run(self, roi_bgr: np.ndarray) -> np.ndarray:
        # Keep `run()` as the default best-effort path for callers that don't
        # care about variants.
        return self.run_variants(roi_bgr)[0][1]

    def run_variants(self, roi_bgr: np.ndarray) -> List[Tuple[str, np.ndarray]]:
        gray = cv2.cvtColor(roi_bgr, cv2.COLOR_BGR2GRAY)

        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        norm = clahe.apply(gray)

        # Light blur to reduce sensor noise without erasing fine creases.
        blur = cv2.GaussianBlur(norm, (3, 3), 0)

        return [
            ("edges", self._edges_variant(blur)),
            ("blackhat", self._blackhat_variant(blur)),
            ("adaptive_inv", self._adaptive_inv_variant(blur)),
        ]

    def _edges_variant(self, blur: np.ndarray) -> np.ndarray:
        """
        Edge-forward variant. Works well for high-contrast palms and avoids
        hallucinating lines on flat backgrounds.
        """
        lap = cv2.Laplacian(blur, cv2.CV_32F, ksize=3)
        lap = cv2.convertScaleAbs(lap)

        edges = cv2.Canny(blur, 30, 105)
        merged = cv2.addWeighted(lap, 0.65, edges, 0.35, 0)

        _, binary = cv2.threshold(merged, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        kernel = np.ones((3, 3), np.uint8)
        clean = cv2.morphologyEx(binary, cv2.MORPH_OPEN, kernel, iterations=1)
        clean = cv2.morphologyEx(clean, cv2.MORPH_CLOSE, kernel, iterations=1)

        return clean

    def _blackhat_variant(self, blur: np.ndarray) -> np.ndarray:
        """
        Blackhat enhances dark creases on lighter skin (common for palm lines),
        improving recall on softer lighting.
        """
        k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (17, 17))
        blackhat = cv2.morphologyEx(blur, cv2.MORPH_BLACKHAT, k)

        # Merge a little edge signal to keep structure on very flat images.
        edges = cv2.Canny(blur, 28, 100)
        merged = cv2.addWeighted(blackhat, 0.78, edges, 0.22, 0)

        _, binary = cv2.threshold(merged, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        kernel = np.ones((3, 3), np.uint8)
        clean = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel, iterations=2)
        clean = cv2.morphologyEx(clean, cv2.MORPH_OPEN, kernel, iterations=1)
        return clean

    def _adaptive_inv_variant(self, blur: np.ndarray) -> np.ndarray:
        """
        Adaptive thresholding on inverted intensity favors thin dark ridges.
        This is a good fallback when global thresholding fails.
        """
        inv = cv2.bitwise_not(blur)
        binary = cv2.adaptiveThreshold(
            inv,
            255,
            cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY,
            31,
            4,
        )

        kernel = np.ones((3, 3), np.uint8)
        clean = cv2.morphologyEx(binary, cv2.MORPH_OPEN, kernel, iterations=1)
        clean = cv2.morphologyEx(clean, cv2.MORPH_CLOSE, kernel, iterations=2)
        return clean
