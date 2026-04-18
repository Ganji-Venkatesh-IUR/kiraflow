#!/bin/bash
set -e

echo "🚀 Setting up KiraFlow project..."

# Create all directories
mkdir -p kiraflow/backend/ai
mkdir -p kiraflow/backend/schemas
mkdir -p kiraflow/flutter_app/lib/screens
mkdir -p kiraflow/flutter_app/lib/services
mkdir -p kiraflow/flutter_app/lib/models

echo "📁 Directories created"

# ─────────────────────────────────────────
# BACKEND FILES
# ─────────────────────────────────────────

cat > kiraflow/backend/requirements.txt << 'EOF'
fastapi==0.111.0
uvicorn[standard]==0.29.0
python-multipart==0.0.9
pydantic==2.7.1
opencv-python-headless==4.9.0.80
numpy==1.26.4
ultralytics==8.2.18
requests==2.31.0
python-dotenv==1.0.1
EOF

cat > kiraflow/backend/Dockerfile << 'EOF'
FROM python:3.11-slim
WORKDIR /app
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx libglib2.0-0 libsm6 libxrender1 libxext6 \
    && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

cat > kiraflow/backend/schemas/__init__.py << 'EOF'
EOF

cat > kiraflow/backend/schemas/output.py << 'EOF'
from pydantic import BaseModel
from typing import List, Optional, Dict, Any

class AnalysisOutput(BaseModel):
    daily_sales_range: List[int]
    monthly_revenue_range: List[int]
    monthly_income_range: List[int]
    confidence_score: float
    risk_flags: List[str]
    recommendation: str
    visual_signals: Optional[Dict[str, Any]] = None
    geo_signals: Optional[Dict[str, Any]] = None
EOF

cat > kiraflow/backend/ai/__init__.py << 'EOF'
EOF

cat > kiraflow/backend/ai/preprocess.py << 'EOF'
import cv2
import numpy as np

