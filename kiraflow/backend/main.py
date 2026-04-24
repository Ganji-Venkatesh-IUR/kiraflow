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

from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import os

static_dir = os.path.join(os.path.dirname(__file__), "static")
if os.path.exists(static_dir):
    app.mount("/static", StaticFiles(directory=static_dir), name="static")

@app.get("/demo")
def demo():
    return FileResponse(os.path.join(static_dir, "index.html"))
