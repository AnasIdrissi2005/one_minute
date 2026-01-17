package com.example.one_minute

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
  private val CHANNEL = "one_minute/locktask"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "start" -> {
            try {
              startLockTask()
              result.success(true)
            } catch (e: Exception) {
              result.error("LOCKTASK_START_FAILED", e.message, null)
            }
          }
          "stop" -> {
            try {
              stopLockTask()
              result.success(true)
            } catch (e: Exception) {
              result.error("LOCKTASK_STOP_FAILED", e.message, null)
            }
          }
          else -> result.notImplemented()
        }
      }
  }
}
