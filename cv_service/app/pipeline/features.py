from itertools import combinations
from typing import Dict, List, Tuple

import numpy as np


def _line_length(points: np.ndarray) -> float:
    if len(points) < 2:
        return 0.0
    deltas = np.diff(points, axis=0)
    return float(np.sqrt((deltas[:, 0] ** 2) + (deltas[:, 1] ** 2)).sum())


def _curvature(points: np.ndarray) -> float:
    if len(points) < 3:
        return 0.0
    deltas = np.diff(points, axis=0)
    angles = np.arctan2(deltas[:, 1], deltas[:, 0])
    turn = np.abs(np.diff(angles)).sum()
    return float(turn / np.pi)


def _continuity(points: np.ndarray) -> float:
    if len(points) < 2:
        return 0.0
    direct = float(np.linalg.norm(points[-1] - points[0]))
    path = _line_length(points) + 1e-6
    return float(max(0.0, min(direct / path, 1.0)))


def _segments_intersect(a1, a2, b1, b2) -> bool:
    def ccw(p1, p2, p3):
        return (p3[1] - p1[1]) * (p2[0] - p1[0]) > (p2[1] - p1[1]) * (p3[0] - p1[0])

    return ccw(a1, b1, b2) != ccw(a2, b1, b2) and ccw(a1, a2, b1) != ccw(a1, a2, b2)


def _intersection_count(line_a: np.ndarray, line_b: np.ndarray) -> int:
    if len(line_a) < 2 or len(line_b) < 2:
        return 0

    count = 0
    for i in range(len(line_a) - 1):
        for j in range(len(line_b) - 1):
            if _segments_intersect(line_a[i], line_a[i + 1], line_b[j], line_b[j + 1]):
                count += 1
    return count


def compute_features(lines: List[Dict[str, object]], image_w: float, image_h: float) -> Dict[str, object]:
    diag = float((image_w**2 + image_h**2) ** 0.5) + 1e-6

    features: Dict[str, object] = {}
    arrays: Dict[str, np.ndarray] = {}

    for line in lines:
        key = str(line["key"])
        points_raw = line.get("points", [])
        points = np.array([[float(p["x"]), float(p["y"])] for p in points_raw], dtype=np.float32)
        arrays[key] = points

        length = _line_length(points) / diag
        curv = _curvature(points)
        continuity = _continuity(points)

        features[key] = {
            "length": round(float(length), 6),
            "curvature": round(float(curv), 6),
            "continuity": round(float(continuity), 6),
            "intersections": 0,
            "mean_y_norm": round(float(points[:, 1].mean() / image_h), 6) if len(points) > 0 else None,
        }

    for a, b in combinations(["life", "head", "heart", "fate", "sun"], 2):
        c = _intersection_count(arrays.get(a, np.zeros((0, 2))), arrays.get(b, np.zeros((0, 2))))
        if a in features:
            features[a]["intersections"] = int(features[a]["intersections"]) + c
        if b in features:
            features[b]["intersections"] = int(features[b]["intersections"]) + c

    head_y = features.get("head", {}).get("mean_y_norm") if isinstance(features.get("head"), dict) else None
    heart_y = features.get("heart", {}).get("mean_y_norm") if isinstance(features.get("heart"), dict) else None
    life_y = features.get("life", {}).get("mean_y_norm") if isinstance(features.get("life"), dict) else None

    features["global"] = {
        "heart_head_gap": round(float(abs((heart_y or 0.0) - (head_y or 0.0))), 6) if heart_y is not None and head_y is not None else None,
        "head_life_gap": round(float(abs((head_y or 0.0) - (life_y or 0.0))), 6) if head_y is not None and life_y is not None else None,
        "detected_lines": int(sum(1 for k in ["life", "head", "heart", "fate", "sun"] if arrays.get(k, np.zeros((0, 2))).shape[0] >= 2)),
    }

    return features
