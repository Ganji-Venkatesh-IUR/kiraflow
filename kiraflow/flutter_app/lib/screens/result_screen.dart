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
