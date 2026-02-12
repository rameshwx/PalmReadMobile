from typing import Dict, List, Tuple

import cv2
import numpy as np

from app.pipeline.interfaces import LineCandidate

LINE_KEYS = ["life", "head", "heart", "fate", "sun"]


def _path_metrics(points: np.ndarray, roi_size: int) -> Dict[str, float]:
    deltas = np.diff(points, axis=0)
    seg_lengths = np.sqrt((deltas[:, 0] ** 2) + (deltas[:, 1] ** 2))
    path_len = float(seg_lengths.sum()) + 1e-6

    mean_y = float(np.mean(points[:, 1]) / roi_size)
    dy = float(points[-1, 1] - points[0, 1])
    dx = float(points[-1, 0] - points[0, 0])
    verticality = min(abs(dy) / (abs(dx) + 1e-6), 4.0) / 4.0

    if len(deltas) >= 2:
        angles = np.arctan2(deltas[:, 1], deltas[:, 0])
        curvature = float(np.abs(np.diff(angles)).sum() / np.pi)
    else:
        curvature = 0.0

    return {
        "length_norm": min(path_len / (roi_size * 2.5), 1.0),
        "mean_y": mean_y,
        "verticality": verticality,
        "curvature": min(curvature / 3.0, 1.0),
    }


class HeuristicLineSelector:
    def select(self, candidates: List[np.ndarray], roi_size: int) -> List[LineCandidate]:
        scored: List[Tuple[np.ndarray, Dict[str, float]]] = [
            (pts, _path_metrics(pts, roi_size)) for pts in candidates
        ]

        # target y positions in normalized ROI coordinates
        y_targets: Dict[str, float] = {
            "heart": 0.24,
            "head": 0.42,
            "life": 0.56,
            "fate": 0.53,
            "sun": 0.40,
        }

        used = set()
        results: List[LineCandidate] = []

        for key in LINE_KEYS:
            best_idx = -1
            best_score = -1.0

            for idx, (_pts, metrics) in enumerate(scored):
                if idx in used:
                    continue

                y_penalty = abs(metrics["mean_y"] - y_targets[key])
                base = (metrics["length_norm"] * 0.55) + ((1.0 - y_penalty) * 0.35)

                if key in ("fate", "sun"):
                    base += metrics["verticality"] * 0.25
                if key == "life":
                    base += metrics["curvature"] * 0.15
                if key == "head":
                    base += (1.0 - metrics["curvature"]) * 0.08

                if base > best_score:
                    best_idx = idx
                    best_score = base

            if best_idx == -1 or best_score < 0.35:
                results.append(LineCandidate(key=key, confidence=0.1, points_roi=[]))
                continue

            used.add(best_idx)
            chosen = scored[best_idx][0]

            confidence = float(max(0.15, min(best_score, 0.95)))
            points_roi = [(float(x), float(y)) for x, y in chosen.tolist()]
            results.append(LineCandidate(key=key, confidence=confidence, points_roi=points_roi))

        return results
