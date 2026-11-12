import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/user.dart';

class AuthConfig {
  final bool telegram;
  final String telegramBot;
  final bool google;
  final String googleId;
  final bool apple;
  final String appleClientId;
  final String privacyVersion;
  final String termsVersion;
  final int minPassword;

  const AuthConfig({
    this.telegram = false,
    this.telegramBot = '',
    this.google = false,
    this.googleId = '',
    this.apple = false,
    this.appleClientId = '',
    this.privacyVersion = '2026-11-07',
    this.termsVersion = '2026-11-07',
    this.minPassword = 8,
  });

  factory AuthConfig.fromJson(Map<String, dynamic> json) => AuthConfig(
        telegram: json['telegram'] == true,
        telegramBot: json['telegramBot']?.toString() ?? '',
        google: json['google'] == true,
        googleId: json['googleId']?.toString() ?? '',
        apple: json['apple'] == true,
        appleClientId: json['appleClientId']?.toString() ?? '',
        privacyVersion: json['privacyVersion']?.toString() ?? '2026-11-07',
        termsVersion: json['termsVersion']?.toString() ?? '2026-11-07',
        minPassword: (json['minPassword'] as num?)?.toInt() ?? 8,
      );
}

class TelegramStartResult {
  final String loginId;
  final String bot;
  final String link;

  const TelegramStartResult({
    required this.loginId,
    required this.bot,
    required this.link,
  });

  factory TelegramStartResult.fromJson(Map<String, dynamic> json) =>
      TelegramStartResult(
        loginId: json['loginId']?.toString() ?? '',
        bot: json['bot']?.toString() ?? '',
        link: json['link']?.toString() ?? '',
      );
}

class AuthResult {
  final bool success;
  final User? user;
  final String? token;
  final String? error;

  const AuthResult({required this.success, this.user, this.token, this.error});
}

/// Error with a message that is safe to show directly to the athlete.
class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService extends ChangeNotifier {
  static const String _prefTokenKey =
      'rucha_auth_token_v1'; // secure storage key
  static const String _prefUserKey =
      'rucha_auth_user_v1'; // SharedPrefs (non-sensitive)
  static const String _prefAccountsDbKey = 'rucha_local_accounts_db_v1';
  static const String _prefBaseUrlKey = 'rucha_api_base_v1';
  static const String _prefGuestKey = 'rucha_guest_mode_v1';

  // Session tokens stored in encrypted keystore / Keychain
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  User? _currentUser;
  String? _sessionToken;
  AuthConfig _config = const AuthConfig();
  bool _isLoading = false;
  bool _isCheckingServer = false;
  bool _serverOnline = false;
  String _serverMessage = 'Server not checked yet.';
  bool _isGuest = false;
  bool _initialized = false;
  String _baseUrl = RuchaConstants.defaultApiUrl;

  AuthService({String baseUrl = RuchaConstants.defaultApiUrl}) {
    _baseUrl = _normalizeBaseUrl(baseUrl);
    unawaited(_initialize());
  }

  User? get currentUser => _currentUser;
  String? get sessionToken => _sessionToken;
  AuthConfig get config => _config;
  String get baseUrl => _baseUrl;
  bool get isInitialized => _initialized;
  bool get isAuthenticated => _currentUser != null;
  bool get isGuest => _isGuest;
  bool get isLoading => _isLoading;
  bool get isCheckingServer => _isCheckingServer;
  bool get serverOnline => _serverOnline;
  String get serverMessage => _serverMessage;

  /// The gate used by `main.dart`. Guest mode is a first-class, local-only mode.
  bool get canUseApp =>
      _isGuest || (_currentUser != null && _currentUser!.profileComplete);

  bool get isLocalAccount =>
      _sessionToken?.startsWith('local_') == true ||
      (_currentUser?.providers.contains('local') ?? false);

  bool get telegramAvailable =>
      _serverOnline && _config.telegram && _config.telegramBot.isNotEmpty;

  int get minPassword => max(8, _config.minPassword);

