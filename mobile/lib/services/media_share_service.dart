import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MediaShareService {
  static const MethodChannel _channel = MethodChannel('com.rucha.mobile/media_share');

  /// Opens the device camera to capture a background photo for the Run/Ride Card.
  static Future<String?> openCamera() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final String? path = await _channel.invokeMethod<String>('openCamera');
      return path;
    } on PlatformException catch (e) {
      debugPrint('Camera error: ${e.message}');
      return null;
    }
  }

  /// Opens the device photo library to choose a custom background image.
  static Future<String?> pickImageFromPhotos() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final String? path = await _channel.invokeMethod<String>('pickImage');
      return path;
    } on PlatformException catch (e) {
      debugPrint('Gallery picker error: ${e.message}');
      return null;
    }
  }

  /// Saves the rendered Run/Ride Card directly to the phone's Photo Gallery (Pictures/RUCHA).
  static Future<bool> saveCardToGallery({String? filePath, Uint8List? bytes}) async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final bool? success = await _channel.invokeMethod<bool>('saveImageToGallery', {
        if (filePath != null) 'filePath': filePath,
        if (bytes != null) 'bytes': bytes,
      });
      return success ?? false;
    } on PlatformException catch (e) {
      debugPrint('Save to gallery error: ${e.message}');
      return false;
    }
  }

  /// Opens the native Android Share Sheet to share the card to Instagram (Stories & Direct),
  /// Telegram, WhatsApp, Bluetooth, and more.
  static Future<bool> shareCard({required String filePath, required String caption}) async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final bool? success = await _channel.invokeMethod<bool>('shareCard', {
        'filePath': filePath,
        'caption': caption,
      });
      return success ?? false;
    } on PlatformException catch (e) {
      debugPrint('Share card error: ${e.message}');
      return false;
    }
  }

  /// Opens Telegram app directly using native Android intent (tg:// or https://t.me).
  static Future<bool> openTelegram({String bot = 'ruchaabot', String start = ''}) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final bool? success = await _channel.invokeMethod<bool>('openTelegram', {
        'bot': bot,
        'start': start,
      });
      return success ?? false;
    } on PlatformException catch (e) {
      debugPrint('Open Telegram error: ${e.message}');
      return false;
    }
  }
}
