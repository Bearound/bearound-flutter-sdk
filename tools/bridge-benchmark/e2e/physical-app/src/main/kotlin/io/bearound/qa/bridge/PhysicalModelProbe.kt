package io.bearound.qa.bridge

import android.content.Context
import android.os.Build
import android.os.Debug
import android.os.SystemClock
import io.flutter.plugin.common.StandardMethodCodec
import org.json.JSONArray
import org.json.JSONObject
import java.util.Properties

class PhysicalModelProbe(
    private val context: Context,
    private val packedRows: Boolean = false,
    private val dictionaryRows: Boolean = false
) {
    private val identityFields = setOf("uuid", "major", "minor")
    private val observationFields = listOf("rssi", "proximity", "accuracy", "timestamp", "metadata",
        "txPower", "alreadySynced", "syncedAt", "isStale", "rssiRaw")
    private val dictionaryRequiredFields = identityFields + observationFields
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
    private fun packDictionary(frames: List<Map<String, Any?>>): Map<String, Any?> {
        val strings = mutableListOf<String>()
        val stringIndices = mutableMapOf<String, Int>()
        val metadata = mutableListOf<List<Any?>>()
        val metadataIndices = mutableMapOf<Map<String, Any?>, Int>()
        val stats = mutableListOf<List<Any?>>()
        val statsIndices = mutableMapOf<Map<String, Any?>, Int>()
        val beacons = mutableListOf<List<Any?>>()
        val beaconIndices = mutableMapOf<List<Any?>, Int>()
        fun stringIndex(value: Any?): Int? {
            if (value == null) return null
            check(value is String) { "Dictionary string field has an unexpected type" }
            return stringIndices.getOrPut(value) { strings.add(value); strings.lastIndex }
        }
        fun metadataIndex(value: Any?): Int? {
            if (value == null) return null
            val map = value as Map<String, Any?>
            check(map.keys.containsAll(metadataFields)) { "Metadata row is missing a required field" }
            return metadataIndices.getOrPut(map) {
                val row = metadataFields.map { field ->
                    if (field == "firmwareVersion") stringIndex(map[field]) else map[field]
                } + listOf(map.filterKeys { it !in metadataFields }.takeIf { it.isNotEmpty() })
                metadata.add(row)
                metadata.lastIndex
            }
        }
        fun statsIndex(value: Any?): Int? {
            if (value == null) return null
            val map = value as Map<String, Any?>
            return statsIndices.getOrPut(map) {
                stats.add(nestedRow(map, statsFields) as List<Any?>)
                stats.lastIndex
            }
        }
        val frameReferences = frames.map { frame ->
            (frame.getValue("beacons") as List<Map<String, Any?>>).map { value ->
                check(value.keys.containsAll(dictionaryRequiredFields)) {
                    "Dictionary observation is missing a required field"
                }
                val identity = listOf(value["uuid"], value["major"], value["minor"])
                val index = beaconIndices.getOrPut(identity) {
                    beacons.add(listOf(stringIndex(identity[0]), identity[1], identity[2], mutableListOf<Any?>()))
                    beacons.lastIndex
                }
                val observations = beacons[index][3] as MutableList<Any?>
                val reference = listOf(index, observations.size)
                val row = observationFields.map { field ->
                    when (field) {
                        "proximity" -> stringIndex(value[field])
                        "metadata" -> metadataIndex(value[field])
                        else -> value[field]
                    }
                }
                observations.add(row + listOf(value.containsKey("rssiSamples"), statsIndex(value["rssiSamples"]),
                    value.filterKeys { it !in identityFields && it !in observationFields && it != "rssiSamples" }
                        .takeIf { it.isNotEmpty() }))
                reference
            }
        }
        return mapOf("schemaVersion" to 3, "strings" to strings, "metadata" to metadata,
            "rssiSamples" to stats, "beacons" to beacons, "frames" to frameReferences,
            "beaconFields" to listOf("uuidRef", "major", "minor", "observations"),
            "observationFields" to observationFields.map {
                when (it) { "proximity" -> "proximityRef"; "metadata" -> "metadataRef"; else -> it }
            } + listOf("rssiSamplesPresent", "rssiSamplesRef", "extraFields"),
            "metadataFields" to metadataFields.map { if (it == "firmwareVersion") "firmwareVersionRef" else it } + "extraFields",
            "rssiSampleFields" to statsFields + "extraFields")
    }

    @Suppress("UNCHECKED_CAST")
    private fun unpackDictionary(value: Any?): List<Map<String, Any?>> {
        val packed = value as Map<String, Any?>
        check(packed["schemaVersion"] == 3) { "Unexpected dictionary schema version" }
        val strings = packed.getValue("strings") as List<*>
        val metadata = packed.getValue("metadata") as List<*>
        val stats = packed.getValue("rssiSamples") as List<*>
        val beacons = packed.getValue("beacons") as List<*>
        fun stringAt(reference: Any?): Any? {
            if (reference == null) return null
            check(reference is Int && reference in strings.indices && strings[reference] is String) {
                "Invalid string dictionary reference"
            }
            return strings[reference]
        }
        fun rowAt(table: List<*>, reference: Any?, size: Int): List<Any?>? {
            if (reference == null) return null
            check(reference is Int && reference in table.indices) { "Invalid row dictionary reference" }
            val row = table[reference] as List<Any?>
            check(row.size == size) { "Invalid dictionary row size" }
            return row
        }
        return (packed.getValue("frames") as List<List<List<Int>>>).map { frame ->
            val restored = frame.map { reference ->
                check(reference.size == 2) { "Invalid frame reference size" }
                val beacon = rowAt(beacons, reference[0], 4)!!
                val observation = rowAt(beacon[3] as List<*>, reference[1], 13)!!.toMutableList()
                check(observation[10] is Boolean) { "Invalid RSSI presence marker" }
                observation[1] = stringAt(observation[1])
                observation[4] = rowAt(metadata, observation[4], 8)?.mapIndexed { index, item ->
                    if (index == 0) stringAt(item) else item
                }
                observation[11] = rowAt(stats, observation[11], 8)
                mutableMapOf("uuid" to stringAt(beacon[0]), "major" to beacon[1], "minor" to beacon[2]).apply {
                    putAll(observationMap(observation))
                }
            }
            mapOf("beacons" to restored)
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun dictionaryControls(): JSONObject {
        val original = (frames(1, 1)[0]["beacons"] as List<Map<String, Any?>>)[0]
        val extraValues = listOf("Aa", "BB").mapIndexed { index, label ->
            original.toMutableMap().apply {
                this["major"] = if (index == 0) 1 else 12
                this["minor"] = if (index == 0) 23 else 3
                this["extraFields"] = listOf(7, 7L, null, true)
                this["metadata"] = (original["metadata"] as Map<String, Any?>).toMutableMap().apply {
                    this["firmwareVersion"] = label
                    this["firmwareVersionRef"] = "preserved extra field"
                    this["label"] = label
                }
                this["rssiSamples"] = (original["rssiSamples"] as Map<String, Any?>).toMutableMap().apply {
                    this["label"] = label
                }
            }
        }
        check("Aa".hashCode() == "BB".hashCode())
        val extrasOnly = extraValues.map { value ->
            value.toMutableMap().apply {
                this["metadata"] = (value["metadata"] as Map<String, Any?>).toMutableMap().apply {
                    this["firmwareVersion"] = "4.2"
                }
            }
        }
        val presentNull = original.toMutableMap().apply {
            this["rssiSamples"] = null
            this["metadata"] = (original["metadata"] as Map<String, Any?>).toMutableMap().apply {
                this["firmwareVersion"] = null
            }
        }
        val edge = listOf(mapOf("beacons" to extraValues + extrasOnly + presentNull), FixedBeaconLists.expectedNullable(),
            mapOf("beacons" to listOf(extraValues[1], extraValues[0], extraValues[1])),
            mapOf("beacons" to emptyList<Any>()))
        check(unpack(pack(edge)) == edge)
        check(unpackDictionary(packDictionary(edge)) == edge)
        val dictionary = packDictionary(frames(1, 2))
        check((dictionary["metadata"] as List<*>).size == 2 && (dictionary["rssiSamples"] as List<*>).size == 1)
        val repeated = unpackDictionary(packDictionary(frames(1, 2, "repeatedBlocks")))
        val a = (repeated[0]["beacons"] as List<Map<String, Any?>>)[0]
        val b = (repeated[1]["beacons"] as List<Map<String, Any?>>)[0]
        check(a["metadata"] !== b["metadata"] && a["rssiSamples"] !== b["rssiSamples"])
        val corrupted = packDictionary(frames(1, 1)).toMutableMap().apply {
            this["frames"] = listOf(listOf(listOf(Int.MAX_VALUE, 0)))
        }
        check(runCatching { unpackDictionary(corrupted) }.isFailure)
        return JSONObject().put("extraFieldsAndInternalNameCollisions", true).put("stringHashCollisions", true)
            .put("identityConcatenationCollision", true).put("presentNullRssi", true)
            .put("distinctChangedBlocks", true).put("freshNestedMaps", true).put("invalidReferenceRejected", true)
    }

    @Suppress("UNCHECKED_CAST")
    private fun frames(size: Int, count: Int, profile: String = "changingMetadata"): List<Map<String, Any?>> = List(count) { frame ->
        val values = (FixedBeaconLists.expectedComplete(size)["beacons"] as List<Map<String, Any?>>)
            .map { original ->
                original.toMutableMap().apply {
                    this["timestamp"] = (original["timestamp"] as Long) + frame * 1000L
                    this["rssi"] = (original["rssi"] as Int) - frame % 9
                    this["alreadySynced"] = frame % 2 == 0
                    this["syncedAt"] = if (frame % 2 == 0) (this["timestamp"] as Long) - 100 else null
                    if (profile != "repeatedBlocks") {
                        this["metadata"] = (original["metadata"] as Map<String, Any?>).toMutableMap().apply {
                            this["batteryLevel"] = (this["batteryLevel"] as Int) - frame % 4
                            this["temperature"] = (this["temperature"] as Int) + frame % 3
                            this["movements"] = frame
                        }
                    }
                    if (profile == "uniqueBlocks") {
                        this["rssiSamples"] = (original["rssiSamples"] as Map<String, Any?>).toMutableMap().apply {
                            this["count"] = (this["count"] as Int) + frame
                            this["firstSeen"] = (this["firstSeen"] as Long) + frame * 1000L
                            this["lastSeen"] = (this["lastSeen"] as Long) + frame * 1000L
                        }
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
            val value = if (dictionaryRows) {
                if (compact) packDictionary(input) else pack(input)
            } else if (compact) pack(input) else input
            val buffer = StandardMethodCodec.INSTANCE.encodeSuccessEnvelope(value)
            encodedBytes = buffer.position()
            encodeCpu += Debug.threadCpuTimeNanos() - encodeStart
            buffer.flip()
            val decodeStart = Debug.threadCpuTimeNanos()
            val decoded = StandardMethodCodec.INSTANCE.decodeEnvelope(buffer)
            val restored = if (dictionaryRows) {
                if (compact) unpackDictionary(decoded) else unpack(decoded)
            } else if (compact) unpack(decoded) else decoded
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
        check(!dictionaryRows || packedRows) { "Dictionary comparison requires schema2 rows as baseline" }
        val properties = Properties()
        context.assets.open("source-hashes.properties").use { properties.load(it) }
        val rounds = JSONArray()
        val caseContexts = JSONArray()
        val controls = JSONObject().put("typedGoldenEveryOperation", true).put("order", true)
            .put("nullableAndOmittedFields", true).put("changingMetadata", true)
            .put("emptyFrame", true).put("duplicateIdentity", true)
        if (dictionaryRows) {
            val extra = dictionaryControls()
            extra.keys().forEach { key -> controls.put(key, extra.get(key)) }
        }
        val nullable = listOf(FixedBeaconLists.expectedNullable(), mapOf("beacons" to emptyList<Any>()))
        check(unpack(pack(nullable)) == nullable)
        val duplicate = frames(1, 1).map { mapOf("beacons" to listOf(
            (it["beacons"] as List<*>)[0], (it["beacons"] as List<*>)[0])) }
        check(unpack(pack(duplicate)) == duplicate)
        val cases = listOf(1, 6, 50).flatMap { size -> listOf(1, 10, 100).map { count ->
            Triple(size, count, "changingMetadata")
        } } + if (dictionaryRows) listOf(Triple(6, 100, "repeatedBlocks"), Triple(6, 100, "uniqueBlocks")) else emptyList()
        for ((size, count, profile) in cases) {
            val input = frames(size, count, profile)
            if (dictionaryRows) {
                val dictionary = packDictionary(input)
                caseContexts.put(JSONObject().put("fixtureProfile", profile).put("listSize", size).put("frames", count)
                    .put("originalPayloadEncodedBytes", StandardMethodCodec.INSTANCE.encodeSuccessEnvelope(input).position())
                    .put("stringEntries", (dictionary["strings"] as List<*>).size)
                    .put("metadataEntries", (dictionary["metadata"] as List<*>).size)
                    .put("rssiSampleEntries", (dictionary["rssiSamples"] as List<*>).size))
            }
            val operations = maxOf(1, 1000 / (size * count))
            val warmup = maxOf(20, operations / 10)
            measure(input, false, warmup)
            measure(input, true, warmup)
            for (cycle in 1..3) {
                listOf(false, true, true, false).forEachIndexed { index, compact ->
                    rounds.put(measure(input, compact, operations).put("listSize", size)
                        .put("frames", count).put("observations", size * count)
                        .put("cycle", cycle).put("orderInCycle", index + 1).put("fixtureProfile", profile)
                        .put("warmupOperationsPerVariant", warmup))
                }
            }
        }
        check(rounds.length() == if (dictionaryRows) 132 else 108)
        return JSONObject().put("status", "success").put("runId", runId)
            .put("schemaVersion", 1).put("modelSchemaVersion", if (dictionaryRows) 3 else if (packedRows) 2 else 1)
            .put("baselineModelSchemaVersion", if (dictionaryRows) 2 else 0).put("rounds", rounds)
            .put("caseContexts", caseContexts)
            .put("modelExample", JSONObject(if (dictionaryRows) packDictionary(frames(1, 2)) else pack(frames(1, 2))))
            .put("baselineModelExample", JSONObject(pack(frames(1, 2))))
            .put("sourceHashes", JSONObject(properties.stringPropertyNames().associateWith { properties.getProperty(it) }))
            .put("environment", JSONObject().put("model", Build.MODEL).put("sdkInt", Build.VERSION.SDK_INT)
                .put("thread", Thread.currentThread().name).put("debuggable", true))
            .put("controls", controls)
            .put("scope", "Private batch representation and real Flutter codec on ART worker thread; " +
                "encode includes grouping, decode includes reconstruction, all operations preserve golden fields; " +
                "wall/process allocations include equality validation and other process activity; " +
                "no scanner, radio, network, Flutter engine or published protocol change")
    }
}