def preprocess_image(raw_bytes: bytes) -> np.ndarray:
    nparr = np.frombuffer(raw_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError("Could not decode image")
    img = cv2.resize(img, (640, 640))
    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    l_enhanced = clahe.apply(l)
    lab_enhanced = cv2.merge([l_enhanced, a, b])
    enhanced = cv2.cvtColor(lab_enhanced, cv2.COLOR_LAB2BGR)
    return enhanced
EOF

cat > kiraflow/backend/ai/detector.py << 'EOF'
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
EOF

cat > kiraflow/backend/ai/geo_signals.py << 'EOF'
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
EOF

cat > kiraflow/backend/ai/fusion.py << 'EOF'
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
EOF

cat > kiraflow/backend/ai/fraud.py << 'EOF'
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
EOF

cat > kiraflow/backend/main.py << 'EOF'
from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import List
import uvicorn

from ai.preprocess import preprocess_image
from ai.detector import detect_visual_signals
from ai.geo_signals import get_geo_signals
from ai.fusion import run_fusion
from ai.fraud import check_fraud
from schemas.output import AnalysisOutput

app = FastAPI(title="KiraFlow API", version="1.0.0")

app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

@app.get("/")
def root():
    return {"status": "KiraFlow API running", "version": "1.0.0"}

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/analyze", response_model=AnalysisOutput)
async def analyze_store(
    images: List[UploadFile] = File(...),
    latitude: float = Form(...),
    longitude: float = Form(...),
):
    if len(images) < 3 or len(images) > 5:
        raise HTTPException(status_code=400, detail="Send 3–5 images")

    processed_images = []
    for img_file in images:
        raw_bytes = await img_file.read()
        processed = preprocess_image(raw_bytes)
        processed_images.append(processed)

    visual_signals = detect_visual_signals(processed_images)
    geo_signals = get_geo_signals(latitude, longitude)
    fusion_result = run_fusion(visual_signals, geo_signals)
    risk_flags = check_fraud(visual_signals, geo_signals, fusion_result)
    recommendation = _build_recommendation(fusion_result["confidence_score"], risk_flags)

    return AnalysisOutput(
        daily_sales_range=fusion_result["daily_sales_range"],
        monthly_revenue_range=fusion_result["monthly_revenue_range"],
        monthly_income_range=fusion_result["monthly_income_range"],
        confidence_score=round(fusion_result["confidence_score"], 2),
        risk_flags=risk_flags,
        recommendation=recommendation,
        visual_signals=visual_signals,
        geo_signals=geo_signals,
    )

def _build_recommendation(confidence: float, risk_flags: list) -> str:
    high_severity = {"inventory_footfall_mismatch", "image_inconsistency"}
    has_severe = any(f in high_severity for f in risk_flags)
    if confidence >= 0.75 and not has_severe:
        return "approve"
    elif confidence >= 0.55 and not has_severe:
        return "approve_with_verification"
    elif has_severe or confidence < 0.4:
        return "reject"
    return "needs_verification"

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
EOF

# ─────────────────────────────────────────
# DOCKER COMPOSE
# ─────────────────────────────────────────

cat > kiraflow/docker-compose.yml << 'EOF'
version: '3.9'
services:
  backend:
    build: ./backend
    ports:
      - "8000:8000"
    environment:
      - MAPMYINDIA_API_KEY=${MAPMYINDIA_API_KEY:-}
    volumes:
      - ./backend:/app
    command: uvicorn main:app --host 0.0.0.0 --port 8000 --reload
    restart: unless-stopped
  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: kiraflow
      POSTGRES_USER: kiraflow
      POSTGRES_PASSWORD: kiraflow123
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
volumes:
  pgdata:
EOF

# ─────────────────────────────────────────
# FLUTTER FILES
# ─────────────────────────────────────────

cat > kiraflow/flutter_app/pubspec.yaml << 'EOF'
name: kiraflow
description: KiraFlow - Remote Cash Flow Underwriting for Kirana Stores
publish_to: 'none'
version: 1.0.0+1
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
  image_picker: ^1.0.7
  geolocator: ^11.0.0
  permission_handler: ^11.3.0
  http: ^1.2.0
  cupertino_icons: ^1.0.6
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
flutter:
  uses-material-design: true
EOF

cat > kiraflow/flutter_app/lib/main.dart << 'EOF'
import 'package:flutter/material.dart';
import 'screens/upload_screen.dart';

void main() => runApp(const KiraFlowApp());

class KiraFlowApp extends StatelessWidget {
  const KiraFlowApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KiraFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1D9E75)),
        useMaterial3: true,
      ),
      home: const UploadScreen(),
    );
  }
}
EOF

cat > kiraflow/flutter_app/lib/models/analysis_result.dart << 'EOF'
class AnalysisResult {
  final List<int> dailySalesRange;
  final List<int> monthlyRevenueRange;
  final List<int> monthlyIncomeRange;
  final double confidenceScore;
  final List<String> riskFlags;
  final String recommendation;

  AnalysisResult({
    required this.dailySalesRange,
    required this.monthlyRevenueRange,
    required this.monthlyIncomeRange,
    required this.confidenceScore,
    required this.riskFlags,
    required this.recommendation,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      dailySalesRange: List<int>.from(json['daily_sales_range'] ?? [0, 0]),
      monthlyRevenueRange: List<int>.from(json['monthly_revenue_range'] ?? [0, 0]),
      monthlyIncomeRange: List<int>.from(json['monthly_income_range'] ?? [0, 0]),
      confidenceScore: (json['confidence_score'] ?? 0.0).toDouble(),
      riskFlags: List<String>.from(json['risk_flags'] ?? []),
      recommendation: json['recommendation'] ?? 'needs_verification',
    );
  }

  String get recommendationLabel {
    switch (recommendation) {
      case 'approve': return 'Approve';
      case 'approve_with_verification': return 'Approve with verification';
      case 'needs_verification': return 'Needs verification';
      case 'reject': return 'Reject';
      default: return 'Needs verification';
    }
  }

