class ApiConfig {
  static const String baseUrl = 'http://192.168.18.194:3000';

  static const Duration timeout = Duration(seconds: 8);

  static Uri uri(String path) {
    return Uri.parse('$baseUrl$path');
  }
}