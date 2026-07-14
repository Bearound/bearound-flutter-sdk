package com.example.bearound_flutter_sdk

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.bearound.sdk.BeAroundSDK
import io.bearound.sdk.interfaces.BeAroundSDKListener
import io.bearound.sdk.models.Beacon
import io.bearound.sdk.models.BeaconMetadata
import io.bearound.sdk.models.ForegroundScanConfig
import io.bearound.sdk.models.MaxQueuedPayloads
import io.bearound.sdk.models.NotificationContent
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
  private lateinit var bluetoothZoneEventChannel: EventChannel
  private lateinit var bluetoothScanModeEventChannel: EventChannel
  private lateinit var bluetoothStateEventChannel: EventChannel

  private var beaconsEventSink: EventChannel.EventSink? = null
  private var scanningEventSink: EventChannel.EventSink? = null
  private var errorEventSink: EventChannel.EventSink? = null
  private var syncLifecycleEventSink: EventChannel.EventSink? = null
  private var backgroundDetectionEventSink: EventChannel.EventSink? = null
  private var beaconRegionEventSink: EventChannel.EventSink? = null
  private var activeScanEventSink: EventChannel.EventSink? = null

  // iOS-only event channels — kept here so the Dart layer sees the same channel
  // names on both platforms. They never emit on Android.
  private var bluetoothZoneEventSink: EventChannel.EventSink? = null
  private var bluetoothScanModeEventSink: EventChannel.EventSink? = null

  // Bluetooth adapter state — emitted live so JS/Dart mirrors the iOS "Bluetooth eye".
  private var bluetoothStateEventSink: EventChannel.EventSink? = null

  private lateinit var context: Context
  private val mainHandler = Handler(Looper.getMainLooper())
  private var sdk: BeAroundSDK? = null

  // Dynamic foreground-notification content set from Dart; returned synchronously
  // to the native SDK via onProvideNotificationContent.
  @Volatile
  private var foregroundNotificationContent: NotificationContent? = null

  private val btStateReceiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
      mainHandler.post {
        bluetoothStateEventSink?.success(mapOf("state" to currentBluetoothState()))
      }
    }
  }

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    // NEVER-CRASH-THE-HOST: getInstance itself never throws on native ≥3.4.5,
    // but a host that force-resolves an older native SDK can hit a linkage
    // Error (NoClassDefFoundError) right here in the host's startup path.
    // Degrade to sdk == null — every method call then answers SDK_UNAVAILABLE.
    try {
      sdk = BeAroundSDK.getInstance(context)
      sdk?.listener = this
    } catch (t: Throwable) {
      android.util.Log.e("BearoundFlutterSdk", "Native SDK unavailable: ${t.message}")
    }

    methodChannel = MethodChannel(binding.binaryMessenger, "bearound_flutter_sdk")
    methodChannel.setMethodCallHandler(this)

    beaconsEventChannel = EventChannel(binding.binaryMessenger, "bearound_flutter_sdk/beacons")
    beaconsEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { beaconsEventSink = events }
      override fun onCancel(arguments: Any?) { beaconsEventSink = null }
    })

    scanningEventChannel = EventChannel(binding.binaryMessenger, "bearound_flutter_sdk/scanning")
    scanningEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { scanningEventSink = events }
      override fun onCancel(arguments: Any?) { scanningEventSink = null }
    })

    errorEventChannel = EventChannel(binding.binaryMessenger, "bearound_flutter_sdk/errors")
    errorEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { errorEventSink = events }
      override fun onCancel(arguments: Any?) { errorEventSink = null }
    })

    syncLifecycleEventChannel = EventChannel(binding.binaryMessenger, "bearound_flutter_sdk/sync_lifecycle")
    syncLifecycleEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { syncLifecycleEventSink = events }
      override fun onCancel(arguments: Any?) { syncLifecycleEventSink = null }
    })

    backgroundDetectionEventChannel = EventChannel(binding.binaryMessenger, "bearound_flutter_sdk/background_detection")
    backgroundDetectionEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { backgroundDetectionEventSink = events }
      override fun onCancel(arguments: Any?) { backgroundDetectionEventSink = null }
    })

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

    // iOS-only event channels — registered for API parity but never emit on Android.
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

    bluetoothStateEventChannel = EventChannel(binding.binaryMessenger, "bearound_flutter_sdk/bluetooth_state")
    bluetoothStateEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        bluetoothStateEventSink = events
        // Emit current state immediately on subscribe.
        events?.success(mapOf("state" to currentBluetoothState()))
      }

      override fun onCancel(arguments: Any?) { bluetoothStateEventSink = null }
    })

    try {
      ContextCompat.registerReceiver(
        context,
        btStateReceiver,
        IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED),
        ContextCompat.RECEIVER_EXPORTED
      )
    } catch (_: Throwable) {
      // Receiver registration is best-effort; getBluetoothState() still works.
    }
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
    bluetoothZoneEventChannel.setStreamHandler(null)
    bluetoothScanModeEventChannel.setStreamHandler(null)
    bluetoothStateEventChannel.setStreamHandler(null)

    try { context.unregisterReceiver(btStateReceiver) } catch (_: Throwable) { /* not registered */ }

    sdk?.listener = null
    sdk = null
    beaconsEventSink = null
    scanningEventSink = null
    errorEventSink = null
    syncLifecycleEventSink = null
    backgroundDetectionEventSink = null
    beaconRegionEventSink = null
    activeScanEventSink = null
    bluetoothZoneEventSink = null
    bluetoothScanModeEventSink = null
    bluetoothStateEventSink = null
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    // NEVER-CRASH-THE-HOST: the Flutter engine only converts RuntimeException
    // into a PlatformException — any java.lang.Error (NoSuchMethodError when the
    // host's dependency resolution downgrades the native SDK, NoClassDefFoundError,
    // ExceptionInInitializerError) would reach the main thread's uncaught handler
    // and KILL the host app. Convert everything to a Dart-side error instead.
    try {
      dispatchMethodCall(call, result)
    } catch (t: Throwable) {
      try {
        result.error("BEAROUND_INTERNAL", "${call.method} failed: ${t.message}", t.stackTraceToString())
      } catch (_: Throwable) {
        // Reply already submitted — nothing left to answer; never rethrow.
      }
    }
  }

  private fun dispatchMethodCall(call: MethodCall, result: Result) {
    val sdk = this.sdk
    if (sdk == null) {
      result.error("SDK_UNAVAILABLE", "BearoundSDK instance not available", null)
      return
    }

    when (call.method) {
      // --- Lifecycle ---
      "configure" -> {
        val args = call.arguments as? Map<*, *>
        val businessToken = (args?.get("businessToken") as? String)?.trim()
        if (businessToken.isNullOrEmpty()) {
          result.error("INVALID_ARGUMENT", "businessToken is required", null)
          return
        }

        val precisionRaw = (args?.get("scanPrecision") as? String) ?: "high"
        val maxQueuedValue = (args?.get("maxQueuedPayloads") as? Number)?.toInt() ?: 100

        val scanPrecision = mapToScanPrecision(precisionRaw)
        val maxQueuedPayloads = mapToMaxQueuedPayloads(maxQueuedValue)

        val wasScanning = sdk.isScanning
        if (wasScanning) sdk.stopScanning()

        sdk.listener = this
        sdk.configure(
          businessToken = businessToken,
          scanPrecision = scanPrecision,
          maxQueuedPayloads = maxQueuedPayloads,
          technology = "flutter"
        )

        if (wasScanning) sdk.startScanning()
        result.success(null)
      }

      "startScanning" -> {
        sdk.listener = this
        val args = call.arguments as? Map<*, *>
        val fg = (args?.get("foregroundScanConfig") as? Map<*, *>)?.let { mapForegroundScanConfig(it) }
        if (fg != null) sdk.startScanning(fg) else sdk.startScanning()
        result.success(null)
      }

      "stopScanning" -> {
        sdk.stopScanning()
        result.success(null)
      }

      "isScanning" -> result.success(sdk.isScanning)

      "setUserProperties" -> {
        val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
        sdk.setUserProperties(mapUserProperties(args))
        result.success(null)
      }

      "clearUserProperties" -> {
        sdk.clearUserProperties()
        result.success(null)
      }

      // --- Push token ---
      // Encaminha o token (FCM no Android) pro SDK nativo, que o associa ao
      // device e envia no próximo sync. O SDK também tenta auto-coletar o FCM
      // via Firebase; esta chamada cobre apps que fornecem o token manualmente.
      "setPushToken" -> {
        val token = call.argument<String>("token")
        if (token == null) {
          result.error("INVALID_ARGUMENT", "token is required", null)
        } else {
          sdk.setPushToken(token)
          result.success(null)
        }
      }

      // Silent-push wake-up: forward an FCM data message so the native SDK can
      // restart the scan + sync on demand. Returns true only for Bearound pushes
      // (the SDK inspects the payload marker); pass everything else through.
      "handleRemoteMessage" -> {
        @Suppress("UNCHECKED_CAST")
        val raw = call.argument<Map<String, Any?>>("data") ?: emptyMap()
        val data = raw.mapValues { it.value?.toString() ?: "" }
        result.success(sdk.handleRemoteMessage(data))
      }

      // Android OS API level (Build.VERSION.SDK_INT) — lets the Dart permission
      // layer mirror the native scan gate (BLUETOOTH_SCAN on 12+, location on <12)
      // without pulling in device_info_plus.
      "getAndroidSdkInt" -> result.success(Build.VERSION.SDK_INT)

      // --- Diagnostic getters ---
      // Native SDK version injected at build time (io.bearound.sdk.BuildConfig.SDK_VERSION).
      "getSdkVersion" -> result.success(io.bearound.sdk.BuildConfig.SDK_VERSION)
      "getCurrentScanPrecision" -> result.success(sdk.currentScanPrecision?.name?.lowercase(Locale.US) ?: "")
      "getBleDiagnosticInfo" -> result.success("") // iOS-only
      "getPendingBatchCount" -> result.success(sdk.pendingBatchCount)
      "isConfigured" -> result.success(sdk.isConfigured)
      "isLocationAvailable" -> result.success(sdk.isLocationAvailable())
      "getAuthorizationStatus" -> result.success(sdk.getLocationPermissionStatus())
      "getBluetoothState" -> result.success(currentBluetoothState())

      // --- Permissions ---
      "requestPermissions" -> result.success(true) // Android: handled by permission_handler in Dart
      "checkPermissions" -> result.success(true)
      "requestLocationAuthorization" -> {
        // No native call needed on Android — runtime permissions handled in Dart.
        result.success(null)
      }

      // Push/notifications são app-level agora. O SDK nativo removeu a API de
      // notificações da biblioteca, então o bridge não a forwarda mais.

      // --- Persisted log ---
      // Detection log é iOS-only (o Android SDK não expõe getDetectionLogJson/
      // clearDetectionLog) — paridade documentada em EVENT-PARITY.md.
      "getPersistedLog" -> result.success("[]")
      "clearPersistedLog" -> result.success(null)

      // --- Foreground service scanning (Android-specific) ---
      "enableForegroundScanning" -> {
        val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
        sdk.enableForegroundScanning(mapForegroundScanConfig(args))
        result.success(null)
      }
      "disableForegroundScanning" -> {
        sdk.disableForegroundScanning()
        result.success(null)
      }
      "isForegroundScanningEnabled" -> result.success(sdk.isForegroundScanningEnabled)
      "setForegroundNotificationContent" -> {
        val args = call.arguments as? Map<*, *>
        val title = args?.get("title") as? String
        val text = args?.get("text") as? String
        foregroundNotificationContent =
          if (title != null && text != null) NotificationContent(title, text) else null
        result.success(null)
      }

      // --- Background reliability (Doze + OEM battery killers) — Android-only ---
      "isIgnoringBatteryOptimizations" -> result.success(sdk.isIgnoringBatteryOptimizations())
      "openBatteryOptimizationSettings" -> result.success(sdk.openBatteryOptimizationSettings())
      "isAutostartManageable" -> result.success(sdk.isAutostartManageable())
      "openManufacturerAutostartSettings" -> result.success(sdk.openManufacturerAutostartSettings())

      // iOS-only debug-notification toggle — the Dart docstring promises a
      // silent no-op on Android, so answer success instead of notImplemented
      // (which surfaces as MissingPluginException inside the host app).
      "setDebugNotificationsEnabled" -> result.success(null)

      // Backward-compat
      // TODO(cleanup): removable no-op shim — the native SDK no longer has a
      // separate Bluetooth-scanning toggle; kept for older Dart callers.
      "setBluetoothScanning" -> result.success(null)

      else -> result.notImplemented()
    }
  }

  // --- BeAroundSDKListener callbacks ---

  override fun onBeaconsUpdated(beacons: List<Beacon>) {
    val payload = mapOf("beacons" to beacons.map { mapBeacon(it) })
    mainHandler.post { beaconsEventSink?.success(payload) }
  }

  override fun onError(error: Exception) {
    android.util.Log.e("BearoundFlutterSdk", "SDK Error: ${error.message}", error)
    val payload = mapOf("message" to (error.message ?: "Unknown error"))
    mainHandler.post { errorEventSink?.success(payload) }
  }

  override fun onScanningStateChanged(isScanning: Boolean) {
    val payload = mapOf("isScanning" to isScanning)
    mainHandler.post { scanningEventSink?.success(payload) }
  }

  override fun onAppStateChanged(isInBackground: Boolean) {
    // Not needed for Flutter SDK — handled by the Flutter framework.
  }

  override fun onSyncStarted(beaconCount: Int) {
    val payload = mapOf("type" to "started", "beaconCount" to beaconCount)
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
    val payload = mapOf("beaconCount" to beaconCount)
    mainHandler.post { backgroundDetectionEventSink?.success(payload) }
  }

  override fun onProvideNotificationContent(beacons: List<Beacon>): NotificationContent? =
    foregroundNotificationContent

  override fun onEnterBeaconRegion() {
    mainHandler.post { beaconRegionEventSink?.success(mapOf("type" to "enter")) }
  }

  override fun onExitBeaconRegion() {
    mainHandler.post { beaconRegionEventSink?.success(mapOf("type" to "exit")) }
  }

  override fun onActiveScanStateChanged(isActive: Boolean) {
    mainHandler.post { activeScanEventSink?.success(mapOf("isActive" to isActive)) }
  }

  // --- Mapping helpers ---

  private fun mapBeacon(beacon: Beacon): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>(
      "uuid" to beacon.uuid.toString(),
      "major" to beacon.major,
      "minor" to beacon.minor,
      "rssi" to beacon.rssi,
      "proximity" to beacon.proximity.toApiString(),
      "accuracy" to beacon.accuracy,
      "timestamp" to beacon.timestamp.time,
      "metadata" to beacon.metadata?.let { mapMetadata(it) },
      "txPower" to beacon.txPower,
      // Sync metadata.
      "alreadySynced" to beacon.alreadySynced,
      "syncedAt" to beacon.syncedAt?.time,
      // Android-only fields (no iOS equivalent).
      "isStale" to beacon.isStale,
      "rssiRaw" to beacon.rssiRaw
    )
    beacon.rssiSamples?.let { stats ->
      map["rssiSamples"] = mapOf(
        "count" to stats.count,
        "min" to stats.min,
        "max" to stats.max,
        "avg" to stats.avg,
        "stdDev" to stats.stdDev,
        "firstSeen" to stats.firstSeen,
        "lastSeen" to stats.lastSeen
      )
    }
    return map
  }

  private fun mapMetadata(metadata: BeaconMetadata): Map<String, Any?> {
    return mapOf(
      "firmwareVersion" to metadata.firmwareVersion,
      "batteryLevel" to metadata.batteryLevel,
      "movements" to metadata.movements,
      "temperature" to metadata.temperature,
      "txPower" to metadata.txPower,
      "rssiFromBLE" to metadata.rssiFromBLE,
      "isConnectable" to metadata.isConnectable
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
      customProperties = customProperties
    )
  }

  // Host app's own name (android:label), already localized by Android per device
  // locale. No dependency, no Info.plist/gradle reading needed.
  private fun appLabel(): String =
    context.applicationInfo.loadLabel(context.packageManager).toString()

  // Generic, neutral subtitle — no Bluetooth/"reading data" wording. Localized
  // by the device language (no dependency).
  private fun defaultSubtitle(): String = when (java.util.Locale.getDefault().language) {
    "pt" -> "Atualizando conteúdo"
    "es" -> "Actualizando contenido"
    else -> "Updating content"
  }

  private fun mapForegroundScanConfig(args: Map<*, *>): ForegroundScanConfig {
    val default = ForegroundScanConfig()
    return ForegroundScanConfig(
      enabled = true,
      // Default title = host app's name; default subtitle = generic & neutral.
      notificationTitle = (args["notificationTitle"] as? String) ?: appLabel(),
      notificationText = (args["notificationText"] as? String) ?: defaultSubtitle(),
      notificationChannelId = args["notificationChannelId"] as? String,
      notificationChannelName = (args["notificationChannelName"] as? String) ?: default.notificationChannelName
    )
  }

  private fun mapToScanPrecision(value: String): ScanPrecision {
    return when (value.lowercase(Locale.US)) {
      "high" -> ScanPrecision.HIGH
      "medium" -> ScanPrecision.MEDIUM
      "low" -> ScanPrecision.LOW
      else -> ScanPrecision.HIGH
    }
  }

  private fun mapToMaxQueuedPayloads(value: Int): MaxQueuedPayloads {
    return when (value) {
      50 -> MaxQueuedPayloads.SMALL
      100 -> MaxQueuedPayloads.MEDIUM
      200 -> MaxQueuedPayloads.LARGE
      500 -> MaxQueuedPayloads.XLARGE
      else -> MaxQueuedPayloads.MEDIUM
    }
  }

  private fun currentBluetoothState(): String {
    val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    val adapter = manager?.adapter ?: return "unsupported"
    if (!adapter.isEnabled) return "poweredOff"
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      val granted = ContextCompat.checkSelfPermission(
        context,
        Manifest.permission.BLUETOOTH_SCAN
      ) == PackageManager.PERMISSION_GRANTED
      if (!granted) return "unauthorized"
    }
    return "poweredOn"
  }
}
