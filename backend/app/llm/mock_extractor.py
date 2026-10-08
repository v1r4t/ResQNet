# backend/app/llm/mock_extractor.py
import re
from app.llm.extractor import Extractor, ExtractedIncident

class MockExtractor(Extractor):
    source: str = "mock"
    confidence: float = 0.9

    def extract(self, text: str) -> ExtractedIncident:
        text_lower = text.lower()

        # Determine type
        incident_type = "unknown"
        if "accident" in text_lower or "crash" in text_lower:
            incident_type = "accident"
        elif "fire" in text_lower:
            incident_type = "fire"
        elif "construction" in text_lower:
            incident_type = "construction"
        elif "weather" in text_lower or "flood" in text_lower:
            incident_type = "weather"

        # Determine severity
        severity = "medium"
        if "major" in text_lower or "severe" in text_lower or "critical" in text_lower:
            severity = "high"
        elif "minor" in text_lower or "small" in text_lower:
            severity = "low"

        # Extract road name
        road = "Unknown Road"
        road_match = re.search(r'on\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\s+(?:Road|Street|Avenue|Boulevard|Highway|Lane))', text)
        if road_match:
            road = road_match.group(1)

        # Extract lanes blocked
        lanes_blocked = 1
        number_words = {'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10}
        lanes_match = re.search(r'(\d+|one|two|three|four|five|six|seven|eight|nine|ten)\s+lane', text_lower)
        if lanes_match:
            val = lanes_match.group(1)
            if val.isalpha():
                lanes_blocked = number_words.get(val, 1)
            else:
                lanes_blocked = int(val)

        # Extract delay
        delay = 0.0
        delay_match = re.search(r'(\d+)\s*min', text_lower)
        if delay_match:
            delay = float(delay_match.group(1))

        return ExtractedIncident(
            type=incident_type,
            severity=severity,
            road=road,
            lanes_blocked=lanes_blocked,
            delay=delay,
            description=text
        )
