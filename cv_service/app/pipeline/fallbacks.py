from typing import Dict, List, Tuple

import cv2
import numpy as np


def center_crop_fallback(image_bgr: np.ndarray, roi_size: int) -> Tuple[np.ndarray, Dict[str, float], List[str]]:
    h, w = image_bgr.shape[:2]
    side = int(min(h, w) * 0.85)
    x0 = max((w - side) // 2, 0)
    y0 = max((h - side) // 2, 0)
    crop = image_bgr[y0 : y0 + side, x0 : x0 + side]

    if crop.size == 0:
        crop = image_bgr.copy()
        x0 = 0
        y0 = 0
        side = min(h, w)

    roi = cv2.resize(crop, (roi_size, roi_size), interpolation=cv2.INTER_AREA)
    meta = {
        "image_w": float(w),
        "image_h": float(h),
        "crop_x": float(x0),
        "crop_y": float(y0),
        "crop_w": float(crop.shape[1]),
        "crop_h": float(crop.shape[0]),
        "roi_size": float(roi_size),
        "rotation_deg": 0.0,
    }
    return roi, meta, ["fallback_center_crop"]
