from typing import Dict, List, Sequence, Tuple

from app.pipeline.interfaces import LineCandidate


Point = Tuple[float, float]


def _perpendicular_distance(point: Point, start: Point, end: Point) -> float:
    x, y = point
    x1, y1 = start
    x2, y2 = end

    if x1 == x2 and y1 == y2:
        return ((x - x1) ** 2 + (y - y1) ** 2) ** 0.5

    numerator = abs((y2 - y1) * x - (x2 - x1) * y + x2 * y1 - y2 * x1)
    denominator = ((y2 - y1) ** 2 + (x2 - x1) ** 2) ** 0.5
    return numerator / denominator


def rdp(points: Sequence[Point], epsilon: float) -> List[Point]:
    if len(points) < 3:
        return list(points)

    start = points[0]
    end = points[-1]

    max_distance = 0.0
    max_index = 0
    for i in range(1, len(points) - 1):
        distance = _perpendicular_distance(points[i], start, end)
        if distance > max_distance:
            max_distance = distance
            max_index = i

    if max_distance > epsilon:
        left = rdp(points[: max_index + 1], epsilon)
        right = rdp(points[max_index:], epsilon)
        return left[:-1] + right

    return [start, end]


def _map_point_to_original(point: Point, roi_meta: Dict[str, float]) -> Point:
    roi_size = float(roi_meta.get("roi_size", 512.0))
    crop_x = float(roi_meta.get("crop_x", 0.0))
    crop_y = float(roi_meta.get("crop_y", 0.0))
    crop_w = float(roi_meta.get("crop_w", roi_size))
    crop_h = float(roi_meta.get("crop_h", roi_size))
    image_w = float(roi_meta.get("image_w", crop_w))
    image_h = float(roi_meta.get("image_h", crop_h))

    x_roi, y_roi = point
    x = crop_x + (x_roi / roi_size) * crop_w
    y = crop_y + (y_roi / roi_size) * crop_h

    x = max(0.0, min(x, image_w - 1.0))
    y = max(0.0, min(y, image_h - 1.0))

    return x, y


def simplify_and_map_lines(lines: List[LineCandidate], roi_meta: Dict[str, float]) -> List[Dict[str, object]]:
    roi_size = float(roi_meta.get("roi_size", 512.0))
    epsilon = ((roi_size**2 + roi_size**2) ** 0.5) * 0.01

    out: List[Dict[str, object]] = []
    for line in lines:
        if len(line.points_roi) < 2:
            out.append(
                {
                    "key": line.key,
                    "confidence": float(line.confidence),
                    "points": [],
                    "missing": True,
                }
            )
            continue

        simplified = rdp(line.points_roi, epsilon)
        mapped_points = [
            {"x": float(x), "y": float(y)} for x, y in (_map_point_to_original(p, roi_meta) for p in simplified)
        ]

        out.append(
            {
                "key": line.key,
                "confidence": float(line.confidence),
                "points": mapped_points,
                "missing": len(mapped_points) < 2,
            }
        )

    return out
