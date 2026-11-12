import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/activity.dart';
import '../models/challenge.dart';
import '../models/club.dart';
import '../models/community_post.dart';
import '../models/popular_area.dart';
import '../core/constants.dart';

class ApiService {
  String _baseUrl;
  String? _sessionToken;

  ApiService({String baseUrl = RuchaConstants.defaultApiUrl})
      : _baseUrl = baseUrl;

  String get baseUrl => _baseUrl;

  void setBaseUrl(String value) {
    var next = value.trim();
    while (next.endsWith('/')) {
      next = next.substring(0, next.length - 1);
    }
    if (next.isNotEmpty && next != _baseUrl) {
      _baseUrl = next;
    }
  }

  void configure({String? baseUrl, String? token}) {
    if (baseUrl != null) setBaseUrl(baseUrl);
    _sessionToken = token;
  }

  void setSessionToken(String? token) {
    _sessionToken = token;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_sessionToken != null) 'Authorization': 'Bearer $_sessionToken',
      };

  Future<bool> checkHealth() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 4));
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
      final res = await http
          .get(Uri.parse('$baseUrl/activities'), headers: _headers)
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data
            .map((x) => Activity.fromJson(x as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<PopularArea>> fetchPopularAreas() async {
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/areas/popular'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data
            .whereType<Map>()
            .map(
                (item) => PopularArea.fromJson(Map<String, dynamic>.from(item)))
            .where((area) => area.lat != 0 || area.lng != 0)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> saveActivity(Activity act) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/activities'),
            headers: _headers,
            body: jsonEncode(act.toServerJson()),
          )
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<List<Challenge>> fetchChallenges() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/challenges'), headers: _headers)
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data
            .map((x) => Challenge.fromJson(x as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Challenge?> createChallenge(Map<String, dynamic> challengeData) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/challenges'),
            headers: _headers,
            body: jsonEncode(challengeData),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        return Challenge.fromJson(decoded as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> joinChallenge(String challengeId,
      {String? athleteId, String? athleteName}) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/challenges/join'),
            headers: _headers,
            body: jsonEncode({
              'challengeId': challengeId,
              'athleteId': athleteId ?? '',
              'athleteName': athleteName ?? '',
            }),
          )
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Best-effort progress post for a server-backed challenge. The local result
  /// is authoritative and is always saved first by the runner.
  Future<bool> postChallengeProgress({
    required String challengeId,
    required double distanceKm,
    required int durationSec,
    required int elevationM,
    String athleteId = '',
    String athleteName = '',
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/challenges/progress'),
            headers: _headers,
            body: jsonEncode({
              'challengeId': challengeId,
              'athleteId': athleteId,
              'athleteName': athleteName,
              'distanceKm': distanceKm,
              'durationSec': durationSec,
              'elevationM': elevationM,
              'finishedAt': DateTime.now().toUtc().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<List<Club>> fetchClubs() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/clubs'), headers: _headers)
          .timeout(const Duration(seconds: 7));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return data
              .whereType<Map>()
              .map((item) => Club.fromJson(Map<String, dynamic>.from(item)))
              .where((club) => club.id.isNotEmpty && club.name.isNotEmpty)
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<bool> joinClub(String clubId, {bool leave = false}) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/clubs/join'),
            headers: _headers,
            body: jsonEncode({'clubId': clubId, 'leave': leave}),
          )
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Returns `null` when the request fails so callers can keep cached posts
  /// instead of treating an offline server as an empty community.
  Future<List<CommunityPost>?> fetchCommunityPosts(String clubId) async {
    try {
      final res = await http
          .get(
            Uri.parse(
                '$baseUrl/community/posts?clubId=${Uri.encodeQueryComponent(clubId)}'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 7));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((item) =>
                  CommunityPost.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<CommunityPost>?> fetchCommunityFeed() async {
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/community/feed'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 7));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((item) =>
                  CommunityPost.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
      }
    } catch (_) {}
    return null;
  }

  Future<CommunityPost?> createCommunityPost(Map<String, dynamic> post) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/community/posts'),
            headers: _headers,
            body: jsonEncode(post),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          return CommunityPost.fromJson(Map<String, dynamic>.from(decoded));
        }
      }
    } catch (_) {}
    return null;
  }

  /// Create a new community/club. Returns the created [Club] on success.
  Future<Club?> createClub(Map<String, dynamic> data) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/clubs'),
            headers: _headers,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          return Club.fromJson(Map<String, dynamic>.from(decoded));
        }
      }
    } catch (_) {}
    return null;
  }

  /// Update an existing club (e.g. toggle challengesDisabled). Returns true on success.
  Future<bool> updateClub(Club club) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$baseUrl/clubs/${club.id}'),
            headers: _headers,
            body: jsonEncode(club.toJson()),
          )
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {}
    return false;
  }

  /// Returns the member map {athleteId: athleteName} for a club.
  Future<Map<String, String>> fetchClubMembers(String clubId) async {
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/clubs/${Uri.encodeComponent(clubId)}/members'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      }
    } catch (_) {}
    return {};
  }

  /// Accept or decline a pending join request. [decision] is "accept" or "decline".
  Future<bool> respondClubJoin(
      String clubId, String athleteId, String decision) async {
    try {
      final res = await http
          .post(
            Uri.parse(
                '$baseUrl/clubs/${Uri.encodeComponent(clubId)}/requests/$athleteId'),
            headers: _headers,
            body: jsonEncode({'decision': decision}),
          )
          .timeout(const Duration(seconds: 6));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetch challenges for a specific club.
  Future<List<Challenge>> fetchClubChallenges(String clubId) async {
    try {
      final res = await http
          .get(
            Uri.parse(
                '$baseUrl/challenges?clubId=${Uri.encodeQueryComponent(clubId)}'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data
            .map((x) => Challenge.fromJson(x as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Approve or decline a pending community challenge.
  Future<bool> respondChallenge(String challengeId, String decision) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/challenges/respond'),
            headers: _headers,
            body:
                jsonEncode({'challengeId': challengeId, 'decision': decision}),
          )
          .timeout(const Duration(seconds: 6));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetch the leaderboard for a challenge.
  Future<List<Map<String, dynamic>>> fetchLeaderboard(
      String challengeId) async {
    try {
      final res = await http
          .get(
            Uri.parse(
                '$baseUrl/challenges/leaderboard?id=${Uri.encodeQueryComponent(challengeId)}'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final rows = decoded is Map ? decoded['rows'] : decoded;
        if (rows is List) {
          return rows
              .whereType<Map>()
              .map((r) => Map<String, dynamic>.from(r))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }
}
