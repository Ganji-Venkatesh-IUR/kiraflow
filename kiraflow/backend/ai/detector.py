import numpy as np
from typing import List, Dict, Any

def detect_visual_signals(images: List[np.ndarray]) -> Dict[str, Any]:
    try:
        from ultralytics import YOLO
        model = YOLO("yolov8n.pt")
        use_yolo = True
    except Exception:
        use_yolo = False

    all_detections = []
    for img in images:
        if use_yolo:
            results = model(img, verbose=False)
            detections = _parse_yolo_results(results)
        else:
            detections = _heuristic_detection(img)
        all_detections.append(detections)
    return _aggregate_signals(all_detections)

def _parse_yolo_results(results) -> Dict[str, Any]:
    boxes = results[0].boxes
    total_objects = len(boxes) if boxes is not None else 0
    unique_classes = set()
    confidences = []
    if boxes is not None and len(boxes) > 0:
        for box in boxes:
            unique_classes.add(int(box.cls[0]))
            confidences.append(float(box.conf[0]))
    shelf_density = min(total_objects / 50.0, 1.0)
    sku_diversity = min(len(unique_classes) / 20.0, 1.0)
    avg_conf = np.mean(confidences) if confidences else 0.5
    return {
        "total_objects": total_objects,
        "unique_classes": len(unique_classes),
        "shelf_density": round(shelf_density, 3),
        "sku_diversity": round(sku_diversity, 3),
        "avg_confidence": round(avg_conf, 3),
    }

def _heuristic_detection(img: np.ndarray) -> Dict[str, Any]:
    import cv2
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    edges = cv2.Canny(gray, 50, 150)
    edge_density = np.count_nonzero(edges) / edges.size
    color_std = np.std(img.reshape(-1, 3), axis=0).mean()
    color_variance = min(color_std / 80.0, 1.0)
    brightness = gray.mean() / 255.0
    return {
        "total_objects": int(edge_density * 100),
        "unique_classes": int(color_variance * 20),
        "shelf_density": round(min(edge_density * 3, 1.0), 3),
        "sku_diversity": round(color_variance, 3),
        "avg_confidence": round(brightness, 3),
    }

def _aggregate_signals(all_detections: List[Dict]) -> Dict[str, Any]:
    avg_shelf_density = np.mean([d["shelf_density"] for d in all_detections])
    avg_sku_diversity = np.mean([d["sku_diversity"] for d in all_detections])
    total_objects = sum(d["total_objects"] for d in all_detections)
    base_inventory_value = 150000
    inventory_value_approx = int(
        base_inventory_value * avg_shelf_density * (0.5 + 0.5 * avg_sku_diversity)
    )
    shelf_variance = np.std([d["shelf_density"] for d in all_detections])
    refill_signal = bool(shelf_variance > 0.15)
    return {
        "shelf_density_index": round(float(avg_shelf_density), 3),
        "sku_diversity_score": round(float(avg_sku_diversity), 3),
        "inventory_value_approx": inventory_value_approx,
        "refill_signal": refill_signal,
        "total_objects_detected": total_objects,
        "images_analyzed": len(all_detections),
    }
