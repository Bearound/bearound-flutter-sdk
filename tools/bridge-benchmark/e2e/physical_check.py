#!/usr/bin/env python3
"""Bounded runner for the isolated synthetic Android bridge QA application."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid


PACKAGE = "io.bearound.qa.bridge"
HARNESS = Path(__file__).resolve().parents[1]
APK = HARNESS / "e2e/physical-app/build/outputs/apk/debug/physical-app-debug.apk"


def execute(command, timeout=30, required=True):
    result = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
    if required and result.returncode:
        raise RuntimeError(f"Command failed ({result.returncode}): {command[0]} {command[1:]}\n"
                           f"{result.stdout[-4000:]}\n{result.stderr[-4000:]}")
    return result


def validate_results(result, run_id):
    if result.get("runId") != run_id or result.get("status") != "success":
        raise RuntimeError(f"Physical controls failed: {result.get('error')}")
    config = result.get("config", {})
    if config != {
        "listSizes": [1, 6, 50], "abbaCycles": 3, "callbacksPerRound": 1000,
        "warmupCallbacks": 5000, "batchSize": 25, "fixtureBaseTimeMs": 1700000000000,
        "queueProbe": "public Handler.hasMessages(0), presence per producer batch",
    }:
        raise RuntimeError("Unexpected physical benchmark configuration")
    controls = result.get("controls", [])
    names = {control.get("name") for control in controls if control.get("passed") is True}
    required = {f"candidate_unobserved_zero_reads_queue_{size}" for size in (0, 1, 6, 50)}
    required.update(("published_unobserved_positive_reads_queue", "candidate_between_subscriptions_discard",
                     "all_round_controls"))
    for variant in ("published", "candidate"):
        required.update(f"{variant}_golden_async_{size}" for size in (0, 1, 6, 50))
        required.update(f"{variant}_{name}" for name in (
            "golden_nullable", "callback_order", "cancel_before_delivery", "live_sink_resubscribe"))
    required.update(f"codec_golden_{name}" for name in ("empty", "nullable", "complete_1", "complete_6", "complete_50"))
    if names != required or len(controls) != len(required) or not all(c.get("passed") is True for c in controls):
        raise RuntimeError("Missing, duplicate, or failed functional controls")
    rounds = result.get("rounds", [])
    if len(rounds) != 72 or len(result.get("codecRounds", [])) != 5:
        raise RuntimeError("Expected 72 raw rounds and five separate codec probes")
    expected_order = ["published", "candidate", "candidate", "published"]
    expected_keys = {(size, subscribed, cycle, order)
                     for size in (1, 6, 50) for subscribed in (False, True)
                     for cycle in range(1, 4) for order in range(1, 5)}
    seen = set()
    for row in rounds:
        key = (row.get("listSize"), row.get("subscribed"), row.get("cycle"), row.get("orderInCycle"))
        if key not in expected_keys or key in seen or row.get("variant") != expected_order[key[3] - 1]:
            raise RuntimeError("Invalid raw ABBA round identity or order")
        seen.add(key)
        maps = row["variant"] == "published" or row["subscribed"]
        if row.get("mode") != "raw-bridge" or row.get("callbacks") != 1000 or row.get("controlsPassed") is not True:
            raise RuntimeError("Invalid raw callback round")
        if row.get("beaconReads") != (row["listSize"] * 1000 if maps else 0):
            raise RuntimeError("Independent list-read control failed")
        if (maps and row.get("sizeReads", -1) <= 0) or (not maps and row.get("sizeReads") != 0):
            raise RuntimeError("Independent list-size control failed")
        if row.get("pendingDeliveryBatches") != (40 if maps else 0) or row.get("queuePresenceSamples") != 40:
            raise RuntimeError("Independent public queue-presence control failed")
        if row.get("events") != (1000 if row["subscribed"] else 0):
            raise RuntimeError("Independent event-count control failed")
        if row["subscribed"] and row.get("deliveryThreadId") != result["environment"]["mainThreadId"]:
            raise RuntimeError("Delivery thread control failed")
        if row.get("threadCpuNs") != row.get("producerCpuNs", -1) + row.get("consumerCpuNs", -1):
            raise RuntimeError("CPU accounting mismatch")
    for probe in result["codecRounds"]:
        if probe.get("mode") != "codec-roundtrip" or probe.get("goldenEqual") is not True or probe.get("encodedBytes", 0) <= 0:
            raise RuntimeError("Separate codec golden control failed")
    hashes = result.get("sourceHashes", {})
    if hashes.get("nativeCoordinate") != "com.github.Bearound:bearound-android-sdk:v3.14.0":
        raise RuntimeError("Native SDK pin mismatch")
    expected = {}
    for line in (HARNESS / "build/source-hashes.properties").read_text().splitlines():
        name, value = line.split("=", 1)
        expected[name] = value
    if hashes != expected:
        raise RuntimeError("APK source hashes do not match the build's source hashes")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serial", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--skip-build", action="store_true", help="Use the existing APK and generated hash file")
    args = parser.parse_args()
    if not args.output.is_absolute():
        parser.error("--output must be an absolute directory")
    output = args.output
    output.mkdir(parents=True, exist_ok=True)
    run_id = f"bridge-{uuid.uuid4().hex}"
    adb = os.environ.get("BRIDGE_ADB", "/Users/jotta/Library/Android/sdk/platform-tools/adb")
    base = [adb, "-s", args.serial]
    metadata = {"runId": run_id, "package": PACKAGE, "scope": "Synthetic Android bridge QA, not whole-app ANR certification"}
    launched = False
    try:
        if not args.skip_build:
            build = execute(["bash", str(HARNESS / "run.sh"), "physical-build"], timeout=260)
            (output / "physical-build.log").write_text(build.stdout + build.stderr)
        if not APK.is_file():
            raise RuntimeError(f"APK missing: {APK}")
        metadata["apkSha256"] = hashlib.sha256(APK.read_bytes()).hexdigest()
        metadata["apkPath"] = str(APK)
        device = {}
        for name in ("ro.build.version.release", "ro.build.version.sdk", "ro.product.manufacturer", "ro.product.model"):
            device[name] = execute(base + ["shell", "getprop", name], timeout=10).stdout.strip()
        metadata["deviceOs"] = device
        before = execute(base + ["shell", "dumpsys", "activity", "exit-info", PACKAGE], required=False)
        (output / "exit-info-before.txt").write_text(before.stdout + before.stderr)
        log_start = execute(base + ["shell", "date", "+%m-%dT%H:%M:%S.000"], timeout=10).stdout.strip().replace("T", " ", 1)
        execute(base + ["shell", "am", "force-stop", PACKAGE], required=False)
        install = execute(base + ["install", "-r", "-t", str(APK)], timeout=90)
        (output / "install.log").write_text(install.stdout + install.stderr)
        launch = execute(base + ["shell", "am", "start", "-W", "-n", f"{PACKAGE}/.MainActivity", "--es", "run_id", run_id])
        (output / "launch.log").write_text(launch.stdout + launch.stderr)
        launched = True
        deadline = time.monotonic() + 240
        result = None
        while time.monotonic() < deadline:
            read = execute(base + ["shell", "run-as", PACKAGE, "cat", "files/results.json"], timeout=10, required=False)
            if read.returncode == 0 and read.stdout.strip():
                if len(read.stdout) > 4_000_000:
                    raise RuntimeError("Result exceeded the bounded synthetic output size")
                try:
                    candidate = json.loads(read.stdout)
                except json.JSONDecodeError:
                    candidate = None
                if candidate and candidate.get("runId") == run_id:
                    result = candidate
                    (output / "results.json").write_text(read.stdout)
                    break
            time.sleep(2)
        if result is None:
            raise RuntimeError("No finished result within the 240-second physical watchdog")
        validate_results(result, run_id)
        metadata["status"] = "success"
        metadata["controls"] = len(result["controls"])
        metadata["rawRounds"] = len(result["rounds"])
        print(f"Physical bridge QA passed: {metadata['controls']} controls, 72 raw rounds, five codec probes")
        print(f"Results: {output / 'results.json'}")
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as error:
        metadata["status"] = "error"
        metadata["error"] = str(error)
        print(f"Physical bridge QA failed: {error}", file=sys.stderr)
        return 1
    finally:
        if launched:
            try:
                after = execute(base + ["shell", "dumpsys", "activity", "exit-info", PACKAGE], required=False)
                (output / "exit-info-after.txt").write_text(after.stdout + after.stderr)
                crash = execute(base + ["logcat", "-b", "crash", "-v", "threadtime", "-d", "-T", log_start, "-t", "1000"], required=False)
                qa_pids = set(re.findall(r"Process: " + re.escape(PACKAGE) + r", PID: (\d+)", crash.stdout))
                relevant = []
                for line in crash.stdout.splitlines():
                    header = re.match(r"\d\d-\d\d\s+\S+\s+(\d+)\s+\d+\s+", line)
                    if PACKAGE in line or (header and header.group(1) in qa_pids):
                        relevant.append(line)
                (output / "qa-package-crash.log").write_text("\n".join(relevant) + ("\n" if relevant else ""))
            except (OSError, subprocess.TimeoutExpired) as error:
                metadata["captureError"] = str(error)
        (output / "run-metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
