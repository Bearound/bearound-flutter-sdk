import 'package:sqflite/sqflite.dart';
import '../models/beacon.dart';

class BeaconLocalStorage {
  final Database db;

  BeaconLocalStorage(this.db);

  /// Salva os beacons. Usa (uuid, major, minor) como chave única.
  Future<void> saveBeacons(List<Beacon> beacons) async {
    for (final beacon in beacons) {
      await db.insert(
        'beacons',
        beacon.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Retorna todos os beacons armazenados.
  Future<List<Beacon>> loadBeacons() async {
    final maps = await db.query('beacons');
    return maps.map((map) => Beacon.fromJson(map)).toList();
  }

  /// Limpa todos os beacons armazenados.
  Future<void> clearBeacons() async {
    await db.delete('beacons');
  }

  /// Remove apenas um beacon específico (por uuid, major, minor)
  Future<void> deleteBeacon(String uuid, int major, int minor) async {
    await db.delete(
      'beacons',
      where: 'uuid = ? AND major = ? AND minor = ?',
      whereArgs: [uuid, major, minor],
    );
  }
}
