package com.example.bearound_flutter_sdk

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.example.bearound_flutter_sdk.BeAround
import io.flutter.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class BearoundFlutterSdkPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {

  private lateinit var methodChannel: MethodChannel
  private lateinit var eventChannel: EventChannel
  private var beAround: BeAround? = null
  private lateinit var context: Context
  private var eventSink: EventChannel.EventSink? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    methodChannel = MethodChannel(binding.binaryMessenger, "bearound_flutter_sdk")
    methodChannel.setMethodCallHandler(this)

    eventChannel = EventChannel(binding.binaryMessenger, "bearound_flutter_sdk_events")
    eventChannel.setStreamHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
    beAround = null
    eventSink = null
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    Log.d("BearoundFlutterSdkPlugin", "onMethodCall: ${call.method}")
    when (call.method) {
      "initialize" -> {
        val iconRes = context.applicationInfo.icon
        val debug = call.argument<Boolean>("debug") ?: false
        beAround = BeAround(context).apply {
          setListener(object : BeAround.Listener {
            override fun onBeaconsFound(beacons: List<BeAround.BeaconData>) {
              Handler(Looper.getMainLooper()).post {
                eventSink?.success(mapOf(
                  "event" to "beacons",
                  "beacons" to beacons.map { it.toMap() }
                ))
              }
            }

            override fun onStateChanged(state: String) {
              Handler(Looper.getMainLooper()).post {
                eventSink?.success(mapOf(
                  "event" to "state",
                  "state" to state
                ))
              }
            }
          })
          initialize(iconRes, debug)
        }
        result.success(null)
      }
      "stop" -> {
        beAround?.stop()
        result.success(null)
      }
      "getAppState" -> {
        if (beAround == null) {
          result.error(
            "NOT_INITIALIZED",
            "BeAround ainda não foi inicializado. Chame initialize() antes.",
            null
          )
        } else {
          val state = beAround?.getAppState()
          result.success(state)
        }
      }
      "getAdvertisingId" -> {
        if (beAround == null) {
          result.error(
            "NOT_INITIALIZED",
            "BeAround ainda não foi inicializado. Chame initialize() antes.",
            null
          )
        } else {
          val advertisingId = beAround?.getAdvertisingId()
          result.success(advertisingId)
        }
      }
      else -> result.notImplemented()
    }
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    eventSink = events
  }
  override fun onCancel(arguments: Any?) {
    eventSink = null
  }
}

