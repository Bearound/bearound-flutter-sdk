package com.example.bearound_flutter_sdk

import android.app.Application.NOTIFICATION_SERVICE
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ProcessLifecycleOwner
import com.google.android.gms.ads.identifier.AdvertisingIdClient
import kotlinx.coroutines.*
import org.altbeacon.beacon.*

/**
 * BeAround SDK - Class for managing beacon monitoring and syncing events with a remote API.
 *
 * @param context Application context for initializing the beacon manager and accessing system services.
 */
class BeAround(private val context: Context) : MonitorNotifier {

    private val beaconUUID = "e25b8d3c-947a-452f-a13f-589cb706d2e5"
    private val beaconManager = BeaconManager.getInstanceForApplication(context.applicationContext)
    private var debug: Boolean = false
    private var advertisingId: String? = null
    private var advertisingIdFetchAttempted = false

    companion object {
        private const val TAG = "BeAroundSdkFlutter"
        private const val NOTIFICATION_CHANNEL_ID = "beacon_notifications"
        private const val FOREGROUND_SERVICE_NOTIFICATION_ID = 3
    }

    interface Listener {
        fun onBeaconsFound(beacons: List<BeaconData>)
        fun onStateChanged(state: String)
    }

    private var listener: Listener? = null

    fun setListener(l: Listener?) {
        listener = l
    }

    data class BeaconData(
        val uuid: String,
        val major: Int,
        val minor: Int,
        val rssi: Int,
        val bluetoothName: String?,
        val bluetoothAddress: String?,
        val distanceMeters: Double
    ) {
        fun toMap() = mapOf(
            "uuid" to uuid,
            "major" to major,
            "minor" to minor,
            "rssi" to rssi,
            "bluetoothName" to bluetoothName,
            "bluetoothAddress" to bluetoothAddress,
            "distanceMeters" to distanceMeters
        )
    }

    fun getAdvertisingId(): String? = advertisingId

    fun fetchAdvertisingId() {
        if (advertisingIdFetchAttempted && advertisingId != null) return
        advertisingIdFetchAttempted = true
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val adInfo = AdvertisingIdClient.getAdvertisingIdInfo(context)
                advertisingId = adInfo.id
                log("Successfully fetched Advertising ID: $advertisingId")
            } catch (e: Exception) {
                advertisingId = null
                Log.e(TAG, "Failed to fetch Advertising ID: ${e.message}")
            }
        }
    }

    fun getAppState(): String {
        val state = ProcessLifecycleOwner.get().lifecycle.currentState
        return when {
            state.isAtLeast(Lifecycle.State.RESUMED) -> "foreground"
            state.isAtLeast(Lifecycle.State.STARTED) -> "background"
            else -> "inactive"
        }
    }

    fun initialize(iconNotification: Int, debug: Boolean = false) {
        this.debug = debug
        log("Initializing BeAround SDK...")

        createNotificationChannel()
        beaconManager.beaconParsers.clear()
        beaconManager.beaconParsers.add(
            BeaconParser().setBeaconLayout("m:2-3=0215,i:4-19,i:20-21,i:22-23,p:24-24")
        )

        val foregroundNotification: Notification =
            NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(iconNotification)
                .setContentTitle("Monitoramento de Beacons")
                .setContentText("Execução contínua em segundo plano")
                .setOngoing(true)
                .build()

        beaconManager.enableForegroundServiceScanning(
            foregroundNotification,
            FOREGROUND_SERVICE_NOTIFICATION_ID
        )

        beaconManager.setEnableScheduledScanJobs(false)
        beaconManager.setRegionStatePersistenceEnabled(false)
        beaconManager.setBackgroundScanPeriod(1100L)
        beaconManager.setBackgroundBetweenScanPeriod(20000L)
        beaconManager.setForegroundBetweenScanPeriod(1000L)
        beaconManager.addMonitorNotifier(this)
        beaconManager.startMonitoring(getRegion())

        fetchAdvertisingId()
    }

    fun stop() {
        log("Stopped monitoring beacons region")
        beaconManager.stopMonitoring(getRegion())
        beaconManager.removeAllMonitorNotifiers()
        beaconManager.removeAllRangeNotifiers()
    }

    override fun didEnterRegion(region: Region) {
        log("didEnterRegion: ${region.uniqueId}")
        beaconManager.startRangingBeacons(region)
        beaconManager.addRangeNotifier(rangeNotifierForEvent)
        listener?.onStateChanged("enter")
    }

    override fun didExitRegion(region: Region) {
        log("didExitRegion: ${region.uniqueId}")
        // *** Não chama mais onExitRegion! ***
        beaconManager.stopRangingBeacons(region)
        beaconManager.removeRangeNotifier(rangeNotifierForEvent)
        listener?.onStateChanged("exit")
    }

    override fun didDetermineStateForRegion(state: Int, region: Region) {
        val stateString = if (state == MonitorNotifier.INSIDE) "enter" else "exit"
        log("didDetermineStateForRegion: $stateString")
        listener?.onStateChanged(stateString)
    }

    private val rangeNotifierForEvent = RangeNotifier { beacons, rangedRegion ->
        log("Ranged beacons in ${rangedRegion.uniqueId}: ${beacons.size} found")
        val matchingBeacons = beacons.filter {
            it.id1.toString() == beaconUUID
        }
        // *** Emite TODOS os beacons encontrados SEMPRE! ***
        listener?.onBeaconsFound(matchingBeacons.map { toData(it) })
    }

    private fun toData(beacon: Beacon) = BeaconData(
        uuid = beacon.id1.toString(),
        major = beacon.id2.toInt(),
        minor = beacon.id3.toInt(),
        rssi = beacon.rssi,
        bluetoothName = beacon.bluetoothName,
        bluetoothAddress = beacon.bluetoothAddress,
        distanceMeters = beacon.distance
    )

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Notificações de Beacon"
            val descriptionText = "Canal para notificações relacionadas a beacons."
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(NOTIFICATION_CHANNEL_ID, name, importance).apply {
                description = descriptionText
            }
            val notificationManager: NotificationManager =
                context.getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun log(message: String) {
        if (debug) Log.d(TAG, message)
    }

    private fun getRegion(): Region {
        return Region("BeAroundSdkRegion", Identifier.parse(beaconUUID), null, null)
    }
}