import 'package:flutter/services.dart';

class LockTask {
  static const _ch = MethodChannel('one_minute/locktask');

  static Future<void> start() async {
    try { await _ch.invokeMethod('start'); } catch (_) {}
  }

  static Future<void> stop() async {
    try { await _ch.invokeMethod('stop'); } catch (_) {}
  }
}
