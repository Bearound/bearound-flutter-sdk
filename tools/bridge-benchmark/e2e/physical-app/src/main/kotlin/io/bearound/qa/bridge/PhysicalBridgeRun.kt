package io.bearound.qa.bridge

import android.content.Context
import android.os.Build
import android.os.Debug
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.plugin.common.StandardMethodCodec
import org.json.JSONArray
import org.json.JSONObject
import java.util.Properties
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine

class PhysicalBridgeRun(
    private val context: Context, runId: String, private val progress: (String) -> Unit
) {
    val controls = JSONArray()
    val rounds = JSONArray()
    private val codecRounds = JSONArray()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val mainThreadId = Looper.getMainLooper().thread.id
    val result = JSONObject().put("schemaVersion", 1).put("runId", runId)
        .put("controls", controls).put("rounds", rounds).put("codecRounds", codecRounds)
        .put("config", JSONObject().put("listSizes", JSONArray(listOf(1, 6, 50)))
            .put("abbaCycles", 3).put("callbacksPerRound", 1000).put("warmupCallbacks", 5000)
            .put("batchSize", 25).put("fixtureBaseTimeMs", FixedBeaconLists.BASE_TIME)
            .put("queueProbe", "public Handler.hasMessages(0), presence per producer batch"))
        .put("scope", "Synthetic actual Android bridge callbacks and separate codec roundtrips; " +
            "no Flutter engine, Dart consumer, scanner, radio, network, or whole-app ANR certification")

    suspend fun run() {
        check(Thread.currentThread().id == mainThreadId) { "Run must execute on the Android main thread" }
        val properties = Properties()
        context.assets.open("source-hashes.properties").use { properties.load(it) }
        result.put("sourceHashes", JSONObject(properties.stringPropertyNames().associateWith {
            properties.getProperty(it)
        }))
        check(properties.getProperty("nativeCoordinate") == "com.github.Bearound:bearound-android-sdk:v3.14.0")
        result.put("environment", JSONObject().put("sdkInt", Build.VERSION.SDK_INT)
            .put("osRelease", Build.VERSION.RELEASE).put("manufacturer", Build.MANUFACTURER)
            .put("model", Build.MODEL).put("abis", JSONArray(Build.SUPPORTED_ABIS.toList()))
            .put("runtime", System.getProperty("java.vm.name"))
            .put("mainThreadId", mainThreadId).put("debuggable", true)
            .put("allocationScope", "ART process-wide bytes, may include UI and other threads")
            .put("wallScope", "Elapsed real time including scheduling and main-looper yields")
            .put("cpuScope", "Main-thread producer batch CPU plus instrumented sink CPU")
            .put("forcedGc", false).put("allocationCounterSupported", runtimeStat("art.gc.bytes-allocated") != null)
            .put("allocationUnavailableReason", if (runtimeStat("art.gc.bytes-allocated") == null)
                "ART runtime allocation counter unavailable or not numeric" else JSONObject.NULL))
        progress("Bridge QA: functional controls")
        regressions()
        codecChecks()
        for (size in listOf(1, 6, 50)) for (subscribed in listOf(false, true)) {
            for (variant in BridgeVariant.entries) {
                progress("Bridge QA: warmup ${variant.label}, size $size, subscribed $subscribed")
                measure(variant, size, subscribed, 5000, null, null, false)
            }
            for (cycle in 1..3) {
                listOf(BridgeVariant.PUBLISHED, BridgeVariant.CANDIDATE,
                    BridgeVariant.CANDIDATE, BridgeVariant.PUBLISHED).forEachIndexed { order, variant ->
                    progress("Bridge QA: ${variant.label}, size $size, subscribed $subscribed, cycle $cycle/${order + 1}")
                    rounds.put(measure(variant, size, subscribed, 1000, cycle, order + 1, true))
                }
            }
        }
        check(rounds.length() == 72)
        control("all_round_controls", "72 ABBA rounds passed list, queue, event, checksum, and thread controls")
    }

    private fun control(name: String, detail: String = "passed") {
        controls.put(JSONObject().put("name", name).put("passed", true).put("detail", detail))
    }

    private suspend fun yieldMain() = suspendCoroutine<Unit> { continuation ->
        check(mainHandler.post { continuation.resume(Unit) }) { "Main-looper continuation rejected" }
    }

    private suspend fun regressions() {
        for (size in listOf(0, 1, 6, 50)) {
            PhysicalFixture(BridgeVariant.CANDIDATE).use { fixture ->
                val list = CountingBeaconList(FixedBeaconLists.complete(size), rejectReads = true)
                fixture.update(list)
                check(list.sizeReads == 0L && list.beaconReads == 0L && !fixture.hasPendingDelivery())
                yieldMain()
                check(!fixture.hasPendingDelivery())
                control("candidate_unobserved_zero_reads_queue_$size")
            }
        }
        PhysicalFixture(BridgeVariant.PUBLISHED).use { fixture ->
            val list = CountingBeaconList(FixedBeaconLists.complete(6))
            fixture.update(list)
            check(list.beaconReads == 6L && list.sizeReads > 0L && fixture.hasPendingDelivery())
            yieldMain()
            check(!fixture.hasPendingDelivery())
            control("published_unobserved_positive_reads_queue")
        }
        for (variant in BridgeVariant.entries) {
            for (size in listOf(0, 1, 6, 50)) {
                PhysicalFixture(variant).use { fixture ->
                    val sink = CapturingSink()
                    fixture.subscribe(sink)
                    fixture.update(FixedBeaconLists.complete(size))
                    check(sink.events.isEmpty() && fixture.hasPendingDelivery())
                    yieldMain()
                    check(sink.error == null && sink.events == listOf(FixedBeaconLists.expectedComplete(size)))
                    control("${variant.label}_golden_async_$size")
                }
            }
            PhysicalFixture(variant).use { fixture ->
                val sink = CapturingSink()
                fixture.subscribe(sink)
                fixture.update(FixedBeaconLists.nullable())
                yieldMain()
                check(sink.error == null && sink.events == listOf(FixedBeaconLists.expectedNullable()))
                control("${variant.label}_golden_nullable")
            }
            PhysicalFixture(variant).use { fixture ->
                val sink = CapturingSink()
                fixture.subscribe(sink)
                val inputs = listOf(1, 6, 50)
                inputs.forEach { fixture.update(FixedBeaconLists.complete(it)) }
                check(sink.events.isEmpty() && fixture.hasPendingDelivery())
                yieldMain()
                check(sink.error == null && sink.events == inputs.map { FixedBeaconLists.expectedComplete(it) })
                control("${variant.label}_callback_order")
            }
            PhysicalFixture(variant).use { fixture ->
                val old = CapturingSink()
                fixture.subscribe(old)
                fixture.update(FixedBeaconLists.complete(1))
                fixture.subscribe(null)
                yieldMain()
                check(old.events.isEmpty())
                control("${variant.label}_cancel_before_delivery")
                fixture.subscribe(old)
                fixture.update(FixedBeaconLists.complete(6))
                fixture.subscribe(null)
                val replacement = CapturingSink()
                fixture.subscribe(replacement)
                yieldMain()
                check(old.events.isEmpty() && replacement.events == listOf(FixedBeaconLists.expectedComplete(6)))
                control("${variant.label}_live_sink_resubscribe")
            }
        }
        PhysicalFixture(BridgeVariant.CANDIDATE).use { fixture ->
            val sink = CapturingSink()
            fixture.subscribe(sink)
            fixture.subscribe(null)
            fixture.update(CountingBeaconList(FixedBeaconLists.complete(50), rejectReads = true))
            check(!fixture.hasPendingDelivery())
            fixture.subscribe(sink)
            yieldMain()
            check(sink.events.isEmpty())
            fixture.update(FixedBeaconLists.complete(6))
            yieldMain()
            check(sink.events == listOf(FixedBeaconLists.expectedComplete(6)))
            control("candidate_between_subscriptions_discard")
        }
    }

    private fun codecChecks() {
        val payloads = listOf("empty" to FixedBeaconLists.expectedComplete(0),
            "nullable" to FixedBeaconLists.expectedNullable()) +
            listOf(1, 6, 50).map { "complete_$it" to FixedBeaconLists.expectedComplete(it) }
        for ((name, payload) in payloads) {
            val cpuStart = Debug.threadCpuTimeNanos()
            val wallStart = SystemClock.elapsedRealtimeNanos()
            val buffer = StandardMethodCodec.INSTANCE.encodeSuccessEnvelope(payload)
            val bytes = buffer.position()
            buffer.flip()
            val decoded = StandardMethodCodec.INSTANCE.decodeEnvelope(buffer)
            val cpu = Debug.threadCpuTimeNanos() - cpuStart
            val wall = SystemClock.elapsedRealtimeNanos() - wallStart
            check(decoded == payload) { "Codec golden mismatch: $name" }
            codecRounds.put(JSONObject().put("mode", "codec-roundtrip").put("fixture", name)
                .put("encodedBytes", bytes).put("threadCpuNs", cpu).put("wallNs", wall)
                .put("goldenEqual", true).put("scope", "Functional one-shot probe, separate from raw bridge rounds"))
            control("codec_golden_$name")
        }
    }

    private fun runtimeStat(name: String): Long? = try {
        Debug.getRuntimeStat(name)?.toLongOrNull()
    } catch (_: RuntimeException) { null }

    private fun delta(before: Long?, after: Long?): Any =
        if (before != null && after != null && after >= before) after - before else JSONObject.NULL

    private suspend fun measure(
        variant: BridgeVariant, size: Int, subscribed: Boolean, count: Int,
        cycle: Int?, order: Int?, measured: Boolean
    ): JSONObject {
        val input = CountingBeaconList(FixedBeaconLists.complete(size))
        val sink = BoundedSink(mainThreadId)
        val expectedHash = FixedBeaconLists.expectedComplete(size).hashCode()
        var expectedChecksum = 0L
        if (subscribed) repeat(count) { expectedChecksum = expectedChecksum * 31L + expectedHash }
        PhysicalFixture(variant).use { fixture ->
            if (subscribed) fixture.subscribe(sink)
            var producerCpu = 0L
            var pendingBatches = 0
            val allocatedBefore = runtimeStat("art.gc.bytes-allocated")
            val gcBefore = runtimeStat("art.gc.gc-count")
            val gcTimeBefore = runtimeStat("art.gc.gc-time")
            val wallStart = SystemClock.elapsedRealtimeNanos()
            repeat(count / 25) {
                val cpuStart = Debug.threadCpuTimeNanos()
                repeat(25) { fixture.update(input) }
                if (fixture.hasPendingDelivery()) pendingBatches++
                producerCpu += Debug.threadCpuTimeNanos() - cpuStart
                yieldMain()
            }
            val wall = SystemClock.elapsedRealtimeNanos() - wallStart
            val allocatedAfter = runtimeStat("art.gc.bytes-allocated")
            val gcAfter = runtimeStat("art.gc.gc-count")
            val gcTimeAfter = runtimeStat("art.gc.gc-time")
            val maps = variant == BridgeVariant.PUBLISHED || subscribed
            check(input.beaconReads == if (maps) size.toLong() * count else 0L) { "List-read control failed" }
            check(if (maps) input.sizeReads > 0 else input.sizeReads == 0L) { "List-size control failed" }
            check(pendingBatches == if (maps) count / 25 else 0) { "Public queue-presence control failed" }
            check(!fixture.hasPendingDelivery()) { "Bridge delivery remained queued after drain" }
            check(sink.deliveries == if (subscribed) count.toLong() else 0L) { "Event-count control failed" }
            check(sink.checksum == expectedChecksum && !sink.wrongThread && sink.error == null) {
                "Sink checksum or thread control failed"
            }
            return JSONObject().put("mode", "raw-bridge").put("variant", variant.label)
                .put("listSize", size).put("subscribed", subscribed).put("cycle", cycle ?: JSONObject.NULL)
                .put("orderInCycle", order ?: JSONObject.NULL).put("callbacks", count).put("measured", measured)
                .put("producerCpuNs", producerCpu).put("consumerCpuNs", sink.consumerCpuNs)
                .put("threadCpuNs", producerCpu + sink.consumerCpuNs).put("wallNs", wall)
                .put("processAllocatedBytes", delta(allocatedBefore, allocatedAfter))
                .put("gcCount", delta(gcBefore, gcAfter)).put("gcTimeMs", delta(gcTimeBefore, gcTimeAfter))
                .put("sizeReads", input.sizeReads).put("beaconReads", input.beaconReads)
                .put("events", sink.deliveries).put("checksum", sink.checksum)
                .put("deliveryThreadId", sink.deliveryThreadId ?: JSONObject.NULL)
                .put("queuePresenceSamples", count / 25).put("pendingDeliveryBatches", pendingBatches)
                .put("controlsPassed", true)
        }
    }
}