  String get formattedDailySales => '₹${_fmt(dailySalesRange[0])} – ₹${_fmt(dailySalesRange[1])}';
  String get formattedMonthlyRevenue => '₹${_fmt(monthlyRevenueRange[0])} – ₹${_fmt(monthlyRevenueRange[1])}';
  String get formattedMonthlyIncome => '₹${_fmt(monthlyIncomeRange[0])} – ₹${_fmt(monthlyIncomeRange[1])}';
  String get confidencePercent => '${(confidenceScore * 100).toStringAsFixed(0)}%';

  String _fmt(int value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toString();
  }
}
EOF

cat > kiraflow/flutter_app/lib/services/api_service.dart << 'EOF'
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/analysis_result.dart';

class ApiService {
  // IMPORTANT: Replace with your Codespace forwarded URL
  // Example: https://laughing-doodle-abc123-8000.app.github.dev
  static const String baseUrl = 'http://localhost:8000';

  static Future<AnalysisResult> analyzeStore({
    required List<XFile> images,
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse('$baseUrl/analyze');
    final request = http.MultipartRequest('POST', uri);

    for (int i = 0; i < images.length; i++) {
      final bytes = await images[i].readAsBytes();
      request.files.add(http.MultipartFile.fromBytes('images', bytes, filename: 'photo_$i.jpg'));
    }

    request.fields['latitude'] = latitude.toString();
    request.fields['longitude'] = longitude.toString();

    final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return AnalysisResult.fromJson(jsonDecode(response.body));
    }
    throw Exception('Error ${response.statusCode}: ${response.body}');
  }
}
EOF

