package com.example.bearound_flutter_sdk

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.bearound.sdk.BeAroundSDK
import io.bearound.sdk.interfaces.BeAroundSDKListener
import io.bearound.sdk.models.BackgroundScanInterval
import io.bearound.sdk.models.Beacon
import io.bearound.sdk.models.BeaconMetadata
import io.bearound.sdk.models.ForegroundScanInterval
import io.bearound.sdk.models.MaxQueuedPayloads
import io.bearound.sdk.models.UserProperties
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.Locale

class BearoundFlutterSdkPlugin : FlutterPlugin, MethodCallHandler, BeAroundSDKListener {
  private lateinit var methodChannel: MethodChannel
  private lateinit var beaconsEventChannel: EventChannel
  private lateinit var syncEventChannel: EventChannel
  private lateinit var scanningEventChannel: EventChannel
  private lateinit var errorEventChannel: EventChannel
  private lateinit var syncLifecycleEventChannel: EventChannel
  private lateinit var backgroundDetectionEventChannel: EventChannel

  private var beaconsEventSink: EventChannel.EventSink? = null
  private var syncEventSink: EventChannel.EventSink? = null
  private var scanningEventSink: EventChannel.EventSink? = null
  private var errorEventSink: EventChannel.EventSink? = null
  private var syncLifecycleEventSink: EventChannel.EventSink? = null
  private var backgroundDetectionEventSink: EventChannel.EventSink? = null

  private lateinit var context: Context
  private val mainHandler = Handler(Looper.getMainLooper())
  private var sdk: BeAroundSDK? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    sdk = BeAroundSDK.getInstance(context)
    sdk?.listener = this

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

    syncLifecycleEventChannel = EventChannel(binding.binaryMessenger, "bearound_flutter_sdk/sync_lifecycle")
    syncLifecycleEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        syncLifecycleEventSink = events
      }

      override fun onCancel(arguments: Any?) {
        syncLifecycleEventSink = null
      }
    })

    backgroundDetectionEventChannel = EventChannel(binding.binaryMessenger, "bearound_flutter_sdk/background_detection")
    backgroundDetectionEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        backgroundDetectionEventSink = events
      }

      override fun onCancel(arguments: Any?) {
        backgroundDetectionEventSink = null
      }
    })
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)
    beaconsEventChannel.setStreamHandler(null)
    syncEventChannel.setStreamHandler(null)
    scanningEventChannel.setStreamHandler(null)
    errorEventChannel.setStreamHandler(null)
    syncLifecycleEventChannel.setStreamHandler(null)
    backgroundDetectionEventChannel.setStreamHandler(null)

    sdk?.listener = null
    sdk = null
    beaconsEventSink = null
    syncEventSink = null
    scanningEventSink = null
    errorEventSink = null
    syncLifecycleEventSink = null
    backgroundDetectionEventSink = null
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
        
        val foregroundSeconds = (args?.get("foregroundScanInterval") as? Number)?.toInt() ?: 15
        val backgroundSeconds = (args?.get("backgroundScanInterval") as? Number)?.toInt() ?: 30
        val maxQueuedValue = (args?.get("maxQueuedPayloads") as? Number)?.toInt() ?: 100

        // Map Int values to native Android enums
        val foregroundInterval = mapToForegroundScanInterval(foregroundSeconds)
        val backgroundInterval = mapToBackgroundScanInterval(backgroundSeconds)
        val maxQueuedPayloads = mapToMaxQueuedPayloads(maxQueuedValue)

        // v2.2.0: Bluetooth scanning and periodic scanning are now automatic
        sdk?.configure(
          businessToken = businessToken,
          foregroundScanInterval = foregroundInterval,
          backgroundScanInterval = backgroundInterval,
          maxQueuedPayloads = maxQueuedPayloads
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
        // v2.2.0: Bluetooth scanning is now automatic - method deprecated
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

  // region BeAroundSDKListener Implementation
  
  override fun onBeaconsUpdated(beacons: List<Beacon>) {
    val payload = mapOf(
      "beacons" to beacons.map { mapBeacon(it) }
    )
    mainHandler.post { beaconsEventSink?.success(payload) }
  }

  override fun onError(error: Exception) {
    val payload = mapOf(
      "message" to (error.message ?: "Unknown error")
    )
    mainHandler.post { errorEventSink?.success(payload) }
  }

  override fun onScanningStateChanged(isScanning: Boolean) {
    val payload = mapOf("isScanning" to isScanning)
    mainHandler.post { scanningEventSink?.success(payload) }
  }

  override fun onSyncStatusUpdated(secondsUntilNextSync: Int, isRanging: Boolean) {
    val payload = mapOf(
      "secondsUntilNextSync" to secondsUntilNextSync,
      "isRanging" to isRanging,
    )
    mainHandler.post { syncEventSink?.success(payload) }
  }
  
  override fun onAppStateChanged(isInBackground: Boolean) {
    // Not needed for Flutter SDK - handled by Flutter framework
  }
  
  override fun onSyncStarted(beaconCount: Int) {
    val payload = mapOf(
      "type" to "started",
      "beaconCount" to beaconCount
    )
    mainHandler.post { syncLifecycleEventSink?.success(payload) }
  }
  
  override fun onSyncCompleted(beaconCount: Int, success: Boolean, error: Exception?) {
    val payload = mapOf(
      "type" to "completed",
      "beaconCount" to beaconCount,
      "success" to success,
      "error" to error?.message
    )
    mainHandler.post { syncLifecycleEventSink?.success(payload) }
  }
  
  override fun onBeaconDetectedInBackground(beaconCount: Int) {
    val payload = mapOf(
      "beaconCount" to beaconCount
    )
    mainHandler.post { backgroundDetectionEventSink?.success(payload) }
  }
  
  // endregion

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

  private fun mapToForegroundScanInterval(seconds: Int): ForegroundScanInterval {
    return when (seconds) {
      5 -> ForegroundScanInterval.SECONDS_5
      10 -> ForegroundScanInterval.SECONDS_10
      15 -> ForegroundScanInterval.SECONDS_15
      20 -> ForegroundScanInterval.SECONDS_20
      25 -> ForegroundScanInterval.SECONDS_25
      30 -> ForegroundScanInterval.SECONDS_30
      35 -> ForegroundScanInterval.SECONDS_35
      40 -> ForegroundScanInterval.SECONDS_40
      45 -> ForegroundScanInterval.SECONDS_45
      50 -> ForegroundScanInterval.SECONDS_50
      55 -> ForegroundScanInterval.SECONDS_55
      60 -> ForegroundScanInterval.SECONDS_60
      else -> ForegroundScanInterval.SECONDS_15  // Default fallback
    }
  }

  private fun mapToBackgroundScanInterval(seconds: Int): BackgroundScanInterval {
    return when (seconds) {
      15 -> BackgroundScanInterval.SECONDS_15
      30 -> BackgroundScanInterval.SECONDS_30
      60 -> BackgroundScanInterval.SECONDS_60
      90 -> BackgroundScanInterval.SECONDS_90
      120 -> BackgroundScanInterval.SECONDS_120
      else -> BackgroundScanInterval.SECONDS_30  // Default fallback
    }
  }

  private fun mapToMaxQueuedPayloads(value: Int): MaxQueuedPayloads {
    return when (value) {
      50 -> MaxQueuedPayloads.SMALL
      100 -> MaxQueuedPayloads.MEDIUM
      200 -> MaxQueuedPayloads.LARGE
      500 -> MaxQueuedPayloads.XLARGE
      else -> MaxQueuedPayloads.MEDIUM  // Default fallback
    }
  }
}
