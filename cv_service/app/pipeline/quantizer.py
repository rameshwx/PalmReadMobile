from typing import Dict, List, Optional


def _bucket(value: Optional[float], edges: List[float], labels: List[str]) -> str:
    if value is None:
        return labels[0]
    for idx, edge in enumerate(edges):
        if value < edge:
            return labels[idx]
    return labels[-1]


def quantize_features(features: Dict[str, object]) -> Dict[str, object]:
    def lf(key: str, metric: str) -> Optional[float]:
        section = features.get(key)
        if not isinstance(section, dict):
            return None
        value = section.get(metric)
        if isinstance(value, (int, float)):
            return float(value)
        return None

    life_length = lf("life", "length")
    life_curvature = lf("life", "curvature")
    heart_continuity = lf("heart", "continuity")
    fate_length = lf("fate", "length")

    quantized: Dict[str, object] = {
        "life": {
            "length_bucket": _bucket(life_length, [0.28, 0.48], ["conserve", "steady", "surge"]),
            "curvature_bucket": _bucket(life_curvature, [0.35, 0.85], ["steady", "adaptive", "intense"]),
            "intersection_bucket": _bucket(lf("life", "intersections"), [1, 3], ["low", "medium", "high"]),
        },
        "head": {
            "length_bucket": _bucket(lf("head", "length"), [0.22, 0.42], ["short", "medium", "long"]),
            "curvature_bucket": _bucket(lf("head", "curvature"), [0.25, 0.70], ["flat", "arched", "complex"]),
        },
        "heart": {
            "length_bucket": _bucket(lf("heart", "length"), [0.20, 0.40], ["short", "medium", "long"]),
            "continuity_bucket": _bucket(heart_continuity, [0.45, 0.75], ["reserved", "balanced", "expressive"]),
        },
        "fate": {
            "length_bucket": _bucket(fate_length, [0.25, 0.50], ["incremental", "opportunity", "leadership"]),
            "continuity_bucket": _bucket(lf("fate", "continuity"), [0.45, 0.75], ["fragmented", "steady", "continuous"]),
        },
        "sun": {
            "length_bucket": _bucket(lf("sun", "length"), [0.20, 0.38], ["subtle", "clear", "strong"]),
            "continuity_bucket": _bucket(lf("sun", "continuity"), [0.45, 0.75], ["intermittent", "stable", "defined"]),
        },
    }

    global_section = features.get("global", {})
    if isinstance(global_section, dict):
        quantized["global"] = {
            "heart_head_gap_bucket": _bucket(
                float(global_section["heart_head_gap"]) if isinstance(global_section.get("heart_head_gap"), (int, float)) else None,
                [0.08, 0.18],
                ["tight", "balanced", "wide"],
            ),
            "detected_lines_bucket": _bucket(
                float(global_section["detected_lines"]) if isinstance(global_section.get("detected_lines"), (int, float)) else None,
                [3, 5],
                ["few", "most", "all"],
            ),
        }

    return quantized
