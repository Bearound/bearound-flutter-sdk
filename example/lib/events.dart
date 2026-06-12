import 'package:flutter/material.dart';

/// Geofence / two-eyes event kinds — mirrors the RN example for parity.
enum GeofenceEventKind {
  regionEnter,
  regionExit,
  scanActive,
  scanPaused,
  btZoneEnter,
  btZoneExit,
}

class GeofenceEventEntry {
  final String id;
  final GeofenceEventKind kind;
  final DateTime timestamp;
  final String detail;

  GeofenceEventEntry({
    required this.id,
    required this.kind,
    required this.timestamp,
    required this.detail,
  });
}

String geofenceEventTitle(GeofenceEventKind kind) {
  switch (kind) {
    case GeofenceEventKind.regionEnter:
      return '👁 LOCATION — ENTROU';
    case GeofenceEventKind.regionExit:
      return '👁 LOCATION — SAIU';
    case GeofenceEventKind.scanActive:
      return 'SCAN LIGADO';
    case GeofenceEventKind.scanPaused:
      return 'SCAN PAUSADO';
    case GeofenceEventKind.btZoneEnter:
      return '👁 BLUETOOTH — ENTROU';
    case GeofenceEventKind.btZoneExit:
      return '👁 BLUETOOTH — SAIU';
  }
}

Color geofenceEventColor(GeofenceEventKind kind) {
  switch (kind) {
    case GeofenceEventKind.regionEnter:
    case GeofenceEventKind.scanActive:
      return const Color(0xFF4CAF50);
    case GeofenceEventKind.regionExit:
      return const Color(0xFFFF9800);
    case GeofenceEventKind.scanPaused:
      return const Color(0xFF9E9E9E);
    case GeofenceEventKind.btZoneEnter:
      return const Color(0xFF2196F3);
    case GeofenceEventKind.btZoneExit:
      return const Color(0xFFFF9800);
  }
}

/// App-state bucket displayed in the log modal.
enum AppStateBucket { foreground, background, backgroundLocked, terminated }

String appStateLabel(AppStateBucket bucket) {
  switch (bucket) {
    case AppStateBucket.foreground:
      return 'Foreground';
    case AppStateBucket.background:
      return 'Background';
    case AppStateBucket.backgroundLocked:
      return 'Background (tela bloqueada)';
    case AppStateBucket.terminated:
      return 'Terminated (relaunch)';
  }
}

Color appStateColor(AppStateBucket bucket) {
  switch (bucket) {
    case AppStateBucket.foreground:
      return const Color(0xFF4CAF50);
    case AppStateBucket.background:
      return const Color(0xFFFF9800);
    case AppStateBucket.backgroundLocked:
      return const Color(0xFF607D8B);
    case AppStateBucket.terminated:
      return const Color(0xFF9C27B0);
  }
}

AppStateBucket appStateBucketFromString(String? value) {
  switch (value) {
    case 'foreground':
      return AppStateBucket.foreground;
    case 'backgroundLocked':
      return AppStateBucket.backgroundLocked;
    case 'terminated':
      return AppStateBucket.terminated;
    default:
      return AppStateBucket.background;
  }
}
