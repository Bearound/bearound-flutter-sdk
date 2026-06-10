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

class _LogModalState extends State<LogModal> {
  List<PersistedLogEntry> _entries = const [];
  _Filter _filter = _Filter.all;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

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
