import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class BeaconDatabase {
  static late final Database _db;
  static bool _initialized = false;

  static Future<Database> get database async {
    if (!_initialized) {
      _db = await _initDB();
      _initialized = true;
    }
    return _db;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'beacons.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE beacons (
            uuid TEXT NOT NULL,
            major INTEGER NOT NULL,
            minor INTEGER NOT NULL,
            rssi INTEGER,
            bluetoothName TEXT,
            bluetoothAddress TEXT,
            distanceMeters REAL,
            PRIMARY KEY (uuid, major, minor)
          )
        ''');
      },
    );
  }
}
