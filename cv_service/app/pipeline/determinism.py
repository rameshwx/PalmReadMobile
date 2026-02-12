import os
import random

import cv2
import numpy as np


def configure_determinism(num_threads: int = 1) -> None:
    os.environ.setdefault("PYTHONHASHSEED", "0")
    random.seed(42)
    np.random.seed(42)

    cv2.setNumThreads(max(num_threads, 1))
    cv2.ocl.setUseOpenCL(False)
