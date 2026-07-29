import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';
import 'package:flutter/material.dart';

import 'events.dart';

/// Renders the native persisted log filtered by app state bucket.
class LogModal extends StatefulWidget {
  const LogModal({super.key});

  @override
  State<LogModal> createState() => _LogModalState();
}

enum _Filter { all, foreground, background, backgroundLocked, terminated }

/// Mirrors the iOS `LogViewMode`: raw entries or per-minute aggregation.
enum _ViewMode { detail, grouped }

/// One minute of activity — same shape the iOS `MinuteGroup` renders:
/// total detections, per-state counts and how many distinct beacons appeared.
class _MinuteGroup {
  _MinuteGroup({
    required this.date,
    required this.total,
    required this.fg,
    required this.bg,
    required this.lk,
    required this.tm,
    required this.uniqueBeacons,
  });

  final DateTime date;
  final int total;
  final int fg;
  final int bg;
  final int lk;
  final int tm;
  final int uniqueBeacons;
}

class _LogModalState extends State<LogModal> {
  List<PersistedLogEntry> _entries = const [];
  _Filter _filter = _Filter.all;
  _ViewMode _viewMode = _ViewMode.detail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// Android has no native persisted log (the plugin's getPersistedLog is an
  /// iOS-only stub returning `[]`), so there the entries come from the app-side
  /// store fed by the SDK streams. iOS keeps reading the native log.
  Future<void> _refresh() async {
    try {
      final entries = await BearoundFlutterSdk.getPersistedLog();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clear() async {
    try {
      await BearoundFlutterSdk.clearPersistedLog();
    } catch (_) {
      // Best effort.
    }
    if (mounted) setState(() => _entries = const []);
  }

  bool _matchesFilter(PersistedLogEntry entry) {
    switch (_filter) {
      case _Filter.all:
        return true;
      case _Filter.foreground:
        return entry.state == PersistedLogState.foreground;
      case _Filter.background:
        return entry.state == PersistedLogState.background;
      case _Filter.backgroundLocked:
        return entry.state == PersistedLogState.backgroundLocked;
      case _Filter.terminated:
        return entry.state == PersistedLogState.terminated;
    }
  }

  AppStateBucket _toBucket(PersistedLogState state) {
    switch (state) {
      case PersistedLogState.foreground:
        return AppStateBucket.foreground;
      case PersistedLogState.background:
        return AppStateBucket.background;
      case PersistedLogState.backgroundLocked:
        return AppStateBucket.backgroundLocked;
      case PersistedLogState.terminated:
        return AppStateBucket.terminated;
    }
  }

  static final _beaconIdPattern = RegExp(r'\b(\d+\.\d+)\b');

  /// Aggregates entries per minute, exactly like the iOS `groupedByMinute`.
  List<_MinuteGroup> _groupByMinute(List<PersistedLogEntry> entries) {
    final buckets = <int, List<PersistedLogEntry>>{};
    for (final e in entries) {
      final t = DateTime.fromMillisecondsSinceEpoch(e.timestamp);
      final key = DateTime(t.year, t.month, t.day, t.hour, t.minute)
          .millisecondsSinceEpoch;
      buckets.putIfAbsent(key, () => []).add(e);
    }
    final groups = buckets.entries.map((b) {
      final list = b.value;
      final ids = <String>{};
      for (final e in list) {
        for (final m in _beaconIdPattern.allMatches(e.detail)) {
          ids.add(m.group(1)!);
        }
      }
      int countOf(PersistedLogState s) => list.where((e) => e.state == s).length;
      return _MinuteGroup(
        date: DateTime.fromMillisecondsSinceEpoch(b.key),
        total: list.length,
        fg: countOf(PersistedLogState.foreground),
        bg: countOf(PersistedLogState.background),
        lk: countOf(PersistedLogState.backgroundLocked),
        tm: countOf(PersistedLogState.terminated),
        uniqueBeacons: ids.length,
      );
    }).toList();
    groups.sort((a, b) => b.date.compareTo(a.date));
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _entries.where(_matchesFilter).toList();
    final counts = {
      AppStateBucket.foreground: _entries
          .where((e) => e.state == PersistedLogState.foreground)
          .length,
      AppStateBucket.background: _entries
          .where((e) => e.state == PersistedLogState.background)
          .length,
      AppStateBucket.backgroundLocked: _entries
          .where((e) => e.state == PersistedLogState.backgroundLocked)
          .length,
      AppStateBucket.terminated: _entries
          .where((e) => e.state == PersistedLogState.terminated)
          .length,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log de Eventos'),
        actions: [
          if (_entries.isNotEmpty)
            TextButton(
              onPressed: _clear,
              child: const Text('Apagar', style: TextStyle(color: Colors.red)),
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _summary(
                        'FG',
                        counts[AppStateBucket.foreground]!,
                        appStateColor(AppStateBucket.foreground),
                      ),
                      const SizedBox(width: 8),
                      _summary(
                        'BG',
                        counts[AppStateBucket.background]!,
                        appStateColor(AppStateBucket.background),
                      ),
                      const SizedBox(width: 8),
                      _summary(
                        'BG🔒',
                        counts[AppStateBucket.backgroundLocked]!,
                        appStateColor(AppStateBucket.backgroundLocked),
                      ),
                      const SizedBox(width: 8),
                      _summary(
                        'Terminated',
                        counts[AppStateBucket.terminated]!,
                        appStateColor(AppStateBucket.terminated),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SegmentedButton<_ViewMode>(
                    segments: const [
                      ButtonSegment(
                        value: _ViewMode.detail,
                        label: Text('Detalhado'),
                      ),
                      ButtonSegment(
                        value: _ViewMode.grouped,
                        label: Text('Por Minuto'),
                      ),
                    ],
                    selected: {_viewMode},
                    onSelectionChanged: (v) =>
                        setState(() => _viewMode = v.first),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      for (final f in _Filter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(_filterLabel(f)),
                            selected: _filter == f,
                            onSelected: (_) => setState(() => _filter = f),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhum evento registrado ainda.',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : _viewMode == _ViewMode.grouped
                      ? ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _groupByMinute(filtered).length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) =>
                              _minuteRow(_groupByMinute(filtered)[index]),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final entry = filtered[index];
                            final bucket = _toBucket(entry.state);
                            final color = appStateColor(bucket);
                            final time = DateTime.fromMillisecondsSinceEpoch(
                              entry.timestamp,
                            );
                            return ListTile(
                              leading: Container(
                                margin: const EdgeInsets.only(top: 6),
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.type,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _fmtTime(time),
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.detail,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    appStateLabel(bucket),
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  /// One per-minute row — same information the iOS `MinuteGroupRow` shows:
  /// "dd/MM HH:mm", total detections, per-state badges (only when non-zero) and
  /// the number of distinct beacons seen in that minute.
  Widget _minuteRow(_MinuteGroup g) {
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${two(g.date.day)}/${two(g.date.month)} ${two(g.date.hour)}:${two(g.date.minute)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(stamp, style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                '${g.total} detecções',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (g.fg > 0)
                _countBadge('FG', g.fg, appStateColor(AppStateBucket.foreground)),
              if (g.bg > 0)
                _countBadge('BG', g.bg, appStateColor(AppStateBucket.background)),
              if (g.lk > 0)
                _countBadge(
                  'LK',
                  g.lk,
                  appStateColor(AppStateBucket.backgroundLocked),
                ),
              if (g.tm > 0)
                _countBadge('T', g.tm, appStateColor(AppStateBucket.terminated)),
              const Spacer(),
              Text(
                '${g.uniqueBeacons} beacon${g.uniqueBeacons == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _countBadge(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 2),
          Text('$count', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _summary(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  String _filterLabel(_Filter f) {
    switch (f) {
      case _Filter.all:
        return 'Todos';
      case _Filter.foreground:
        return 'Foreground';
      case _Filter.background:
        return 'Background';
      case _Filter.backgroundLocked:
        return 'BG bloqueado';
      case _Filter.terminated:
        return 'Terminated';
    }
  }

  String _fmtTime(DateTime t) {
    String pad(int v) => v.toString().padLeft(2, '0');
    return '${pad(t.hour)}:${pad(t.minute)}:${pad(t.second)}';
  }
}
