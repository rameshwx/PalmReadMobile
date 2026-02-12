import cv2
import numpy as np


class PalmPreprocessor:
    def run(self, roi_bgr: np.ndarray) -> np.ndarray:
        gray = cv2.cvtColor(roi_bgr, cv2.COLOR_BGR2GRAY)

        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        norm = clahe.apply(gray)

        blur = cv2.GaussianBlur(norm, (3, 3), 0)

        lap = cv2.Laplacian(blur, cv2.CV_32F, ksize=3)
        lap = cv2.convertScaleAbs(lap)

        edges = cv2.Canny(blur, 35, 110)
        merged = cv2.addWeighted(lap, 0.65, edges, 0.35, 0)

        _, binary = cv2.threshold(merged, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        kernel = np.ones((3, 3), np.uint8)
        clean = cv2.morphologyEx(binary, cv2.MORPH_OPEN, kernel, iterations=1)
        clean = cv2.morphologyEx(clean, cv2.MORPH_CLOSE, kernel, iterations=1)

        return clean
