# backend/app/llm/gemini_extractor.py
import json
import google.generativeai as genai
from app.config import settings
from app.llm.extractor import Extractor, ExtractedIncident

genai.configure(api_key=settings.GEMINI_API_KEY)
model = genai.GenerativeModel('gemini-pro')

class GeminiExtractor(Extractor):
    def extract(self, text: str) -> ExtractedIncident:
        prompt = f"""Extract incident information from this emergency report. Return JSON only:
{{"type": "accident|fire|construction|weather|other", "severity": "low|medium|high|critical", "road": "road name", "lanes_blocked": number, "delay_minutes": number, "description": "brief description"}}

Report: {text}"""

        response = model.generate_content(prompt)
        try:
            data = json.loads(response.text)
            return ExtractedIncident(
                type=data.get("type", "unknown"),
                severity=data.get("severity", "medium"),
                road=data.get("road", "Unknown Road"),
                lanes_blocked=data.get("lanes_blocked", 1),
                delay=data.get("delay_minutes", 0.0),
                description=data.get("description", text)
            )
        except (json.JSONDecodeError, KeyError, TypeError):
            return ExtractedIncident(
                type="unknown",
                severity="medium",
                road="Unknown Road",
                description=text
            )
