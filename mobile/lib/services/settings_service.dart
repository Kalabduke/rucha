import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists user-facing preferences that appear in the Settings screen.
/// All values default to false / their safe baseline; callers call [load]
/// once at startup before reading them.
class SettingsService extends ChangeNotifier {
  static const _keyEthiopianCalendar = 'pref_ethiopian_calendar';
  static const _keyGeezNumerals = 'pref_geez_numerals';
  static const _keyDataSaver = 'pref_data_saver';
  static const _keyAutoPause = 'pref_auto_pause';
  static const _keyLanguage = 'pref_language'; // 'en' | 'am'

  bool _ethiopianCalendar = false;
  bool _geezNumerals = false;
  bool _dataSaver = false;
  bool _autoPause = false;
  String _language = 'en';

  bool get ethiopianCalendar => _ethiopianCalendar;
  bool get geezNumerals => _geezNumerals;
  bool get dataSaver => _dataSaver;
  bool get autoPause => _autoPause;
  String get language => _language;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _ethiopianCalendar = prefs.getBool(_keyEthiopianCalendar) ?? false;
    _geezNumerals = prefs.getBool(_keyGeezNumerals) ?? false;
    _dataSaver = prefs.getBool(_keyDataSaver) ?? false;
    _autoPause = prefs.getBool(_keyAutoPause) ?? false;
    _language = prefs.getString(_keyLanguage) ?? 'en';
    notifyListeners();
  }

  Future<void> setEthiopianCalendar(bool value) async {
    _ethiopianCalendar = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEthiopianCalendar, value);
  }

  Future<void> setGeezNumerals(bool value) async {
    _geezNumerals = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyGeezNumerals, value);
  }

  Future<void> setDataSaver(bool value) async {
    _dataSaver = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDataSaver, value);
  }

  Future<void> setAutoPause(bool value) async {
    _autoPause = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoPause, value);
  }

  Future<void> setLanguage(String value) async {
    _language = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, value);
  }
}
