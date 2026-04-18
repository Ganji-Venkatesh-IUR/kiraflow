import numpy as np
from typing import Dict, Any

def run_fusion(visual: Dict[str, Any], geo: Dict[str, Any]) -> Dict[str, Any]:
    sdi = visual.get("shelf_density_index", 0.5)
    sku = visual.get("sku_diversity_score", 0.5)
    refill = visual.get("refill_signal", False)
    footfall = geo.get("footfall_proxy_index", 0.5)
    catchment = geo.get("catchment_density", 0.5)
    comp_penalty = geo.get("competition_penalty", 0.2)
    area = geo.get("area_type", "semi-urban")

    area_base = {"metro": 18000, "city": 12000, "urban": 10000, "town": 7000, "semi-urban": 5000, "rural": 3000, "unknown": 6000}
    base = area_base.get(area, 6000)

    geo_multiplier = np.clip(0.5 + (footfall * 0.35) + (catchment * 0.15), 0.3, 2.0)
    visual_multiplier = np.clip(0.4 + (sdi * 0.35) + (sku * 0.25), 0.2, 2.0)
    comp_factor = 1.0 - comp_penalty
    refill_boost = base * 0.08 if refill else 0

    daily_estimate = (base * geo_multiplier * visual_multiplier * comp_factor) + refill_boost
    lower_daily = int(daily_estimate * 0.80)
    upper_daily = int(daily_estimate * 1.20)
    monthly_lower = lower_daily * 26
    monthly_upper = upper_daily * 26
    income_lower = int(monthly_lower * 0.10)
    income_upper = int(monthly_upper * 0.16)
    confidence = _compute_confidence(visual, geo)

    return {
        "daily_sales_range": [lower_daily, upper_daily],
        "monthly_revenue_range": [monthly_lower, monthly_upper],
        "monthly_income_range": [income_lower, income_upper],
        "daily_point_estimate": int(daily_estimate),
        "confidence_score": confidence,
    }

def _compute_confidence(visual: Dict, geo: Dict) -> float:
    score = 0.0
    score += min(visual.get("images_analyzed", 0) / 5.0, 1.0) * 0.30
    score += ((visual.get("shelf_density_index", 0) + visual.get("sku_diversity_score", 0)) / 2.0) * 0.35
    score += ((geo.get("footfall_proxy_index", 0) + geo.get("catchment_density", 0)) / 2.0) * 0.35
    return round(float(np.clip(score, 0.0, 1.0)), 3)
