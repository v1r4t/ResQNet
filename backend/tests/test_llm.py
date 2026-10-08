# backend/tests/test_llm.py
from app.llm.mock_extractor import MockExtractor

def test_mock_extractor_accident():
    extractor = MockExtractor()
    result = extractor.extract("Major accident on Outer Ring Road. Two lanes blocked. Heavy traffic.")
    assert result.type == "accident"
    assert result.severity == "high"
    assert result.lanes_blocked == 2

def test_mock_extractor_fire():
    extractor = MockExtractor()
    result = extractor.extract("Fire on Main Street. Minor incident.")
    assert result.type == "fire"
    assert result.severity == "low"

def test_mock_extractor_default():
    extractor = MockExtractor()
    result = extractor.extract("Something happened somewhere")
    assert result.type == "unknown"
    assert result.severity == "medium"
