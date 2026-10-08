# backend/app/llm/__init__.py
from app.config import settings
from app.llm.extractor import Extractor
from app.llm.mock_extractor import MockExtractor
from app.llm.gemini_extractor import GeminiExtractor
from app.llm.openai_extractor import OpenAIExtractor

def get_extractor() -> Extractor:
    if settings.LLM_PROVIDER == "gemini" and settings.GEMINI_API_KEY:
        return GeminiExtractor()
    elif settings.LLM_PROVIDER == "openai" and settings.OPENAI_API_KEY:
        return OpenAIExtractor()
    return MockExtractor()
