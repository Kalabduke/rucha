import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/activity.dart';
import '../models/challenge.dart';
import '../core/constants.dart';

class ApiService {
  final String baseUrl;
  String? _sessionToken;

  ApiService({this.baseUrl = RuchaConstants.defaultApiUrl});

  void setSessionToken(String? token) {
    _sessionToken = token;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_sessionToken != null) 'Authorization': 'Bearer $_sessionToken',
  };

  Future<bool> checkHealth() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['ok'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<List<Activity>> fetchActivities() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/activities'), headers: _headers)
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((x) => Activity.fromJson(x as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> saveActivity(Activity act) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/activities'),
        headers: _headers,
        body: jsonEncode(act.toJson()),
      ).timeout(const Duration(seconds: 8));
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<List<Challenge>> fetchChallenges() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/challenges'), headers: _headers)
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((x) => Challenge.fromJson(x as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Challenge?> createChallenge(Map<String, dynamic> challengeData) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/challenges'),
        headers: _headers,
        body: jsonEncode(challengeData),
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        return Challenge.fromJson(decoded as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> joinChallenge(String challengeId, {String? athleteId, String? athleteName}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/challenges/join'),
        headers: _headers,
        body: jsonEncode({
          'challengeId': challengeId,
          'athleteId': athleteId ?? '',
          'athleteName': athleteName ?? '',
        }),
      ).timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