  Future<void> _initialize() async {
    String baseUrl = _baseUrl;
    try {
      final prefs = await SharedPreferences.getInstance();

      // Always use the hardcoded production URL — clear any stale override
      // from old builds that had server settings visible to users.
      await prefs.remove(_prefBaseUrlKey);
      _baseUrl = RuchaConstants.defaultApiUrl;

      _isGuest = prefs.getBool(_prefGuestKey) ?? false;

      // Read session token from encrypted secure storage.
      // Fall back to SharedPreferences for accounts created by older builds,
      // then migrate them to secure storage on the spot.
      String? token = await _secureStorage.read(key: _prefTokenKey);
      if (token == null || token.isEmpty) {
        token = prefs.getString(_prefTokenKey);
        if (token != null && token.isNotEmpty) {
          await _secureStorage.write(key: _prefTokenKey, value: token);
          await prefs.remove(_prefTokenKey); // remove from insecure storage
        }
      }

      final userJson = prefs.getString(_prefUserKey);
      if (token != null && token.isNotEmpty) {
        _sessionToken = token;
        if (userJson != null && userJson.isNotEmpty) {
          try {
            _currentUser =
                User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('AuthService initialize failed: $e');
    }

    _initialized = true;
    notifyListeners();

    // Do not block app start on a network round-trip. The auth screen shows the
    // live server state and lets the athlete switch API URLs.
    unawaited(fetchConfig().then((_) {
      if (_currentUser != null && !isLocalAccount) {
        unawaited(refreshCurrentUser());
      }
    }));
  }

  String _normalizeBaseUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return RuchaConstants.defaultApiUrl;
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(value)) {
      final isLocal = value.startsWith('localhost') ||
          value.startsWith('127.0.0.1') ||
          value.startsWith('10.0.2.2');
      value = '${isLocal ? 'http' : 'https'}://$value';
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) {
      throw const FormatException(
          'Enter a valid server URL, for example https://example.com/api');
    }
    if (uri.path.isEmpty || uri.path == '/') {
      value = '$value/api';
    }
    return value;
  }

  /// Checks `/auth/config` and updates [serverOnline], [serverMessage] and the
  /// Telegram availability flags. Never throws: the UI reads the message.
  Future<bool> testConnection() async {
    _isCheckingServer = true;
    notifyListeners();

    try {
      final res = await http
          .get(Uri.parse('$baseUrl/auth/config'))
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        try {
          final decoded = jsonDecode(res.body);
          if (decoded is! Map<String, dynamic>) {
            throw const FormatException('Unexpected response');
          }
          _config = AuthConfig.fromJson(decoded);
          _serverOnline = true;
          _serverMessage = _config.telegram
              ? 'Connected · Telegram sign-in is enabled.'
              : 'Connected · Telegram sign-in is not configured on this server.';
          return true;
        } catch (_) {
          _serverOnline = false;
          _serverMessage = 'The server replied, but not with RUCHA API JSON. '
              'Check that the URL ends with /api.';
          return false;
        }
      }

      _serverOnline = false;
      if (res.statusCode == 404) {
        _serverMessage = 'No RUCHA API found at $baseUrl (HTTP 404). '
            'This address is probably the static web app, not the Go backend.';
      } else {
        _serverMessage = 'Server returned HTTP ${res.statusCode}.';
      }
      return false;
    } on TimeoutException {
      _serverOnline = false;
      _serverMessage =
          'Connection timed out. Check the URL, Wi-Fi and that the backend is running.';
      return false;
    } catch (e) {
      _serverOnline = false;
      _serverMessage = 'Cannot reach $baseUrl. '
          'Start the backend or enter a reachable server URL.';
      debugPrint('AuthService testConnection failed: $e');
      return false;
    } finally {
      _isCheckingServer = false;
      notifyListeners();
    }
  }

  Future<AuthConfig> fetchConfig() async {
    await testConnection();
    return _config;
  }