cat > kiraflow/flutter_app/lib/screens/upload_screen.dart << 'EOF'
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import 'result_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final List<XFile> _images = [];
  final ImagePicker _picker = ImagePicker();
  Position? _position;
  bool _loading = false;
  String _status = '';

  static const kTeal = Color(0xFF1D9E75);
  static const kTealLight = Color(0xFFE1F5EE);
  static const kDark = Color(0xFF1A1A1A);
  static const kMuted = Color(0xFF6B7280);
  static const kBorder = Color(0xFFE5E7EB);

  @override
  void initState() { super.initState(); _getLocation(); }

  Future<void> _getLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        setState(() => _position = pos);
      }
    } catch (e) { debugPrint('GPS error: $e'); }
  }

  Future<void> _pick() async {
    if (_images.length >= 5) { _snack('Max 5 photos'); return; }
    final imgs = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1200);
    if (imgs.isNotEmpty) setState(() => _images.addAll(imgs.take(5 - _images.length)));
  }

  Future<void> _camera() async {
    if (_images.length >= 5) { _snack('Max 5 photos'); return; }
    final img = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1200);
    if (img != null) setState(() => _images.add(img));
  }

  Future<void> _analyze() async {
    if (_images.length < 3) { _snack('Add at least 3 photos'); return; }
    if (_position == null) { _snack('Waiting for GPS...'); await _getLocation(); return; }
    setState(() { _loading = true; _status = 'Uploading photos...'; });
    try {
      setState(() => _status = 'Running AI analysis...');
      final result = await ApiService.analyzeStore(images: _images, latitude: _position!.latitude, longitude: _position!.longitude);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => ResultScreen(result: result)));
    } catch (e) { _snack('Failed: $e'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

  static const _labels = ['Shelf 1', 'Shelf 2', 'Counter', 'Exterior 1', 'Exterior 2'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: Row(children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(color: kTeal, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.store, color: Colors.white, size: 18)),
          const SizedBox(width: 10),
          const Text('KiraFlow', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kDark)),
        ]),
        actions: [
          Padding(padding: const EdgeInsets.only(right: 16),
            child: _position != null
              ? Row(children: [Icon(Icons.location_on, size: 14, color: kTeal), const SizedBox(width: 4),
                  Text('GPS locked', style: TextStyle(fontSize: 12, color: kTeal, fontWeight: FontWeight.w500))])
              : Row(children: [SizedBox(width: 12, height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: kMuted)),
                  const SizedBox(width: 6), Text('Getting GPS...', style: TextStyle(fontSize: 12, color: kMuted))])),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: kTealLight, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Store assessment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF085041))),
              const SizedBox(height: 4),
              const Text('Upload 3–5 photos to get an AI-powered cash flow estimate.',
                style: TextStyle(fontSize: 13, color: Color(0xFF0F6E56))),
            ])),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Store photos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kDark)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _images.length >= 3 ? kTealLight : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20)),
              child: Text('${_images.length}/5', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: _images.length >= 3 ? kTeal : kMuted))),
          ]),
          const SizedBox(height: 6),
          Text('Include: shelves ×2, counter, exterior ×2', style: TextStyle(fontSize: 12, color: kMuted)),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: 5,
            itemBuilder: (_, i) => i < _images.length ? _filledSlot(i) : _emptySlot(i),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: _camera,
              icon: const Icon(Icons.camera_alt_outlined, size: 18), label: const Text('Camera'),
              style: OutlinedButton.styleFrom(foregroundColor: kDark, side: const BorderSide(color: kBorder),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: _pick,
              icon: const Icon(Icons.photo_library_outlined, size: 18), label: const Text('Gallery'),
              style: OutlinedButton.styleFrom(foregroundColor: kDark, side: const BorderSide(color: kBorder),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
          ]),
          const SizedBox(height: 20),
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder)),
            child: Row(children: [
              Icon(Icons.location_on, color: _position != null ? kTeal : kMuted, size: 20),
              const SizedBox(width: 10),
              Expanded(child: _position != null
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('GPS location captured', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF085041))),
                    Text('${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF0F6E56))),
                  ])
                : const Text('Acquiring GPS...', style: TextStyle(fontSize: 13, color: kMuted))),
              if (_position != null) const Icon(Icons.check_circle, color: kTeal, size: 18),
            ])),
          const SizedBox(height: 32),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: (_loading || _images.length < 3) ? null : _analyze,
              style: ElevatedButton.styleFrom(backgroundColor: kTeal, foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFD1D5DB), padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              child: _loading
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    const SizedBox(width: 10),
                    Text(_status, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ])
                : Text(_images.length < 3 ? 'Add ${3 - _images.length} more photo(s)' : 'Analyse store',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            )),
          const SizedBox(height: 12),
          Center(child: Text('Analysis takes ~10 seconds', style: TextStyle(fontSize: 12, color: kMuted))),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _filledSlot(int i) => Stack(children: [
    ClipRRect(borderRadius: BorderRadius.circular(10),
      child: Image.file(File(_images[i].path), fit: BoxFit.cover, width: double.infinity, height: double.infinity)),
    Positioned(bottom: 0, left: 0, right: 0,
      child: Container(padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(color: Colors.black45,
          borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10))),
        child: Text(_labels[i], textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500)))),
    Positioned(top: 4, right: 4,
      child: GestureDetector(onTap: () => setState(() => _images.removeAt(i)),
        child: Container(width: 22, height: 22,
          decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
          child: const Icon(Icons.close, size: 13, color: Colors.white)))),
  ]);

  Widget _emptySlot(int i) {
    final isNext = i == _images.length;
    return GestureDetector(onTap: isNext ? _camera : null,
      child: Container(
        decoration: BoxDecoration(
          color: isNext ? kTealLight : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isNext ? kTeal : kBorder, width: isNext ? 1.5 : 1)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(isNext ? Icons.add_a_photo_outlined : Icons.photo_outlined, size: 22,
            color: isNext ? kTeal : const Color(0xFFD1D5DB)),
          const SizedBox(height: 4),
          Text(_labels[i], textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: isNext ? kTeal : const Color(0xFFD1D5DB), fontWeight: FontWeight.w500)),
        ])));
  }
}
EOF

cat > kiraflow/flutter_app/lib/screens/result_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import '../models/analysis_result.dart';

class ResultScreen extends StatelessWidget {
  final AnalysisResult result;
  const ResultScreen({super.key, required this.result});

