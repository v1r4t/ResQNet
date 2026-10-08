# backend/app/llm/extractor.py
from abc import ABC, abstractmethod
from pydantic import BaseModel

class ExtractedIncident(BaseModel):
    type: str
    severity: str
    road: str
    lanes_blocked: int = 1
    delay: float = 0.0
    description: str = ""

class Extractor(ABC):
    @abstractmethod
    def extract(self, text: str) -> ExtractedIncident:
        pass
