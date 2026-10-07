package io.bearound.qa.bridge

import android.content.Context
import android.os.Build
import android.os.Debug
import android.os.SystemClock
import io.flutter.plugin.common.StandardMethodCodec
import org.json.JSONArray
import org.json.JSONObject
import java.util.Properties

class PhysicalModelProbe(private val context: Context, private val packedRows: Boolean = false) {
    private val identityFields = setOf("uuid", "major", "minor")
    private val observationFields = listOf("rssi", "proximity", "accuracy", "timestamp", "metadata",
        "txPower", "alreadySynced", "syncedAt", "isStale", "rssiRaw")
    private val metadataFields = listOf("firmwareVersion", "batteryLevel", "movements", "temperature",
        "txPower", "rssiFromBLE", "isConnectable")
    private val statsFields = listOf("count", "min", "max", "avg", "stdDev", "firstSeen", "lastSeen")

    @Suppress("UNCHECKED_CAST")
    private fun nestedRow(value: Any?, fields: List<String>): Any? {
        if (value == null) return null
        val map = value as Map<String, Any?>
        check(map.keys.containsAll(fields)) { "Nested row is missing a required published field" }
        return fields.map { map[it] } + listOf(map.filterKeys { it !in fields }.takeIf { it.isNotEmpty() })
    }

    @Suppress("UNCHECKED_CAST")
    private fun nestedMap(value: Any?, fields: List<String>): Any? {
        if (value == null) return null
        val row = value as List<Any?>
        return fields.mapIndexed { index, field -> field to row[index] }.toMap().toMutableMap().apply {
            (row.last() as Map<String, Any?>?)?.let { putAll(it) }
        }
    }

    private fun observationRow(value: Map<String, Any?>): List<Any?> {
        check(value.keys.containsAll(observationFields)) { "Observation is missing a required published field" }
        val row = observationFields.map { field ->
            if (field == "metadata") nestedRow(value[field], metadataFields) else value[field]
        }
        val extras = value.filterKeys { it !in observationFields && it !in identityFields && it != "rssiSamples" }
        return row + listOf(value.containsKey("rssiSamples"), nestedRow(value["rssiSamples"], statsFields),
            extras.takeIf { it.isNotEmpty() })
    }

    @Suppress("UNCHECKED_CAST")
    private fun observationMap(value: Any?): Map<String, Any?> {
        val row = value as List<Any?>
        val map = observationFields.mapIndexed { index, field ->
            field to if (field == "metadata") nestedMap(row[index], metadataFields) else row[index]
        }.toMap().toMutableMap()
        if (row[10] == true) map["rssiSamples"] = nestedMap(row[11], statsFields)
        (row[12] as Map<String, Any?>?)?.let { map.putAll(it) }
        return map
    }

