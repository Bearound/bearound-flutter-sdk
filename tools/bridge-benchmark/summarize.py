#!/usr/bin/env python3
"""Validate equal workloads and summarize the retained bridge measurements."""

import argparse
import hashlib
import json
import statistics
from pathlib import Path


def summarize(path):
    raw = json.loads(path.read_text())
    assert raw['schema'] == 1
    assert raw['environment']['nativeVersion'] == '3.14.0'
    assert raw['environment']['queueDrainOnMeasuredThread'] is True
    assert raw['sourceHashes']['publishedOriginal'] == '7d4fbbc13e6dc0ae1eced82576d50e9da18a798618d2320ef1f3ee0e0d94d270'
    assert raw['inputConfig']['abbaCycles'] >= 3
    expected_rounds = len(raw['inputConfig']['listSizes']) * len(raw['inputConfig']['sinkModes']) * 4 * raw['inputConfig']['abbaCycles']
    assert len(raw['measurements']) == expected_rounds
    groups = []
    for size in raw['inputConfig']['listSizes']:
        for subscribed in raw['inputConfig']['sinkModes']:
            variants = {}
            for variant in ('published', 'candidate'):
                rows = [r for r in raw['measurements'] if r['listSize'] == size and
                        r['subscribed'] == subscribed and r['variant'] == variant]
                assert len(rows) == 2 * raw['inputConfig']['abbaCycles']
                assert all(r['callbackCount'] == raw['inputConfig']['callbacksPerRound'] for r in rows)
                callbacks = sum(r['callbackCount'] for r in rows)
                reads = sum(r['beaconReads'] for r in rows)
                queued = sum(r['queuedDeliveryCount'] for r in rows)
                delivered = sum(r['deliveries'] for r in rows)
                maps_payload = subscribed or variant == 'published'
                assert reads == (callbacks * size if maps_payload else 0)
                assert queued == (callbacks if maps_payload else 0)
                assert delivered == (callbacks if subscribed else 0)
                assert len({r['payloadChecksum'] for r in rows}) == 1
                metrics = {}
                for key in ('threadCpuNs', 'wallNs', 'allocatedBytes'):
                    values = [r[key] / r['callbackCount'] for r in rows if r[key] is not None]
                    assert all(v >= 0 for v in values)
                    metrics[key] = {'medianPerCallback': statistics.median(values) if values else None,
                                    'minPerCallback': min(values) if values else None,
                                    'maxPerCallback': max(values) if values else None}
                variants[variant] = {'callbacks': callbacks, 'beaconReads': reads,
                                     'queuedDeliveries': queued, 'deliveries': delivered,
                                     'payloadChecksum': rows[0]['payloadChecksum'],
                                     'metrics': metrics,
                                     'gcCount': sum(r['gcCount'] for r in rows),
                                     'gcTimeMs': sum(r['gcTimeMs'] for r in rows)}
            assert variants['published']['callbacks'] == variants['candidate']['callbacks']
            if subscribed:
                assert variants['published']['payloadChecksum'] == variants['candidate']['payloadChecksum']
            ratios = {}
            for key in ('threadCpuNs', 'wallNs', 'allocatedBytes'):
                before = variants['published']['metrics'][key]['medianPerCallback']
                after = variants['candidate']['metrics'][key]['medianPerCallback']
                ratios[key] = None if before is None or after is None or before == 0 else after / before
            paired_cycles = []
            for run in sorted({r.get('run', 1) for r in raw['measurements']}):
                run_rows = [r for r in raw['measurements'] if r['listSize'] == size and
                            r['subscribed'] == subscribed and r.get('run', 1) == run]
                cycle_ids = sorted({(r.get('roundWithinRun', r['round']) - 1) // 4 for r in run_rows})
                for cycle in cycle_ids:
                    cycle_rows = [r for r in run_rows if (r.get('roundWithinRun', r['round']) - 1) // 4 == cycle]
                    assert len(cycle_rows) == 4
                    assert [r['variant'] for r in cycle_rows] == ['published', 'candidate', 'candidate', 'published']
                    cycle_ratios = {}
                    for key in ('threadCpuNs', 'wallNs', 'allocatedBytes'):
                        before = [r[key] for r in cycle_rows if r['variant'] == 'published']
                        after = [r[key] for r in cycle_rows if r['variant'] == 'candidate']
                        cycle_ratios[key] = None if any(v is None for v in before + after) or sum(before) == 0 else sum(after) / sum(before)
                    paired_cycles.append({'run': run, 'cycle': cycle + 1, 'ratios': cycle_ratios})
            paired_medians = {}
            for key in ('threadCpuNs', 'wallNs', 'allocatedBytes'):
                values = [c['ratios'][key] for c in paired_cycles if c['ratios'][key] is not None]
                paired_medians[key] = statistics.median(values) if values else None
            groups.append({'listSize': size, 'subscribed': subscribed, 'variants': variants,
                           'candidateToPublishedRatios': ratios,
                           'pairedCycles': paired_cycles, 'medianPairedRatios': paired_medians})
    return {'scope': 'Instrumented real Android Flutter callback in Robolectric on a host JVM',
            'rawSha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'sourceHashes': raw['sourceHashes'], 'environment': raw['environment'],
            'inputConfig': {k: v for k, v in raw['inputConfig'].items() if k != 'fixtures'},
            'groups': groups, 'wholeAppCpuMeasured': False, 'physicalAnrCertified': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('raw', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = json.dumps(summarize(args.raw), indent=2) + '\n'
    if args.output:
        args.output.write_text(result)
    else:
        print(result, end='')


if __name__ == '__main__':
    main()
