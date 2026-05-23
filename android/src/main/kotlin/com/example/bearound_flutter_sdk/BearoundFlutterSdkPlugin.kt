package com.example.bearound_flutter_sdk

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.bearound.sdk.BeAroundSDK
import io.bearound.sdk.interfaces.BeAroundSDKListener
import io.bearound.sdk.models.Beacon
import io.bearound.sdk.models.BeaconMetadata
import io.bearound.sdk.models.LocationCaptureResult
import io.bearound.sdk.models.MaxQueuedPayloads
import io.bearound.sdk.models.ScanPrecision
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
  private lateinit var scanningEventChannel: EventChannel
  private lateinit var errorEventChannel: EventChannel
  private lateinit var syncLifecycleEventChannel: EventChannel
  private lateinit var backgroundDetectionEventChannel: EventChannel
  private lateinit var beaconRegionEventChannel: EventChannel
  private lateinit var activeScanEventChannel: EventChannel
  private lateinit var locationCaptureEventChannel: EventChannel
  // v2.6 — Two Eyes
  private lateinit var bluetoothZoneEventChannel: EventChannel
  private lateinit var bluetoothScanModeEventChannel: EventChannel

  private var beaconsEventSink: EventChannel.EventSink? = null
  private var scanningEventSink: EventChannel.EventSink? = null
  private var errorEventSink: EventChannel.EventSink? = null
  private var syncLifecycleEventSink: EventChannel.EventSink? = null
  private var backgroundDetectionEventSink: EventChannel.EventSink? = null
  private var beaconRegionEventSink: EventChannel.EventSink? = null
  private var activeScanEventSink: EventChannel.EventSink? = null
  private var locationCaptureEventSink: EventChannel.EventSink? = null
  private var bluetoothZoneEventSink: EventChannel.EventSink? = null
  private var bluetoothScanModeEventSink: EventChannel.EventSink? = null

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

    // v2.4 — region transition + active-scan + location capture channels
    beaconRegionEventChannel = EventChannel(binding.binaryMessenger, "bearound_flutter_sdk/beacon_region")
    beaconRegionEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { beaconRegionEventSink = events }
      override fun onCancel(arguments: Any?) { beaconRegionEventSink = null }
    })

    activeScanEventChannel = EventChannel(binding.binaryMessenger, "bearound_flutter_sdk/active_scan")
    activeScanEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { activeScanEventSink = events }
      override fun onCancel(arguments: Any?) { activeScanEventSink = null }
    })

    locationCaptureEventChannel = EventChannel(binding.binaryMessenger, "bearound_flutter_sdk/location_capture")
    locationCaptureEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { locationCaptureEventSink = events }
      override fun onCancel(arguments: Any?) { locationCaptureEventSink = null }
    })

    // v2.6 — Two Eyes (BLE-only zone + duty cycle mode)
    bluetoothZoneEventChannel = EventChannel(binding.binaryMessenger, "bearound_flutter_sdk/bluetooth_zone")
    bluetoothZoneEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { bluetoothZoneEventSink = events }
      override fun onCancel(arguments: Any?) { bluetoothZoneEventSink = null }
    })

    bluetoothScanModeEventChannel = EventChannel(binding.binaryMessenger, "bearound_flutter_sdk/bluetooth_scan_mode")
    bluetoothScanModeEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { bluetoothScanModeEventSink = events }
      override fun onCancel(arguments: Any?) { bluetoothScanModeEventSink = null }
    })
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)
    beaconsEventChannel.setStreamHandler(null)
    scanningEventChannel.setStreamHandler(null)
    errorEventChannel.setStreamHandler(null)
    syncLifecycleEventChannel.setStreamHandler(null)
    backgroundDetectionEventChannel.setStreamHandler(null)
    beaconRegionEventChannel.setStreamHandler(null)
    activeScanEventChannel.setStreamHandler(null)
    locationCaptureEventChannel.setStreamHandler(null)
    bluetoothZoneEventChannel.setStreamHandler(null)
    bluetoothScanModeEventChannel.setStreamHandler(null)

    sdk?.listener = null
    sdk = null
    beaconsEventSink = null
    scanningEventSink = null
    errorEventSink = null
    syncLifecycleEventSink = null
    backgroundDetectionEventSink = null
    beaconRegionEventSink = null
    activeScanEventSink = null
    locationCaptureEventSink = null
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

        val precisionRaw = (args?.get("scanPrecision") as? String) ?: "medium"
        val maxQueuedValue = (args?.get("maxQueuedPayloads") as? Number)?.toInt() ?: 100

        val scanPrecision = mapToScanPrecision(precisionRaw)
        val maxQueuedPayloads = mapToMaxQueuedPayloads(maxQueuedValue)

        val wasScanning = sdk?.isScanning ?: false
        if (wasScanning) {
          sdk?.stopScanning()
        }

        sdk?.listener = this

        sdk?.configure(
          businessToken = businessToken,
          scanPrecision = scanPrecision,
          maxQueuedPayloads = maxQueuedPayloads
        )

        if (wasScanning) {
          sdk?.startScanning()
        }

        result.success(null)
      }
      "startScanning" -> {
        sdk?.listener = this
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
  
  override fun onBeaconsUpdated(beacons: List<Beacon>) {
    val payload = mapOf(
      "beacons" to beacons.map { mapBeacon(it) }
    )
    mainHandler.post { beaconsEventSink?.success(payload) }
  }

  override fun onError(error: Exception) {
    android.util.Log.e("BearoundFlutterSdk", "SDK Error: ${error.message}", error)
    
    val payload = mapOf(
      "message" to (error.message ?: "Unknown error")
    )
    mainHandler.post { errorEventSink?.success(payload) }
  }

  override fun onScanningStateChanged(isScanning: Boolean) {
    val payload = mapOf("isScanning" to isScanning)
    mainHandler.post { scanningEventSink?.success(payload) }
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

  // v2.4 — Beacon region + location capture lifecycle

  override fun onEnterBeaconRegion() {
    val payload = mapOf("type" to "enter")
    mainHandler.post { beaconRegionEventSink?.success(payload) }
  }

  override fun onExitBeaconRegion() {
    val payload = mapOf("type" to "exit")
    mainHandler.post { beaconRegionEventSink?.success(payload) }
  }

  override fun onActiveScanStateChanged(isActive: Boolean) {
    val payload = mapOf("isActive" to isActive)
    mainHandler.post { activeScanEventSink?.success(payload) }
  }

  override fun onStartLocationCapture(reason: String) {
    val payload = mapOf(
      "type" to "started",
      "reason" to reason
    )
    mainHandler.post { locationCaptureEventSink?.success(payload) }
  }

  override fun onCompleteLocationCapture(result: LocationCaptureResult) {
    val payload = mutableMapOf<String, Any?>(
      "type" to "completed",
      "reason" to result.reason,
      "outcome" to result.outcome,
      "hasFix" to result.hasFix,
      "timestamp" to result.timestamp.time
    )
    result.location?.let { loc ->
      val locMap = mutableMapOf<String, Any?>(
        "latitude" to loc.latitude,
        "longitude" to loc.longitude,
        "timestamp" to loc.time
      )
      if (loc.hasAccuracy()) locMap["horizontalAccuracy"] = loc.accuracy.toDouble()
      if (loc.hasAltitude()) locMap["altitude"] = loc.altitude
      if (loc.hasSpeed()) locMap["speed"] = loc.speed.toDouble()
      if (loc.hasBearing()) locMap["course"] = loc.bearing.toDouble()
      payload["location"] = locMap
    }
    mainHandler.post { locationCaptureEventSink?.success(payload) }
  }

  // v2.6 — Two Eyes (BLE-only zone + duty cycle mode)

  override fun onEnterBluetoothZone() {
    val payload = mapOf("type" to "enter")
    mainHandler.post { bluetoothZoneEventSink?.success(payload) }
  }

  override fun onExitBluetoothZone() {
    val payload = mapOf("type" to "exit")
    mainHandler.post { bluetoothZoneEventSink?.success(payload) }
  }

  override fun onChangeBluetoothScanMode(mode: io.bearound.sdk.BluetoothScanMode, nextIdleScanAtEpochMs: Long?) {
    val payload = mutableMapOf<String, Any?>("mode" to mode.name.lowercase())
    if (nextIdleScanAtEpochMs != null) {
      payload["nextIdleScanAtEpochMs"] = nextIdleScanAtEpochMs
    }
    mainHandler.post { bluetoothScanModeEventSink?.success(payload) }
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

  private fun mapToScanPrecision(value: String): ScanPrecision {
    return when (value.lowercase(Locale.US)) {
      "high" -> ScanPrecision.HIGH
      "medium" -> ScanPrecision.MEDIUM
      "low" -> ScanPrecision.LOW
      else -> ScanPrecision.MEDIUM
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
