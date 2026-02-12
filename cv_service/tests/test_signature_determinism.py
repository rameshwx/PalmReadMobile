import unittest

from app.pipeline.quantizer import quantize_features
from app.pipeline.signature import compute_hand_signature_hash

def _base_features(life_length: float = 0.42):
    return {
        "life": {"length": life_length, "curvature": 0.52, "continuity": 0.71, "intersections": 1},
        "head": {"length": 0.34, "curvature": 0.30, "continuity": 0.68, "intersections": 0},
        "heart": {"length": 0.31, "curvature": 0.44, "continuity": 0.70, "intersections": 1},
        "fate": {"length": 0.40, "curvature": 0.26, "continuity": 0.62, "intersections": 1},
        "sun": {"length": 0.25, "curvature": 0.22, "continuity": 0.58, "intersections": 0},
        "global": {"heart_head_gap": 0.10, "detected_lines": 5},
    }


class SignatureDeterminismTest(unittest.TestCase):
    def test_canonical_hash_ignores_dict_order(self):
        q1 = {
            "life": {"length_bucket": "steady", "curvature_bucket": "adaptive"},
            "heart": {"continuity_bucket": "balanced"},
        }
        q2 = {
            "heart": {"continuity_bucket": "balanced"},
            "life": {"curvature_bucket": "adaptive", "length_bucket": "steady"},
        }

        self.assertEqual(compute_hand_signature_hash(q1), compute_hand_signature_hash(q2))

    def test_nearby_feature_values_in_same_bucket_keep_same_hash(self):
        q1 = quantize_features(_base_features(life_length=0.421))
        q2 = quantize_features(_base_features(life_length=0.439))

        self.assertEqual(q1, q2)
        self.assertEqual(compute_hand_signature_hash(q1), compute_hand_signature_hash(q2))

    def test_bucket_change_changes_hash(self):
        q1 = quantize_features(_base_features(life_length=0.26))
        q2 = quantize_features(_base_features(life_length=0.60))

        self.assertNotEqual(q1, q2)
        self.assertNotEqual(compute_hand_signature_hash(q1), compute_hand_signature_hash(q2))


if __name__ == "__main__":
    unittest.main()
