package com.example.bearound_flutter_sdk

import android.content.Context
import io.flutter.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.bearound.sdk.BeAround

class BearoundFlutterSdkPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
  private lateinit var methodChannel: MethodChannel
  private var beAround: BeAround? = null
  private lateinit var context: Context

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    methodChannel = MethodChannel(binding.binaryMessenger, "bearound_flutter_sdk")
    methodChannel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)
    beAround = null
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    Log.d("BearoundFlutterSdkPlugin", "onMethodCall: ${call.method}")
    when (call.method) {
      "initialize" -> {
        val iconRes = context.applicationInfo.icon
        val debug = call.argument<Boolean>("debug") ?: false
        val clientToken = call.argument<String>("clientToken")?.trim().orEmpty()
        if (clientToken.isEmpty()) {
            result.error("INIT_ERROR", "clientToken must not be empty", null)
            return
        }
        beAround = BeAround.getInstance(context);
          beAround?.initialize(
            iconRes,
            clientToken,
            debug
          )
        result.success(null)
      }
      "stop" -> {
        beAround?.stop()
        beAround = null
        result.success(null)
      }
      else -> result.notImplemented()
    }
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {}

  override fun onCancel(arguments: Any?) {}
}