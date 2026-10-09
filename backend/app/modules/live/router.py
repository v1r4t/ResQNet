import httpx
import time
from fastapi import APIRouter, HTTPException, Query

router = APIRouter(prefix="/api/live", tags=["live data"])
OSRM_BASE_URL = "https://router.project-osrm.org"


@router.get("/route")
def get_live_route(
    origin_lon: float = Query(..., ge=77.0, le=78.0),
    origin_lat: float = Query(..., ge=12.7, le=13.3),
    destination_lon: float = Query(..., ge=77.0, le=78.0),
    destination_lat: float = Query(..., ge=12.7, le=13.3),
):
    coordinates = f"{origin_lon},{origin_lat};{destination_lon},{destination_lat}"
    url = f"{OSRM_BASE_URL}/route/v1/driving/{coordinates}"
    payload = None
    last_error: Exception | None = None
    for attempt in range(3):
        try:
            response = httpx.get(
                url,
                params={"overview": "full", "geometries": "geojson", "steps": "true"},
                timeout=httpx.Timeout(15.0, connect=5.0),
                headers={"User-Agent": "ResQNet/1.0"},
            )
            response.raise_for_status()
            payload = response.json()
            break
        except (httpx.HTTPError, ValueError) as exc:
            last_error = exc
            if attempt < 2:
                time.sleep(0.5 * (attempt + 1))

    if payload is None:
        raise HTTPException(
            status_code=502,
            detail="Live Bangalore routing service is temporarily unavailable; please retry",
        ) from last_error

    if payload.get("code") != "Ok" or not payload.get("routes"):
        raise HTTPException(status_code=404, detail="No drivable route found between these Bangalore locations")

    route = payload["routes"][0]
    return {
        "source": "OSRM/OpenStreetMap",
        "distance_m": route["distance"],
        "duration_s": route["duration"],
        "duration_min": route["duration"] / 60,
        "geometry": route["geometry"],
        "steps": [
            {
                "name": step.get("name") or "Unnamed road",
                "distance_m": step["distance"],
                "duration_s": step["duration"],
                "type": step.get("maneuver", {}).get("type"),
            }
            for leg in route.get("legs", [])
            for step in leg.get("steps", [])
        ],
    }