  Future<Map<String, dynamic>> _getLocalAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_prefAccountsDbKey);
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str);
        if (decoded is Map<String, dynamic>) {
          final removedSeeds = decoded.keys.where((key) {
            final value = decoded[key];
            return value is Map &&
                (value['id'] == 'usr_athlete_seed' ||
                    value['id'] == 'usr_runner_seed');
          }).toList();
          for (final key in removedSeeds) {
            decoded.remove(key);
          }
          if (removedSeeds.isNotEmpty) {
            await prefs.setString(_prefAccountsDbKey, jsonEncode(decoded));
          }
          return decoded;
        }
      }
    } catch (e) {
      debugPrint('AuthService local account load failed: $e');
    }
    return <String, dynamic>{};
  }

  Future<void> _writeLocalAccounts(Map<String, dynamic> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefAccountsDbKey, jsonEncode(accounts));
  }

  Future<void> _saveLocalAccount(
    String username,
    String password,
    User user, {
    String? existingSalt,
  }) async {
    try {
      final accounts = await _getLocalAccounts();
      final clean = username.trim().toLowerCase();
      final salt = existingSalt ?? _generateSalt();
      final userMap = user.toJson();
      userMap['salt'] = salt;
      userMap['passwordHash'] = _hashPassword(password, salt);
      userMap['savedAt'] = DateTime.now().toIso8601String();
      userMap.remove('password');
      accounts[clean] = userMap;
      await _writeLocalAccounts(accounts);
    } catch (e) {
      debugPrint('AuthService local account save failed: $e');
    }
  }

  Future<void> _saveSession(User user, String token) async {
    _currentUser = user;
    _sessionToken = token;
    _isGuest = false;
    notifyListeners();
    try {
      // Token in encrypted keystore; user profile (non-sensitive) in SharedPrefs
      await _secureStorage.write(key: _prefTokenKey, value: token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefUserKey, jsonEncode(user.toJson()));
      await prefs.remove(_prefGuestKey);
    } catch (_) {}
  }

  Future<void> _clearSession() async {
    _currentUser = null;
    _sessionToken = null;
    _isGuest = false;
    notifyListeners();
    try {
      await _secureStorage.delete(key: _prefTokenKey);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefTokenKey); // clean up legacy location too
      await prefs.remove(_prefUserKey);
      await prefs.remove(_prefGuestKey);
    } catch (_) {}
  }

  /// Allows using tracking, run cards and local history without an account.
  Future<void> continueAsGuest() async {
    _currentUser = null;
    _sessionToken = null;
    _isGuest = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefTokenKey);
      await prefs.remove(_prefUserKey);
      await prefs.setBool(_prefGuestKey, true);
    } catch (_) {}
  }

  Future<void> refreshCurrentUser() async {
    if (_sessionToken == null || isLocalAccount || !_serverOnline) return;
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_sessionToken',
        },
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['user'] is Map) {
          _currentUser =
              User.fromJson(Map<String, dynamic>.from(data['user'] as Map));
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              _prefUserKey, jsonEncode(_currentUser!.toJson()));
          notifyListeners();
        }
      } else if (res.statusCode == 401) {
        await _clearSession();
      }
    } catch (_) {}
  }

  Future<TelegramStartResult> telegramStart() async {
    if (!_serverOnline) {
      throw const AuthException(
        'Telegram sign-in needs the RUCHA Go backend. The configured API is not '
        'reachable, so no login code can be sent. Open Server settings and connect '
        'to the backend, or create a local account below.',
      );
    }
    if (!_config.telegram) {
      throw const AuthException(
        'Telegram sign-in is not configured on this server. '
        'Set TELEGRAM_BOT_TOKEN on the backend, or use a local account.',
      );
    }

    _isLoading = true;
    notifyListeners();
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/telegram/start'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return TelegramStartResult.fromJson(data);
      }
      throw AuthException(_serverError(res,
          fallback: 'Telegram sign-in could not be started.'));
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw const AuthException(
          'Telegram sign-in timed out. Check your connection and try again.');
    } catch (e) {
      throw AuthException(
          'Could not reach Telegram sign-in. ${_friendlyNetworkError(e)}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AuthResult> telegramVerify(String loginId, String code) async {
    if (loginId.isEmpty) {
      return const AuthResult(
          success: false, error: 'Start Telegram sign-in again.');
    }
    _isLoading = true;
    notifyListeners();
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/auth/telegram/verify'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'loginId': loginId, 'code': code.trim()}),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final user =
            User.fromJson(Map<String, dynamic>.from(data['user'] as Map));
        final token = data['token']?.toString() ?? '';
        await _saveSession(user, token);
        return AuthResult(success: true, user: user, token: token);
      }
      return AuthResult(
          success: false,
          error: _serverError(res, fallback: 'Verification failed.'));
    } on TimeoutException {
      return const AuthResult(
        success: false,
        error: 'Verification timed out. Check your connection and try again.',
      );
    } catch (e) {
      return AuthResult(
        success: false,
        error:
            'Could not verify the Telegram code. ${_friendlyNetworkError(e)}',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String? validateUsername(String raw) {
    final clean = raw.trim().toLowerCase();
    if (clean.length < 3 || clean.length > 20) {
      return 'Username must be 3-20 characters.';
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(clean)) {
      return 'Use only lowercase letters, numbers and _';
    }
    return null;
  }

  Future<AuthResult> register(
    String username,
    String password,
    String displayName, {
    String phoneNumber = '',
    bool acceptPrivacy = true,
    bool acceptTerms = true,
  }) async {
    final clean = username.trim().toLowerCase();
    final usernameError = validateUsername(clean);
    if (usernameError != null) {
      return AuthResult(success: false, error: usernameError);
    }
    if (password.length < minPassword) {
      return AuthResult(
        success: false,
        error: 'Password must be at least $minPassword characters.',
      );
    }
    final name = displayName.trim().isEmpty ? clean : displayName.trim();

    final accounts = await _getLocalAccounts();
    if (accounts.containsKey(clean)) {
      return const AuthResult(
        success: false,
        error:
            'That username is already used on this device. Choose another one.',
      );
    }

    _isLoading = true;
    notifyListeners();

    if (_serverOnline) {
      try {
        final res = await http
            .post(
              Uri.parse('$baseUrl/auth/register'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'username': clean,
                'password': password,
                'displayName': name,
                'phone': phoneNumber.trim(),
                'acceptPrivacy': acceptPrivacy,
                'acceptTerms': acceptTerms,
                'privacyVersion': _config.privacyVersion,
                'termsVersion': _config.termsVersion,
              }),
            )
            .timeout(const Duration(seconds: 10));

        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final user =
              User.fromJson(Map<String, dynamic>.from(data['user'] as Map));
          final token = data['token']?.toString() ?? '';
          await _saveSession(user, token);
          await _saveLocalAccount(clean, password, user);
          return AuthResult(success: true, user: user, token: token);
        }

        if (res.statusCode != 404 && res.statusCode != 405) {
          return AuthResult(
            success: false,
            error: _serverError(res,
                fallback: 'The server could not create this account.'),
          );
        }
        _serverOnline = false;
        _serverMessage =
            'The configured API does not expose account registration. '
            'Your account will be saved on this device.';
      } on TimeoutException {
        _serverOnline = false;
        _serverMessage =
            'The server did not respond. Your account will be saved on this device.';
      } catch (e) {
        _serverOnline = false;
        _serverMessage =
            'Could not reach the server. Your account will be saved on this device.';
        debugPrint('AuthService register remote failed: $e');
      }
    }

    final stamp = DateTime.now().toIso8601String();
    final localUser = User(
      id: 'usr_local_${DateTime.now().millisecondsSinceEpoch}',
      username: clean,
      displayName: name,
      phoneNumber: phoneNumber.trim(),
      createdAt: stamp,
      profileComplete: true,
      hasPassword: true,
      providers: const ['local'],
      privacyVersion: _config.privacyVersion,
      termsVersion: _config.termsVersion,
    );
    await _saveLocalAccount(clean, password, localUser);
    final token = 'local_${localUser.id}';
    await _saveSession(localUser, token);
    _isLoading = false;
    notifyListeners();
    return AuthResult(success: true, user: localUser, token: token);
  }

  Future<AuthResult> login(String username, String password) async {
    final clean = username.trim().toLowerCase();
    if (clean.isEmpty || password.isEmpty) {
      return const AuthResult(
          success: false, error: 'Enter your username and password.');
    }

    _isLoading = true;
    notifyListeners();

    String? remoteError;
    if (_serverOnline) {
      try {
        final res = await http
            .post(
              Uri.parse('$baseUrl/auth/login'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'username': clean, 'password': password}),
            )
            .timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final user =
              User.fromJson(Map<String, dynamic>.from(data['user'] as Map));
          final token = data['token']?.toString() ?? '';
          await _saveSession(user, token);
          await _saveLocalAccount(clean, password, user);
          _isLoading = false;
          notifyListeners();
          return AuthResult(success: true, user: user, token: token);
        }

        remoteError =
            _serverError(res, fallback: 'Wrong username or password.');
        if (res.statusCode != 401 && res.statusCode != 404) {
          _isLoading = false;
          notifyListeners();
          return AuthResult(success: false, error: remoteError);
        }
        if (res.statusCode == 404) {
          _serverOnline = false;
          remoteError = null;
        }
      } on TimeoutException {
        _serverOnline = false;
        remoteError = null;
      } catch (e) {
        _serverOnline = false;
        remoteError = null;
        debugPrint('AuthService login remote failed: $e');
      }
    }

    final accounts = await _getLocalAccounts();
    if (accounts.containsKey(clean)) {
      final account = Map<String, dynamic>.from(accounts[clean] as Map);
      final valid = _verifyLocalPassword(account, password);
      if (valid) {
        final user = User.fromJson(account);
        if (account['passwordHash'] == null) {
          // Upgrade accounts created by older app builds from plain text.
          await _saveLocalAccount(clean, password, user);
        }
        final token = 'local_${user.id}';
        await _saveSession(user, token);
        _isLoading = false;
        notifyListeners();
        return AuthResult(success: true, user: user, token: token);
      }
      _isLoading = false;
      notifyListeners();
      return const AuthResult(
          success: false, error: 'Incorrect password for this account.');
    }

    _isLoading = false;
    notifyListeners();
    if (remoteError != null) {
      return AuthResult(success: false, error: remoteError);
    }
    if (!_serverOnline) {
      return AuthResult(
        success: false,
        error:
            'No account "@$clean" is saved on this device. Create an account below, '
            'or connect to the RUCHA server in Server settings.',
      );
    }
    return const AuthResult(
        success: false, error: 'Wrong username or password.');
  }

  Future<AuthResult> completeProfile(
    String username,
    String password,
    String displayName, {
    String phoneNumber = '',
    bool acceptPrivacy = true,
    bool acceptTerms = true,
  }) async {
    final clean = username.trim().toLowerCase();
    final usernameError = validateUsername(clean);
    if (usernameError != null) {
      return AuthResult(success: false, error: usernameError);
    }
    if (password.length < minPassword) {
      return AuthResult(
        success: false,
        error: 'Password must be at least $minPassword characters.',
      );
    }

    _isLoading = true;
    notifyListeners();

    if (_sessionToken != null && _serverOnline && !isLocalAccount) {
      try {
        final res = await http
            .post(
              Uri.parse('$baseUrl/auth/complete'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_sessionToken',
              },
              body: jsonEncode({
                'username': clean,
                'password': password,
                'displayName':
                    displayName.trim().isEmpty ? clean : displayName.trim(),
                'phone': phoneNumber.trim(),
                'acceptPrivacy': acceptPrivacy,
                'acceptTerms': acceptTerms,
                'privacyVersion': _config.privacyVersion,
                'termsVersion': _config.termsVersion,
              }),
            )
            .timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final user =
              User.fromJson(Map<String, dynamic>.from(data['user'] as Map));
          final token = data['token']?.toString() ?? _sessionToken!;
          await _saveSession(user, token);
          await _saveLocalAccount(clean, password, user);
          return AuthResult(success: true, user: user, token: token);
        }

        if (res.statusCode != 404 && res.statusCode != 405) {
          return AuthResult(
            success: false,
            error:
                _serverError(res, fallback: 'Could not complete your profile.'),
          );
        }
      } catch (_) {}
    }

    final localUser = User(
      id: 'usr_local_${DateTime.now().millisecondsSinceEpoch}',
      username: clean,
      displayName: displayName.trim().isEmpty ? clean : displayName.trim(),
      phoneNumber: phoneNumber.trim(),
      profileComplete: true,
      hasPassword: true,
      providers: _currentUser?.providers ?? const ['local'],
      createdAt: DateTime.now().toIso8601String(),
      privacyVersion: _config.privacyVersion,
      termsVersion: _config.termsVersion,
    );
    await _saveLocalAccount(clean, password, localUser);
    final token = 'local_${localUser.id}';
    await _saveSession(localUser, token);
    _isLoading = false;
    notifyListeners();
    return AuthResult(success: true, user: localUser, token: token);
  }

  Future<Map<String, dynamic>> checkUsername(String username) async {
    final clean = username.trim().toLowerCase();
    final error = validateUsername(clean);
    if (error != null) {
      return {'available': false, 'reason': error};
    }

    final localAccounts = await _getLocalAccounts();
    if (localAccounts.containsKey(clean)) {
      return {'available': false, 'reason': 'Username is already taken'};
    }

    if (_serverOnline) {
      try {
        final res = await http
            .get(Uri.parse(
                '$baseUrl/auth/username?u=${Uri.encodeQueryComponent(clean)}'))
            .timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          return {
            'available': data['available'] == true,
            'reason': data['reason']?.toString() ?? '',
          };
        }
      } catch (_) {}
    }
    return {'available': true, 'reason': 'Available'};
  }

  Future<List<User>> searchUsers(String query) async {
    final clean = query.trim().toLowerCase();
    final results = <User>[];

    final localAccounts = await _getLocalAccounts();
    localAccounts.forEach((uname, data) {
      final map = Map<String, dynamic>.from(data as Map);
      final display = map['displayName']?.toString().toLowerCase() ?? '';
      if (clean.isEmpty || uname.contains(clean) || display.contains(clean)) {
        try {
          results.add(User.fromJson(map));
        } catch (_) {}
      }
    });

    if (clean.isNotEmpty && _serverOnline) {
      try {
        final res = await http.get(
          Uri.parse('$baseUrl/users?q=${Uri.encodeQueryComponent(clean)}'),
          headers: {
            'Content-Type': 'application/json',
            if (_sessionToken != null) 'Authorization': 'Bearer $_sessionToken',
          },
        ).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is List) {
            for (final item in data) {
              if (item is! Map) continue;
              final user = User.fromJson(Map<String, dynamic>.from(item));
              if (!results.any((r) => r.username == user.username)) {
                results.add(user);
              }
            }
          }
        }
      } catch (_) {}
    }

    results.sort((a, b) => a.username.compareTo(b.username));
    return results;
  }

  Future<bool> sendFriendRequest(String username) async {
    if (_sessionToken == null || !_serverOnline || isLocalAccount) return false;
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/friends'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_sessionToken',
            },
            body: jsonEncode({'username': username.trim().toLowerCase()}),
          )
          .timeout(const Duration(seconds: 6));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Returns the full friend state: pending incoming, pending outgoing, accepted friends.
  Future<Map<String, dynamic>?> friendState() async {
    if (_sessionToken == null || !_serverOnline || isLocalAccount) return null;
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/friends'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_sessionToken',
        },
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) return data;
      }
    } catch (_) {}
    return null;
  }

  /// Accept or decline a pending friend request edge.
  Future<bool> respondFriendRequest(String edgeId, String decision) async {
    if (_sessionToken == null || !_serverOnline || isLocalAccount) return false;
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/friends'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_sessionToken',
            },
            body: jsonEncode(
                {'action': 'respond', 'edgeId': edgeId, 'decision': decision}),
          )
          .timeout(const Duration(seconds: 6));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    if (_sessionToken != null && !isLocalAccount && _serverOnline) {
      try {
        await http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_sessionToken',
          },
        ).timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
    await _clearSession();
  }

  static String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  /// PBKDF2-HMAC-SHA256 — 100,000 iterations for offline brute-force resistance.
  /// Prefix "pbkdf2:" distinguishes new hashes from legacy SHA-256 hashes.
  static String _hashPassword(String password, String salt) {
    const iterations = 100000;
    const keyLength = 32;
    final passwordBytes = utf8.encode(password);
    // Decode the base64url salt; normalize handles missing padding
    List<int> saltBytes;
    try {
      saltBytes = base64Url.decode(base64Url.normalize(salt));
    } catch (_) {
      saltBytes = utf8.encode(salt); // fallback for malformed salt
    }
    final hmac = Hmac(sha256, passwordBytes);
    var u = hmac.convert([...saltBytes, 0, 0, 0, 1]).bytes as List<int>;
    final dk = List<int>.from(u);
    for (int i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes as List<int>;
      for (int j = 0; j < keyLength; j++) {
        dk[j] ^= u[j];
      }
    }
    return 'pbkdf2:${base64UrlEncode(Uint8List.fromList(dk))}';
  }

  static bool _verifyLocalPassword(
      Map<String, dynamic> account, String password) {
    final hash = account['passwordHash']?.toString();
    final salt = account['salt']?.toString();
    if (hash != null && salt != null) {
      // Handle legacy SHA-256 hashes transparently (re-hashed on next save)
      if (!hash.startsWith('pbkdf2:')) {
        return sha256.convert(utf8.encode('$salt:$password')).toString() ==
            hash;
      }
      return _hashPassword(password, salt) == hash;
    }
    final legacy = account['password']?.toString();
    return legacy != null && legacy == password;
  }

  String _serverError(http.Response res, {required String fallback}) {
    final extracted = _extractError(res.body);
    if (extracted != null) return extracted;
    if (res.statusCode == 404) {
      return 'No RUCHA API found at $baseUrl (HTTP 404). Check Server settings.';
    }
    return '$fallback (HTTP ${res.statusCode}).';
  }

  String? _extractError(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data['error'] != null) {
        final message = data['error'].toString().trim();
        if (message.isNotEmpty) return message;
      }
    } catch (_) {}
    return null;
  }

  String _friendlyNetworkError(Object error) {
    final text = error.toString();
    if (text.contains('Failed host lookup')) {
      return 'The server address could not be found.';
    }
    if (text.contains('Connection refused')) {
      return 'The server refused the connection. Is the backend running?';
    }
    return 'Check your connection and the Server settings URL.';
  }
}
