class HandNotDetectedError(Exception):
    """Raised when a submitted image does not contain a detectable human hand/palm."""


class PalmLinesNotDetectedError(Exception):
    """Raised when a hand is present but palm lines could not be extracted reliably."""
