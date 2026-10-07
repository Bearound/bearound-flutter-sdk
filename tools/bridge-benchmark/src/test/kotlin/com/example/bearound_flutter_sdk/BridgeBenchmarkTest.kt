package com.example.bearound_flutter_sdk

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.LooperMode
import java.io.File

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
@LooperMode(LooperMode.Mode.PAUSED)
class BridgeBenchmarkTest {
    @Test
    fun `measure real bridge callbacks with equal bounded ABBA workloads`() {
        val callbackCount = 1_000
        val warmupCount = 5_000
        val batchBound = 25
        val cycles = 3
        val sizes = listOf(1, 6, 50)
        val inputs = sizes.associateWith { FixedBeaconLists.complete(it) }
        val expected = sizes.associateWith { FixedBeaconLists.expectedComplete(it) }
        val thread = Thread.currentThread()
        val factory = Class.forName("java.lang.management.ManagementFactory")
        val cpuInterface = Class.forName("java.lang.management.ThreadMXBean")
        val allocationInterface = Class.forName("com.sun.management.ThreadMXBean")
        val gcInterface = Class.forName("java.lang.management.GarbageCollectorMXBean")
        val cpuBean = factory.getMethod("getThreadMXBean").invoke(null)
        val currentCpu = cpuInterface.getMethod("getCurrentThreadCpuTime")
        val allocationMethod = allocationInterface.getMethod("getThreadAllocatedBytes", java.lang.Long.TYPE)
        val cpuReady = runCatching {
            if (cpuInterface.getMethod("isCurrentThreadCpuTimeSupported").invoke(cpuBean) != true) false else {
                cpuInterface.getMethod("setThreadCpuTimeEnabled", java.lang.Boolean.TYPE).invoke(cpuBean, true)
                true
            }
        }.getOrDefault(false)
        val allocationReady = runCatching {
            if (!allocationInterface.isInstance(cpuBean) ||
                allocationInterface.getMethod("isThreadAllocatedMemorySupported").invoke(cpuBean) != true) false else {
                allocationInterface.getMethod("setThreadAllocatedMemoryEnabled", java.lang.Boolean.TYPE)
                    .invoke(cpuBean, true)
                true
            }
        }.getOrDefault(false)
        fun cpu(): Long? = if (cpuReady) (currentCpu.invoke(cpuBean) as Long).takeIf { it >= 0 } else null
        fun allocated(): Long? = if (allocationReady)
            (allocationMethod.invoke(cpuBean, thread.id) as Long).takeIf { it >= 0 } else null
        fun delta(before: Long?, after: Long?): Any =
            if (before != null && after != null) after - before else JSONObject.NULL
        fun gcCounts(): Pair<Long, Long>? {
            val beans = factory.getMethod("getGarbageCollectorMXBeans").invoke(null) as List<*>
            val counts = beans.map { gcInterface.getMethod("getCollectionCount").invoke(it) as Long }
            val times = beans.map { gcInterface.getMethod("getCollectionTime").invoke(it) as Long }
            return if (beans.isEmpty() || counts.any { it < 0 } || times.any { it < 0 }) null
                else counts.sum() to times.sum()
        }

        val measurements = JSONArray()
        for (size in sizes) for (subscribed in listOf(false, true)) {
            for (variant in BridgeVariant.values()) BridgeFixture(variant).use { fixture ->
                if (subscribed) fixture.subscribe(BoundedBenchmarkSink())
                repeat(warmupCount / batchBound) {
                    repeat(batchBound) { fixture.update(inputs.getValue(size)) }
                    fixture.queuedDeliveries()
                    fixture.drain()
                }
                assertEquals(0, fixture.queuedDeliveries())
            }

            var round = 0
            repeat(cycles) {
                for (variant in listOf(BridgeVariant.PUBLISHED, BridgeVariant.CANDIDATE,
                    BridgeVariant.CANDIDATE, BridgeVariant.PUBLISHED)) {
                    round++
                    BridgeFixture(variant).use { fixture ->
                        val input = CountingBeaconList(inputs.getValue(size))
                        val sink = BoundedBenchmarkSink()
                        if (subscribed) fixture.subscribe(sink)
                        assertEquals(thread.id, fixture.deliveryThreadId())
                        var queued = 0L
                        val gcBefore = gcCounts()
                        val allocatedBefore = allocated()
                        val cpuBefore = cpu()
                        val wallStart = System.nanoTime()
                        repeat(callbackCount / batchBound) {
                            repeat(batchBound) { fixture.update(input) }
                            val actualQueue = fixture.queuedDeliveries()
                            check(actualQueue <= batchBound) { "Delivery batch exceeded its bound" }
                            queued += actualQueue
                            fixture.drain()
                        }
                        val wallNs = System.nanoTime() - wallStart
                        val cpuAfter = cpu()
                        val allocatedAfter = allocated()
                        val gcAfter = gcCounts()

                        val performsMapping = subscribed || variant == BridgeVariant.PUBLISHED
                        assertEquals(if (performsMapping) callbackCount.toLong() * size else 0L,
                            input.beaconReads)
                        if (!performsMapping) assertEquals(0L, input.sizeReads)
                        assertEquals(if (performsMapping) callbackCount.toLong() else 0L, queued)
                        assertEquals(if (subscribed) callbackCount.toLong() else 0L, sink.deliveries)
                        assertEquals(0, fixture.queuedDeliveries())
                        var expectedChecksum = 0L
                        if (subscribed) {
                            repeat(callbackCount) {
                                expectedChecksum = expectedChecksum * 31L + expected.getValue(size).hashCode()
                            }
                            assertEquals(thread.id, sink.deliveryThreadId)
                        }
                        assertEquals(expectedChecksum, sink.checksum)

                        measurements.put(JSONObject()
                            .put("listSize", size).put("subscribed", subscribed)
                            .put("variant", variant.label).put("round", round)
                            .put("callbackCount", callbackCount).put("beaconReads", input.beaconReads)
                            .put("deliveries", sink.deliveries).put("queuedDeliveryCount", queued)
                            .put("threadCpuNs", delta(cpuBefore, cpuAfter)).put("wallNs", wallNs)
                            .put("allocatedBytes", delta(allocatedBefore, allocatedAfter))
                            .put("gcCount", delta(gcBefore?.first, gcAfter?.first))
                            .put("gcTimeMs", delta(gcBefore?.second, gcAfter?.second))
                            .put("payloadChecksum", sink.checksum))
                    }
                }
            }
        }
        assertEquals(72, measurements.length())
        val fixtureInputs = JSONObject()
        for (size in sizes) fixtureInputs.put(size.toString(), JSONObject(expected.getValue(size)))
        val environment = JSONObject()
            .put("javaVersion", System.getProperty("java.version"))
            .put("javaVm", System.getProperty("java.vm.name"))
            .put("os", System.getProperty("os.name"))
            .put("osVersion", System.getProperty("os.version"))
            .put("architecture", System.getProperty("os.arch"))
            .put("runtime", "Robolectric 4.13 / Android API 34 / Gradle 8.13")
            .put("nativeCoordinate", sourceHashes().getValue("nativeCoordinate"))
            .put("nativeVersion", io.bearound.sdk.BuildConfig.SDK_VERSION)
            .put("threadName", thread.name).put("threadId", thread.id)
            .put("queueDrainOnMeasuredThread", true)
            .put("cpuProvider", cpuBean.javaClass.name)
            .put("allocationProvider", if (allocationReady) cpuBean.javaClass.name else JSONObject.NULL)
            .put("cpuUnavailableReason", if (cpu() != null) JSONObject.NULL else "Thread CPU provider unavailable")
            .put("allocationUnavailableReason", if (allocated() != null) JSONObject.NULL else "Thread allocation provider unavailable")
            .put("gcUnavailableReason", if (gcCounts() != null) JSONObject.NULL else "GC counters unavailable")
            .put("timingScope", "Real callback, queue probes, payload checksum and equal queue drain")
            .put("excluded", "Fixture creation, IO, Robolectric initialization, Flutter codec/engine, JNI, Dart and BLE")
            .put("instrumentationLimit", "List counters, queue inspection, metric probes and sink checksum add equal instrumentation overhead")
        val result = JSONObject().put("schema", 1).put("environment", environment)
            .put("inputConfig", JSONObject()
                .put("listSizes", JSONArray(sizes)).put("sinkModes", JSONArray(listOf(false, true)))
                .put("callbacksPerRound", callbackCount).put("warmupCallbacksPerVariant", warmupCount)
                .put("batchBound", batchBound).put("abbaCycles", cycles)
                .put("order", JSONArray(listOf("published", "candidate", "candidate", "published")))
                .put("fixtures", fixtureInputs))
            .put("sourceHashes", JSONObject(sourceHashes())).put("measurements", measurements)
        val output = File(checkNotNull(System.getProperty("bridge.output")) { "Absolute JSON output is required" })
        assertTrue("JSON output must be absolute", output.isAbsolute)
        output.parentFile?.mkdirs()
        output.writeText(result.toString(2) + "\n")
        println("Bridge benchmark wrote ${measurements.length()} measurements to $output")
    }
}
