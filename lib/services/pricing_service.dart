import 'dart:convert';
import 'package:http/http.dart' as http;

class PricingService {
  // If you're testing on a real phone (not emulator), replace
  // 127.0.0.1 with your computer's local IP address instead.
  static const String _baseUrl = 'http://127.0.0.1:8000';

  static Future<double?> predictPrice({
    required String state,
    required String region,
    required String craftCategory,
    required String material,
    required double materialCost,
    required double labourCost,
    required double labourHours,
    required String productSize,
    required int complexity,
    required double currentMarketPrice,
    required double demandScore,
    required double seasonScore,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/predict-price'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'state': state,
          'region': region,
          'craft_category': craftCategory,
          'material': material,
          'material_cost': materialCost,
          'labour_cost': labourCost,
          'labour_hours': labourHours,
          'product_size': productSize,
          'complexity': complexity,
          'current_market_price': currentMarketPrice,
          'demand_score': demandScore,
          'season_score': seasonScore,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return (data['predicted_price'] as num).toDouble();
        }
      }

      print('Pricing API failed: ${response.statusCode} ${response.body}');
      return null;
    } catch (e) {
      print('Pricing API error: $e');
      return null;
    }
  }
}