    private fun pack(frames: List<Map<String, Any?>>): Map<String, Any?> {
        val indices = mutableMapOf<List<Any?>, Int>()
        val beacons = mutableListOf<MutableMap<String, Any?>>()
        val packedFrames = frames.map { frame ->
            @Suppress("UNCHECKED_CAST")
            val values = frame.getValue("beacons") as List<Map<String, Any?>>
            val references = values.map { value ->
                val identity = listOf(value["uuid"], value["major"], value["minor"])
                val index = indices.getOrPut(identity) {
                    val next = beacons.size
                    beacons.add(mutableMapOf("uuid" to identity[0], "major" to identity[1],
                        "minor" to identity[2], "observations" to mutableListOf<Any?>() ))
                    next
                }
                @Suppress("UNCHECKED_CAST")
                val observations = beacons[index].getValue("observations") as MutableList<Any?>
                val reference = listOf(index, observations.size)
                observations.add(if (packedRows) observationRow(value) else value.filterKeys { it !in identityFields })
                reference
            }
            mapOf("references" to references)
        }
        return mutableMapOf<String, Any?>("schemaVersion" to if (packedRows) 2 else 1,
            "beacons" to beacons, "frames" to packedFrames).apply {
            if (packedRows) {
                put("observationFields", observationFields + listOf("rssiSamplesPresent", "rssiSamples", "extraFields"))
                put("metadataFields", metadataFields + "extraFields")
                put("rssiSampleFields", statsFields + "extraFields")
            }
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun unpack(value: Any?): List<Map<String, Any?>> {
        val packed = value as Map<String, Any?>
        check(packed["schemaVersion"] == if (packedRows) 2 else 1)
        val beacons = packed.getValue("beacons") as List<Map<String, Any?>>
        val frames = packed.getValue("frames") as List<Map<String, Any?>>
        return frames.map { frame ->
            val references = frame.getValue("references") as List<List<Int>>
            val restored = references.map { reference ->
                val beacon = beacons[reference[0]]
                val observations = beacon.getValue("observations") as List<Any?>
                val observation = if (packedRows) observationMap(observations[reference[1]])
                    else observations[reference[1]] as Map<String, Any?>
                mutableMapOf("uuid" to beacon["uuid"], "major" to beacon["major"],
                    "minor" to beacon["minor"]).apply { putAll(observation) }
            }
            mapOf("beacons" to restored)
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun frames(size: Int, count: Int): List<Map<String, Any?>> = List(count) { frame ->
        val values = (FixedBeaconLists.expectedComplete(size)["beacons"] as List<Map<String, Any?>>)
            .map { original ->
                original.toMutableMap().apply {
                    this["timestamp"] = (original["timestamp"] as Long) + frame * 1000L
                    this["rssi"] = (original["rssi"] as Int) - frame % 9
                    this["alreadySynced"] = frame % 2 == 0
                    this["syncedAt"] = if (frame % 2 == 0) (this["timestamp"] as Long) - 100 else null
                    this["metadata"] = (original["metadata"] as Map<String, Any?>).toMutableMap().apply {
                        this["batteryLevel"] = (this["batteryLevel"] as Int) - frame % 4
                        this["temperature"] = (this["temperature"] as Int) + frame % 3
                        this["movements"] = frame
                    }
                    if (frame % 11 == 10) {
                        this["metadata"] = null
                        this["txPower"] = null
                        this["rssiRaw"] = null
                        remove("rssiSamples")
                    }
                }
            }
        mapOf("beacons" to if (frame % 2 == 0) values else values.reversed())
    }

    private fun stat(name: String): Long? = Debug.getRuntimeStat(name)?.toLongOrNull()
    private fun delta(before: Long?, after: Long?): Any =
        if (before != null && after != null && after >= before) after - before else JSONObject.NULL

    private fun measure(input: List<Map<String, Any?>>, compact: Boolean, operations: Int): JSONObject {
        var encodeCpu = 0L
        var decodeCpu = 0L
        var encodedBytes = 0
        val allocatedBefore = stat("art.gc.bytes-allocated")
        val gcBefore = stat("art.gc.gc-count")
        val wallStart = SystemClock.elapsedRealtimeNanos()
        repeat(operations) {
            val encodeStart = Debug.threadCpuTimeNanos()
            val value = if (compact) pack(input) else input
            val buffer = StandardMethodCodec.INSTANCE.encodeSuccessEnvelope(value)
            encodedBytes = buffer.position()
            encodeCpu += Debug.threadCpuTimeNanos() - encodeStart
            buffer.flip()
            val decodeStart = Debug.threadCpuTimeNanos()
            val decoded = StandardMethodCodec.INSTANCE.decodeEnvelope(buffer)
            val restored = if (compact) unpack(decoded) else decoded
            decodeCpu += Debug.threadCpuTimeNanos() - decodeStart
            check(restored == input) { "Lossless codec reconstruction failed" }
        }
        val wall = SystemClock.elapsedRealtimeNanos() - wallStart
        return JSONObject().put("variant", if (compact) "prototype" else "baseline")
            .put("operations", operations).put("encodedBytes", encodedBytes)
            .put("encodeCpuNs", encodeCpu).put("decodeCpuNs", decodeCpu)
            .put("roundTripCpuNs", encodeCpu + decodeCpu).put("wallNs", wall)
            .put("processAllocatedBytes", delta(allocatedBefore, stat("art.gc.bytes-allocated")))
            .put("gcCount", delta(gcBefore, stat("art.gc.gc-count")))
            .put("goldenEqual", true)
    }

    fun run(runId: String): JSONObject {
        val properties = Properties()
        context.assets.open("source-hashes.properties").use { properties.load(it) }
        val rounds = JSONArray()
        val nullable = listOf(FixedBeaconLists.expectedNullable(), mapOf("beacons" to emptyList<Any>()))
        check(unpack(pack(nullable)) == nullable)
        val duplicate = frames(1, 1).map { mapOf("beacons" to listOf(
            (it["beacons"] as List<*>)[0], (it["beacons"] as List<*>)[0])) }
        check(unpack(pack(duplicate)) == duplicate)
        for (size in listOf(1, 6, 50)) for (count in listOf(1, 10, 100)) {
            val input = frames(size, count)
            val operations = maxOf(1, 1000 / (size * count))
            val warmup = maxOf(20, operations / 10)
            measure(input, false, warmup)
            measure(input, true, warmup)
            for (cycle in 1..3) {
                listOf(false, true, true, false).forEachIndexed { index, compact ->
                    rounds.put(measure(input, compact, operations).put("listSize", size)
                        .put("frames", count).put("observations", size * count)
                        .put("cycle", cycle).put("orderInCycle", index + 1)
                        .put("warmupOperationsPerVariant", warmup))
                }
            }
        }
        check(rounds.length() == 108)
        return JSONObject().put("status", "success").put("runId", runId)
            .put("schemaVersion", 1).put("modelSchemaVersion", if (packedRows) 2 else 1).put("rounds", rounds)
            .put("modelExample", JSONObject(pack(frames(1, 2))))
            .put("sourceHashes", JSONObject(properties.stringPropertyNames().associateWith { properties.getProperty(it) }))
            .put("environment", JSONObject().put("model", Build.MODEL).put("sdkInt", Build.VERSION.SDK_INT)
                .put("thread", Thread.currentThread().name).put("debuggable", true))
            .put("controls", JSONObject().put("typedGoldenEveryOperation", true).put("order", true)
                .put("nullableAndOmittedFields", true).put("changingMetadata", true)
                .put("emptyFrame", true).put("duplicateIdentity", true))
            .put("scope", "Private batch representation and real Flutter codec on ART worker thread; " +
                "encode includes grouping, decode includes reconstruction, all operations preserve golden fields; " +
                "wall/process allocations include equality validation and other process activity; " +
                "no scanner, radio, network, Flutter engine or published protocol change")
    }
}
