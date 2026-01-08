package com.example.bearound_flutter_sdk

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.bearound.sdk.BeAroundSDK
import io.bearound.sdk.interfaces.BeAroundSDKDelegate
import io.bearound.sdk.models.Beacon
import io.bearound.sdk.models.BeaconMetadata
import io.bearound.sdk.models.UserProperties
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.Locale

class BearoundFlutterSdkPlugin : FlutterPlugin, MethodCallHandler, BeAroundSDKDelegate {
  private lateinit var methodChannel: MethodChannel
  private lateinit var beaconsEventChannel: EventChannel
  private lateinit var syncEventChannel: EventChannel
  private lateinit var scanningEventChannel: EventChannel
  private lateinit var errorEventChannel: EventChannel

  private var beaconsEventSink: EventChannel.EventSink? = null
  private var syncEventSink: EventChannel.EventSink? = null
  private var scanningEventSink: EventChannel.EventSink? = null
  private var errorEventSink: EventChannel.EventSink? = null

  private lateinit var context: Context
  private val mainHandler = Handler(Looper.getMainLooper())
  private var sdk: BeAroundSDK? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    sdk = BeAroundSDK.getInstance(context)
    sdk?.delegate = this

    methodChannel = MethodChannel(binding.binaryMessenger, "bearound_flutter_sdk")
    methodChannel.setMethodCallHandler(this)

    beaconsEventChannel = EventChannel(binding.binaryMessenger, "bearound_flutter_sdk/beacons")
    beaconsEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        beaconsEventSink = events
      }

      override fun onCancel(arguments: Any?) {
        beaconsEventSink = null
      }
    })

    syncEventChannel = EventChannel(binding.binaryMessenger, "bearound_flutter_sdk/sync")
    syncEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        syncEventSink = events
      }

      override fun onCancel(arguments: Any?) {
        syncEventSink = null
      }
    })

    scanningEventChannel = EventChannel(binding.binaryMessenger, "bearound_flutter_sdk/scanning")
    scanningEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        scanningEventSink = events
      }

      override fun onCancel(arguments: Any?) {
        scanningEventSink = null
      }
    })

    errorEventChannel = EventChannel(binding.binaryMessenger, "bearound_flutter_sdk/errors")
    errorEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        errorEventSink = events
      }

      override fun onCancel(arguments: Any?) {
        errorEventSink = null
      }
    })
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)
    beaconsEventChannel.setStreamHandler(null)
    syncEventChannel.setStreamHandler(null)
    scanningEventChannel.setStreamHandler(null)
    errorEventChannel.setStreamHandler(null)

    sdk?.delegate = null
    sdk = null
    beaconsEventSink = null
    syncEventSink = null
    scanningEventSink = null
    errorEventSink = null
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "configure" -> {
        val args = call.arguments as? Map<*, *>
        val businessToken = (args?.get("businessToken") as? String)?.trim()
        
        if (businessToken.isNullOrEmpty()) {
          result.error("INVALID_ARGUMENT", "businessToken is required", null)
          return
        }
        
        val syncIntervalSeconds = (args?.get("syncInterval") as? Number)?.toLong() ?: 30L
        val enableBluetoothScanning = args?.get("enableBluetoothScanning") as? Boolean ?: false
        val enablePeriodicScanning = args?.get("enablePeriodicScanning") as? Boolean ?: true

        sdk?.configure(
          businessToken = businessToken,
          syncInterval = syncIntervalSeconds * 1000L,
          enableBluetoothScanning = enableBluetoothScanning,
          enablePeriodicScanning = enablePeriodicScanning,
        )
        result.success(null)
      }
      "startScanning" -> {
        sdk?.startScanning()
        result.success(null)
      }
      "stopScanning" -> {
        sdk?.stopScanning()
        result.success(null)
      }
      "isScanning" -> {
        result.success(sdk?.isScanning ?: false)
      }
      "setBluetoothScanning" -> {
        val enabled = call.argument<Boolean>("enabled") ?: false
        sdk?.setBluetoothScanning(enabled)
        result.success(null)
      }
      "setUserProperties" -> {
        val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
        val properties = mapUserProperties(args)
        sdk?.setUserProperties(properties)
        result.success(null)
      }
      "clearUserProperties" -> {
        sdk?.clearUserProperties()
        result.success(null)
      }
      else -> result.notImplemented()
    }
  }

  override fun didUpdateBeacons(beacons: List<Beacon>) {
    val payload = mapOf(
      "beacons" to beacons.map { mapBeacon(it) }
    )
    mainHandler.post { beaconsEventSink?.success(payload) }
  }

  override fun didFailWithError(error: Exception) {
    val payload = mapOf(
      "message" to (error.message ?: "Unknown error")
    )
    mainHandler.post { errorEventSink?.success(payload) }
  }

  override fun didChangeScanning(isScanning: Boolean) {
    val payload = mapOf("isScanning" to isScanning)
    mainHandler.post { scanningEventSink?.success(payload) }
  }

  override fun didUpdateSyncStatus(secondsUntilNextSync: Int, isRanging: Boolean) {
    val payload = mapOf(
      "secondsUntilNextSync" to secondsUntilNextSync,
      "isRanging" to isRanging,
    )
    mainHandler.post { syncEventSink?.success(payload) }
  }

  private fun mapBeacon(beacon: Beacon): Map<String, Any?> {
    return mapOf(
      "uuid" to beacon.uuid.toString(),
      "major" to beacon.major,
      "minor" to beacon.minor,
      "rssi" to beacon.rssi,
      "proximity" to beacon.proximity.name.lowercase(Locale.US),
      "accuracy" to beacon.accuracy,
      "timestamp" to beacon.timestamp.time,
      "metadata" to beacon.metadata?.let { mapMetadata(it) },
      "txPower" to beacon.txPower,
    )
  }

  private fun mapMetadata(metadata: BeaconMetadata): Map<String, Any?> {
    return mapOf(
      "firmwareVersion" to metadata.firmwareVersion,
      "batteryLevel" to metadata.batteryLevel,
      "movements" to metadata.movements,
      "temperature" to metadata.temperature,
      "txPower" to metadata.txPower,
      "rssiFromBLE" to metadata.rssiFromBLE,
      "isConnectable" to metadata.isConnectable,
    )
  }

  private fun mapUserProperties(args: Map<*, *>): UserProperties {
    val internalId = args["internalId"] as? String
    val email = args["email"] as? String
    val name = args["name"] as? String
    val customRaw = args["customProperties"] as? Map<*, *> ?: emptyMap<Any, Any>()
    val customProperties = customRaw.mapNotNull { entry ->
      val key = entry.key as? String ?: return@mapNotNull null
      val value = entry.value as? String ?: return@mapNotNull null
      key to value
    }.toMap()

    return UserProperties(
      internalId = internalId,
      email = email,
      name = name,
      customProperties = customProperties,
    )
  }
}
