import copy
import unittest
from pathlib import Path

from physical_check import HARNESS, validate_results


def valid_result():
    names = [f"candidate_unobserved_zero_reads_queue_{size}" for size in (0, 1, 6, 50)]
    names += ["published_unobserved_positive_reads_queue", "candidate_between_subscriptions_discard", "all_round_controls"]
    for variant in ("published", "candidate"):
        names += [f"{variant}_golden_async_{size}" for size in (0, 1, 6, 50)]
        names += [f"{variant}_{name}" for name in (
            "golden_nullable", "callback_order", "cancel_before_delivery", "live_sink_resubscribe")]
    codec_names = ("empty", "nullable", "complete_1", "complete_6", "complete_50")
    names += [f"codec_golden_{name}" for name in codec_names]
    rounds = []
    for size in (1, 6, 50):
        for subscribed in (False, True):
            for cycle in range(1, 4):
                for order, variant in enumerate(("published", "candidate", "candidate", "published"), 1):
                    maps = subscribed or variant == "published"
                    rounds.append({
                        "mode": "raw-bridge", "listSize": size, "subscribed": subscribed,
                        "cycle": cycle, "orderInCycle": order, "variant": variant,
                        "callbacks": 1000, "controlsPassed": True,
                        "beaconReads": size * 1000 if maps else 0, "sizeReads": 1000 if maps else 0,
                        "pendingDeliveryBatches": 40 if maps else 0, "queuePresenceSamples": 40,
                        "events": 1000 if subscribed else 0, "deliveryThreadId": 1 if subscribed else None,
                        "producerCpuNs": 10, "consumerCpuNs": 2 if subscribed else 0,
                        "threadCpuNs": 12 if subscribed else 10,
                    })
    hashes = dict(line.split("=", 1) for line in (HARNESS / "build/source-hashes.properties").read_text().splitlines())
    return {
        "runId": "test", "status": "success", "environment": {"mainThreadId": 1},
        "config": {"listSizes": [1, 6, 50], "abbaCycles": 3, "callbacksPerRound": 1000,
                   "warmupCallbacks": 5000, "batchSize": 25, "fixtureBaseTimeMs": 1700000000000,
                   "queueProbe": "public Handler.hasMessages(0), presence per producer batch"},
        "controls": [{"name": name, "passed": True} for name in names], "rounds": rounds,
        "codecRounds": [{"mode": "codec-roundtrip", "fixture": name, "goldenEqual": True, "encodedBytes": 10}
                        for name in codec_names], "sourceHashes": hashes,
    }


class PhysicalResultValidationTest(unittest.TestCase):
    def setUp(self):
        self.result = valid_result()

    def test_accepts_complete_independent_controls_and_raw_rounds(self):
        validate_results(self.result, "test")

    def test_rejects_app_error_and_wrong_run(self):
        for key, value in (("status", "error"), ("runId", "other")):
            with self.subTest(key=key):
                changed = copy.deepcopy(self.result)
                changed[key] = value
                with self.assertRaises(RuntimeError):
                    validate_results(changed, "test")

    def test_rejects_missing_control_and_duplicate_round(self):
        self.result["controls"].pop()
        with self.assertRaises(RuntimeError):
            validate_results(self.result, "test")
        changed = valid_result()
        changed["rounds"][1] = copy.deepcopy(changed["rounds"][0])
        with self.assertRaises(RuntimeError):
            validate_results(changed, "test")

    def test_rejects_forged_queue_list_event_thread_and_cpu_controls(self):
        for key, value in (("pendingDeliveryBatches", 39), ("beaconReads", 999),
                           ("sizeReads", 0), ("events", 1), ("threadCpuNs", 11)):
            with self.subTest(key=key):
                changed = copy.deepcopy(self.result)
                changed["rounds"][0][key] = value
                with self.assertRaises(RuntimeError):
                    validate_results(changed, "test")
        changed = copy.deepcopy(self.result)
        subscribed = next(row for row in changed["rounds"] if row["subscribed"])
        subscribed["deliveryThreadId"] = 2
        with self.assertRaises(RuntimeError):
            validate_results(changed, "test")

    def test_rejects_codec_mismatch_and_stale_apk_source_hash(self):
        self.result["codecRounds"][0]["goldenEqual"] = False
        with self.assertRaises(RuntimeError):
            validate_results(self.result, "test")
        changed = valid_result()
        changed["sourceHashes"]["candidate"] = "0" * 64
        with self.assertRaises(RuntimeError):
            validate_results(changed, "test")


if __name__ == "__main__":
    unittest.main()
