# backend/app/modules/routing/worker.py
import time
from app.modules.routing import service

def run_worker(interval_seconds: int = 10):
    while True:
        try:
            result = service.recalculate_routes()
            if result["recalculated"] > 0:
                print(f"Recalculated {result['recalculated']} routes")
        except Exception as e:
            print(f"Worker error: {e}")
        time.sleep(interval_seconds)
