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
