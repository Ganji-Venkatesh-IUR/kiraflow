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
