package com.example.bearound_flutter_sdk

import android.os.Handler
import android.os.Looper
import android.os.Message
import io.bearound.sdk.interfaces.BeAroundSDKListener
import io.bearound.sdk.models.Beacon
import io.bearound.sdk.models.BeaconMetadata
import io.bearound.sdk.models.RssiStats
import io.flutter.plugin.common.EventChannel
import org.robolectric.Shadows.shadowOf
import org.robolectric.util.ReflectionHelpers
import java.io.File
import java.util.Date
import java.util.Properties
import java.util.UUID

enum class BridgeVariant(val label: String) {
    PUBLISHED("published"), CANDIDATE("candidate")
}

class BridgeFixture(variant: BridgeVariant) : AutoCloseable {
    private val plugin: BeAroundSDKListener = when (variant) {
        BridgeVariant.PUBLISHED -> PublishedBearoundFlutterSdkPlugin()
        BridgeVariant.CANDIDATE -> BearoundFlutterSdkPlugin()
    }
    private val handler: Handler = ReflectionHelpers.getField(plugin, "mainHandler")

    fun subscribe(sink: EventChannel.EventSink?) {
        ReflectionHelpers.setField(plugin, "beaconsEventSink", sink)
    }

    fun update(beacons: List<Beacon>) = plugin.onBeaconsUpdated(beacons)

    fun queuedDeliveries(): Int {
        val queue = Looper.getMainLooper().queue
        return synchronized(queue) {
            var message: Message? = ReflectionHelpers.getField(queue, "mMessages")
            var count = 0
            while (message != null) {
                if (message.target === handler) count++
                message = ReflectionHelpers.getField(message, "next")
            }
            count
        }
    }

    fun drain() = shadowOf(Looper.getMainLooper()).idle()

    fun deliveryThreadId(): Long = handler.looper.thread.id

    override fun close() {
        handler.removeCallbacksAndMessages(null)
        subscribe(null)
    }
}

class CountingBeaconList(
    private val values: List<Beacon>, private val rejectReads: Boolean = false
) : AbstractList<Beacon>() {
    var beaconReads = 0L
        private set
    var sizeReads = 0L
        private set

    override val size: Int
        get() {
            sizeReads++
            check(!rejectReads) { "Unobserved callback read the list size" }
            return values.size
        }

    override fun get(index: Int): Beacon {
        beaconReads++
        check(!rejectReads) { "Unobserved callback read a beacon" }
        return values[index]
    }
}

class CapturingEventSink : EventChannel.EventSink {
    val events = mutableListOf<Any?>()
    override fun success(event: Any?) { events += event }
    override fun error(code: String, message: String?, details: Any?) {
        throw AssertionError("Unexpected bridge error: $code $message")
    }
    override fun endOfStream() { throw AssertionError("Unexpected end of stream") }
}

class BoundedBenchmarkSink : EventChannel.EventSink {
    var deliveries = 0L
        private set
    var checksum = 0L
        private set
    var deliveryThreadId: Long? = null
        private set

    override fun success(event: Any?) {
        deliveries++
        checksum = checksum * 31L + event.hashCode()
        deliveryThreadId = Thread.currentThread().id
    }
    override fun error(code: String, message: String?, details: Any?) {
        throw AssertionError("Unexpected bridge error: $code $message")
    }
    override fun endOfStream() { throw AssertionError("Unexpected end of stream") }
}

object FixedBeaconLists {
    const val BASE_TIME = 1_700_000_000_000L
    val UUID_VALUE: UUID = UUID.fromString("00000000-0000-0000-0000-000000000001")

    fun complete(size: Int): List<Beacon> = List(size) { index ->
        val time = BASE_TIME + index
        Beacon(
            uuid = UUID_VALUE, major = 1, minor = 400 + index,
            rssi = -65 - index, proximity = Beacon.Proximity.NEAR, accuracy = 1.25 + index,
            timestamp = Date(time),
            metadata = BeaconMetadata("4.2", 90 - index, index, 22 + index,
                -59, -62 - index, index % 2 == 0),
            txPower = -59, alreadySynced = index % 2 == 0, syncedAt = Date(time - 100),
            rssiRaw = -60 - index,
            rssiSamples = RssiStats(8, -68 - index, -60 - index, -64.5 - index,
                2.25, time - 7_000, time),
            isStale = index % 2 != 0
        )
    }

    fun expectedComplete(size: Int): Map<String, Any?> = mapOf("beacons" to List(size) { index ->
        val time = BASE_TIME + index
        mapOf(
            "uuid" to UUID_VALUE.toString(), "major" to 1, "minor" to 400 + index,
            "rssi" to -65 - index, "proximity" to "near", "accuracy" to 1.25 + index,
            "timestamp" to time, "metadata" to mapOf(
                "firmwareVersion" to "4.2", "batteryLevel" to 90 - index,
                "movements" to index, "temperature" to 22 + index, "txPower" to -59,
                "rssiFromBLE" to -62 - index, "isConnectable" to (index % 2 == 0)
            ),
            "txPower" to -59, "alreadySynced" to (index % 2 == 0), "syncedAt" to time - 100,
            "isStale" to (index % 2 != 0), "rssiRaw" to -60 - index,
            "rssiSamples" to mapOf(
                "count" to 8, "min" to -68 - index, "max" to -60 - index,
                "avg" to -64.5 - index, "stdDev" to 2.25,
                "firstSeen" to time - 7_000, "lastSeen" to time
            )
        )
    })

    fun nullable(): List<Beacon> = listOf(Beacon(
        uuid = UUID_VALUE, major = 1, minor = 400, rssi = -65,
        proximity = Beacon.Proximity.UNKNOWN, accuracy = -1.0, timestamp = Date(BASE_TIME)
    ))

    fun expectedNullable(): Map<String, Any?> = mapOf("beacons" to listOf(mapOf(
        "uuid" to UUID_VALUE.toString(), "major" to 1, "minor" to 400, "rssi" to -65,
        "proximity" to "unknown", "accuracy" to -1.0, "timestamp" to BASE_TIME,
        "metadata" to null, "txPower" to null, "alreadySynced" to false,
        "syncedAt" to null, "isStale" to false, "rssiRaw" to null
    )))
}

fun sourceHashes(): Map<String, String> {
    val properties = Properties()
    File(checkNotNull(System.getProperty("bridge.hashes"))).inputStream().use { properties.load(it) }
    return properties.stringPropertyNames().associateWith { properties.getProperty(it) }
}
