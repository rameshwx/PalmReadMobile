from typing import List

import cv2
import numpy as np


def _morphological_skeleton(binary: np.ndarray) -> np.ndarray:
    img = (binary > 0).astype(np.uint8) * 255
    skel = np.zeros_like(img)
    kernel = cv2.getStructuringElement(cv2.MORPH_CROSS, (3, 3))

    while True:
        eroded = cv2.erode(img, kernel)
        temp = cv2.dilate(eroded, kernel)
        temp = cv2.subtract(img, temp)
        skel = cv2.bitwise_or(skel, temp)
        img = eroded.copy()

        if cv2.countNonZero(img) == 0:
            break

    return skel


def extract_candidate_paths(binary_map: np.ndarray, roi_size: int) -> List[np.ndarray]:
    skeleton = _morphological_skeleton(binary_map)

    contours, _ = cv2.findContours(skeleton, cv2.RETR_LIST, cv2.CHAIN_APPROX_NONE)
    min_arc = roi_size * 0.12

    candidates: List[np.ndarray] = []
    for contour in contours:
        if contour.shape[0] < 8:
            continue

        arc = cv2.arcLength(contour, closed=False)
        if arc < min_arc:
            continue

        points = contour.reshape(-1, 2).astype(np.float32)
        candidates.append(points)

    candidates.sort(key=lambda pts: cv2.arcLength(pts.reshape(-1, 1, 2), closed=False), reverse=True)
    return candidates[:40]
