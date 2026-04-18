import os
import requests
from typing import Dict, Any

MAPMYINDIA_KEY = os.getenv("MAPMYINDIA_API_KEY", "")

def get_geo_signals(latitude: float, longitude: float) -> Dict[str, Any]:
    if MAPMYINDIA_KEY:
        return _fetch_mapmyindia(latitude, longitude)
    return _heuristic_geo(latitude, longitude)

def _fetch_mapmyindia(lat: float, lng: float) -> Dict[str, Any]:
    try:
        url = "https://atlas.mapmyindia.com/api/places/nearby/json"
        params = {"keywords": "grocery,kirana,supermarket", "refLocation": f"{lat},{lng}", "radius": 500, "apikey": MAPMYINDIA_KEY}
        r = requests.get(url, params=params, timeout=10)
        data = r.json()
        nearby_stores = len(data.get("suggestedLocations", []))
        return _build_geo_signals(nearby_stores, "urban", lat, lng)
    except Exception:
        return _heuristic_geo(lat, lng)

def _heuristic_geo(lat: float, lng: float) -> Dict[str, Any]:
    is_urban = _is_likely_urban(lat, lng)
    catchment_density = 0.72 if is_urban else 0.38
    footfall_proxy = 0.65 if is_urban else 0.30
    competition_density = 0.55 if is_urban else 0.25
    return {
        "catchment_density": catchment_density,
        "footfall_proxy_index": footfall_proxy,
        "competition_density": competition_density,
        "competition_penalty": round(competition_density * 0.3, 3),
        "area_type": "urban" if is_urban else "semi-urban",
        "latitude": lat,
        "longitude": lng,
    }

def _build_geo_signals(nearby_stores: int, area_type: str, lat: float, lng: float) -> Dict[str, Any]:
    is_urban = area_type in ("city", "town", "metro", "urban")
    catchment_density = 0.8 if is_urban else 0.4
    footfall_proxy = catchment_density * 0.85
    competition_density = min(nearby_stores / 10.0, 1.0)
    return {
        "catchment_density": round(catchment_density, 3),
        "footfall_proxy_index": round(footfall_proxy, 3),
        "competition_density": round(competition_density, 3),
        "competition_penalty": round(competition_density * 0.3, 3),
        "area_type": area_type,
        "nearby_stores_count": nearby_stores,
        "latitude": lat,
        "longitude": lng,
    }

def _is_likely_urban(lat: float, lng: float) -> bool:
    urban_zones = [
        (28.4, 28.9, 76.8, 77.4), (18.8, 19.3, 72.7, 73.1),
        (12.8, 13.1, 77.4, 77.8), (22.4, 22.7, 88.2, 88.5),
        (17.2, 17.6, 78.3, 78.6), (22.2, 22.5, 70.7, 70.9),
        (22.6, 22.8, 75.8, 76.0), (23.1, 23.3, 77.3, 77.5),
    ]
    return any(a <= lat <= b and c <= lng <= d for a, b, c, d in urban_zones)
