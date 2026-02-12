import hashlib
import json
from typing import Any, Dict


def canonical_json(data: Dict[str, Any]) -> str:
    return json.dumps(data, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def compute_hand_signature_hash(quantized_features: Dict[str, Any]) -> str:
    canonical = canonical_json(quantized_features)
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()
