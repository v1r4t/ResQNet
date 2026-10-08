# backend/app/llm/openai_extractor.py
import json
import openai
from app.config import settings
from app.llm.extractor import Extractor, ExtractedIncident

openai.api_key = settings.OPENAI_API_KEY

class OpenAIExtractor(Extractor):
    def extract(self, text: str) -> ExtractedIncident:
        response = openai.ChatCompletion.create(
            model="gpt-4",
            messages=[{"role": "user", "content": f"Extract incident info from: {text}. Return JSON with keys: type, severity, road, lanes_blocked, delay_minutes, description."}]
        )
        try:
            data = json.loads(response.choices[0].message.content)
            return ExtractedIncident(
                type=data.get("type", "unknown"),
                severity=data.get("severity", "medium"),
                road=data.get("road", "Unknown Road"),
                lanes_blocked=data.get("lanes_blocked", 1),
                delay=data.get("delay_minutes", 0.0),
                description=data.get("description", text)
            )
        except (json.JSONDecodeError, KeyError, TypeError, IndexError):
            return ExtractedIncident(
                type="unknown",
                severity="medium",
                road="Unknown Road",
                description=text
            )
