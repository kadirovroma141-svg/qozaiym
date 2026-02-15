import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIService {
  static String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? "";
  static const String _baseUrl = "https://api.openai.com/v1/chat/completions";

  Future<String?> identifyBusNumber(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_apiKey",
        },
        body: jsonEncode({
          "model": "gpt-4o",
          "messages": [
            {
              "role": "user",
              "content": [
                {
                  "type": "text",
                  "text":
                      "Identify the bus route number in this image. Return ONLY the number. If the number is not clearly visible or there is no bus, return 'null'."
                },
                {
                  "type": "image_url",
                  "image_url": {"url": "data:image/jpeg;base64,$base64Image"}
                }
              ]
            }
          ],
          "max_tokens": 10
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content =
            data['choices'][0]['message']['content'].toString().trim();

        debugPrint("AI Response: $content");

        if (content.toLowerCase().contains("null") || content.isEmpty) {
          return null;
        }
        return content;
      } else {
        debugPrint("AI Error: ${response.statusCode}");
        debugPrint("AI Error Body: ${response.body}");
        debugPrint("AI Error Headers: ${response.headers}");
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint("AI Exception: $e");
      debugPrint("AI Stack trace: $stackTrace");
      return null;
    }
  }
}
