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
