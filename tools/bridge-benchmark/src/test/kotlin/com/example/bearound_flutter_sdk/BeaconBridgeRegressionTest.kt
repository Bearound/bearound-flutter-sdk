package com.example.bearound_flutter_sdk

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.LooperMode
import java.io.File
import java.security.MessageDigest

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
@LooperMode(LooperMode.Mode.PAUSED)
class BeaconBridgeRegressionTest {
    @Test
    fun `candidate without a sink never reads the list or queues delivery`() {
        for (size in listOf(0, 1, 6, 50)) BridgeFixture(BridgeVariant.CANDIDATE).use { fixture ->
            val input = CountingBeaconList(FixedBeaconLists.complete(size), rejectReads = true)
            fixture.update(input)
            assertEquals(0L, input.beaconReads)
            assertEquals(0L, input.sizeReads)
            assertEquals(0, fixture.queuedDeliveries())
        }
    }

    @Test
    fun `published callback without a sink performs measurable discarded work`() {
        BridgeFixture(BridgeVariant.PUBLISHED).use { fixture ->
            val input = CountingBeaconList(FixedBeaconLists.complete(6))
            fixture.update(input)
            assertEquals(6L, input.beaconReads)
            assertEquals(1, fixture.queuedDeliveries())
            fixture.drain()
            assertEquals(0, fixture.queuedDeliveries())
        }
    }

    @Test
    fun `both callbacks deliver exact complete payloads asynchronously for all fixed sizes`() {
        for (size in listOf(1, 6, 50)) {
            val observed = mutableListOf<Any?>()
            for (variant in BridgeVariant.values()) BridgeFixture(variant).use { fixture ->
                val sink = CapturingEventSink()
                fixture.subscribe(sink)
                val input = CountingBeaconList(FixedBeaconLists.complete(size))
                fixture.update(input)
                assertTrue(sink.events.isEmpty())
                assertEquals(size.toLong(), input.beaconReads)
                assertEquals(1, fixture.queuedDeliveries())
                fixture.drain()
                assertEquals(listOf(FixedBeaconLists.expectedComplete(size)), sink.events)
                assertEquals(0, fixture.queuedDeliveries())
                observed += sink.events.single()
            }
            assertEquals(observed[0], observed[1])
        }
    }

    @Test
    fun `subscribed empty lists still deliver an asynchronous empty payload`() {
        for (variant in BridgeVariant.values()) BridgeFixture(variant).use { fixture ->
            val sink = CapturingEventSink()
            fixture.subscribe(sink)
            fixture.update(emptyList())
            assertTrue(sink.events.isEmpty())
            assertEquals(1, fixture.queuedDeliveries())
            fixture.drain()
            assertEquals(listOf(mapOf("beacons" to emptyList<Any>())), sink.events)
        }
    }

    @Test
    fun `nullable fields remain null and absent RSSI stats remain omitted`() {
        for (variant in BridgeVariant.values()) BridgeFixture(variant).use { fixture ->
            val sink = CapturingEventSink()
            fixture.subscribe(sink)
            fixture.update(FixedBeaconLists.nullable())
            fixture.drain()
            assertEquals(listOf(FixedBeaconLists.expectedNullable()), sink.events)
        }
    }

    @Test
    fun `consecutive callbacks retain event order and current RSSI`() {
        for (variant in BridgeVariant.values()) BridgeFixture(variant).use { fixture ->
            val sink = CapturingEventSink()
            fixture.subscribe(sink)
            for (rssi in listOf(-70, -50, -80)) {
                fixture.update(FixedBeaconLists.complete(1).map { it.copy(rssi = rssi) })
            }
            assertEquals(3, fixture.queuedDeliveries())
            assertTrue(sink.events.isEmpty())
            fixture.drain()
            val values = sink.events.map { event ->
                val beacons = (event as Map<*, *>)["beacons"] as List<*>
                (beacons.single() as Map<*, *>)["rssi"]
            }
            assertEquals(listOf(-70, -50, -80), values)
        }
    }

    @Test
    fun `cancelling before drain prevents delivery to the old sink`() {
        for (variant in BridgeVariant.values()) BridgeFixture(variant).use { fixture ->
            val sink = CapturingEventSink()
            fixture.subscribe(sink)
            fixture.update(FixedBeaconLists.complete(1))
            fixture.subscribe(null)
            fixture.drain()
            assertTrue(sink.events.isEmpty())
        }
    }

    @Test
    fun `resubscribing before drain routes the queued payload to the live sink`() {
        for (variant in BridgeVariant.values()) BridgeFixture(variant).use { fixture ->
            val old = CapturingEventSink()
            val live = CapturingEventSink()
            fixture.subscribe(old)
            fixture.update(FixedBeaconLists.complete(1))
            fixture.subscribe(null)
            fixture.subscribe(live)
            fixture.drain()
            assertTrue(old.events.isEmpty())
            assertEquals(listOf(FixedBeaconLists.expectedComplete(1)), live.events)
        }
    }

    @Test
    fun `candidate drops callbacks between subscriptions and delivers the next observed callback`() {
        BridgeFixture(BridgeVariant.CANDIDATE).use { fixture ->
            fixture.subscribe(CapturingEventSink())
            fixture.subscribe(null)
            fixture.update(FixedBeaconLists.complete(1))
            assertEquals(0, fixture.queuedDeliveries())
            val sink = CapturingEventSink()
            fixture.subscribe(sink)
            fixture.update(FixedBeaconLists.complete(6))
            fixture.drain()
            assertEquals(listOf(FixedBeaconLists.expectedComplete(6)), sink.events)
        }
    }

    @Test
    fun `source hashes identify fixed published source generated baseline and real candidate`() {
        val hashes = sourceHashes()
        assertEquals("4f61d32d47b96cd16de0464c3f04f4aaea5d8a50", hashes["publishedCommit"])
        assertEquals("7d4fbbc13e6dc0ae1eced82576d50e9da18a798618d2320ef1f3ee0e0d94d270",
            hashes["publishedOriginal"])
        assertTrue(hashes.getValue("publishedGenerated").matches(Regex("[0-9a-f]{64}")))
        val candidate = File(System.getProperty("bridge.repo"),
            "android/src/main/kotlin/com/example/bearound_flutter_sdk/BearoundFlutterSdkPlugin.kt")
        val actual = MessageDigest.getInstance("SHA-256").digest(candidate.readBytes())
            .joinToString("") { "%02x".format(it) }
        assertEquals(actual, hashes["candidate"])
        assertEquals("com.github.Bearound:bearound-android-sdk:v3.14.0", hashes["nativeCoordinate"])
        assertEquals("3.14.0", io.bearound.sdk.BuildConfig.SDK_VERSION)
    }
}
