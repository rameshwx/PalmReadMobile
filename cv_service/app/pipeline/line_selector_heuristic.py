from typing import Dict, List, Optional, Tuple

import cv2
import numpy as np

from app.pipeline.interfaces import Handedness, LineCandidate

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
        "path_len": path_len,
        "mean_y": mean_y,
        "verticality": verticality,
        "curvature": min(curvature / 3.0, 1.0),
    }


def _sample_points(points: np.ndarray, max_points: int) -> np.ndarray:
    if points.shape[0] <= max_points:
        return points
    idx = np.linspace(0, points.shape[0] - 1, max_points).astype(np.int32)
    return points[idx]


def _clamp_points(points: np.ndarray, roi_size: int) -> np.ndarray:
    return np.clip(points, 0.0, float(roi_size - 1)).astype(np.float32)


def _guide_proximity_score(points: np.ndarray, guide: np.ndarray, roi_size: int) -> float:
    if points.shape[0] < 2 or guide.shape[0] < 2:
        return 0.0

    pts = _sample_points(points, 96)
    g = _sample_points(guide, 48)

    diffs = pts[:, None, :] - g[None, :, :]
    dists = np.sqrt(np.sum(diffs * diffs, axis=2))
    mean_min = float(np.min(dists, axis=1).mean())
    dist_score = max(0.0, 1.0 - (mean_min / (roi_size * 0.22)))

    cand_vec = points[-1] - points[0]
    guide_vec = guide[-1] - guide[0]
    cand_norm = float(np.linalg.norm(cand_vec)) + 1e-6
    guide_norm = float(np.linalg.norm(guide_vec)) + 1e-6
    dir_score = float(np.dot(cand_vec, guide_vec) / (cand_norm * guide_norm))
    dir_score = max(0.0, min((dir_score + 1.0) / 2.0, 1.0))

    guide_deltas = np.diff(guide, axis=0)
    guide_len = float(np.sqrt((guide_deltas[:, 0] ** 2) + (guide_deltas[:, 1] ** 2)).sum()) + 1e-6
    cand_deltas = np.diff(points, axis=0)
    cand_len = float(np.sqrt((cand_deltas[:, 0] ** 2) + (cand_deltas[:, 1] ** 2)).sum())
    len_ratio = cand_len / guide_len
    len_score = max(0.0, 1.0 - min(abs(len_ratio - 1.0), 1.0))

    return float((dist_score * 0.65) + (dir_score * 0.20) + (len_score * 0.15))


def _build_guides(
    landmarks_roi: Optional[List[Tuple[float, float]]],
    roi_size: int,
    handedness: Handedness,
) -> Dict[str, np.ndarray]:
    if landmarks_roi is None or len(landmarks_roi) < 21:
        return {}

    try:
        lm = np.array(landmarks_roi, dtype=np.float32)
    except Exception:
        return {}

    if lm.shape[0] < 21 or lm.shape[1] != 2:
        return {}

    wrist = lm[0]
    thumb_cmc = lm[1]
    thumb_mcp = lm[2]
    index_mcp = lm[5]
    middle_mcp = lm[9]
    ring_mcp = lm[13]
    pinky_mcp = lm[17]

    thumb_left = bool(thumb_mcp[0] < pinky_mcp[0])
    if handedness == "left":
        thumb_left = False
    elif handedness == "right":
        thumb_left = True

    thumb_sign = -1.0 if thumb_left else 1.0
    pinky_sign = 1.0 if thumb_left else -1.0
    rs = float(roi_size)

    mcp_center = (index_mcp + middle_mcp + ring_mcp + pinky_mcp) / 4.0
    palm_center = (mcp_center * 0.60) + (wrist * 0.40)

    heart = np.array(
        [
            pinky_mcp + np.array([0.05 * rs * pinky_sign, -0.03 * rs], dtype=np.float32),
            (ring_mcp + middle_mcp) / 2.0 + np.array([0.0, -0.07 * rs], dtype=np.float32),
            (middle_mcp + index_mcp) / 2.0 + np.array([0.0, -0.06 * rs], dtype=np.float32),
            index_mcp + np.array([-0.04 * rs * pinky_sign, -0.02 * rs], dtype=np.float32),
        ],
        dtype=np.float32,
    )

    head = np.array(
        [
            index_mcp + np.array([0.02 * rs * thumb_sign, 0.10 * rs], dtype=np.float32),
            palm_center + np.array([0.0, 0.00 * rs], dtype=np.float32),
            pinky_mcp + np.array([-0.05 * rs * thumb_sign, 0.08 * rs], dtype=np.float32),
        ],
        dtype=np.float32,
    )

    life = np.array(
        [
            index_mcp + np.array([0.01 * rs * thumb_sign, 0.04 * rs], dtype=np.float32),
            thumb_mcp + np.array([0.03 * rs * thumb_sign, 0.10 * rs], dtype=np.float32),
            thumb_cmc + np.array([0.07 * rs * thumb_sign, 0.11 * rs], dtype=np.float32),
            wrist + np.array([0.16 * rs * thumb_sign, -0.02 * rs], dtype=np.float32),
        ],
        dtype=np.float32,
    )

    fate = np.array(
        [
            wrist + np.array([0.0, -0.06 * rs], dtype=np.float32),
            palm_center + np.array([0.0, 0.0], dtype=np.float32),
            middle_mcp + np.array([0.0, -0.03 * rs], dtype=np.float32),
        ],
        dtype=np.float32,
    )

    sun = np.array(
        [
            (wrist * 0.55) + (ring_mcp * 0.45) + np.array([0.02 * rs * pinky_sign, 0.0], dtype=np.float32),
            ((palm_center + ring_mcp) / 2.0) + np.array([0.03 * rs * pinky_sign, -0.02 * rs], dtype=np.float32),
            ring_mcp + np.array([0.04 * rs * pinky_sign, -0.03 * rs], dtype=np.float32),
        ],
        dtype=np.float32,
    )

    return {
        "heart": _clamp_points(heart, roi_size),
        "head": _clamp_points(head, roi_size),
        "life": _clamp_points(life, roi_size),
        "fate": _clamp_points(fate, roi_size),
        "sun": _clamp_points(sun, roi_size),
    }


