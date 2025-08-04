package com.example.bearound_flutter_sdk

import android.content.Context
//import com.example.sdk.BeAround
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
  private lateinit var eventChannel: EventChannel
  private var eventSink: EventChannel.EventSink? = null

  private var beAround: BeAround? = null
  private lateinit var context: Context

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
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    Log.d("BearoundFlutterSdkPlugin", "onMethodCall: ${call.method}")
    when (call.method) {
      "initialize" -> {
        val debug = call.argument<Boolean>("debug") ?: false
        beAround = BeAround(context)
        beAround?.setListener(object : BeAround.Listener {
          override fun onBeaconDetected(beacon: org.altbeacon.beacon.Beacon) {
            val beaconMap = mapOf(
              "uuid" to beacon.id1.toString(),
              "major" to beacon.id2.toString(),
              "minor" to beacon.id3.toString(),
              "rssi" to beacon.rssi,
              "bluetoothName" to beacon.bluetoothName,
              "bluetoothAddress" to beacon.bluetoothAddress,
              "distanceMeters" to beacon.distance
            )
            eventSink?.success(mapOf("beacon" to beaconMap))
          }

          override fun onMonitoringStopped() {
            eventSink?.endOfStream()
          }
        })
        beAround?.initialize("", debug)
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

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    eventSink = events
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
  }
}