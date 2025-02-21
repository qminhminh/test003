import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static Future<String> login({
    required String endpointLogin,
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse(endpointLogin),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"username": username, "password": password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['token'];
    } else {
      throw Exception("Login failed: ${response.body}");
    }
  }
}