class HeuristicLineSelector:
    def select(
        self,
        candidates: List[np.ndarray],
        roi_size: int,
        landmarks_roi: Optional[List[Tuple[float, float]]] = None,
        handedness: Handedness = "unknown",
    ) -> List[LineCandidate]:
        guides = _build_guides(landmarks_roi, roi_size, handedness)

        scored: List[Tuple[np.ndarray, Dict[str, float], Dict[str, float]]] = []
        for pts in candidates:
            metrics = _path_metrics(pts, roi_size)
            guide_scores: Dict[str, float] = {}
            for key in LINE_KEYS:
                guide = guides.get(key)
                if guide is None:
                    continue
                guide_scores[key] = _guide_proximity_score(pts, guide, roi_size)
            scored.append((pts, metrics, guide_scores))

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

            for idx, (_pts, metrics, guide_scores) in enumerate(scored):
                if idx in used:
                    continue

                y_penalty = abs(metrics["mean_y"] - y_targets[key])
                base = (metrics["length_norm"] * 0.36) + ((1.0 - y_penalty) * 0.24)

                if key in ("fate", "sun"):
                    base += metrics["verticality"] * 0.22
                if key == "life":
                    base += metrics["curvature"] * 0.15
                if key == "head":
                    base += (1.0 - metrics["curvature"]) * 0.08

                guide_score = guide_scores.get(key, 0.0)
                if guide_score > 0.0:
                    # Landmark-guided anchoring helps reject unrelated creases.
                    base = (base * 0.50) + (guide_score * 0.72)

                if base > best_score:
                    best_idx = idx
                    best_score = base

            min_score = 0.27
            if key in ("fate", "sun"):
                min_score = 0.23
            if key in guides:
                min_score = 0.25

            if best_idx == -1 or best_score < min_score:
                guide = guides.get(key)
                if guide is not None and guide.shape[0] >= 2:
                    # Fallback to a landmark-guided estimate for this line.
                    # This keeps overlay geometry consistent on weaker photos.
                    points_roi = [(float(x), float(y)) for x, y in guide.tolist()]
                    confidence = float(max(0.18, min(0.34, best_score if best_score > 0 else 0.22)))
                    results.append(
                        LineCandidate(key=key, confidence=confidence, points_roi=points_roi)
                    )
                    continue
                results.append(LineCandidate(key=key, confidence=0.1, points_roi=[]))
                continue

            used.add(best_idx)
            chosen = scored[best_idx][0]

            confidence = float(max(0.15, min(best_score, 0.95)))
            points_roi = [(float(x), float(y)) for x, y in chosen.tolist()]
            results.append(LineCandidate(key=key, confidence=confidence, points_roi=points_roi))

        return results