  static const kTeal = Color(0xFF1D9E75);
  static const kTealLight = Color(0xFFE1F5EE);
  static const kDark = Color(0xFF1A1A1A);
  static const kMuted = Color(0xFF6B7280);
  static const kBorder = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0,
        title: const Text('Analysis result', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kDark)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kDark), onPressed: () => Navigator.pop(context))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          _banner(), const SizedBox(height: 20),
          _confidence(), const SizedBox(height: 16),
          const Text('Cash flow estimates', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kDark)),
          const SizedBox(height: 10),
          _metric('Daily sales', result.formattedDailySales, Icons.today),
          const SizedBox(height: 8),
          _metric('Monthly revenue', result.formattedMonthlyRevenue, Icons.calendar_month),
          const SizedBox(height: 8),
          _metric('Monthly income', result.formattedMonthlyIncome, Icons.account_balance_wallet_outlined),
          if (result.riskFlags.isNotEmpty) ...[const SizedBox(height: 20), _risks()],
          const SizedBox(height: 20), _rawJson(), const SizedBox(height: 30),
        ])),
    );
  }

  Widget _banner() {
    Color bg, tc, ic; IconData icon;
    if (result.recommendation == 'approve') { bg = const Color(0xFFEAF3DE); tc = const Color(0xFF27500A); ic = const Color(0xFF3B6D11); icon = Icons.check_circle; }
    else if (result.recommendation == 'approve_with_verification') { bg = kTealLight; tc = const Color(0xFF085041); ic = kTeal; icon = Icons.verified_outlined; }
    else if (result.recommendation == 'reject') { bg = const Color(0xFFFCEBEB); tc = const Color(0xFF791F1F); ic = const Color(0xFFA32D2D); icon = Icons.cancel_outlined; }
    else { bg = const Color(0xFFFAEEDA); tc = const Color(0xFF633806); ic = const Color(0xFF854F0B); icon = Icons.info_outline; }
    return Container(width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [Icon(icon, color: ic, size: 28), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Recommendation', style: TextStyle(fontSize: 12, color: tc.withOpacity(0.7), fontWeight: FontWeight.w500)),
          Text(result.recommendationLabel, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: tc)),
        ]))]));
  }

  Widget _confidence() {
    final pct = result.confidenceScore;
    final color = pct >= 0.7 ? kTeal : pct >= 0.5 ? const Color(0xFFBA7517) : const Color(0xFFA32D2D);
    return Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Confidence score', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kDark)),
          Text(result.confidencePercent, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: pct, backgroundColor: kBorder,
            valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 6)),
        const SizedBox(height: 6),
        Text(pct >= 0.7 ? 'High confidence — reliable estimate'
          : pct >= 0.5 ? 'Medium confidence — verify recommended' : 'Low confidence — manual visit needed',
          style: const TextStyle(fontSize: 12, color: kMuted)),
      ]));
  }

  Widget _metric(String label, String value, IconData icon) =>
    Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: kTealLight, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: kTeal, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: kMuted))),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kDark)),
      ]));

  Widget _risks() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Risk flags', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kDark)),
    const SizedBox(height: 8),
    ...result.riskFlags.map((f) => Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFBA7517)),
        const SizedBox(width: 8),
        Expanded(child: Text(f.replaceAll('_', ' '), style: const TextStyle(fontSize: 13, color: Color(0xFF633806)))),
      ]))),
  ]);

  Widget _rawJson() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Raw API output', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kDark)),
    const SizedBox(height: 8),
    Container(width: double.infinity, padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(10)),
      child: Text(
        '{\n  "daily_sales_range": ${result.dailySalesRange},\n  "monthly_revenue_range": ${result.monthlyRevenueRange},\n  "monthly_income_range": ${result.monthlyIncomeRange},\n  "confidence_score": ${result.confidenceScore},\n  "risk_flags": ${result.riskFlags},\n  "recommendation": "${result.recommendation}"\n}',
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF9FE1CB), height: 1.6))),
  ]);
}
EOF

echo ""
echo "✅ All files created successfully!"
echo ""
echo "📋 Next steps:"
echo "  1. cd kiraflow/backend"
echo "  2. pip install -r requirements.txt"
echo "  3. uvicorn main:app --host 0.0.0.0 --port 8000 --reload"
echo "  4. Make port 8000 Public in the Ports tab"
echo "  5. Test: curl http://localhost:8000/health"
echo ""
echo "🎉 KiraFlow is ready to run!"
