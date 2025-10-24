package com.example.bearound_flutter_sdk

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.bearound.sdk.BeAround
import io.bearound.sdk.BeaconData
import io.bearound.sdk.BeaconListener
import io.bearound.sdk.SyncListener
import io.bearound.sdk.RegionListener

class BearoundFlutterSdkPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var methodChannel: MethodChannel
  private lateinit var beaconsEventChannel: EventChannel
  private lateinit var syncEventChannel: EventChannel
  private lateinit var regionEventChannel: EventChannel

  private var beAround: BeAround? = null
  private lateinit var context: Context
  private val mainHandler = Handler(Looper.getMainLooper())

  // Event sinks for streaming events to Flutter
  private var beaconsEventSink: EventChannel.EventSink? = null
  private var syncEventSink: EventChannel.EventSink? = null
  private var regionEventSink: EventChannel.EventSink? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext

    // Setup method channel
    methodChannel = MethodChannel(binding.binaryMessenger, "bearound_flutter_sdk")
    methodChannel.setMethodCallHandler(this)

    // Setup event channels
    beaconsEventChannel = EventChannel(binding.binaryMessenger, "bearound_flutter_sdk/beacons")
    beaconsEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        beaconsEventSink = events
        Log.d("BearoundFlutterSdk", "Beacons event channel started listening")
      }

      override fun onCancel(arguments: Any?) {
        beaconsEventSink = null
        Log.d("BearoundFlutterSdk", "Beacons event channel cancelled")
      }
    })

    syncEventChannel = EventChannel(binding.binaryMessenger, "bearound_flutter_sdk/sync")
    syncEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        syncEventSink = events
        Log.d("BearoundFlutterSdk", "Sync event channel started listening")
      }

      override fun onCancel(arguments: Any?) {
        syncEventSink = null
        Log.d("BearoundFlutterSdk", "Sync event channel cancelled")
      }
    })

    regionEventChannel = EventChannel(binding.binaryMessenger, "bearound_flutter_sdk/region")
    regionEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        regionEventSink = events
        Log.d("BearoundFlutterSdk", "Region event channel started listening")
      }

      override fun onCancel(arguments: Any?) {
        regionEventSink = null
        Log.d("BearoundFlutterSdk", "Region event channel cancelled")
      }
    })
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)

    // Remove listeners
    beAround?.removeBeaconListener(beaconListener)
    beAround?.removeSyncListener(syncListener)
    beAround?.removeRegionListener(regionListener)

    beAround = null
    beaconsEventSink = null
    syncEventSink = null
    regionEventSink = null
  }

  private fun checkPermissions(): String {
    val locationGranted = ContextCompat.checkSelfPermission(
      context,
      Manifest.permission.ACCESS_FINE_LOCATION
    ) == PackageManager.PERMISSION_GRANTED

    val locationCoarseGranted = ContextCompat.checkSelfPermission(
      context,
      Manifest.permission.ACCESS_COARSE_LOCATION
    ) == PackageManager.PERMISSION_GRANTED

    var bluetoothGranted = true
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      val bluetoothScan = ContextCompat.checkSelfPermission(
        context,
        Manifest.permission.BLUETOOTH_SCAN
      ) == PackageManager.PERMISSION_GRANTED

      val bluetoothConnect = ContextCompat.checkSelfPermission(
        context,
        Manifest.permission.BLUETOOTH_CONNECT
      ) == PackageManager.PERMISSION_GRANTED

      bluetoothGranted = bluetoothScan && bluetoothConnect
    }

    return """
      Permissions Status:
        - ACCESS_FINE_LOCATION: $locationGranted
        - ACCESS_COARSE_LOCATION: $locationCoarseGranted
        - BLUETOOTH (SDK 31+): $bluetoothGranted
    """.trimIndent()
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    Log.d("BearoundFlutterSdkPlugin", "onMethodCall: ${call.method}")
    when (call.method) {
      "initialize" -> {
        val iconRes = context.applicationInfo.icon
        val debug = call.argument<Boolean>("debug") ?: false
        val clientToken = call.argument<String>("clientToken")?.trim().orEmpty()

        Log.d("BearoundFlutterSdkPlugin", "Initialize called with:")
        Log.d("BearoundFlutterSdkPlugin", "  - iconRes: $iconRes")
        Log.d("BearoundFlutterSdkPlugin", "  - debug: $debug")
        Log.d("BearoundFlutterSdkPlugin", "  - clientToken: ${if (clientToken.isEmpty()) "EMPTY" else "provided"}")

        // Check permissions
        Log.d("BearoundFlutterSdkPlugin", checkPermissions())

        // Temporarily allow empty token for testing (like native example)
        // if (clientToken.isEmpty()) {
        //   result.error("INIT_ERROR", "clientToken must not be empty", null)
        //   return
        // }

        Log.d("BearoundFlutterSdkPlugin", "Getting BeAround instance...")
        beAround = BeAround.getInstance(context)

        if (beAround == null) {
          Log.e("BearoundFlutterSdkPlugin", "❌ BeAround.getInstance returned null!")
          result.error("INIT_ERROR", "Failed to get BeAround instance", null)
          return
        }

        Log.d("BearoundFlutterSdkPlugin", "✓ BeAround instance obtained")
        Log.d("BearoundFlutterSdkPlugin", "Calling beAround.initialize()...")

        beAround?.initialize(iconRes, clientToken, debug)

        Log.d("BearoundFlutterSdkPlugin", "✓ BeAround.initialize() completed")
        Log.d("BearoundFlutterSdkPlugin", "BeAround.isInitialized: ${BeAround.isInitialized()}")

        // Add listeners
        Log.d("BearoundFlutterSdkPlugin", "Adding listeners...")
        beAround?.addBeaconListener(beaconListener)
        beAround?.addSyncListener(syncListener)
        beAround?.addRegionListener(regionListener)
        Log.d("BearoundFlutterSdkPlugin", "✓ All listeners added")

        result.success(null)
        Log.d("BearoundFlutterSdkPlugin", "✓ Initialize completed successfully")
      }
      "stop" -> {
        Log.d("BearoundFlutterSdkPlugin", "Stop called")
        beAround?.removeBeaconListener(beaconListener)
        beAround?.removeSyncListener(syncListener)
        beAround?.removeRegionListener(regionListener)
        beAround?.stop()
        beAround = null
        result.success(null)
        Log.d("BearoundFlutterSdkPlugin", "✓ Stop completed")
      }
      else -> result.notImplemented()
    }
  }

  // BeaconListener implementation
  private val beaconListener = object : BeaconListener {
    override fun onBeaconsDetected(beacons: List<BeaconData>, eventType: String) {
      mainHandler.post {
        val beaconsList = beacons.map { beacon ->
          mapOf(
            "uuid" to beacon.uuid,
            "major" to beacon.major,
            "minor" to beacon.minor,
            "rssi" to beacon.rssi,
            "bluetoothName" to beacon.bluetoothName,
            "bluetoothAddress" to beacon.bluetoothAddress,
            "lastSeen" to beacon.lastSeen
          )
        }

        val eventData = mapOf(
          "type" to "beaconsDetected",
          "beacons" to beaconsList,
          "eventType" to eventType.uppercase()
        )

        beaconsEventSink?.success(eventData)
        Log.d("BearoundFlutterSdk", "Sent beacon event: $eventType with ${beacons.size} beacons")
      }
    }
  }

  // SyncListener implementation
  private val syncListener = object : SyncListener {
    override fun onSyncSuccess(eventType: String, beaconCount: Int, message: String) {
      mainHandler.post {
        val eventData = mapOf(
          "type" to "syncSuccess",
          "eventType" to eventType,
          "beaconsCount" to beaconCount,
          "message" to message
        )

        syncEventSink?.success(eventData)
        Log.d("BearoundFlutterSdk", "Sync success: $eventType, count: $beaconCount")
      }
    }

    override fun onSyncError(
      eventType: String,
      beaconCount: Int,
      errorCode: Int?,
      errorMessage: String
    ) {
      mainHandler.post {
        val eventData = mapOf(
          "type" to "syncError",
          "eventType" to eventType,
          "beaconsCount" to beaconCount,
          "errorCode" to errorCode,
          "errorMessage" to errorMessage
        )

        syncEventSink?.success(eventData)
        Log.d("BearoundFlutterSdk", "Sync error: $errorMessage")
      }
    }
  }

  // RegionListener implementation
  private val regionListener = object : RegionListener {
    override fun onRegionEnter(regionName: String) {
      mainHandler.post {
        val eventData = mapOf(
          "type" to "beaconRegionEnter",
          "regionName" to regionName
        )

        regionEventSink?.success(eventData)
        Log.d("BearoundFlutterSdk", "Region enter: $regionName")
      }
    }

    override fun onRegionExit(regionName: String) {
      mainHandler.post {
        val eventData = mapOf(
          "type" to "beaconRegionExit",
          "regionName" to regionName
        )

        regionEventSink?.success(eventData)
        Log.d("BearoundFlutterSdk", "Region exit: $regionName")
      }
    }
  }
}