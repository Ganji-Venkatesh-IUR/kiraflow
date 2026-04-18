from typing import List, Dict, Any

def check_fraud(visual: Dict[str, Any], geo: Dict[str, Any], fusion: Dict[str, Any]) -> List[str]:
    flags = []
    sdi = visual.get("shelf_density_index", 0.5)
    sku = visual.get("sku_diversity_score", 0.5)
    footfall = geo.get("footfall_proxy_index", 0.5)
    n_images = visual.get("images_analyzed", 0)
    confidence = fusion.get("confidence_score", 0.5)

    if sdi > 0.75 and footfall < 0.25:
        flags.append("inventory_footfall_mismatch")
    if n_images < 3:
        flags.append("insufficient_images")
    if sdi > 0.6 and sku < 0.2:
        flags.append("low_sku_diversity_mismatch")
    if confidence < 0.45:
        flags.append("low_confidence_estimate")
    if n_images == 3:
        flags.append("limited_view_coverage")
    return flags
